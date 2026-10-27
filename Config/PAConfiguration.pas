unit PAConfiguration;

interface

uses
  System.JSON,
  System.SysUtils,
  PADomainTypes;

type
  TBrowserProfile = record
    Id: string;
    Executable: string;
    ClassName: string;
    TitlePattern: string;
    HasUrl: Boolean;
    Url: string;
    LaunchUrl: Boolean;
    Activate: Boolean;
    Autoplay: Boolean;
  end;

  TAudioRuleConfiguration = record
    Id: string;
    Priority: Integer;
    Slide: TSlideSelector;
    Foreground: TForegroundSelector;
    LevelPercent: Byte;
  end;

  TAudioConfiguration = record
    Enabled: Boolean;
    DeltaMode: Boolean;
    ContextMaxAgeMs: Cardinal;
    Rules: TArray<TAudioRuleConfiguration>;
  end;

  TPAConfiguration = record
    SchemaVersion: Integer;
    Mode: TApplicationMode;
    Audio: TAudioConfiguration;
    BrowserProfiles: TArray<TBrowserProfile>;
    Sequence: TArray<TSequenceEntry>;
  end;

  TConfigurationResultKind = (
    crSuccess,
    crValidationError,
    crMalformedJson,
    crUnsupportedVersion,
    crMissingFile,
    crFileError,
    crSaveError
  );

  TConfigurationResult = record
    Kind: TConfigurationResultKind;
    Configuration: TPAConfiguration;
    Diagnostics: TArray<TConfigurationDiagnostic>;
    function Succeeded: Boolean;
    function HasErrors: Boolean;
  end;

  TConfigurationStore = class
  private
    FActive: TPAConfiguration;
    FHasActive: Boolean;
  public
    function ParseText(const Text: string): TConfigurationResult;
    function LoadFromFile(const FileName: string): TConfigurationResult;
    function Reload(const FileName: string): TConfigurationResult;
    function SaveToFile(const FileName: string;
      const Configuration: TPAConfiguration): TConfigurationResult;
    function Serialize(const Configuration: TPAConfiguration): string;
    function TryGetActive(out Configuration: TPAConfiguration): Boolean;
  end;

function ValidateConfiguration(const Configuration: TPAConfiguration):
  TArray<TConfigurationDiagnostic>;
function SerializeConfiguration(const Configuration: TPAConfiguration): string;
function ParseConfigurationText(const Text: string): TConfigurationResult;

implementation

uses
  System.Classes,
  System.Generics.Collections,
  System.IOUtils,
  System.StrUtils,
  Winapi.Windows;

const
  CurrentSchemaVersion = 1;

procedure AddDiagnostic(var Diagnostics: TArray<TConfigurationDiagnostic>;
  Severity: TDiagnosticSeverity; const Path, Description: string);
var
  Index: Integer;
begin
  Index := Length(Diagnostics);
  SetLength(Diagnostics, Index + 1);
  Diagnostics[Index].Severity := Severity;
  Diagnostics[Index].FieldPath := Path;
  Diagnostics[Index].Description := Description;
end;

function IsError(const Diagnostic: TConfigurationDiagnostic): Boolean;
begin
  Result := Diagnostic.Severity = dsError;
end;

function HasDiagnosticErrors(
  const Diagnostics: TArray<TConfigurationDiagnostic>): Boolean;
var
  Diagnostic: TConfigurationDiagnostic;
begin
  Result := False;
  for Diagnostic in Diagnostics do
    if IsError(Diagnostic) then
      Exit(True);
end;

function JsonObject(Value: TJSONValue; const Path: string;
  var Diagnostics: TArray<TConfigurationDiagnostic>): TJSONObject;
begin
  if Value is TJSONObject then
    Result := TJSONObject(Value)
  else
  begin
    Result := nil;
    AddDiagnostic(Diagnostics, dsError, Path, 'Expected a JSON object.');
  end;
end;

function RequiredValue(ObjectValue: TJSONObject; const Name, Path: string;
  var Diagnostics: TArray<TConfigurationDiagnostic>): TJSONValue;
begin
  Result := ObjectValue.GetValue(Name);
  if Result = nil then
    AddDiagnostic(Diagnostics, dsError, Path + '/' + Name,
      'Required property is missing.');
end;

function StringValue(Value: TJSONValue; const Path: string;
  var Diagnostics: TArray<TConfigurationDiagnostic>): string;
begin
  if not (Value is TJSONString) then
  begin
    AddDiagnostic(Diagnostics, dsError, Path, 'Expected a string.');
    Exit('');
  end;
  Result := TJSONString(Value).Value;
end;

function BooleanValue(Value: TJSONValue; const Path: string;
  var Diagnostics: TArray<TConfigurationDiagnostic>): Boolean;
begin
  if (Value is TJSONTrue) then
    Exit(True);
  if (Value is TJSONFalse) then
    Exit(False);
  AddDiagnostic(Diagnostics, dsError, Path, 'Expected a Boolean.');
  Result := False;
end;

function IntegerValue(Value: TJSONValue; const Path: string;
  var Diagnostics: TArray<TConfigurationDiagnostic>): Integer;
var
  Number: TJSONNumber;
begin
  if not (Value is TJSONNumber) then
  begin
    AddDiagnostic(Diagnostics, dsError, Path, 'Expected an integer.');
    Exit(0);
  end;
  Number := TJSONNumber(Value);
  if not TryStrToInt(Number.Value, Result) then
  begin
    AddDiagnostic(Diagnostics, dsError, Path,
      'Expected an integer without a fractional component.');
    Result := 0;
  end;
