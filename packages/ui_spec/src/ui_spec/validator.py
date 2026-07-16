from typing import Any
import jsonschema
from jsonschema.exceptions import ValidationError

from .schema import get_render_ui_schema, load_component_schema, CATALOG_COMPONENTS

def _validate_node_recursively(node: dict[str, Any]) -> None:
    if not isinstance(node, dict):
        raise ValidationError("Node must be an object")
    
    component = node.get("component")
    if not component:
        raise ValidationError("Node is missing 'component' field")
        
    if component not in CATALOG_COMPONENTS:
        raise ValidationError(f"Unknown component: {component}")
        
    props = node.get("props", {})
    comp_schema = load_component_schema(component)
    
    # Validate props against the component schema
    jsonschema.validate(instance=props, schema=comp_schema)
    
    # Validate children recursively
    children = node.get("children", [])
    if not isinstance(children, list):
        raise ValidationError("'children' must be an array")
        
    for child in children:
        _validate_node_recursively(child)


def validate_render_ui(payload: dict[str, Any]) -> tuple[bool, dict[str, Any] | None]:
    """
    Validates a render_ui payload.
    Returns (True, None) if valid.
    Returns (False, fallback_payload) if invalid, containing diagnostic info.
    """
    try:
        # First validate structural skeleton
        jsonschema.validate(instance=payload, schema=get_render_ui_schema())
        
        # Then recursively validate component-specific props
        root = payload.get("root")
        if root:
            _validate_node_recursively(root)
            
        return True, None
        
    except ValidationError as e:
        error_msg = f"UI Spec validation failed: {e.message}"
        
        # Construct fallback UI
        fallback = {
            "surfaceId": payload.get("surfaceId", "main"),
            "root": {
                "component": "InfoCard",
                "props": {
                    "title": "UI Generation Error",
                    "body": error_msg,
                    "theme": {
                        "color.surface": "#2C1E1E",
                        "color.accent": "#EF4444"
                    }
                }
            }
        }
        return False, fallback
