//
//  Project     : OpenBSP Map Compiler
//  Unit        : obspMapParser.pas
//  Description : Map file parser
//  History     :
//    30/12/04 - OT - Fixed texture mapping
//    26/10/04 - OT - Fixed Classic Quake texture mapping
//                    Fixed Brush Primitives texture mapping
//                    Added GetClassicQuakeTextureMatrix
//                    Added GetBrushPrimitivesTextureMatrix
//    23/10/04 - OT - Added support for Classic Quake map format
//    14/08/04 - OT - Added basic support for Doom3 maps
//    17/06/04 - OT - Creation
//
unit obspMapParser;

interface

uses SysUtils, obspBaseTypes, obspBaseCompiler, obspMapClasses, obspParser,
Classes;

type
  TMapFormat = (mfNone, mfClassicQuake, mfBrushPrimitives, mfDoom3);

  TMapParser = class(TBaseCompiler)
  private
    FMapFormat: TMapFormat;
    FCurrentEntity: TEntity;
    FCurrentBrush: TBrush;
    FPatchCount,
    FBrushCount: Cardinal;
    FParser: TTextParser;
    function GetBrushPrimitivesTextureMatrix(Normal: TVector3f; 
                                             BaseMatrix: TMatrix4f): TMatrix4f;
    function GetClassicQuakeTextureMatrix(Normal: TVector3f; Shift: TVector2f; 
                                          Rotate: Single; Scale: TVector2f): TMatrix4f;
    procedure ParseMatchedToken(const Token: String);
    procedure ParseNextToken;
    procedure ParseFloatArray(var FloatArray: array of Single;
                              const Count: Integer);
    procedure ParseBrush;
    procedure ParseBrushDef;
    procedure ParseBrushDef3;
    procedure ParsePatchDef2;
    procedure ParsePatchDef3;
    function ParseEntity: Boolean;
  public
    constructor Create(const AManager: TBaseCompilerManager;
                       const AOwner: TBaseCompilerObject); override;
    destructor Destroy; override;

    procedure ParseMapFile(const Filename: String);
  end;

implementation

uses obspUtils, obspMath, obspSurfPatch;

{ TMapParser }

constructor TMapParser.Create(const AManager: TBaseCompilerManager;
                              const AOwner: TBaseCompilerObject);
begin
  inherited;
  FParser := TTextParser.Create;
end;

destructor TMapParser.Destroy;
begin
  FParser.Free;
  inherited;
end;

function TMapParser.GetBrushPrimitivesTextureMatrix(Normal: TVector3f; BaseMatrix: TMatrix4f): TMatrix4f;
var 
  RotY, RotZ: Single;
  sy, cy, sz, cz: Single;
  tangent, binormal: TVector3f;
begin
  // do some cleaning
  if (Abs(Normal[0]) < 1E-6) then
    Normal[0] := 0;
  if (Abs(Normal[1]) < 1E-6) then
    Normal[1] := 0;
  if (Abs(Normal[2]) < 1E-6) then
    Normal[2] := 0;

  // compute the two rotations around Y and Z to rotate X to normal
  RotY := -ArcTan2(Normal[2], Sqrt(Normal[1] * Normal[1] + Normal[0] * Normal[0]));
  RotZ := ArcTan2(normal[1], normal[0]);

  // do some precomputing
  SinCos(RotY, sy, cy);
  SinCos(RotZ, sz, cz);

  // rotate (0,1,0) and (0,0,1) to compute texS and texT
  tangent[0] := -sz;
  tangent[1] := cz;
  tangent[2] := 0;

  // the texY vector is along -Z ( T texture coorinates axis )
  binormal[0] := -sy * cz;
  binormal[1] := -sy * sz;
  binormal[2] := -cy;

