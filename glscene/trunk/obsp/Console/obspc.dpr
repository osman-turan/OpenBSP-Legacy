//
//  Project     : OpenBSP Map Compiler
//  Unit        : obspc.dpr
//  Description : Console project
//  History     :
//    18/06/04 - OT - Creation
//
program obspc;

{$APPTYPE CONSOLE}

uses
  RecyclerMM in '..\Base\RecyclerMM.pas',
  ConMain in 'ConMain.pas',
  obspBaseCompiler in '..\Base\obspBaseCompiler.pas',
  obspBaseTypes in '..\Base\obspBaseTypes.pas',
  obspBSP in '..\Base\obspBSP.pas',
  obspCompiler in '..\Base\obspCompiler.pas',
  obspFile in '..\Base\obspFile.pas',
  obspMapClasses in '..\Base\obspMapClasses.pas',
  obspMapParser in '..\Base\obspMapParser.pas',
  obspMath in '..\Base\obspMath.pas',
  obspParser in '..\Base\obspParser.pas',
  obspUtils in '..\Base\obspUtils.pas',
  obspVersion in '..\Base\obspVersion.pas',
  obspLighting in '..\Base\obspLighting.pas',
  obspPolygon in '..\Base\obspPolygon.pas',
  obspMultiThreading in '..\Base\obspMultiThreading.pas',
  obspTexture in '..\Base\obspTexture.pas',
  obspMaterial in '..\Base\obspMaterial.pas',
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

//------------------------------------------------------------------------------

var Comp: TConsoleCompiler;
begin
  Comp := TConsoleCompiler.Create;
  Comp.Run;
  Comp.Free;
end.
