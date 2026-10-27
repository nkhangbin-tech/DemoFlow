program PAConfigurationTests;

{$APPTYPE CONSOLE}

uses
  System.IOUtils,
  System.SysUtils,
  PAConfiguration in '..\Config\PAConfiguration.pas',
  PADomainTypes in '..\Domain\PADomainTypes.pas';

var
  FailureCount: Integer;

procedure AssertTrue(const Name: string; Condition: Boolean);
begin
  if Condition then
    Writeln('PASS ', Name)
  else
  begin
    Writeln('FAIL ', Name);
    Inc(FailureCount);
  end;
end;

procedure AssertContains(const Name, Text, Part: string);
begin
  AssertTrue(Name, Pos(Part, Text) > 0);
end;

function MinimalJson: string;
begin
  Result :=
    '{"schemaVersion":1,"mode":"passThrough","audio":{"enabled":false,' +
    '"deltaMode":false,"contextMaxAgeMs":3000,"rules":[]},"browserProfiles":[' +
    '{"id":"browser-a","executable":"browser.exe","className":"Browser",' +
    '"titlePattern":"video","url":null,"launchUrl":false,"activate":true,' +
    '"autoplay":false}],"sequence":[{"id":"slide-1","kind":"powerPoint",' +
    '"slide":{"kind":"slideIndex","value":1},"build":null,' +
    '"next":"browser-a","previous":"slide-2"},' +
    '{"id":"slide-2","kind":"powerPoint","slide":{"kind":"slideIndex",' +
    '"value":2},"build":null,"next":"browser-a","previous":"slide-1"},' +
    '{"id":"browser-a","kind":"browser","browserProfile":"browser-a",' +
    '"next":"slide-1","previous":"slide-2","browserReturn":"slide-1"}]}';
end;

function RepresentativeJson: string;
begin
  Result :=
    '{"schemaVersion":1,"mode":"interceptAndRoute","audio":{"enabled":true,' +
    '"deltaMode":true,"contextMaxAgeMs":4500,"rules":[{"id":"r1",' +
    '"priority":10,"slide":{"kind":"slideIndex","value":1},' +
    '"foreground":{"kind":"browser","profileId":"browser-a"},' +
    '"levelPercent":35}]},"browserProfiles":[{"id":"browser-a",' +
    '"executable":"browser.exe","className":"Browser","titlePattern":"video",' +
    '"url":"https://example.test/video","launchUrl":true,"activate":true,' +
    '"autoplay":false}],"sequence":[{"id":"slide-1","kind":"powerPoint",' +
    '"slide":{"kind":"slideIndex","value":1},"build":2,"next":"browser-a",' +
    '"previous":"browser-a"},{"id":"browser-a","kind":"browser",' +
    '"browserProfile":"browser-a","next":"slide-1","previous":"slide-1",' +
    '"browserReturn":"slide-1"}]}';
end;

procedure TestValidAndRoundTrip;
var
  First, Second: TConfigurationResult;
  Store: TConfigurationStore;
  Text: string;
begin
  First := ParseConfigurationText(RepresentativeJson);
  AssertTrue('Representative configuration parses', First.Succeeded);
  AssertTrue('Representative configuration has one rule',
    Length(First.Configuration.Audio.Rules) = 1);
  Store := TConfigurationStore.Create;
  try
    Text := Store.Serialize(First.Configuration);
    Second := Store.ParseText(Text);
    AssertTrue('Serialized configuration parses', Second.Succeeded);
    AssertTrue('Round trip preserves mode',
      Second.Configuration.Mode = First.Configuration.Mode);
    AssertTrue('Round trip preserves browser URL',
      Second.Configuration.BrowserProfiles[0].Url =
      First.Configuration.BrowserProfiles[0].Url);
    AssertTrue('Round trip preserves build',
      Second.Configuration.Sequence[0].ConfiguredBuild = 2);
    AssertTrue('Round trip preserves browser return',
      Second.Configuration.Sequence[1].BrowserReturnId = 'slide-1');
  finally
    Store.Free;
  end;
end;

procedure TestInvalidInputs;
var
  ResultValue: TConfigurationResult;
