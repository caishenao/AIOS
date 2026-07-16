---
name: ui-style-dashboard
description: |
  仪表盘界面风格。当需要同时展示多项设备状态、数据指标或监控信息时使用本风格。
  强调信息密度、多列网格、紧凑布局。适合电脑和平板等大屏幕设备。
  Use when displaying multiple device statuses, metrics, or monitoring
  information simultaneously. Emphasizes information density, multi-column
  grids, and compact layout. Best for desktop and tablet screens.
---

# 仪表盘风格 (Dashboard Style)

## 主题令牌（Theme Tokens）

```json
{
  "color.background": "#0A0A12",
  "color.surface": "#12121C",
  "color.accent": "#3B82F6",
  "color.onSurface": "#D4D4DC",
  "color.onAccent": "#FFFFFF",
  "color.success": "#22C55E",
  "color.warning": "#EAB308",
  "color.danger": "#EF4444",
  "color.muted": "#6B7280",
  "radius.card": 12,
  "spacing.base": 12,
  "font.scale": 0.95
}
```

## 布局规则 (Layout Rules)

- **Grid layout**: use `Row` + `Column` combinations to create 2-3 column grids.
- **High density**: smaller cards, tighter spacing, more items visible at once.
- **Compact typography**: `font.scale` at 0.95 for denser text.
- **Section headers**: use `Section` with collapsible groups to organize content.
- **Scrollable regions**: `ListView` for long lists with compact item height.
- **Status-first**: device tiles show state prominently with colored indicators.

## 组件选用映射 (Component Mapping)

| User Intent | Component | Variant | Notes |
|---|---|---|---|
| Weather info | `WeatherCard` | `compact` | Smaller, fits in grid cell |
| Device status | `DeviceTile` | `compact` | Small tile, icon + state |
| Camera / Video | `MediaPlayer` | `thumbnail` | Small preview, tap to expand |
| General info | `InfoCard` | `compact` | Reduced padding |
| Device group | `Section` + `Row` | — | 2-3 tiles per row |
| Data / Metrics | `MetricChart` | `bar` | Compact with mini axes |
| Overview | `Row` of `Column`s | — | Multi-column dashboard |

## render_ui 输出约束 (Output Constraints)

1. Set `styleSkill` to `"ui-style-dashboard"`.
2. Inject dashboard theme tokens into every visible node's `props.theme`.
3. Prefer `Row` wrapping `Column`s for top-level layout (multi-column).
4. Group related devices into `Section`s with collapsible headers.
5. Use `MetricChart` for any numeric data with history.
6. Keep individual card content minimal — just key info + interaction.

## 示例 (Example)

### Multi-Device Dashboard

```json
{
  "surfaceId": "main",
  "styleSkill": "ui-style-dashboard",
  "root": {
    "component": "Column",
    "props": { "spacing": 12 },
    "children": [
      {
        "component": "Row",
        "props": { "spacing": 12 },
        "children": [
          {
            "component": "WeatherCard",
            "props": {
              "location": "上海",
              "temp": 28,
              "condition": "晴",
              "variant": "compact",
              "theme": { "color.surface": "#12121C", "radius.card": 12 }
            }
          },
          {
            "component": "MetricChart",
            "props": {
              "title": "室内温度",
              "series": [{"label": "温度", "data": [23, 24, 24, 25, 25, 24]}],
              "kind": "line",
              "theme": { "color.surface": "#12121C", "color.accent": "#3B82F6" }
            }
          }
        ]
      },
      {
        "component": "Section",
        "props": { "title": "客厅" },
        "children": [
          {
            "component": "Row",
            "props": { "spacing": 12 },
            "children": [
              {
                "component": "DeviceTile",
                "props": {
                  "name": "主灯", "state": true, "type": "light",
                  "controllable": true, "variant": "compact"
                },
                "events": { "onToggle": "device.toggle.light.main" }
              },
              {
                "component": "DeviceTile",
                "props": {
                  "name": "空调", "state": false, "type": "climate",
                  "controllable": true, "variant": "compact"
                },
                "events": { "onToggle": "device.toggle.climate.living" }
              },
              {
                "component": "DeviceTile",
                "props": {
                  "name": "窗帘", "state": true, "type": "cover",
                  "controllable": true, "variant": "compact"
                },
                "events": { "onToggle": "device.toggle.cover.living" }
              }
            ]
          }
        ]
      }
    ]
  }
}
```
