; Inno Setup script for AI Desktop
; Build the app first:  flutter build windows --release
; Then compile this script with Inno Setup (ISCC.exe) to produce the installer.

#define MyAppName "Nadira Shakila"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Nadira Shakila"
#define MyAppExeName "ai_desktop.exe"

[Setup]
; A fixed AppId lets new versions upgrade the existing install in-place
; (no manual uninstall needed).
AppId={{8F3C2A91-7B4D-4E2A-9C1F-AID3SK70PXY1}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={localappdata}\Programs\AI Desktop
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
; Per-user install: no admin prompt, upgrades in-place.
PrivilegesRequired=lowest
; Paths below are relative to the project root (parent of this script).
SourceDir=..
OutputDir=installer\output
OutputBaseFilename=AIDesktop-Setup-{#MyAppVersion}
SetupIconFile=windows\runner\resources\app_icon.ico
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional icons:"

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{userdesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch {#MyAppName}"; Flags: nowait postinstall skipifsilent
