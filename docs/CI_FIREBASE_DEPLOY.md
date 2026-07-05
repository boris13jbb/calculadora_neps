# Despliegue CI — GitHub Actions + Firebase

Workflow: `.github/workflows/deploy-web.yml`

## Secret requerido

En **GitHub → Settings → Secrets and variables → Actions**, cree:

| Secret | Valor |
|--------|--------|
| `FIREBASE_SERVICE_ACCOUNT` | Contenido completo del JSON de service account (una sola línea o multilínea) |

Archivo local de referencia (no commitear):

```
vicunha-calculadora-neps-firebase-adminsdk-fbsvc-6f75950579.json
```

### Registrar el secret desde PowerShell

```powershell
cd C:\Users\BRS\Documents\regneps
node -e "console.log(JSON.stringify(require('./vicunha-calculadora-neps-firebase-adminsdk-fbsvc-6f75950579.json')))" | gh secret set FIREBASE_SERVICE_ACCOUNT
```

## Roles IAM recomendados

Cuenta: `firebase-adminsdk-fbsvc@vicunha-calculadora-neps.iam.gserviceaccount.com`

En [Google Cloud IAM](https://console.cloud.google.com/iam-admin/iam?project=vicunha-calculadora-neps):

| Rol | Para qué |
|-----|----------|
| **Firebase Admin** | Despliegue general |
| **Service Usage Consumer** | Publicar reglas Firestore desde CI |
| **Firebase Hosting Admin** | Publicar web |

Sin **Service Usage Consumer**, el workflow publica **Hosting** correctamente pero las reglas Firestore quedan como advertencia (no bloquean el deploy web).

## Qué despliega el CI

1. **Hosting** (obligatorio, debe pasar en verde)
2. **Firestore rules** (opcional; `continue-on-error`)

Functions no se despliegan desde este workflow; use localmente:

```powershell
$env:GOOGLE_APPLICATION_CREDENTIALS = "ruta\al\service-account.json"
firebase deploy --only functions --project vicunha-calculadora-neps
```

## URL de producción

https://vicunha-calculadora-neps.web.app
