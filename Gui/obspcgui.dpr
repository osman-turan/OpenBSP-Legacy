program obspcgui;

uses
  RecyclerMM in '..\Base\RecyclerMM.pas',
  Forms,
  GuiMain in 'GuiMain.pas' {FormMain},
  obspParser in '..\Base\obspParser.pas',
  obspCompiler in '..\Base\obspCompiler.pas',
  obspBSP in '..\Base\obspBSP.pas',
  obspBaseCompiler in '..\Base\obspBaseCompiler.pas',
  obspFile in '..\Base\obspFile.pas',
  obspMapParser in '..\Base\obspMapParser.pas',
  obspMapClasses in '..\Base\obspMapClasses.pas',
  obspBaseTypes in '..\Base\obspBaseTypes.pas',
  obspVersion in '..\Base\obspVersion.pas',
  obspUtils in '..\Base\obspUtils.pas',
  obspMath in '..\Base\obspMath.pas',
  obspLighting in '..\Base\obspLighting.pas',
  obspPolygon in '..\Base\obspPolygon.pas',
  obspMultiThreading in '..\Base\obspMultiThreading.pas',
  obspMaterial in '..\Base\obspMaterial.pas',
  obspTexture in '..\Base\obspTexture.pas',
  obspTGA in '..\Base\obspTGA.pas',
  obspSurfPatch in '..\Base\obspSurfPatch.pas',
  obspSurfPlanar in '..\Base\obspSurfPlanar.pas',
  obspSurfTriMesh in '..\Base\obspSurfTriMesh.pas',
  obspMD3Mesh in '..\Base\obspMD3Mesh.pas',
  File3DS in '..\Base\File3DS.pas',
  Utils3DS in '..\Base\Utils3DS.pas',
  Types3DS in '..\Base\Types3DS.pas',
  Const3DS in '..\Base\Const3DS.pas',
  obspMD5Mesh in '..\Base\obspMD5Mesh.pas',
  obspMesh in '..\Base\obspMesh.pas',
  obspTrace in '..\Base\obspTrace.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.Title := 'OpenBSP Map Compiler';
  Application.CreateForm(TFormMain, FormMain);
  Application.Run;
end.
