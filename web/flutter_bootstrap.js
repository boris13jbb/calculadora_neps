{{flutter_js}}
{{flutter_build_config}}

var appVersion = window.VICUNHA_APP_VERSION || null;

_flutter.loader.load({
  serviceWorkerSettings: appVersion
    ? { serviceWorkerVersion: appVersion }
    : undefined,
});
