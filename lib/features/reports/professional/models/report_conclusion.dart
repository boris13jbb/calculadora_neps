/// Hallazgo o conclusión generada por reglas locales.
class ReportFinding {
  const ReportFinding({
    required this.category,
    required this.text,
    this.severity = FindingSeverity.info,
  });

  final String category;
  final String text;
  final FindingSeverity severity;
}

enum FindingSeverity { info, warning, critical }

/// Conclusiones y recomendaciones del reporte.
class ReportConclusion {
  const ReportConclusion({
    this.findings = const [],
    this.autoSummary = '',
    this.editedText = '',
    this.manualRecommendations = '',
    this.enabled = true,
  });

  final List<ReportFinding> findings;
  final String autoSummary;
  final String editedText;
  final String manualRecommendations;
  final bool enabled;

  String get displayText {
    if (editedText.trim().isNotEmpty) return editedText.trim();
    return autoSummary;
  }

  String get fullText {
    final buffer = StringBuffer();
    if (displayText.isNotEmpty) {
      buffer.writeln(displayText);
    }
    if (findings.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Hallazgos:');
      for (final f in findings) {
        buffer.writeln('• ${f.text}');
      }
    }
    if (manualRecommendations.trim().isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Recomendaciones:');
      buffer.writeln(manualRecommendations.trim());
    }
    return buffer.toString().trim();
  }

  ReportConclusion copyWith({
    List<ReportFinding>? findings,
    String? autoSummary,
    String? editedText,
    String? manualRecommendations,
    bool? enabled,
  }) {
    return ReportConclusion(
      findings: findings ?? this.findings,
      autoSummary: autoSummary ?? this.autoSummary,
      editedText: editedText ?? this.editedText,
      manualRecommendations:
          manualRecommendations ?? this.manualRecommendations,
      enabled: enabled ?? this.enabled,
    );
  }
}
