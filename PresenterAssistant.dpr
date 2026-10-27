program PresenterAssistant;

uses
  Vcl.Forms,
  uMainForm in 'uMainForm.pas' {MainForm},
  PAConfiguration in 'Config\PAConfiguration.pas',
  PADomainTypes in 'Domain\PADomainTypes.pas',
  PALogger in 'Infrastructure\PALogger.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
