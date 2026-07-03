import 'package:cloud_firestore/cloud_firestore.dart';

/// Normaliza valores de Firestore / Cloud Functions a tipos seguros en web.
class FirestoreJsonHelper {
  static Map<String, dynamic> normalizeMap(Map<String, dynamic> raw) {
    return raw.map(
      (key, value) => MapEntry(key, normalizeValue(value)),
    );
  }

  static dynamic normalizeValue(dynamic value) {
    if (value == null) return null;

    if (_isFixnumInt64(value)) {
      return int.tryParse(value.toString()) ?? value.toString();
    }

    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      if (_isTimestampMap(map)) {
        return _timestampMapToIso(map);
      }
      return normalizeMap(map);
    }

    if (value is List) {
      return value.map(normalizeValue).toList();
    }

    if (value is Timestamp) {
      return _timestampToIso(value);
    }

    if (value is DateTime) {
      return value.toIso8601String();
    }

    return value;
  }

  /// Convierte cualquier respuesta de callable a estructura JSON segura.
  static Map<String, dynamic> normalizeCallableRoot(dynamic data) {
    final normalized = normalizeValue(data);
    if (normalized is Map) {
      return Map<String, dynamic>.from(normalized);
    }
    return {};
  }

  static bool _isFixnumInt64(dynamic value) {
    return value.runtimeType.toString() == 'Int64';
  }

  static String _timestampToIso(Timestamp value) {
    try {
      return value.toDate().toIso8601String();
    } catch (_) {
      return '';
    }
  }

  static bool _isTimestampMap(Map<String, dynamic> map) {
    if (map.length > 4) return false;
    final seconds = map['_seconds'] ?? map['seconds'];
    final nanoseconds = map['_nanoseconds'] ?? map['nanoseconds'];
    return seconds != null && nanoseconds != null;
  }

  static String _timestampMapToIso(Map<String, dynamic> map) {
    final seconds = map['_seconds'] ?? map['seconds'];
    final nanoseconds = map['_nanoseconds'] ?? map['nanoseconds'];
    final millis = _toInt(seconds) * 1000 + (_toInt(nanoseconds) ~/ 1000000);
    return DateTime.fromMillisecondsSinceEpoch(millis).toIso8601String();
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (_isFixnumInt64(value)) {
      return int.tryParse(value.toString()) ?? 0;
    }
    return int.tryParse(value.toString()) ?? 0;
  }
}
