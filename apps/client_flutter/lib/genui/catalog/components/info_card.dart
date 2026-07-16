import 'package:flutter/material.dart';
import '../catalog_registry.dart';
import '../theme_tokens.dart';

class InfoCardComponent extends StatelessWidget {
  final String title;
  final String body;
  final String? icon;
  final ThemeTokens theme;
  final Map<String, String>? events;
  final EventCallback? onEvent;

  const InfoCardComponent({
    super.key,
    required this.title,
    required this.body,
    this.icon,
    required this.theme,
    this.events,
    this.onEvent,
  });

  static void register(CatalogRegistry registry) {
    registry.register('InfoCard', ({
      required props,
      required children,
      bindings,
      events,
      theme,
      required context,
      onEvent,
    }) {
      return InfoCardComponent(
        title: props['title'] ?? '',
        body: props['body'] ?? '',
        icon: props['icon'],
        theme: theme ?? ThemeTokens.minimal,
        events: events,
        onEvent: onEvent,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (onEvent != null) {
          final action = events?['onTap'] ?? 'info.select';
          onEvent!(action, {
            'title': title,
            'body': body,
          });
        }
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: EdgeInsets.only(bottom: theme.baseSpacing / 2),
          padding: EdgeInsets.all(theme.baseSpacing),
          decoration: BoxDecoration(
            color: theme.surface,
            borderRadius: BorderRadius.circular(theme.cardRadius),
            border: Border.all(color: theme.accent.withAlpha(30)),
            boxShadow: [
              BoxShadow(
                color: theme.accent.withAlpha(5),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  if (icon != null) ...[
                    Icon(Icons.info_outline, color: theme.accent), // Mock icon
                    SizedBox(width: theme.baseSpacing / 2),
                  ],
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: theme.onSurface,
                        fontSize: 18 * theme.fontScale,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: theme.baseSpacing / 2),
              Text(
                body,
                style: TextStyle(
                  color: theme.onSurface.withAlpha(200),
                  fontSize: 14 * theme.fontScale,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
