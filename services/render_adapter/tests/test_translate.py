from render_adapter.translate import translate_to_a2ui, parse_client_event

def test_translate_to_a2ui() -> None:
    payload = {
        "surfaceId": "main",
        "styleSkill": "ui-style-minimal",
        "root": {
            "component": "InfoCard",
            "props": {"title": "Hi", "body": "There"}
        }
    }
    msg = translate_to_a2ui(payload)
    assert msg.type == "render"
    assert msg.surface_id == "main"
    assert msg.style_skill == "ui-style-minimal"
    assert msg.ui_tree["component"] == "InfoCard"

def test_parse_client_event() -> None:
    raw = {
        "type": "user_event",
        "action": "device.toggle",
        "payload": {"state": True}
    }
    event = parse_client_event(raw)
    assert event.action == "device.toggle"
    assert event.payload["state"] is True
