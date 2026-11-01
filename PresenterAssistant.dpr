program PresenterAssistant;

uses
  Vcl.Forms,
  uMainForm in 'uMainForm.pas' {MainForm},
  PAConfiguration in 'Config\PAConfiguration.pas',
  PADomainTypes in 'Domain\PADomainTypes.pas',
  PALogger in 'Infrastructure\PALogger.pas',
  PAPowerPointMonitor in 'PowerPoint\PAPowerPointMonitor.pas',
  uDemoCardForm in 'uDemoCardForm.pas' {DemoCardForm},
  uWelcomeForm in 'uWelcomeForm.pas' {WelcomeForm},
  uSceneEditorForm in 'uSceneEditorForm.pas' {frmSceneEditor};

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TMainForm, MainForm);
  //Application.CreateForm(TDemoCardForm, DemoCardForm);
  Application.CreateForm(TWelcomeForm, WelcomeForm);
  Application.Run;
end.
