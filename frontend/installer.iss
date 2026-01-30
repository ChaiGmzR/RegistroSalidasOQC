; Inno Setup Script para OQC Registro de Salidas
; Incluye backend Node.js integrado

#define MyAppName "OQC Registro de Salidas"
#define MyAppVersion "1.0.3"
#define MyAppPublisher "Ilsan Electronics"
#define MyAppExeName "oqc_registro_salidas.exe"
#define MyAppURL "https://ilsan.com"
#define SourcePath "C:\Users\jesus\OneDrive\Documents\Desarrollo\OQC\RegistroSalidasOQC\frontend"
#define BackendPath "C:\Users\jesus\OneDrive\Documents\Desarrollo\OQC\RegistroSalidasOQC\backend"

[Setup]
; Identificador único de la aplicación
AppId={{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
; Ubicación del instalador de salida
OutputDir={#SourcePath}\..\installers
OutputBaseFilename=OQC_Registro_Salidas_Setup_{#MyAppVersion}
SetupIconFile={#SourcePath}\windows\runner\resources\app_icon.ico
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
; Privilegios de administrador no requeridos para instalación por usuario
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; === FRONTEND (Flutter App) ===
Source: "{#SourcePath}\build\windows\x64\runner\Release\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourcePath}\build\windows\x64\runner\Release\flutter_windows.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourcePath}\build\windows\x64\runner\Release\pdfium.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourcePath}\build\windows\x64\runner\Release\printing_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourcePath}\build\windows\x64\runner\Release\screen_retriever_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourcePath}\build\windows\x64\runner\Release\window_manager_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourcePath}\build\windows\x64\runner\Release\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

; === BACKEND (Node.js compilado) ===
Source: "{#BackendPath}\dist\oqc-backend.exe"; DestDir: "{app}\backend"; Flags: ignoreversion
Source: "{#BackendPath}\dist\.env"; DestDir: "{app}\backend"; Flags: ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[Code]
// Añadir regla de firewall para el backend (opcional, requiere admin)
procedure CurStepChanged(CurStep: TSetupStep);
var
  ResultCode: Integer;
begin
  if CurStep = ssPostInstall then
  begin
    // Intentar agregar regla de firewall (puede fallar sin admin)
    Exec('netsh', 'advfirewall firewall add rule name="OQC Backend" dir=in action=allow program="' + ExpandConstant('{app}') + '\backend\oqc-backend.exe" enable=yes', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  end;
end;
