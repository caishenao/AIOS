import 'dart:convert';
import 'dart:io';
import '../lib/config.dart';
import '../lib/discovery.dart';
import 'package:puppeteer/puppeteer.dart';

Map<String, Map<String, dynamic>> _virtualIotDevices = {};

Future<void> _loadIotDevices() async {
  final file = File('gateway_devices.json');
  if (await file.exists()) {
    try {
      final content = await file.readAsString();
      final list = jsonDecode(content) as List<dynamic>;
      _virtualIotDevices.clear();
      for (final item in list) {
        if (item is Map<String, dynamic> && item.containsKey('id')) {
          _virtualIotDevices[item['id']] = item;
        }
      }
      return;
    } catch (_) {}
  }
  // Initialize with default devices and save
  _virtualIotDevices = {
    'living_room_light': {
      'id': 'living_room_light',
      'name': '客厅大灯',
      'type': 'light',
      'state': 'off',
      'brightness': 80,
    },
    'gateway_thermostat': {
      'id': 'gateway_thermostat',
      'name': '温控器',
      'type': 'thermostat',
      'temperature': 24.5,
      'humidity': 55.0,
      'target_temp': 25.0,
    },
    'smart_switch': {
      'id': 'smart_switch',
      'name': '智能插座',
      'type': 'switch',
      'state': 'on',
      'current_power_w': 12.4,
    }
  };
  await _saveIotDevices();
}

Map<String, dynamic> _parseOfflineIntent(String content) {
  final text = content.toLowerCase();
  
  // Rule 1: Light control
  if (text.contains('开') && text.contains('灯')) {
    return {
      'status': 'success',
      'choices': [{
        'message': {
          'role': 'assistant',
          'content': '好的，正在为您打开客厅主灯。',
          'tool_calls': [{
            'id': 'call_offline_light',
            'type': 'function',
            'function': {
              'name': 'control_iot_device',
              'arguments': '{"deviceId":"living_room_light","action":"on"}'
            }
          }]
        }
      }]
    };
  }
  if (text.contains('关') && text.contains('灯')) {
    return {
      'status': 'success',
      'choices': [{
        'message': {
          'role': 'assistant',
          'content': '好的，正在为您关闭客厅主灯。',
          'tool_calls': [{
            'id': 'call_offline_light',
            'type': 'function',
            'function': {
              'name': 'control_iot_device',
              'arguments': '{"deviceId":"living_room_light","action":"off"}'
            }
          }]
        }
      }]
    };
  }

  // Rule 2: Climate/AC control
  if (text.contains('开') && text.contains('空调')) {
    return {
      'status': 'success',
      'choices': [{
        'message': {
          'role': 'assistant',
          'content': '好的，正在为您打开卧室空调。',
          'tool_calls': [{
            'id': 'call_offline_ac',
            'type': 'function',
            'function': {
              'name': 'control_iot_device',
              'arguments': '{"deviceId":"bedroom_ac","action":"on"}'
            }
          }]
        }
      }]
    };
  }
  if (text.contains('关') && text.contains('空调')) {
    return {
      'status': 'success',
      'choices': [{
        'message': {
          'role': 'assistant',
          'content': '好的，正在为您关闭卧室空调。',
          'tool_calls': [{
            'id': 'call_offline_ac',
            'type': 'function',
            'function': {
              'name': 'control_iot_device',
              'arguments': '{"deviceId":"bedroom_ac","action":"off"}'
            }
          }]
        }
      }]
    };
  }
  final tempMatch = RegExp(r'(?:调到|设置为)\s*(\d+)\s*(?:度|°c)?').firstMatch(text);
  if (tempMatch != null && text.contains('空调')) {
    final temp = tempMatch.group(1);
    return {
      'status': 'success',
      'choices': [{
        'message': {
          'role': 'assistant',
          'content': '好的，已将卧室空调温度调至 $temp 度。',
          'tool_calls': [{
            'id': 'call_offline_ac_temp',
            'type': 'function',
            'function': {
              'name': 'control_iot_device',
              'arguments': '{"deviceId":"bedroom_ac","action":"temp=$temp.0"}'
            }
          }]
        }
      }]
    };
  }

  // Rule 3: Door lock control
  if (text.contains('锁门') || (text.contains('锁') && text.contains('门'))) {
    return {
      'status': 'success',
      'choices': [{
        'message': {
          'role': 'assistant',
          'content': '好的，智能门锁已上锁。',
          'tool_calls': [{
            'id': 'call_offline_lock',
            'type': 'function',
            'function': {
              'name': 'control_iot_device',
              'arguments': '{"deviceId":"door_lock","action":"on"}'
            }
          }]
        }
      }]
    };
  }
  if (text.contains('开门') || text.contains('开锁')) {
    return {
      'status': 'success',
      'choices': [{
        'message': {
          'role': 'assistant',
          'content': '好的，正在为您开锁。',
          'tool_calls': [{
            'id': 'call_offline_unlock',
            'type': 'function',
            'function': {
              'name': 'control_iot_device',
              'arguments': '{"deviceId":"door_lock","action":"off"}'
            }
          }]
        }
      }]
    };
  }

  // Rule 4: Query state
  if (text.contains('状态') || text.contains('查询') || text.contains('温度')) {
    return {
      'status': 'success',
      'choices': [{
        'message': {
          'role': 'assistant',
          'content': '好的，正在为您获取智能家居设备状态数据。',
          'tool_calls': [{
            'id': 'call_offline_get',
            'type': 'function',
            'function': {
              'name': 'get_iot_data',
              'arguments': '{}'
            }
          }]
        }
      }]
    };
  }

  // Fallback text reply
  return {
    'status': 'success',
    'choices': [{
      'message': {
        'role': 'assistant',
        'content': '处于离线紧急模式下，无法识别您的指令。支持的动作有：开/关灯，开/关空调，调空调温度，开锁/锁门。',
      }
    }]
  };
}

