import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_steward/genui/surface/ui_node.dart';
import 'package:home_steward/genui/surface/genui_surface.dart';
import 'package:home_steward/genui/catalog/catalog_registry.dart';
import 'package:home_steward/genui/catalog/components/confirm_dialog.dart';

void main() {
  testWidgets('Test ConfirmDialogComponent interaction', (WidgetTester tester) async {
    final registry = CatalogRegistry.instance;
    ConfirmDialogComponent.register(registry);

    final uiNode = UiNode(
      component: 'ConfirmDialog',
      props: {
        'title': '高危操作确认',
        'message': '确定要开启安防报警器吗？',
        'confirmAction': 'alarm.enable',
        'cancelAction': 'alarm.cancel',
        'confirmText': '确认启用',
        'cancelText': '别动它',
        'payload': {'level': 'high'},
      },
    );

    String? triggeredAction;
    Map<String, dynamic>? triggeredPayload;

    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: GenUiSurface(
            root: uiNode,
            onEvent: (action, payload) {
              triggeredAction = action;
              triggeredPayload = payload;
            },
          ),
        ),
      ),
    ));

    // Verify title and message
    expect(find.text('高危操作确认'), findsOneWidget);
    expect(find.text('确定要开启安防报警器吗？'), findsOneWidget);
    expect(find.text('确认启用'), findsOneWidget);
    expect(find.text('别动它'), findsOneWidget);

    // Test Confirm action
    await tester.tap(find.text('确认启用'));
    await tester.pump();
    expect(triggeredAction, 'alarm.enable');
    expect(triggeredPayload?['level'], 'high');

    // Reset variables
    triggeredAction = null;
    triggeredPayload = null;

    // Test Cancel action
    await tester.tap(find.text('别动它'));
    await tester.pump();
    expect(triggeredAction, 'alarm.cancel');
  });
}
