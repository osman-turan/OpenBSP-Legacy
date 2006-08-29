//
//  Project     : OpenBSP Map Compiler
//  Unit        : obspMaterial.pas
//  Description : Material (shader) utilities
//  History     :
//    11/11/04 - OT - Added Doom3 material script "table" keyword support
//                    Added Doom3 material script "bumpmap" keyword support (basic syntax)
//                    Added some keyword priority
//    01/11/04 - OT - Some texture loading optimization added
//                    Added TMaterial.DiffuseMapFile and NormalMapFile 
//                    TMaterial.Diffuse replaced with TMaterial.DiffuseMap
//                    TMaterial.Normalmap replaced with TMaterial.NormalMap
//                    
//    29/10/04 - OT - Fixed material parsing
//    11/10/04 - OT - Added surface parameters support
//    12/09/04 - OT - Creation
//
unit obspMaterial;

interface

uses SysUtils, obspBaseTypes, obspParser, obspTexture, obspMath;

type
  TCompileFlag = (cfNonSolid, cfTranslucent, cfNoDraw, cfNoLightmap);
  TCompileFlags = set of TCompileFlag;

// material records (shaders)
  PMaterial = ^TMaterial;
  TMaterial = packed record
    MaterialName: String;
    RefCount: Integer;       // points how many usages in active .map file (0=not used)

    CompileFlags: TCompileFlags;

    Subdivisions: Single;
    LightmapSampleSize: Single;
    SaturateLighting: Boolean;
    GlobalTexture: Boolean;
    AvarageColor: TVector4f;

    DiffuseMapFile: String;
    NormalMapFile: String;
    DiffuseMap: TTexture;
    NormalMap: TTexture;
  end;

  TMaterialManager = class
  private
    FTexturePath: String;
    FLoadedTextureCount: Integer;
    FMaterials: array of TMaterial;
    FMaterialCount: Integer;
    function GetMaterial(Index: Integer): PMaterial;
    procedure SetTexturePath(const Value: String);
  protected
    function CreateDefaultMaterial(const MaterialName: String): PMaterial;
    procedure FinishMaterial(Material: PMaterial);
    procedure LoadTexture(Filename: String; Texture: PTexture);
    function ParseMaterial(Parser: TTextParser): Boolean;
    procedure ParseMaterialFile(Filename: String);
  public
    constructor Create;
    destructor Destroy; override;

    procedure Clear;

    function AddMaterial(Filename: String): Integer;
    procedure AddMaterialPath(Path: String);
    function GetMaterialIndex(Material: String): Integer;

    property Materials[Index: Integer]: PMaterial read GetMaterial;
    property MaterialCount: Integer read FMaterialCount;
    property TexturePath: String read FTexturePath write SetTexturePath;
    property LoadedTextureCount: Integer read FLoadedTextureCount;
  end;

implementation

uses obspUtils, obspMapClasses;

{ TMaterialManager }

function TMaterialManager.AddMaterial(Filename: String): Integer;
var
  material: PMaterial;
  i: Integer;
begin
  Filename := ConvertUnixPathToDosPath(Filename);

  if LowerCase(Copy(Filename, 1, 9)) <> 'textures\' then
    Filename := 'textures\' + Filename;

  for i:=0 to FMaterialCount-1 do
  begin
    material := @FMaterials[i];

    if SameText(material.MaterialName, Filename) then
    begin
      if (material.RefCount = 0) and (not (cfNoDraw in material.CompileFlags)) then
      begin
        LoadTexture(material.DiffuseMapFile, @material.DiffuseMap);
        LoadTexture(material.NormalMapFile, @material.NormalMap);
        FinishMaterial(material);
      end;

      Inc(material.RefCount);
      Result := i;
      Exit;
    end;
  end;

  material := CreateDefaultMaterial(Filename);
  material.RefCount := 1; // mark as used in map

  LoadTexture(material.DiffuseMapFile, @material.DiffuseMap);
  FinishMaterial(material);

  Result := FMaterialCount - 1;
end;

procedure TMaterialManager.AddMaterialPath(Path: String);
var
  SearchRec: TSearchRec;
  matPath: String;
  ext: String;
begin
  matPath := IncludeTrailingPathDelimiter(Path);
  if FindFirst(matPath + '*.*', 0, SearchRec) = 0 then
  repeat
    ext := LowerCase(ExtractFileExt(SearchRec.Name));

  // read Quake3 shaders (.shader)
  // or Doom3 materials (.mtr)
    if (ext = '.mtr') or (ext = '.shader') then
      ParseMaterialFile(matPath + SearchRec.Name);
  until FindNext(SearchRec) <> 0;

  FindClose(SearchRec);
end;

