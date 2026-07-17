import 'package:flutter/material.dart';
import '../catalog_registry.dart';
import '../theme_tokens.dart';

class ConfirmDialogComponent extends StatelessWidget {
  final String title;
  final String message;
  final String confirmAction;
  final String cancelAction;
  final String confirmText;
  final String cancelText;
  final Map<String, dynamic> payload;
  final ThemeTokens theme;
  final EventCallback? onEvent;

  const ConfirmDialogComponent({
    super.key,
    required this.title,
    required this.message,
    required this.confirmAction,
    required this.cancelAction,
    required this.confirmText,
    required this.cancelText,
    required this.payload,
    required this.theme,
    this.onEvent,
  });

  static void register(CatalogRegistry registry) {
    registry.register('ConfirmDialog', ({
      required props,
      required children,
      bindings,
      events,
      theme,
      required context,
      onEvent,
    }) {
      return ConfirmDialogComponent(
        title: props['title'] as String? ?? '安全确认',
        message: props['message'] as String? ?? '您确定要执行此操作吗？',
        confirmAction: props['confirmAction'] as String? ?? 'confirm',
        cancelAction: props['cancelAction'] as String? ?? 'cancel',
        confirmText: props['confirmText'] as String? ?? '确定',
        cancelText: props['cancelText'] as String? ?? '取消',
        payload: props['payload'] as Map<String, dynamic>? ?? const {},
        theme: theme ?? ThemeTokens.minimal,
        onEvent: onEvent,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final isDanger = confirmAction.toLowerCase().contains('delete') || 
                     confirmAction.toLowerCase().contains('remove') ||
                     confirmAction.toLowerCase().contains('lock') ||
                     confirmAction.toLowerCase().contains('close') ||
                     message.contains('删') || message.contains('锁') || message.contains('关');

    final primaryBtnColor = isDanger ? Colors.redAccent : t.accent;
    final primaryBtnTextColor = isDanger ? Colors.white : Colors.black;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(t.baseSpacing),
      decoration: BoxDecoration(
        color: t.surface.withAlpha(220),
        borderRadius: BorderRadius.circular(t.cardRadius),
        border: Border.all(
          color: isDanger ? Colors.redAccent.withAlpha(120) : t.accent.withAlpha(120),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDanger ? Colors.redAccent.withAlpha(20) : t.accent.withAlpha(20),
            blurRadius: 16,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDanger ? Colors.redAccent.withAlpha(24) : t.accent.withAlpha(24),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isDanger ? Icons.gpp_maybe_outlined : Icons.verified_user_outlined,
                  color: isDanger ? Colors.redAccent : t.accent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: t.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 16 * t.fontScale,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: t.baseSpacing * 0.8),
          Text(
            message,
            style: TextStyle(
              color: t.onSurface.withAlpha(180),
              fontSize: 13 * t.fontScale,
              height: 1.5,
            ),
          ),
          SizedBox(height: t.baseSpacing),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: t.onSurface.withAlpha(200),
                  side: BorderSide(color: t.onSurface.withAlpha(40)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onPressed: () {
                  onEvent?.call(cancelAction, {});
                },
                child: Text(cancelText, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBtnColor,
                  foregroundColor: primaryBtnTextColor,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                onPressed: () {
                  onEvent?.call(confirmAction, payload);
                },
                child: Text(confirmText, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
