import 'package:flutter/material.dart';

import '../../surface/ui_node.dart';
import '../catalog_registry.dart';
import '../theme_tokens.dart';

/// Displays weather information with location, temperature, condition,
/// and an optional horizontal hourly forecast row.
///
/// Props:
/// - `location` (String): Location name.
/// - `temp` (num): Current temperature value.
/// - `tempUnit` (String): Temperature unit, default `"°C"`.
/// - `condition` (String): Weather condition text (e.g. "Sunny", "Rainy").
/// - `conditionIcon` (String?): Icon key for the condition.
/// - `hourly` (List<Map>): Hourly forecast entries with `time`, `temp`, `icon`.
/// - `variant` (String?): `"large"` for the full-size card, `"compact"` for inline.
class CatalogWeatherCard extends StatelessWidget {
  final Map<String, dynamic> props;
  final List<UiNode> children;
  final ThemeTokens? theme;
  final Map<String, String>? events;
  final EventCallback? onEvent;

  const CatalogWeatherCard({
    super.key,
    required this.props,
    this.children = const [],
    this.theme,
    this.events,
    this.onEvent,
  });

  /// Registers this component in the [CatalogRegistry].
  static void register(CatalogRegistry registry) {
    registry.register('WeatherCard', ({
      required Map<String, dynamic> props,
      required List<UiNode> children,
      Map<String, dynamic>? bindings,
      Map<String, String>? events,
      ThemeTokens? theme,
      required BuildContext context,
      EventCallback? onEvent,
    }) {
      return CatalogWeatherCard(
        props: props,
        children: children,
        theme: theme,
        events: events,
        onEvent: onEvent,
      );
    });
  }

  IconData _conditionIcon(String? condition) {
    switch (condition?.toLowerCase()) {
      case 'sunny':
      case 'clear':
        return Icons.wb_sunny;
      case 'cloudy':
      case 'overcast':
        return Icons.cloud;
      case 'rainy':
      case 'rain':
        return Icons.water_drop;
      case 'snowy':
      case 'snow':
        return Icons.ac_unit;
      case 'stormy':
      case 'thunderstorm':
        return Icons.thunderstorm;
      case 'windy':
        return Icons.air;
      case 'foggy':
      case 'fog':
        return Icons.foggy;
      case 'partly_cloudy':
        return Icons.cloud_queue;
      default:
        return Icons.thermostat;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = theme ?? ThemeTokens.minimal;
    final location = props['location'] as String? ?? 'Unknown';
    final temp = props['temp'];
    final tempUnit = props['tempUnit'] as String? ?? '°C';
    final condition = props['condition'] as String? ?? '';
    final hourly = (props['hourly'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    final variant = props['variant'] as String? ?? 'large';
    final isCompact = variant == 'compact';

    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(vertical: t.baseSpacing / 2),
      padding: EdgeInsets.all(t.baseSpacing * 1.25),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(t.cardRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            t.accent.withAlpha(60),
            t.surface,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: t.accent.withAlpha(25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Location
          Row(
            children: [
              Icon(Icons.location_on, color: t.accent, size: 16 * t.fontScale),
              SizedBox(width: t.baseSpacing / 4),
              Text(
                location,
                style: TextStyle(
                  color: t.onSurface.withAlpha(180),
                  fontSize: 14 * t.fontScale,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: t.baseSpacing),

          // Temperature + condition
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${temp ?? '--'}$tempUnit',
                      style: TextStyle(
                        color: t.onSurface,
                        fontSize: isCompact ? 36 * t.fontScale : 52 * t.fontScale,
                        fontWeight: FontWeight.w300,
                        height: 1.1,
                      ),
                    ),
                    SizedBox(height: t.baseSpacing / 4),
                    Text(
                      condition,
                      style: TextStyle(
                        color: t.onSurface.withAlpha(160),
                        fontSize: 16 * t.fontScale,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                _conditionIcon(condition),
                color: t.accent,
                size: isCompact ? 40 : 56,
              ),
            ],
          ),

          // Hourly forecast
          if (hourly.isNotEmpty) ...[
            SizedBox(height: t.baseSpacing),
            Divider(color: t.onSurface.withAlpha(30), height: 1),
            SizedBox(height: t.baseSpacing),
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: hourly.length,
                separatorBuilder: (_, __) => SizedBox(width: t.baseSpacing),
                itemBuilder: (context, index) {
                  final entry = hourly[index];
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        entry['time']?.toString() ?? '',
                        style: TextStyle(
                          color: t.onSurface.withAlpha(120),
                          fontSize: 12 * t.fontScale,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Icon(
                        _conditionIcon(entry['icon'] as String?),
                        color: t.accent,
                        size: 22,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${entry['temp'] ?? '--'}°',
                        style: TextStyle(
                          color: t.onSurface,
                          fontSize: 13 * t.fontScale,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
