//
//  Project     : OpenBSP Map Compiler
//  Unit        : ViewerMain.pas
//  Description : OpenBSP Map Viewer main unit
//  History:
//    07/10/04 - OT - "Show Lightmap Space" option removed 
//    15/08/04 - OT - Faster rendering with "Checker Board" texture
//    25/06/04 - OT - Faster rendering
//                    Added "Wireframe" option
//                    Added "Default" texture
//                    Added free movement
//    22/06/04 - OT - Creation
//
unit ViewerMain;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, GLScene, GLMisc, Menus, GLWin32Viewer, GLObjects, GLTexture,
  VectorTypes, OpenGL1x, GLCadencer, VectorGeometry, obspFile, obspBaseTypes,
  ComCtrls, ExtCtrls, GLGraphics, GLUtils, GLState;

type
  TFormMain = class(TForm)
    MainMenu1: TMainMenu;
    MenuFile: TMenuItem;
    MenuOpen: TMenuItem;
    N1: TMenuItem;
    MenuExit: TMenuItem;
    GLScene1: TGLScene;
    GLSceneViewer1: TGLSceneViewer;
    SceneCamera: TGLCamera;
    SceneCenter: TGLDummyCube;
    OpenMapDialog: TOpenDialog;
    SceneRenderer: TGLDirectOpenGL;
    GLCadencer1: TGLCadencer;
    GLMaterialLibrary1: TGLMaterialLibrary;
    MenuOptions: TMenuItem;
    MenuWireframe: TMenuItem;
    StatusBar: TStatusBar;
    FPSUpdateTimer: TTimer;
    MenuShowBSPTreePlanes: TMenuItem;
    Lightmaps: TGLMaterialLibrary;
    procedure MenuExitClick(Sender: TObject);
    procedure MenuOpenClick(Sender: TObject);
    procedure SceneRendererRender(Sender: TObject;
      var rci: TRenderContextInfo);
    procedure GLCadencer1Progress(Sender: TObject; const deltaTime,
      newTime: Double);
    procedure GLSceneViewer1MouseDown(Sender: TObject;
      Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure GLSceneViewer1MouseMove(Sender: TObject; Shift: TShiftState;
      X, Y: Integer);
    procedure FormKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure FormKeyUp(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure FPSUpdateTimerTimer(Sender: TObject);
    procedure MenuStateChanged(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
    FNodes: array of TOBSPNode;
    FNumNodes: Cardinal;
    FLeafs: array of TOBSPLeaf;
    FNumLeafs: Cardinal;
    FPlanes: array of TOBSPPlane;
    FNumPlanes: Cardinal;
    FBrushSides: array of TOBSPBrushSide;
    FNumBrushSides: Cardinal;
    FSurfaceRefs: array of packed record
                             BrushSide: Cardinal;
                             PlaneIndex: Cardinal;
                           end;
    FSurfaces: array of TOBSPSurface;
    FNumSurfaces: Cardinal;
    FElements: array of Cardinal;
    FNumElements: Cardinal;
    FVertices: array of TOBSPVertex;
    FNumVertices: Cardinal;

    FLeafIndex,
    FOldLeafIndex: Integer;
    FRotations: TVector2f;
    FRotationDelta: TVector2f;
    FKeys: array[Word] of Boolean;
    mx, my: Integer;
    x, y: Integer;
    procedure RegisterLightmap(Index: Integer;
                               Buffer: PByteArray;
                               W, H: Integer);
    function PointInLeaf(p: TVector3f): Integer;
  end;

var
  FormMain: TFormMain;

implementation

{$R *.dfm}

uses obspMath;

procedure TFormMain.MenuExitClick(Sender: TObject);
begin
  Close;
end;

procedure TFormMain.MenuOpenClick(Sender: TObject);
var
  lightmapblocks: array of Byte;

  procedure UploadLightmaps(W, H, Size: Integer);
  var
    i: Integer;
    stride: Integer;
    counts: Integer;
  begin
    stride := W * H * 3;
    counts := Size div stride;
    for i:=0 to counts-1 do
      RegisterLightmap(i, @lightmapblocks[i * stride], W, H);
  end;

  procedure BuildSurfaceRefs;
  var
    i, j: Integer;
    idx: Cardinal;
  begin
    for i:=0 to FNumBrushSides-1 do
    for j:=0 to FBrushSides[i].NumSurfaces-1 do
    begin
      idx := FBrushSides[i].FirstSurface + Cardinal(j);
      FSurfaceRefs[idx].BrushSide := i;
      FSurfaceRefs[idx].PlaneIndex := FBrushSides[i].PlaneIndex;
    end;
  end;

var
  f: TFileStream;
  header: TOBSPHeader;
begin
  if not OpenMapDialog.Execute then Exit;

  f := TFileStream.Create(OpenMapDialog.FileName, fmOpenRead or fmShareDenyWrite);
  GLScene1.BeginUpdate;
  try
    f.Read(header, SizeOf(header));
    if (header.Identity <> OBSP_IDENTITY) then
      raise Exception.Create('Invalid map header');

    if (header.Version <> OBSP_VERSION) then
      raise Exception.Create('Invalid map version');

  // everything seems ok. Let's try to get data
    FNumNodes     := header.Lumps[LUMP_NODES].Length div SizeOf(TOBSPNode);
    FNumLeafs     := header.Lumps[LUMP_LEAFS].Length div SizeOf(TOBSPLeaf);
    FNumPlanes    := header.Lumps[LUMP_PLANES].Length div SizeOf(TOBSPPlane);
    FNumSurfaces  := header.Lumps[LUMP_SURFACES].Length div SizeOf(TOBSPSurface);
    FNumElements  := header.Lumps[LUMP_ELEMENTS].Length div SizeOf(Cardinal);
    FNumVertices  := header.Lumps[LUMP_VERTICES].Length div SizeOf(TOBSPVertex);

    SetLength(FNodes, FNumNodes);
    SetLength(FLeafs, FNumLeafs);
    SetLength(FPlanes, FNumPlanes);
    SetLength(FSurfaces, FNumSurfaces);
    SetLength(FSurfaceRefs, FNumSurfaces);
    SetLength(FElements, FNumElements);
    SetLength(FVertices, FNumVertices);
    SetLength(lightmapblocks, header.Lumps[LUMP_LIGHTMAPS].Length);

    f.Seek(header.Lumps[LUMP_NODES].Offset, soFromBeginning);
    f.Read(FNodes[0], header.Lumps[LUMP_NODES].Length);

    f.Seek(header.Lumps[LUMP_LEAFS].Offset, soFromBeginning);
    f.Read(FLeafs[0], header.Lumps[LUMP_LEAFS].Length);

    f.Seek(header.Lumps[LUMP_PLANES].Offset, soFromBeginning);
    f.Read(FPlanes[0], header.Lumps[LUMP_PLANES].Length);

    f.Seek(header.Lumps[LUMP_SURFACES].Offset, soFromBeginning);
    f.Read(FSurfaces[0], header.Lumps[LUMP_SURFACES].Length);

    f.Seek(header.Lumps[LUMP_ELEMENTS].Offset, soFromBeginning);
    f.Read(FElements[0], header.Lumps[LUMP_ELEMENTS].Length);

    f.Seek(header.Lumps[LUMP_VERTICES].Offset, soFromBeginning);
    f.Read(FVertices[0], header.Lumps[LUMP_VERTICES].Length);

    f.Seek(header.Lumps[LUMP_LIGHTMAPS].Offset, soFromBeginning);
    f.Read(lightmapblocks[0], header.Lumps[LUMP_LIGHTMAPS].Length);

    Lightmaps.Materials.Clear;
    UploadLightmaps(256, 256, header.Lumps[LUMP_LIGHTMAPS].Length);
    BuildSurfaceRefs;
  finally
    lightmapblocks := nil;
    f.Free;
    StatusBar.Panels.Items[1].Text := Format('%d Triangle(s)', [FNumElements div 3]);
    StatusBar.Panels.Items[2].Text := Format('%d Node(s)', [FNumNodes]);
    StatusBar.Panels.Items[3].Text := Format('%d Leaf(s)', [FNumLeafs]);
    SceneCamera.ResetRotations;
    SceneCamera.Position.AsVector := NullHmgVector;
    FRotations[0]:=0;
    FRotations[1]:=0;
    SceneRenderer.StructureChanged;
    GLScene1.EndUpdate;
  end;
end;

procedure TFormMain.SceneRendererRender(Sender: TObject;
  var rci: TRenderContextInfo);
var
  i: Integer;
  lastlightmap: Integer;
  material, lightmap: TGLLibMaterial;
  v: TVector3f;
  p: POBSPPlane;
begin
  if FNumSurfaces = 0 then Exit;

  glDisable(GL_LIGHTING);
//  glDisable(GL_CULL_FACE);
{
  Inc(x);
  if x = FSurfaces[0].LightmapRect[2] then
  begin
    x:=0;
    Inc(y);
    if y = FSurfaces[0].LightmapRect[3] then
      y := 0;
  end;

  v := vec_combine(FSurfaces[0].LightmapOrigin,
                   FPlanes[FSurfaceRefs[0].PlaneIndex].Tangent,
                   FSurfaces[0].LightmapScaling[0] * x);
  v := vec_combine(v,
                   FPlanes[FSurfaceRefs[0].PlaneIndex].Binormal,
                   FSurfaces[0].LightmapScaling[1] * y);

  glPointSize(10);
  glColor3f(1, 0, 0);
  glBegin(GL_POINTS);
    glVertex3fv(@v[0]);
  glEnd;     }

  if MenuShowBSPTreePlanes.Checked then
  begin
    glDisable(GL_TEXTURE_2D);

    glPointSize(5);
    glColor3f(1, 0, 0);
    for i:=0 to FNumNodes-1 do
    begin
      p := @FPlanes[FNodes[i].PlaneIndex];
      v := vec_scale(p.Normal, -p.Dist);

      glBegin(GL_POINTS);
        glVertex3fv(@v[0]);
      glEnd;

      glBegin(GL_LINES);
        glVertex3fv(@v[0]);
        v := vec_combine(v, p.Normal, 8);
        glVertex3fv(@v[0]);
      glEnd;
    end;
  end;

  if not MenuWireframe.Checked then
  begin
    glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);

    glActiveTextureARB(GL_TEXTURE0_ARB);
    glClientActiveTextureARB(GL_TEXTURE0_ARB);
    glEnableClientState(GL_TEXTURE_COORD_ARRAY);
    rci.GLStates.SetGLState(stTexture2D);
    material := GLMaterialLibrary1.Materials.GetLibMaterialByName('Default');
    rci.GLStates.SetGLCurrentTexture(0, GL_TEXTURE_2D, material.Material.Texture.Handle);

    glActiveTextureARB(GL_TEXTURE1_ARB);
    glClientActiveTextureARB(GL_TEXTURE1_ARB);
    glDisableClientState(GL_TEXTURE_COORD_ARRAY);
    rci.GLStates.UnSetGLState(stTexture2D);

    glColor3f(1, 1, 1);
  end
  else
  begin
    glPolygonMode(GL_FRONT_AND_BACK, GL_LINE);

    glActiveTextureARB(GL_TEXTURE1_ARB);
    glClientActiveTextureARB(GL_TEXTURE1_ARB);
    rci.GLStates.UnSetGLState(stTexture2D);
    glDisableClientState(GL_TEXTURE_COORD_ARRAY);

    glActiveTextureARB(GL_TEXTURE0_ARB);
    glClientActiveTextureARB(GL_TEXTURE0_ARB);
    rci.GLStates.UnSetGLState(stTexture2D);
    glDisableClientState(GL_TEXTURE_COORD_ARRAY);

    glColor3f(0, 0, 0);
  end;

  glEnableClientState(GL_VERTEX_ARRAY);
  glCullFace(GL_FRONT);

  glLockArraysEXT(0, FNumVertices);

  lastlightmap := -1;

  for i:=0 to FNumSurfaces-1 do
  begin
    glVertexPointer(3, GL_FLOAT, SizeOf(TOBSPVertex), @FVertices[FSurfaces[i].FirstVertex].Position);

    if not MenuWireframe.Checked then
    begin
      glActiveTextureARB(GL_TEXTURE0_ARB);
      glClientActiveTextureARB(GL_TEXTURE0_ARB);
      glTexCoordPointer(2, GL_FLOAT, SizeOf(TOBSPVertex), @FVertices[FSurfaces[i].FirstVertex].TexCoord);

      glActiveTextureARB(GL_TEXTURE1_ARB);
      glClientActiveTextureARB(GL_TEXTURE1_ARB);

      if (FSurfaces[i].LightmapIndex >= 0) and
         (FSurfaces[i].LightmapIndex < Lightmaps.Materials.Count) then
      begin
        rci.GLStates.SetGLState(stTexture2D);
        glEnableClientState(GL_TEXTURE_COORD_ARRAY);
        glTexCoordPointer(2, GL_FLOAT, SizeOf(TOBSPVertex), @FVertices[FSurfaces[i].FirstVertex].LM_TexCoord);
        glDisableClientState(GL_COLOR_ARRAY);
        glColor3f(1, 1, 1);

        if lastlightmap <> FSurfaces[i].LightmapIndex then
        begin
          lightmap := Lightmaps.Materials.Items[FSurfaces[i].LightmapIndex];

          rci.GLStates.SetGLCurrentTexture(1, GL_TEXTURE_2D, lightmap.Material.Texture.Handle);
          glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_MODULATE);

          lastlightmap := FSurfaces[i].LightmapIndex;
        end;
      end
      else
      begin
        rci.GLStates.UnSetGLState(stTexture2D);
        glDisableClientState(GL_TEXTURE_COORD_ARRAY);
        glEnableClientState(GL_COLOR_ARRAY);
        glColorPointer(4, GL_UNSIGNED_BYTE, SizeOf(TOBSPVertex), @FVertices[FSurfaces[i].FirstVertex].Color);
      end;
    end;

    glDrawElements(GL_TRIANGLES, FSurfaces[i].NumElements,
                   GL_UNSIGNED_INT, @FElements[FSurfaces[i].FirstElement]);
  end;

  glUnlockArraysEXT;

  glActiveTextureARB(GL_TEXTURE1_ARB);
  glClientActiveTextureARB(GL_TEXTURE1_ARB);
  rci.GLStates.UnSetGLState(stTexture2D);
  glDisableClientState(GL_TEXTURE_COORD_ARRAY);

  glActiveTextureARB(GL_TEXTURE0_ARB);
  glClientActiveTextureARB(GL_TEXTURE0_ARB);
  rci.GLStates.UnSetGLState(stTexture2D);
  glDisableClientState(GL_TEXTURE_COORD_ARRAY);

  glDisableClientState(GL_VERTEX_ARRAY);
  glDisableClientState(GL_COLOR_ARRAY);
end;

procedure TFormMain.GLCadencer1Progress(Sender: TObject; const deltaTime,
  newTime: Double);
var
  forwarddist: Single;
  strafedist: Single;
  liftdist: Single;
  p: TVector3f;
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

  if FKeys[VK_HOME] or FKeys[VK_SPACE] then
    liftdist := liftdist + 160 * deltaTime;

  if FKeys[VK_END] or FKeys[Ord('C')] then
    liftdist := liftdist - 160 * deltaTime;

  FRotations[0] := FRotations[0] + (FRotationDelta[0] * deltaTime);
  FRotations[1] := FRotations[1] + (FRotationDelta[1] * deltaTime);
  FRotationDelta[0] := 0;
  FRotationDelta[1] := 0;

  SceneCamera.Move(forwarddist);
  SceneCamera.Slide(strafedist);
  SceneCamera.Lift(liftdist);

  SceneCamera.ResetRotations;
  SceneCamera.Turn(FRotations[0]);
  SceneCamera.Pitch(FRotations[1]);

// translate position in quake coordinates
  p := vec_make(SceneCamera.Position.X,
                -SceneCamera.Position.Z,
                SceneCamera.Position.Y);

  FLeafIndex := PointInLeaf(p);
  if FLeafIndex <> FOldLeafIndex then
    StatusBar.Panels.Items[4].Text := 'Leaf '+IntToStr(FLeafIndex);

  GLSceneViewer1.ResetPerformanceMonitor;
  GLSceneViewer1.Invalidate;
end;

procedure TFormMain.GLSceneViewer1MouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  mx:=x; my:=y;
end;

procedure TFormMain.GLSceneViewer1MouseMove(Sender: TObject;
  Shift: TShiftState; X, Y: Integer);
begin
  if ssLeft in Shift then
  begin
    FRotationDelta[0] := FRotationDelta[0] - ((mx-x) * 30);
    FRotationDelta[1] := FRotationDelta[1] + ((my-y) * 30);
  end;

  mx:=x; my:=y;
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

procedure TFormMain.FPSUpdateTimerTimer(Sender: TObject);
begin
  StatusBar.Panels.Items[0].Text := GLSceneViewer1.FramesPerSecondText;
end;

procedure TFormMain.MenuStateChanged(Sender: TObject);
begin
  SceneRenderer.StructureChanged;
end;

function TFormMain.PointInLeaf(p: TVector3f): Integer;
var
  node: POBSPNode;
  idx: Integer;
begin
  if FNumNodes = 0 then
  begin
    Result := 0;
    Exit;
  end;

  idx:=0;
  while (idx >= 0) do
  begin
    // if idx < 0 we have found a leaf.
    node := @FNodes[idx];

    if (vec_dot(FPlanes[node.PlaneIndex].Normal, p) +
        FPlanes[node.PlaneIndex].Dist) >= 0.0 then
      idx := node.FrontChild
    Else
      idx := node.BackChild;
  End;

  Result := (-(idx+1));
end;

procedure TFormMain.RegisterLightmap(Index: Integer;
                                     Buffer: PByteArray;
                                     W, H: Integer);
var
  matlib: TGLLibMaterial;
  bitmap: TBitmap;
  y: Integer;
begin
  bitmap := TBitmap.Create;
  try
    bitmap.PixelFormat:=pf24bit;
    bitmap.Width:=W;
    bitmap.Height:=H;

{    BrightenRGBArray(Buffer, W * H, 2);
    GammaCorrectRGBArray(Buffer, W * H, 2.5);
}
    // convert RAW RGB to BMP
    for y:=0 to H-1 do
      BGR24ToRGB24(@Buffer^[y*W*3],
                   bitmap.ScanLine[H-1-y], W);

    matlib := Lightmaps.AddTextureMaterial(IntToStr(Index), bitmap);
    with matlib.Material.Texture do
    begin
      MinFilter:=miLinear;
      TextureWrap:=twNone;
      TextureFormat:=tfRGB;
    end;
  finally
//    bitmap.SaveToFile(Format('C:\Documents and Settings\Osman\Desktop\%d.bmp', [Index]));
    bitmap.Free;
  end;
end;

end.