end;

function NullableString(Value: TJSONValue; const Path: string;
  var Diagnostics: TArray<TConfigurationDiagnostic>;
  out HasValue: Boolean): string;
var
  BeforeCount: Integer;
begin
  HasValue := False;
  if Value is TJSONNull then
    Exit('');
  BeforeCount := Length(Diagnostics);
  Result := StringValue(Value, Path, Diagnostics);
  HasValue := Length(Diagnostics) = BeforeCount;
end;

procedure CheckProperties(ObjectValue: TJSONObject; const Path: string;
  const Allowed: array of string;
  var Diagnostics: TArray<TConfigurationDiagnostic>);
var
  Pair: TJSONPair;
  AllowedProperty: string;
  Found: Boolean;
begin
  for Pair in ObjectValue do
  begin
    Found := False;
    for AllowedProperty in Allowed do
      if SameText(Pair.JsonString.Value, AllowedProperty) then
        Found := True;
    if not Found then
      AddDiagnostic(Diagnostics, dsError, Path + '/' + Pair.JsonString.Value,
        'Unknown property.');
  end;
end;

function ParseMode(const Value, Path: string;
  var Diagnostics: TArray<TConfigurationDiagnostic>): TApplicationMode;
begin
  if Value = 'passThrough' then
    Exit(amPassThrough);
  if Value = 'interceptAndRoute' then
    Exit(amInterceptAndRoute);
  AddDiagnostic(Diagnostics, dsError, Path,
    'Expected passThrough or interceptAndRoute.');
  Result := amUnknown;
end;

function ParseSlideSelector(Value: TJSONValue; const Path: string;
  var Diagnostics: TArray<TConfigurationDiagnostic>): TSlideSelector;
var
  ObjectValue: TJSONObject;
  Kind: string;
  SelectorValue: TJSONValue;
begin
  Result := Default(TSlideSelector);
  ObjectValue := JsonObject(Value, Path, Diagnostics);
  if ObjectValue = nil then
    Exit;
  CheckProperties(ObjectValue, Path,
    ['kind', 'value', 'slideIndex', 'showPosition'], Diagnostics);
  SelectorValue := RequiredValue(ObjectValue, 'kind', Path, Diagnostics);
  if SelectorValue = nil then
    Exit;
  Kind := StringValue(SelectorValue, Path + '/kind', Diagnostics);
  if Kind = 'wildcard' then
    Result.Kind := sskWildcard
  else if Kind = 'slideIndex' then
  begin
    Result.Kind := sskSlideIndex;
    SelectorValue := RequiredValue(ObjectValue, 'value', Path, Diagnostics);
    if SelectorValue <> nil then
    begin
      Result.Value := IntegerValue(SelectorValue, Path + '/value', Diagnostics);
      Result.HasValue := True;
    end;
  end
  else if Kind = 'showPosition' then
  begin
    Result.Kind := sskShowPosition;
    SelectorValue := RequiredValue(ObjectValue, 'value', Path, Diagnostics);
    if SelectorValue <> nil then
    begin
      Result.Value := IntegerValue(SelectorValue, Path + '/value', Diagnostics);
      Result.HasValue := True;
    end;
  end
  else if Kind = 'entryId' then
  begin
    Result.Kind := sskEntryId;
    SelectorValue := RequiredValue(ObjectValue, 'value', Path, Diagnostics);
    if SelectorValue <> nil then
    begin
      Result.EntryId := StringValue(SelectorValue, Path + '/value', Diagnostics);
      Result.HasValue := True;
    end;
  end
  else
    AddDiagnostic(Diagnostics, dsError, Path + '/kind',
      'Unsupported slide selector kind.');
end;

function ParseForegroundSelector(Value: TJSONValue; const Path: string;
  var Diagnostics: TArray<TConfigurationDiagnostic>): TForegroundSelector;
var
  ObjectValue: TJSONObject;
  Kind: string;
  ProfileValue: TJSONValue;
begin
  Result := Default(TForegroundSelector);
  ObjectValue := JsonObject(Value, Path, Diagnostics);
  if ObjectValue = nil then
    Exit;
  CheckProperties(ObjectValue, Path, ['kind', 'profileId'], Diagnostics);
  ProfileValue := RequiredValue(ObjectValue, 'kind', Path, Diagnostics);
  if ProfileValue = nil then
    Exit;
  Kind := StringValue(ProfileValue, Path + '/kind', Diagnostics);
  if Kind = 'powerPointSlideshow' then
    Result.Kind := fskPowerPointSlideshow
  else if Kind = 'powerPointEditor' then
    Result.Kind := fskPowerPointEditor
  else if Kind = 'browser' then
  begin
    Result.Kind := fskBrowser;
    ProfileValue := RequiredValue(ObjectValue, 'profileId', Path, Diagnostics);
    if ProfileValue <> nil then
      Result.BrowserProfileId := StringValue(ProfileValue,
        Path + '/profileId', Diagnostics);
  end
  else if Kind = 'other' then
    Result.Kind := fskOther
  else if Kind = 'unknown' then
    Result.Kind := fskUnknownApplication
  else if Kind = 'wildcard' then
    Result.Kind := fskWildcard
  else
    AddDiagnostic(Diagnostics, dsError, Path + '/kind',
      'Unsupported foreground selector kind.');
