{
  Acropolis

    Creation SkinHat
    Modifications by Osman Turan

  !!!IMPORTANT NOTE!!!
    +Z is up instead of +Y in OpenBSP file for compability the other
  BSP files.
}
unit Main;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, GLScene, GLObjects, GLMisc, GLWin32Viewer, GLCadencer, GLTexture,
  JPEG, OpenGL1x, obspBaseTypes, obspFile, GLSkyBox, GLVectorFileObjects;

type
  TFormMain = class(TForm)
    GLSceneEngine: TGLScene;
    GLSceneRenderer: TGLSceneViewer;
    SceneCamera: TGLCamera;
    GLCadencer1: TGLCadencer;
    MapMaterials: TGLMaterialLibrary;
    sky_base: TGLPlane;
    GenericMaterials: TGLMaterialLibrary;
    sky_add: TGLPlane;
    GLSkyBox1: TGLSkyBox;
    MapRenderer: TGLFreeForm;
    Lightmaps: TGLMaterialLibrary;
    procedure GLCadencer1Progress(Sender: TObject; const deltaTime,
      newTime: Double);
    procedure FormCreate(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure FormKeyUp(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure GLSceneRendererMouseDown(Sender: TObject;
      Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure GLSceneRendererMouseMove(Sender: TObject; Shift: TShiftState;
      X, Y: Integer);
    procedure sky_baseProgress(Sender: TObject; const deltaTime,
      newTime: Double);
    procedure sky_addProgress(Sender: TObject; const deltaTime,
      newTime: Double);
  private
    { Private declarations }
  public
    { Public declarations }
    FRotations: TVector2f;
    FRotationDelta: TVector2f;
    FKeys: array[Word] of Boolean;
    mx, my: Integer;
  end;

var
  FormMain: TFormMain;

implementation

uses GLFileOBSP;

{$R *.dfm}

{ TFormMain }

procedure TFormMain.GLCadencer1Progress(Sender: TObject; const deltaTime,
  newTime: Double);
var
  forwarddist: Single;
  strafedist: Single;
  liftdist: Single;
begin
  forwarddist := 0;
  strafedist := 0;
  liftdist := 0;

  if FKeys[Ord('W')] or FKeys[VK_UP] then
    forwarddist := forwarddist + 320 * deltaTime;

  if FKeys[Ord('S')] or FKeys[VK_DOWN] then
    forwarddist := forwarddist - 320 * deltaTime;

  if FKeys[Ord('A')] then
    strafedist := strafedist - 160 * deltaTime;

  if FKeys[Ord('D')] then
    strafedist := strafedist + 160 * deltaTime;

  if FKeys[VK_LEFT] then
    FRotationDelta[0] := FRotationDelta[0] - 60;

  if FKeys[VK_RIGHT] then
    FRotationDelta[0] := FRotationDelta[0] + 60;

  if FKeys[VK_HOME] then
    liftdist := liftdist + 160 * deltaTime;

  if FKeys[VK_END] then
    liftdist := liftdist - 160 * deltaTime;

  FRotations[0] := FRotations[0] + (FRotationDelta[0] * deltaTime);
  FRotations[1] := FRotations[1] + (FRotationDelta[1] * deltaTime);
  FRotationDelta[0] := 0;
  FRotationDelta[1] := 0;

  SceneCamera.Move(forwarddist);
  SceneCamera.Slide(strafedist);
  SceneCamera.Lift(liftdist);

  SceneCamera.ResetRotations;
// roll instead of turn because +Z is up
  SceneCamera.Roll(FRotations[0]);
  SceneCamera.Pitch(FRotations[1]);

  GLSceneRenderer.ResetPerformanceMonitor;
  GLSceneRenderer.Invalidate;
end;

procedure TFormMain.FormCreate(Sender: TObject);
begin
  SetCurrentDir(ExtractFilePath(Application.ExeName) + '..\..\Media\');

  MapRenderer.LoadFromFile('maps\acropolis4.obsp');

  GenericMaterials.Materials.GetLibMaterialByName('textures/clouds').Material.Texture.Image.LoadFromFile('textures\clouds.jpg');

  SceneCamera.Position.SetPoint(900, 2800, 750);
  FRotations[1] := -100;
end;

procedure TFormMain.FormKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  FKeys[Key] := True;
end;

procedure TFormMain.FormKeyUp(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  FKeys[Key] := False;
end;

procedure TFormMain.GLSceneRendererMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  mx:=x; my:=y;
end;

procedure TFormMain.GLSceneRendererMouseMove(Sender: TObject;
  Shift: TShiftState; X, Y: Integer);
begin
  if ssLeft in Shift then
  begin
    FRotationDelta[0] := FRotationDelta[0] - ((mx-x) * 30);
    FRotationDelta[1] := FRotationDelta[1] + ((my-y) * 30);
  end;

  mx:=x; my:=y;
end;

procedure TFormMain.sky_baseProgress(Sender: TObject; const deltaTime,
  newTime: Double);
begin
  sky_base.XOffset := sky_base.XOffset + deltaTime * 0.09;
  sky_base.YOffset := sky_base.YOffset + deltaTime * 0.06;
end;

procedure TFormMain.sky_addProgress(Sender: TObject; const deltaTime,
  newTime: Double);
begin
  sky_add.XOffset := sky_add.XOffset + deltaTime * 0.0025;
  sky_add.YOffset := sky_add.YOffset + deltaTime * 0.0035;
end;

end.
