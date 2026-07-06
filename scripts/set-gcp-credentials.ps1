# Carga credenciales de service account para scripts locales y Firebase CLI.
$repoRoot = Split-Path $PSScriptRoot -Parent
$secretsDir = Join-Path $repoRoot "secrets"

if (-not (Test-Path $secretsDir)) {
  Write-Error "No existe la carpeta secrets/. Cree secrets/ y coloque el JSON de service account."
  exit 1
}

$candidates = Get-ChildItem -Path $secretsDir -Filter "*.json" -File |
  Where-Object { $_.Name -notmatch 'package|tsconfig' } |
  Sort-Object LastWriteTime -Descending

if ($candidates.Count -eq 0) {
  Write-Error "No hay archivos .json en secrets/. Descargue la clave desde GCP Console."
  exit 1
}

$credPath = $candidates[0].FullName
$env:GOOGLE_APPLICATION_CREDENTIALS = $credPath
Write-Host "GOOGLE_APPLICATION_CREDENTIALS = $credPath"
