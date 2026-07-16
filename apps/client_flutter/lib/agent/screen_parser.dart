/// Screen-Parser — tiered screen understanding service.
///
/// Three-tier waterfall architecture for extracting structured UI JSON:
///   Tier 1 (< 1ms)     — Flutter Semantics tree (own app only)
///   Tier 2 (~10-50ms)  — Platform Accessibility APIs (any app)
///   Tier 3 (~600-800ms)— OmniParser vision model (opaque UIs, needs GPU)
///
/// Usage:
///   final parser = ref.read(screenParserProvider);
///   final structure = await parser.parseCurrentScreen();
///   final json = structure?.toCompactJson(); // 1-5KB vs 500KB-2MB screenshot
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screen_structure.dart';
import 'parsers/flutter_semantics_parser.dart';
import 'parsers/platform_a11y_parser.dart';
import 'parsers/omniparser_bridge.dart';

/// Parse mode determines which tiers to attempt.
enum ScreenParserMode {
  /// Auto: try Tier 1 → 2 → 3 in order.
  auto,

  /// Flutter semantics only (Tier 1).
  flutter,

  /// Platform accessibility API only (Tier 2).
  platform,

  /// OmniParser only (Tier 3).
  omniparser,
}

/// Riverpod provider for ScreenParser.
final screenParserProvider = Provider<ScreenParser>((ref) {
  return ScreenParser();
});

/// Main Screen-Parser service: orchestrates the three-tier waterfall.
class ScreenParser {
  final FlutterSemanticsParser _flutterParser = FlutterSemanticsParser();
  final PlatformA11yParser _platformParser = PlatformA11yParser();
  final OmniParserBridge _omniParser = OmniParserBridge();

  /// Configure OmniParser endpoint.
  void setOmniParserEndpoint(String endpoint) {
    // Create a new instance with the custom endpoint
    _omniParserOverride = OmniParserBridge(endpoint: endpoint);
  }

  OmniParserBridge? _omniParserOverride;
  OmniParserBridge get _activeOmniParser => _omniParserOverride ?? _omniParser;

  /// Parse the current screen using the tiered waterfall.
  ///
  /// [mode] selects which tiers to try (default: auto).
  /// [windowTitle] filters to a specific window (Tier 2 only).
  /// [maxDepth] limits the UI tree depth (default: 10).
  /// [interactiveOnly] filters to only interactive elements.
  /// [screenshotPath] path to screenshot for OmniParser (Tier 3).
  Future<ScreenStructure?> parseCurrentScreen({
    ScreenParserMode mode = ScreenParserMode.auto,
    String? windowTitle,
    int maxDepth = 10,
    bool interactiveOnly = false,
    String? screenshotPath,
  }) async {
    switch (mode) {
      case ScreenParserMode.flutter:
        return _tryTier1(maxDepth: maxDepth, interactiveOnly: interactiveOnly);

      case ScreenParserMode.platform:
        return _tryTier2(windowTitle: windowTitle, maxDepth: maxDepth);

      case ScreenParserMode.omniparser:
        return _tryTier3(screenshotPath: screenshotPath);

      case ScreenParserMode.auto:
        // Waterfall: Tier 1 → Tier 2 → Tier 3
        debugPrint('[ScreenParser] Starting auto parse...');

        // Tier 1: Flutter semantics (fastest, own app only)
        final t1 = _tryTier1(maxDepth: maxDepth, interactiveOnly: interactiveOnly);
        if (t1 != null) {
          debugPrint('[ScreenParser] Tier 1 (Flutter Semantics) succeeded in ${t1.latencyMs}ms');
          return t1;
        }

        // Tier 2: Platform accessibility API
        if (!kIsWeb) {
          final t2 = await _tryTier2(windowTitle: windowTitle, maxDepth: maxDepth);
          if (t2 != null) {
            debugPrint('[ScreenParser] Tier 2 (Platform A11y) succeeded in ${t2.latencyMs}ms');
            return t2;
          }
        }

        // Tier 3: OmniParser (needs screenshot + GPU)
        if (screenshotPath != null) {
          final t3 = await _tryTier3(screenshotPath: screenshotPath);
          if (t3 != null) {
            debugPrint('[ScreenParser] Tier 3 (OmniParser) succeeded in ${t3.latencyMs}ms');
            return t3;
          }
        }

        debugPrint('[ScreenParser] All tiers failed');
        return null;
    }
  }

  /// Tier 1: Flutter Semantics tree (synchronous, <1ms).
  ScreenStructure? _tryTier1({
    int maxDepth = 10,
    bool interactiveOnly = false,
  }) {
    try {
      return _flutterParser.parse(
        maxDepth: maxDepth,
        interactiveOnly: interactiveOnly,
      );
    } catch (e) {
      debugPrint('[ScreenParser] Tier 1 error: $e');
      return null;
    }
  }

  /// Tier 2: Platform Accessibility API (async, ~10-50ms).
  Future<ScreenStructure?> _tryTier2({
    String? windowTitle,
    int maxDepth = 10,
  }) async {
    try {
      return await _platformParser.parse(
        windowTitle: windowTitle,
        maxDepth: maxDepth,
      );
    } catch (e) {
      debugPrint('[ScreenParser] Tier 2 error: $e');
      return null;
    }
  }

  /// Tier 3: OmniParser vision model (async, ~600-800ms, needs GPU).
  Future<ScreenStructure?> _tryTier3({String? screenshotPath}) async {
    try {
      // Check availability
      final available = await _activeOmniParser.isAvailable();
      if (!available) {
        debugPrint('[ScreenParser] Tier 3: OmniParser not available');
        return null;
      }

      if (screenshotPath != null) {
        return await _activeOmniParser.parseFile(screenshotPath);
      }

      return null;
    } catch (e) {
      debugPrint('[ScreenParser] Tier 3 error: $e');
      return null;
    }
  }

  /// Quick check: is OmniParser service running?
  Future<bool> isOmniParserAvailable() => _activeOmniParser.isAvailable();
}
