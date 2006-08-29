program Acropolis;

uses
  Forms,
  Main in 'Main.pas' {FormMain},
  obspBaseTypes in '..\..\Base\obspBaseTypes.pas',
  obspFile in '..\..\Base\obspFile.pas',
  GLFileOBSP in '..\..\Patches\GLScene\GLFileOBSP.pas',
  obspMapLoader in '..\..\Patches\obspMapLoader.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TFormMain, FormMain);
  Application.Run;
end.