// build texture matrix
  Result[0, 0] := BaseMatrix[0, 0] * Tangent[0] + BaseMatrix[1, 0] * Binormal[0];
  Result[0, 1] := BaseMatrix[0, 1] * Tangent[0] + BaseMatrix[1, 1] * Binormal[0];
  Result[0, 2] := Normal[0];
  Result[0, 3] := 0;

  Result[1, 0] := BaseMatrix[0, 0] * Tangent[1] + BaseMatrix[1, 0] * Binormal[1];
  Result[1, 1] := BaseMatrix[0, 1] * Tangent[1] + BaseMatrix[1, 1] * Binormal[1];
  Result[1, 2] := Normal[1];
  Result[1, 3] := 0;

  Result[2, 0] := BaseMatrix[0, 0] * Tangent[2] + BaseMatrix[1, 0] * Binormal[2];
  Result[2, 1] := BaseMatrix[0, 1] * Tangent[2] + BaseMatrix[1, 1] * Binormal[2];
  Result[2, 2] := Normal[2];
  Result[2, 3] := 0;

  Result[3, 0] := BaseMatrix[3, 0];
  Result[3, 1] := BaseMatrix[3, 1];
  Result[3, 2] := BaseMatrix[3, 2];
  Result[3, 3] := 1;
end;

function TMapParser.GetClassicQuakeTextureMatrix(Normal: TVector3f; Shift: TVector2f; 
                                                 Rotate: Single; Scale: TVector2f): TMatrix4f;
const
  BASE_AXIS: array[0..17] of TVector3f = (
   (0,0,1), (1,0,0), (0,-1,0),  // floor
   (0,0,-1), (1,0,0), (0,-1,0), // ceiling
   (1,0,0), (0,1,0), (0,0,-1),  // west wall
   (-1,0,0), (0,1,0), (0,0,-1), // east wall
   (0,1,0), (1,0,0), (0,0,-1),  // south wall
   (0,-1,0), (1,0,0), (0,0,-1)  // north wall
  );

var 
  bestdot: Single;
  bestindex, sv, tv, i: Integer;
  bestaxis: TVector3f;
  texVec: array[0..1] of TVector3f;
  sine, cosine, f1, f2, dot: Single;
begin
// find nearest axis
  bestdot := 0;
  bestindex := 0;
	
  for i:=0 to 5 do
  begin
    dot := vec_dot(Normal, BASE_AXIS[i*3]);
    if (dot > (bestdot + 0.0001)) then
    begin
      bestdot := dot;
      bestindex := i;
    end;
  end;

  bestaxis := BASE_AXIS[bestindex*3];
  texVec[0] := BASE_AXIS[bestindex*3+1];
  texVec[1] := BASE_AXIS[bestindex*3+2];

// rotate mapping
  if (Rotate = 0) then
  begin
    sine := 0;
    cosine := 1;
  end
  else if (Rotate = 90) then
  begin
    sine := 1;
    cosine := 0;
  end
  else if (Rotate = 180) then
  begin
    sine := 0;
    cosine := -1;
  end
  else if (Rotate = 270) then
  begin
    sine := -1;
    cosine := 0;
  end
  else
    SinCos(DegToRad(Rotate), sine, cosine);

// find non-zero elements
  if (texVec[0,0] <> 0) then
    sv := 0
  else if (texVec[0,1] <> 0) then
    sv := 1
  else
    sv := 2;

  if (texVec[1,0] <> 0) then
    tv := 0
  else if (texVec[1,1] <> 0) then
    tv := 1
  else
    tv := 2;

// apply rotation to axial mapping vectors up vector (still axial)
  for i:=0 to 1 do
  begin
    f1 := cosine * texVec[i, sv] - sine * texVec[i, tv];
    f2 := sine * texVec[i, sv] + cosine * texVec[i, tv];
    texVec[i, sv] := f1;
    texVec[i, tv] := f2;
  end;

// HACK: By normally we must divide the scaling with texture dimensions
// In QuArK there is a constant (=128) for this operation. So, it seems OK.
  texVec[0] := vec_scale(texVec[0], 1 / (Scale[0] * 128));
  texVec[1] := vec_scale(texVec[1], 1 / (Scale[1] * 128));

