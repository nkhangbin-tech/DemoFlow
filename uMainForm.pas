unit uMainForm;

interface

uses
  PAConfiguration,
  PALogger,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.Forms,
  Vcl.Menus,
  Vcl.StdCtrls,
  System.Classes,
  System.SysUtils,
  Winapi.Messages;

type
  TMainForm = class(TForm)
    StatusLabel: TLabel;
    LoggerStatusLabel: TLabel;
    ConfigurationStatusLabel: TLabel;
    SafeModeStatusLabel: TLabel;
    ConfigurationPathLabel: TLabel;
    DiagnosticLabel: TLabel;
    CloseButton: TButton;
    TrayIcon: TTrayIcon;
    TrayPopupMenu: TPopupMenu;
    ShowMenuItem: TMenuItem;
    ReloadMenuItem: TMenuItem;
    StatusMenuItem: TMenuItem;
    ServicesMenuItem: TMenuItem;
    TraySeparator: TMenuItem;
    ExitMenuItem: TMenuItem;
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormResize(Sender: TObject);
    procedure CloseButtonClick(Sender: TObject);
    procedure TrayIconDblClick(Sender: TObject);
    procedure ShowMenuItemClick(Sender: TObject);
    procedure ReloadMenuItemClick(Sender: TObject);
    procedure ExitMenuItemClick(Sender: TObject);
  private
    FLogger: TLogger;
    FConfigurationStore: TConfigurationStore;
    FConfigurationPath: string;
    FStopping: Boolean;
    FFinalExitRequested: Boolean;
    procedure StartApplication;
    procedure StopApplication;
    procedure InitializeTray;
    procedure HideToTray;
    procedure RestoreFromTray;
    procedure RequestApplicationExit;
    procedure ReloadConfiguration;
    procedure UpdateTrayStatus;
    procedure WMQueryEndSession(var Message: TWMQueryEndSession);
      message WM_QUERYENDSESSION;
    procedure SetDiagnostic(const Value: string);
    function ApplicationDataDirectory: string;
  end;

var
  MainForm: TMainForm;

implementation

{$R *.dfm}

function TMainForm.ApplicationDataDirectory: string;
var
  LocalAppData: string;
begin
  LocalAppData := GetEnvironmentVariable('LOCALAPPDATA');
  if LocalAppData = '' then
    raise Exception.Create('LOCALAPPDATA is not available.');
  Result := IncludeTrailingPathDelimiter(LocalAppData) + 'PresenterAssistant';
end;

procedure TMainForm.SetDiagnostic(const Value: string);
begin
  DiagnosticLabel.Caption := 'Startup diagnostic: ' + Value;
  UpdateTrayStatus;
end;

procedure TMainForm.StartApplication;
var
  ApplicationDirectory, LogPath: string;
  ConfigurationResult: TConfigurationResult;
begin
  StatusLabel.Caption := 'Application status: starting';
  LoggerStatusLabel.Caption := 'Logger: initializing';
  ConfigurationStatusLabel.Caption := 'Configuration: loading';
  SafeModeStatusLabel.Caption := 'Safe mode: evaluating';
  try
    ApplicationDirectory := ApplicationDataDirectory;
    FConfigurationPath := IncludeTrailingPathDelimiter(ApplicationDirectory) +
      'config.json';
    ConfigurationPathLabel.Caption := 'Configuration path: ' + FConfigurationPath;
    ForceDirectories(ApplicationDirectory);
    LogPath := IncludeTrailingPathDelimiter(ApplicationDirectory) +
      'Logs\app.log';
  except
    on E: Exception do
    begin
      LoggerStatusLabel.Caption := 'Logger: unavailable';
      ConfigurationStatusLabel.Caption := 'Configuration: not loaded';
      SafeModeStatusLabel.Caption := 'Safe mode: active';
      StatusLabel.Caption := 'Application status: running in safe mode';
      SetDiagnostic(E.Message);
      Exit;
    end;
  end;

  try
    FLogger := TLogger.Create(LogPath);
    LoggerStatusLabel.Caption := 'Logger: initialized';
    FLogger.Log(lsInfo, 'Application startup', 'startup');
  except
    on E: Exception do
    begin
      FLogger := nil;
      LoggerStatusLabel.Caption := 'Logger: unavailable';
      SetDiagnostic('Logger initialization failed: ' + E.Message);
    end;
  end;

  FConfigurationStore := TConfigurationStore.Create;
  ConfigurationResult := FConfigurationStore.Reload(FConfigurationPath);
  if ConfigurationResult.Succeeded then
  begin
    ConfigurationStatusLabel.Caption := 'Configuration: loaded';
    SafeModeStatusLabel.Caption := 'Safe mode: inactive';
    StatusLabel.Caption := 'Application status: ready; automation services disabled';
    SetDiagnostic('Configuration loaded successfully.');
    if FLogger <> nil then
      FLogger.Log(lsInfo, 'Configuration loaded', 'startup');
  end
  else
  begin
    ConfigurationStatusLabel.Caption := 'Configuration: not loaded';
    SafeModeStatusLabel.Caption := 'Safe mode: active';
    StatusLabel.Caption := 'Application status: running in safe mode';
    if Length(ConfigurationResult.Diagnostics) > 0 then
      SetDiagnostic(ConfigurationResult.Diagnostics[0].Description)
    else
      SetDiagnostic('Configuration could not be activated.');
    if FLogger <> nil then
      FLogger.Log(lsWarning, 'Configuration was not activated; safe mode is active',
        'startup');
  end;
  UpdateTrayStatus;
