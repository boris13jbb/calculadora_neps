const double testLengthM = 0.09;
const int decimals = 0;

/// Key legacy global (solo lectura/migración; no escribir datos nuevos aquí).
const String storageKey = 'vicunha_neps_flutter_exportaciones_v1';
const String recordsHiveBoxName = 'vicunha_records_v1';
const String recordsHiveMigrationKey = 'vicunha_records_hive_migration_v1';
const String flatRecordsBackfillKey = 'vicunha_flat_records_backfill_v1';

/// Prefijos de almacenamiento local por UID.
const String recordsPrefsKeyPrefix = 'vicunha_records_uid_v1_';
const String recordsHiveBoxPrefix = 'vicunha_records_uid_v1_';
const String recordsAmbiguousKey = 'vicunha_records_ambiguous_v1';
const String recordsLegacySplitDoneKey = 'vicunha_records_legacy_split_v1';
const String pendingSyncKeyPrefix = 'vicunha_pending_sync_v1_';
const String captureDraftKeyPrefix = 'vicunha_capture_draft_v1_';
const String personalSessionsKeyPrefix = 'vicunha_personal_sessions_v1_';
const String personalReportsKeyPrefix = 'vicunha_personal_reports_v1_';
const String lotePrefsKeyPrefix = 'vicunha_lote_prefs_v1_';

/// Registros cargados en la primera página (Firestore / memoria).
const int recordsInitialPageSize = 50;

/// Incremento al pulsar «Cargar más».
const int recordsPageSizeIncrement = 50;

/// Máximo de registros en consultas paginadas.
const int recordsMaxPageSize = 500;

/// Límite para informes consolidados por rango de fechas (Firestore / local).
const int reportExportRecordLimit = 10000;

/// Límite de registros para KPIs y gráficas ligeras del panel principal.
const int dashboardRecordsLimit = 100;
const String fabricCatalogStorageKey = 'vicunha_fabric_catalog_v1';
const String savedReportsStorageKey = 'vicunha_saved_reports_v1';
const String cloudMigrationKey = 'vicunha_cloud_migration_v1';
const String cloudReportsMigrationKey = 'vicunha_cloud_reports_migration_v1';
const String cloudUserMigrationKeyPrefix = 'vicunha_cloud_user_migration_v1_';
const String cloudWorkspaceId = 'vicunha';

/// Dominio de emails internos para usuarios normales (no visible en UI).
const String internalAuthEmailDomain = 'vicunha.local';

const String loteTramaPrefix = '63E264';
const String loteTramaPrefixStorageKey = 'vicunha_lote_trama_prefix_v1';
const String loteTramaFullStorageKey = 'vicunha_lote_trama_full_v1';
const String loteTramaFullEntryStorageKey = 'vicunha_lote_trama_full_entry_v1';
const String loteTramaCatalogStorageKey = 'vicunha_lote_trama_catalog_v1';
const String alertConfigStorageKey = 'vicunha_alert_config_v1';
const String notificationPrefsKey = 'vicunha_notification_prefs_v1';

/// Prefijo de la sesión de captura activa por UID (`…_{uid}`).
const String activeCaptureSessionKeyPrefix =
    'vicunha_active_capture_session_v1_';

/// IDs ya incluidos en Captura → Guardar, por UID + captureSessionId.
const String savedCaptureIdsKeyPrefix = 'vicunha_saved_capture_ids_v1_';

String recordsPrefsKeyForUid(String uid) => '$recordsPrefsKeyPrefix$uid';
String recordsHiveBoxForUid(String uid) => '$recordsHiveBoxPrefix$uid';
String pendingSyncKeyForUid(String uid) => '$pendingSyncKeyPrefix$uid';
String captureDraftKeyForUid(String uid) => '$captureDraftKeyPrefix$uid';
String personalSessionsKeyForUid(String uid) =>
    '$personalSessionsKeyPrefix$uid';
String personalReportsKeyForUid(String uid) => '$personalReportsKeyPrefix$uid';
String lotePrefsKeyForUid(String uid) => '$lotePrefsKeyPrefix$uid';
String activeCaptureSessionKeyForUid(String uid) =>
    '$activeCaptureSessionKeyPrefix$uid';

/// Clave local de tracking de guardados: UID + sesión de captura.
String savedCaptureIdsKeyFor(String uid, String captureSessionId) =>
    '$savedCaptureIdsKeyPrefix${uid}_$captureSessionId';

/// Site key reCAPTCHA v3 para Firebase App Check (web).
/// Definir con: `--dart-define=APP_CHECK_RECAPTCHA_SITE_KEY=...`
const String appCheckRecaptchaSiteKey = String.fromEnvironment(
  'APP_CHECK_RECAPTCHA_SITE_KEY',
  defaultValue: '',
);

/// Activa App Check en debug solo si se define explícitamente.
/// Producción (release): activo por defecto.
/// Debug: `--dart-define=APP_CHECK_ENABLED=true`
const bool appCheckEnabled = bool.fromEnvironment(
  'APP_CHECK_ENABLED',
  defaultValue: false,
);

/// Imprime token debug de App Check al iniciar (solo si APP_CHECK está activo).
const bool appCheckLogDebugToken = bool.fromEnvironment(
  'APP_CHECK_LOG_DEBUG_TOKEN',
  defaultValue: false,
);

const String manualFabricOption = '__manual_fabric__';
