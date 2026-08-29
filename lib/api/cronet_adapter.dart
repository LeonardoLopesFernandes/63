import 'dart:async';
import 'dart:typed_data';

import 'package:cronet_http/cronet_http.dart';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;

/// Adaptador que roteia as chamadas do Dio pela pilha de rede do Chromium
/// (Cronet), idêntica à usada pelo Chrome/Kiwi. Isso faz o app passar por
/// WAF/Akamai/bot-management como um navegador.
class CronetAdapter implements HttpClientAdapter {
  final CronetClient client;

  CronetAdapter(this.client);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    final uri = options.uri;
    final headers = <String, String>{};
    options.headers.forEach((key, value) {
      if (value == null) return;
      headers[key] = value is List ? value.join(',') : value.toString();
    });

    List<int>? bodyBytes;
    if (requestStream != null) {
      bodyBytes = await requestStream.expand((x) => x).toList();
    }

    final request = http.Request(options.method.toUpperCase(), uri);
    request.headers.addAll(headers);
    if (bodyBytes != null && bodyBytes.isNotEmpty) {
      request.bodyBytes = bodyBytes;
    }

    final streamed = await client.send(request);

    final respHeaders = <String, List<String>>{};
    streamed.headers.forEach((key, value) {
      respHeaders[key] = [value];
    });

    final bytes = await streamed.stream.expand((x) => x).toList();

    return ResponseBody.fromBytes(
      bytes,
      streamed.statusCode,
      statusMessage: streamed.reasonPhrase,
      headers: respHeaders,
      isRedirect: streamed.isRedirect,
    );
  }

  @override
  void close({bool force = false}) => client.close();
}

late final CronetAdapter cronetAdapter;

void initCronetTransport() {
  final engine = CronetEngine.build(
    userAgent:
        'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
  );
  cronetAdapter = CronetAdapter(CronetClient.fromCronetEngine(engine));
}
