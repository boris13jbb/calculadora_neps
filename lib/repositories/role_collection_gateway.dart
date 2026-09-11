import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants.dart';
import '../utils/firestore_json_helper.dart';

/// Acceso a `workspaces/{id}/roles`. Las lecturas no crean documentos.
abstract class RoleCollectionGateway {
  Future<List<Map<String, dynamic>>> listDocuments();

  Future<Map<String, dynamic>?> getDocument(String id);

  Future<void> setDocument(
    String id,
    Map<String, dynamic> data, {
    bool merge = false,
  });
}

class FirestoreRoleCollectionGateway implements RoleCollectionGateway {
  FirestoreRoleCollectionGateway(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _rolesRef => _firestore
      .collection('workspaces')
      .doc(cloudWorkspaceId)
      .collection('roles');

  @override
  Future<List<Map<String, dynamic>>> listDocuments() async {
    final snap = await _rolesRef.get();
    return snap.docs.map(_fromSnapshot).toList();
  }

  @override
  Future<Map<String, dynamic>?> getDocument(String id) async {
    final doc = await _rolesRef.doc(id).get();
    if (!doc.exists || doc.data() == null) return null;
    return _fromSnapshot(doc);
  }

  @override
  Future<void> setDocument(
    String id,
    Map<String, dynamic> data, {
    bool merge = false,
  }) {
    if (merge) {
      return _rolesRef.doc(id).set(data, SetOptions(merge: true));
    }
    return _rolesRef.doc(id).set(data);
  }

  Map<String, dynamic> _fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = FirestoreJsonHelper.normalizeMap(doc.data() ?? {});
    data['code'] ??= doc.id;
    return data;
  }
}
