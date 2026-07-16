"""
UI Spec package for Home Steward.
Provides JSON schema validation for A2UI render_ui tool payloads.
"""

from .schema import CATALOG_COMPONENTS, load_component_schema
from .validator import validate_render_ui

__all__ = [
    "CATALOG_COMPONENTS",
    "load_component_schema",
    "validate_render_ui",
]
