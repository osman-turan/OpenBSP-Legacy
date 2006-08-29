//
//  Project     : OpenBSP Map Compiler
//  Unit        : obspMapLoader.pas
//  Description : Generic OpenBSP map loader for developers
//  History     :
//    05/08/04 - OT - Creation
//

unit obspMapLoaderLaz;

interface

uses SysUtils, Classes, obspFile, obspBaseTypes;

type
  TOBSPMap = class
  private
    FMaterials: TStringList;
    FPlanes: array of TOBSPPlane;
    FNodes: array of TOBSPNode;
    FLeafs: array of TOBSPLeaf;
    FLBrushes: array of Cardinal;
    FLSurfaces: array of Cardinal;
    FBrushes: array of TOBSPBrush;
    FBrushSides: array of TOBSPBrushSide;
    FSurfaces: array of TOBSPSurface;
    FElements: array of Cardinal;
    FVertices: array of TOBSPVertex;
    FLightmaps: array of Byte;
    FLightmapHeight: Integer;
    FLightmapWidth: Integer;
    FLightmapCount: Integer;

    function GetMaterial(Index: Integer): String;
    function GetMaterialCount: Integer;
    function GetNode(Index: Integer): TOBSPNode;
    function GetNodeCount: Integer;
    function GetPlane(Index: Integer): TOBSPPlane;
    function GetPlaneCount: Integer;
    function GetLeaf(Index: Integer): TOBSPLeaf;
    function GetLeafCount: Integer;
    function GetLeafBrush(Index: Integer): Integer;
    function GetLeafBrushCount: Integer;
    function GetLeafSurface(Index: Integer): Integer;
    function GetLeafSurfaceCount: Integer;
    function GetBrush(Index: Integer): TOBSPBrush;
    function GetBrushCount: Integer;
    function GetBrushSide(Index: Integer): TOBSPBrushSide;
    function GetBrushSideCount: Integer;
    function GetSurface(Index: Integer): TOBSPSurface;
    function GetSurfaceCount: Integer;
    function GetElement(Index: Integer): Integer;
    function GetElementCount: Integer;
    function GetVertex(Index: Integer): TOBSPVertex;
    function GetVertexCount: Integer;
    function GetLightmap(Index: Integer): PVector3bArray;
  protected
    procedure LoadEntities(Stream: TStream;
                           OffsetStart: Cardinal;
                           Header: TOBSPHeader);
    procedure LoadMaterials(Stream: TStream;
                            OffsetStart: Cardinal;
                            Header: TOBSPHeader);
    procedure LoadPlanes(Stream: TStream;
                         OffsetStart: Cardinal;
                         Header: TOBSPHeader);
    procedure LoadNodes(Stream: TStream;
                        OffsetStart: Cardinal;
                        Header: TOBSPHeader);
    procedure LoadLeafs(Stream: TStream;
                        OffsetStart: Cardinal;
                        Header: TOBSPHeader);
    procedure LoadLeafBrushes(Stream: TStream;
                              OffsetStart: Cardinal;
                              Header: TOBSPHeader);
    procedure LoadLeafSurfaces(Stream: TStream;
                               OffsetStart: Cardinal;
                               Header: TOBSPHeader);
    procedure LoadBrushes(Stream: TStream;
                          OffsetStart: Cardinal;
                          Header: TOBSPHeader);
    procedure LoadBrushSides(Stream: TStream;
                             OffsetStart: Cardinal;
                             Header: TOBSPHeader);
    procedure LoadSurfaces(Stream: TStream;
                           OffsetStart: Cardinal;
                           Header: TOBSPHeader);
    procedure LoadElements(Stream: TStream;
                           OffsetStart: Cardinal;
                           Header: TOBSPHeader);
    procedure LoadVertices(Stream: TStream;
                           OffsetStart: Cardinal;
                           Header: TOBSPHeader);
    procedure LoadLightmaps(Stream: TStream;
                           OffsetStart: Cardinal;
                           Header: TOBSPHeader);
  public
    constructor Create;
    destructor Destroy; override;

    function LoadFromFile(Filename: String): Boolean;
    function LoadFromStream(Stream: TStream): Boolean;
    procedure ClearMap;

    property Materials[Index: Integer]: String read GetMaterial;
    property MaterialCount: Integer read GetMaterialCount;
    
    property Planes[Index: Integer]: TOBSPPlane read GetPlane;
    property PlaneCount: Integer read GetPlaneCount;

    property Nodes[Index: Integer]: TOBSPNode read GetNode;
    property NodeCount: Integer read GetNodeCount;

    property Leafs[Index: Integer]: TOBSPLeaf read GetLeaf;
    property LeafCount: Integer read GetLeafCount;

    property LeafBrushes[Index: Integer]: Integer read GetLeafBrush;
    property LeafBrushCount: Integer read GetLeafBrushCount;

    property LeafSurfaces[Index: Integer]: Integer read GetLeafSurface;
    property LeafSurfaceCount: Integer read GetLeafSurfaceCount;

    property Brushes[Index: Integer]: TOBSPBrush read GetBrush;
    property BrushCount: Integer read GetBrushCount;

    property BrushSides[Index: Integer]: TOBSPBrushSide read GetBrushSide;
    property BrushSideCount: Integer read GetBrushSideCount;

    property Surfaces[Index: Integer]: TOBSPSurface read GetSurface;
    property SurfaceCount: Integer read GetSurfaceCount;

    property Elements[Index: Integer]: Integer read GetElement;
    property ElementCount: Integer read GetElementCount;

    property Vertices[Index: Integer]: TOBSPVertex read GetVertex;
    property VertexCount: Integer read GetVertexCount;

    property Lightmaps[Index: Integer]: PVector3bArray read GetLightmap;
    property LightmapCount: Integer read FLightmapCount;
    property LightmapWidth: Integer read FLightmapWidth;
    property LightmapHeight: Integer read FLightmapHeight;
  end;

