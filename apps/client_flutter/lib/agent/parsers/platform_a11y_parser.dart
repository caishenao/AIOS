/// Platform Accessibility Parser — Tier 2 Screen-Parser.
///
/// Uses OS-level accessibility APIs to extract UI structure from
/// ANY application on the system, not just Flutter.
///
/// - Windows: UI Automation (UIA) via PowerShell
/// - Android: uiautomator dump via adb
/// - Linux: AT-SPI2 via python3 pyatspi
library;

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../screen_structure.dart';

class PlatformA11yParser {
  /// Parse the current foreground window's UI tree via platform accessibility API.
  ///
  /// [windowTitle] optionally filters to a specific window (Windows only).
  /// [maxDepth] limits recursion depth.
  Future<ScreenStructure?> parse({
    String? windowTitle,
    int maxDepth = 10,
  }) async {
    if (kIsWeb) return null;

    final stopwatch = Stopwatch()..start();

    try {
      ScreenNode? root;
      ScreenMeta? meta;

      if (Platform.isWindows) {
        final result = await _parseWindows(windowTitle: windowTitle, maxDepth: maxDepth);
        root = result?.$1;
        meta = result?.$2;
      } else if (Platform.isAndroid) {
        final result = await _parseAndroid(maxDepth: maxDepth);
        root = result?.$1;
        meta = result?.$2;
      } else if (Platform.isLinux) {
        final result = await _parseLinux(windowTitle: windowTitle, maxDepth: maxDepth);
        root = result?.$1;
        meta = result?.$2;
      } else if (Platform.isMacOS) {
        final result = await _parseMacOS(windowTitle: windowTitle, maxDepth: maxDepth);
        root = result?.$1;
        meta = result?.$2;
      }

      stopwatch.stop();

      if (root == null || meta == null) return null;

      return ScreenStructure(
        source: 'platform_a11y',
        latencyMs: stopwatch.elapsedMilliseconds,
        rootNode: root,
        meta: meta,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      debugPrint('PlatformA11yParser error: $e');
      return null;
    }
  }

  // ─────────────────────────── WINDOWS (UI Automation) ───────────────────────

  Future<(ScreenNode, ScreenMeta)?> _parseWindows({
    String? windowTitle,
    int maxDepth = 10,
  }) async {
    // PowerShell script that uses UI Automation to dump the foreground window's
    // accessibility tree as JSON.
    final psScript = '''
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type -AssemblyName System.Windows.Forms

function Get-UITree {
    param(
        [System.Windows.Automation.AutomationElement]\$element,
        [int]\$depth = 0,
        [int]\$maxDepth = $maxDepth
    )
    if (\$depth -gt \$maxDepth) { return \$null }

    \$rect = \$element.Current.BoundingRectangle
    \$node = @{
        role = \$element.Current.ControlType.ProgrammaticName -replace 'ControlType\\.', ''
        label = \$element.Current.Name
        bounds = @{
            left = [math]::Round(\$rect.Left, 1)
            top = [math]::Round(\$rect.Top, 1)
            width = [math]::Round(\$rect.Width, 1)
            height = [math]::Round(\$rect.Height, 1)
        }
        interactive = \$element.Current.IsEnabled -and (
            \$element.Current.ControlType.ProgrammaticName -match 'Button|Edit|ComboBox|CheckBox|RadioButton|Slider|Tab|Menu|Hyperlink|ListItem|TreeItem'
        )
        enabled = \$element.Current.IsEnabled
    }

    \$value = ''
    try {
        \$valPattern = \$element.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern)
        if (\$valPattern) { \$value = \$valPattern.Current.Value }
    } catch {}
    if (\$value) { \$node['value'] = \$value }

    \$children = @()
    try {
        \$condition = [System.Windows.Automation.Condition]::TrueCondition
        \$childElements = \$element.FindAll([System.Windows.Automation.TreeScope]::Children, \$condition)
        foreach (\$child in \$childElements) {
            \$childNode = Get-UITree -element \$child -depth (\$depth + 1) -maxDepth \$maxDepth
            if (\$childNode) { \$children += \$childNode }
        }
    } catch {}
    if (\$children.Count -gt 0) { \$node['children'] = \$children }

    return \$node
}

\$targetWindow = \$null
${windowTitle != null ? '''
\$root = [System.Windows.Automation.AutomationElement]::RootElement
\$condition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, "$windowTitle")
\$targetWindow = \$root.FindFirst([System.Windows.Automation.TreeScope]::Children, \$condition)
''' : '''
\$hWnd = [System.Windows.Forms.Form]::ActiveForm
\$targetWindow = [System.Windows.Automation.AutomationElement]::FocusedElement
try {
    \$walker = [System.Windows.Automation.TreeWalker]::ControlViewWalker
    \$current = [System.Windows.Automation.AutomationElement]::FocusedElement
    while (\$current -ne \$null) {
        \$parent = \$walker.GetParent(\$current)
        if (\$parent -eq [System.Windows.Automation.AutomationElement]::RootElement -or \$parent -eq \$null) {
            \$targetWindow = \$current
            break
        }
        \$current = \$parent
    }
} catch {
    \$targetWindow = [System.Windows.Automation.AutomationElement]::FocusedElement
}
'''}

if (-not \$targetWindow) {
    Write-Output '{"error":"No target window found"}'
    exit 1
}

\$screen = [System.Windows.Forms.Screen]::PrimaryScreen
\$result = @{
    meta = @{
        screenWidth = \$screen.Bounds.Width
        screenHeight = \$screen.Bounds.Height
        pixelRatio = 1.0
        windowTitle = \$targetWindow.Current.Name
        platform = 'windows'
    }
    root = Get-UITree -element \$targetWindow -depth 0 -maxDepth $maxDepth
}

\$result | ConvertTo-Json -Depth 20 -Compress
''';

    try {
      final res = await Process.run(
        'powershell',
        ['-NoProfile', '-NonInteractive', '-Command', psScript],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      ).timeout(const Duration(seconds: 10));

      if (res.exitCode != 0) {
        debugPrint('Windows UIA error: ${res.stderr}');
        return null;
      }

      final output = (res.stdout as String).trim();
      if (output.isEmpty || output.startsWith('{"error"')) return null;

      final data = jsonDecode(output) as Map<String, dynamic>;
      final root = ScreenNode.fromJson(data['root'] as Map<String, dynamic>);
      final meta = ScreenMeta.fromJson(data['meta'] as Map<String, dynamic>);
      return (root, meta);
    } catch (e) {
      debugPrint('Windows UIA parse error: $e');
      return null;
    }
  }