end;

function ParseJsonText(const Text: string;
  var Diagnostics: TArray<TConfigurationDiagnostic>): TJSONObject;
var
  Value: TJSONValue;
begin
  Result := nil;
  try
    Value := TJSONObject.ParseJSONValue(Text);
  except
    on E: Exception do
    begin
      AddDiagnostic(Diagnostics, dsError, '',
        'Malformed JSON: ' + E.Message);
      Exit;
    end;
  end;
  if Value = nil then
  begin
    AddDiagnostic(Diagnostics, dsError, '',
      'Malformed JSON: no JSON value was found.');
    Exit;
  end;
  Result := Value as TJSONObject;
  if Result = nil then
  begin
    AddDiagnostic(Diagnostics, dsError, '',
      'The configuration root must be a JSON object.');
    Value.Free;
  end;
end;

function ParseConfigurationText(const Text: string): TConfigurationResult;
var
  Root: TJSONObject;
  Value: TJSONValue;
  Version: Integer;
  BrowserArray, RuleArray, SequenceArray: TJSONArray;
  ObjectValue: TJSONObject;
  Index: Integer;
  Browser: TBrowserProfile;
  Rule: TAudioRuleConfiguration;
  Entry: TSequenceEntry;
  HasUrl: Boolean;
  LevelValue: Integer;
