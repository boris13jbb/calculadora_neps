import 'report_configuration.dart';

/// Plantilla guardada de configuración de reporte.
class ReportTemplate {
  ReportTemplate({
    required this.id,
    required this.name,
    this.description = '',
    required this.configuration,
    this.isGlobal = false,
    this.createdByUid,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  final String id;
  String name;
  String description;
  ReportConfiguration configuration;
  bool isGlobal;
  String? createdByUid;
  DateTime createdAt;
  DateTime updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'configuration': configuration.toJson(),
        'isGlobal': isGlobal,
        if (createdByUid != null) 'createdByUid': createdByUid,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory ReportTemplate.fromJson(Map<String, dynamic> json) {
    return ReportTemplate(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      configuration: ReportConfiguration.fromJson(
        Map<String, dynamic>.from(json['configuration'] as Map? ?? {}),
      ),
      isGlobal: json['isGlobal'] == true,
      createdByUid: json['createdByUid']?.toString(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
    );
  }
}
