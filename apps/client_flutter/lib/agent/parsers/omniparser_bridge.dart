/// OmniParser Bridge — Tier 3 Screen-Parser.
///
/// Connects to a locally-running OmniParser service (Microsoft's open-source
/// screen parsing model: YOLOv8 detection + Florence-2 captioning) to
/// extract UI structure from screenshots.
///
/// Requires:
/// - NVIDIA GPU with 4GB+ VRAM
/// - OmniParser service running at configured endpoint
/// - Screenshot file path or base64 data
library;

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../screen_structure.dart';

class OmniParserBridge {
  /// Default OmniParser service endpoint.
  static const String defaultEndpoint = 'http://localhost:8200';

  final String endpoint;

  OmniParserBridge({this.endpoint = defaultEndpoint});

  /// Check if OmniParser service is available.
  Future<bool> isAvailable() async {
    try {
      final response = await http
          .get(Uri.parse('$endpoint/health'))
          .timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Parse a screenshot file and return structured UI elements.
  ///
  /// [imagePath] is the absolute path to a screenshot PNG/JPG file.
  Future<ScreenStructure?> parseFile(String imagePath) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) {
        debugPrint('OmniParser: Screenshot file not found: $imagePath');
        return null;
      }

      final bytes = await file.readAsBytes();
      final base64Data = base64Encode(bytes);
      return parseBase64(base64Data, imagePath: imagePath);
    } catch (e) {
      debugPrint('OmniParser: Error reading file: $e');
      return null;
    }
  }

  /// Parse a base64-encoded screenshot.
  Future<ScreenStructure?> parseBase64(
    String base64Data, {
    String? imagePath,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      final response = await http
          .post(
            Uri.parse('$endpoint/parse'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'image': base64Data,
              'format': 'structured',
            }),
          )
          .timeout(const Duration(seconds: 30));

      stopwatch.stop();

      if (response.statusCode != 200) {
        debugPrint('OmniParser: API error ${response.statusCode}: ${response.body}');
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return _convertResponse(data, stopwatch.elapsedMilliseconds);
    } catch (e) {
      stopwatch.stop();
      debugPrint('OmniParser: Request error: $e');
      return null;
    }
  }

  /// Convert OmniParser API response to our unified ScreenStructure format.
  ScreenStructure _convertResponse(Map<String, dynamic> data, int latencyMs) {
    final elements = data['elements'] as List<dynamic>? ?? [];
    final imageWidth = (data['width'] as num?)?.toDouble() ?? 1920.0;
    final imageHeight = (data['height'] as num?)?.toDouble() ?? 1080.0;

    // OmniParser returns a flat list of elements with bounding boxes.
    // We group them into a tree structure based on spatial containment.
    final nodes = elements.map((e) {
      final elem = e as Map<String, dynamic>;
      final bbox = elem['bbox'] as List<dynamic>? ?? [0, 0, 0, 0];

      // OmniParser bbox format: [x1, y1, x2, y2] (normalized 0-1 or pixels)
      double x1 = (bbox[0] as num).toDouble();
      double y1 = (bbox[1] as num).toDouble();
      double x2 = (bbox[2] as num).toDouble();
      double y2 = (bbox[3] as num).toDouble();

      // If normalized (0-1 range), convert to pixels
      if (x2 <= 1.0 && y2 <= 1.0) {
        x1 *= imageWidth;
        y1 *= imageHeight;
        x2 *= imageWidth;
        y2 *= imageHeight;
      }

      final label = elem['label'] as String? ??
          elem['caption'] as String? ??
          elem['text'] as String?;
      final type = elem['type'] as String? ?? 'element';

      return ScreenNode(
        role: _mapOmniType(type),
        label: label,
        bounds: BoundingBox(
          left: x1,
          top: y1,
          width: x2 - x1,
          height: y2 - y1,
        ),
        actions: _inferActions(type),
        interactive: _isInteractive(type),
      );
    }).toList();

    // Build a simple tree: all elements as children of a root container
    final root = ScreenNode(
      role: 'screen',
      label: 'OmniParser detected elements',
      bounds: BoundingBox(left: 0, top: 0, width: imageWidth, height: imageHeight),
      children: nodes,
    );

    return ScreenStructure(
      source: 'omniparser',
      latencyMs: latencyMs,
      rootNode: root,
      meta: ScreenMeta(
        screenWidth: imageWidth,
        screenHeight: imageHeight,
        platform: _getCurrentPlatform(),
      ),
      timestamp: DateTime.now(),
    );
  }

  /// Map OmniParser element types to our role vocabulary.
  String _mapOmniType(String type) {
    switch (type.toLowerCase()) {
      case 'button':
        return 'button';
      case 'input':
      case 'textbox':
      case 'textarea':
      case 'edit':
        return 'input';
      case 'text':
      case 'label':
      case 'static':
        return 'text';
      case 'image':
      case 'icon':
        return 'image';
      case 'checkbox':
        return 'checkbox';
      case 'radio':
        return 'radio';
      case 'dropdown':
      case 'combobox':
      case 'select':
        return 'dropdown';
      case 'slider':
      case 'scrollbar':
        return 'slider';
      case 'link':
      case 'hyperlink':
        return 'link';
      case 'menu':
      case 'menuitem':
        return 'menu';
      case 'tab':
        return 'tab';
      case 'list':
        return 'list';
      case 'table':
        return 'table';
      default:
        return 'element';
    }
  }

  /// Infer possible actions from element type.
  List<String> _inferActions(String type) {
    switch (type.toLowerCase()) {
      case 'button':
      case 'link':
      case 'hyperlink':
      case 'checkbox':
      case 'radio':
      case 'tab':
      case 'menuitem':
        return ['tap'];
      case 'input':
      case 'textbox':
      case 'textarea':
      case 'edit':
        return ['tap', 'set_text'];
      case 'slider':
      case 'scrollbar':
        return ['increase', 'decrease'];
      case 'dropdown':
      case 'combobox':
      case 'select':
        return ['tap'];
      default:
        return [];
    }
  }

  /// Check if element type is interactive.
  bool _isInteractive(String type) {
    return ['button', 'input', 'textbox', 'textarea', 'edit', 'checkbox',
            'radio', 'dropdown', 'combobox', 'select', 'slider', 'scrollbar',
            'link', 'hyperlink', 'tab', 'menuitem', 'menu'].contains(type.toLowerCase());
  }

  String _getCurrentPlatform() {
    if (kIsWeb) return 'web';
    if (Platform.isWindows) return 'windows';
    if (Platform.isAndroid) return 'android';
    if (Platform.isLinux) return 'linux';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isIOS) return 'ios';
    return 'unknown';
  }
}
