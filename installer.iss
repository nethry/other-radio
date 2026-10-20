; Inno Setup script for the OtherRadio Windows installer.
; Build with installer\windows\build_installer.ps1, which passes the defines below.

#ifndef AppVersion
  #error AppVersion must be supplied by build_installer.ps1
#endif
#ifndef BundleDir
  #define BundleDir "build\windows\x64\runner\Release"
#endif
#ifndef OutputDir
  #define OutputDir "build\installer"
#endif

[Setup]
; Keep AppId stable: it is how new versions upgrade an existing install.
AppId={{AD56191B-D15A-4FA3-95B8-35DB6B8D118D}
AppName=OtherRadio
AppVersion={#AppVersion}
AppVerName=OtherRadio {#AppVersion}
AppPublisher=OtherRadio
VersionInfoVersion={#AppVersion}
; Per-user install: no admin prompt, lands in %LOCALAPPDATA%\Programs\OtherRadio.
PrivilegesRequired=lowest
DefaultDirName={autopf}\OtherRadio
DisableProgramGroupPage=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
OutputDir={#OutputDir}
OutputBaseFilename=OtherRadio-Setup-{#AppVersion}
SetupIconFile=windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\other_radio.exe
UninstallDisplayName=OtherRadio
WizardStyle=modern
Compression=lzma2/max
SolidCompression=yes
CloseApplications=yes

[Languages]
; The application interface is Polish; the installer matches it.
Name: "polish"; MessagesFile: "compiler:Languages\Polish.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#BundleDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
#ifndef CrtDir
  #error CrtDir is required to bundle the MSVC runtime
#endif
; Flutter's bundle omits the MSVC runtime; ship it app-locally so clean PCs start the app.
Source: "{#CrtDir}\*.dll"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\OtherRadio"; Filename: "{app}\other_radio.exe"
Name: "{autodesktop}\OtherRadio"; Filename: "{app}\other_radio.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\other_radio.exe"; Description: "{cm:LaunchProgram,OtherRadio}"; Flags: nowait postinstall skipifsilent