  // ─────────────────────────── ANDROID (uiautomator) ─────────────────────────

  Future<(ScreenNode, ScreenMeta)?> _parseAndroid({int maxDepth = 10}) async {
    try {
      // Dump UI hierarchy via uiautomator
      await Process.run('adb', ['shell', 'uiautomator', 'dump', '/sdcard/ui_dump.xml']);
      final pullRes = await Process.run('adb', ['shell', 'cat', '/sdcard/ui_dump.xml']);
      await Process.run('adb', ['shell', 'rm', '/sdcard/ui_dump.xml']);

      final xml = pullRes.stdout as String;
      if (xml.isEmpty) return null;

      // Get screen size
      final sizeRes = await Process.run('adb', ['shell', 'wm', 'size']);
      final sizeMatch = RegExp(r'(\d+)x(\d+)').firstMatch(sizeRes.stdout as String);
      final screenWidth = sizeMatch != null ? double.parse(sizeMatch.group(1)!) : 1080.0;
      final screenHeight = sizeMatch != null ? double.parse(sizeMatch.group(2)!) : 1920.0;

      // Parse XML to ScreenNode tree
      final root = _parseAndroidXml(xml, maxDepth);
      if (root == null) return null;

      final meta = ScreenMeta(
        screenWidth: screenWidth,
        screenHeight: screenHeight,
        pixelRatio: 1.0,
        platform: 'android',
      );
      return (root, meta);
    } catch (e) {
      debugPrint('Android uiautomator error: $e');
      return null;
    }
  }