begin
  Result := Default(TConfigurationResult);
  Result.Kind := crMalformedJson;
  Root := ParseJsonText(Text, Result.Diagnostics);
  if Root = nil then
    Exit;
  try
    CheckProperties(Root, '', ['schemaVersion', 'mode', 'audio',
      'browserProfiles', 'sequence'], Result.Diagnostics);
    Value := RequiredValue(Root, 'schemaVersion', '', Result.Diagnostics);
    if Value = nil then
      Exit;
    Version := IntegerValue(Value, '/schemaVersion', Result.Diagnostics);
    if Version <> CurrentSchemaVersion then
    begin
      AddDiagnostic(Result.Diagnostics, dsError, '/schemaVersion',
        'Only schema version 1 is supported.');
      Result.Kind := crUnsupportedVersion;
      Exit;
    end;
    Result.Configuration.SchemaVersion := Version;
    Value := RequiredValue(Root, 'mode', '', Result.Diagnostics);
    if Value <> nil then
      Result.Configuration.Mode := ParseMode(
        StringValue(Value, '/mode', Result.Diagnostics), '/mode',
        Result.Diagnostics);

    Value := RequiredValue(Root, 'audio', '', Result.Diagnostics);
    if Value <> nil then
    begin
      ObjectValue := JsonObject(Value, '/audio', Result.Diagnostics);
      if ObjectValue <> nil then
      begin
        CheckProperties(ObjectValue, '/audio',
          ['enabled', 'deltaMode', 'contextMaxAgeMs', 'rules'],
          Result.Diagnostics);
        Value := RequiredValue(ObjectValue, 'enabled', '/audio',
          Result.Diagnostics);
        if Value <> nil then
          Result.Configuration.Audio.Enabled := BooleanValue(Value,
            '/audio/enabled', Result.Diagnostics);
        Value := RequiredValue(ObjectValue, 'deltaMode', '/audio',
          Result.Diagnostics);
        if Value <> nil then
          Result.Configuration.Audio.DeltaMode := BooleanValue(Value,
            '/audio/deltaMode', Result.Diagnostics);
        Value := RequiredValue(ObjectValue, 'contextMaxAgeMs', '/audio',
          Result.Diagnostics);
        if Value <> nil then
          Result.Configuration.Audio.ContextMaxAgeMs := Cardinal(
            IntegerValue(Value, '/audio/contextMaxAgeMs',
              Result.Diagnostics));
        Value := RequiredValue(ObjectValue, 'rules', '/audio',
          Result.Diagnostics);
        if Value <> nil then
        begin
          RuleArray := Value as TJSONArray;
          if RuleArray = nil then
            AddDiagnostic(Result.Diagnostics, dsError, '/audio/rules',
              'Expected an array.')
          else
            for Index := 0 to RuleArray.Count - 1 do
            begin
              Rule := Default(TAudioRuleConfiguration);
              ObjectValue := JsonObject(RuleArray.Items[Index],
                Format('/audio/rules/%d', [Index]), Result.Diagnostics);
              if ObjectValue = nil then
                Continue;
              CheckProperties(ObjectValue,
                Format('/audio/rules/%d', [Index]),
                ['id', 'priority', 'slide', 'foreground', 'levelPercent'],
                Result.Diagnostics);
              Value := RequiredValue(ObjectValue, 'id',
                Format('/audio/rules/%d', [Index]), Result.Diagnostics);
              if Value <> nil then
                Rule.Id := StringValue(Value,
                  Format('/audio/rules/%d/id', [Index]), Result.Diagnostics);
              Value := RequiredValue(ObjectValue, 'priority',
                Format('/audio/rules/%d', [Index]), Result.Diagnostics);
              if Value <> nil then
                Rule.Priority := IntegerValue(Value,
                  Format('/audio/rules/%d/priority', [Index]),
                  Result.Diagnostics);
              Value := RequiredValue(ObjectValue, 'slide',
                Format('/audio/rules/%d', [Index]), Result.Diagnostics);
              if Value <> nil then
                Rule.Slide := ParseSlideSelector(Value,
                  Format('/audio/rules/%d/slide', [Index]),
                  Result.Diagnostics);
              Value := RequiredValue(ObjectValue, 'foreground',
                Format('/audio/rules/%d', [Index]), Result.Diagnostics);
              if Value <> nil then
                Rule.Foreground := ParseForegroundSelector(Value,
                  Format('/audio/rules/%d/foreground', [Index]),
                  Result.Diagnostics);
              Value := RequiredValue(ObjectValue, 'levelPercent',
                Format('/audio/rules/%d', [Index]), Result.Diagnostics);
              if Value <> nil then
              begin
                LevelValue := IntegerValue(Value,
                  Format('/audio/rules/%d/levelPercent', [Index]),
                  Result.Diagnostics);
                if (LevelValue < 0) or (LevelValue > 100) then
                  AddDiagnostic(Result.Diagnostics, dsError,
                    Format('/audio/rules/%d/levelPercent', [Index]),
                    'Volume must be between 0 and 100.');
                Rule.LevelPercent := Byte(ClampPercentage(LevelValue));
              end;
              SetLength(Result.Configuration.Audio.Rules,
                Length(Result.Configuration.Audio.Rules) + 1);
              Result.Configuration.Audio.Rules[
                High(Result.Configuration.Audio.Rules)] := Rule;
            end;
        end;
      end;
    end;

    Value := RequiredValue(Root, 'browserProfiles', '', Result.Diagnostics);
    if Value <> nil then
    begin
      BrowserArray := Value as TJSONArray;
      if BrowserArray = nil then
        AddDiagnostic(Result.Diagnostics, dsError, '/browserProfiles',
          'Expected an array.')
      else
        for Index := 0 to BrowserArray.Count - 1 do
        begin
          Browser := Default(TBrowserProfile);
          ObjectValue := JsonObject(BrowserArray.Items[Index],
            Format('/browserProfiles/%d', [Index]), Result.Diagnostics);
          if ObjectValue = nil then
            Continue;
          CheckProperties(ObjectValue, Format('/browserProfiles/%d', [Index]),
            ['id', 'executable', 'className', 'titlePattern', 'url',
             'launchUrl', 'activate', 'autoplay'], Result.Diagnostics);
          Value := RequiredValue(ObjectValue, 'id',
            Format('/browserProfiles/%d', [Index]), Result.Diagnostics);
          if Value <> nil then
            Browser.Id := StringValue(Value,
              Format('/browserProfiles/%d/id', [Index]), Result.Diagnostics);
          Value := RequiredValue(ObjectValue, 'executable',
            Format('/browserProfiles/%d', [Index]), Result.Diagnostics);
          if Value <> nil then
            Browser.Executable := StringValue(Value,
              Format('/browserProfiles/%d/executable', [Index]),
              Result.Diagnostics);
          Value := RequiredValue(ObjectValue, 'className',
            Format('/browserProfiles/%d', [Index]), Result.Diagnostics);
          if Value <> nil then
            Browser.ClassName := StringValue(Value,
              Format('/browserProfiles/%d/className', [Index]),
              Result.Diagnostics);
          Value := RequiredValue(ObjectValue, 'titlePattern',
            Format('/browserProfiles/%d', [Index]), Result.Diagnostics);
          if Value <> nil then
            Browser.TitlePattern := StringValue(Value,
              Format('/browserProfiles/%d/titlePattern', [Index]),
              Result.Diagnostics);
          Value := RequiredValue(ObjectValue, 'url',
            Format('/browserProfiles/%d', [Index]), Result.Diagnostics);
          if Value <> nil then
            Browser.Url := NullableString(Value,
              Format('/browserProfiles/%d/url', [Index]),
              Result.Diagnostics, HasUrl);
          Browser.HasUrl := HasUrl;
          Value := RequiredValue(ObjectValue, 'launchUrl',
            Format('/browserProfiles/%d', [Index]), Result.Diagnostics);
          if Value <> nil then
            Browser.LaunchUrl := BooleanValue(Value,
              Format('/browserProfiles/%d/launchUrl', [Index]),
              Result.Diagnostics);
          Value := RequiredValue(ObjectValue, 'activate',
            Format('/browserProfiles/%d', [Index]), Result.Diagnostics);
          if Value <> nil then
            Browser.Activate := BooleanValue(Value,
              Format('/browserProfiles/%d/activate', [Index]),
              Result.Diagnostics);
          Value := RequiredValue(ObjectValue, 'autoplay',
            Format('/browserProfiles/%d', [Index]), Result.Diagnostics);
          if Value <> nil then
            Browser.Autoplay := BooleanValue(Value,
              Format('/browserProfiles/%d/autoplay', [Index]),
              Result.Diagnostics);
          SetLength(Result.Configuration.BrowserProfiles,
            Length(Result.Configuration.BrowserProfiles) + 1);
          Result.Configuration.BrowserProfiles[
            High(Result.Configuration.BrowserProfiles)] := Browser;
        end;
    end;

    Value := RequiredValue(Root, 'sequence', '', Result.Diagnostics);
    if Value <> nil then
    begin
      SequenceArray := Value as TJSONArray;
      if SequenceArray = nil then
        AddDiagnostic(Result.Diagnostics, dsError, '/sequence',
          'Expected an array.')
      else
        for Index := 0 to SequenceArray.Count - 1 do
        begin
          Entry := Default(TSequenceEntry);
          ObjectValue := JsonObject(SequenceArray.Items[Index],
            Format('/sequence/%d', [Index]), Result.Diagnostics);
          if ObjectValue = nil then
            Continue;
          CheckProperties(ObjectValue, Format('/sequence/%d', [Index]),
            ['id', 'kind', 'slide', 'browserProfile', 'build', 'next',
             'previous', 'browserReturn'], Result.Diagnostics);
          Value := RequiredValue(ObjectValue, 'id',
            Format('/sequence/%d', [Index]), Result.Diagnostics);
          if Value <> nil then
            Entry.Id := StringValue(Value,
              Format('/sequence/%d/id', [Index]), Result.Diagnostics);
          Value := RequiredValue(ObjectValue, 'kind',
            Format('/sequence/%d', [Index]), Result.Diagnostics);
          if Value <> nil then
          begin
            if StringValue(Value, Format('/sequence/%d/kind', [Index]),
              Result.Diagnostics) = 'powerPoint' then
              Entry.Kind := sekPowerPoint
            else if StringValue(Value, Format('/sequence/%d/kind', [Index]),
              Result.Diagnostics) = 'browser' then
              Entry.Kind := sekBrowser
            else
              AddDiagnostic(Result.Diagnostics,
                dsError, Format('/sequence/%d/kind', [Index]),
                'Expected powerPoint or browser.');
          end;
          Value := ObjectValue.GetValue('slide');
          if Value <> nil then
            Entry.Slide := ParseSlideSelector(Value,
              Format('/sequence/%d/slide', [Index]), Result.Diagnostics);
          Value := ObjectValue.GetValue('browserProfile');
          if Value <> nil then
            Entry.BrowserProfileId := StringValue(Value,
              Format('/sequence/%d/browserProfile', [Index]),
              Result.Diagnostics);
          Value := ObjectValue.GetValue('build');
          if Value <> nil then
          begin
            if Value is TJSONNull then
              Entry.HasConfiguredBuild := False
            else
            begin
              Entry.HasConfiguredBuild := True;
              Entry.ConfiguredBuild := IntegerValue(Value,
                Format('/sequence/%d/build', [Index]), Result.Diagnostics);
            end;
          end;
          Value := ObjectValue.GetValue('next');
          if Value <> nil then
            Entry.NextId := StringValue(Value,
              Format('/sequence/%d/next', [Index]), Result.Diagnostics);
          Value := ObjectValue.GetValue('previous');
          if Value <> nil then
            Entry.PreviousId := StringValue(Value,
              Format('/sequence/%d/previous', [Index]), Result.Diagnostics);
          Value := ObjectValue.GetValue('browserReturn');
          if Value <> nil then
            Entry.BrowserReturnId := StringValue(Value,
              Format('/sequence/%d/browserReturn', [Index]),
              Result.Diagnostics);
          SetLength(Result.Configuration.Sequence,
            Length(Result.Configuration.Sequence) + 1);
          Result.Configuration.Sequence[
            High(Result.Configuration.Sequence)] := Entry;
        end;
    end;
  finally
    Root.Free;
  end;
  Result.Diagnostics := ValidateConfiguration(Result.Configuration) +
    Result.Diagnostics;
  if HasDiagnosticErrors(Result.Diagnostics) then
    Result.Kind := crValidationError
  else
    Result.Kind := crSuccess;