Future<void> _saveIotDevices() async {
  final file = File('gateway_devices.json');
  final jsonString = const JsonEncoder.withIndent('  ').convert(_virtualIotDevices.values.toList());
  await file.writeAsString(jsonString);
}

Browser? _browser;
Page? _page;

Future<Page> _getBrowserPage() async {
  if (_browser == null) {
    _browser = await puppeteer.launch();
  }
  if (_page == null) {
    _page = await _browser!.newPage();
    await _page!.setViewport(DeviceViewport(width: 1280, height: 800));
  }
  return _page!;
}

void main(List<String> args) async {
  final configPath = 'daemon_config.json';
  var config = await DaemonConfig.load(configPath);
  await _loadIotDevices();

  // Parse arguments manually
  for (int i = 0; i < args.length; i++) {
    if (args[i] == '--port' && i + 1 < args.length) {
      final p = int.tryParse(args[i + 1]);
      if (p != null) {
        config = DaemonConfig(
          id: config.id,
          name: config.name,
          port: p,
          skills: config.skills,
          auth: config.auth,
          token: config.token,
        );
      }
    } else if (args[i] == '--name' && i + 1 < args.length) {
      config = DaemonConfig(
        id: config.id,
        name: args[i + 1],
        port: config.port,
        skills: config.skills,
        auth: config.auth,
        token: config.token,
      );
    } else if (args[i] == '--skills' && i + 1 < args.length) {
      final skillList = args[i + 1].split(',').map((s) => s.trim()).toList();
      config = DaemonConfig(
        id: config.id,
        name: config.name,
        port: config.port,
        skills: skillList,
        auth: config.auth,
        token: config.token,
      );
    }
  }

  // Save the resolved config back to daemon_config.json
  await config.save(configPath);

  print('========================================');
  print('          AIOS 无界面应用启动          ');
  print('========================================');
  print('节点 ID: ${config.id}');
  print('节点名称: ${config.name}');
  print('监听端口: ${config.port}');
  print('激活能力: ${config.skills.join(', ')}');
  print('鉴权模式: ${config.auth}');
  if (config.auth == 'token') {
    print('\x1B[31m[SECURITY] Node Pairing Token: ${config.token}\x1B[0m');
  }
  print('========================================');

  // Start HTTP API Server
  final server = await HttpServer.bind(InternetAddress.anyIPv4, config.port);
  print('HTTP Server running at http://localhost:${config.port}');

  // Start UDP Multicast Broadcaster
  final discovery = DaemonDiscoveryService(config);
  await discovery.start();
  print('UDP Multicast Discovery broadcasing on port 12100...');

  // Listen to requests
  server.listen((HttpRequest request) async {
    // Enable CORS
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    request.response.headers.add('Access-Control-Allow-Headers', 'Origin, Content-Type');

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
      return;
    }

    // Authenticate if config.auth is 'token'
    final path = request.uri.path;
    if (config.auth == 'token' && path != '/agent-card') {
      final authHeader = request.headers.value('Authorization') ?? '';
      var isAuthenticated = false;
      if (authHeader.startsWith('Bearer ')) {
        final requestToken = authHeader.substring(7).trim();
        isAuthenticated = (requestToken == config.token);
      }
      if (!isAuthenticated) {
        request.response.statusCode = HttpStatus.unauthorized;
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({'error': 'Unauthorized: Invalid pairing token'}));
        await request.response.close();
        return;
      }
    }

    try {
      final path = request.uri.path;

      // GET /agent-card
      if (request.method == 'GET' && path == '/agent-card') {
        const rfwWidgetsString = '''
import core;
import material;

widget DaemonSensorCard = Container(
  padding: [16.0, 16.0, 16.0, 16.0],
  margin: [0.0, 0.0, 0.0, 8.0],
  decoration: {
    color: 0xFF141724,
    borderRadius: [16.0, 16.0, 16.0, 16.0],
    border: { color: 0xFF00E5FF, width: 1.5 }
  },
  child: Column(
    crossAxisAlignment: 'start',
    children: [
      Row(
        mainAxisAlignment: 'spaceBetween',
        children: [
          Text(text: data.title, style: { color: 0xFFFFFFFF, fontSize: 16.0, fontWeight: 'bold' }),
          Icon(icon: 0xE80B, color: 0xFF00E5FF, size: 20.0),
        ]
      ),
      SizedBox(height: 12.0),
      Text(text: data.value, style: { color: 0xFF00E5FF, fontSize: 32.0, fontWeight: 'bold' }),
      SizedBox(height: 6.0),
      Text(text: data.status, style: { color: 0xFFA0A5C0, fontSize: 12.0 }),
    ]
  )
);
''';
        final card = {
          'id': config.id,
          'name': config.name,
          'description': 'AIOS Headless Gateway Daemon',
          'version': '1.0.0',
          'endpoint': 'http://${request.headers.value('host') ?? "localhost:${config.port}"}',
          'skills': config.skills,
          'auth': config.auth,
          'devices': _virtualIotDevices.values.toList(),
          'rfw_widgets': rfwWidgetsString,
        };
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(card));
        await request.response.close();
        return;
      }

      // POST /browser-action
      if (request.method == 'POST' && path == '/browser-action') {
        if (!config.skills.contains('web_automation')) {
          request.response.statusCode = HttpStatus.forbidden;
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode({'error': 'Skill web_automation is not enabled'}));
          await request.response.close();
          return;
        }

        final content = await utf8.decoder.bind(request).join();
        final body = jsonDecode(content) as Map<String, dynamic>;
        final actions = body['actions'] as List<dynamic>? ?? [];

        try {
          final page = await _getBrowserPage();
          final results = <Map<String, dynamic>>[];

          for (final actionMap in actions) {
            final action = actionMap['action'] as String? ?? '';
            
            if (action == 'goto') {
              final url = actionMap['url'] as String? ?? '';
              await page.goto(url, wait: Until.networkAlmostIdle);
              results.add({'action': 'goto', 'status': 'success', 'url': url});
            } else if (action == 'click') {
              final selector = actionMap['selector'] as String? ?? '';
              await page.click(selector);
              results.add({'action': 'click', 'status': 'success'});
            } else if (action == 'type') {
              final selector = actionMap['selector'] as String? ?? '';
              final text = actionMap['text'] as String? ?? '';
              await page.type(selector, text);
              results.add({'action': 'type', 'status': 'success'});
            } else if (action == 'get_text') {
              final selector = actionMap['selector'] as String? ?? '';
              final text = await page.evaluate('''(sel) => {
                const el = document.querySelector(sel);
                return el ? el.innerText : '';
              }''', args: [selector]);
              results.add({'action': 'get_text', 'status': 'success', 'text': text});
            } else if (action == 'screenshot') {
              final bytes = await page.screenshot();
              final base64String = base64Encode(bytes);
              results.add({'action': 'screenshot', 'status': 'success', 'image': base64String});
            } else if (action == 'close') {
              if (_browser != null) {
                await _browser!.close();
                _browser = null;
                _page = null;
              }
              results.add({'action': 'close', 'status': 'success'});
            } else {
              results.add({'action': action, 'status': 'error', 'message': 'Unknown action $action'});
            }
          }

          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode({'status': 'success', 'results': results}));
          await request.response.close();
          return;
        } catch (e) {
          request.response.statusCode = HttpStatus.internalServerError;
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode({'status': 'error', 'message': e.toString()}));
          await request.response.close();
          return;
        }
      }

      // POST /offline-chat
      if (request.method == 'POST' && path == '/offline-chat') {
        final content = await utf8.decoder.bind(request).join();
        final body = jsonDecode(content) as Map<String, dynamic>;
        final messages = body['messages'] as List<dynamic>? ?? [];
        
        final userContent = messages.isNotEmpty 
            ? (messages.last['content'] as String? ?? '')
            : '';

        var ollamaSuccess = false;
        try {
          final client = HttpClient();
          final req = await client.postUrl(Uri.parse('http://localhost:11434/api/chat'));
          req.headers.contentType = ContentType.json;
          req.write(jsonEncode({
            'model': 'qwen2.5:0.5b',
            'messages': messages,
            'stream': false,
          }));
          final resp = await req.close().timeout(const Duration(seconds: 4));
          if (resp.statusCode == HttpStatus.ok) {
            final respContent = await utf8.decoder.bind(resp).join();
            final ollamaData = jsonDecode(respContent) as Map<String, dynamic>;
            final message = ollamaData['message'] as Map<String, dynamic>;
            
            request.response.headers.contentType = ContentType.json;
            request.response.write(jsonEncode({
              'status': 'success',
              'choices': [{
                'message': {
                  'role': 'assistant',
                  'content': message['content'],
                  if (message.containsKey('tool_calls')) 'tool_calls': message['tool_calls']
                }
              }]
            }));
            await request.response.close();
            ollamaSuccess = true;
          }
        } catch (_) {
          // Fallback to local rule parser
        }

        if (!ollamaSuccess) {
          final res = _parseOfflineIntent(userContent);
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode(res));
          await request.response.close();
        }
        return;
      }

      // POST /task / POST /a2a/tasks (Compatibility mapping for general A2A routing)
      if (request.method == 'POST' && (path == '/task' || path == '/a2a/tasks' || path == '/')) {
        final content = await utf8.decoder.bind(request).join();
        final body = jsonDecode(content);
        final intent = (body['intent'] ?? body['task']) as String? ?? '';

        // Run general command/script depending on enabled skills
        if (config.skills.contains('command_exec') && intent.isNotEmpty) {
          final res = await _executeCommand(intent);
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode({
            'reply': 'Command executed:\n${res['stdout'] ?? ""}\n${res['stderr'] ?? ""}',
            'status': 'success',
            'details': res,
          }));
        } else {
          request.response.statusCode = HttpStatus.badRequest;
          request.response.write('{"error": "Unsupported task or disabled capability"}');
        }
        await request.response.close();
        return;
      }

      // POST /execute-command
      if (request.method == 'POST' && path == '/execute-command') {
        if (!config.skills.contains('command_exec')) {
          _respondError(request, 'Skill "command_exec" is disabled.');
          return;
        }
        final content = await utf8.decoder.bind(request).join();
        final body = jsonDecode(content);
        final command = body['command'] as String? ?? '';
        final result = await _executeCommand(command);
        _respondJson(request, result);
        return;
      }

      // POST /execute-script
      if (request.method == 'POST' && path == '/execute-script') {
        if (!config.skills.contains('script_exec')) {
          _respondError(request, 'Skill "script_exec" is disabled.');
          return;
        }
        final content = await utf8.decoder.bind(request).join();
        final body = jsonDecode(content);
        final scriptContent = body['script'] as String? ?? '';
        final ext = body['extension'] as String? ?? (Platform.isWindows ? '.ps1' : '.sh');
        final result = await _executeScript(scriptContent, ext);
        _respondJson(request, result);
        return;
      }

      // POST /upload-file
      if (request.method == 'POST' && path == '/upload-file') {
        if (!config.skills.contains('file_upload')) {
          _respondError(request, 'Skill "file_upload" is disabled.');
          return;
        }
        final content = await utf8.decoder.bind(request).join();
        final body = jsonDecode(content);
        final filePath = body['path'] as String? ?? '';
        final fileContent = body['content'] as String? ?? '';
        final isBase64 = body['is_base64'] as bool? ?? false;
        final result = await _writeFile(filePath, fileContent, isBase64);
        _respondJson(request, result);
        return;
      }

      // POST /download-file
      if (request.method == 'POST' && path == '/download-file') {
        if (!config.skills.contains('file_upload')) {
          _respondError(request, 'Skill "file_upload" is disabled.');
          return;
        }
        final content = await utf8.decoder.bind(request).join();
        final body = jsonDecode(content);
        final filePath = body['path'] as String? ?? '';
        final result = await _readFile(filePath);
        _respondJson(request, result);
        return;
      }

      // GET /iot-data
      if (request.method == 'GET' && path == '/iot-data') {
        if (!config.skills.contains('iot_data')) {
          _respondError(request, 'Skill "iot_data" is disabled.');
          return;
        }
        _respondJson(request, {
          'status': 'success',
          'devices': _virtualIotDevices.values.toList(),
        });
        return;
      }

      // POST /control-device
      if (request.method == 'POST' && path == '/control-device') {
        if (!config.skills.contains('iot_control')) {
          _respondError(request, 'Skill "iot_control" is disabled.');
          return;
        }
        final content = await utf8.decoder.bind(request).join();
        final body = jsonDecode(content);
        final devId = body['deviceId'] as String? ?? '';
        final action = body['action'] as String? ?? '';
        final result = await _controlIotDevice(devId, action);
        _respondJson(request, result);
        return;
      }

      // GET /screen-structure
      if (request.method == 'GET' && path == '/screen-structure') {
        if (!config.skills.contains('screen_parse')) {
          _respondError(request, 'Skill "screen_parse" is disabled.');
          return;
        }
        final windowTitle = request.uri.queryParameters['windowTitle'];
        final maxDepth = int.tryParse(request.uri.queryParameters['maxDepth'] ?? '') ?? 10;
        final result = await _getScreenStructure(windowTitle: windowTitle, maxDepth: maxDepth);
        _respondJson(request, result);
        return;
      }

      // POST /parse-screenshot
      if (request.method == 'POST' && path == '/parse-screenshot') {
        if (!config.skills.contains('screen_parse')) {
          _respondError(request, 'Skill "screen_parse" is disabled.');
          return;
        }
        final content = await utf8.decoder.bind(request).join();
        final body = jsonDecode(content);
        final image = body['image'] as String? ?? '';
        final result = await _parseScreenshot(image);
        _respondJson(request, result);
        return;
      }

      // 404 Route
      request.response.statusCode = HttpStatus.notFound;
      request.response.write('{"error": "Endpoint not found"}');
      await request.response.close();

    } catch (e) {
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.write(jsonEncode({'error': e.toString()}));
      await request.response.close();
    }
  });
}