begin
  ResultValue := ParseConfigurationText('{');
  AssertTrue('Malformed JSON rejected', ResultValue.Kind = crMalformedJson);
  ResultValue := ParseConfigurationText('{}');
  AssertTrue('Missing schema version rejected', ResultValue.HasErrors);
  AssertContains('Missing schema path', ResultValue.Diagnostics[0].FieldPath,
    '/schemaVersion');
  ResultValue := ParseConfigurationText(
    StringReplace(MinimalJson, '"schemaVersion":1', '"schemaVersion":2',
      [rfReplaceAll]));
  AssertTrue('Unsupported version rejected',
    ResultValue.Kind = crUnsupportedVersion);
  ResultValue := ParseConfigurationText(
    StringReplace(MinimalJson, '"mode":"passThrough"',
      '"unknown":true,"mode":"passThrough"', [rfReplaceAll]));
  AssertTrue('Unknown root property rejected', ResultValue.HasErrors);
  ResultValue := ParseConfigurationText(
    StringReplace(RepresentativeJson, '"levelPercent":35', '"levelPercent":101',
      [rfReplaceAll]));
  AssertTrue('Invalid volume rejected', ResultValue.HasErrors);
  ResultValue := ParseConfigurationText(
    StringReplace(RepresentativeJson, '"browserProfile":"browser-a"',
      '"browserProfile":"missing"', [rfReplaceAll]));
  AssertTrue('Missing browser profile rejected', ResultValue.HasErrors);
  ResultValue := ParseConfigurationText(
    StringReplace(RepresentativeJson, '"browserReturn":"slide-1"',
      '"browserReturn":"missing"', [rfReplaceAll]));
  AssertTrue('Missing navigation target rejected', ResultValue.HasErrors);
  ResultValue := ParseConfigurationText(
    StringReplace(RepresentativeJson, '"autoplay":false',
      '"unsupported":true,"autoplay":false', [rfReplaceAll]));
  AssertTrue('Unknown nested property rejected', ResultValue.HasErrors);
  ResultValue := ParseConfigurationText(
    StringReplace(RepresentativeJson, '"priority":10', '"priority":1.5',
      [rfReplaceAll]));
  AssertTrue('Fractional integer rejected', ResultValue.HasErrors);
  ResultValue := ParseConfigurationText(
    StringReplace(RepresentativeJson, '"id":"browser-a","kind":"browser"',
      '"id":"slide-1","kind":"browser"', [rfReplaceAll]));
  AssertTrue('Duplicate sequence ID rejected', ResultValue.HasErrors);
  ResultValue := ParseConfigurationText(
    StringReplace(RepresentativeJson, '"previous":"browser-a"',
      '"previous":"slide-1"', [rfReplaceAll]));
  AssertTrue('Forbidden sequence self-transition rejected',
    ResultValue.HasErrors);
  ResultValue := ParseConfigurationText(
    StringReplace(RepresentativeJson, '"build":2', '"build":-1',
      [rfReplaceAll]));
  AssertTrue('Negative build rejected', ResultValue.HasErrors);
  ResultValue := ParseConfigurationText(
    StringReplace(RepresentativeJson,
      '"url":"https://example.test/video","launchUrl":true',
      '"url":null,"launchUrl":true', [rfReplaceAll]));
  AssertTrue('URL launch without URL rejected', ResultValue.HasErrors);
end;

procedure TestReloadAndSave;
var
  Store: TConfigurationStore;
  GoodFile, BadFile, SavedFile: string;
  ResultValue: TConfigurationResult;
  Active: TPAConfiguration;
  GoodText: string;
begin
  GoodFile := TPath.Combine(TPath.GetTempPath, 'pa-config-good.json');
  BadFile := TPath.Combine(TPath.GetTempPath, 'pa-config-bad.json');
  SavedFile := TPath.Combine(TPath.GetTempPath, 'pa-config-saved.json');
  if TFile.Exists(GoodFile) then TFile.Delete(GoodFile);
  if TFile.Exists(BadFile) then TFile.Delete(BadFile);
  if TFile.Exists(SavedFile) then TFile.Delete(SavedFile);
  Store := TConfigurationStore.Create;
  try
    GoodText := MinimalJson;
    TFile.WriteAllText(GoodFile, GoodText, TEncoding.UTF8);
    ResultValue := Store.Reload(GoodFile);
    AssertTrue('Valid file reloads', ResultValue.Succeeded);
    TFile.WriteAllText(BadFile, '{', TEncoding.UTF8);
    ResultValue := Store.Reload(BadFile);
    AssertTrue('Malformed reload fails', not ResultValue.Succeeded);
    AssertTrue('Failed reload preserves active configuration',
      Store.TryGetActive(Active) and (Active.Sequence[0].Id = 'slide-1'));
    ResultValue := Store.LoadFromFile(
      TPath.Combine(TPath.GetTempPath, 'pa-missing.json'));
    AssertTrue('Missing first-run file is reported',
      ResultValue.Kind = crMissingFile);
    ResultValue := Store.SaveToFile(SavedFile, Active);
    AssertTrue('Validated configuration saves', ResultValue.Succeeded);
    ResultValue := Store.LoadFromFile(SavedFile);
    AssertTrue('Saved configuration reloads', ResultValue.Succeeded);
  finally
    if TFile.Exists(GoodFile) then TFile.Delete(GoodFile);
    if TFile.Exists(BadFile) then TFile.Delete(BadFile);
    if TFile.Exists(SavedFile) then TFile.Delete(SavedFile);
    if TFile.Exists(SavedFile + '.tmp') then
      TFile.Delete(SavedFile + '.tmp');
    Store.Free;
  end;
end;

begin
  FailureCount := 0;
  TestValidAndRoundTrip;
  TestInvalidInputs;
  TestReloadAndSave;
  if FailureCount = 0 then
    Writeln('All configuration tests passed.')
  else
  begin
    Writeln(FailureCount, ' test(s) failed.');
    ExitCode := 1;
  end;
end.