// create texture matrix from mapping vectors
  Result[0,0] := texVec[0, 0];
  Result[0,1] := texVec[1, 0];
  Result[0,2] := Normal[0];
  Result[0,3] := 0;

  Result[1,0] := texVec[0, 1];
  Result[1,1] := texVec[1, 1];
  Result[1,2] := Normal[1];
  Result[1,3] := 0;

  Result[2,0] := texVec[0, 2];
  Result[2,1] := texVec[1, 2];
  Result[2,2] := Normal[2];
  Result[2,3] := 0;

  Result[3,0] := Shift[0];
  Result[3,1] := Shift[1];
  Result[3,2] := 0;
  Result[3,3] := 1;
end;

procedure TMapParser.ParseBrush;
var
  i: Integer;
  plane: TPlane;
  planepoints: array[0..2] of TVector3f;
  matdef: array[0..4] of Single;
  texmatrix: TMatrix4f;
  texture: String;
begin
// check map integrity
  if FMapFormat <> mfClassicQuake then
  begin
    if FMapFormat = mfNone then
      FMapFormat := mfClassicQuake
    else
      Error('Mixed map format');
  end;

  FCurrentBrush := FCurrentEntity.AddBrush;
  Inc(FBrushCount);

  while True do
  begin
    ParseNextToken;
    if FParser.Token = '}' then Break;
    FParser.UnGetToken;
  // read three point of plane
    for i:=0 to 2 do
    begin
      ParseMatchedToken('(');

      ParseFloatArray(planepoints[i], 3);

      ParseMatchedToken(')');
    end;

  // create plane and snap it
    plane := plane_frompoints(planepoints[0], planepoints[1], planepoints[2]);
    i := World.AddPlane(plane);
    plane := World.Planes[i];

    ParseNextToken;
    texture := FParser.Token;

    ParseFloatArray(matdef, 5);

  // create texture matrix
    texmatrix := GetClassicQuakeTextureMatrix(plane.Normal,            // plane
                                              PVector2f(@matdef[0])^,  // shift 
                                              PSingle(@matdef[2])^,    // rotate
                                              PVector2f(@matdef[3])^); // scale
  // add brush side
    FCurrentBrush.AddSide(plane,
                          texture,
                          texmatrix);

    FParser.SkipLine;
  end;
end;

procedure TMapParser.ParseBrushDef;
var
  i: Integer;
  plane: TPlane;
  planepoints: array[0..2] of TVector3f;
  matdef: array[0..1, 0..2] of Single;
  texmatrix: TMatrix4f;
begin
// check map integrity
  if FMapFormat <> mfBrushPrimitives then
  begin
    if FMapFormat = mfNone then
      FMapFormat := mfBrushPrimitives
    else
      Error('Mixed map format');
  end;

  ParseMatchedToken('{');

  FCurrentBrush := FCurrentEntity.AddBrush;
  Inc(FBrushCount);

  while True do
  begin
    ParseNextToken;
    if FParser.Token = '}' then Break;
    FParser.UnGetToken;
  // read three point of plane
    for i:=0 to 2 do
    begin
      ParseMatchedToken('(');

      ParseFloatArray(planepoints[i], 3);

      ParseMatchedToken(')');
    end;

    ParseMatchedToken('(');

    for i:=0 to 1 do
    begin
      ParseMatchedToken('(');

      ParseFloatArray(matdef[i], 3);

      ParseMatchedToken(')');
    end;

    ParseMatchedToken(')');

    ParseNextToken;

  // create texture matrix
    mat_identity(texmatrix);

    texmatrix[0, 0] := matdef[0, 0];
    texmatrix[0, 1] := matdef[1, 0];

    texmatrix[1, 0] := matdef[0, 1];
    texmatrix[1, 1] := matdef[1, 1];

    texmatrix[3, 0] := matdef[0, 2];
    texmatrix[3, 1] := matdef[1, 2];

    plane := plane_frompoints(planepoints[0], planepoints[1], planepoints[2]);
    i := World.AddPlane(plane);
    plane := World.Planes[i];

    texmatrix := GetBrushPrimitivesTextureMatrix(plane.Normal, texmatrix);

  // add brush side
    FCurrentBrush.AddSide(plane,
                          FParser.Token,
                          texmatrix);

    FParser.SkipLine;
  end;

  ParseMatchedToken('}');