end;

function FindBrowser(const Configuration: TPAConfiguration;
  const Id: string): Boolean;
var
  Item: TBrowserProfile;
begin
  Result := False;
  for Item in Configuration.BrowserProfiles do
    if Item.Id = Id then
      Exit(True);
end;

function FindEntry(const Configuration: TPAConfiguration;
  const Id: string): Boolean;
var
  Item: TSequenceEntry;
begin
  Result := False;
  for Item in Configuration.Sequence do
    if Item.Id = Id then
      Exit(True);
end;

function DuplicateId(const Id: string; const Seen: TArray<string>): Boolean;
var
  Existing: string;
begin
  Result := False;
  for Existing in Seen do
    if Existing = Id then
      Exit(True);
end;

function SelectorSpecificity(const Selector: TSlideSelector): Integer;
begin
  if Selector.Kind = sskWildcard then
    Result := 0
  else
    Result := 3;
end;

function ForegroundSpecificity(const Selector: TForegroundSelector): Integer;
begin
  case Selector.Kind of
    fskWildcard: Result := 0;
    fskBrowser:
      if Selector.BrowserProfileId = '' then Result := 1 else Result := 2;
  else
    Result := 1;
  end;
end;

function SameSpecificity(const Left, Right: TAudioRuleConfiguration): Boolean;
begin
  Result := (SelectorSpecificity(Left.Slide) +
    ForegroundSpecificity(Left.Foreground)) =
    (SelectorSpecificity(Right.Slide) +
    ForegroundSpecificity(Right.Foreground));
end;

function ValidateConfiguration(const Configuration: TPAConfiguration):
  TArray<TConfigurationDiagnostic>;
var
  Index, OtherIndex: Integer;
  Seen: TArray<string>;
  Browser: TBrowserProfile;
  Rule, OtherRule: TAudioRuleConfiguration;
  Entry: TSequenceEntry;
  Selector: TSlideSelector;
