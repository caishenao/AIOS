import 'package:flutter/material.dart';
import '../catalog_registry.dart';
import '../theme_tokens.dart';

class DeviceTileComponent extends StatelessWidget {
  final String name;
  final bool state;
  final String type;
  final bool controllable;
  final String? onToggleEvent;
  final EventCallback? onEvent;
  final ThemeTokens theme;

  const DeviceTileComponent({
    super.key,
    required this.name,
    required this.state,
    required this.type,
    required this.controllable,
    this.onToggleEvent,
    this.onEvent,
    required this.theme,
  });

  static void register(CatalogRegistry registry) {
    registry.register('DeviceTile', ({
      required props,
      required children,
      bindings,
      events,
      theme,
      required context,
      onEvent,
    }) {
      bool parseBool(dynamic value) {
        if (value == null) return false;
        if (value is bool) return value;
        if (value is String) {
          final s = value.toLowerCase();
          return s == 'true' || s == '1' || s == 'on' || s == '开启' || s == '开';
        }
        if (value is num) return value > 0;
        return false;
      }

      return DeviceTileComponent(
        name: props['name']?.toString() ?? 'Unknown',
        state: parseBool(props['state']),
        type: props['type']?.toString() ?? 'switch',
        controllable: parseBool(props['controllable']),
        onToggleEvent: events?['onToggle'],
        onEvent: onEvent,
        theme: theme ?? ThemeTokens.minimal,
      );
    });
  }

  IconData _getIcon() {
    switch (type) {
      case 'light': return Icons.lightbulb;
      case 'climate': return Icons.thermostat;
      case 'lock': return Icons.lock;
      case 'cover': return Icons.blinds;
      default: return Icons.power;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: theme.baseSpacing / 2),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(theme.cardRadius),
      ),
      child: ListTile(
        leading: Icon(
          _getIcon(),
          color: state ? theme.accent : theme.onSurface.withAlpha(100),
        ),
        title: Text(
          name,
          style: TextStyle(
            color: theme.onSurface,
            fontSize: 16 * theme.fontScale,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: controllable
            ? Switch(
                value: state,
                activeColor: theme.accent,
                onChanged: (val) {
                  if (onToggleEvent != null && onEvent != null) {
                    onEvent!(onToggleEvent!, {'state': val});
                  }
                },
              )
            : Text(state ? 'ON' : 'OFF', style: TextStyle(color: theme.onSurface)),
      ),
    );
  }
}
