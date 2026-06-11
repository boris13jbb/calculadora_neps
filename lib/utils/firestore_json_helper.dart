import 'package:cloud_firestore/cloud_firestore.dart';

/// Normaliza valores de Firestore a tipos serializables por los modelos.
class FirestoreJsonHelper {
  static Map<String, dynamic> normalizeMap(Map<String, dynamic> raw) {
    return raw.map(
      (key, value) => MapEntry(key, normalizeValue(value)),
    );
  }

  static dynamic normalizeValue(dynamic value) {
    if (value is Timestamp) {
      return value.toDate().toIso8601String();
    }
    if (value is DateTime) {
      return value.toIso8601String();
    }
    if (value is Map) {
      return normalizeMap(Map<String, dynamic>.from(value));
    }
    if (value is List) {
      return value.map(normalizeValue).toList();
    }
    return value;
  }
}
