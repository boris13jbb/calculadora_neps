import '../core/constants.dart';

class NepRecord {
  String id;
  String telar;
  double neps;
  String tela;
  String loteTrama;
  DateTime createdAt;

  NepRecord({
    required this.telar,
    required this.neps,
    String? id,
    this.tela = '',
    this.loteTrama = '',
    DateTime? createdAt,
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        createdAt = createdAt ?? DateTime.now();

  double get mtsCalculados => neps / testLengthM;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'telar': telar,
      'neps': neps,
      'tela': tela,
      'loteTrama': loteTrama,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory NepRecord.fromJson(Map<String, dynamic> json) {
    return NepRecord(
      id: json['id']?.toString(),
      telar: json['telar']?.toString() ?? '',
      neps: double.tryParse(json['neps'].toString()) ?? 0,
      tela: json['tela']?.toString() ?? '',
      loteTrama: json['loteTrama']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}
