import 'package:flutter/material.dart';

import '../../utils/lote_trama_helper.dart';

/// Estado del formulario de captura (controladores y modo de lote).
class CaptureFormScope extends ChangeNotifier {
  CaptureFormScope();

  final TextEditingController telarController = TextEditingController();
  final TextEditingController nepsController = TextEditingController();
  final TextEditingController lotePrefixController = TextEditingController();
  final TextEditingController loteSuffixController = TextEditingController();
  final TextEditingController loteFullController = TextEditingController();
  final TextEditingController manualTelaController = TextEditingController();
  final TextEditingController turnoController = TextEditingController();
  final TextEditingController operarioController = TextEditingController();
  final TextEditingController lineaProduccionController =
      TextEditingController();
  final TextEditingController observacionController = TextEditingController();
  final TextEditingController accionInmediataController =
      TextEditingController();

  bool loteFullEntryMode = false;

  /// Persistencia del lote completo (asignado por [AppState]).
  VoidCallback? onLoteFullPersist;

  void attachListeners(VoidCallback onChanged) {
    nepsController.addListener(onChanged);
    loteSuffixController.addListener(onChanged);
    loteFullController.addListener(_handleLoteFullChanged);
    lotePrefixController.addListener(onChanged);
  }

  void detachListeners(VoidCallback onChanged) {
    nepsController.removeListener(onChanged);
    loteSuffixController.removeListener(onChanged);
    loteFullController.removeListener(_handleLoteFullChanged);
    lotePrefixController.removeListener(onChanged);
  }

  void _handleLoteFullChanged() {
    final full = loteFullController.text.trim();
    if (full.isEmpty) return;
    final parts = LoteTramaHelper.split(
      full,
      fallbackPrefix: lotePrefixController.text,
    );
    if (lotePrefixController.text != parts.prefix) {
      lotePrefixController.text = parts.prefix;
    }
    if (loteSuffixController.text != parts.suffix) {
      loteSuffixController.text = parts.suffix;
    }
    onLoteFullPersist?.call();
    notifyListeners();
  }

  void clearCaptureFields({bool notify = true}) {
    telarController.clear();
    nepsController.clear();
    lotePrefixController.clear();
    loteSuffixController.clear();
    loteFullController.clear();
    manualTelaController.clear();
    turnoController.clear();
    operarioController.clear();
    lineaProduccionController.clear();
    observacionController.clear();
    accionInmediataController.clear();
    loteFullEntryMode = false;
    if (notify) {
      notifyListeners();
    }
  }

  /// Limpia los campos del registro individual tras guardar, conservando
  /// tela y lote de la sesión para captura continua.
  void clearFieldsForNextRecord({bool notify = true}) {
    telarController.clear();
    nepsController.clear();
    turnoController.clear();
    operarioController.clear();
    lineaProduccionController.clear();
    observacionController.clear();
    accionInmediataController.clear();
    if (notify) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    telarController.dispose();
    nepsController.dispose();
    lotePrefixController.dispose();
    loteSuffixController.dispose();
    loteFullController.dispose();
    manualTelaController.dispose();
    turnoController.dispose();
    operarioController.dispose();
    lineaProduccionController.dispose();
    observacionController.dispose();
    accionInmediataController.dispose();
    super.dispose();
  }
}