end;

procedure TMapParser.ParseBrushDef3;
var
  i: Integer;
  planedef: array[0..3] of Single;
  plane: TPlane;
  matdef: array[0..1, 0..2] of Single;
  texmatrix: TMatrix4f;
begin
// check map integrity
  if FMapFormat <> mfDoom3 then
    Error('Mixed map format');

  ParseMatchedToken('{');

  FCurrentBrush := FCurrentEntity.AddBrush;
  Inc(FBrushCount);

  while True do
  begin
    ParseNextToken;
    if FParser.Token = '}' then Break;
    FParser.UnGetToken;
  // read plane defination
    ParseMatchedToken('(');

    ParseFloatArray(planedef, 4);
    plane.Normal[0] := planedef[0];
    plane.Normal[1] := planedef[1];
    plane.Normal[2] := planedef[2];
    plane.Dist      := planedef[3];
    i := World.AddPlane(plane);
    plane := World.Planes[i];

    ParseMatchedToken(')');

    ParseMatchedToken('(');

    for i:=0 to 1 do
    begin
      ParseMatchedToken('(');

      ParseFloatArray(matdef[i], 3);

      ParseMatchedToken(')');
    end;

    ParseMatchedToken(')');

    ParseNextToken;

  // create texture matrix
    mat_identity(texmatrix);

    texmatrix[0, 0] := matdef[0, 0];
    texmatrix[0, 1] := matdef[1, 0];

    texmatrix[1, 0] := matdef[0, 1];
    texmatrix[1, 1] := matdef[1, 1];

    texmatrix[3, 0] := matdef[0, 2];
    texmatrix[3, 1] := matdef[1, 2];

    texmatrix := GetBrushPrimitivesTextureMatrix(plane.Normal, texmatrix);

  // add brush side
    FCurrentBrush.AddSide(plane,
                          FParser.Token,
                          texmatrix);

    FParser.SkipLine;
  end;

  ParseMatchedToken('}');
end;

function TMapParser.ParseEntity: Boolean;
var s: String;
begin
  Result := False;
  if not FParser.GetNextToken then Exit;

// analyze map format
  if SameText(FParser.Token, 'Version') then
  begin
    if FMapFormat <> mfNone then
      Error('Mixed map format');

    FMapFormat := mfDoom3;
    ParseNextToken;

    if FParser.Token <> '2' then
      Error('Unrecognized Doom3 map file version');

    ParseMatchedToken('{');
  end
  else if FParser.Token <> '{' then
    Error('Unrecognized map file format');

  FCurrentEntity := World.AddEntity;

  while True do
  begin
    ParseNextToken;

    if FParser.Token = '}' then Break;

    if FParser.Token = '{' then // brush or patch
    begin
      ParseNextToken;

      if SameText(FParser.Token, 'brushDef') then
        ParseBrushDef
      else if SameText(FParser.Token, 'brushDef3') then
        ParseBrushDef3
      else if SameText(FParser.Token, 'patchDef2') then
        ParsePatchDef2
      else if SameText(FParser.Token, 'patchDef3') then
        ParsePatchDef3
      else
      begin
        FParser.UnGetToken; // give a last chance for it
        ParseBrush;
      end;

      Result := True;
    end
    else
    begin                       // entity keys
      s := FParser.Token;
      ParseNextToken;

      if not Assigned(FCurrentEntity) then
        Error('CurrentEntity is invalid');

      FCurrentEntity.AddKey(s, FParser.Token);
      Result := True;
    end;

    Progress(Trunc(100 * (FParser.Position / FParser.Size)));    
  end;
