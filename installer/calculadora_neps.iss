; ============================================================================
;  Instalador de Windows para "Calculadora Neps VICUNHA"
;  Generado con Inno Setup 6 (https://jrsoftware.org/isinfo.php)
;
;  Requisito previo: compilar la app de escritorio antes de compilar el instalador:
;      flutter build windows --release
;
;  Compilar el instalador:
;      "%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe" installer\calculadora_neps.iss
;
;  El instalador resultante queda en: build\installer\
; ============================================================================

#define MyAppName "Calculadora Neps VICUNHA"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "VICUNHA"
#define MyAppExeName "calculadora_neps.exe"
#define MyBuildDir "..\build\windows\x64\runner\Release"
#define MyIcon "..\windows\runner\resources\app_icon.ico"

[Setup]
; AppId identifica de forma unica la aplicacion (no cambiar entre versiones).
AppId={{99EECEEE-2048-475C-BCC9-300A667B73B3}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir=..\build\installer
OutputBaseFilename=CalculadoraNepsVICUNHA-Setup-{#MyAppVersion}
SetupIconFile={#MyIcon}
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
; Instalacion en Archivos de programa (requiere elevacion UAC).
PrivilegesRequired=admin

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Copia el contenido de la carpeta Release (exe, DLLs, runtime VC++ y carpeta data).
; Se excluyen artefactos de compilacion que no se necesitan en tiempo de ejecucion.
Source: "{#MyBuildDir}\*"; DestDir: "{app}"; Excludes: "*.lib,*.exp,*.pdb"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
