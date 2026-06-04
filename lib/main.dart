import 'dart:convert';
import 'dart:io';

import 'package:excel/excel.dart' as xls;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const NepsApp());
}

const double testLengthM = 0.09;
const int decimals = 0;
const String storageKey = 'vicunha_neps_flutter_exportaciones_v1';

class NepsApp extends StatelessWidget {
  const NepsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VICUNHA Calculadora Neps',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const NepsHomePage(),
    );
  }
}

class NepRecord {
  String telar;
  double neps;

  NepRecord({required this.telar, required this.neps});

  Map<String, dynamic> toJson() {
    return {
      'telar': telar,
      'neps': neps,
    };
  }

  factory NepRecord.fromJson(Map<String, dynamic> json) {
    return NepRecord(
      telar: json['telar']?.toString() ?? '',
      neps: double.tryParse(json['neps'].toString()) ?? 0,
    );
  }
}

class NepsHomePage extends StatefulWidget {
  const NepsHomePage({super.key});

  @override
  State<NepsHomePage> createState() => _NepsHomePageState();
}

class _NepsHomePageState extends State<NepsHomePage> {
  final TextEditingController telarController = TextEditingController();
  final TextEditingController nepsController = TextEditingController();

  List<NepRecord> records = [];
  bool isLoading = true;
  bool isExporting = false;

  @override
  void initState() {
    super.initState();
    nepsController.addListener(() => setState(() {}));
    loadData();
  }

  @override
  void dispose() {
    telarController.dispose();
    nepsController.dispose();
    super.dispose();
  }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedData = prefs.getString(storageKey);

    if (savedData != null && savedData.isNotEmpty) {
      try {
        final List decoded = jsonDecode(savedData);
        records = decoded
            .map((item) => NepRecord.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      } catch (_) {
        records = [];
      }
    } else {
      records = [];
    }

    setState(() => isLoading = false);
  }