begin
  Result := [];
  if Configuration.SchemaVersion <> CurrentSchemaVersion then
    AddDiagnostic(Result, dsError, '/schemaVersion',
      'Only schema version 1 is supported.');
  if Configuration.Mode = amUnknown then
    AddDiagnostic(Result, dsError, '/mode', 'Mode is required.');
  SetLength(Seen, 0);
  for Index := 0 to Length(Configuration.BrowserProfiles) - 1 do
  begin
    Browser := Configuration.BrowserProfiles[Index];
    if Browser.Id = '' then
      AddDiagnostic(Result, dsError,
        Format('/browserProfiles/%d/id', [Index]), 'ID must not be empty.');
    if DuplicateId(Browser.Id, Seen) then
      AddDiagnostic(Result, dsError,
        Format('/browserProfiles/%d/id', [Index]), 'Duplicate profile ID.');
    SetLength(Seen, Length(Seen) + 1);
    Seen[High(Seen)] := Browser.Id;
    if Browser.Executable = '' then
      AddDiagnostic(Result, dsError,
        Format('/browserProfiles/%d/executable', [Index]),
        'Executable must not be empty.');
    if Browser.ClassName = '' then
      AddDiagnostic(Result, dsError,
        Format('/browserProfiles/%d/className', [Index]),
        'Class name must not be empty.');
    if Browser.TitlePattern = '' then
      AddDiagnostic(Result, dsError,
        Format('/browserProfiles/%d/titlePattern', [Index]),
        'Title pattern must not be empty.');
    if Browser.LaunchUrl and not Browser.HasUrl then
      AddDiagnostic(Result, dsError,
        Format('/browserProfiles/%d/launchUrl', [Index]),
        'launchUrl requires a non-null url.');
  end;
  Seen := [];
  for Index := 0 to Length(Configuration.Audio.Rules) - 1 do
  begin
    Rule := Configuration.Audio.Rules[Index];
    if Rule.Id = '' then
      AddDiagnostic(Result, dsError,
        Format('/audio/rules/%d/id', [Index]), 'ID must not be empty.');
    if DuplicateId(Rule.Id, Seen) then
      AddDiagnostic(Result, dsError,
        Format('/audio/rules/%d/id', [Index]), 'Duplicate rule ID.');
    SetLength(Seen, Length(Seen) + 1);
    Seen[High(Seen)] := Rule.Id;
    if Rule.Priority < 0 then
      AddDiagnostic(Result, dsError,
        Format('/audio/rules/%d/priority', [Index]),
        'Priority must be non-negative.');
    if Rule.LevelPercent > 100 then
      AddDiagnostic(Result, dsError,
        Format('/audio/rules/%d/levelPercent', [Index]),
        'Volume must be between 0 and 100.');
    Selector := Rule.Slide;
    if (Selector.Kind in [sskSlideIndex, sskShowPosition]) and
      ((not Selector.HasValue) or (Selector.Value <= 0)) then
      AddDiagnostic(Result, dsError,
        Format('/audio/rules/%d/slide/value', [Index]),
        'Slide selector value must be positive.');
    if Rule.Foreground.Kind = fskBrowser then
    begin
      if Rule.Foreground.BrowserProfileId = '' then
        AddDiagnostic(Result, dsError,
          Format('/audio/rules/%d/foreground/profileId', [Index]),
          'Browser profile ID is required.');
      if not FindBrowser(Configuration, Rule.Foreground.BrowserProfileId) then
        AddDiagnostic(Result, dsError,
          Format('/audio/rules/%d/foreground/profileId', [Index]),
          'Browser profile does not exist.');
    end;
    for OtherIndex := 0 to Index - 1 do
    begin
      OtherRule := Configuration.Audio.Rules[OtherIndex];
      if (Rule.Priority = OtherRule.Priority) and
        SameSpecificity(Rule, OtherRule) then
        AddDiagnostic(Result, dsError,
          Format('/audio/rules/%d', [Index]),
          'Equal-priority/equal-specificity volume rule is ambiguous.');
    end;
  end;
  Seen := [];
  for Index := 0 to Length(Configuration.Sequence) - 1 do
  begin
    Entry := Configuration.Sequence[Index];
    if Entry.Id = '' then
      AddDiagnostic(Result, dsError,
        Format('/sequence/%d/id', [Index]), 'ID must not be empty.');
    if DuplicateId(Entry.Id, Seen) then
      AddDiagnostic(Result, dsError,
        Format('/sequence/%d/id', [Index]), 'Duplicate sequence ID.');
    SetLength(Seen, Length(Seen) + 1);
    Seen[High(Seen)] := Entry.Id;
    if Entry.Kind = sekPowerPoint then
    begin
      if Entry.Slide.Kind = sskUnknown then
        AddDiagnostic(Result, dsError,
          Format('/sequence/%d/slide', [Index]),
          'PowerPoint entry requires a slide selector.');
      if Entry.HasConfiguredBuild and (Entry.ConfiguredBuild < 0) then
        AddDiagnostic(Result, dsError,
          Format('/sequence/%d/build', [Index]),
          'Build must be non-negative.');
    end
    else if Entry.Kind = sekBrowser then
    begin
      if not FindBrowser(Configuration, Entry.BrowserProfileId) then
        AddDiagnostic(Result, dsError,
          Format('/sequence/%d/browserProfile', [Index]),
          'Browser profile does not exist.');
    end
    else
      AddDiagnostic(Result, dsError,
        Format('/sequence/%d/kind', [Index]), 'Entry kind is required.');
    if (Entry.NextId <> '') and not FindEntry(Configuration, Entry.NextId) then
      AddDiagnostic(Result, dsError,
        Format('/sequence/%d/next', [Index]), 'Target does not exist.');
    if (Entry.PreviousId <> '') and not FindEntry(Configuration,
      Entry.PreviousId) then
      AddDiagnostic(Result, dsError,
        Format('/sequence/%d/previous', [Index]), 'Target does not exist.');
    if (Entry.BrowserReturnId <> '') and not FindEntry(Configuration,
      Entry.BrowserReturnId) then
      AddDiagnostic(Result, dsError,
        Format('/sequence/%d/browserReturn', [Index]),
        'Target does not exist.');
    if Entry.NextId = Entry.Id then
      AddDiagnostic(Result, dsError, Format('/sequence/%d/next', [Index]),
        'Self-transitions are not allowed.');
    if Entry.PreviousId = Entry.Id then
      AddDiagnostic(Result, dsError,
        Format('/sequence/%d/previous', [Index]),
        'Self-transitions are not allowed.');
    if Entry.BrowserReturnId = Entry.Id then
      AddDiagnostic(Result, dsError,
        Format('/sequence/%d/browserReturn', [Index]),
        'Self-transitions are not allowed.');
    if (Entry.Kind = sekBrowser) and (Entry.NextId = '') then
      AddDiagnostic(Result, dsError, Format('/sequence/%d/next', [Index]),
        'Browser entry requires a next target.');
    if (Entry.Kind = sekBrowser) and (Entry.PreviousId = '') and
      (Entry.BrowserReturnId = '') then
      AddDiagnostic(Result, dsError, Format('/sequence/%d/previous', [Index]),
        'Browser entry requires previous or browserReturn.');
  end;