// REST Helper methods
void _respondJson(HttpRequest request, Map<String, dynamic> data) async {
  request.response.headers.contentType = ContentType.json;
  request.response.write(jsonEncode(data));
  await request.response.close();
}

void _respondError(HttpRequest request, String msg) async {
  request.response.statusCode = HttpStatus.forbidden;
  request.response.headers.contentType = ContentType.json;
  request.response.write(jsonEncode({'error': msg}));
  await request.response.close();
}

// Execution Logic
Future<Map<String, dynamic>> _executeCommand(String command) async {
  try {
    ProcessResult res;
    if (Platform.isWindows) {
      res = await Process.run('powershell', ['-NoProfile', '-NonInteractive', '-Command', command]);
    } else {
      res = await Process.run('sh', ['-c', command]);
    }
    return {
      'status': 'success',
      'stdout': res.stdout.toString(),
      'stderr': res.stderr.toString(),
      'exit_code': res.exitCode,
    };
  } catch (e) {
    return {'status': 'error', 'message': e.toString()};
  }
}

Future<Map<String, dynamic>> _executeScript(String scriptContent, String ext) async {
  final tempDir = Directory.systemTemp;
  final tempFile = File('${tempDir.path}${Platform.pathSeparator}aios_script_${DateTime.now().millisecondsSinceEpoch}$ext');
  try {
    await tempFile.writeAsString(scriptContent);
    ProcessResult res;
    if (Platform.isWindows) {
      res = await Process.run('powershell', ['-NoProfile', '-NonInteractive', '-File', tempFile.path]);
    } else {
      await Process.run('chmod', ['+x', tempFile.path]);
      res = await Process.run(tempFile.path, []);
    }
    return {
      'status': 'success',
      'stdout': res.stdout.toString(),
      'stderr': res.stderr.toString(),
      'exit_code': res.exitCode,
    };
  } catch (e) {
    return {'status': 'error', 'message': e.toString()};
  } finally {
    if (await tempFile.exists()) {
      await tempFile.delete();
    }
  }
}

