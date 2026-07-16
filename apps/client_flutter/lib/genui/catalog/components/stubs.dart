import 'package:flutter/material.dart';
import '../catalog_registry.dart';

class StubComponent extends StatelessWidget {
  final String name;
  const StubComponent(this.name, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.grey.withAlpha(50),
      child: Text('Stub: $name', style: const TextStyle(color: Colors.grey)),
    );
  }
}

// Minimal stubs for remaining components to satisfy registry
class WeatherCardComponent {
  static void register(CatalogRegistry registry) {
    registry.register('WeatherCard', ({required props, required children, bindings, events, theme, required context, onEvent}) => const StubComponent('WeatherCard'));
  }
}

class MetricChartComponent {
  static void register(CatalogRegistry registry) {
    registry.register('MetricChart', ({required props, required children, bindings, events, theme, required context, onEvent}) => const StubComponent('MetricChart'));
  }
}

class SectionComponent {
  static void register(CatalogRegistry registry) {
    registry.register('Section', ({required props, required children, bindings, events, theme, required context, onEvent}) => const StubComponent('Section'));
  }
}
class ConfirmDialogComponent {
  static void register(CatalogRegistry registry) {
    registry.register('ConfirmDialog', ({required props, required children, bindings, events, theme, required context, onEvent}) => const StubComponent('ConfirmDialog'));
  }
}
class TextInputComponent {
  static void register(CatalogRegistry registry) {
    registry.register('TextInput', ({required props, required children, bindings, events, theme, required context, onEvent}) => const StubComponent('TextInput'));
  }
}
class SliderComponent {
  static void register(CatalogRegistry registry) {
    registry.register('Slider', ({required props, required children, bindings, events, theme, required context, onEvent}) => const StubComponent('Slider'));
  }
}
class ToggleComponent {
  static void register(CatalogRegistry registry) {
    registry.register('Toggle', ({required props, required children, bindings, events, theme, required context, onEvent}) => const StubComponent('Toggle'));
  }
}