procedure TMaterialManager.Clear;
var i: Integer;
begin
  for i:=0 to FMaterialCount-1 do
  begin
    if Assigned(FMaterials[i].DiffuseMap.Pixels) then
      FreeMem(FMaterials[i].DiffuseMap.Pixels);

    if Assigned(FMaterials[i].NormalMap.Pixels) then
      FreeMem(FMaterials[i].NormalMap.Pixels);
  end;

  FMaterials := nil;
  FMaterialCount := 0;
  FLoadedTextureCount := 0;
end;

constructor TMaterialManager.Create;
begin
  FTexturePath := '';
  Clear;
end;

function TMaterialManager.CreateDefaultMaterial(const MaterialName: String): PMaterial;
var material: PMaterial;
begin
  Inc(FMaterialCount);
  SetLength(FMaterials, FMaterialCount);
  material := @FMaterials[FMaterialCount-1];
  FillChar(material^, SizeOf(TMaterial), 0);
  material^.MaterialName := MaterialName;
  material^.RefCount := 0;
  material^.DiffuseMapFile := MaterialName;
  material^.Subdivisions := MAX_WORLD_COORD;
  material^.LightmapSampleSize := 0;        // Mark as invalid. So, it can be overwritten
  material^.GlobalTexture := False;
  material^.SaturateLighting := False;

  Result := material;
end;

destructor TMaterialManager.Destroy;
begin
  Clear;
  inherited;
end;

procedure TMaterialManager.FinishMaterial(Material: PMaterial);
const COLOR_FACTOR = 1 / 255;
var
  i: Integer;
  f: Extended;
  avgColor: TVector4x;
begin
  if (Material.DiffuseMap.Width > 0) and
     (Material.DiffuseMap.Height > 0) and
     Assigned(Material.DiffuseMap.Pixels) then
  begin
    avgColor[0] := 0;
    avgColor[1] := 0;
    avgColor[2] := 0;
    avgColor[3] := 0;

    for i:=0 to (Material.DiffuseMap.Width * Material.DiffuseMap.Height) - 1 do
    begin
      avgColor[0] := avgColor[0] + (Material.DiffuseMap.Pixels[i][0] * COLOR_FACTOR);
      avgColor[1] := avgColor[1] + (Material.DiffuseMap.Pixels[i][1] * COLOR_FACTOR);
      avgColor[2] := avgColor[2] + (Material.DiffuseMap.Pixels[i][2] * COLOR_FACTOR);
      avgColor[3] := avgColor[3] + (Material.DiffuseMap.Pixels[i][3] * COLOR_FACTOR);
    end;

    f := 1 / (Material.DiffuseMap.Width * Material.DiffuseMap.Height);

    Material.AvarageColor[0] := avgColor[0] * f;
    Material.AvarageColor[1] := avgColor[1] * f;
    Material.AvarageColor[2] := avgColor[2] * f;
    Material.AvarageColor[3] := avgColor[3] * f;
  end;
end;

function TMaterialManager.GetMaterial(Index: Integer): PMaterial;
begin
  Result := @FMaterials[Index];
end;

function TMaterialManager.GetMaterialIndex(Material: String): Integer;
var i: Integer;
begin
  Result := -1;
  Material := ConvertUnixPathToDosPath(Material);

  for i:=0 to FMaterialCount-1 do
    if SameText(Material, FMaterials[i].MaterialName) then
    begin
      Result := i;
      Exit;
    end;
end;

procedure TMaterialManager.LoadTexture(Filename: String;
  Texture: PTexture);
var 
  ext: String;
  success: Boolean;
begin
  ext := ExtractFileExt(Filename);
  Texture.Width := 0;
  Texture.Height := 0;
  Texture.Pixels := nil;

// try .tga first
  if FileExists(FTexturePath + Filename + '.tga') then
    success := LoadTGATexture(FTexturePath + Filename + '.tga', Texture)
  else if (ext = '.tga') and FileExists(FTexturePath + Filename) then
    success := LoadTGATexture(FTexturePath + Filename, Texture)
// then .jpg file
  else if FileExists(FTexturePath + Filename + '.jpg') then
    success := LoadJPEGTexture(FTexturePath + Filename + '.jpg', Texture)
  else if (ext = '.jpg') and FileExists(FTexturePath + Filename) then
    success := LoadJPEGTexture(FTexturePath + Filename, Texture)
  else
    success := False;

  if success then
    Inc(FLoadedTextureCount);
end;

function TMaterialManager.ParseMaterial(Parser: TTextParser): Boolean;
var
  material: PMaterial;
  matname, token: String;
  nolayers: Boolean;
  f: Extended;
begin
  Result := False;
  if not Parser.GetNextToken then Exit;

// assign material name
  matname := ConvertUnixPathToDosPath(Parser.Token);

// is this a Doom3 script table?
// Example: 
// table testTable { clamp snap { 0, 0.5, 1 } }

  if LowerCase(matname) = 'table' then
  begin
    while Parser.GetNextToken do
    begin
      if Parser.Token = '}' then
      begin
        if not Parser.GetNextToken then
          Break;

        if Parser.Token = '}' then
          Break;
      end;
    end;

    Result := True; // continue parsing
    Exit;
  end;

  if not Parser.GetNextToken then
    Exit;

  if Parser.Token <> '{' then
    Exit;

