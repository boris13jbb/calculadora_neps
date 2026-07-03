import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

const _region = 'us-central1';

/// Llama a una Cloud Function callable por HTTP con token Bearer explícito.
///
/// Evita fallos del SDK nativo/web donde `request.auth` llega vacío aunque
/// Firebase Auth tenga sesión activa (común en Android).
Future<Map<String, dynamic>?> postCallableFunction(
  String name,
  Map<String, dynamic> data,
) async {
  final projectId = Firebase.app().options.projectId;
  if (projectId.isEmpty) return null;

  final user = FirebaseAuth.instanceFor(app: Firebase.app()).currentUser;
  if (user == null) {
    throw FirebaseFunctionsException(
      code: 'unauthenticated',
      message: 'Debe iniciar sesión nuevamente.',
    );
  }

  final idToken = await user.getIdToken(true);
  if (idToken == null || idToken.isEmpty) {
    throw FirebaseFunctionsException(
      code: 'unauthenticated',
      message: 'Debe iniciar sesión nuevamente.',
    );
  }

  final url = Uri.parse(
    'https://$_region-$projectId.cloudfunctions.net/$name',
  );

  final response = await http.post(
    url,
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $idToken',
    },
    body: jsonEncode({'data': data}),
  );

  dynamic decoded;
  try {
    decoded =
        response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);
  } catch (_) {
    decoded = null;
  }

  final body = decoded is Map ? Map<String, dynamic>.from(decoded) : null;
  if (body != null && body.containsKey('error')) {
    final error = Map<String, dynamic>.from(body['error'] as Map);
    throw FirebaseFunctionsException(
      code: _mapErrorCode(error['status']?.toString() ?? 'UNKNOWN'),
      message: error['message']?.toString() ?? 'Error en $name',
      details: error['details'],
    );
  }

  if (response.statusCode < 200 || response.statusCode >= 300) {
    debugPrint(
      'Callable HTTP $name -> ${response.statusCode}: ${response.body}',
    );
    throw FirebaseFunctionsException(
      code: 'unknown',
      message: 'Error HTTP ${response.statusCode} en $name.',
      details: response.body,
    );
  }

  if (body == null) {
    throw FirebaseFunctionsException(
      code: 'internal',
      message: 'Respuesta inválida de $name.',
      details: response.body,
    );
  }

  final result = body.containsKey('result') ? body['result'] : body['data'];
  if (result is Map) {
    return Map<String, dynamic>.from(result);
  }
  return {};
}

String _mapErrorCode(String status) {
  return status.toLowerCase().replaceAll('_', '-');
}