end;

function NewObject: TJSONObject;
begin
  Result := TJSONObject.Create;
end;

function SelectorToJson(const Selector: TSlideSelector): TJSONObject;
begin
  Result := NewObject;
  case Selector.Kind of
    sskSlideIndex:
      begin
        Result.AddPair('kind', 'slideIndex');
        Result.AddPair('value', TJSONNumber.Create(Selector.Value));
      end;
    sskShowPosition:
      begin
        Result.AddPair('kind', 'showPosition');
        Result.AddPair('value', TJSONNumber.Create(Selector.Value));
      end;
    sskEntryId:
      begin
        Result.AddPair('kind', 'entryId');
        Result.AddPair('value', Selector.EntryId);
      end;
  else
    Result.AddPair('kind', 'wildcard');
  end;
end;

function ForegroundToJson(const Selector: TForegroundSelector): TJSONObject;
var
  Kind: string;
begin
  Result := NewObject;
  case Selector.Kind of
    fskPowerPointSlideshow: Kind := 'powerPointSlideshow';
    fskPowerPointEditor: Kind := 'powerPointEditor';
    fskBrowser: Kind := 'browser';
    fskOther: Kind := 'other';
    fskUnknownApplication: Kind := 'unknown';
  else
    Kind := 'wildcard';
  end;
  Result.AddPair('kind', Kind);
  if Selector.Kind = fskBrowser then
    Result.AddPair('profileId', Selector.BrowserProfileId);
end;

function SerializeConfiguration(const Configuration: TPAConfiguration): string;
var
  Root, Audio, BrowserObject, RuleObject, EntryObject: TJSONObject;
  BrowserArray, RuleArray, SequenceArray: TJSONArray;
  Browser: TBrowserProfile;
  Rule: TAudioRuleConfiguration;
  Entry: TSequenceEntry;
