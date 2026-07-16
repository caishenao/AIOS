import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';
import 'package:http/http.dart' as http;

void main() {
  HttpServer? server;
  final port = 9092;

  setUpAll(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    server!.listen((HttpRequest request) async {
      final path = request.uri.path;
      if (request.method == 'POST' && path == '/offline-chat') {
        final content = await utf8.decoder.bind(request).join();
        final body = jsonDecode(content) as Map<String, dynamic>;
        final messages = body['messages'] as List<dynamic>? ?? [];
        final userContent = messages.isNotEmpty 
            ? (messages.last['content'] as String? ?? '')
            : '';

        // Mimic local rule-based intent parser
        final text = userContent.toLowerCase();
        Map<String, dynamic> res;
        if (text.contains('开') && text.contains('灯')) {
          res = {
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
        } else {
          res = {
            'status': 'success',
            'choices': [{
              'message': {'role': 'assistant', 'content': 'Fallback content'}
            }]
          };
        }

        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(res));
        await request.response.close();
      } else {
        request.response.statusCode = 404;
        await request.response.close();
      }
    });
  });

  tearDownAll(() async {
    await server?.close();
  });

  test('POST /offline-chat parses lighting command and returns tool calls', () async {
    final response = await http.post(
      Uri.parse('http://localhost:$port/offline-chat'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'messages': [
          {'role': 'user', 'content': '打开客厅的灯'}
        ]
      }),
    );

    expect(response.statusCode, 200);
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    expect(data['status'], 'success');
    expect(data['choices'], isList);
    
    final message = data['choices'][0]['message'] as Map<String, dynamic>;
    expect(message['content'], contains('打开客厅主灯'));
    
    final toolCalls = message['tool_calls'] as List<dynamic>;
    expect(toolCalls[0]['function']['name'], 'control_iot_device');
    expect(toolCalls[0]['function']['arguments'], contains('living_room_light'));
  });
}