Future<Map<String, dynamic>> _writeFile(String path, String content, bool isBase64) async {
  try {
    final file = File(path);
    await file.parent.create(recursive: true);
    if (isBase64) {
      final bytes = base64Decode(content);
      await file.writeAsBytes(bytes);
    } else {
      await file.writeAsString(content);
    }
    return {
      'status': 'success',
      'message': 'File uploaded and saved to ${file.absolute.path}',
    };
  } catch (e) {
    return {'status': 'error', 'message': e.toString()};
  }
}

Future<Map<String, dynamic>> _readFile(String path) async {
  try {
    final file = File(path);
    if (!await file.exists()) {
      return {'status': 'error', 'message': 'File not found'};
    }
    
    final ext = path.split('.').last.toLowerCase();
    final binaryExtensions = {'png', 'jpg', 'jpeg', 'gif', 'pdf', 'zip', 'tar', 'gz', 'exe', 'bin', 'dll', 'so', 'apk'};
    final isBinary = binaryExtensions.contains(ext);
    
    String content;
    if (isBinary) {
      final bytes = await file.readAsBytes();
      content = base64Encode(bytes);
    } else {
      content = await file.readAsString();
    }
    
    return {
      'status': 'success',
      'content': content,
      'is_binary': isBinary,
    };
  } catch (e) {
    return {'status': 'error', 'message': e.toString()};
  }
}