implementation

{ TOBSPMap }

procedure TOBSPMap.ClearMap;
begin
  FMaterials.Clear;
  FPlanes := nil;
  FNodes := nil;
  FLeafs := nil;
  FLBrushes := nil;
  FLSurfaces := nil;
  FBrushes := nil;
  FBrushSides := nil;
  FSurfaces := nil;
  FElements := nil;
  FVertices := nil;
  FLightmaps := nil;
  FLightmapHeight := 256;
  FLightmapWidth := 256;
  FLightmapCount := 0;
end;

constructor TOBSPMap.Create;
begin
  FMaterials := TStringList.Create;

  ClearMap;
end;

destructor TOBSPMap.Destroy;
begin
  FMaterials.Free;
  inherited;
end;

function TOBSPMap.GetBrush(Index: Integer): TOBSPBrush;
begin
  Result := FBrushes[Index];
end;

function TOBSPMap.GetBrushCount: Integer;
begin
  Result := Length(FBrushes);
end;

function TOBSPMap.GetBrushSide(Index: Integer): TOBSPBrushSide;
begin
  Result := FBrushSides[Index];
end;

function TOBSPMap.GetBrushSideCount: Integer;
begin
  Result := Length(FBrushSides);
end;

function TOBSPMap.GetElement(Index: Integer): Integer;
begin
  Result := FElements[Index];
end;

function TOBSPMap.GetElementCount: Integer;
begin
  Result := Length(FElements);
end;

function TOBSPMap.GetLeaf(Index: Integer): TOBSPLeaf;
begin
  Result := FLeafs[Index];
end;

function TOBSPMap.GetLeafBrush(Index: Integer): Integer;
begin
  Result := FLBrushes[Index];
end;

function TOBSPMap.GetLeafBrushCount: Integer;
begin
  Result := Length(FLBrushes);
end;

function TOBSPMap.GetLeafCount: Integer;
begin
  Result := Length(FLeafs);
end;

function TOBSPMap.GetLeafSurface(Index: Integer): Integer;
begin
  Result := FLSurfaces[Index];
end;

function TOBSPMap.GetLeafSurfaceCount: Integer;
begin
  Result := Length(FLSurfaces);
end;

function TOBSPMap.GetLightmap(Index: Integer): PVector3bArray;
begin
  Result := @FLightmaps[Index * FLightmapWidth * FLightmapHeight * 3];
end;

function TOBSPMap.GetMaterial(Index: Integer): String;
begin
  Result := FMaterials.Strings[Index];
end;

function TOBSPMap.GetMaterialCount: Integer;
begin
  Result := FMaterials.Count;
end;

function TOBSPMap.GetNode(Index: Integer): TOBSPNode;
begin
  Result := FNodes[Index];
end;

function TOBSPMap.GetNodeCount: Integer;
begin
  Result := Length(FNodes);
end;