end;

procedure TMainForm.StopApplication;
begin
  if FStopping then
    Exit;
  FStopping := True;
  StatusLabel.Caption := 'Application status: stopping';
  if FLogger <> nil then
  begin
    FLogger.Log(lsInfo, 'Application shutdown', 'shutdown');
    FLogger.Flush(2000);
    FLogger.Shutdown(2000);
    FreeAndNil(FLogger);
  end;
  FreeAndNil(FConfigurationStore);
end;

procedure TMainForm.InitializeTray;
begin
  try
    TrayIcon.Icon.Assign(Application.Icon);
    TrayIcon.Hint := 'Presenter Assistant';
    UpdateTrayStatus;
    TrayIcon.Visible := True;
  except
    on E: Exception do
      SetDiagnostic('Tray initialization failed: ' + E.Message);
  end;
end;

procedure TMainForm.UpdateTrayStatus;
var
  SafeMode: Boolean;
begin
  SafeMode := Pos('Safe mode: active', SafeModeStatusLabel.Caption) = 1;
  if SafeMode then
    StatusMenuItem.Caption := 'Status: safe mode'
  else if ConfigurationStatusLabel.Caption = 'Configuration: loaded' then
    StatusMenuItem.Caption := 'Status: configuration loaded'
  else
    StatusMenuItem.Caption := 'Status: configuration not loaded';
  ServicesMenuItem.Caption := 'Automation services are not implemented';
  ReloadMenuItem.Enabled := not FStopping;
  ShowMenuItem.Enabled := not FStopping;
  ExitMenuItem.Enabled := not FStopping;
  TrayIcon.Hint := 'Presenter Assistant - ' + StatusMenuItem.Caption;
end;

procedure TMainForm.HideToTray;
begin
  if FFinalExitRequested or FStopping then
    Exit;
  Hide;
end;

procedure TMainForm.RestoreFromTray;
begin
  if FStopping then
    Exit;
  Show;
  WindowState := wsNormal;
  Application.Restore;
  BringToFront;
end;

procedure TMainForm.RequestApplicationExit;
begin
  if FFinalExitRequested then
    Exit;
  FFinalExitRequested := True;
  if TrayIcon.Visible then
    TrayIcon.Visible := False;
  Close;
end;

procedure TMainForm.ReloadConfiguration;
var
  ConfigurationResult: TConfigurationResult;
  HasActiveConfiguration: Boolean;
  ActiveConfiguration: TPAConfiguration;
begin
  if FStopping or (FConfigurationStore = nil) then
    Exit;
  ConfigurationResult := FConfigurationStore.Reload(FConfigurationPath);
  if ConfigurationResult.Succeeded then
  begin
    ConfigurationStatusLabel.Caption := 'Configuration: loaded';
    SafeModeStatusLabel.Caption := 'Safe mode: inactive';
    StatusLabel.Caption := 'Application status: ready; automation services disabled';
    SetDiagnostic('Configuration reloaded successfully.');
    if FLogger <> nil then
      FLogger.Log(lsInfo, 'Configuration reloaded', 'configuration');
  end
  else
  begin
    HasActiveConfiguration := FConfigurationStore.TryGetActive(
      ActiveConfiguration);
    if HasActiveConfiguration then
    begin
      ConfigurationStatusLabel.Caption := 'Configuration: loaded (reload failed)';
      SafeModeStatusLabel.Caption := 'Safe mode: inactive';
      StatusLabel.Caption := 'Application status: ready; automation services disabled';
    end
    else
    begin
      ConfigurationStatusLabel.Caption := 'Configuration: not loaded';
      SafeModeStatusLabel.Caption := 'Safe mode: active';
      StatusLabel.Caption := 'Application status: running in safe mode';
    end;
    if Length(ConfigurationResult.Diagnostics) > 0 then
      SetDiagnostic(ConfigurationResult.Diagnostics[0].Description)
    else
      SetDiagnostic('Configuration reload failed.');
    if FLogger <> nil then
      FLogger.Log(lsWarning, 'Configuration reload failed; previous state preserved',
        'configuration');
  end;
  UpdateTrayStatus;
end;

procedure TMainForm.FormCreate(Sender: TObject);
begin
  StartApplication;
  InitializeTray;
end;

procedure TMainForm.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  if not FFinalExitRequested then
  begin
    Action := caNone;
    HideToTray;
    Exit;
  end;
  StopApplication;
end;

procedure TMainForm.FormResize(Sender: TObject);
begin
  if WindowState = wsMinimized then
    HideToTray;
end;

procedure TMainForm.CloseButtonClick(Sender: TObject);
begin
  HideToTray;
end;

procedure TMainForm.TrayIconDblClick(Sender: TObject);
begin
  RestoreFromTray;
end;

procedure TMainForm.ShowMenuItemClick(Sender: TObject);
begin
  RestoreFromTray;
end;

procedure TMainForm.ReloadMenuItemClick(Sender: TObject);
begin
  ReloadConfiguration;
end;

procedure TMainForm.ExitMenuItemClick(Sender: TObject);
begin
  RequestApplicationExit;
end;

procedure TMainForm.WMQueryEndSession(var Message: TWMQueryEndSession);
begin
  FFinalExitRequested := True;
  if TrayIcon.Visible then
    TrayIcon.Visible := False;
  StopApplication;
  Message.Result := 1;
end;

end.
