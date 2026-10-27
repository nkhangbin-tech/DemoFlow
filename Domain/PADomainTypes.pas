unit PADomainTypes;

interface

type
  TApplicationMode = (
    amUnknown,
    amPassThrough,
    amInterceptAndRoute
  );

  TServiceHealth = (
    shUnknown,
    shHealthy,
    shDegraded,
    shFaulted,
    shStopped
  );

  TForegroundKind = (
    fkUnknown,
    fkPowerPointSlideshow,
    fkPowerPointEditor,
    fkConfiguredBrowser,
    fkOther
  );

  TPowerPointConnectionState = (
    pcsUnknown,
    pcsDisconnected,
    pcsConnectedNoShow,
    pcsShowKnown,
    pcsShowUnknown,
    pcsFaulted
  );

  TBuildObservationKind = (
    bokUnavailable,
    bokVerified,
    bokAmbiguous
  );

  TEndpointAvailability = (
    eaUnknown,
    eaUnavailable,
    eaAvailable
  );

  TInputBindingKind = (
    ibkDisabled,
    ibkCaptureOnly,
    ibkWinTabMapping
  );

  TSequenceEntryKind = (
    sekUnknown,
    sekPowerPoint,
    sekBrowser
  );

  TSlideSelectorKind = (
    sskUnknown,
    sskSlideIndex,
    sskShowPosition,
    sskEntryId,
    sskWildcard
  );

  TForegroundSelectorKind = (
    fskUnknown,
    fskPowerPointSlideshow,
    fskPowerPointEditor,
    fskBrowser,
    fskOther,
    fskUnknownApplication,
    fskWildcard
  );

  TDiagnosticSeverity = (
    dsInfo,
    dsWarning,
    dsError
  );

  TObservedBuildState = record
    Kind: TBuildObservationKind;
    HasValue: Boolean;
    Value: Integer;
  end;

  TPowerPointObservation = record
    Connection: TPowerPointConnectionState;
    HasSlideIndex: Boolean;
    SlideIndex: Integer;
    HasShowPosition: Boolean;
    ShowPosition: Integer;
    Build: TObservedBuildState;
    ObservedAtTicks: Int64;
    Generation: UInt64;
    CorrelationId: UInt64;
  end;

  TAudioState = record
    Availability: TEndpointAvailability;
    EndpointGeneration: UInt64;
    HasObservedVolume: Boolean;
    ObservedVolumePercent: Byte;
    HasObservedScalar: Boolean;
    ObservedScalar: Double;
    IsMuted: Boolean;
    HasNominalVolume: Boolean;
    NominalVolumePercent: Byte;
    DeltaOffsetPercent: Integer;
    HasEffectiveTarget: Boolean;
    EffectiveTargetPercent: Byte;
    ActiveRuleId: string;
  end;

  TRuntimeWindowObservation = record
    HasWindowHandle: Boolean;
    WindowHandle: NativeUInt;
    HasProcessId: Boolean;
    ProcessId: Cardinal;
    IsVisible: Boolean;
    IsForeground: Boolean;
  end;

  TWindowProfile = record
    Id: string;
    Executable: string;
    ClassName: string;
    TitlePattern: string;
  end;

  TInputBindingState = record
    Kind: TInputBindingKind;
    Generation: UInt64;
    HasKeyboardBinding: Boolean;
    KeyboardVirtualKey: Word;
    HasMouseBinding: Boolean;
    MouseButton: Integer;
  end;

  TSlideSelector = record
    Kind: TSlideSelectorKind;
    HasValue: Boolean;
    Value: Integer;
    EntryId: string;
  end;

  TForegroundSelector = record
    Kind: TForegroundSelectorKind;
    BrowserProfileId: string;
  end;

  TVolumeRule = record
    Id: string;
    Priority: Integer;
    Slide: TSlideSelector;
    Foreground: TForegroundSelector;
    NominalVolumePercent: Byte;
  end;

  TSequenceEntry = record
    Id: string;
    Kind: TSequenceEntryKind;
    Slide: TSlideSelector;
    BrowserProfileId: string;
    HasConfiguredBuild: Boolean;
    ConfiguredBuild: Integer;
    NextId: string;
    PreviousId: string;
    BrowserReturnId: string;
  end;

  TConfigurationDiagnostic = record
    Severity: TDiagnosticSeverity;
    FieldPath: string;
    Description: string;
  end;

function ClampPercentage(const Value: Int64): Byte;
function CalculateEffectiveVolume(const NominalVolumePercent,
  DeltaOffsetPercent: Integer): Byte;

implementation

function ClampPercentage(const Value: Int64): Byte;
begin
  if Value <= 0 then
    Exit(0);
  if Value >= 100 then
    Exit(100);
  Result := Byte(Value);
end;

function CalculateEffectiveVolume(const NominalVolumePercent,
  DeltaOffsetPercent: Integer): Byte;
begin
  Result := ClampPercentage(Int64(NominalVolumePercent) +
    Int64(DeltaOffsetPercent));
end;

end.
