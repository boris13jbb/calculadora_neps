import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Logs de depuracion para sesion agente (NDJSON via ingest HTTP).
class AgentDebugLog {
  AgentDebugLog._();

  static const _endpoint =
      'http://127.0.0.1:7251/ingest/52b3d315-adf4-4dd1-9fb9-835a72beaf88';
  static const _sessionId = '63da50';

  // #region agent log
  static void write({
    required String location,
    required String message,
    required String hypothesisId,
    Map<String, dynamic>? data,
    String runId = 'pre-fix',
  }) {
    final payload = <String, dynamic>{
      'sessionId': _sessionId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'location': location,
      'message': message,
      'hypothesisId': hypothesisId,
      'data': data ?? <String, dynamic>{},
      'runId': runId,
    };

    final line = '${jsonEncode(payload)}\n';

    try {
      File(r'd:\DOCUMENTOS\regneps\debug-63da50.log').writeAsStringSync(
        line,
        mode: FileMode.append,
        flush: true,
      );
    } catch (_) {}

    unawaited(() async {
      try {
        final client = HttpClient();
        final request = await client.postUrl(Uri.parse(_endpoint));
        request.headers.set('Content-Type', 'application/json');
        request.headers.set('X-Debug-Session-Id', _sessionId);
        request.write(jsonEncode(payload));
        await request.close();
        client.close(force: true);
      } catch (_) {}
    }());
  }
  // #endregion
}
