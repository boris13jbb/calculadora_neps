/// Tombstone remoto/local de un registro eliminado (delete-wins).
class RecordTombstone {
  const RecordTombstone({
    required this.recordId,
    required this.ownerUid,
    required this.deletedByUid,
    required this.deletedAt,
  });

  final String recordId;
  final String ownerUid;
  final String deletedByUid;
  final DateTime deletedAt;

  Map<String, dynamic> toJson() => {
        'recordId': recordId,
        'ownerUid': ownerUid,
        'deletedByUid': deletedByUid,
        'deletedAt': deletedAt.toIso8601String(),
      };

  factory RecordTombstone.fromJson(Map<String, dynamic> json) {
    return RecordTombstone(
      recordId: json['recordId']?.toString() ?? '',
      ownerUid: json['ownerUid']?.toString() ?? '',
      deletedByUid: json['deletedByUid']?.toString() ?? '',
      deletedAt: DateTime.tryParse(json['deletedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