begin
  Root := NewObject;
  try
    Root.AddPair('schemaVersion', TJSONNumber.Create(Configuration.SchemaVersion));
    if Configuration.Mode = amInterceptAndRoute then
      Root.AddPair('mode', 'interceptAndRoute')
    else
      Root.AddPair('mode', 'passThrough');
    Audio := NewObject;
    if Configuration.Audio.Enabled then
      Audio.AddPair('enabled', TJSONTrue.Create)
    else
      Audio.AddPair('enabled', TJSONFalse.Create);
    if Configuration.Audio.DeltaMode then
      Audio.AddPair('deltaMode', TJSONTrue.Create)
    else
      Audio.AddPair('deltaMode', TJSONFalse.Create);
    Audio.AddPair('contextMaxAgeMs',
      TJSONNumber.Create(Configuration.Audio.ContextMaxAgeMs));
    RuleArray := TJSONArray.Create;
    for Rule in Configuration.Audio.Rules do
    begin
      RuleObject := NewObject;
      RuleObject.AddPair('id', Rule.Id);
      RuleObject.AddPair('priority', TJSONNumber.Create(Rule.Priority));
      RuleObject.AddPair('slide', SelectorToJson(Rule.Slide));
      RuleObject.AddPair('foreground', ForegroundToJson(Rule.Foreground));
      RuleObject.AddPair('levelPercent',
        TJSONNumber.Create(Rule.LevelPercent));
      RuleArray.AddElement(RuleObject);
    end;
    Audio.AddPair('rules', RuleArray);
    Root.AddPair('audio', Audio);
    BrowserArray := TJSONArray.Create;
    for Browser in Configuration.BrowserProfiles do
    begin
      BrowserObject := NewObject;
      BrowserObject.AddPair('id', Browser.Id);
      BrowserObject.AddPair('executable', Browser.Executable);
      BrowserObject.AddPair('className', Browser.ClassName);
      BrowserObject.AddPair('titlePattern', Browser.TitlePattern);
      if Browser.HasUrl then
        BrowserObject.AddPair('url', Browser.Url)
      else
        BrowserObject.AddPair('url', TJSONNull.Create);
      if Browser.LaunchUrl then
        BrowserObject.AddPair('launchUrl', TJSONTrue.Create)
      else
        BrowserObject.AddPair('launchUrl', TJSONFalse.Create);
      if Browser.Activate then
        BrowserObject.AddPair('activate', TJSONTrue.Create)
      else
        BrowserObject.AddPair('activate', TJSONFalse.Create);
      if Browser.Autoplay then
        BrowserObject.AddPair('autoplay', TJSONTrue.Create)
      else
        BrowserObject.AddPair('autoplay', TJSONFalse.Create);
      BrowserArray.AddElement(BrowserObject);
    end;
    Root.AddPair('browserProfiles', BrowserArray);
    SequenceArray := TJSONArray.Create;
    for Entry in Configuration.Sequence do
    begin
      EntryObject := NewObject;
      EntryObject.AddPair('id', Entry.Id);
      if Entry.Kind = sekBrowser then
        EntryObject.AddPair('kind', 'browser')
      else
        EntryObject.AddPair('kind', 'powerPoint');
      if Entry.Kind = sekPowerPoint then
        EntryObject.AddPair('slide', SelectorToJson(Entry.Slide))
      else
        EntryObject.AddPair('browserProfile', Entry.BrowserProfileId);
      if Entry.HasConfiguredBuild then
        EntryObject.AddPair('build', TJSONNumber.Create(Entry.ConfiguredBuild))
      else
        EntryObject.AddPair('build', TJSONNull.Create);
      if Entry.NextId <> '' then EntryObject.AddPair('next', Entry.NextId);
      if Entry.PreviousId <> '' then
        EntryObject.AddPair('previous', Entry.PreviousId);
      if Entry.BrowserReturnId <> '' then
        EntryObject.AddPair('browserReturn', Entry.BrowserReturnId);
      SequenceArray.AddElement(EntryObject);
    end;
    Root.AddPair('sequence', SequenceArray);
    Result := Root.ToJSON;
  finally
    Root.Free;
  end;
end;

function TConfigurationResult.Succeeded: Boolean;
begin
  Result := Kind = crSuccess;
end;

function TConfigurationResult.HasErrors: Boolean;
begin
  Result := HasDiagnosticErrors(Diagnostics);
end;

function TConfigurationStore.ParseText(const Text: string):
  TConfigurationResult;
begin
  Result := ParseConfigurationText(Text);
end;

function TConfigurationStore.LoadFromFile(const FileName: string):
  TConfigurationResult;
var
  Text: string;
begin
  Result := Default(TConfigurationResult);
  if not TFile.Exists(FileName) then
  begin
    Result.Kind := crMissingFile;
    AddDiagnostic(Result.Diagnostics, dsError, '',
      'Configuration file does not exist.');
    Exit;
  end;
  try
    Text := TFile.ReadAllText(FileName, TEncoding.UTF8);
  except
    on E: Exception do
    begin
      Result.Kind := crFileError;
      AddDiagnostic(Result.Diagnostics, dsError, '',
        'Configuration file could not be read: ' + E.Message);
      Exit;
    end;
  end;
  Result := ParseText(Text);
end;

function TConfigurationStore.Reload(const FileName: string):
  TConfigurationResult;
begin
  Result := LoadFromFile(FileName);
  if Result.Succeeded then
  begin
    FActive := Result.Configuration;
    FHasActive := True;
  end;
end;

function TConfigurationStore.SaveToFile(const FileName: string;
  const Configuration: TPAConfiguration): TConfigurationResult;
var
  Diagnostics: TArray<TConfigurationDiagnostic>;
  TempName, Text: string;
  Stream: TStringStream;
begin
  Result := Default(TConfigurationResult);
  Diagnostics := ValidateConfiguration(Configuration);
  if HasDiagnosticErrors(Diagnostics) then
  begin
    Result.Kind := crValidationError;
    Result.Diagnostics := Diagnostics;
    Exit;
  end;
  Text := SerializeConfiguration(Configuration);
  TempName := FileName + '.tmp';
  try
    Stream := TStringStream.Create(Text, TEncoding.UTF8);
    try
      Stream.SaveToFile(TempName);
    finally
      Stream.Free;
    end;
    if not MoveFileEx(PChar(TempName), PChar(FileName),
      MOVEFILE_REPLACE_EXISTING or MOVEFILE_WRITE_THROUGH) then
      RaiseLastOSError;
    Result.Kind := crSuccess;
    Result.Configuration := Configuration;
  except
    on E: Exception do
    begin
      Result.Kind := crSaveError;
      AddDiagnostic(Result.Diagnostics, dsError, '',
        'Configuration could not be saved: ' + E.Message);
      if TFile.Exists(TempName) then
        TFile.Delete(TempName);
    end;
  end;
end;

function TConfigurationStore.Serialize(const Configuration: TPAConfiguration):
  string;
begin
  Result := SerializeConfiguration(Configuration);
end;

function TConfigurationStore.TryGetActive(out Configuration: TPAConfiguration):
  Boolean;
begin
  Result := FHasActive;
  if Result then
    Configuration := FActive;
end;

end.
