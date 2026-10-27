unit uMainForm;

interface

uses
  PAConfiguration,
  PALogger,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.StdCtrls,
  System.Classes,
  System.SysUtils;

type
  TMainForm = class(TForm)
    StatusLabel: TLabel;
    LoggerStatusLabel: TLabel;
    ConfigurationStatusLabel: TLabel;
    SafeModeStatusLabel: TLabel;
    ConfigurationPathLabel: TLabel;
    DiagnosticLabel: TLabel;
    CloseButton: TButton;
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure CloseButtonClick(Sender: TObject);
  private
    FLogger: TLogger;
    FConfigurationStore: TConfigurationStore;
    FConfigurationPath: string;
    FStopping: Boolean;
    procedure StartApplication;
    procedure StopApplication;
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

procedure TMainForm.FormCreate(Sender: TObject);
begin
  StartApplication;
end;

procedure TMainForm.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  StopApplication;
end;

procedure TMainForm.CloseButtonClick(Sender: TObject);
begin
  Close;
end;

end.
