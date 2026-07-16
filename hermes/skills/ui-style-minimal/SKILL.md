---
name: ui-style-minimal
description: |
  极简卡片界面风格。当需要向用户展示天气、设备状态、媒体、信息或确认卡片时，
  使用本风格渲染——强调留白、单列、大字号、低信息密度。
  Use when rendering weather, device, media, info, or confirmation UIs in a
  minimal aesthetic. Emphasizes whitespace, single-column layout, large type,
  and low information density.
---

# 极简卡片风格 (Minimal Card Style)

## 主题令牌（Theme Tokens）

These tokens are injected into every component's `props.theme` when this skill
is active. The client uses them for all color, spacing, and typography decisions.

```json
{
  "color.background": "#0B0B0F",
  "color.surface": "#16161D",
  "color.accent": "#7C5CFF",
  "color.onSurface": "#E8E8ED",
  "color.onAccent": "#FFFFFF",
  "color.success": "#4ADE80",
  "color.warning": "#FBBF24",
  "color.danger": "#F87171",
  "radius.card": 20,
  "spacing.base": 16,
  "font.scale": 1.15
}
```

## 布局规则 (Layout Rules)

- **Single-column first**: all content stacks vertically. No multi-column grids.
- **Max 3 primary cards per screen**: if more content is needed, use a scrollable
  `ListView` but keep the visible area to ≤3 cards.
- **Generous whitespace**: spacing between cards = `spacing.base * 1.5`.
- **Unified border radius**: all cards use `radius.card` (20dp).
- **Full-bleed media**: `MediaPlayer` variants use edge-to-edge rendering with
  no horizontal padding.

## 组件选用映射 (Component Mapping)

| User Intent | Component | Variant | Notes |
|---|---|---|---|
| Weather info | `WeatherCard` | `large` | Full-width, prominent temperature |
| Device status | `DeviceTile` | `toggle` | Large toggle switch, clear state |
| Camera / Video | `MediaPlayer` | `fullbleed` | Edge-to-edge, no padding |
| General info | `InfoCard` | (default) | Title + body, accent left border |
| List of items | `ListView` + children | `vertical` | Single column, spaced |
| Confirmation | `ConfirmDialog` | (default) | Modal overlay, danger = red |
| Data / Metrics | `MetricChart` | `line` | Minimal axis, accent color |

## render_ui 输出约束 (Output Constraints)

When calling `render_ui` with this skill active:

1. Set `styleSkill` to `"ui-style-minimal"`.
2. Inject the theme tokens above into every visible node's `props.theme`.
3. Prefer `Column` over `Row` for top-level layout.
4. Use `Section` with descriptive titles to group related content.
5. Never nest more than 3 levels deep.
6. For device controls, always include `events.onToggle` or `events.onChange`
   so the user can interact directly.

## 示例 (Examples)

### Weather Response

```json
{
  "surfaceId": "main",
  "styleSkill": "ui-style-minimal",
  "root": {
    "component": "Column",
    "props": {
      "spacing": 24,
      "theme": { "color.background": "#0B0B0F" }
    },
    "children": [
      {
        "component": "WeatherCard",
        "props": {
          "location": "上海",
          "temp": 28,
          "condition": "晴",
          "hourly": [
            {"time": "14:00", "temp": 29, "condition": "晴"},
            {"time": "15:00", "temp": 28, "condition": "多云"},
            {"time": "16:00", "temp": 27, "condition": "多云"}
          ],
          "variant": "large",
          "theme": {
            "color.surface": "#16161D",
            "color.accent": "#7C5CFF",
            "radius.card": 20
          }
        }
      }
    ]
  }
}
```

### Device List Response

```json
{
  "surfaceId": "main",
  "styleSkill": "ui-style-minimal",
  "root": {
    "component": "Column",
    "props": { "spacing": 24 },
    "children": [
      {
        "component": "Section",
        "props": { "title": "客厅设备" },
        "children": [
          {
            "component": "DeviceTile",
            "props": {
              "name": "客厅灯",
              "state": true,
              "type": "light",
              "controllable": true,
              "theme": { "color.surface": "#16161D", "color.accent": "#7C5CFF" }
            },
            "events": { "onToggle": "device.toggle.light.living_room" }
          },
          {
            "component": "DeviceTile",
            "props": {
              "name": "空调",
              "state": false,
              "type": "climate",
              "controllable": true,
              "theme": { "color.surface": "#16161D", "color.accent": "#7C5CFF" }
            },
            "events": { "onToggle": "device.toggle.climate.living_room" }
          }
        ]
      }
    ]
  }
}
```
