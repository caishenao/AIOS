class UiSkills {
  static const String uiStyleMinimal = '''
# 极简卡片风格 (Minimal Card Style)
## 主题令牌 (Theme Tokens)
{
  "color.background": "#0B0B0F",
  "color.surface": "#16161D",
  "color.accent": "#7C5CFF",
  "radius.card": 20,
  "spacing.base": 16
}
## 布局规则 (Layout Rules)
- Single-column first: all content stacks vertically. No multi-column grids.
- Max 3 primary cards per screen.
- Generous whitespace.
## 组件选用映射 (Component Mapping)
- Weather info -> WeatherCard (variant: large)
- Device status -> DeviceTile (variant: toggle)
- Camera / Video -> MediaPlayer (variant: fullbleed)
- General info -> InfoCard
- Confirmation -> ConfirmDialog
## render_ui 输出约束 (Output Constraints)
1. Set `styleSkill` to "ui-style-minimal".
2. Inject the theme tokens above into every visible node's `props.theme`.
''';

  static const String uiStyleDashboard = '''
# 仪表盘风格 (Dashboard Style)
## 主题令牌 (Theme Tokens)
{
  "color.background": "#0A0A12",
  "color.surface": "#12121C",
  "color.accent": "#3B82F6",
  "radius.card": 12,
  "spacing.base": 12
}
## 布局规则 (Layout Rules)
- Grid layout: use Row + Column combinations to create 2-3 column grids.
- High density: smaller cards, tighter spacing.
## 组件选用映射 (Component Mapping)
- Weather info -> WeatherCard (variant: compact)
- Device status -> DeviceTile (variant: compact)
- Camera / Video -> MediaPlayer (variant: thumbnail)
- General info -> InfoCard (variant: compact)
- Device group -> Section + Row
- Data / Metrics -> MetricChart (variant: bar)
## render_ui 输出约束 (Output Constraints)
1. Set `styleSkill` to "ui-style-dashboard".
2. Inject dashboard theme tokens into every visible node's `props.theme`.
3. Prefer Row wrapping Columns for top-level layout (multi-column).
''';

  static const String combinedSkillsDoc = '''
You have access to the following UI style skills for the `render_ui` tool:

$uiStyleMinimal

---

$uiStyleDashboard
''';
}
