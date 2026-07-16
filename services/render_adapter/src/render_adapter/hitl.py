import asyncio
import uuid
from typing import Any
from pydantic import BaseModel

class PendingConfirmation(BaseModel):
    model_config = {"arbitrary_types_allowed": True}
    
    id: str
    action: str
    tool_name: str
    arguments: dict[str, Any]
    event: asyncio.Event
    confirmed: bool = False

class HITLGate:
    def __init__(self) -> None:
        self.pending_confirmations: dict[str, PendingConfirmation] = {}
        # Simple patterns indicating irreversible actions
        self.irreversible_patterns = [
            "lock", "unlock", "disarm", "open_cover", "close_cover", "turn_off_hvac"
        ]

    def requires_confirmation(self, tool_name: str, arguments: dict[str, Any]) -> bool:
        """Check if an action is irreversible and requires confirmation."""
        # Check tool name
        arg_str = str(arguments).lower()
        if any(p in tool_name.lower() or p in arg_str for p in self.irreversible_patterns):
            return True
            
        # Check specific argument patterns (e.g. state=false for climate)
        # This is simplified; in a real app, you'd have more robust logic
        arg_str = str(arguments).lower()
        if "climate" in arg_str and "off" in arg_str:
            return True
            
        return False

    def create_confirmation(self, tool_name: str, arguments: dict[str, Any], message: str) -> dict[str, Any]:
        """Create a ConfirmDialog payload for the client."""
        conf_id = str(uuid.uuid4())
        self.pending_confirmations[conf_id] = PendingConfirmation(
            id=conf_id,
            action="confirm_action",
            tool_name=tool_name,
            arguments=arguments,
            event=asyncio.Event()
        )
        
        return {
            "component": "ConfirmDialog",
            "props": {
                "message": message,
                "confirmAction": "confirm",
                "cancelAction": "cancel",
                "severity": "warning"
            },
            "events": {
                "onConfirm": f"hitl.confirm.{conf_id}",
                "onCancel": f"hitl.cancel.{conf_id}"
            }
        }

    def resolve(self, confirmation_id: str, confirmed: bool) -> None:
        """Resolve a pending confirmation based on client response."""
        if confirmation_id in self.pending_confirmations:
            conf = self.pending_confirmations[confirmation_id]
            conf.confirmed = confirmed
            conf.event.set()

    async def wait_for_confirmation(self, confirmation_id: str, timeout: int = 300) -> bool:
        """Wait for user confirmation with a timeout."""
        if confirmation_id not in self.pending_confirmations:
            return False
            
        conf = self.pending_confirmations[confirmation_id]
        try:
            await asyncio.wait_for(conf.event.wait(), timeout=timeout)
            return conf.confirmed
        except asyncio.TimeoutError:
            return False
        finally:
            self.pending_confirmations.pop(confirmation_id, None)

hitl_gate = HITLGate()
