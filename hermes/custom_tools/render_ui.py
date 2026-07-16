"""
render_ui — Custom Hermes tool for dynamic UI generation.

This file is placed in ~/.hermes/custom_tools/ and auto-discovered by Hermes
at startup. It registers a tool that the AI calls to express "what UI to show"
instead of replying with plain text.

The render adapter intercepts this tool call from the Hermes response and
translates it into A2UI WebSocket messages for the Flutter client.

Hermes itself does NOT execute this tool — the adapter does. The tool handler
here is a pass-through that returns the payload as-is for the adapter to process.
"""

# Tool registration follows Hermes custom_tools convention.
# Hermes scans this directory and registers tools based on TOOL_DEFINITION.

TOOL_DEFINITION = {
    "name": "render_ui",
    "description": (
        "Render a native UI on the user's current device surface. "
        "Call this INSTEAD of replying with plain text whenever a "
        "visual/interactive interface helps (device status, media, weather, "
        "lists, forms, confirmations). Compose the UI ONLY from the component "
        "catalog; you cannot invent new component types. Respect the currently "
        "active styleSkill."
    ),
    "parameters": {
        "type": "object",
        "required": ["surfaceId", "root"],
        "properties": {
            "surfaceId": {
                "type": "string",
                "description": "Target rendering surface, default 'main'",
            },
            "styleSkill": {
                "type": "string",
                "description": "Currently active UI style skill name",
            },
            "root": {"$ref": "#/$defs/node"},
        },
        "$defs": {
            "node": {
                "type": "object",
                "required": ["component"],
                "properties": {
                    "component": {
                        "type": "string",
                        "description": (
                            "Catalog component name: InfoCard, WeatherCard, "
                            "DeviceTile, MediaPlayer, MetricChart, ListView, "
                            "Row, Column, Section, ConfirmDialog, TextInput, "
                            "Slider, Toggle, EmailDashboard, MapNavigation"
                        ),
                    },
                    "props": {
                        "type": "object",
                        "description": "Component properties matching its schema",
                    },
                    "bindings": {
                        "type": "object",
                        "description": (
                            "Data bindings: bind props to DataContext paths "
                            "for interactive state flow"
                        ),
                    },
                    "events": {
                        "type": "object",
                        "description": (
                            "Event → action name mapping, e.g. "
                            "{'onTap': 'device.toggle'}"
                        ),
                    },
                    "children": {
                        "type": "array",
                        "items": {"$ref": "#/$defs/node"},
                    },
                },
            }
        },
    },
}


def handle(arguments: dict) -> dict:
    """
    Pass-through handler. The render adapter intercepts this tool call
    from the Hermes API response *before* it reaches this handler.

    If this handler is somehow invoked directly (e.g. during testing),
    it returns the arguments unchanged so the caller can inspect them.
    """
    return {
        "status": "rendered",
        "surfaceId": arguments.get("surfaceId", "main"),
        "component_count": _count_nodes(arguments.get("root", {})),
    }


def _count_nodes(node: dict) -> int:
    """Count total nodes in the UI tree."""
    count = 1
    for child in node.get("children", []):
        count += _count_nodes(child)
    return count