end;

procedure TMapParser.ParseFloatArray(var FloatArray: array of Single;
  const Count: Integer);
var
  i: Integer;
  t: Extended;
begin
  for i:=0 to Count-1 do
  begin
    ParseNextToken;

    if TryStrToFloatGeneric(FParser.Token, t) then
      FloatArray[i] := t
    else
      Error('%s is not a floating-point value', [FParser.Token]);
  end;
end;

procedure TMapParser.ParseMapFile(const Filename: String);
var
  i: Integer;
  totalbrushes, validbrushes: Integer;
begin
  StartWork('Parsing map file...');
  FBrushCount := 0;
  FPatchCount := 0;
  FMapFormat := mfNone;

  FParser.LoadFromFile(Filename);

  while ParseEntity do ;

  EndWork;
  
  case FMapFormat of
    mfClassicQuake:    PrintMessage('Map Format: Classic Quake');
    mfBrushPrimitives: PrintMessage('Map Format: Brush Primitives');
    mfDoom3:           PrintMessage('Map Format: Doom3 Primitives');
  else
    Error('Unrecognized map file format');
  end;

  PrintMessage('%5d entities', [World.EntityCount]);
  PrintMessage('%5d brushes', [FBrushCount]);
  PrintMessage('%5d patches', [FPatchCount]);
  PrintMessage('%5d textures loaded', [World.MaterialManager.LoadedTextureCount]);

  StartWork('Building base polygons...');

  totalbrushes := 0;
  validbrushes := 0;

  for i:=0 to World.EntityCount-1 do
  begin
    totalbrushes := totalbrushes + World.Entities[i].BrushCount;
    World.Entities[i].BuildBasePolygons;
    validbrushes := validbrushes + World.Entities[i].BrushCount;

    Progress(Trunc(100 * (i+1) / World.EntityCount));
  end;
  EndWork;

  PrintMessage('%5d invalid brushes culled', [totalbrushes-validbrushes]);
end;

procedure TMapParser.ParseNextToken;
begin
  if not FParser.GetNextToken then
    Error('Unexpected end of file');
end;

procedure TMapParser.ParsePatchDef2;
var
  material: String;
  patch: TPatchSurface;
  x, y, patch_w, patch_h: Integer;
  floatarray: array[0..4] of Single;
begin
(*

 {
  patchDef2
  {
   base_wall/basewall03
   ( 3 9 0 0 0 )
(
( ( 1984 192 -256 0 0 ) ( 2048 192 -256 0 0.12500 ) ( 2048 256 -224 0 0.25000 ) ( 2048 320 -192 0 0.31250 ) ( 1984 320 -192 0 0.37500 ) ( 1920 320 -192 0 0.43750 ) ( 1920 256 -224 0 0.50000 ) ( 1920 192 -256 0 0.75000 ) ( 1984 192 -256 0 1 ) )
( ( 1984 192 -320 0.50000 0 ) ( 2048 192 -320 0.50000 0.12500 ) ( 2048 256 -320 0.50000 0.25000 ) ( 2048 320 -320 0.50000 0.31250 ) ( 1984 320 -320 0.50000 0.37500 ) ( 1920 320 -320 0.50000 0.43750 ) ( 1920 256 -320 0.50000 0.50000 ) ( 1920 192 -320 0.50000 0.75000 ) ( 1984 192 -320 0.50000 1 ) )
( ( 1984 192 -496 1 0 ) ( 2048 192 -496 1 0.12500 ) ( 2048 256 -496 1 0.25000 ) ( 2048 320 -496 1 0.31250 ) ( 1984 320 -496 1 0.37500 ) ( 1920 320 -496 1 0.43750 ) ( 1920 256 -496 1 0.50000 ) ( 1920 192 -496 1 0.75000 ) ( 1984 192 -496 1 1 ) )
)
  }
 }

*)

  ParseMatchedToken('{');

