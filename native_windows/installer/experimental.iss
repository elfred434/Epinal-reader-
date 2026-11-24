; Experimental native build, deliberately separate from stable Flutter install.
[Setup]
AppId={{0FA65A93-33EC-4903-B047-8CFF773BF853}
AppName=Épinal Native Expérimental
AppVersion=0.1.0
AppPublisher=Epinal Reader
DefaultDirName={localappdata}\Programs\Epinal-Native-Experimental
DefaultGroupName=Épinal Native Expérimental
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=.
OutputBaseFilename=Epinal-Native-Experimental-Setup-x64
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\Epinal.Native.Experimental.exe
CloseApplications=yes

[Languages]
Name: "french"; MessagesFile: "compiler:Languages\French.isl"

[Files]
Source: "..\publish\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Épinal Native Expérimental"; Filename: "{app}\Epinal.Native.Experimental.exe"

[Run]
Filename: "{app}\Epinal.Native.Experimental.exe"; Description: "Lancer Épinal Native Expérimental"; Flags: nowait postinstall skipifsilent
