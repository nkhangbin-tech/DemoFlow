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
    SourceFileName: string;
  end;

function SaveSceneProject(
  const FileName: string;
  const Document: TSceneAuthoringSnapshot): TSceneFileOperationResult;
function LoadSceneProject(const FileName: string): TSceneFileLoadResult;

// The caller retains the loaded source context while editing a separate document.
// This operation never mutates either record; adopt the target only after Success.
function SaveSceneProjectAs(const Source: TSceneFileLoadResult;
  const FileName: string;
  const Document: TSceneAuthoringSnapshot): TSceneFileOperationResult;

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
  Existing: TSceneFileLoadResult;
begin
  Result := Default(TSceneFileOperationResult);
  TempName := '';
  try
    // Existing legacy sources are read-only through ordinary Save.
    if TFile.Exists(FileName) then
    begin
      Existing := LoadSceneProject(FileName);
      if Existing.Success and (Existing.DocumentResult.SourceFormatVersion in [1, 2]) then
        raise EInvalidOpException.Create('Legacy format requires Save As to a different file.');
      if Existing.Success and (Existing.DocumentResult.SourceFormatVersion = 3) and
        (Document.PowerPointFileName = '') then
        raise EInvalidOpException.Create('Version 3 Save requires PowerPoint metadata.');
    end;
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

function SaveSceneProjectAs(const Source: TSceneFileLoadResult;
  const FileName: string;
  const Document: TSceneAuthoringSnapshot): TSceneFileOperationResult;
var
  SourceHandle, TargetHandle: THandle;
  SourceInfo, TargetInfo: TByHandleFileInformation;
begin
  Result := Default(TSceneFileOperationResult);
  try
    if not Source.Success or not Source.DocumentResult.Success or
      not (Source.DocumentResult.SourceFormatVersion in [1, 2, 3]) or
      (Source.SourceFileName = '') then
      raise EInvalidOpException.Create('Save As requires a successfully loaded source.');
    if (Source.DocumentResult.SourceFormatVersion in [1, 2]) and
      (Document.PowerPointFileName = '') then
      raise EInvalidOpException.Create('Legacy Save As v3 requires confirmed PowerPoint metadata.');
    if SameText(TPath.GetFullPath(FileName), Source.SourceFileName) then
      raise EInvalidOpException.Create('Save As must use a different source and destination.');
    // Protect the original during the entire write, including alternate path aliases.
    // No write/delete sharing: replacing the original through an alias must fail.
    SourceHandle := CreateFile(PWideChar(Source.SourceFileName), GENERIC_READ,
      FILE_SHARE_READ, nil, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);
    if SourceHandle = INVALID_HANDLE_VALUE then
      RaiseLastOSError;
    try
      if not GetFileInformationByHandle(SourceHandle, SourceInfo) then RaiseLastOSError;
      TargetHandle := CreateFile(PWideChar(FileName), GENERIC_READ,
        FILE_SHARE_READ or FILE_SHARE_WRITE or FILE_SHARE_DELETE, nil, OPEN_EXISTING,
        FILE_ATTRIBUTE_NORMAL, 0);
      if TargetHandle <> INVALID_HANDLE_VALUE then
      try
        if not GetFileInformationByHandle(TargetHandle, TargetInfo) then RaiseLastOSError;
        if (SourceInfo.dwVolumeSerialNumber = TargetInfo.dwVolumeSerialNumber) and
          (SourceInfo.nFileIndexHigh = TargetInfo.nFileIndexHigh) and
          (SourceInfo.nFileIndexLow = TargetInfo.nFileIndexLow) then
          raise EInvalidOpException.Create('Save As destination aliases the source file.');
      finally CloseHandle(TargetHandle); end;
      Result := SaveSceneProject(FileName, Document);
    finally
      CloseHandle(SourceHandle);
    end;
  except
    on E: Exception do
      Result.ErrorMessage := 'Scene Project Save As failed: ' + E.Message;
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
    Result.SourceFileName := TPath.GetFullPath(FileName);
    Result.Success := True;
  except
    on E: Exception do
      Result.ErrorMessage := 'Scene Project could not be loaded: ' + E.Message;
  end;
end;

end.
