import 'dart:convert';
import 'dart:io';

import 'package:companion_flutter/companion_api.dart';
import 'package:flutter_test/flutter_test.dart';

// Parse the bytes received by an actual HTTP server, including the binary part.
Map<String, ({Map<String, String> headers, List<int> bytes})> _parts(
  HttpHeaders headers,
  List<int> body,
) {
  final contentType = headers.contentType!;
  expect(contentType.mimeType, 'multipart/form-data');
  final boundary = contentType.parameters['boundary']!;
  final wireText = latin1.decode(body);
  expect(wireText, endsWith('--$boundary--\r\n'));
  final parts = <String, ({Map<String, String> headers, List<int> bytes})>{};
  for (final segment in wireText.split('--$boundary').skip(1)) {
    if (segment.startsWith('--')) break;
    final separator = segment.indexOf('\r\n\r\n');
    expect(separator, greaterThan(0));
    final partHeaders = <String, String>{};
    final headerText = utf8.decode(
      latin1.encode(segment.substring(2, separator)),
    );
    for (final line in headerText.split('\r\n')) {
      final colon = line.indexOf(':');
      partHeaders[line.substring(0, colon).toLowerCase()] = line
          .substring(colon + 1)
          .trim();
    }
    final disposition = partHeaders['content-disposition']!;
    final name = RegExp(
      r'(?:^|;\s*)name="([^"]+)"',
    ).firstMatch(disposition)![1]!;
    expect(segment, endsWith('\r\n'));
    parts[name] = (
      headers: partHeaders,
      bytes: latin1.encode(
        segment.substring(separator + 4, segment.length - 2),
      ),
    );
  }
  return parts;
}

void main() {
  late HttpServer server;
  late Directory directory;
  late File recording;
  late CompanionApi api;
  late List<int> audio;
  late Map<String, ({Map<String, String> headers, List<int> bytes})> parts;
  late String authorization;
  late String requestPath;
  late String requestMethod;
  late int declaredLength;
  late int receivedLength;
  var requests = 0;
  var responseStatus = 200;
  Object responseBody = {'id': 'profile-1', 'voice_id': 'cloned-voice'};

  setUp(() async {
    requests = 0;
    responseStatus = 200;
    responseBody = {'id': 'profile-1', 'voice_id': 'cloned-voice'};
    directory = await Directory.systemTemp.createTemp('voice-clone-upload-');
    audio = List<int>.generate(1024, (i) => i % 256);
    recording = await File('${directory.path}/录音样本.m4a').writeAsBytes(audio);
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      requests++;
      requestMethod = request.method;
      requestPath = request.uri.path;
      authorization = request.headers.value(HttpHeaders.authorizationHeader)!;
      declaredLength = request.headers.contentLength;
      final body = await request.fold<List<int>>(
        [],
        (bytes, chunk) => bytes..addAll(chunk),
      );
      receivedLength = body.length;
      parts = _parts(request.headers, body);
      request.response.statusCode = responseStatus;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(responseBody));
      await request.response.close();
    });
    api = CompanionApi(baseUrl: 'http://127.0.0.1:${server.port}/api')
      ..authToken = 'synthetic-admin-token';
  });

  tearDown(() async {
    await server.close(force: true);
    await directory.delete(recursive: true);
  });

  Future<Map<String, dynamic>> createVoice({
    String name = '我的日常音色 🎙️',
    bool consent = true,
  }) => api.createAdminClonedVoice(
    file: recording,
    displayName: name,
    gender: 'female',
    prefix: 'casual',
    consentConfirmed: consent,
  );

  for (final name in ['我的日常音色 🎙️', 'casual voice']) {
    test('voice clone uploads name "$name" and unmodified audio', () async {
      final result = await createVoice(name: name);
      expect(result, {'id': 'profile-1', 'voice_id': 'cloned-voice'});
      expect(requests, 1);
      expect(requestMethod, 'POST');
      expect(requestPath, '/api/admin-api/tts/voices/clone');
      expect(authorization, 'Bearer synthetic-admin-token');
      expect(declaredLength, receivedLength);
      expect(
        parts.keys,
        unorderedEquals([
          'display_name',
          'gender',
          'prefix',
          'consent_confirmed',
          'file',
        ]),
      );
      expect(utf8.decode(parts['display_name']!.bytes), name);
      expect(utf8.decode(parts['gender']!.bytes), 'female');
      expect(utf8.decode(parts['prefix']!.bytes), 'casual');
      expect(utf8.decode(parts['consent_confirmed']!.bytes), 'true');
      expect(parts['file']!.headers['content-type'], 'audio/mp4');
      expect(
        parts['file']!.headers['content-disposition'],
        contains('filename="录音样本.m4a"'),
      );
      expect(parts['file']!.bytes, audio);
    });
  }

  for (final status in [401, 422, 502]) {
    test(
      'voice clone preserves server detail for HTTP $status without retry',
      () async {
        responseStatus = status;
        const message = '录音需要至少 5 秒有效人声，或服务暂时不可用';
        responseBody = {'detail': message};
        await expectLater(
          createVoice(),
          throwsA(
            isA<ApiException>()
                .having((error) => error.statusCode, 'statusCode', status)
                .having((error) => error.message, 'message', message),
          ),
        );
        expect(requests, 1);
        expect(await recording.readAsBytes(), audio);
      },
    );
  }

  test(
    'voice clone sends the supplied consent instead of assuming consent',
    () async {
      await createVoice(consent: false);
      expect(utf8.decode(parts['consent_confirmed']!.bytes), 'false');
    },
  );

  test('missing recording fails before upload', () async {
    await recording.delete();
    await expectLater(createVoice(), throwsA(isA<FileSystemException>()));
    expect(requests, 0);
  });
}