function TOBSPMap.GetPlane(Index: Integer): TOBSPPlane;
begin
  Result := FPlanes[Index];
end;

function TOBSPMap.GetPlaneCount: Integer;
begin
  Result := Length(FPlanes);
end;

function TOBSPMap.GetSurface(Index: Integer): TOBSPSurface;
begin
  Result := FSurfaces[Index];
end;

function TOBSPMap.GetSurfaceCount: Integer;
begin
  Result := Length(FSurfaces);
end;

function TOBSPMap.GetVertex(Index: Integer): TOBSPVertex;
begin
  Result := FVertices[Index];
end;

function TOBSPMap.GetVertexCount: Integer;
begin
  Result := Length(FVertices);
end;

procedure TOBSPMap.LoadBrushes(Stream: TStream; OffsetStart: Cardinal;
  Header: TOBSPHeader);
begin
  SetLength(FBrushes, Header.Lumps[LUMP_BRUSHES].Length div SizeOf(TOBSPBrush));
  Stream.Seek(OffsetStart + Header.Lumps[LUMP_BRUSHES].Offset, soFromBeginning);
  Stream.Read(FBrushes[0], Header.Lumps[LUMP_BRUSHES].Length);
end;

procedure TOBSPMap.LoadBrushSides(Stream: TStream; OffsetStart: Cardinal;
  Header: TOBSPHeader);
begin
  SetLength(FBrushSides, Header.Lumps[LUMP_BRUSHSIDES].Length div SizeOf(TOBSPBrushSide));
  Stream.Seek(OffsetStart + Header.Lumps[LUMP_BRUSHSIDES].Offset, soFromBeginning);
  Stream.Read(FBrushSides[0], Header.Lumps[LUMP_BRUSHSIDES].Length);
end;

procedure TOBSPMap.LoadElements(Stream: TStream; OffsetStart: Cardinal;
  Header: TOBSPHeader);
begin
  SetLength(FElements, Header.Lumps[LUMP_ELEMENTS].Length div SizeOf(Cardinal));
  Stream.Seek(OffsetStart + Header.Lumps[LUMP_ELEMENTS].Offset, soFromBeginning);
  Stream.Read(FElements[0], Header.Lumps[LUMP_ELEMENTS].Length);
end;

procedure TOBSPMap.LoadEntities(Stream: TStream; OffsetStart: Cardinal;
  Header: TOBSPHeader);
begin

end;

function TOBSPMap.LoadFromFile(Filename: String): Boolean;
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

function TOBSPMap.LoadFromStream(Stream: TStream): Boolean;
var
  header: TOBSPHeader;
  offset: Integer;
begin
  Result := False;

  offset := Stream.Position;

  Stream.Read(header, SizeOf(header));

  if not ((header.Identity = OBSP_IDENTITY) and
          (header.Version = OBSP_VERSION)) then
    Exit;

  ClearMap;

  LoadEntities(Stream, offset, header);
  LoadMaterials(Stream, offset, header);
  LoadPlanes(Stream, offset, header);
  LoadNodes(Stream, offset, header);
  LoadLeafs(Stream, offset, header);
  LoadLeafBrushes(Stream, offset, header);
  LoadLeafSurfaces(Stream, offset, header);
  LoadBrushes(Stream, offset, header);
  LoadBrushSides(Stream, offset, header);
  LoadSurfaces(Stream, offset, header);
  LoadElements(Stream, offset, header);
  LoadVertices(Stream, offset, header);
  LoadLightmaps(Stream, offset, header);

  Result := True;
end;

procedure TOBSPMap.LoadLeafBrushes(Stream: TStream; OffsetStart: Cardinal;
  Header: TOBSPHeader);
begin
  SetLength(FLBrushes, Header.Lumps[LUMP_LBRUSHES].Length div SizeOf(Cardinal));
  Stream.Seek(OffsetStart + Header.Lumps[LUMP_LBRUSHES].Offset, soFromBeginning);
  Stream.Read(FLBrushes[0], Header.Lumps[LUMP_LBRUSHES].Length);
end;

procedure TOBSPMap.LoadLeafs(Stream: TStream; OffsetStart: Cardinal;
  Header: TOBSPHeader);
begin
  SetLength(FLeafs, Header.Lumps[LUMP_LEAFS].Length div SizeOf(TOBSPLeaf));
  Stream.Seek(OffsetStart + Header.Lumps[LUMP_LEAFS].Offset, soFromBeginning);
  Stream.Read(FLeafs[0], Header.Lumps[LUMP_LEAFS].Length);
