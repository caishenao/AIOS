import json
import os
from pathlib import Path
from typing import Any

SCHEMA_DIR = Path(__file__).parent / "schemas"
COMPONENTS_DIR = SCHEMA_DIR / "components"

CATALOG_COMPONENTS = [
    "InfoCard",
    "WeatherCard",
    "DeviceTile",
    "MediaPlayer",
    "MetricChart",
    "ListView",
    "Row",
    "Column",
    "Section",
    "ConfirmDialog",
    "TextInput",
    "Slider",
    "Toggle",
    "EmailDashboard",
    "MapNavigation",
]

_schema_cache: dict[str, dict[str, Any]] = {}

def load_schema(path: Path) -> dict[str, Any]:
    """Load a JSON schema from disk, caching it in memory."""
    key = str(path)
    if key not in _schema_cache:
        with open(path, "r", encoding="utf-8") as f:
            _schema_cache[key] = json.load(f)
    return _schema_cache[key]

def get_render_ui_schema() -> dict[str, Any]:
    """Get the master render_ui tool schema."""
    return load_schema(SCHEMA_DIR / "render_ui.schema.json")

def load_component_schema(component_name: str) -> dict[str, Any]:
    """Get the specific schema for a catalog component by name."""
    filename = ""
    if component_name == "InfoCard": filename = "info_card.schema.json"
    elif component_name == "WeatherCard": filename = "weather_card.schema.json"
    elif component_name == "DeviceTile": filename = "device_tile.schema.json"
    elif component_name == "MediaPlayer": filename = "media_player.schema.json"
    elif component_name == "MetricChart": filename = "metric_chart.schema.json"
    elif component_name == "ListView": filename = "list_view.schema.json"
    elif component_name == "Row": filename = "row.schema.json"
    elif component_name == "Column": filename = "column.schema.json"
    elif component_name == "Section": filename = "section.schema.json"
    elif component_name == "ConfirmDialog": filename = "confirm_dialog.schema.json"
    elif component_name == "TextInput": filename = "text_input.schema.json"
    elif component_name == "Slider": filename = "slider.schema.json"
    elif component_name == "Toggle": filename = "toggle.schema.json"
    elif component_name == "EmailDashboard": filename = "email_dashboard.schema.json"
    elif component_name == "MapNavigation": filename = "map_navigation.schema.json"
    else:
        raise ValueError(f"Unknown component: {component_name}")
        
    return load_schema(COMPONENTS_DIR / filename)