Future<Map<String, dynamic>> _controlIotDevice(String devId, String action) async {
  final dev = _virtualIotDevices[devId];
  if (dev == null) {
    return {'status': 'error', 'message': 'Device not found'};
  }

  if (action == 'on' || action == 'off') {
    dev['state'] = action;
    if (devId == 'smart_switch') {
      dev['current_power_w'] = action == 'on' ? 15.6 : 0.0;
    }
  } else if (action.startsWith('brightness=')) {
    final val = int.tryParse(action.substring(11));
    if (val != null) dev['brightness'] = val.clamp(0, 100);
  } else if (action.startsWith('temp=')) {
    final val = double.tryParse(action.substring(5));
    if (val != null) dev['target_temp'] = val;
  }

  await _saveIotDevices();

  return {
    'status': 'success',
    'device': dev,
  };
}

Future<Map<String, dynamic>> _getScreenStructure({String? windowTitle, int maxDepth = 10}) async {
  if (Platform.isWindows) {
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
      );
      if (res.exitCode == 0) {
        final data = jsonDecode(res.stdout as String) as Map<String, dynamic>;
        return {
          'status': 'success',
          'source': 'platform_a11y',
          'meta': data['meta'],
          'root': data['root'],
        };
      }
      return {'status': 'error', 'message': res.stderr.toString()};
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  } else if (Platform.isLinux) {
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
      final res = await Process.run('python3', ['-c', pyScript]);
      if (res.exitCode == 0) {
        final data = jsonDecode(res.stdout as String) as Map<String, dynamic>;
        return {
          'status': 'success',
          'source': 'platform_a11y',
          'meta': data['meta'],
          'root': data['root'],
        };
      }
      return {'status': 'error', 'message': res.stderr.toString()};
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }
  return {'status': 'error', 'message': 'Platform not supported'};
}

