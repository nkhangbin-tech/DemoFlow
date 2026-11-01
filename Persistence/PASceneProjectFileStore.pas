unit PASceneProjectFileStore;

interface

uses
  PASceneDocumentCodec,
  PASceneDomain;

type
  TSceneFileOperationResult = record
    Success: Boolean;
    ErrorMessage: string;
  end;

  TSceneFileLoadResult = record
    Success: Boolean;
    ErrorMessage: string;
    DocumentResult: TSceneDocumentResult;
  end;

function SaveSceneProject(
  const FileName: string;
  const Document: TSceneAuthoringSnapshot): TSceneFileOperationResult;
function LoadSceneProject(const FileName: string): TSceneFileLoadResult;

implementation

uses
  System.IOUtils,
  System.SysUtils,
  Winapi.Windows;

function NewTemporaryName(const FileName: string): string;
var
  Guid: TGUID;
begin
  if CreateGUID(Guid) <> 0 then
    RaiseLastOSError;
  Result := TPath.Combine(ExtractFilePath(FileName),
    '.' + ExtractFileName(FileName) + '.' +
    StringReplace(GUIDToString(Guid), '{', '', []) + '.tmp');
end;

function SaveSceneProject(
  const FileName: string;
  const Document: TSceneAuthoringSnapshot): TSceneFileOperationResult;
var
  Text, TempName: string;
  ExistingDestination: Boolean;
begin
  Result := Default(TSceneFileOperationResult);
  TempName := '';
  try
    Text := SerializeSceneDocument(Document);
    TempName := NewTemporaryName(FileName);
    TFile.WriteAllText(TempName, Text, TEncoding.UTF8);
    ExistingDestination := TFile.Exists(FileName);
    if ExistingDestination then
    begin
      if not ReplaceFile(PWideChar(FileName), PWideChar(TempName), nil,
        0, nil, nil) then
        RaiseLastOSError;
    end
    else if not MoveFileEx(PWideChar(TempName), PWideChar(FileName),
      MOVEFILE_WRITE_THROUGH) then
      RaiseLastOSError;
    TempName := '';
    Result.Success := True;
  except
    on E: Exception do
      Result.ErrorMessage := 'Scene Project could not be saved: ' + E.Message;
  end;
  if (TempName <> '') and TFile.Exists(TempName) then
    try
      TFile.Delete(TempName);
    except
      on E: Exception do
        if Result.ErrorMessage = '' then
          Result.ErrorMessage := 'Temporary Scene Project cleanup failed: ' +
            E.Message;
    end;
end;

function LoadSceneProject(const FileName: string): TSceneFileLoadResult;
var
  Text: string;
begin
  Result := Default(TSceneFileLoadResult);
  try
    if not TFile.Exists(FileName) then
    begin
      Result.ErrorMessage := 'Scene Project file does not exist.';
      Exit;
    end;
    try
      Text := TFile.ReadAllText(FileName, TEncoding.UTF8);
    except
      on E: Exception do
      begin
        Result.ErrorMessage := 'Scene Project file could not be read: ' +
          E.Message;
        Exit;
      end;
    end;
    Result.DocumentResult := ParseSceneDocument(Text);
    if not Result.DocumentResult.Success then
    begin
      Result.ErrorMessage := 'Scene Project document is invalid.';
      Exit;
    end;
    Result.Success := True;
  except
    on E: Exception do
      Result.ErrorMessage := 'Scene Project could not be loaded: ' + E.Message;
  end;
end;

end.
