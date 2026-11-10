import 'package:calculadora_neps/models/nep_record.dart';
import 'package:calculadora_neps/services/personal_session_archive_service.dart';
import 'package:calculadora_neps/services/personal_session_firestore_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  PersonalCaptureSessionArchive archive({
    required String id,
    required String ownerUid,
    required DateTime savedAt,
    String sessionId = 'ses-1',
    String name = 'Sesión',
  }) {
    return PersonalCaptureSessionArchive(
      id: id,
      ownerUid: ownerUid,
      captureSessionId: sessionId,
      savedAt: savedAt,
      name: name,
      records: [
        NepRecord(
          id: 'rec-$id',
          telar: '10',
          neps: 4,
          createdByUid: ownerUid,
          captureSessionId: sessionId,
        ),
      ],
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Fusión de archivos personales', () {
    test('conserva sesiones distintas del teléfono y de la web', () {
      final phone = archive(
        id: 'ps-phone',
        ownerUid: 'uid-a',
        savedAt: DateTime.utc(2026, 11, 10, 12),
        name: 'Teléfono',
      );
      final web = archive(
        id: 'ps-web',
        ownerUid: 'uid-a',
        savedAt: DateTime.utc(2026, 11, 10, 13),
        name: 'Web',
      );

      final merged = mergePersonalSessionArchives(
        uid: 'uid-a',
        local: [phone],
        remote: [web],
      );

      expect(merged.map((item) => item.id), ['ps-web', 'ps-phone']);
    });

    test('el guardado más reciente gana si el id coincide', () {
      final older = archive(
        id: 'ps-1',
        ownerUid: 'uid-a',
        savedAt: DateTime.utc(2026, 11, 1),
        name: 'Vieja',
      );
      final newer = archive(
        id: 'ps-1',
        ownerUid: 'uid-a',
        savedAt: DateTime.utc(2026, 11, 10),
        name: 'Nueva',
      );

      final merged = mergePersonalSessionArchives(
        uid: 'uid-a',
        local: [older],
        remote: [newer],
      );

      expect(merged, hasLength(1));
      expect(merged.single.name, 'Nueva');
    });

    test('ignora archivos de otra cuenta', () {
      final foreign = archive(
        id: 'ps-b',
        ownerUid: 'uid-b',
        savedAt: DateTime.utc(2026, 11, 10),
      );

      final merged = mergePersonalSessionArchives(
        uid: 'uid-a',
        local: const [],
        remote: [foreign],
      );

      expect(merged, isEmpty);
    });
  });

  group('Sincronización local y nube', () {
    test('trae a este dispositivo la sesión guardada en la otra plataforma',
        () async {
      final remote = _MemoryPersonalSessionCloud();
      final webArchive = archive(
        id: 'ps-phone',
        ownerUid: 'uid-a',
        savedAt: DateTime.utc(2026, 11, 10, 8),
        name: 'Desde el teléfono',
      );
      await remote.upsert(webArchive);

      final service = PersonalSessionArchiveService(cloud: remote);
      final loaded = await service.loadSynced('uid-a');

      expect(loaded.single.name, 'Desde el teléfono');
      expect(
        (await service.loadForUid('uid-a')).single.id,
        'ps-phone',
      );
    });

    test('sube la sesión que solo existe en este dispositivo', () async {
      final remote = _MemoryPersonalSessionCloud();
      final service = PersonalSessionArchiveService(cloud: remote);
      final localOnly = archive(
        id: 'ps-local',
        ownerUid: 'uid-a',
        savedAt: DateTime.utc(2026, 11, 10, 9),
        name: 'Solo teléfono',
      );

      await service.upsert(localOnly);
      final loaded = await service.loadSynced('uid-a');

      expect(loaded.single.id, 'ps-local');
      expect((await remote.fetchForUid('uid-a')).single.name, 'Solo teléfono');
    });

    test('si la nube falla, el archivo local no se pierde', () async {
      final remote = _MemoryPersonalSessionCloud()..fail = true;
      final service = PersonalSessionArchiveService(cloud: remote);
      final localOnly = archive(
        id: 'ps-offline',
        ownerUid: 'uid-a',
        savedAt: DateTime.utc(2026, 11, 10, 10),
      );

      await service.upsert(localOnly);
      final loaded = await service.loadSynced('uid-a');

      expect(loaded.single.id, 'ps-offline');
      expect(remote.byId, isEmpty);
      expect(service.lastCloudPushFailed, isTrue);
    });

    test('el mismo id conserva el snapshot más reciente completo', () {
      NepRecord record(String id) => NepRecord(
            id: id,
            telar: '1',
            neps: 2,
            createdByUid: 'uid-a',
            captureSessionId: 'ses-1',
          );
      final older = PersonalCaptureSessionArchive(
        id: 'ps-1',
        ownerUid: 'uid-a',
        captureSessionId: 'ses-1',
        savedAt: DateTime.utc(2026, 11, 1),
        records: [record('a'), record('b'), record('c')],
      );
      final newer = PersonalCaptureSessionArchive(
        id: 'ps-1',
        ownerUid: 'uid-a',
        captureSessionId: 'ses-1',
        savedAt: DateTime.utc(2026, 11, 10),
        records: [record('z')],
      );

      final merged = mergePersonalSessionArchives(
        uid: 'uid-a',
        local: [older],
        remote: [newer],
      );

      expect(merged.single.records.map((item) => item.id), ['z']);
    });
  });

  group('Tamaño de sesión y páginas', () {
    List<Map<String, dynamic>> maps(int count) => [
          for (var i = 0; i < count; i++) {'id': 'r$i', 'neps': 1},
        ];

    test('400 registros caben en el documento de la sesión', () {
      final plan = planPersonalSessionChunks(maps(400));
      expect(plan.inline, isTrue);
      expect(plan.chunks.single, hasLength(400));
    });

    test('401 registros se parten sin perder ninguno', () {
      final plan = planPersonalSessionChunks(maps(401));
      expect(plan.inline, isFalse);
      expect(plan.chunks.map((chunk) => chunk.length), [400, 1]);
      expect(
        plan.chunks.expand((chunk) => chunk).length,
        401,
      );
    });

    test('una página de 100 no cierra la descarga; una menor sí', () {
      expect(personalSessionPageCompletesFetch(100), isFalse);
      expect(personalSessionPageCompletesFetch(99), isTrue);
      expect(personalSessionPageCompletesFetch(0), isTrue);
    });

    test('faltan fragmentos: no se reconstruye una sesión parcial', () {
      final complete = archiveFromCloudParts(
        docId: 'ps-1',
        parent: {
          'ownerUid': 'uid-a',
          'captureSessionId': 'ses-1',
          'name': 'Grande',
          'savedAt': '2026-11-10T12:00:00.000Z',
          'records': <dynamic>[],
          'chunkCount': 2,
        },
        chunksByIndex: {
          0: maps(400),
          1: maps(1),
        },
      );
      expect(complete, isNotNull);
      expect(complete!.records, hasLength(401));

      final partial = archiveFromCloudParts(
        docId: 'ps-1',
        parent: {
          'ownerUid': 'uid-a',
          'captureSessionId': 'ses-1',
          'name': 'Grande',
          'savedAt': '2026-11-10T12:00:00.000Z',
          'records': <dynamic>[],
          'chunkCount': 2,
        },
        chunksByIndex: {
          0: maps(400),
        },
      );
      expect(partial, isNull);
    });
  });
}

class _MemoryPersonalSessionCloud implements PersonalSessionCloudPort {
  final Map<String, PersonalCaptureSessionArchive> byId = {};
  bool fail = false;

  @override
  Future<List<PersonalCaptureSessionArchive>> fetchForUid(String uid) async {
    if (fail) throw StateError('sin red');
    return byId.values.where((item) => item.ownerUid == uid).toList();
  }

  @override
  Future<void> upsert(PersonalCaptureSessionArchive archive) async {
    if (fail) throw StateError('sin red');
    byId[archive.id] = archive;
  }
}
