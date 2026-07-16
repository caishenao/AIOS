import httpx
import logging
from typing import Any

logger = logging.getLogger(__name__)

class A2AClient:
    def __init__(self) -> None:
        pass

    async def delegate_task(self, endpoint: str, task: str, session_id: str) -> dict[str, Any]:
        """
        Delegate a task to another A2A agent.
        """
        url = f"{endpoint.rstrip('/')}/a2a/tasks"
        payload = {
            "task": task,
            "session_id": session_id
        }
        try:
            async with httpx.AsyncClient() as client:
                response = await client.post(url, json=payload, timeout=30.0)
                response.raise_for_status()
                return response.json()
        except httpx.HTTPError as e:
            logger.error(f"Failed to delegate A2A task to {url}: {e}")
            return {"error": str(e), "status": "failed"}

a2a_client = A2AClient()
