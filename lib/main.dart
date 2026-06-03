import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const NepsApp());
}

const double testLengthM = 0.09;
const int decimals = 0;
const String storageKey = 'vicunha_neps_flutter_sin_precarga_v1';

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
        colorSchemeSeed: const Color(0xFFC5A059),
      ),
      home: const NepsHomePage(),
    );
  }
}

class NepRecord {
  String telar;
  double neps;

  NepRecord({
    required this.telar,
    required this.neps,
  });

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

  final FocusNode telarFocus = FocusNode();
  final FocusNode nepsFocus = FocusNode();

  List<NepRecord> records = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    nepsController.addListener(() {
      setState(() {});
    });
    loadData();
  }

  @override
  void dispose() {
    telarController.dispose();
    nepsController.dispose();
    telarFocus.dispose();
    nepsFocus.dispose();
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

    setState(() {
      isLoading = false;
    });
  }

  Future<void> saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final data = records.map((e) => e.toJson()).toList();
    await prefs.setString(storageKey, jsonEncode(data));
  }

  double calculateMts(double neps) {
    return neps / testLengthM;
  }

  String formatNumber(double value) {
    if (decimals == 0) {
      return value.round().toString();
    }

    return value.toStringAsFixed(decimals);
  }

  double parseNumber(String value) {
    final normalized = value.replaceAll(',', '.');
    return double.tryParse(normalized) ?? 0;
  }

  String formatNeps(double value) {
    if (value == value.roundToDouble()) {
      return value.round().toString();
    }

    return value.toString();
  }

  double get previewValue {
    if (nepsController.text.trim().isEmpty) {
      return 0;
    }

    final neps = parseNumber(nepsController.text);
    return calculateMts(neps);
  }

  double get totalNeps {
    return records.fold(0, (sum, item) => sum + item.neps);
  }

  double get totalMts {
    return records.fold(0, (sum, item) => sum + calculateMts(item.neps));
  }

  double get averageMts {
    if (records.isEmpty) {
      return 0;
    }

    return totalMts / records.length;
  }

  Future<void> addRecord() async {
    final telar = telarController.text.trim();
    final nepsText = nepsController.text.trim();

    if (telar.isEmpty) {
      showMessage('Ingrese el número de telar.');
      telarFocus.requestFocus();
      return;
    }

    if (nepsText.isEmpty || parseNumber(nepsText) <= 0) {
      showMessage('Ingrese una cantidad válida de neps.');
      nepsFocus.requestFocus();
      return;
    }

    final neps = parseNumber(nepsText);

    setState(() {
      records.add(
        NepRecord(
          telar: telar,
          neps: neps,
        ),
      );
    });

    await saveData();

    telarController.clear();
    nepsController.clear();
    telarFocus.requestFocus();

    showMessage('Registro agregado correctamente.');
  }

  Future<void> deleteRecord(int index) async {
    setState(() {
      records.removeAt(index);
    });

    await saveData();
  }

  Future<void> confirmDeleteRecord(int index) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Eliminar registro'),
          content: const Text('¿Desea eliminar este registro?'),
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
        );
      },
    );

    if (result == true) {
      await deleteRecord(index);
    }
  }

  Future<void> clearTable() async {
    if (records.isEmpty) {
      showMessage('La tabla ya está vacía.');
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Vaciar tabla'),
          content: const Text('¿Seguro que desea vaciar toda la tabla?'),
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
        );
      },
    );

    if (result == true) {
      setState(() {
        records = [];
      });

      await saveData();
      showMessage('Tabla vaciada correctamente.');
    }
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
      final mts = calculateMts(item.neps);

      buffer.writeln(
        '${i + 1}\t${item.telar}\t${formatNeps(item.neps)}\t${formatNumber(mts)}',
      );
    }

    await Clipboard.setData(
      ClipboardData(text: buffer.toString()),
    );

    showMessage('Tabla copiada correctamente.');
  }

  Future<void> copyCSV() async {
    if (records.isEmpty) {
      showMessage('No hay datos para exportar.');
      return;
    }

    final buffer = StringBuffer();
    buffer.writeln('Nro,Telar,Neps,Mts calculados');

    for (int i = 0; i < records.length; i++) {
      final item = records[i];
      final mts = calculateMts(item.neps);

      buffer.writeln(
        '${i + 1},${item.telar},${formatNeps(item.neps)},${formatNumber(mts)}',
      );
    }

    await Clipboard.setData(
      ClipboardData(text: buffer.toString()),
    );

    showMessage('CSV copiado. Puede pegarlo en Excel.');
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

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      body: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: double.infinity),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFD9D2B0),
              Color(0xFFC2B280),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(14),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(
                  maxWidth: 1100,
                ),
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
                            buildActions(),
                            const SizedBox(height: 12),
                            buildTable(),
                            const SizedBox(height: 12),
                            buildSummary(),
                            const SizedBox(height: 12),
                            const Text(
                              '* El resultado se calcula automáticamente cada vez que se ingresa o modifica el valor de Neps.',
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
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
            style: TextStyle(
              color: Color(0xFFCFD8C5),
              fontSize: 13,
            ),
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
          left: BorderSide(
            color: Color(0xFFB8860B),
            width: 8,
          ),
        ),
      ),
      child: const Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '📌 Fórmula utilizada: '),
            TextSpan(
              text: 'Metros calculados = Neps ÷ 0.09\n',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2A2E),
              ),
            ),
            TextSpan(text: 'Ejemplo: '),
            TextSpan(
              text: '51 ÷ 0.09 = 566.667',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2A2E),
              ),
            ),
          ],
        ),
        style: TextStyle(
          color: Color(0xFF3B2F1C),
          fontSize: 14,
        ),
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
                  Expanded(
                    child: buildAddButton(),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: buildClearButton(),
                  ),
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
          'Número de Telar',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Color(0xFF2C3E2F),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: telarController,
          focusNode: telarFocus,
          textInputAction: TextInputAction.next,
          decoration: inputDecoration('Ej: 102'),
          onSubmitted: (_) {
            nepsFocus.requestFocus();
          },
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
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Color(0xFF2C3E2F),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: nepsController,
          focusNode: nepsFocus,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
          ),
          textInputAction: TextInputAction.done,
          decoration: inputDecoration('Ej: 53'),
          onSubmitted: (_) => addRecord(),
        ),
      ],
    );
  }

  Widget buildPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Resultado automático',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Color(0xFF2C3E2F),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7DF),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(
              color: const Color(0xFFC5A059),
              width: 2,
            ),
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

  InputDecoration inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(40),
        borderSide: const BorderSide(
          color: Color(0xFFCFC29C),
          width: 2,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(40),
        borderSide: const BorderSide(
          color: Color(0xFFB8860B),
          width: 2,
        ),
      ),
    );
  }

  Widget buildAddButton() {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFFC5A059),
        foregroundColor: const Color(0xFF1F2A2E),
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      onPressed: addRecord,
      icon: const Icon(Icons.add),
      label: const Text(
        'Agregar',
        style: TextStyle(fontWeight: FontWeight.w900),
      ),
    );
  }

  Widget buildClearButton() {
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFFE2D5B6),
        foregroundColor: const Color(0xFF3B2F1C),
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      onPressed: () {
        telarController.clear();
        nepsController.clear();
        telarFocus.requestFocus();
      },
      child: const Text(
        'Limpiar',
        style: TextStyle(fontWeight: FontWeight.w900),
      ),
    );
  }

  Widget buildActions() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF2F6B45),
            foregroundColor: Colors.white,
          ),
          onPressed: copyCSV,
          icon: const Icon(Icons.download),
          label: const Text('Exportar CSV'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFE2D5B6),
            foregroundColor: const Color(0xFF3B2F1C),
          ),
          onPressed: copyTable,
          icon: const Icon(Icons.copy),
          label: const Text('Copiar tabla'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFB94D4D),
            foregroundColor: Colors.white,
          ),
          onPressed: clearTable,
          icon: const Icon(Icons.delete),
          label: const Text('Vaciar tabla'),
        ),
      ],
    );
  }

  Widget buildTable() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFD6C394),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: 700,
            ),
            child: DataTable(
              headingRowColor: MaterialStateProperty.all(
                const Color(0xFF1F2A2E),
              ),
              headingTextStyle: const TextStyle(
                color: Color(0xFFF7EAC5),
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
              dataTextStyle: const TextStyle(
                color: Color(0xFF1F2A2E),
                fontSize: 14,
              ),
              columns: const [
                DataColumn(label: Text('#')),
                DataColumn(label: Text('TELAR')),
                DataColumn(label: Text('NEPS')),
                DataColumn(label: Text('MTS CALCULADOS\nNEPS ÷ 0.09')),
                DataColumn(label: Text('ACCIÓN')),
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
                      final mts = calculateMts(item.neps);

                      return DataRow(
                        cells: [
                          DataCell(Text('${index + 1}')),
                          DataCell(Text(item.telar)),
                          DataCell(Text(formatNeps(item.neps))),
                          DataCell(
                            Text(
                              formatNumber(mts),
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
                              onPressed: () => confirmDeleteRecord(index),
                              icon: const Icon(
                                Icons.delete,
                                color: Color(0xFFB94D4D),
                              ),
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
            buildSummaryCard(
              title: 'Total registros',
              value: records.length.toString(),
            ),
            buildSummaryCard(
              title: 'Total neps',
              value: formatNumber(totalNeps),
            ),
            buildSummaryCard(
              title: 'Total mts',
              value: formatNumber(totalMts),
            ),
            buildSummaryCard(
              title: 'Promedio mts',
              value: formatNumber(averageMts),
            ),
          ],
        );
      },
    );
  }

  Widget buildSummaryCard({
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEBDFC3),
        borderRadius: BorderRadius.circular(16),
        border: const Border(
          left: BorderSide(
            color: Color(0xFFB8860B),
            width: 5,
          ),
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
