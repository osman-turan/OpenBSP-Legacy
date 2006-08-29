//
//  Project     : OpenBSP Map Compiler
//  Unit        : obspMD3Mesh.pas
//  Description : Quake3 mesh model (MD3) loader for 
//                importing triangle meshes into map
//  History     :
//    20/12/04 - OT - Creation
//
unit obspMD3Mesh;

interface

uses Classes, SysUtils, obspBaseTypes, obspParser, obspMath, obspUtils;

const
  MD3_IDENTITY  = 'IDP3';               // file header identity
  MD3_VERSION   = 15;                   // file header version

  MD3_XYZ_SCALE = 1.0 / 64;             // vertex scales

type
  PMD3Frame = ^TMD3Frame;
  TMD3Frame = packed record
    Bounds: TAABB;
    LocalOrigin: TVector3f;
    Radius: Single;
    Name: array[0..15] of Char;
  end;

  PMD3Surface = ^TMD3Surface;
  TMD3Surface = packed record
    Identity: array[0..3] of Char;
    Name: array[0..63] of Char;         // polyset name
    Flags: Integer;
    numFrames: Integer;                 // all surfaces in a model should have the same
    numShaders: Integer;                // all surfaces in a model should have the same
    numVerts: Integer;
    numTriangles: Integer;
    ofsTriangles: Integer;
    ofsShaders: Integer;                // offset from start of TMD3Surface
    ofsST: Integer;                     // texture coords are common for all frames
    ofsXYZNormals: Integer;             // numVerts * numFrames
    ofsEnd: Integer;                    // next surface follows
  end;

  PMD3Shader = ^TMD3Shader;
  TMD3Shader = packed record
    Name: array[0..63] of Char;
    ShaderIndex: Integer;               // for in-game use
  end;

  PMD3Triangle = ^TMD3Triangle;
  TMD3Triangle = packed record
    Indexes: array[0..2] of Integer;    // clock-wise order indicies
  end;

  PMD3ST = ^TMD3ST;
  TMD3ST = packed record
    ST: array[0..1] of Single;
  end;

  PMD3XYZNormal = ^TMD3XYZNormal;
  TMD3XYZNormal = packed record
    XYZ: array[0..2] of SmallInt;
    Normal: SmallInt;
  end;

  TMD3FileHeader = packed record
    Identity: array[0..3] of Char;
    Version: Integer;
    Name: array[0..63] of Char;         // model name
    Flags: Integer;
    numFrames: Integer;
    numTags: Integer;
    numSurfaces: Integer;
    numSkins: Integer;
    ofsFrames: Integer;                 // offset for first frame
    ofsTags: Integer;                   // numFrames * numTags
    ofsSurfaces: Integer;               // first surface, others follow
    ofsEnd: Integer;                    // end of file
  end;

  TMD3Model = class;

  TMD3Mesh = class
  private
    FOwner: TMD3Model;
    FShaders: array of TMD3Shader;
    FTriangles: array of TMD3Triangle;
    FVertices: array of TMD3XYZNormal;  // Size = FVertexCount * Owner.FrameCount
    FTexCoords: array of TMD3ST;
    FShaderCount: Integer;
    FTriangleCount: Integer;
    FVertexCount: Integer;
  public
    constructor Create(AOwner: TMD3Model);
    destructor Destroy; override;

    procedure Clear;

    procedure SetShaderCount(Count: Integer);
    procedure SetTriangleCount(Count: Integer);
    procedure SetVertexCount(Count: Integer);

    function GetShadersAsAddress: Pointer;
    function GetTrianglesAsAddress: Pointer;
    function GetVerticesAsAddress: Pointer;
    function GetTexCoordsAsAddress: Pointer;

    function GetShader(Index: Integer): PMD3Shader;
    function GetTriangle(Index: Integer): PMD3Triangle;
    function GetVertex(Frame: Integer; Index: Integer): PMD3XYZNormal;
    function GetTexCoord(Index: Integer): PMD3ST;

    property ShaderCount: Integer read FShaderCount;
    property TriangleCount: Integer read FTriangleCount;
    property VertexCount: Integer read FVertexCount;
    property Owner: TMD3Model read FOwner;
  end;

  TMD3Model = class
  private
    FFrameCount: Integer;
    FMeshes: TList;

    function GetMeshCount: Integer;
  public
    constructor Create;
    destructor Destroy; override;

    function LoadFromStream(Stream: TStream): Boolean;
    function LoadFromFile(Filename: String): Boolean;
    procedure Clear;

    function AddMesh(Mesh: TMD3Mesh): Integer;

    function GetMesh(Index: Integer): TMD3Mesh;

    property MeshCount: Integer read GetMeshCount;
    property FrameCount: Integer read FFrameCount;
  end;

implementation

{ TMD3Mesh }

procedure TMD3Mesh.Clear;
begin
  FShaders := nil;
  FTriangles := nil;
  FVertices := nil;
  FTexCoords := nil;

  FShaderCount := 0;
  FTriangleCount := 0;
  FVertexCount := 0;
end;

constructor TMD3Mesh.Create(AOwner: TMD3Model);
begin
  FOwner := AOwner;
  Clear;
end;

