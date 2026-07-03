import 'package:flutter_test/flutter_test.dart';

import 'package:calculadora_neps/utils/firestore_json_helper.dart';

void main() {
  group('FirestoreJsonHelper', () {
    test('normaliza mapas con timestamp Firestore (_seconds/_nanoseconds)', () {
      final normalized = FirestoreJsonHelper.normalizeMap({
        'createdAt': {'_seconds': 1710000000, '_nanoseconds': 0},
      });

      expect(normalized['createdAt'], isA<String>());
      expect(DateTime.tryParse(normalized['createdAt'] as String), isNotNull);
    });

    test('normaliza mapas anidados', () {
      final normalized = FirestoreJsonHelper.normalizeMap({
        'user': {
          'updatedAt': {'seconds': 1710000000, 'nanoseconds': 500000000},
        },
      });

      final user = normalized['user'] as Map<String, dynamic>;
      expect(user['updatedAt'], isA<String>());
    });

    test('normaliza raíz de respuesta callable con lista de usuarios', () {
      final normalized = FirestoreJsonHelper.normalizeCallableRoot({
        'users': [
          {
            'uid': 'abc',
            'username': 'operario01',
            'createdAt': {'_seconds': 1710000000, '_nanoseconds': 0},
          },
        ],
      });

      final users = normalized['users'] as List<dynamic>;
      final first = users.first as Map<String, dynamic>;
      expect(first['createdAt'], isA<String>());
    });
  });
}