end;

procedure TOBSPMap.LoadLeafSurfaces(Stream: TStream; OffsetStart: Cardinal;
  Header: TOBSPHeader);
begin
  SetLength(FLSurfaces, Header.Lumps[LUMP_LSURFACES].Length div SizeOf(Cardinal));
  Stream.Seek(OffsetStart + Header.Lumps[LUMP_LSURFACES].Offset, soFromBeginning);
  Stream.Read(FLSurfaces[0], Header.Lumps[LUMP_LSURFACES].Length);
end;

procedure TOBSPMap.LoadLightmaps(Stream: TStream; OffsetStart: Cardinal;
  Header: TOBSPHeader);
begin
  SetLength(FLightmaps, Header.Lumps[LUMP_LIGHTMAPS].Length);
  Stream.Seek(OffsetStart + Header.Lumps[LUMP_LIGHTMAPS].Offset, soFromBeginning);
  Stream.Read(FLightmaps[0], Header.Lumps[LUMP_LIGHTMAPS].Length);
  FLightmapCount := Header.Lumps[LUMP_LIGHTMAPS].Length div (FLightmapWidth * FLightmapHeight * 3);
end;

procedure TOBSPMap.LoadMaterials(Stream: TStream; OffsetStart: Cardinal;
  Header: TOBSPHeader);
var
  matstr, s: String;
  i, len: Integer;
  //matstr:string;
  buffer:PChar;
begin
 // strpcopy(buffer,matstr);
  Stream.Seek(OffsetStart + Header.Lumps[LUMP_MATERIALS].Offset, soFromBeginning);
  buffer:=stralloc(Header.Lumps[LUMP_MATERIALS].Length);
 // SetLength(matstr, Header.Lumps[LUMP_MATERIALS].Length);
 // buffer:=pchar(matstr);
  //Stream.Read(PChar(matstr)^, Header.Lumps[LUMP_MATERIALS].Length);
  Stream.Read(buffer, Header.Lumps[LUMP_MATERIALS].Length);
  matstr:=strpas(buffer);
  strdispose(buffer);
  len := Length(matstr);
  s := '';
  i:=1;
  while i <= len do
  begin
    if matstr[i] = #0 then
    begin
      FMaterials.Add(s);
      s := '';
    end
    else
      s := s + matstr[i];

    Inc(i);
  end;
end;

procedure TOBSPMap.LoadNodes(Stream: TStream; OffsetStart: Cardinal;
  Header: TOBSPHeader);
begin
  SetLength(FNodes, Header.Lumps[LUMP_NODES].Length div SizeOf(TOBSPNode));
  Stream.Seek(OffsetStart + Header.Lumps[LUMP_NODES].Offset, soFromBeginning);
  Stream.Read(FNodes[0], Header.Lumps[LUMP_NODES].Length);
end;

procedure TOBSPMap.LoadPlanes(Stream: TStream; OffsetStart: Cardinal;
  Header: TOBSPHeader);
begin
  SetLength(FPlanes, Header.Lumps[LUMP_PLANES].Length div SizeOf(TOBSPPlane));
  Stream.Seek(OffsetStart + Header.Lumps[LUMP_PLANES].Offset, soFromBeginning);
  Stream.Read(FPlanes[0], Header.Lumps[LUMP_PLANES].Length);
end;

procedure TOBSPMap.LoadSurfaces(Stream: TStream; OffsetStart: Cardinal;
  Header: TOBSPHeader);
begin
  SetLength(FSurfaces, Header.Lumps[LUMP_SURFACES].Length div SizeOf(TOBSPSurface));
  Stream.Seek(OffsetStart + Header.Lumps[LUMP_SURFACES].Offset, soFromBeginning);
  Stream.Read(FSurfaces[0], Header.Lumps[LUMP_SURFACES].Length);
end;

procedure TOBSPMap.LoadVertices(Stream: TStream; OffsetStart: Cardinal;
  Header: TOBSPHeader);
begin
  SetLength(FVertices, Header.Lumps[LUMP_VERTICES].Length div SizeOf(TOBSPVertex));
  Stream.Seek(OffsetStart + Header.Lumps[LUMP_VERTICES].Offset, soFromBeginning);
  Stream.Read(FVertices[0], Header.Lumps[LUMP_VERTICES].Length);
end;

end.