Future<Map<String, dynamic>> _parseScreenshot(String base64Image) async {
  final endpoint = 'http://localhost:8200/parse';
  try {
    final client = HttpClient();
    final request = await client.postUrl(Uri.parse(endpoint));
    request.headers.contentType = ContentType.json;
    final requestBody = jsonEncode({
      'image': base64Image,
      'format': 'structured',
    });
    request.write(requestBody);
    final response = await request.close();
    
    if (response.statusCode == 200) {
      final responseBody = await response.transform(utf8.decoder).join();
      final data = jsonDecode(responseBody) as Map<String, dynamic>;
      
      final elements = data['elements'] as List<dynamic>? ?? [];
      final width = (data['width'] as num?)?.toDouble() ?? 1920.0;
      final height = (data['height'] as num?)?.toDouble() ?? 1080.0;
      
      final nodes = elements.map((e) {
        final elem = e as Map<String, dynamic>;
        final bbox = elem['bbox'] as List<dynamic>? ?? [0, 0, 0, 0];
        
        double x1 = (bbox[0] as num).toDouble();
        double y1 = (bbox[1] as num).toDouble();
        double x2 = (bbox[2] as num).toDouble();
        double y2 = (bbox[3] as num).toDouble();
        
        if (x2 <= 1.0 && y2 <= 1.0) {
          x1 *= width;
          y1 *= height;
          x2 *= width;
          y2 *= height;
        }
        
        return {
          'role': elem['type'] ?? 'element',
          'label': elem['label'] ?? elem['caption'] ?? elem['text'],
          'bounds': {
            'left': x1,
            'top': y1,
            'width': x2 - x1,
            'height': y2 - y1,
          },
          'interactive': true,
        };
      }).toList();
      
      return {
        'status': 'success',
        'source': 'omniparser',
        'meta': {
          'screenWidth': width,
          'screenHeight': height,
          'platform': Platform.operatingSystem,
        },
        'root': {
          'role': 'screen',
          'bounds': {'left': 0, 'top': 0, 'width': width, 'height': height},
          'children': nodes,
        }
      };
    } else {
      final errorBody = await response.transform(utf8.decoder).join();
      return {'status': 'error', 'message': 'OmniParser server returned ${response.statusCode}: $errorBody'};
    }
  } catch (e) {
    return {'status': 'error', 'message': 'Failed to connect to OmniParser server: $e'};
  }
}

