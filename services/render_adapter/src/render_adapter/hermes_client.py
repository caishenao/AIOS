import logging
from typing import Any

import httpx
import json

from .render_ui import RENDER_UI_TOOL_SCHEMA
from .a2a_client import a2a_client

logger = logging.getLogger(__name__)

class HermesClient:
    def __init__(self, base_url: str, api_key: str, model: str = "hermes-agent") -> None:
        self.base_url = base_url.rstrip("/")
        self.api_key = api_key
        self.model = model
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
        }
        self.client = httpx.AsyncClient(base_url=self.base_url, headers=headers, timeout=60.0)

    async def close(self) -> None:
        await self.client.aclose()

    async def health_check(self) -> bool:
        try:
            # Note: /health might not be present on public endpoints like deepseek, 
            # so we just try /models as a fallback or return True
            try:
                response = await self.client.get("/health")
                return response.status_code == 200
            except Exception:
                response = await self.client.get("/v1/models")
                return response.status_code == 200
        except httpx.RequestError:
            return False

    async def send_message(self, session_id: str, messages: list[dict[str, Any]], tools: list[dict[str, Any]] | None = None, a2a_agents: list[dict[str, Any]] | None = None) -> dict[str, Any]:
        """
        Send a message to Hermes via OpenAI-compatible endpoint.
        """
        if tools is None:
            # Inject render_ui tool
            tools = [{"type": "function", "function": RENDER_UI_TOOL_SCHEMA}]
            
            # Inject platform-specific tools
            try:
                from .platform_tools import get_platform_tools_schemas
                tools.extend(get_platform_tools_schemas())
            except Exception as e:
                logger.error(f"Error extending platform tools: {e}")
            
            # Inject a2a_delegate tool if there are available agents
            if a2a_agents:
                tools.append({
                    "type": "function",
                    "function": {
                        "name": "a2a_delegate",
                        "description": "Delegate a task to another A2A agent on the network.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "endpoint": {"type": "string", "description": "The endpoint URL of the target agent"},
                                "task": {"type": "string", "description": "The task instruction to send"}
                            },
                            "required": ["endpoint", "task"]
                        }
                    }
                })

        # Inject system prompt if not present
        if not any(m.get("role") == "system" for m in messages):
            system_msg = {
                "role": "system",
                "content": "You are Home Steward, a smart home assistant. You must ALWAYS use the `render_ui` tool to present information to the user. Do not reply with plain text. Use Catalog components like InfoCard, WeatherCard, DeviceTile, etc."
            }
            messages = [system_msg] + messages

        payload: dict[str, Any] = {
            "model": self.model,
            "messages": messages,
        }
        if tools:
            payload["tools"] = tools

        try:
            response = await self.client.post("/v1/chat/completions", json=payload)
            response.raise_for_status()
            result = response.json()
            logger.info(f"LLM response: {result}")
            
            # Process tool calls
            choices = result.get("choices", [])
            if choices:
                message = choices[0].get("message", {})
                tool_calls = message.get("tool_calls", [])
                
                if tool_calls:
                    # Append the assistant message first
                    messages.append(message)
                    
                    has_executed_any = False
                    for tool_call in tool_calls:
                        function = tool_call.get("function", {})
                        name = function.get("name")
                        
                        if name == "a2a_delegate":
                            try:
                                args = json.loads(function.get("arguments", "{}"))
                                endpoint = args.get("endpoint")
                                task = args.get("task")
                                if endpoint and task:
                                    a2a_result = await a2a_client.delegate_task(endpoint, task, session_id)
                                    messages.append({
                                        "role": "tool",
                                        "tool_call_id": tool_call.get("id"),
                                        "name": "a2a_delegate",
                                        "content": json.dumps(a2a_result)
                                    })
                                    has_executed_any = True
                            except Exception as e:
                                logger.error(f"Error handling a2a_delegate: {e}")
                                
                        elif name in ["exec_adb", "adb_screenshot", "adb_click", 
                                      "exec_powershell", "capture_screen", "simulate_mouse", 
                                      "simulate_keyboard", "exec_shell"]:
                            try:
                                args = json.loads(function.get("arguments", "{}"))
                                from .platform_tools import execute_platform_tool
                                tool_result = await execute_platform_tool(name, args)
                                messages.append({
                                    "role": "tool",
                                    "tool_call_id": tool_call.get("id"),
                                    "name": name,
                                    "content": json.dumps(tool_result)
                                })
                                has_executed_any = True
                            except Exception as e:
                                logger.error(f"Error handling platform tool {name}: {e}")
                                
                    if has_executed_any:
                        # Recursive call to let Hermes continue generating based on the tool results
                        return await self.send_message(session_id, messages, tools, a2a_agents)
                        
            return result
        except httpx.HTTPStatusError as e:
            logger.error(f"Hermes HTTP error: {e.response.status_code} - {e.response.text}")
            raise
        except httpx.RequestError as e:
            logger.error(f"Hermes connection error: {e}")
            raise

    async def cancel_run(self, run_id: str) -> bool:
        """Cancel an ongoing run in Hermes."""
        try:
            response = await self.client.post(f"/v1/runs/{run_id}/stop")
            return response.status_code == 200
        except httpx.RequestError:
            return False
