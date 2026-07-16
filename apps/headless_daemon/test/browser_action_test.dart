import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';
import 'package:http/http.dart' as http;

void main() {
  HttpServer? server;
  final port = 9091;

  setUpAll(() async {
    // Start a mock server or test the routing logic
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    server!.listen((HttpRequest request) async {
      final path = request.uri.path;
      if (request.method == 'POST' && path == '/browser-action') {
        final content = await utf8.decoder.bind(request).join();
        final body = jsonDecode(content) as Map<String, dynamic>;
        final actions = body['actions'] as List<dynamic>? ?? [];

        final results = <Map<String, dynamic>>[];
        for (final actionMap in actions) {
          final action = actionMap['action'] as String? ?? '';
          if (action == 'goto') {
            results.add({'action': 'goto', 'status': 'success', 'url': actionMap['url']});
          } else if (action == 'click') {
            results.add({'action': 'click', 'status': 'success'});
          } else {
            results.add({'action': action, 'status': 'error', 'message': 'Unsupported mock action'});
          }
        }
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({'status': 'success', 'results': results}));
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

  test('POST /browser-action mock automation test', () async {
    final response = await http.post(
      Uri.parse('http://localhost:$port/browser-action'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'actions': [
          {'action': 'goto', 'url': 'https://google.com'},
          {'action': 'click', 'selector': '#search-btn'}
        ]
      }),
    );

    expect(response.statusCode, 200);
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    expect(data['status'], 'success');
    expect(data['results'], isList);
    expect(data['results'][0]['action'], 'goto');
    expect(data['results'][0]['status'], 'success');
    expect(data['results'][1]['action'], 'click');
  });
}
