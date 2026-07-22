import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import '../models/report_configuration.dart';
import '../models/report_template.dart';

const String _templatesStorageKey = 'vicunha_report_templates_v1';

/// Persistencia local de plantillas de reporte.
class ReportTemplateRepository {
  ReportTemplateRepository({SharedPreferences? prefs}) : _prefs = prefs;

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _storage async =>
      _prefs ??= await SharedPreferences.getInstance();

  Future<List<ReportTemplate>> loadAll({String? userUid}) async {
    final prefs = await _storage;
    final raw = prefs.getString(_templatesStorageKey);
    if (raw == null || raw.isEmpty) return _builtInTemplates();

    try {
      final list = jsonDecode(raw) as List;
      final templates = list
          .whereType<Map>()
          .map((m) => ReportTemplate.fromJson(Map<String, dynamic>.from(m)))
          .toList();

      final builtIn = _builtInTemplates();
      final userTemplates = templates.where((t) {
        if (t.isGlobal) return true;
        if (userUid == null) return !t.isGlobal;
        return t.createdByUid == userUid;
      }).toList();

      return [...builtIn, ...userTemplates];
    } catch (_) {
      return _builtInTemplates();
    }
  }

  List<ReportTemplate> _builtInTemplates() {
    final templates = <ReportTemplate>[];
    for (final kind in ReportTemplateKind.values) {
      if (kind == ReportTemplateKind.personalizado) continue;
      final config = ReportConfiguration();
      config.applyTemplate(kind);
      templates.add(
        ReportTemplate(
          id: 'builtin_${kind.name}',
          name: kind.label,
          description: 'Plantilla predefinida del sistema',
          configuration: config,
          isGlobal: true,
        ),
      );
    }
    return templates;
  }

  Future<void> save(ReportTemplate template) async {
    final prefs = await _storage;
    final all = await loadAll(userUid: template.createdByUid);
    final updated = all.where((t) => t.id != template.id).toList();
    if (!template.id.startsWith('builtin_')) {
      template.updatedAt = DateTime.now();
      updated.add(template);
    }
    final toSave = updated
        .where((t) => !t.id.startsWith('builtin_'))
        .map((t) => t.toJson())
        .toList();
    await prefs.setString(_templatesStorageKey, jsonEncode(toSave));
  }

  Future<void> delete(String id, {String? userUid}) async {
    if (id.startsWith('builtin_')) return;
    final prefs = await _storage;
    final all = await loadAll(userUid: userUid);
    final updated = all.where((t) => t.id != id).toList();
    final toSave = updated
        .where((t) => !t.id.startsWith('builtin_'))
        .map((t) => t.toJson())
        .toList();
    await prefs.setString(_templatesStorageKey, jsonEncode(toSave));
  }

  Future<bool> nameExists(String name, {String? excludeId}) async {
    final all = await loadAll();
    return all.any(
      (t) =>
          t.name.toLowerCase() == name.toLowerCase().trim() &&
          t.id != excludeId,
    );
  }
}

final reportTemplateRepository = ReportTemplateRepository();