// parse material
  ParseNextToken;
  material := FParser.Token;

// parse patch dimensions
  ParseMatchedToken('(');
  ParseFloatArray(floatarray, 5);
  ParseMatchedToken(')');

  patch_h := Trunc(floatarray[0]);
  patch_w := Trunc(floatarray[1]);

// invalid patch? if yes, skip it!
  if (patch_w <= 0) or (patch_h <= 0) then
  begin
    while FParser.GetNextToken do
      if FParser.Token = '}' then Break;
  end
  else
  begin // valid patch
    patch := TPatchSurface.Create(FCurrentEntity, material);
    patch.PatchWidth := patch_w;
    patch.PatchHeight := patch_h;

    ParseMatchedToken('(');

    for y:=0 to patch_h-1 do
    begin
      ParseMatchedToken('(');

      for x:=0 to patch_w-1 do
      begin
      // parse control point
        ParseMatchedToken('(');
        ParseFloatArray(floatarray, 5);
        ParseMatchedToken(')');

        patch.AddControlPoint(PVector3f(@floatarray[0])^, PVector2f(@floatarray[3])^);
      end;

      ParseMatchedToken(')');
    end;

    ParseMatchedToken(')');
    ParseMatchedToken('}');

    Inc(FPatchCount);
  end;

  ParseMatchedToken('}');
end;

procedure TMapParser.ParsePatchDef3;
var
  material: String;
  patch: TPatchSurface;
  x, y, patch_w, patch_h: Integer;
  floatarray: array[0..6] of Single;
begin
(*

{
 patchDef3
 {
  "textures/caves/metalswatch1"
  ( 3 3 1 1 0 0 0 )
  (
   (  ( -268 1680 1288 0 0 ) ( -266 1681 1288 0 0.03125 ) ( -265 1680 1288 0 0.0625 ) )
   (  ( -269 1679 1288 0.03125 0 ) ( -266 1679 1288 0.03125 0.03125 ) ( -263 1679 1288 0.03125 0.0625 ) )
   (  ( -268 1677 1288 0.0625 0 ) ( -266 1676 1288 0.0625 0.03125 ) ( -265 1677 1288 0.0625 0.0625 ) )
  )
 }
}

*)

  ParseMatchedToken('{');

// parse material
  ParseNextToken;
  material := FParser.Token;

// parse patch dimensions
  ParseMatchedToken('(');
  ParseFloatArray(floatarray, 7);
  ParseMatchedToken(')');

  patch_h := Trunc(floatarray[0]);
  patch_w := Trunc(floatarray[1]);

// invalid patch? if yes, skip it!
  if (patch_w <= 0) or (patch_h <= 0) then
  begin
    while FParser.GetNextToken do
      if FParser.Token = '}' then Break;
  end
  else
  begin // valid patch
    patch := TPatchSurface.Create(FCurrentEntity, material);
    patch.PatchWidth := patch_w;
    patch.PatchHeight := patch_h;

    ParseMatchedToken('(');

    for y:=0 to patch_h-1 do
    begin
      ParseMatchedToken('(');

      for x:=0 to patch_w-1 do
      begin
      // parse control point
        ParseMatchedToken('(');
        ParseFloatArray(floatarray, 5);
        ParseMatchedToken(')');

        patch.AddControlPoint(PVector3f(@floatarray[0])^, PVector2f(@floatarray[3])^);
      end;

      ParseMatchedToken(')');
    end;

    ParseMatchedToken(')');
    ParseMatchedToken('}');

    Inc(FPatchCount);
  end;

  ParseMatchedToken('}');
end;

procedure TMapParser.ParseMatchedToken(const Token: String);
begin
  ParseNextToken;

  if not SameText(FParser.Token, Token) then
    Error('"%s" was not found, found "%s" (line: %d)', [Token, FParser.Token, FParser.Line]);
end;

end.
