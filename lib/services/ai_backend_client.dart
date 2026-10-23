import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AiApiException implements Exception {
  const AiApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class AiBackendResult {
  const AiBackendResult(this.bytes, this.mimeType);
  final Uint8List bytes;
  final String mimeType;
}

/// Only the transport changes in stage 3 part 1; the AI Studio UI is unchanged.
/// Persist an unresolved request ID (never a token/photo/prompt) across reloads.
class AiBackendClient {
  AiBackendClient({
    required this.userId,
    required this.getToken,
    required this.isCurrentUser,
    http.Client? client,
    String? baseUrl,
    this.waitTimeout = const Duration(seconds: 210),
    this.pollDelay = const Duration(seconds: 2),
  }) : _client = client ?? http.Client(),
       _baseUrl = baseUrl ?? const String.fromEnvironment('API_BASE_URL');
  static final Set<String> _activeCalls = {};
  final String userId;
  final Future<String?> Function() getToken;
  final bool Function() isCurrentUser;
  final http.Client _client;
  final String _baseUrl;
  final Duration waitTimeout;
  final Duration pollDelay;
  void close() => _client.close();

  Uri _url(String path) {
    final base = Uri.tryParse(_baseUrl);
    if (base == null ||
        !base.hasAuthority ||
        base.userInfo.isNotEmpty ||
        base.hasQuery ||
        base.hasFragment ||
        !['', '/'].contains(base.path) ||
        !(base.scheme == 'https' ||
            base.scheme == 'http' &&
                ['localhost', '127.0.0.1', '10.0.2.2'].contains(base.host))) {
      throw const AiApiException(
        'Адрес AI-сервиса не настроен. Обратитесь к администратору.',
      );
    }
    return base.replace(path: path);
  }

  Future<Map<String, String>> _headers() async {
    if (!isCurrentUser()) {
      throw const AiApiException('Аккаунт изменился. Войдите снова.');
    }
    final token = await getToken().timeout(const Duration(seconds: 20));
    if (!isCurrentUser() || token == null || token.isEmpty) {
      throw const AiApiException('Войдите в аккаунт для использования AI.');
    }
    return {'Authorization': 'Bearer $token'};
  }

  Future<Map<String, dynamic>> _response(http.StreamedResponse response) async {
    Future<Uint8List> collect() async {
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in response.stream) {
        if (bytes.length + chunk.length > 1024 * 1024) {
          throw const AiApiException('Ответ AI-сервиса слишком большой.');
        }
        bytes.add(chunk);
      }
      return bytes.takeBytes();
    }

    return _decode(
      response.statusCode,
      await collect().timeout(const Duration(seconds: 30)),
    );
  }

  Future<Map<String, dynamic>?> _status(String id) async {
    final request = http.Request('GET', _url('/operations/$id'))
      ..followRedirects = false;
    request.headers.addAll(await _headers());
    final response = await _client
        .send(request)
        .timeout(const Duration(seconds: 30));
    if (response.statusCode == 404) {
      await response.stream.listen((_) {}).cancel();
      return null;
    }
    return _response(response);
  }

  Map<String, dynamic> _decode(int code, List<int> bytes) {
    if (bytes.length > 1024 * 1024) {
      throw const AiApiException('Ответ AI-сервиса слишком большой.');
    }
    Map<String, dynamic> data;
    try {
      data = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    } catch (_) {
      throw const AiApiException(
        'AI-сервис вернул некорректный ответ. Повторите тот же запрос позже.',
      );
    }
    if (code < 200 || code >= 300) {
      throw AiApiException(
        data['error'] is String
            ? data['error'] as String
            : 'AI-сервис временно недоступен.',
      );
    }
    return data;
  }

  bool _terminal(Map<String, dynamic> data) =>
      ['succeeded', 'failed', 'canceled'].contains(data['status']);

  Future<AiBackendResult> run({
    required String kind,
    required Uint8List imageBytes,
    String filename = 'room.jpg',
    String? projectId,
    String prompt = '',
    String style = '',
  }) async {
    // UX guard only. The authoritative charge protection is the server ledger.
    final lock = '$userId:$kind';
    if (!_activeCalls.add(lock)) {
      throw const AiApiException(
        'AI-запрос уже выполняется. Дождитесь результата.',
      );
    }
    try {
      return await _run(
        kind: kind,
        imageBytes: imageBytes,
        filename: filename,
        projectId: projectId,
        prompt: prompt,
        style: style,
      );
    } finally {
      _activeCalls.remove(lock);
    }
  }

  Future<AiBackendResult> _run({
    required String kind,
    required Uint8List imageBytes,
    String filename = 'room.jpg',
    String? projectId,
    String prompt = '',
    String style = '',
  }) async {
    if (!['room', 'background'].contains(kind)) throw ArgumentError.value(kind);
    _url('/');
    if (kind == 'room' && (projectId == null || projectId.isEmpty)) {
      throw const AiApiException(
        'Сначала создайте или откройте проект в личном кабинете.',
      );
    }
    final hash = sha256
        .convert(
          utf8.encode(
            jsonEncode([
              kind,
              projectId,
              prompt.trim(),
              style,
              base64Encode(imageBytes),
            ]),
          ),
        )
        .toString();
    final prefs = await SharedPreferences.getInstance();
    final storageKey = 'roomcraft_ai_pending_${userId}_$kind';
    String? id;
    Map<String, dynamic>? status;
    final raw = prefs.getString(storageKey);
    if (raw != null) {
      Map<String, dynamic> pending;
      try {
        pending = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        throw const AiApiException(
          'Не удалось прочитать ID предыдущего запроса. Обратитесь к администратору.',
        );
      }
      id = pending['id'] as String;
      status = await _status(id);
      if (pending['hash'] != hash) {
        if (status != null && !_terminal(status)) {
          throw const AiApiException(
            'Предыдущий AI-запрос ещё выполняется или требует проверки. Не запускайте новый запрос.',
          );
        }
        id = null;
        status = null;
      }
    }
    id ??= List.generate(
      24,
      (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    if (!await prefs.setString(
      storageKey,
      jsonEncode({'id': id, 'hash': hash}),
    )) {
      throw const AiApiException(
        'Не удалось сохранить ID запроса. Генерация не отправлена.',
      );
    }
    final deadline = DateTime.now().add(waitTimeout);
    if (status == null) {
      final request = http.MultipartRequest(
        'POST',
        _url(kind == 'room' ? '/generate-room' : '/remove-background'),
      );
      request.followRedirects = false;
      request.headers.addAll({...await _headers(), 'Idempotency-Key': id});
      if (projectId != null) request.fields['projectId'] = projectId;
      if (kind == 'room') {
        request.fields['prompt'] = prompt.trim();
        request.fields['style'] = style;
      }
      request.files.add(
        http.MultipartFile.fromBytes('image', imageBytes, filename: filename),
      );
      final response = await _client
          .send(request)
          .timeout(const Duration(seconds: 30));
      status = await _response(response);
      final canonicalId = status['operationId'];
      if (canonicalId is String &&
          RegExp(r'^[a-zA-Z0-9_-]{16,128}$').hasMatch(canonicalId)) {
        id = canonicalId;
        if (!await prefs.setString(
          storageKey,
          jsonEncode({'id': id, 'hash': hash}),
        )) {
          throw const AiApiException(
            'Не удалось сохранить ID принятого запроса. Не запускайте новый запрос; обратитесь к администратору.',
          );
        }
      }
    }
    while (true) {
      if (!isCurrentUser()) {
        throw const AiApiException(
          'Аккаунт изменился. Откройте проект заново.',
        );
      }
      if (status!['status'] == 'succeeded') {
        final encoded = status['imageBase64'];
        final mime = status['mimeType'];
        if (encoded is! String || !['image/jpeg', 'image/png'].contains(mime)) {
          throw const AiApiException(
            'Не удалось получить изображение. Повторите тот же запрос.',
          );
        }
        final bytes = base64Decode(encoded);
        if (bytes.isEmpty || bytes.length > 400000) {
          throw const AiApiException('Некорректное изображение в ответе AI.');
        }
        await prefs.remove(storageKey);
        return AiBackendResult(bytes, mime as String);
      }
      if (_terminal(status)) {
        await prefs.remove(storageKey);
        throw AiApiException(
          status['error'] as String? ?? 'AI не смог обработать изображение.',
        );
      }
      if (status['status'] == 'requires_review') {
        throw AiApiException(
          status['error'] as String? ??
              'Запрос требует проверки администратором.',
        );
      }
      if (DateTime.now().isAfter(deadline)) {
        throw const AiApiException(
          'Ожидание AI затянулось. Повторите тот же запрос — его ID сохранён.',
        );
      }
      await Future<void>.delayed(pollDelay);
      status = await _status(id);
      if (status == null) {
        throw const AiApiException(
          'Не удалось найти принятый запрос. Повторите тот же запрос позже.',
        );
      }
    }
  }
}
