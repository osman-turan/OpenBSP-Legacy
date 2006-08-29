program OBSPViewer;

uses
  Forms,
  ViewerMain in 'ViewerMain.pas' {FormMain},
  obspBaseTypes in '..\Base\obspBaseTypes.pas',
  obspFile in '..\Base\obspFile.pas',
  obspMath in '..\Base\obspMath.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TFormMain, FormMain);
  Application.Run;
end.
