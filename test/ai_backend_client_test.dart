import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:roomcraft_ai/services/ai_backend_client.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  AiBackendClient client(
    MockClient transport, {
    String userId = 'alice',
    bool Function()? current,
  }) => AiBackendClient(
    userId: userId,
    getToken: () async => 'test-only-id-token',
    isCurrentUser: current ?? () => true,
    client: transport,
    baseUrl: 'http://localhost:3000',
    pollDelay: Duration.zero,
  );
  http.Response success() => http.Response(
    jsonEncode({
      'status': 'succeeded',
      'imageBase64': 'AQID',
      'mimeType': 'image/jpeg',
    }),
    200,
  );
  test(
    'Transport sends token and key, consumes actual bytes and stores no photo/token/prompt',
    () async {
      var posts = 0;
      final api = client(
        MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer test-only-id-token');
          if (request.method == 'POST') {
            posts++;
            expect(
              request.headers['Idempotency-Key']!.length,
              greaterThanOrEqualTo(16),
            );
            expect(request.body, contains('name="projectId"'));
            expect(request.body, isNot(contains('name="userId"')));
            return http.Response('{"status":"processing"}', 202);
          }
          return success();
        }),
      );
      final result = await api.run(
        kind: 'room',
        projectId: 'project-1',
        prompt: 'private-client-brief',
        imageBytes: Uint8List.fromList([1, 2, 3]),
      );
      expect(result.bytes, [1, 2, 3]);
      expect(posts, 1);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), isEmpty);
      api.close();
    },
  );
  test(
    'Lost POST response survives a recreated client and uses GET, not another paid POST',
    () async {
      String? id;
      final first = client(
        MockClient((request) async {
          id = request.headers['Idempotency-Key'];
          throw http.ClientException('connection lost');
        }),
      );
      final bytes = Uint8List.fromList([1, 2, 3]);
      await expectLater(
        first.run(
          kind: 'room',
          projectId: 'p',
          prompt: 'secret brief',
          imageBytes: bytes,
        ),
        throwsA(isA<http.ClientException>()),
      );
      first.close();
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('roomcraft_ai_pending_alice_room')!;
      expect(raw, contains(id));
      expect(raw, isNot(contains('secret brief')));
      expect(raw, isNot(contains('test-only-id-token')));
      final next = client(
        MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/operations/$id');
          return success();
        }),
      );
      await next.run(
        kind: 'room',
        projectId: 'p',
        prompt: 'secret brief',
        imageBytes: bytes,
      );
      next.close();
    },
  );
  test(
    '404 before acceptance reuses the same persisted idempotency key',
    () async {
      String? id;
      final bytes = Uint8List.fromList([1]);
      final first = client(
        MockClient((request) async {
          id = request.headers['Idempotency-Key'];
          throw http.ClientException('offline');
        }),
      );
      await expectLater(
        first.run(kind: 'room', projectId: 'p', imageBytes: bytes),
        throwsA(isA<http.ClientException>()),
      );
      first.close();
      final second = client(
        MockClient((request) async {
          if (request.method == 'GET') {
            return http.Response('{"code":"OPERATION_NOT_FOUND"}', 404);
          }
          expect(request.headers['Idempotency-Key'], id);
          return success();
        }),
      );
      await second.run(kind: 'room', projectId: 'p', imageBytes: bytes);
      second.close();
    },
  );
  test(
    'Unresolved request cannot be silently replaced with changed inputs',
    () async {
      final first = client(
        MockClient(
          (_) async => http.Response(
            '{"status":"requires_review","error":"Review needed"}',
            200,
          ),
        ),
      );
      await expectLater(
        first.run(
          kind: 'room',
          projectId: 'p',
          imageBytes: Uint8List.fromList([1]),
        ),
        throwsA(isA<AiApiException>()),
      );
      first.close();
      final second = client(
        MockClient((request) async {
          expect(request.method, 'GET');
          return http.Response('{"status":"requires_review"}', 200);
        }),
      );
      await expectLater(
        second.run(
          kind: 'room',
          projectId: 'p',
          imageBytes: Uint8List.fromList([2]),
        ),
        throwsA(isA<AiApiException>()),
      );
      second.close();
    },
  );
  test(
    'Auth switch, missing project and missing API config cannot submit a paid request',
    () async {
      var calls = 0;
      final transport = MockClient((_) async {
        calls++;
        return success();
      });
      final api = client(transport, current: () => false);
      await expectLater(
        api.run(kind: 'room', projectId: 'p', imageBytes: Uint8List(1)),
        throwsA(isA<AiApiException>()),
      );
      await expectLater(
        api.run(kind: 'room', imageBytes: Uint8List(1)),
        throwsA(isA<AiApiException>()),
      );
      api.close();
      expect(calls, 0);
      final unconfigured = AiBackendClient(
        userId: 'alice',
        getToken: () async => 'test',
        isCurrentUser: () => true,
        baseUrl: '',
      );
      await expectLater(
        unconfigured.run(
          kind: 'room',
          projectId: 'p',
          imageBytes: Uint8List(1),
        ),
        throwsA(isA<AiApiException>()),
      );
      unconfigured.close();
    },
  );
  test('401 is surfaced without an automatic paid retry', () async {
    var calls = 0;
    final api = client(
      MockClient((_) async {
        calls++;
        return http.Response('{"error":"Sign in again"}', 401);
      }),
    );
    await expectLater(
      api.run(kind: 'room', projectId: 'p', imageBytes: Uint8List(1)),
      throwsA(isA<AiApiException>()),
    );
    expect(calls, 1);
    api.close();
  });
  test(
    'Canonical duplicate operation ID is used for subsequent polling',
    () async {
      final api = client(
        MockClient((request) async {
          if (request.method == 'POST') {
            return http.Response(
              '{"operationId":"canonical-operation-123456","status":"processing"}',
              202,
            );
          }
          expect(request.url.path, '/operations/canonical-operation-123456');
          return success();
        }),
      );
      await api.run(kind: 'room', projectId: 'p', imageBytes: Uint8List(1));
      api.close();
    },
  );
  test(
    'Concurrent calls across clients cannot overwrite the pending key in one app',
    () async {
      final response = Completer<http.Response>();
      final first = client(MockClient((_) => response.future));
      var secondCalls = 0;
      final second = client(
        MockClient((_) async {
          secondCalls++;
          return success();
        }),
      );
      final pending = first.run(
        kind: 'room',
        projectId: 'p',
        imageBytes: Uint8List(1),
      );
      await expectLater(
        second.run(kind: 'room', projectId: 'p', imageBytes: Uint8List(1)),
        throwsA(isA<AiApiException>()),
      );
      response.complete(success());
      await pending;
      expect(secondCalls, 0);
      first.close();
      second.close();
    },
  );
}
