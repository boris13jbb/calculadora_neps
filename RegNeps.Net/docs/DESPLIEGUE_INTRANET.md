# Despliegue intranet — RegNeps.Web

## Definición operativa (fijada)

| Parámetro | Valor |
|-----------|--------|
| Producto | RegNeps.Net (Blazor Server), **no** Flutter/Firebase Hosting |
| Perfil piloto | `ASPNETCORE_ENVIRONMENT=Intranet` → `appsettings.Intranet.json` |
| Motor BD piloto | **SQLite** (`App_Data/regneps_v2.db` bajo ContentRoot) |
| Motor BD planta (siguiente paso) | **SQL Server** (`Database:UseSqlServer=true`) |
| Bind | `0.0.0.0:5080` (Kestrel) |
| URL desde PC de planta/oficina | `http://<IP-o-hostname-del-servidor>:5080` |
| Firewall | Abrir **TCP 5080** únicamente a subredes corporativas (LAN/VPN); no exponer a Internet |
| Auth | Cookies locales (sin Firebase Auth) |
| Flutter cloud | Permanece en paralelo (`vicunha-calculadora-neps.web.app`) hasta cutover explícito |

Sustituya `SERVIDOR-INTRANET` / `<IP-o-hostname-del-servidor>` por el host real del servidor interno (p. ej. `10.x.x.x` o nombre DNS de planta).

## Publicar

```powershell
cd C:\Users\BRS\Documents\regneps\RegNeps.Net
dotnet publish src/RegNeps.Web -c Release -o publish
```

## Ejecutar en servidor interno (Kestrel)

```powershell
cd publish
$env:ASPNETCORE_ENVIRONMENT = "Intranet"
.\RegNeps.Web.exe
```

Escucha en `http://0.0.0.0:5080` (configurable en `Urls`).

Desde otro PC: `http://IP-DEL-SERVIDOR:5080`

## Base de datos

Por defecto (perfil Intranet / Production con SQLite): `App_Data/regneps_v2.db`.

Para SQL Server en intranet, edite `appsettings.Intranet.json` o `appsettings.Production.json`:

```json
{
  "ConnectionStrings": {
    "RegNeps": "Server=SERVIDOR\\INSTANCIA;Database=RegNeps;Trusted_Connection=True;TrustServerCertificate=True"
  },
  "Database": {
    "UseSqlServer": true
  },
  "Urls": "http://0.0.0.0:5080"
}
```

## Firewall

Abrir puerto **5080** (o 80 si pone un reverse proxy IIS) solo en la red corporativa.

## IIS (opcional)

1. Instalar [ASP.NET Core Hosting Bundle](https://dotnet.microsoft.com/download/dotnet/8.0)
2. Crear sitio apuntando a la carpeta `publish`
3. Application Pool → No Managed Code
4. Binding HTTP en la IP interna

## Checklist post-despliegue

- [ ] Login admin / usuarios migrados
- [ ] Captura de un registro de prueba
- [ ] Ver registros históricos (si ya hubo migración)
- [ ] Exportar PDF/Excel
- [ ] Cambiar contraseñas temporales de usuarios migrados
- [ ] Confirmar que el puerto 5080 no es alcanzable desde fuera de la LAN/VPN
