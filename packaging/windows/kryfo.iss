; per-user installer for kryfo on windows: no admin rights, no telemetry, no
; update check of its own.
;
;   iscc kryfo.iss                          unsigned
;   iscc "/Ssignpath=<command> $f" /DSign kryfo.iss   signed through signpath
;
; paths can be moved with /DFlutterDir=... /DHaloDll=... /DSignalDll=... /DTorDir=...

#define AppName "Kryfo"
#define RepoDir SourcePath + "..\.."

; the version is the app's, from the version: line in mobile\pubspec.yaml
#ifndef AppVersion
  #define AppVersion ""
  #define Pubspec FileOpen(RepoDir + "\mobile\pubspec.yaml")
  #if !Pubspec
    #error cannot read mobile\pubspec.yaml
  #endif
  #sub ReadVersion
    #define Line FileRead(Pubspec)
    #if Copy(Line, 1, 9) == "version: "
      #define Plus Pos("+", Line)
      #if Plus > 0
        #define AppVersion Copy(Line, 10, Plus - 10)
      #else
        #define AppVersion Copy(Line, 10, Len(Line) - 9)
      #endif
    #endif
  #endsub
  #for {0; AppVersion == "" && !FileEof(Pubspec); 0} ReadVersion
  #expr FileClose(Pubspec)
  #if AppVersion == ""
    #error no version: line in mobile\pubspec.yaml
  #endif
#endif
#ifndef FlutterDir
  ; flutter build windows --release
  #define FlutterDir RepoDir + "\mobile\build\windows\x64\runner\Release"
#endif
#ifndef HaloDll
  ; TOR_EXE=... engine/build-windows.sh
  #define HaloDll RepoDir + "\engine\out\windows-x64\halo.dll"
#endif
#ifndef SignalDll
  ; the libsignal shim, cross-built for windows
  #define SignalDll RepoDir + "\mobile\native\kryfo_signal\target\x86_64-pc-windows-gnu\release\kryfo_signal.dll"
#endif
#ifndef TorDir
  ; packaging/windows/stage-tor.sh
  #define TorDir SourcePath + "..\build\windows\tor"
#endif
#ifndef OutputDir
  #define OutputDir SourcePath + "..\build\windows"
#endif

; must equal TOR_EXE_SHA256 in tor-pin.txt and the pin in halo.dll
#define TorExeSha256 "8c38513b3c4584154158e7c584f4144849dc679a64cd679553d72dad28230c54"

#if Exec("powershell.exe", '-NoProfile -ExecutionPolicy Bypass -File "' + SourcePath + 'check-tor.ps1" -Path "' + TorDir + '\tor.exe" -Sha256 ' + TorExeSha256, SourcePath, 1, SW_HIDE) != 0
  #error tor.exe does not match TorExeSha256, see tor-pin.txt
#endif

[Setup]
AppId={{0CBD6E9C-0463-453C-A2FF-E2113BF68D4B}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppName}
AppPublisherURL=https://kryfo.app
PrivilegesRequired=lowest
DefaultDirName={localappdata}\Programs\{#AppName}
DisableProgramGroupPage=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
LicenseFile={#RepoDir}\LICENSE
SetupIconFile={#RepoDir}\mobile\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\kryfo.exe
UninstallDisplayName={#AppName}
OutputDir={#OutputDir}
OutputBaseFilename=kryfo-{#AppVersion}-windows-x64-setup
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
; tor.exe runs from {app}\tor while the app is open
CloseApplications=yes
RestartApplications=no
#ifdef Sign
SignTool=signpath
SignedUninstaller=yes
#endif

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#FlutterDir}\kryfo.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#FlutterDir}\*.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#FlutterDir}\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#HaloDll}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SignalDll}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#TorDir}\tor.exe"; DestDir: "{app}\tor"; Flags: ignoreversion
Source: "{#TorDir}\openssl.cnf"; DestDir: "{app}\tor"; Flags: ignoreversion
Source: "{#TorDir}\licenses\*"; DestDir: "{app}\tor\licenses"; Flags: ignoreversion
Source: "{#RepoDir}\LICENSE"; DestDir: "{app}"; DestName: "LICENSE.txt"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\kryfo.exe"; AppUserModelID: "app.kryfo"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\kryfo.exe"; AppUserModelID: "app.kryfo"; Tasks: desktopicon

[Registry]
; kryfo: links open in the app; a second start hands the link to the first
Root: HKCU; Subkey: "Software\Classes\kryfo"; ValueType: string; ValueName: ""; ValueData: "URL:Kryfo"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Classes\kryfo"; ValueType: string; ValueName: "URL Protocol"; ValueData: ""
Root: HKCU; Subkey: "Software\Classes\kryfo\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: """{app}\kryfo.exe"",0"
Root: HKCU; Subkey: "Software\Classes\kryfo\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\kryfo.exe"" ""%1"""
; error reporting leaves both alone. kryfo.exe sets the same at each start
Root: HKCU; Subkey: "Software\Microsoft\Windows\Windows Error Reporting\ExcludedApplications"; ValueType: dword; ValueName: "kryfo.exe"; ValueData: 1; Flags: uninsdeletevalue
Root: HKCU; Subkey: "Software\Microsoft\Windows\Windows Error Reporting\ExcludedApplications"; ValueType: dword; ValueName: "tor.exe"; ValueData: 1; Flags: uninsdeletevalue
; the toasts' registration, written by the app at its first start
Root: HKCU; Subkey: "Software\Classes\AppUserModelId\app.kryfo"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\PushNotifications\Backup\app.kryfo"; Flags: uninsdeletekey

[Run]
Filename: "{app}\kryfo.exe"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent

[Code]
// the data lives outside {app}, so the uninstaller asks, with delete as the
// default. a silent uninstall keeps it: only a person can say yes.
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  Dir: String;
begin
  if CurUninstallStep <> usPostUninstall then
    Exit;
  Dir := ExpandConstant('{localappdata}\Kryfo');
  if (not DirExists(Dir)) or UninstallSilent then
    Exit;
  if MsgBox('Also delete your Kryfo data?' + #13#10#13#10 +
      'This removes your chats, keys and media in ' + Dir +
      '. It cannot be undone. Choose No to keep them for a later install.',
      mbConfirmation, MB_YESNO or MB_DEFBUTTON1) = IDYES then
    DelTree(Dir, True, True, True);
end;