  Future<void> saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final data = records.map((e) => e.toJson()).toList();
    await prefs.setString(storageKey, jsonEncode(data));
  }

  double calculateMts(double neps) => neps / testLengthM;

  double parseNumber(String value) {
    return double.tryParse(value.replaceAll(',', '.')) ?? 0;
  }

  String formatNumber(double value) {
    if (decimals == 0) return value.round().toString();
    return value.toStringAsFixed(decimals);
  }

  String formatDecimal(double value) {
    if (value == value.roundToDouble()) return value.round().toString();
    return value.toStringAsFixed(3);
  }

  double get previewValue {
    if (nepsController.text.trim().isEmpty) return 0;
    return calculateMts(parseNumber(nepsController.text));
  }

  double get totalNeps => records.fold(0, (sum, item) => sum + item.neps);

  double get totalMts =>
      records.fold(0, (sum, item) => sum + calculateMts(item.neps));

  double get averageMts => records.isEmpty ? 0 : totalMts / records.length;

  String get timestamp {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }

  Future<Directory> getExportDirectory() async {
    return getTemporaryDirectory();
  }

  void showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> runExport(Future<void> Function() action) async {
    if (records.isEmpty) {
      showMessage('No hay datos para exportar.');
      return;
    }

    if (isExporting) return;

    setState(() => isExporting = true);

    try {
      await action();
    } catch (e) {
      showMessage('Error al exportar: $e');
    } finally {
      if (mounted) setState(() => isExporting = false);
    }
  }

  String escapeCsv(String value) {
    final needsQuotes = value.contains(',') || value.contains('"') || value.contains('\n');
    final escaped = value.replaceAll('"', '""');
    return needsQuotes ? '"$escaped"' : escaped;
  }

  String buildCsvText() {
    final buffer = StringBuffer();
    buffer.writeln('Nro,Telar,Neps,Mts calculados');

    for (int i = 0; i < records.length; i++) {
      final item = records[i];
      final mts = calculateMts(item.neps);
      buffer.writeln([
        (i + 1).toString(),
        escapeCsv(item.telar),
        formatDecimal(item.neps),
        formatNumber(mts),
      ].join(','));
    }

    buffer.writeln([
      '',
      'TOTALES',
      formatDecimal(totalNeps),
      formatNumber(totalMts),
    ].join(','));

    return buffer.toString();
  }

  Future<void> exportCsv() async {
    await runExport(() async {
      final dir = await getExportDirectory();
      final file = File('${dir.path}/reporte_neps_$timestamp.csv');
      await file.writeAsString('\uFEFF${buildCsvText()}', encoding: utf8);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/csv')],
        text: 'Reporte CSV de Neps',
      );
    });
  }

  Future<void> exportExcel() async {
    await runExport(() async {
      final excel = xls.Excel.createExcel();
      const sheetName = 'Reporte Neps';
      final sheet = excel[sheetName];
      excel.setDefaultSheet(sheetName);

      if (excel.sheets.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }

      sheet.appendRow([
        xls.TextCellValue('Nro'),
        xls.TextCellValue('Telar'),
        xls.TextCellValue('Neps'),
        xls.TextCellValue('Mts calculados'),
      ]);

      for (int i = 0; i < records.length; i++) {
        final item = records[i];
        sheet.appendRow([
          xls.IntCellValue(i + 1),
          xls.TextCellValue(item.telar),
          xls.DoubleCellValue(item.neps),
          xls.DoubleCellValue(calculateMts(item.neps)),
        ]);
      }

      sheet.appendRow([
        xls.TextCellValue(''),
        xls.TextCellValue('TOTALES'),
        xls.DoubleCellValue(totalNeps),
        xls.DoubleCellValue(totalMts),
      ]);

      sheet.appendRow([
        xls.TextCellValue(''),
        xls.TextCellValue('PROMEDIO MTS'),
        xls.TextCellValue(''),
        xls.DoubleCellValue(averageMts),
      ]);

      final bytes = excel.encode();
      if (bytes == null) {
        showMessage('No se pudo generar el archivo Excel.');
        return;
      }

      final dir = await getExportDirectory();
      final file = File('${dir.path}/reporte_neps_$timestamp.xlsx');
      await file.writeAsBytes(bytes, flush: true);

      await Share.shareXFiles(
        [
          XFile(
            file.path,
            mimeType:
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          ),
        ],
        text: 'Reporte Excel de Neps',
      );
    });
  }

  Future<Uint8List> buildPdfBytes() async {
    final doc = pw.Document();

    final tableData = records.asMap().entries.map((entry) {
      final i = entry.key;
      final item = entry.value;
      return [
        '${i + 1}',
        item.telar,
        formatDecimal(item.neps),
        formatNumber(calculateMts(item.neps)),
      ];
    }).toList();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) {
          return [
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#1F2A2E'),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'VICUNHA  jeansidentity',
                    style: pw.TextStyle(
                      color: PdfColor.fromHex('#F7EAC5'),
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Calculadora de Neps dividido para 0.09 metros',
                    style: pw.TextStyle(
                      color: PdfColor.fromHex('#CFD8C5'),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 14),
            pw.Text(
              'Formula utilizada: Mts calculados = Neps / 0.09',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Table.fromTextArray(
              headers: ['#', 'Telar', 'Neps', 'Mts calculados'],
              data: tableData,
              headerDecoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#1F2A2E'),
              ),
              headerStyle: pw.TextStyle(
                color: PdfColor.fromHex('#F7EAC5'),
                fontWeight: pw.FontWeight.bold,
              ),
              cellAlignment: pw.Alignment.center,
              cellStyle: const pw.TextStyle(fontSize: 10),
              rowDecoration: pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(
                    color: PdfColor.fromHex('#E4D8BA'),
                    width: 0.5,
                  ),
                ),
              ),
            ),
            pw.SizedBox(height: 14),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#EBDFC3'),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Total registros: ${records.length}'),
                  pw.Text('Total neps: ${formatDecimal(totalNeps)}'),
                  pw.Text('Total mts: ${formatNumber(totalMts)}'),
                  pw.Text('Promedio mts: ${formatNumber(averageMts)}'),
                ],
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Text(
              'Reporte generado desde la aplicacion Calculadora Neps VICUNHA.',
              style: const pw.TextStyle(fontSize: 9),
            ),
          ];
        },
      ),
    );

    return doc.save();
  }

  Future<void> exportPdf() async {
    await runExport(() async {
      final bytes = await buildPdfBytes();
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'reporte_neps_$timestamp.pdf',
      );
    });
  }

  Future<void> printPdf() async {
    await runExport(() async {
      await Printing.layoutPdf(
        name: 'Reporte Neps VICUNHA',
        onLayout: (_) async => buildPdfBytes(),
      );
    });
  }

  Future<void> copyTable() async {
    if (records.isEmpty) {
      showMessage('No hay datos para copiar.');
      return;
    }

    final buffer = StringBuffer();
    buffer.writeln('Nro\tTelar\tNeps\tMts calculados');

    for (int i = 0; i < records.length; i++) {
      final item = records[i];
      buffer.writeln(
        '${i + 1}\t${item.telar}\t${formatDecimal(item.neps)}\t${formatNumber(calculateMts(item.neps))}',
      );
    }

    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    showMessage('Tabla copiada correctamente.');
  }

  Future<void> addRecord() async {
    final telar = telarController.text.trim();
    final nepsText = nepsController.text.trim();

    if (telar.isEmpty) {
      showMessage('Ingrese el numero de telar.');
      return;
    }

    if (nepsText.isEmpty || parseNumber(nepsText) <= 0) {
      showMessage('Ingrese una cantidad valida de neps.');
      return;
    }

    setState(() {
      records.add(NepRecord(telar: telar, neps: parseNumber(nepsText)));
    });

    await saveData();
    telarController.clear();
    nepsController.clear();
    showMessage('Registro agregado correctamente.');
  }

  Future<void> deleteRecord(int index) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar registro'),
        content: const Text('Desea eliminar este registro?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB94D4D),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (result == true) {
      setState(() => records.removeAt(index));
      await saveData();
    }
  }

  Future<void> clearTable() async {
    if (records.isEmpty) {
      showMessage('La tabla ya esta vacia.');
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vaciar tabla'),
        content: const Text('Seguro que desea vaciar toda la tabla?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB94D4D),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Vaciar'),
          ),
        ],
      ),
    );

    if (result == true) {
      setState(() => records = []);
      await saveData();
      showMessage('Tabla vaciada correctamente.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFD9D2B0), Color(0xFFC2B280)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(14),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1100),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF9E8),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black38,
                      blurRadius: 28,
                      offset: Offset(0, 16),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      buildHeader(),
                      Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          children: [
                            buildFormulaBox(),
                            const SizedBox(height: 12),
                            buildForm(),
                            const SizedBox(height: 12),
                            if (isExporting) buildExportingNotice(),
                            buildActions(),
                            const SizedBox(height: 12),
                            buildTable(),
                            const SizedBox(height: 12),
                            buildSummary(),
                            const SizedBox(height: 12),
                            const Text(
                              '* El resultado se calcula automaticamente cada vez que se ingresa el valor de Neps.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF7A6648),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildHeader() {
    return Container(
      color: const Color(0xFF1F2A2E),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'VICUNHA',
                style: TextStyle(
                  color: Color(0xFFF7EAC5),
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                  fontFamily: 'serif',
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFC5A059),
                  borderRadius: BorderRadius.circular(40),
                ),
                child: const Text(
                  'jeansidentity',
                  style: TextStyle(
                    color: Color(0xFF1F2A2E),
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Calculadora de Neps dividido para 0.09 metros',
            style: TextStyle(color: Color(0xFFCFD8C5), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget buildFormulaBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEBDFC3),
        borderRadius: BorderRadius.circular(18),
        border: const Border(
          left: BorderSide(color: Color(0xFFB8860B), width: 8),
        ),
      ),
      child: const Text.rich(
        TextSpan(
          children: [
            TextSpan(text: 'Formula utilizada: '),
            TextSpan(
              text: 'Mts calculados = Neps / 0.09\n',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2A2E),
              ),
            ),
            TextSpan(text: 'Ejemplo: '),
            TextSpan(
              text: '51 / 0.09 = 566.667',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2A2E),
              ),
            ),
          ],
        ),
        style: TextStyle(color: Color(0xFF3B2F1C), fontSize: 14),
      ),
    );
  }

  Widget buildForm() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxWidth < 760;

        if (isSmall) {
          return Column(
            children: [
              buildTelarInput(),
              const SizedBox(height: 10),
              buildNepsInput(),
              const SizedBox(height: 10),
              buildPreview(),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: buildAddButton()),
                  const SizedBox(width: 10),
                  Expanded(child: buildClearButton()),
                ],
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: buildTelarInput()),
            const SizedBox(width: 10),
            Expanded(child: buildNepsInput()),
            const SizedBox(width: 10),
            Expanded(child: buildPreview()),
            const SizedBox(width: 10),
            buildAddButton(),
            const SizedBox(width: 10),
            buildClearButton(),
          ],
        );
      },
    );
  }

  Widget buildTelarInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Numero de Telar',
          style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF2C3E2F)),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: telarController,
          textInputAction: TextInputAction.next,
          decoration: inputDecoration('Ej: 102'),
          onSubmitted: (_) => FocusScope.of(context).nextFocus(),
        ),
      ],
    );
  }

  Widget buildNepsInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Cantidad de Neps',
          style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF2C3E2F)),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: nepsController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.done,
          decoration: inputDecoration('Ej: 53'),
          onSubmitted: (_) => addRecord(),
        ),
      ],
    );
  }

  InputDecoration inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(40),
        borderSide: const BorderSide(color: Color(0xFFCFC29C), width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(40),
        borderSide: const BorderSide(color: Color(0xFFB8860B), width: 2),
      ),
    );
  }

  Widget buildPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Resultado automatico',
          style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF2C3E2F)),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7DF),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: const Color(0xFFC5A059), width: 2),
          ),
          child: Text(
            formatNumber(previewValue),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF2F4125),
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget buildAddButton() {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFFC5A059),
        foregroundColor: const Color(0xFF1F2A2E),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      onPressed: addRecord,
      icon: const Icon(Icons.add),
      label: const Text('Agregar', style: TextStyle(fontWeight: FontWeight.w900)),
    );
  }

  Widget buildClearButton() {
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFFE2D5B6),
        foregroundColor: const Color(0xFF3B2F1C),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      onPressed: () {
        telarController.clear();
        nepsController.clear();
      },
      child: const Text('Limpiar', style: TextStyle(fontWeight: FontWeight.w900)),
    );
  }

  Widget buildExportingNotice() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFE2D5B6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: [
          SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 10),
          Text('Generando archivo...', style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget buildActions() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        actionButton(
          label: 'CSV',
          icon: Icons.table_chart,
          color: const Color(0xFF2F6B45),
          onPressed: exportCsv,
        ),
        actionButton(
          label: 'Excel',
          icon: Icons.grid_on,
          color: const Color(0xFF2F6B45),
          onPressed: exportExcel,
        ),
        actionButton(
          label: 'PDF',
          icon: Icons.picture_as_pdf,
          color: const Color(0xFFC5A059),
          foreground: const Color(0xFF1F2A2E),
          onPressed: exportPdf,
        ),
        actionButton(
          label: 'Imprimir',
          icon: Icons.print,
          color: const Color(0xFFE2D5B6),
          foreground: const Color(0xFF3B2F1C),
          onPressed: printPdf,
        ),
        actionButton(
          label: 'Copiar',
          icon: Icons.copy,
          color: const Color(0xFFE2D5B6),
          foreground: const Color(0xFF3B2F1C),
          onPressed: copyTable,
        ),
        actionButton(
          label: 'Vaciar',
          icon: Icons.delete,
          color: const Color(0xFFB94D4D),
          onPressed: clearTable,
        ),
      ],
    );
  }

  Widget actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    Color foreground = Colors.white,
  }) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(backgroundColor: color, foregroundColor: foreground),
      onPressed: isExporting ? null : onPressed,
      icon: Icon(icon),
      label: Text(label),
    );
  }

  Widget buildTable() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD6C394)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 700),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFF1F2A2E)),
              headingTextStyle: const TextStyle(
                color: Color(0xFFF7EAC5),
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
              columns: const [
                DataColumn(label: Text('#')),
                DataColumn(label: Text('TELAR')),
                DataColumn(label: Text('NEPS')),
                DataColumn(label: Text('MTS CALCULADOS\nNEPS / 0.09')),
                DataColumn(label: Text('ACCION')),
              ],
              rows: records.isEmpty
                  ? [
                      const DataRow(
                        cells: [
                          DataCell(Text('-')),
                          DataCell(Text('Sin datos')),
                          DataCell(Text('-')),
                          DataCell(Text('-')),
                          DataCell(Text('-')),
                        ],
                      ),
                    ]
                  : List.generate(records.length, (index) {
                      final item = records[index];
                      return DataRow(
                        cells: [
                          DataCell(Text('${index + 1}')),
                          DataCell(Text(item.telar)),
                          DataCell(Text(formatDecimal(item.neps))),
                          DataCell(
                            Text(
                              formatNumber(calculateMts(item.neps)),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontFamily: 'monospace',
                                fontSize: 15,
                              ),
                            ),
                          ),
                          DataCell(
                            IconButton(
                              tooltip: 'Eliminar',
                              onPressed: () => deleteRecord(index),
                              icon: const Icon(Icons.delete, color: Color(0xFFB94D4D)),
                            ),
                          ),
                        ],
                      );
                    }),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildSummary() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxWidth < 650;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: isSmall ? 2 : 4,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: isSmall ? 2.3 : 2.4,
          children: [
            buildSummaryCard('Total registros', records.length.toString()),
            buildSummaryCard('Total neps', formatDecimal(totalNeps)),
            buildSummaryCard('Total mts', formatNumber(totalMts)),
            buildSummaryCard('Promedio mts', formatNumber(averageMts)),
          ],
        );
      },
    );
  }

  Widget buildSummaryCard(String title, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEBDFC3),
        borderRadius: BorderRadius.circular(16),
        border: const Border(
          left: BorderSide(color: Color(0xFFB8860B), width: 5),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title.toUpperCase(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF6B4C2C),
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF1F2A2E),
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