  ScreenNode? _parseAndroidXml(String xml, int maxDepth) {
    // Simple regex-based XML parser for uiautomator dump
    // Extracts: class, text, content-desc, bounds, clickable, enabled, focused
    final nodePattern = RegExp(
      r'<node\s+([^>]+?)(?:/>|>(.*?)</node>)',
      dotAll: true,
    );

    ScreenNode? parseNodeStr(String nodeStr, int depth) {
      if (depth > maxDepth) return null;

      String? attr(String name) {
        final match = RegExp('$name="([^"]*)"').firstMatch(nodeStr);
        return match?.group(1);
      }

      final className = attr('class') ?? '';
      final text = attr('text');
      final contentDesc = attr('content-desc');
      final boundsStr = attr('bounds');
      final clickable = attr('clickable') == 'true';
      final enabled = attr('enabled') == 'true';
      final focused = attr('focused') == 'true';
      final scrollable = attr('scrollable') == 'true';

      // Parse bounds "[left,top][right,bottom]"
      BoundingBox bounds = const BoundingBox(left: 0, top: 0, width: 0, height: 0);
      if (boundsStr != null) {
        final boundsMatch = RegExp(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]').firstMatch(boundsStr);
        if (boundsMatch != null) {
          final l = double.parse(boundsMatch.group(1)!);
          final t = double.parse(boundsMatch.group(2)!);
          final r = double.parse(boundsMatch.group(3)!);
          final b = double.parse(boundsMatch.group(4)!);
          bounds = BoundingBox(left: l, top: t, width: r - l, height: b - t);
        }
      }

      // Infer role from Android class name
      String role = 'container';
      if (className.contains('Button')) {
        role = 'button';
      } else if (className.contains('EditText')) {
        role = 'input';
      } else if (className.contains('TextView')) {
        role = 'text';
      } else if (className.contains('ImageView')) {
        role = 'image';
      } else if (className.contains('CheckBox')) {
        role = 'checkbox';
      } else if (className.contains('Switch') || className.contains('Toggle')) {
        role = 'switch';
      } else if (className.contains('SeekBar') || className.contains('Slider')) {
        role = 'slider';
      } else if (className.contains('ScrollView') || scrollable) {
        role = 'scrollable';
      }

      final actions = <String>[];
      if (clickable) actions.add('tap');
      if (scrollable) {
        actions.add('scroll_up');
        actions.add('scroll_down');
      }

      final label = (contentDesc?.isNotEmpty == true) ? contentDesc : text;

      return ScreenNode(
        role: role,
        label: (label?.isNotEmpty == true) ? label : null,
        bounds: bounds,
        actions: actions,
        interactive: clickable || className.contains('EditText'),
        enabled: enabled,
        focused: focused,
      );
    }

    // For simplicity, parse top-level hierarchy node
    final hierarchyMatch = RegExp(r'<hierarchy[^>]*>(.*)</hierarchy>', dotAll: true).firstMatch(xml);
    if (hierarchyMatch == null) return null;

    // Parse first top-level node
    final firstNodeMatch = nodePattern.firstMatch(hierarchyMatch.group(1) ?? '');
    if (firstNodeMatch == null) return null;

    return parseNodeStr(firstNodeMatch.group(0) ?? '', 0);
  }

  // ─────────────────────────── LINUX (AT-SPI2) ──────────────────────────────

  Future<(ScreenNode, ScreenMeta)?> _parseLinux({
    String? windowTitle,
    int maxDepth = 10,
  }) async {
    // Python script using pyatspi to dump accessibility tree
    final pyScript = '''
import json, subprocess
try:
    import pyatspi
except ImportError:
    print(json.dumps({"error": "pyatspi not installed. Run: pip install pyatspi"}))
    exit(1)

def get_tree(obj, depth=0, max_depth=$maxDepth):
    if depth > max_depth or obj is None:
        return None
    try:
        role = obj.getRoleName()
        name = obj.name or ""
        try:
            ext = obj.queryComponent()
            bb = ext.getExtents(pyatspi.DESKTOP_COORDS)
            bounds = {"left": bb.x, "top": bb.y, "width": bb.width, "height": bb.height}
        except:
            bounds = {"left": 0, "top": 0, "width": 0, "height": 0}
        
        actions_list = []
        try:
            action = obj.queryAction()
            for i in range(action.nActions):
                actions_list.append(action.getName(i))
        except:
            pass
        
        children = []
        for i in range(obj.childCount):
            child = get_tree(obj.getChildAtIndex(i), depth + 1, max_depth)
            if child:
                children.append(child)
        
        node = {"role": role, "bounds": bounds}
        if name: node["label"] = name
        if actions_list: node["actions"] = actions_list
        if actions_list: node["interactive"] = True
        if children: node["children"] = children
        return node
    except:
        return None

desktop = pyatspi.Registry.getDesktop(0)
target = None
${windowTitle != null ? '''
for app in desktop:
    for w in app:
        if "$windowTitle" in (w.name or ""):
            target = w
            break
    if target: break
''' : '''
import subprocess
res = subprocess.run(["xdotool", "getactivewindow", "getwindowname"], capture_output=True, text=True)
active_title = res.stdout.strip()
for app in desktop:
    for w in app:
        if active_title and active_title in (w.name or ""):
            target = w
            break
    if target: break
if not target and desktop.childCount > 0:
    app = desktop.getChildAtIndex(0)
    if app.childCount > 0:
        target = app.getChildAtIndex(0)
'''}

if not target:
    print(json.dumps({"error": "No target window found"}))
    exit(1)

res = subprocess.run(["xrandr"], capture_output=True, text=True)
import re
m = re.search(r"(\\d+)x(\\d+)", res.stdout)
sw, sh = (int(m.group(1)), int(m.group(2))) if m else (1920, 1080)

result = {
    "meta": {
        "screenWidth": sw,
        "screenHeight": sh,
        "pixelRatio": 1.0,
        "windowTitle": target.name or "Unknown",
        "platform": "linux"
    },
    "root": get_tree(target)
}
print(json.dumps(result))
''';

    try {
      final res = await Process.run(
        'python3', ['-c', pyScript],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      ).timeout(const Duration(seconds: 10));

      if (res.exitCode != 0) {
        debugPrint('Linux AT-SPI error: ${res.stderr}');
        return null;
      }

      final output = (res.stdout as String).trim();
      if (output.isEmpty || output.startsWith('{"error"')) return null;

      final data = jsonDecode(output) as Map<String, dynamic>;
      final root = ScreenNode.fromJson(data['root'] as Map<String, dynamic>);
      final meta = ScreenMeta.fromJson(data['meta'] as Map<String, dynamic>);
      return (root, meta);
    } catch (e) {
      debugPrint('Linux AT-SPI parse error: $e');
      return null;
    }
  }

