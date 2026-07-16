import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_steward/genui/render_backend/render_backend.dart';
import 'package:home_steward/genui/surface/ui_node.dart';
import 'package:home_steward/config/capability_registry.dart';

void main() {
  testWidgets('RfwRenderBackend renders daemon RFW widgets', (WidgetTester tester) async {
    final rfwWidgets = '''
      import core;
      import material;
      widget DaemonSensorCard = Container(
        child: Center(
          child: Text(text: data.title),
        ),
      );
    ''';
    final agent = A2AAgentEntry(
      id: 'agent1',
      name: 'Mock Agent',
      description: 'Desc',
      version: '1.0.0',
      endpoint: 'http://localhost:9000',
      skills: [],
      auth: 'none',
      rfwWidgets: rfwWidgets,
    );

    final backend = RfwRenderBackend([agent]);
    final node = UiNode(
      component: 'DaemonSensorCard',
      props: {'title': 'Hello from Daemon!'},
      children: [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => backend.render(node, context),
          ),
        ),
      ),
    );

    await tester.pump();
    expect(find.text('Hello from Daemon!'), findsOneWidget);
  });
}
