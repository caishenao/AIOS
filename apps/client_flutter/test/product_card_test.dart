import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_steward/genui/surface/ui_node.dart';
import 'package:home_steward/genui/surface/genui_surface.dart';
import 'package:home_steward/genui/catalog/catalog_registry.dart';
import 'package:home_steward/genui/catalog/components/product_card.dart';

void main() {
  testWidgets('Test ProductCardComponent rendering and action triggers', (WidgetTester tester) async {
    // Set a taller viewport to prevent AspectRatio scaling from causing vertical overflow
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final registry = CatalogRegistry.instance;
    ProductCardComponent.register(registry);

    final uiNode = UiNode(
      component: 'ProductCard',
      props: {
        'title': '智能音箱',
        'price': 299.0,
        'description': '高品质音质，内置AI智能助手。',
        'imageUrl': 'https://example.com/speaker.jpg',
        'buyUrl': 'https://item.jd.com/123456.html',
        'buttonText': '去京东购买',
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

    // 1. Verify component displays title, price, description and buttonText
    expect(find.text('智能音箱'), findsOneWidget);
    expect(find.text('¥299.00'), findsOneWidget);
    expect(find.text('高品质音质，内置AI智能助手。'), findsOneWidget);
    expect(find.text('去京东购买'), findsOneWidget);

    // 2. Verify AI consultation trigger button works
    final consultBtn = find.text('咨询 AI');
    expect(consultBtn, findsOneWidget);
    await tester.tap(consultBtn);
    await tester.pump();

    expect(triggeredAction, 'product.consult');
    expect(triggeredPayload?['productTitle'], '智能音箱');
    expect(triggeredPayload?['price'], 299.0);
  });
}