  // ─────────────────────────── macOS (Accessibility API) ─────────────────────

  Future<(ScreenNode, ScreenMeta)?> _parseMacOS({
    String? windowTitle,
    int maxDepth = 10,
  }) async {
    // Use swift inline script to extract accessibility tree
    final swiftScript = '''
import Cocoa
import ApplicationServices

func getTree(_ element: AXUIElement, depth: Int = 0, maxDepth: Int = $maxDepth) -> [String: Any]? {
    guard depth <= maxDepth else { return nil }
    
    var role: CFTypeRef?
    AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
    
    var title: CFTypeRef?
    AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &title)
    
    var value: CFTypeRef?
    AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value)
    
    var position: CFTypeRef?
    AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &position)
    var size: CFTypeRef?
    AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &size)
    
    var point = CGPoint.zero
    var sz = CGSize.zero
    if let p = position { AXValueGetValue(p as! AXValue, .cgPoint, &point) }
    if let s = size { AXValueGetValue(s as! AXValue, .cgSize, &sz) }
    
    var node: [String: Any] = [
        "role": (role as? String) ?? "unknown",
        "bounds": ["left": point.x, "top": point.y, "width": sz.width, "height": sz.height]
    ]
    if let t = title as? String, !t.isEmpty { node["label"] = t }
    if let v = value as? String, !v.isEmpty { node["value"] = v }
    
    var children: CFTypeRef?
    AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
    if let kids = children as? [AXUIElement] {
        var childNodes: [[String: Any]] = []
        for kid in kids {
            if let c = getTree(kid, depth: depth + 1, maxDepth: maxDepth) {
                childNodes.append(c)
            }
        }
        if !childNodes.isEmpty { node["children"] = childNodes }
    }
    return node
}

let app = NSWorkspace.shared.frontmostApplication!
let pid = app.processIdentifier
let appElement = AXUIElementCreateApplication(pid)
let tree = getTree(appElement)
let screen = NSScreen.main!
let result: [String: Any] = [
    "meta": [
        "screenWidth": screen.frame.width,
        "screenHeight": screen.frame.height,
        "pixelRatio": screen.backingScaleFactor,
        "windowTitle": app.localizedName ?? "Unknown",
        "platform": "macos"
    ],
    "root": tree ?? [:]
]
let data = try! JSONSerialization.data(withJSONObject: result)
print(String(data: data, encoding: .utf8)!)
''';

    try {
      // Write swift script to temp file and compile/run
      final tempDir = await Directory.systemTemp.createTemp('a11y_');
      final scriptFile = File('${tempDir.path}/parse.swift');
      await scriptFile.writeAsString(swiftScript);

      final res = await Process.run(
        'swift', [scriptFile.path],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      ).timeout(const Duration(seconds: 10));

      await tempDir.delete(recursive: true);

      if (res.exitCode != 0) {
        debugPrint('macOS Accessibility error: ${res.stderr}');
        return null;
      }

      final output = (res.stdout as String).trim();
      if (output.isEmpty) return null;

      final data = jsonDecode(output) as Map<String, dynamic>;
      final root = ScreenNode.fromJson(data['root'] as Map<String, dynamic>);
      final meta = ScreenMeta.fromJson(data['meta'] as Map<String, dynamic>);
      return (root, meta);
    } catch (e) {
      debugPrint('macOS Accessibility parse error: $e');
      return null;
    }
  }
}
