; Inno Setup 6 — per-user installation and in-place upgrades.
#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif

[Setup]
AppId={{EAF02937-0D4E-4E7E-943A-2E84921C0F1B}
AppName=Épinal
AppVersion={#AppVersion}
AppPublisher=Epinal Reader
AppPublisherURL=https://github.com/elfred434/Epinal-reader-
AppSupportURL=https://github.com/elfred434/Epinal-reader-/issues
AppUpdatesURL=https://github.com/elfred434/Epinal-reader-/releases/latest
DefaultDirName={localappdata}\Programs\Epinal
DefaultGroupName=Épinal
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=..
OutputBaseFilename=Epinal-Setup-x64
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\Epinal.exe
UninstallDisplayName=Épinal
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
RestartApplications=no
UsePreviousTasks=yes

[Languages]
Name: "french"; MessagesFile: "compiler:Languages\French.isl"

[Tasks]
Name: "desktopicon"; Description: "Créer une icône sur le Bureau"; GroupDescription: "Raccourcis supplémentaires :"

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Épinal"; Filename: "{app}\Epinal.exe"; WorkingDir: "{app}"
Name: "{autodesktop}\Épinal"; Filename: "{app}\Epinal.exe"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "{app}\Epinal.exe"; Description: "Lancer Épinal"; Flags: nowait postinstall skipifsilent

; No application data is removed during uninstall. Books, preferences, covers,
; and WebView2 data are stored in the user's roaming profile, outside {app}.
