unit PARecentProject;
interface
function RecentProjectPath(out LastWorked: string): string;
procedure RecordRecentProject(const ProjectPath: string);
implementation
uses System.SysUtils, System.IOUtils, System.IniFiles;
function IndexPath: string;
begin
  Result := TPath.Combine(GetEnvironmentVariable('LOCALAPPDATA'), 'PresenterAssistant');
  ForceDirectories(Result);
  Result := TPath.Combine(Result, 'recent-project.ini');
end;
function RecentProjectPath(out LastWorked: string): string;
var Ini: TMemIniFile;
begin
  Result := ''; LastWorked := '';
  try
    Ini := TMemIniFile.Create(IndexPath, TEncoding.UTF8);
    try
      Result := Ini.ReadString('Recent', 'Path', '');
      LastWorked := Ini.ReadString('Recent', 'LastWorked', '');
      if not TFile.Exists(Result) then Result := '';
    finally Ini.Free; end;
  except Result := ''; LastWorked := ''; end;
end;
procedure RecordRecentProject(const ProjectPath: string);
var Ini: TMemIniFile;
begin
  if (ProjectPath = '') or not TFile.Exists(ProjectPath) then Exit;
  try
    Ini := TMemIniFile.Create(IndexPath, TEncoding.UTF8);
    try
      Ini.WriteString('Recent', 'Path', TPath.GetFullPath(ProjectPath));
      Ini.WriteString('Recent', 'LastWorked', FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));
      Ini.UpdateFile;
    finally Ini.Free; end;
  except
    // Index failure never rolls back a successful document operation.
  end;
end;
end.
