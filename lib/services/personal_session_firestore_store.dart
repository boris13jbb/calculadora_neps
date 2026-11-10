import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants.dart';
import 'personal_session_archive_service.dart';

/// Registros por documento. Firestore limita cada documento a 1 MiB.
const int personalSessionRecordsPerDocument = 400;

/// Página de la consulta. Se recorre completa; no es un tope de historial.
const int personalSessionFetchPageSize = 100;

/// Tope de fragmentos por sesión (400 × 50). Por encima no se escribe nada.
const int personalSessionMaxChunks = 50;

/// Plan de escritura: una sesión cabe en el documento o se parte en fragmentos.
class PersonalSessionChunkPlan {
  const PersonalSessionChunkPlan({
    required this.chunks,
    required this.inline,
  });

  final List<List<Map<String, dynamic>>> chunks;

  /// True si [chunks] es un único bloque que vive en el documento padre.
  final bool inline;
}

/// Parte los registros sin descartar ninguno.
///
/// 400 o menos quedan en el documento de la sesión. 401 o más se parten en
/// bloques de 400. Si hicieran falta más de [personalSessionMaxChunks]
/// bloques, lanza y no escribe una parte como si fuera la sesión completa.
PersonalSessionChunkPlan planPersonalSessionChunks(
  List<Map<String, dynamic>> records,
) {
  if (records.length <= personalSessionRecordsPerDocument) {
    return PersonalSessionChunkPlan(chunks: [records], inline: true);
  }

  final chunks = <List<Map<String, dynamic>>>[];
  for (var start = 0;
      start < records.length;
      start += personalSessionRecordsPerDocument) {
    final end = start + personalSessionRecordsPerDocument > records.length
        ? records.length
        : start + personalSessionRecordsPerDocument;
    chunks.add(records.sublist(start, end));
  }
  if (chunks.length > personalSessionMaxChunks) {
    throw ArgumentError(
      'La sesión tiene demasiados registros para sincronizarla '
      '(${records.length}). Quedó guardada en este dispositivo.',
    );
  }
  return PersonalSessionChunkPlan(chunks: chunks, inline: false);
}

/// La última página incompleta indica que ya no hay más sesiones.
bool personalSessionPageCompletesFetch(
  int pageLength, {
  int pageSize = personalSessionFetchPageSize,
}) {
  return pageLength < pageSize;
}

/// Reconstruye la sesión. Devuelve null si faltan fragmentos: no se presenta
/// una copia parcial como sesión completa.
PersonalCaptureSessionArchive? archiveFromCloudParts({
  required Map<String, dynamic> parent,
  required String docId,
  Map<int, List<dynamic>>? chunksByIndex,
}) {
  final data = Map<String, dynamic>.from(parent);
  data['id'] = docId;
  final savedAt = data['savedAt'];
  if (savedAt is Timestamp) {
    data['savedAt'] = savedAt.toDate().toIso8601String();
  }

  final chunkCount = data['chunkCount'];
  if (chunkCount is int && chunkCount > 1) {
    final parts = chunksByIndex;
    if (parts == null) return null;
    final records = <dynamic>[];
    for (var index = 0; index < chunkCount; index++) {
      final part = parts[index];
      if (part == null || part.isEmpty) return null;
      records.addAll(part);
    }
    data['records'] = records;
    data.remove('chunkCount');
  }

  return PersonalCaptureSessionArchive.fromJson(data);
}

/// Sesiones personales en `workspaces/vicunha/users/{uid}/personalSessions`.
class PersonalSessionFirestoreStore implements PersonalSessionCloudPort {
  PersonalSessionFirestoreStore({FirebaseFirestore? firestore})
      : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _collection(String uid) {
    return _db
        .collection('workspaces')
        .doc(cloudWorkspaceId)
        .collection('users')
        .doc(uid)
        .collection('personalSessions');
  }

  @override
  Future<List<PersonalCaptureSessionArchive>> fetchForUid(String uid) async {
    final trimmed = uid.trim();
    if (trimmed.isEmpty) return const [];

    final docs = await _loadAllSessionDocs(trimmed);
    final archives = <PersonalCaptureSessionArchive>[];
    for (final doc in docs) {
      final archive = await _archiveFromDoc(doc);
      if (archive == null || archive.ownerUid != trimmed) continue;
      archives.add(archive);
    }
    return archives;
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _loadAllSessionDocs(
    String uid,
  ) async {
    final docs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    QueryDocumentSnapshot<Map<String, dynamic>>? cursor;
    while (true) {
      Query<Map<String, dynamic>> query = _collection(uid)
          .orderBy('savedAt', descending: true)
          .limit(personalSessionFetchPageSize);
      if (cursor != null) {
        query = query.startAfterDocument(cursor);
      }
      final snapshot = await query.get();
      if (snapshot.docs.isEmpty) return docs;
      docs.addAll(snapshot.docs);
      if (personalSessionPageCompletesFetch(snapshot.docs.length)) {
        return docs;
      }
      cursor = snapshot.docs.last;
    }
  }

  Future<PersonalCaptureSessionArchive?> _archiveFromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();
    final chunkCount = data['chunkCount'];
    Map<int, List<dynamic>>? chunksByIndex;
    if (chunkCount is int && chunkCount > 1) {
      final chunkSnap = await doc.reference.collection('chunks').get();
      chunksByIndex = <int, List<dynamic>>{};
      for (final chunk in chunkSnap.docs) {
        final index = chunk.data()['index'];
        final records = chunk.data()['records'];
        if (index is int && records is List) {
          chunksByIndex[index] = records;
        }
      }
    }
    return archiveFromCloudParts(
      parent: data,
      docId: doc.id,
      chunksByIndex: chunksByIndex,
    );
  }

  @override
  Future<void> upsert(PersonalCaptureSessionArchive archive) async {
    final uid = archive.ownerUid.trim();
    final id = archive.id.trim();
    if (uid.isEmpty || id.isEmpty || id.contains('/')) {
      throw ArgumentError('Archivo personal sin identificador válido.');
    }
    final recordMaps = archive.records
        .map((record) => record.toJson())
        .toList(growable: false);
    final plan = planPersonalSessionChunks(recordMaps);
    final parent = <String, dynamic>{
      'id': id,
      'ownerUid': uid,
      'captureSessionId': archive.captureSessionId,
      'name': archive.name,
      'savedAt': Timestamp.fromDate(archive.savedAt.toUtc()),
    };
    final doc = _collection(uid).doc(id);

    if (plan.inline) {
      parent['records'] = plan.chunks.single;
      await doc.set(parent);
      return;
    }

    // Un solo lote: o queda la sesión completa, o no cambia la nube.
    final batch = _db.batch();
    for (var index = 0; index < plan.chunks.length; index++) {
      batch.set(doc.collection('chunks').doc('$index'), {
        'index': index,
        'records': plan.chunks[index],
      });
    }
    parent['records'] = <Map<String, dynamic>>[];
    parent['chunkCount'] = plan.chunks.length;
    batch.set(doc, parent);
    await batch.commit();
  }
}
