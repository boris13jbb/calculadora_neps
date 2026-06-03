# Calculadora Neps VICUNHA - Flutter Android

Aplicación Flutter para Android que permite:

- Ingresar número de telar.
- Ingresar cantidad de Neps.
- Calcular automáticamente: `Mts = Neps ÷ 0.09`.
- Guardar registros en el celular.
- Copiar tabla.
- Copiar CSV para pegar en Excel.
- Vaciar tabla.

La app inicia sin datos precargados.

## Opción 1: Compilar APK en tu computadora

1. Instala Flutter.
2. Crea o abre esta carpeta.
3. Ejecuta:

```bash
flutter pub get
flutter create --platforms android --project-name calculadora_neps .
flutter build apk --release
```

El APK queda en:

```text
build/app/outputs/flutter-apk/app-release.apk
```

## Opción 2: Compilar APK gratis con GitHub Actions

1. Crea un repositorio en GitHub.
2. Sube todos estos archivos.
3. Entra a la pestaña **Actions**.
4. Ejecuta el workflow **Build APK**.
5. Cuando termine, descarga el artefacto **calculadora-neps-apk**.
6. Dentro estará el archivo `app-release.apk`.

## Archivos principales

```text
lib/main.dart
pubspec.yaml
.github/workflows/build-apk.yml
```