// check for duplicates
  if GetMaterialIndex(matname) >= 0 then
  begin
  // skip this material
    while True do
    begin
      if not Parser.GetNextToken then
        Break;

      if Parser.Token = '}' then
        Break;

    // skip layers
      if Parser.Token = '{' then
      while True do
      begin
        if not Parser.GetNextToken then
          Break;

        if Parser.Token = '}' then
          Break;
      end;
    end;    

    Result := True; // continue parsing
    Exit;
  end;

// Everything seems OK. Let's create a new one
  material := CreateDefaultMaterial(matname);

  nolayers := True;

  while True do
  begin
    if not Parser.GetNextToken then
      Break;

    if Parser.Token = '}' then
      Break;

  // skip layers
    if Parser.Token = '{' then
    begin
      nolayers := False;

      while True do
      begin
        if not Parser.GetNextToken then
          Break;

        if Parser.Token = '}' then
          Break;
      end;

      Continue;
    end;

    token := LowerCase(Parser.Token);

  // Surface tesselation
    if (token = 'tesssize') or (token = 'q3map_tesssize') then
    begin
      if not Parser.GetNextToken then
        Break;

      if TryStrToFloatGeneric(Parser.Token, f) then
        material.Subdivisions := f;
    end
  // Lightmap sampling size
    else if (token = 'q3map_lightmapsamplesize') or (token = 'obsp_lightmapsamplesize') then
    begin
      if not Parser.GetNextToken then
        Break;

      if TryStrToFloatGeneric(Parser.Token, f) then
        material.LightmapSampleSize := Clamp(f, MIN_LIGHTING_SAMPLE_SIZE, MAX_LIGHTING_SAMPLE_SIZE);
    end
  // Diffuse image (diffusemap overrides qer_editorimage)
    else if (token = 'qer_editorimage') then
    begin
      if not Parser.GetNextToken then
        Break;

      if material.DiffuseMapFile = '' then
        material.DiffuseMapFile := Parser.Token;
    end
    else if (token = 'diffusemap') then
    begin
      if not Parser.GetNextToken then
        Break;

      material.DiffuseMapFile := Parser.Token;
      nolayers := False;
    end
  // Normalmap image (obsp_normalmap/q3map_normalimage overrides bumpmap, because can be less details)
    else if (token = 'q3map_normalimage') or
            (token = 'q3map_normalmap') or
            (token = 'obsp_normalmap') then
    begin
      if not Parser.GetNextToken then
        Break;

      material.NormalMapFile := Parser.Token;
    end
    else if (token = 'bumpmap') then
    begin
      if not Parser.GetNextToken then
        Break;

      if material.NormalMapFile = '' then
        material.NormalMapFile := Parser.Token;
      nolayers := False;
    end
  // Enables saturate lighting
    else if (token = 'obsp_saturatelighting') then
      material.SaturateLighting := True
  // Global Texture (don't bias texture coordinates as close to 0 as possible)
    else if (token = 'q3map_globaltexture') or (token = 'obsp_globaltexture') then
      material.GlobalTexture := True
  // Doom3 style surface parameters (compile flags)
    else if (token = 'nonsolid') then
      Include(material.CompileFlags, cfNonSolid)
    else if (token = 'translucent') then
      Include(material.CompileFlags, cfTranslucent)
    else if (token = 'nodraw') then
      Include(material.CompileFlags, cfNoDraw)
    else if (token = 'nolightmap') then
      Include(material.CompileFlags, cfNoLightmap)
  // Quake3 style surface parameters (compile flags)
    else if (token = 'surfaceparm') then
    begin
      if not Parser.GetNextToken then
        Break;

      token := LowerCase(Parser.Token);
      if (token = 'nonsolid') then
        Include(material.CompileFlags, cfNonSolid)
      else if (token = 'trans') then
        Include(material.CompileFlags, cfTranslucent)
      else if (token = 'nodraw') then
        Include(material.CompileFlags, cfNoDraw)
      else if (token = 'nolightmap') then
        Include(material.CompileFlags, cfNoLightmap);
    end
    else
      Parser.SkipLine;
  end;

// No layers also means nodraw
  if nolayers then
    Include(material.CompileFlags, cfNoDraw);

  Result := True;
end;

procedure TMaterialManager.ParseMaterialFile(Filename: String);
var parser: TTextParser;
begin
  if not FileExists(Filename) then Exit;

  parser := TTextParser.Create;
  try
    parser.LoadFromFile(Filename);

    while ParseMaterial(parser) do ;
  finally
    parser.Free;
  end;
end;

procedure TMaterialManager.SetTexturePath(const Value: String);
begin
  FTexturePath := Value;
end;

end.