destructor TMD3Mesh.Destroy;
begin
  Clear;

  inherited;
end;

function TMD3Mesh.GetShader(Index: Integer): PMD3Shader;
begin
  Result := @FShaders[Index];
end;

function TMD3Mesh.GetShadersAsAddress: Pointer;
begin
  Result := FShaders;
end;

function TMD3Mesh.GetTriangle(Index: Integer): PMD3Triangle;
begin
  Result := @FTriangles[Index];
end;

function TMD3Mesh.GetTrianglesAsAddress: Pointer;
begin
  Result := FTriangles;
end;

function TMD3Mesh.GetVertex(Frame: Integer; Index: Integer): PMD3XYZNormal;
begin
  Result := @FVertices[FVertexCount * Frame + Index];
end;

function TMD3Mesh.GetVerticesAsAddress: Pointer;
begin
  Result := FVertices;
end;

function TMD3Mesh.GetTexCoord(Index: Integer): PMD3ST;
begin
  Result := @FTexCoords[Index];
end;

function TMD3Mesh.GetTexCoordsAsAddress: Pointer;
begin
  Result := FTexCoords;
end;

procedure TMD3Mesh.SetShaderCount(Count: Integer);
begin
  FShaderCount := Count;
  SetLength(FShaders, FShaderCount);
end;

procedure TMD3Mesh.SetTriangleCount(Count: Integer);
begin
  FTriangleCount := Count;
  SetLength(FTriangles, FTriangleCount);
end;

procedure TMD3Mesh.SetVertexCount(Count: Integer);
begin
  FVertexCount := Count;
  SetLength(FVertices, FVertexCount * Owner.FrameCount);
  SetLength(FTexCoords, FVertexCount);
end;

{ TMD3Model }

function TMD3Model.AddMesh(Mesh: TMD3Mesh): Integer;
begin
  Result := FMeshes.Add(Mesh);
end;

procedure TMD3Model.Clear;
var mesh: TMD3Mesh;
begin
  while FMeshes.Count > 0 do
  begin
    mesh := TMD3Mesh(FMeshes.Items[0]);
    mesh.Free;
    FMeshes.Delete(0);
  end;
end;

constructor TMD3Model.Create;
begin
  FMeshes := TList.Create;
  Clear;
end;

destructor TMD3Model.Destroy;
begin
  Clear;
  FMeshes.Free;
  inherited;
end;

function TMD3Model.GetMesh(Index: Integer): TMD3Mesh;
begin
  Result := TMD3Mesh(FMeshes.Items[Index]);
end;

function TMD3Model.GetMeshCount: Integer;
begin
  Result := FMeshes.Count;
end;

function TMD3Model.LoadFromFile(Filename: String): Boolean;
var f: TFileStream;
begin
  Result := False;

  f := TFileStream.Create(Filename, fmOpenRead or fmShareDenyWrite);
  try
    if LoadFromStream(f) then
      Result := True;
  finally
    f.Free;
  end;
end;

function TMD3Model.LoadFromStream(Stream: TStream): Boolean;
var
  i, offset: Integer;
  header: TMD3FileHeader;
  surf: TMD3Surface;
  mesh: TMD3Mesh;
begin
  Result := False;

  Clear;

  try
  // read file header
    FillChar(header, SizeOf(TMD3FileHeader), 0);
    Stream.Read(header, SizeOf(TMD3FileHeader));

    if (header.Identity <> MD3_IDENTITY) or
       (header.Version <> MD3_VERSION) then
      Exit;

    FFrameCount := header.numFrames;

  // skip frames (we don't need bounding boxes or the other info)

  // skip tags (we don't link any model in the compiler)

  // read all surfaces (meshes)
    offset := header.ofsSurfaces;

    for i:=0 to header.numSurfaces-1 do
    begin
      mesh := TMD3Mesh.Create(Self);
      AddMesh(mesh);

      Stream.Seek(offset, soFromBeginning);
      Stream.Read(surf, SizeOf(TMD3Surface));

      mesh.SetShaderCount(surf.numShaders);
      mesh.SetTriangleCount(surf.numTriangles);
      mesh.SetVertexCount(surf.numVerts);

    // read shaders (skins)
      Stream.Seek(offset + surf.ofsShaders, soFromBeginning);
      Stream.Read(mesh.GetShadersAsAddress^, SizeOf(TMD3Shader) * mesh.ShaderCount);

    // read triangles
      Stream.Seek(offset + surf.ofsTriangles, soFromBeginning);
      Stream.Read(mesh.GetTrianglesAsAddress^, SizeOf(TMD3Triangle) * mesh.TriangleCount);

    // read texture coordinates
      Stream.Seek(offset + surf.ofsST, soFromBeginning);
      Stream.Read(mesh.GetTexCoordsAsAddress^, SizeOf(TMD3ST) * mesh.VertexCount);

    // read morph vertices
      Stream.Seek(offset + surf.ofsXYZNormals, soFromBeginning);
      Stream.Read(mesh.GetVerticesAsAddress^, SizeOf(TMD3XYZNormal) * mesh.VertexCount * FFrameCount);

    // increase the offset
      offset := offset + surf.ofsEnd;
    end;

    Result := True;
  except
    Clear;
  end;
end;

end.
