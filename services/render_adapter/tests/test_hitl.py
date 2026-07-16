import pytest
import asyncio
from render_adapter.hitl import HITLGate

def test_requires_confirmation(hitl_gate: HITLGate) -> None:
    assert hitl_gate.requires_confirmation("ha_call_service", {"domain": "lock", "service": "unlock"}) is True
    assert hitl_gate.requires_confirmation("ha_call_service", {"domain": "light", "service": "turn_on"}) is False

def test_create_confirmation(hitl_gate: HITLGate) -> None:
    payload = hitl_gate.create_confirmation("lock_door", {}, "Are you sure?")
    assert payload["component"] == "ConfirmDialog"
    assert len(hitl_gate.pending_confirmations) == 1

@pytest.mark.asyncio
async def test_wait_for_confirmation(hitl_gate: HITLGate) -> None:
    payload = hitl_gate.create_confirmation("lock_door", {}, "Are you sure?")
    conf_id = list(hitl_gate.pending_confirmations.keys())[0]

    # Resolve it in background
    async def resolve_later() -> None:
        await asyncio.sleep(0.1)
        hitl_gate.resolve(conf_id, True)

    asyncio.create_task(resolve_later())
    
    result = await hitl_gate.wait_for_confirmation(conf_id, timeout=1)
    assert result is True
    assert conf_id not in hitl_gate.pending_confirmations
