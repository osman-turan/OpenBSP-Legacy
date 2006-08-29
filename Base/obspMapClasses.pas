//
//  Project     : OpenBSP Map Compiler
//  Unit        : obspMapClasses.pas
//  Description : Includes map class object
//  History:
//    26/01/05 - OT - "TTraceObject" has been moved to "obspTrace.pas"
//    15/01/05 - OT - Added "_blocksize" entity key (SoF2)
//    08/01/05 - OT - More faster tracing
//    04/01/05 - OT - New triangle level tracing routine for lighting
//    27/11/04 - OT - Surface class divided into three type: Planar, Mesh, Patch
//    02/11/04 - OT - Added bogus range check in TBrushSide.BuildBasePolygon
//    26/10/04 - OT - Fixed material saving phase
//    25/10/04 - OT - Removed texture matrix multiplication from TBrushSide.Create
//    13/10/04 - OT - Added TFacetEdge
//                    Added TSurface.QueryInsidePoint
//    30/08/04 - OT - Added TSurface.GetPolygon
//    14/08/04 - OT - Fixed map saving phase
//                    A little faster map saving                          
//    11/07/04 - OT - More faster occlusion query
//                    Little optimization on surface creation from brush side  
//    03/07/04 - OT - Polygon classes has moved to obspPolygon.pas
//                    A bit fast occlusion query
//    02/07/04 - OT - Added lightmapmaping stuffs
//    28/06/04 - OT - A bit faster BSP writing code
//    27/06/04 - OT - BSP tree generation
//                    Faster InternalClip (TPolygon)
//                    Fixed Split (TPolygon)
//    25/06/04 - OT - Fixed texture coordinate generation
//                    Added InternalClip (TPolygon)
//                    Added TriangulateAsStrip (TBrushSide)
//    21/06/04 - OT - Creation
//
unit obspMapClasses;

interface

uses SysUtils, Classes, obspBaseTypes, obspFile, obspParser, obspPolygon,
  obspMaterial;

const
// these values must be power of 2
  MAX_LIGHTMAP_WIDTH  = 1024;
  MAX_LIGHTMAP_HEIGHT = 1024;
  DEFAULT_LIGHTMAP_WIDTH = 256;
  DEFAULT_LIGHTMAP_HEIGHT = 256;
  MIN_LIGHTMAP_WIDTH  = 64;
  MIN_LIGHTMAP_HEIGHT = 64;

  MIN_LIGHTING_SAMPLE_SIZE      = 1; // can eat tons of memory!!!
  DEFAULT_LIGHTING_SAMPLE_SIZE  = 16;
  MAX_LIGHTING_SAMPLE_SIZE      = 64;

  MIN_BLOCK_SIZE                = 128;
  DEFAULT_BLOCK_SIZE            = 1024;
  MAX_BLOCK_SIZE                = 8192;

type
  TEntity = class;
  TBrushSide = class;
  TBrush = class;
  TBSPNode = class;
  TSurface = class;

// World class
  TWorld = class
  private
    FEntities: TList;
    FWorldSpawn: TEntity;
    FHeadNode: TBSPNode;
    FMaterialManager: TMaterialManager;
    FMaterialList: TStringList;         // used at saving map only
    FPlanes: array of TPlane;
    FPlaneCount: Integer;
    FLightmaps: array of PVector3bArray;
    FLightmapCount: Integer;
    FLightmapHeight: Integer;
    FLightmapWidth: Integer;
    FLightmapSampleSize: Integer;
    FBlockSize: TVector3f;

    function GetPlane(Index: Integer): TPlane;
    procedure SetPlane(Index: Integer; const Value: TPlane);
    function GetEntity(Index: Integer): TEntity;
    function GetEntityCount: Integer;
    procedure SetEntity(Index: Integer; const Value: TEntity);
    function GetLightmap(Index: Integer): PVector3bArray;
    procedure SetLightmap(Index: Integer; const Value: PVector3bArray);
  protected
    procedure AddEntityToList(const Entity: TEntity);
    procedure BuildObjectIndices;
    procedure WriteLump(Lump: Integer;
                        const Buffer;
                        Count: Integer;
                        Stream: TStream;
                        var Header: TOBSPHeader);
    procedure WriteEntities(Stream: TStream; var Header: TOBSPHeader);
    procedure WriteMaterials(Stream: TStream; var Header: TOBSPHeader);
    procedure WritePlanes(Stream: TStream; var Header: TOBSPHeader);
    procedure WriteBrushes(Stream: TStream; var Header: TOBSPHeader);
    procedure WriteBrushSides(Stream: TStream; var Header: TOBSPHeader);
    procedure WriteSurfaces(Stream: TStream; var Header: TOBSPHeader);
    procedure WriteElements(Stream: TStream; var Header: TOBSPHeader);
    procedure WriteVertices(Stream: TStream; var Header: TOBSPHeader);
    procedure WriteLightmaps(Stream: TStream; var Header: TOBSPHeader);
  public
    constructor Create;
    destructor Destroy; override;

    procedure InitWorld;

    function SaveToFile(const Filename: String): Integer; // returns saved map size
    procedure Clear;

    function AddEntity: TEntity;
    function AddPlane(const Plane: TPlane): Integer;

    procedure ClearLightmaps;
    function NewLightmap: Integer;

    property WorldSpawn: TEntity read FWorldSpawn;

    property HeadNode: TBSPNode read FHeadNode write FHeadNode;
    property BlockSize: TVector3f read FBlockSize write FBlockSize;
    property LightmapWidth: Integer read FLightmapWidth;
    property LightmapHeight: Integer read FLightmapHeight;
    property LightmapSampleSize: Integer read FLightmapSampleSize;
    property Lightmaps[Index: Integer]: PVector3bArray read GetLightmap write SetLightmap;
    property LightmapCount: Integer read FLightmapCount;
    property Planes[Index: Integer]: TPlane read GetPlane write SetPlane;
    property PlaneCount: Integer read FPlaneCount;
    property Entities[Index: Integer]: TEntity read GetEntity write SetEntity;
    property EntityCount: Integer read GetEntityCount;

    property MaterialManager: TMaterialManager read FMaterialManager;
  end;

// Entity class
  PEntityPair = ^TEntityPair;
  TEntityPair = packed record
    Key: String;
    Value: String;
  end;

  PEntityPairArray = ^TEntityPairArray;
  TEntityPairArray = array[0..MAXINT shr 4] of TEntityPair;

  TEntity = class
  private
    FWorld: TWorld;
    FParser: TTextParser;
    FKeys: PEntityPairArray;
    FBrushes: TList;
    FSurfaces: TList;
    FKeyCount: Integer;
    FKeyGrowSize: Integer;
    FKeyCapacity: Integer;
    function GetBrush(Index: Integer): TBrush;
    function GetBrushCount: Integer;
    procedure SetBrush(Index: Integer; const Value: TBrush);
    procedure SetKeyCapacity(const Value: Integer);
    procedure SetKeyGrowSize(const Value: Integer);
    function GetSurface(Index: Integer): TSurface;
    function GetSurfaceCount: Integer;
    procedure SetSurface(Index: Integer; const Value: TSurface);
  protected
    procedure GrowUpKeys;
    procedure AddBrushToList(const Brush: TBrush);
  public
    constructor Create(AOwner: TWorld);
    destructor Destroy; override;

    function KeyForIndex(const Index: Integer): String;
    function IndexForKey(const Key: String): Integer;

    function IsKeyExists(const Key: String): Boolean;
    function ValueForKey(const Key: String): String;
    function ValueForIndex(const Index: Integer): String;
    function VectorForKey(const Key: String): TVector3f;
    function Matrix3x3ForKey(const Key: String): TMatrix4f;
    function FloatForKey(const Key: String; const Default: Extended = 0): Single;
    function FloatArrayForKey(const Key: String;
                               var FltArray: array of Single;
                               const Count: Integer): Boolean;
    function IntForKey(const Key: String; const Default: Integer = 0): Integer;
    procedure SetKeyValue(const Key, Value: String);

    procedure AddKey(const Key, Value: String);
    procedure RemoveKey(const Key: String);

    function GetEntityString: String;
    procedure BuildBasePolygons;
    procedure BuildSurfaces;

    function AddBrush: TBrush;
    function GetBrushIndex(Brush: TBrush): Integer;
    function AddSurface(Surf: TSurface): Integer;
    function GetSurfaceIndex(Surf: TSurface): Integer;
    procedure RemoveSurface(Surf: TSurface);

    property Brushes[Index: Integer]: TBrush read GetBrush write SetBrush;
    property BrushCount: Integer read GetBrushCount;
    property Surfaces[Index: Integer]: TSurface read GetSurface write SetSurface;
    property SurfaceCount: Integer read GetSurfaceCount;

    property KeyCount: Integer read FKeyCount;
    property KeyGrowSize: Integer read FKeyGrowSize write SetKeyGrowSize;
    property KeyCapacity: Integer read FKeyCapacity write SetKeyCapacity;

    property World: TWorld read FWorld;
  end;

  TSurfaceType = (stNone, stPlanar, stTriangleMesh, stPatch);

  TSurface = class
  private
    FMaterialIndex: Integer;
    FOwnerEntity: TEntity;
    function GetElement(Index: Integer): Cardinal;
    function GetVertex(Index: Integer): POBSPVertex;
    procedure SetElement(Index: Integer; const Value: Cardinal);
    procedure SetVertex(Index: Integer; const Value: POBSPVertex);
    function GetMaterial: PMaterial;
  protected
    FSurfaceType: TSurfaceType;
    FVertices: array of TOBSPVertex;
    FVertexCount: Integer;
    FElementCount: Integer;
    FElements: array of Cardinal;
    FAABB: TAABB;
    FOutputIndex: Cardinal;
    procedure DoClear; dynamic; abstract; // for patches
  public
    constructor Create(Owner: TEntity; MaterialName: String); virtual;
    destructor Destroy; override;

    procedure CalcBounds;
    function AddVertex(const Vert: TOBSPVertex): Integer;
    function AddElement(const Elem: Cardinal): Integer; overload;
    procedure AddElement(iA, iB, iC: Cardinal); overload;
    function GetElementsAsAddress: Pointer;
    function GetVerticesAsAddress: Pointer;
    procedure Clear;
    procedure ClearElements;
    procedure ClearVertices;
    function GetPolygon: TPolygon;

    property SurfaceType: TSurfaceType read FSurfaceType;
    property Material: PMaterial read GetMaterial;
    property MaterialIndex: Integer read FMaterialIndex;
    property Elements[Index: Integer]: Cardinal read GetElement write SetElement;
    property ElementCount: Integer read FElementCount;
    property Vertices[Index: Integer]: POBSPVertex read GetVertex write SetVertex;
    property VertexCount: Integer read FVertexCount;
    property AABB: TAABB read FAABB write FAABB;

    property OwnerEntity: TEntity read FOwnerEntity write FOwnerEntity;
    property OutputIndex: Cardinal read FOutputIndex write FOutputIndex;
  end;


{  TSurface = class
  private
    FFacetList: array of TFacet;
    FFacetCount: Integer;
    FVertices: array of TOBSPVertex;
    FElements: array of Cardinal;
    FElementCount: Integer;
    FVertexCount: Integer;
    FOutputIndex: Cardinal;
    FAABB: TAABB;
    FLightmapHeight: Integer;
    FLightmapOffsetY: Integer;
    FLightmapWidth: Integer;
    FLightmapOffsetX: Integer;
    FLightmapOrigin: TVector3f;
    FLightmapVectorS: Single;
    FLightmapVectorT: Single;
    FLightmapIndex: Cardinal;
    FSurfaceType: TSurfaceType;
    FOwner: TBrushSide;
    function GetElement(Index: Integer): Cardinal;
    function GetVertex(Index: Integer): POBSPVertex;
    procedure SetElement(Index: Integer; const Value: Cardinal);
    procedure SetVertex(Index: Integer; const Value: POBSPVertex);
  protected
    procedure CreateFacetsFromPolygon;
    procedure CreateFacetsFromTriangles;

    procedure TriangulateAsFan;
    function TriangulateAsStrip: Boolean;
  public
    constructor Create(AOwner: TBrushSide);
    destructor Destroy; override;

    function AddVertex(const Vert: TOBSPVertex): Integer;
    function AddElement(const Elem: Cardinal): Integer; overload;
    procedure AddElement(iA, iB, iC: Cardinal); overload;
    function GetElementsAsAddress: Pointer;
    function GetVerticesAsAddress: Pointer;
    procedure Clear;
    procedure ClearElements;
    procedure ClearVertices;
    function GetPolygon: TPolygon;

    function ClosestPointOnEdges(const From: TVector3f): TVector3f;

    procedure Triangulate;

    procedure InitQuery;
    procedure FreeQuery;
    function QueryInsidePoint(const P: TVector3f): Boolean;
    function QueryTracing(StartPoint, EndPoint: TVector3f;
                   const HitPoint: PVector3f;
                   const Fraction: PSingle): Boolean;
    function QueryOcclusion(StartPoint, EndPoint: TVector3f): Boolean;

    property SurfaceType: TSurfaceType read FSurfaceType write FSurfaceType;
    property Elements[Index: Integer]: Cardinal read GetElement write SetElement;
    property ElementCount: Integer read FElementCount;
    property Vertices[Index: Integer]: POBSPVertex read GetVertex write SetVertex;
    property VertexCount: Integer read FVertexCount;
    property AABB: TAABB read FAABB write FAABB;
    property LightmapIndex: Cardinal read FLightmapIndex write FLightmapIndex;
    property LightmapOrigin: TVector3f read FLightmapOrigin write FLightmapOrigin;
    property LightmapOffsetX: Integer read FLightmapOffsetX write FLightmapOffsetX;
    property LightmapOffsetY: Integer read FLightmapOffsetY write FLightmapOffsetY;
    property LightmapVectorS: Single read FLightmapVectorS write FLightmapVectorS;
    property LightmapVectorT: Single read FLightmapVectorT write FLightmapVectorT;
    property LightmapWidth: Integer read FLightmapWidth write FLightmapWidth;
    property LightmapHeight: Integer read FLightmapHeight write FLightmapHeight;

  // Owner can be nil if not made from a brush side
    property Owner: TBrushSide read FOwner write FOwner;
    property OutputIndex: Cardinal read FOutputIndex write FOutputIndex;
  end;
}
// Brush side class
  TBrushSide = class
  private
    FOwner: TBrush;
    FMaterialIndex: Integer;
    FSurfaceList: TList;
    FPlaneIndex: Integer;
    FTangent: TVector3f;
    FBinormal: TVector3f;
    FNormal: TVector3f;
    FOrigin: TVector3f;
    FTexMatrix: TMatrix4f;
    FBasePolygon: TPolygon;
    FVisiblePolygon: TPolygon;
    FVisible: Boolean;
    FCulled: Boolean;
    function GetWorld: TWorld;
    procedure SetPlaneIndex(const Value: Integer);
    function GetPlane: TPlane;
    function GetSurface(Index: Integer): TSurface;
    function GetSurfaceCount: Integer;
    procedure SetSurface(Index: Integer; const Value: TSurface);
    function GetMaterial: PMaterial;
  public
    constructor Create(AOwner: TBrush;
                       Plane: TPlane;
                       MaterialName: String;
                       TexMatrix: TMatrix4f);
    destructor Destroy; override;

    procedure BuildBasePolygon;
    function BuildSurfaceForPolygon(const Poly: TPolygon): TSurface;

    function AddSurface(Surf: TSurface): Integer;
    procedure RemoveSurface(Surf: TSurface);
    function GetSurfaceIndex(const Surface: TSurface): Integer;
    procedure ClearSurfaces;

    property Culled: Boolean read FCulled write FCulled;
    property Visible: Boolean read FVisible write FVisible;
    property BasePolygon: TPolygon read FBasePolygon;
    property VisiblePolygon: TPolygon read FVisiblePolygon write FVisiblePolygon;
    property Surfaces[Index: Integer]: TSurface read GetSurface write SetSurface;
    property SurfaceCount: Integer read GetSurfaceCount;

    property Material: PMaterial read GetMaterial;
    property MaterialIndex: Integer read FMaterialIndex;
    property TextureMatrix: TMatrix4f read FTexMatrix;
    property Plane: TPlane read GetPlane;
    property PlaneIndex: Integer read FPlaneIndex write SetPlaneIndex;
    property Origin: TVector3f read FOrigin;
    property Tangent: TVector3f read FTangent;
    property Binormal: TVector3f read FBinormal;
    property Normal: TVector3f read FNormal;

    property Owner: TBrush read FOwner;
    property World: TWorld read GetWorld;
  end;

// Brush class
  TBrush = class
  private
    FOwner: TEntity;
    FBrushSides: TList;
    FOutputIndex: Cardinal;
    FAABB: TAABB;
    FOpaque: Boolean;
    function GetWorld: TWorld;
    function GetSide(Index: Integer): TBrushSide;
    function GetSideCount: Integer;
    procedure SetSide(Index: Integer; const Value: TBrushSide);
  protected
    procedure AddSideToList(const Side: TBrushSide);
  public
    constructor Create(AOwner: TEntity);
    destructor Destroy; override;

    function CreateCopy: TBrush;
    function AddSide(const p1, p2, p3: TVector3f;
                     const Material: String;
                     const TexMatrix: TMatrix4f): TBrushSide; overload;
    function AddSide(const Plane: TPlane;
                     const Material: String;
                     const TexMatrix: TMatrix4f): TBrushSide; overload;
    function BuildBasePolygons: Boolean;
    procedure Split(Plane: TPlane; out Front, Back: TBrush);
    function MostlyOnSide(Plane: TPlane): TSideClassify;
    function GetVolume: Single;

    property OutputIndex: Cardinal read FOutputIndex write FOutputIndex;
    property Opaque: Boolean read FOpaque write FOpaque;
    property Sides[Index: Integer]: TBrushSide read GetSide write SetSide;
    property SideCount: Integer read GetSideCount;
    property AABB: TAABB read FAABB;

    property Owner: TEntity read FOwner;
    property World: TWorld read GetWorld;
  end;

  TBSPReference = class
  private
    FPlaneIndex: Integer;
    FPolygon: TPolygon;
    FWorld: TWorld;
    FChecked: Boolean;
    function GetPlane: TPlane;
  public
    constructor Create(AWorld: TWorld;
                       Source: TPolygon;
                       APlaneIndex: Integer);
    destructor Destroy; override;

    property Checked: Boolean read FChecked write FChecked;
    property Polygon: TPolygon read FPolygon;
    property Plane: TPlane read GetPlane;
    property PlaneIndex: Integer read FPlaneIndex;

    property World: TWorld read FWorld;
  end;

  TBSPReferenceList = class
  private
    FList: TList;
    function GetCount: Integer;
    function GetReferences(Index: Integer): TBSPReference;
    procedure SetReferences(Index: Integer; const Value: TBSPReference);
  public
    constructor Create;
    destructor Destroy; override;

    procedure UnCheckAll;
    function IndexOf(Ref: TBSPReference): Integer;
    procedure Add(Ref: TBSPReference);
    procedure Delete(Ref: TBSPReference);
    procedure Clear;

    property References[Index: Integer]: TBSPReference read GetReferences write SetReferences;
    property Count: Integer read GetCount;
  end;

  PBSPSideReference = ^TBSPSideReference;
  TBSPSideReference = packed record
    Side: TBrushSide;
    Surf: TSurface;
  end;

  TBSPNode = class
  private
    FOwner: TBSPNode;
    FWorld: TWorld;
    FBrushList: TList;
    FSurfaceList: TList;
    FReferenceList: TBSPReferenceList;
    FFrontChild: TBSPNode;
    FBackChild: TBSPNode;
    FPlaneIndex: Integer;
    FAABB: TAABB;
    FOpaque: Boolean;
    function GetIsLeaf: Boolean;
    function GetPlane: TPlane;
    function GetSurface(Index: Integer): TSurface;
    function GetSurfaceCount: Integer;
    procedure SetSurface(Index: Integer; const Value: TSurface);
    function GetBrush(Index: Integer): TBrush;
    function GetBrushCount: Integer;
    procedure SetBrush(Index: Integer; const Value: TBrush);
  protected
    function SelectSplitter(out Splitter: Integer): Boolean;
  public
    constructor Create(AWorld: TWorld;
                       AOwner: TBSPNode;
                       RefList: TBSPReferenceList);
    destructor Destroy; override;

    procedure BuildNode;

    function AddSurface(Surf: TSurface): Integer;
    function AddBrush(Brush: TBrush): Integer;
    function IndexOfBrush(Brush: TBrush): Integer;
    function IndexOfSurface(Surf: TSurface): Integer;

    function LeafForPoint(Point: TVector3f): TBSPNode;

    property Surfaces[Index: Integer]: TSurface read GetSurface write SetSurface;
    property SurfaceCount: Integer read GetSurfaceCount;

    property Brushes[Index: Integer]: TBrush read GetBrush write SetBrush;
    property BrushCount: Integer read GetBrushCount;

    property Plane: TPlane read GetPlane;
    property PlaneIndex: Integer read FPlaneIndex;
    property IsLeaf: Boolean read GetIsLeaf;
    property Opaque: Boolean read FOpaque write FOpaque;
    property FrontChild: TBSPNode read FFrontChild write FFrontChild;
    property BackChild: TBSPNode read FBackChild write FBackChild;
    property AABB: TAABB read FAABB;

    property Owner: TBSPNode read FOwner;
    property World: TWorld read FWorld;
  end;

implementation

uses obspMath, obspUtils, obspSurfPlanar, obspSurfTriMesh, obspSurfPatch;

{ TWorld }

function TWorld.AddEntity: TEntity;
begin
  Result := TEntity.Create(Self);
end;

procedure TWorld.AddEntityToList(const Entity: TEntity);
begin
  FEntities.Add(Entity);
end;

function TWorld.AddPlane(const Plane: TPlane): Integer;
var
  p: TPlane;
  i: Integer;
begin
  p := plane_snap(Plane);
  for i:=0 to FPlaneCount-1 do
  begin
    if (p.Normal[0] = FPlanes[i].Normal[0]) and
       (p.Normal[1] = FPlanes[i].Normal[1]) and
       (p.Normal[2] = FPlanes[i].Normal[2]) and
       (p.Dist = FPlanes[i].Dist) then
    begin
      Result := i;
      Exit;
    end;
  end;

// (PlaneIndex xor 1) equals negative plane
  SetLength(FPlanes, FPlaneCount+2);
  FPlanes[FPlaneCount] := p;
  FPlanes[FPlaneCount+1] := plane_negate(p);
  Result := FPlaneCount;
  Inc(FPlaneCount, 2);
end;

procedure TWorld.BuildObjectIndices;
var
  i, j, k: Integer;
  brushcount: Cardinal;
  surfcount: Cardinal;
  brush: TBrush;
  surf: TSurface;
  side: TBrushSide;
begin
  brushcount:=0;
  surfcount:=0;

  for i:=0 to EntityCount-1 do
  begin
  // emit brushes
    for j:=0 to Entities[i].BrushCount-1 do
    begin
      brush := Entities[i].Brushes[j];
      brush.OutputIndex := brushcount;
      Inc(brushcount);
    // emit brush sides
      for k:=0 to brush.SideCount-1 do
      begin
        side := brush.Sides[k];

        if FMaterialList.IndexOf(side.Material.MaterialName) < 0 then
          FMaterialList.Add(side.Material.MaterialName);
      end;
    end;
  // emit surfaces
    for j:=0 to Entities[i].SurfaceCount-1 do
    begin
      surf := Entities[i].Surfaces[j];
      surf.OutputIndex := surfcount;
      Inc(surfcount);

      if FMaterialList.IndexOf(surf.Material.MaterialName) < 0 then
        FMaterialList.Add(surf.Material.MaterialName);
    end;
  end;
end;

procedure TWorld.Clear;
begin
  while FEntities.Count > 0 do
  begin
    TEntity(FEntities.Items[0]).Free;
    FEntities.Delete(0);
  end;

  FPlanes := nil;
  FPlaneCount := 0;
  FMaterialManager.Clear;
  FMaterialList.Clear;
end;

procedure TWorld.ClearLightmaps;
var i: Integer;
begin
  for i:=0 to FLightmapCount-1 do
    FreeMem(FLightmaps[i]);

  FLightmaps := nil;    
  FLightmapCount := 0;
end;

constructor TWorld.Create;
begin
  FEntities := TList.Create;

  FLightmapSampleSize := DEFAULT_LIGHTING_SAMPLE_SIZE;
  FLightmapWidth := DEFAULT_LIGHTMAP_WIDTH;
  FLightmapHeight := DEFAULT_LIGHTMAP_HEIGHT;
  FBlockSize := vec_make(DEFAULT_BLOCK_SIZE, DEFAULT_BLOCK_SIZE, DEFAULT_BLOCK_SIZE);

  FMaterialManager := TMaterialManager.Create;
  FMaterialList := TStringList.Create;
  FMaterialList.Sorted := True;
  Clear;
end;

destructor TWorld.Destroy;
begin
  ClearLightmaps;
  Clear;
  FMaterialManager.Free;
  FMaterialList.Free;
  FEntities.Free;
  inherited;
end;

function TWorld.GetEntity(Index: Integer): TEntity;
begin
  Result := TEntity(FEntities.Items[Index]);
end;

function TWorld.GetEntityCount: Integer;
begin
  Result := FEntities.Count;
end;

function TWorld.GetLightmap(Index: Integer): PVector3bArray;
begin
  Result := FLightmaps[Index];
end;

function TWorld.GetPlane(Index: Integer): TPlane;
begin
  Result := FPlanes[Index];
end;

procedure TWorld.InitWorld;
var
  i: Integer;
  lm_size: TVector2f;
  block: TVector3f;
  ent: TEntity;
begin
  for i:=0 to EntityCount-1 do
  begin
    ent := Entities[i];

    if SameText(ent.ValueForKey('classname'), 'worldspawn') then
    begin
      FWorldSpawn := ent;

      if ent.IsKeyExists('samplingsize') then
        FLightmapSampleSize := Clamp(Trunc(ent.FloatForKey('samplingsize')), MIN_LIGHTING_SAMPLE_SIZE, MAX_LIGHTING_SAMPLE_SIZE)
      else
        FLightmapSampleSize := DEFAULT_LIGHTING_SAMPLE_SIZE;

      if ent.FloatArrayForKey('lightmapsize', lm_size, 2) then
      begin
        lm_size[0] := Clamp(lm_size[0], MIN_LIGHTMAP_WIDTH, MAX_LIGHTMAP_WIDTH);
        lm_size[1] := Clamp(lm_size[1], MIN_LIGHTMAP_HEIGHT, MAX_LIGHTMAP_HEIGHT);
        FLightmapWidth := NearestPower(Trunc(lm_size[0]));
        FLightmapHeight := NearestPower(Trunc(lm_size[1]));
      end
      else
      begin
        FLightmapWidth := DEFAULT_LIGHTMAP_WIDTH;
        FLightmapHeight := DEFAULT_LIGHTMAP_HEIGHT;
      end;

      if (ent.FloatArrayForKey('_blocksize', block, 3)) or
         (ent.FloatArrayForKey('blocksize', block, 3)) or
         (ent.FloatArrayForKey('chopsize', block, 3)) then
      begin
        FBlockSize[0] := Trunc(Clamp(block[0], MIN_BLOCK_SIZE, MAX_BLOCK_SIZE));
        FBlockSize[1] := Trunc(Clamp(block[1], MIN_BLOCK_SIZE, MAX_BLOCK_SIZE));
        FBlockSize[2] := Trunc(Clamp(block[2], MIN_BLOCK_SIZE, MAX_BLOCK_SIZE));
      end
      else
        FBlockSize := vec_make(DEFAULT_BLOCK_SIZE, DEFAULT_BLOCK_SIZE, DEFAULT_BLOCK_SIZE);

      ent.SetKeyValue('samplingsize', IntToStr(Trunc(FLightmapSampleSize)));
      ent.SetKeyValue('lightmapsize', Format('%d %d', [FLightmapWidth, FLightmapHeight]));
      ent.SetKeyValue('_blocksize', Format('%d %d %d', [Trunc(FBlockSize[0]), Trunc(FBlockSize[1]), Trunc(FBlockSize[2])]));
    end;
  end;
end;

function TWorld.NewLightmap: Integer;
begin
  Result := FLightmapCount;
  Inc(FLightmapCount);
  SetLength(FLightmaps, FLightmapCount);
  GetMem(FLightmaps[FLightmapCount-1], FLightmapWidth * FLightmapHeight * SizeOf(TVector3b));
  FillChar(FLightmaps[FLightmapCount-1]^, FLightmapWidth * FLightmapHeight * SizeOf(TVector3b), 0);
end;

function TWorld.SaveToFile(const Filename: String): Integer;
var
  nodes: array of TOBSPNode;
  numnodes: Integer;
  leafs: array of TOBSPLeaf;
  numleafs: Integer;
  leafbrushes: array of Cardinal;
  numlbrushes: Integer;
  leafsurfaces: array of Cardinal;
  numlsurfaces: Integer;

  function FindInIndexedList(items: array of Cardinal;
                             first: Integer;
                             item: Cardinal;
                             count: Integer): Boolean;
  var i: Integer;
  begin
    Result := False;
    for i:=first to count-1 do
    begin
      if items[i] = item then
        Exit;
    end;
    Result := True;
  end;

  function PrepareLeaf(leaf: TBSPNode): Integer;
  var
    i, s: Integer;
    mapleaf: TOBSPLeaf;
  begin
    mapleaf.FirstBrush := numlbrushes;
    mapleaf.FirstSurface := numlsurfaces;
    mapleaf.NumBrushes := leaf.BrushCount;
    mapleaf.NumSurfaces := 0;

    SetLength(leafbrushes, numlbrushes + leaf.BrushCount);

    for i:=0 to leaf.BrushCount-1 do
      leafbrushes[numlbrushes+i] := leaf.Brushes[i].OutputIndex;

    Inc(numlbrushes, leaf.BrushCount);

    for i:=0 to leaf.SurfaceCount-1 do
    begin
      s := leaf.Surfaces[i].OutputIndex;

      if FindInIndexedList(leafsurfaces,
                           mapleaf.FirstSurface,
                           s, numlsurfaces) then
      begin
        Inc(numlsurfaces);
        Inc(mapleaf.NumSurfaces);
        SetLength(leafsurfaces, numlsurfaces);
        leafsurfaces[numlsurfaces-1] := s;
      end;
    end;

    mapleaf.Cluster := 0;
    mapleaf.Area := 0;
    for i:=0 to 2 do
    begin
      mapleaf.Mins[i] := Round(leaf.AABB.Mins[i]);
      mapleaf.Maxs[i] := Round(leaf.AABB.Maxs[i]);
    end;

    Inc(numleafs);
    SetLength(leafs, numleafs);
    leafs[numleafs-1] := mapleaf;
    Result := numleafs-1;
  end;

  procedure PrepareNode(node: TBSPNode);
  var
    idx, i: Integer;
  begin
    if not Assigned(node) then Exit;

    if node.IsLeaf then
    begin
      PrepareLeaf(node);
      Exit;
    end;

  // WARNING: if using pointer instead of idx,
  // this can cause a mystery access vialotion
    idx := numnodes;
    Inc(numnodes);
    SetLength(nodes, numnodes);

    nodes[idx].PlaneIndex := node.PlaneIndex;
    for i:=0 to 2 do
    begin
      nodes[idx].Mins[i] := Round(node.AABB.Mins[i]);
      nodes[idx].Maxs[i] := Round(node.AABB.Maxs[i]);
    end;

    if node.FrontChild.IsLeaf then
    begin
      nodes[idx].FrontChild := -(PrepareLeaf(node.FrontChild)+1);
    end
    else
    begin
      nodes[idx].FrontChild := numnodes;
      PrepareNode(node.FrontChild);
    end;

    if node.BackChild.IsLeaf then
    begin
      nodes[idx].BackChild := -(PrepareLeaf(node.BackChild)+1);
    end
    else
    begin
      nodes[idx].BackChild := numnodes;
      PrepareNode(node.BackChild);
    end;
  end;

  procedure PrepareEntities;
  begin
    nodes := nil;
    numnodes := 0;
    leafs := nil;
    leafbrushes := nil;
    numlbrushes := 0;
    leafsurfaces := nil;
    numlsurfaces := 0;

    numleafs := 1;
    SetLength(leafs, 1);
    FillChar(leafs[0], SizeOf(TOBSPLeaf), 0);

//    for i:=0 to EntityCount-1 do
      PrepareNode(FHeadNode);
  end;

var
  f: TFileStream;
  header: TOBSPHeader;
begin
  f := TFileStream.Create(Filename, fmCreate);
  try
  // write blank header first
    FillChar(header, SizeOf(header), 0);
    f.Write(header, SizeOf(header));

  // initialize materials
    FMaterialList.Clear;

  // prepare entities for indexing
    BuildObjectIndices;
    PrepareEntities;

  // write lumps
    WriteEntities(f, header);
    WriteMaterials(f, header);
    WritePlanes(f, header);
    WriteLump(LUMP_NODES, nodes[0], numnodes * SizeOf(TOBSPNode), f, header);
    WriteLump(LUMP_LEAFS, leafs[0], numleafs * SizeOf(TOBSPLeaf), f, header);
    WriteLump(LUMP_LBRUSHES, leafbrushes[0], numlbrushes * SizeOf(Cardinal), f, header);
    WriteLump(LUMP_LSURFACES, leafsurfaces[0], numlsurfaces * SizeOf(Cardinal), f, header);
    WriteBrushes(f, header);
    WriteBrushSides(f, header);
    WriteSurfaces(f, header);
    WriteElements(f, header);
    WriteVertices(f, header);
    WriteLightmaps(f, header);

  // write header again
    f.Position := 0;
    header.Identity := OBSP_IDENTITY;
    header.Version  := OBSP_VERSION;
    f.Write(header, SizeOf(header));
  finally
    FMaterialList.Clear;
    nodes := nil;
    leafs := nil;
    leafbrushes := nil;
    leafsurfaces := nil;

    Result := f.Size; // return total written size
    f.Free;
  end;
end;

procedure TWorld.SetEntity(Index: Integer; const Value: TEntity);
begin
  FEntities.Items[Index] := Value;
end;

procedure TWorld.SetLightmap(Index: Integer; const Value: PVector3bArray);
begin
  Move(Value^, FLightmaps[Index]^, FLightmapWidth * FLightmapHeight * SizeOf(TVector3b));
end;

procedure TWorld.SetPlane(Index: Integer; const Value: TPlane);
begin
  FPlanes[Index] := Value;
end;

procedure TWorld.WriteBrushes(Stream: TStream; var Header: TOBSPHeader);
var
  i, j: Integer;
  brush: TBrush;
  mapbrush: TOBSPBrush;
  numSide: Cardinal;
begin
  Header.Lumps[LUMP_BRUSHES].Offset := Stream.Position;
  numSide := 0;
  for i:=0 to EntityCount-1 do
  for j:=0 to Entities[i].BrushCount-1 do
  begin
    brush := Entities[i].Brushes[j];

    mapbrush.FirstSide := numSide;
    mapbrush.NumSides := brush.SideCount;

    Stream.Write(mapbrush, SizeOf(mapbrush));

    Inc(numSide, brush.SideCount);
  end;
  
  Header.Lumps[LUMP_BRUSHES].Length :=
    Stream.Position - Header.Lumps[LUMP_BRUSHES].Offset;
end;

procedure TWorld.WriteBrushSides(Stream: TStream; var Header: TOBSPHeader);
var
  i, j, k: Integer;
  side: TBrushSide;
  mapside: TOBSPBrushSide;
  surfcount: Cardinal;
begin
  Header.Lumps[LUMP_BRUSHSIDES].Offset := Stream.Position;

  surfcount := 0;

  for i:=0 to EntityCount-1 do
  for j:=0 to Entities[i].BrushCount-1 do
  for k:=0 to Entities[i].Brushes[j].SideCount-1 do
  begin
    side := Entities[i].Brushes[j].Sides[k];
    mapside.PlaneIndex := side.PlaneIndex;
    mapside.MaterialIndex := FMaterialList.IndexOf(side.Material.MaterialName);
    mapside.FirstSurface := surfcount;
    mapside.NumSurfaces := side.SurfaceCount;

    Inc(surfcount, side.SurfaceCount);

    Stream.Write(mapside, SizeOf(mapside));
  end;

  Header.Lumps[LUMP_BRUSHSIDES].Length :=
    Stream.Position - Header.Lumps[LUMP_BRUSHSIDES].Offset;
end;

procedure TWorld.WriteElements(Stream: TStream; var Header: TOBSPHeader);
var
  i, j: Integer;
  surf: TSurface;
begin
  Header.Lumps[LUMP_ELEMENTS].Offset := Stream.Position;

  for i:=0 to EntityCount-1 do
  for j:=0 to Entities[i].SurfaceCount-1 do
  begin
    surf := Entities[i].Surfaces[j];

    case surf.SurfaceType of
      stPlanar:       Stream.Write(surf.GetElementsAsAddress^,
                                   SizeOf(Cardinal) * surf.ElementCount);
      stTriangleMesh: Stream.Write(surf.GetElementsAsAddress^,
                                   SizeOf(Cardinal) * surf.ElementCount);
      stPatch: begin end;
    end;
  end;

  Header.Lumps[LUMP_ELEMENTS].Length :=
    Stream.Position - Header.Lumps[LUMP_ELEMENTS].Offset;
end;

procedure TWorld.WriteEntities(Stream: TStream; var Header: TOBSPHeader);
var
  s: String;
  i: Integer;
begin
  Header.Lumps[LUMP_ENTITIES].Offset := Stream.Position;
  for i:=0 to FEntities.Count-1 do
    s := s + TEntity(FEntities.Items[i]).GetEntityString + #10;

  Header.Lumps[LUMP_ENTITIES].Length := Length(s);
  Stream.Write(PChar(s)^, Length(s));
end;

procedure TWorld.WriteLightmaps(Stream: TStream; var Header: TOBSPHeader);
var i: Integer;
begin
  Header.Lumps[LUMP_LIGHTMAPS].Offset := Stream.Position;

  for i:=0 to FLightmapCount-1 do
    Stream.Write(FLightmaps[i]^, FLightmapWidth * FLightmapHeight * SizeOf(TVector3b));

  Header.Lumps[LUMP_LIGHTMAPS].Length :=
    Stream.Position - Header.Lumps[LUMP_LIGHTMAPS].Offset;
end;

procedure TWorld.WriteLump(Lump: Integer; const Buffer; Count: Integer;
  Stream: TStream; var Header: TOBSPHeader);
begin
  Header.Lumps[Lump].Offset := Stream.Position;

  Stream.Write(Buffer, Count);

  Header.Lumps[Lump].Length :=  
    Stream.Position - Header.Lumps[Lump].Offset;
end;

procedure TWorld.WriteMaterials(Stream: TStream; var Header: TOBSPHeader);
var
  i, l, len: Integer;
  s: String;
  mat: array of Char;
begin
  Header.Lumps[LUMP_MATERIALS].Offset := Stream.Position;

  for i:=0 to FMaterialList.Count-1 do
  begin
    s := ConvertDosPathToUnixPath(FMaterialList.Strings[i]);

    len := Length(s)+1;
    SetLength(mat, len);
    for l:=1 to len-1 do
      mat[l-1] := s[l];

    mat[len-1] := #0;
    Stream.Write(mat[0], len);
  end;

  mat := nil;
  Header.Lumps[LUMP_MATERIALS].Length :=
    Stream.Position - Header.Lumps[LUMP_MATERIALS].Offset;
end;

procedure TWorld.WritePlanes(Stream: TStream; var Header: TOBSPHeader);
var
  i: Integer;
  mapplane: TOBSPPlane;
begin
  Header.Lumps[LUMP_PLANES].Offset := Stream.Position;

  for i:=0 to FPlaneCount-1 do
  begin
    mapplane.Normal := FPlanes[i].Normal;
    mapplane.Dist := FPlanes[i].Dist;

    Stream.Write(mapplane, SizeOf(mapplane));
  end;

  Header.Lumps[LUMP_PLANES].Length :=
    Stream.Position - Header.Lumps[LUMP_PLANES].Offset;
end;

procedure TWorld.WriteSurfaces(Stream: TStream; var Header: TOBSPHeader);
var
  i, j: Integer;
  vertcount, elemcount: Cardinal;
  surf: TSurface;
  planarSurf: TPlanarSurface;
  patchSurf: TPatchSurface;
  triSurf: TTriangleMeshSurface;
  mapsurf: TOBSPSurface;
begin
  Header.Lumps[LUMP_SURFACES].Offset := Stream.Position;

  vertcount := 0;
  elemcount := 0;

  for i:=0 to EntityCount-1 do
  for j:=0 to Entities[i].SurfaceCount-1 do
  begin
    surf := Entities[i].Surfaces[j];
    FillChar(mapsurf, SizeOf(mapsurf), 0);

    case surf.SurfaceType of
      stPlanar:
        begin
          planarSurf := (surf as TPlanarSurface);

          with mapsurf do
          begin
            SurfaceType := SURF_TYPE_PLANAR;
            MaterialIndex := FMaterialList.IndexOf(planarSurf.Material.MaterialName);
            FogIndex := -1;
            LightmapIndex := planarSurf.LightmapIndex;
            LightmapOrigin := planarSurf.LightmapOrigin;
            LightmapVector := vec_make(planarSurf.LightmapVectorS, planarSurf.LightmapVectorT);
            LightmapRect[0] := planarSurf.LightmapOffsetX;
            LightmapRect[1] := planarSurf.LightmapOffsetY;
            LightmapRect[2] := planarSurf.LightmapWidth;
            LightmapRect[3] := planarSurf.LightmapHeight;
            FirstVertex := vertcount;
            NumVertices := planarSurf.VertexCount;
            FirstElement := elemcount;
            NumElements := planarSurf.ElementCount;

            Inc(elemcount, NumElements);
            Inc(vertcount, NumVertices);
          end;
        end;

      stTriangleMesh:
        begin
          triSurf := (surf as TTriangleMeshSurface);

          with mapsurf do
          begin
            SurfaceType := SURF_TYPE_MESH;
            MaterialIndex := FMaterialList.IndexOf(triSurf.Material.MaterialName);
            FogIndex := -1;
            LightmapIndex := -1;
            LightmapOrigin := vec_make(0, 0, 0);
            LightmapVector := vec_make(0, 0);
            LightmapRect[0] := 0;
            LightmapRect[1] := 0;
            LightmapRect[2] := 0;
            LightmapRect[3] := 0;
            FirstVertex := vertcount;
            NumVertices := triSurf.VertexCount;
            FirstElement := elemcount;
            NumElements := triSurf.ElementCount;

            Inc(elemcount, NumElements);
            Inc(vertcount, NumVertices);
          end;
        end;

      stPatch:
        begin
          patchSurf := (surf as TPatchSurface);

          with mapsurf do
          begin
            SurfaceType := SURF_TYPE_PATCH;
            MaterialIndex := FMaterialList.IndexOf(patchSurf.Material.MaterialName);
            FogIndex := -1;
            LightmapIndex := patchSurf.LightmapIndex;
            LightmapRect[0] := patchSurf.LightmapOffsetX;
            LightmapRect[1] := patchSurf.LightmapOffsetY;
            LightmapRect[2] := patchSurf.LightmapWidth;
            LightmapRect[3] := patchSurf.LightmapHeight;
            FirstVertex := vertcount;
            NumVertices := patchSurf.VertexCount;
            FirstElement := 0;
            NumElements := 0;

            Inc(vertcount, NumVertices);
          end;
        end;
    end;

    Stream.Write(mapsurf, SizeOf(mapsurf));
  end;

  Header.Lumps[LUMP_SURFACES].Length :=
    Stream.Position - Header.Lumps[LUMP_SURFACES].Offset;
end;

procedure TWorld.WriteVertices(Stream: TStream; var Header: TOBSPHeader);
var
  i, j: Integer;
  surf: TSurface;
  patch: TPatchSurface;
begin
  Header.Lumps[LUMP_VERTICES].Offset := Stream.Position;

  for i:=0 to EntityCount-1 do
  for j:=0 to Entities[i].SurfaceCount-1 do
  begin
    surf := Entities[i].Surfaces[j];

    case surf.SurfaceType of
      stPlanar:       Stream.Write(surf.GetVerticesAsAddress^,
                                   SizeOf(TOBSPVertex) * surf.VertexCount);
      stTriangleMesh: Stream.Write(surf.GetVerticesAsAddress^,
                                   SizeOf(TOBSPVertex) * surf.VertexCount);
      stPatch:        begin
                        patch := (surf as TPatchSurface);
                        Stream.Write(patch.GetControlPointsAsAddress^,
                                     SizeOf(TOBSPVertex) * patch.ControlPointCount);
                      end;
    end;
  end;

  Header.Lumps[LUMP_VERTICES].Length :=
    Stream.Position - Header.Lumps[LUMP_VERTICES].Offset;
end;

{ TEntity }

function TEntity.AddBrush: TBrush;
begin
  Result := TBrush.Create(Self);
  FBrushes.Add(Result);
end;

procedure TEntity.AddBrushToList(const Brush: TBrush);
begin
  FBrushes.Add(Brush);
end;

procedure TEntity.AddKey(const Key, Value: String);
var item: PEntityPair;
begin
  if FKeyCount >= FKeyCapacity then
    GrowUpKeys;

  item := @FKeys^[FKeyCount];

  Pointer(item^.Key) := nil;
  Pointer(item^.Value) := nil;
  item^.Key := Key;
  item^.Value := Value;

  Inc(FKeyCount);
end;

function TEntity.AddSurface(Surf: TSurface): Integer;
begin
  Result := FSurfaces.Add(Surf);
end;

procedure TEntity.BuildBasePolygons;
var idx: Integer;
begin
  idx := BrushCount-1;
  while idx >= 0 do
  begin
    if not (Brushes[idx].BuildBasePolygons) then // invalid brush?
    begin
      TBrush(FBrushes.Items[idx]).Free;
      FBrushes.Delete(idx);
    end;

    Dec(idx);
  end;
end;

procedure TEntity.BuildSurfaces;
var
  i, j: Integer;
  poly: TPolygon;
  side: TBrushSide;
begin
  for i:=0 to BrushCount-1 do
  for j:=0 to Brushes[i].SideCount-1 do
  begin
    side := Brushes[i].Sides[j];

    if (cfNoDraw in side.Material.CompileFlags) then Continue;
    if side.Culled then Continue;
    if not side.Visible then Continue;
    if not Assigned(side.VisiblePolygon) then Continue;

    poly := TPolygon.Create(0);
    poly.Assign(side.VisiblePolygon);
    side.ClearSurfaces;
    side.BuildSurfaceForPolygon(poly);
  end;
end;

constructor TEntity.Create(AOwner: TWorld);
begin
  FKeyCount := 0;
  FKeyCapacity := 0;
  FKeyGrowSize := 8;
  FKeys := nil;
  FBrushes := TList.Create;
  FSurfaces := TList.Create;
  FParser := TTextParser.Create;

  FWorld := AOwner;
  FWorld.AddEntityToList(Self);
end;

destructor TEntity.Destroy;
begin
  while FBrushes.Count > 0 do
  begin
    TBrush(FBrushes.Items[0]).Free;
    FBrushes.Delete(0);
  end;

  while FSurfaces.Count > 0 do
  begin
    TSurface(FSurfaces.Items[0]).Free;
    FSurfaces.Delete(0);
  end;

  FParser.Free;
  FBrushes.Free;
  FSurfaces.Free;
  FreeMem(FKeys);
  inherited;
end;

function TEntity.FloatArrayForKey(const Key: String;
  var FltArray: array of Single; const Count: Integer): Boolean;
var
  s: String;
  i: Integer;
  t: Extended;
begin
  if not IsKeyExists(Key) then
  begin
    Result := False;
    Exit;
  end;

  s := ValueForKey(Key);
  FParser.LoadFromString(s);

  for i:=0 to Count-1 do
  begin
    if FParser.GetNextToken then
    begin
      if TryStrToFloatGeneric(FParser.Token, t) then
        FltArray[i] := t
      else
        FltArray[i] := 0;
    end
    else
      FltArray[i] := 0;
  end;

  Result := True;
end;

function TEntity.FloatForKey(const Key: String;
const Default: Extended = 0): Single;
var
  s: String;
  t: Extended;
begin
  s := ValueForKey(Key);
  if TryStrToFloatGeneric(s, t) then
    Result := t
  else
    Result := Default;
end;

function TEntity.GetBrush(Index: Integer): TBrush;
begin
  Result := TBrush(FBrushes.Items[Index]);
end;

function TEntity.GetBrushCount: Integer;
begin
  Result := FBrushes.Count;
end;

function TEntity.GetBrushIndex(Brush: TBrush): Integer;
begin
  Result := FBrushes.IndexOf(Brush);
end;

function TEntity.GetEntityString: String;
var
  i: Integer;
  s: String;
begin
  s := '';
// I know "Format" function much easier.
// But, this is more fast
  for i:=0 to FKeyCount-1 do
    s := s + '"' + FKeys^[i].Key + '" "' + FKeys^[i].Value + '"' + #10;

  Result := '{'+ #10 + s + '}';
end;

function TEntity.GetSurface(Index: Integer): TSurface;
begin
  Result := TSurface(FSurfaces.Items[Index]);
end;

function TEntity.GetSurfaceCount: Integer;
begin
  Result := FSurfaces.Count;
end;

function TEntity.GetSurfaceIndex(Surf: TSurface): Integer;
begin
  Result := FSurfaces.IndexOf(Surf);
end;

procedure TEntity.GrowUpKeys;
begin
  SetKeyCapacity(FKeyCapacity + FKeyGrowSize);
end;

function TEntity.IndexForKey(const Key: String): Integer;
var i: Integer;
begin
  Result := -1;
  for i:=0 to FKeyCount-1 do
  begin
    if SameText(Key, FKeys^[i].Key) then
    begin
      Result := i;
      Exit;
    end;
  end;
end;

function TEntity.IntForKey(const Key: String;
  const Default: Integer): Integer;
begin
  Result := Trunc(FloatForKey(Key, Default));
end;

function TEntity.IsKeyExists(const Key: String): Boolean;
begin
  Result := (IndexForKey(Key) >= 0);
end;

function TEntity.KeyForIndex(const Index: Integer): String;
begin
  if Index < FKeyCount then
    Result := FKeys^[Index].Key
  else
    Result := '';
end;

function TEntity.Matrix3x3ForKey(const Key: String): TMatrix4f;
var
  s: String;
  i, j: Integer;
  t: Extended;
  m: TMatrix4f;
begin
  s := ValueForKey(Key);
  FParser.LoadFromString(s);

  mat_Identity(m);

  for i:=0 to 2 do
  for j:=0 to 2 do
  begin
    if not FParser.GetNextToken then Break;
    if TryStrToFloatGeneric(FParser.Token, t) then
      m[i, j] := t;
  end;

  Result := m;
end;

procedure TEntity.RemoveKey(const Key: String);
begin

end;

procedure TEntity.RemoveSurface(Surf: TSurface);
begin
  FSurfaces.Delete(FSurfaces.IndexOf(Surf));
  Surf.Free;
end;

procedure TEntity.SetBrush(Index: Integer; const Value: TBrush);
begin
  FBrushes.Items[Index] := Value;
end;

procedure TEntity.SetKeyCapacity(const Value: Integer);
begin
  if FKeyCapacity <> Value then
  begin
    FKeyCapacity := Value;
    ReallocMem(FKeys, FKeyCapacity * SizeOf(TEntityPair));
  end;
end;

procedure TEntity.SetKeyGrowSize(const Value: Integer);
begin
  FKeyGrowSize := Value;
  if FKeyGrowSize < 1 then
    FKeyGrowSize := 1
  else if FKeyGrowSize > 100 then
    FKeyGrowSize := 100;
end;

procedure TEntity.SetKeyValue(const Key, Value: String);
var idx: Integer;
begin
  idx := IndexForKey(Key);
  if idx < 0 then
    AddKey(Key, Value)
  else
    FKeys^[idx].Value := Value;
end;

procedure TEntity.SetSurface(Index: Integer; const Value: TSurface);
begin
  FSurfaces.Items[Index] := Value;
end;

function TEntity.ValueForIndex(const Index: Integer): String;
begin
  if Index < FKeyCount then
    Result := FKeys^[Index].Value
  else
    Result := '';
end;

function TEntity.ValueForKey(const Key: String): String;
var i: Integer;
begin
  Result := '';
  for i:=0 to FKeyCount-1 do
  begin
    if SameText(Key, FKeys^[i].Key) then
    begin
      Result := FKeys^[i].Value;
      Exit;
    end;
  end;
end;

function TEntity.VectorForKey(const Key: String): TVector3f;
var
  s: String;
  i: Integer;
  t: Extended;
  v: TVector3f;
begin
  s := ValueForKey(Key);
  FParser.LoadFromString(s);

  vec_clear(v);
  for i:=0 to 2 do
  begin
    if not FParser.GetNextToken then Break;
    if TryStrToFloatGeneric(FParser.Token, t) then
      v[i] := t;
  end;

  Result := v;
end;

{ TSurface }

function TSurface.AddElement(const Elem: Cardinal): Integer;
begin
  Result := FElementCount;
  SetLength(FElements, FElementCount + 1);
  FElements[FElementCount] := Elem;
  Inc(FElementCount);
end;

procedure TSurface.AddElement(iA, iB, iC: Cardinal);
begin
  SetLength(FElements, FElementCount + 3);
  FElements[FElementCount+0] := iA;
  FElements[FElementCount+1] := iB;
  FElements[FElementCount+2] := iC;
  Inc(FElementCount, 3);
end;

function TSurface.AddVertex(const Vert: TOBSPVertex): Integer;
begin
  Result := FVertexCount;
  SetLength(FVertices, FVertexCount + 1);
  FVertices[FVertexCount] := Vert;
  Inc(FVertexCount);

  aabb_addpoint(FAABB, Vert.Position); // add bounds also
end;

procedure TSurface.CalcBounds;
var i: Integer;
begin
  aabb_clear(FAABB);
  for i:=0 to FVertexCount-1 do
    aabb_addpoint(FAABB, FVertices[i].Position);
end;

procedure TSurface.Clear;
begin
  ClearElements;
  ClearVertices;
  DoClear;
end;

procedure TSurface.ClearElements;
begin
  FElements := nil;
  FElementCount := 0;
end;

procedure TSurface.ClearVertices;
begin
  FVertices := nil;
  FVertexCount := 0;
  aabb_clear(FAABB);
end;

constructor TSurface.Create(Owner: TEntity; MaterialName: String);
begin
  FOwnerEntity := Owner;
  Clear;
  FSurfaceType := stNone;
  FMaterialIndex := OwnerEntity.World.MaterialManager.AddMaterial(MaterialName);
end;

destructor TSurface.Destroy;
begin
  Clear;
  inherited;
end;

function TSurface.GetElement(Index: Integer): Cardinal;
begin
  Result := FElements[Index];
end;

function TSurface.GetElementsAsAddress: Pointer;
begin
  Result := FElements;
end;

function TSurface.GetMaterial: PMaterial;
begin
  Result := OwnerEntity.World.MaterialManager.Materials[FMaterialIndex];
end;

function TSurface.GetPolygon: TPolygon;
var
  poly: TPolygon;
  i: Integer;
begin
  poly := TPolygon.Create(FVertexCount);

  for i:=0 to FVertexCount-1 do
    poly.Points[i] := FVertices[i].Position;

  Result := poly;
end;

function TSurface.GetVertex(Index: Integer): POBSPVertex;
begin
  Result := @FVertices[Index];
end;

function TSurface.GetVerticesAsAddress: Pointer;
begin
  Result := FVertices;
end;

procedure TSurface.SetElement(Index: Integer; const Value: Cardinal);
begin
  FElements[Index] := Value;
end;

procedure TSurface.SetVertex(Index: Integer; const Value: POBSPVertex);
begin
  FVertices[Index] := Value^;
end;











(*
{ TSurface }

procedure TSurface.CreateFacetsFromPolygon;
var
  i, j: Integer;
  p1, p2: TVector3f;
  facet: PFacet;
begin
  if FVertexCount < 3 then
    Exit;

  FFacetCount := 1;
  SetLength(FFacetList, FFacetCount);
  facet := @FFacetList[0];
  facet.Plane := plane_frompoints(FVertices[0].Position,
                                  FVertices[1].Position,
                                  FVertices[2].Position);
  facet.EdgeCount := FVertexCount;
  SetLength(facet.Edges, facet.EdgeCount);

  for i:=0 to FVertexCount-1 do
  begin
    j := (i+1) mod FVertexCount;

    p1 := FVertices[i].Position;
    p2 := FVertices[j].Position;

    facet.Edges[i].A := i;
    facet.Edges[i].B := j;
    facet.Edges[i].Plane.Normal := vec_normalize(vec_cross(facet.Plane.Normal, vec_sub(p2, p1)));
    facet.Edges[i].Plane.Dist := -vec_dot(p1, facet.Edges[i].Plane.Normal);
  end;
end;

procedure TSurface.CreateFacetsFromTriangles;
var
  i: Integer;
  a, b, c: Integer;
  p1, p2, p3: TVector3f;
  facet: PFacet;
begin
  FFacetCount := FElementCount div 3;
  SetLength(FFacetList, FFacetCount);

  for i:=0 to FFacetCount-1 do
  begin
    facet := @FFacetList[i];

    a := FElements[i * 3 + 0];
    b := FElements[i * 3 + 1];
    c := FElements[i * 3 + 2];

    p1 := FVertices[a].Position;
    p2 := FVertices[b].Position;
    p3 := FVertices[c].Position;

    facet.Plane := plane_frompoints(p1, p2, p3);
    facet.EdgeCount := 3;
    SetLength(facet.Edges, facet.EdgeCount);
  // p1-p2 edge
    facet.Edges[0].A := a;
    facet.Edges[0].B := b;
    facet.Edges[0].Plane.Normal := vec_normalize(vec_cross(facet.Plane.Normal, vec_sub(p2, p1)));
    facet.Edges[0].Plane.Dist := -vec_dot(p1, facet.Edges[0].Plane.Normal);
  // p2-p3 edge
    facet.Edges[1].A := b;
    facet.Edges[1].B := c;
    facet.Edges[1].Plane.Normal := vec_normalize(vec_cross(facet.Plane.Normal, vec_sub(p3, p2)));
    facet.Edges[1].Plane.Dist := -vec_dot(p2, facet.Edges[1].Plane.Normal);
  // p3-p1 edge
    facet.Edges[2].A := c;
    facet.Edges[2].B := a;
    facet.Edges[2].Plane.Normal := vec_normalize(vec_cross(facet.Plane.Normal, vec_sub(p1, p3)));
    facet.Edges[2].Plane.Dist := -vec_dot(p3, facet.Edges[2].Plane.Normal);
  end;
end;

procedure TSurface.FreeQuery;
var i: Integer;
begin
  for i:=0 to FFacetCount-1 do
    FFacetList[i].Edges := nil;

  FFacetList := nil;
  FFacetCount := 0;
end;

function TSurface.GetPolygon: TPolygon;
var
  poly: TPolygon;
  i: Integer;
begin
  poly := TPolygon.Create(FVertexCount);

  for i:=0 to FVertexCount-1 do
    poly.Points[i] := FVertices[i].Position;

  Result := poly;
end;

procedure TSurface.InitQuery;
begin
  case FSurfaceType of
    stNone: Assert(False, 'Bad surface type');
    stPlanar: CreateFacetsFromPolygon;
    stTriangleMesh,
    stPatch: CreateFacetsFromTriangles;
  else
    Assert(False, 'Out of bound surface type');
  end;
end;

function TSurface.QueryInsidePoint(const P: TVector3f): Boolean;
var
  i, j: Integer;
  d: Single;
  facet: PFacet;
begin
  Result := False;

  Assert(FSurfaceType = stPlanar, 'QueryInsidePoint is only for planar surfaces');

// trace surface at facet level
  for i:=0 to FFacetCount-1 do
  begin
    facet := @FFacetList[i];

  // trace against facet plane first
    d := plane_evaluatepoint(facet.Plane, P);

    if Abs(d) > EPSILON_ON_SIDE then
      Continue;

  // trace for each edge
    for j:=0 to facet.EdgeCount-1 do
    begin
      if plane_evaluatepoint(facet.Edges[j].Plane, P) > EPSILON_ON_SIDE then
        Break;
    end;

  // completely inside? Then occluded
    if j = facet.EdgeCount then
    begin
      Result := True;
      Exit;
    end;
  end;
end;

function TSurface.QueryOcclusion(StartPoint, EndPoint: TVector3f): Boolean;
var
  i, j: Integer;
  impact: TVector3f;
  t, d1, d2: Single;
  facet: PFacet;
begin
  Result := False;
// trace surface at facet level
  for i:=0 to FFacetCount-1 do
  begin
    facet := @FFacetList[i];

  // trace against facet plane first
    d1 := plane_evaluatepoint(facet.Plane, StartPoint);
    if (-1 < d1) and (d1 < 1) then // don't intersect self
      Continue;

    d2 := plane_evaluatepoint(facet.Plane, EndPoint);
    if (-1 < d2) and (d2 < 1) then // don't intersect self
      Continue;

    if (d1 >= 1) and (d2 >= 1) then  // completely front side
      Continue;

    if (d1 <= -1) and (d2 <= -1) then // completely back side
      Continue;

    t := (d1 - EPSILON_ON_SIDE) / (d1 - d2);

    if t <= 0 then
      Continue;

  // calculate intersection point
    impact := vec_lerp(StartPoint, EndPoint, t);

  // trace for each edge
    for j:=0 to facet.EdgeCount-1 do
    begin
      if plane_evaluatepoint(facet.Edges[j].Plane, impact) > EPSILON_ON_SIDE then
        Break;
    end;

  // completely inside? Then occluded
    if j = facet.EdgeCount then
    begin
      Result := True;
      Exit;
    end;
  end;
end;

function TSurface.QueryTracing(StartPoint, EndPoint: TVector3f;
  const HitPoint: PVector3f; const Fraction: PSingle): Boolean;
var
  i: Integer;
  p1, p2, p3, impact, edge: TVector3f;
  t, d1, d2: Single;
  plane: TPlane;
begin
  Result := False;
// trace surface at triangle level
  for i:=0 to (FElementCount div 3)-1 do
  begin
    p1 := FVertices[FElements[i*3+0]].Position;
    p2 := FVertices[FElements[i*3+1]].Position;
    p3 := FVertices[FElements[i*3+2]].Position;
  // trace against triangle plane first
    plane := plane_frompoints(p1, p2, p3);
    d1 := plane_evaluatepoint(plane, StartPoint);
    if (-1 < d1) and (d1 < 1) then
      Continue;

    d2 := plane_evaluatepoint(plane, EndPoint);
    if (-1 < d2) and (d2 < 1) then
      Continue;

    t := (d1 - EPSILON_ON_SIDE) / (d1 - d2);

    if t <= 0 then
      Continue;

  // hit something earlier?
    if t >= Fraction^ then
      Continue;

    impact := vec_lerp(StartPoint, EndPoint, t);

  // check for p1-p2 edge
    edge := vec_normalize(vec_cross(plane.Normal, vec_sub(p2, p1)));

    if vec_dot(impact, edge) > (vec_dot(p1, edge) + EPSILON_ON_SIDE) then
      Continue;

  // check for p2-p3 edge
    edge := vec_normalize(vec_cross(plane.Normal, vec_sub(p3, p2)));

    if vec_dot(impact, edge) > (vec_dot(p2, edge) + EPSILON_ON_SIDE) then
      Continue;

  // check for p3-p1 edge
    edge := vec_normalize(vec_cross(plane.Normal, vec_sub(p1, p3)));

    if vec_dot(impact, edge) > (vec_dot(p3, edge) + EPSILON_ON_SIDE) then
      Continue;

    Fraction^ := t;
    HitPoint^ := impact;
    Result := True;
  end;
end;

procedure TSurface.SetElement(Index: Integer; const Value: Cardinal);
begin
  FElements[Index] := Value;
end;

procedure TSurface.SetVertex(Index: Integer; const Value: POBSPVertex);
begin
  FVertices[Index] := Value^;
end;

function TSurface.ClosestPointOnEdges(const From: TVector3f): TVector3f;
var 
  p: TVector3f;
  i: Integer;
  nearest: TVector3f;
  d, minDist: Single;
begin
  minDist := MAX_WORLD_COORD;
  nearest := vec_add(From, vec_make(MAX_WORLD_COORD, MAX_WORLD_COORD, MAX_WORLD_COORD));

  if FElementCount > 0 then // Triangulated?
  begin
    for i:=0 to FElementCount-1 do
    begin
      p := vec_closestpointonedge(From,
                                  FVertices[FElements[i]].Position,
				  FVertices[FElements[(i+1) mod FElementCount]].Position);
      d := vec_dist(From, p);

      if d < minDist then
      begin
        minDist := d;
        nearest := p;
      end;
    end;
  end
  else
  begin
    for i:=0 to FVertexCount-1 do
    begin
      p := vec_closestpointonedge(From,
                                  FVertices[i].Position,
				  FVertices[(i+1) mod FVertexCount].Position);
      d := vec_dist(From, p);

      if d < minDist then
      begin
        minDist := d;
        nearest := p;
      end;
    end;
  end;

  Result := p;
end;

*)

{ TBrushSide }

function TBrushSide.AddSurface(Surf: TSurface): Integer;
begin
  Result := FSurfaceList.Add(Surf);
end;

procedure TBrushSide.BuildBasePolygon;
var
  i: Integer;
  b, t: TVector3f;
begin
  ClearSurfaces;

  vec_tangentspace(FNormal, t, b);
  b := vec_scale(b, 2 * MAX_WORLD_COORD);
  t := vec_scale(t, 2 * MAX_WORLD_COORD);

  FBasePolygon.AddPoint(vec_add(vec_add(FOrigin, t), b));
  FBasePolygon.AddPoint(vec_add(vec_sub(FOrigin, t), b));
  FBasePolygon.AddPoint(vec_sub(vec_sub(FOrigin, t), b));
  FBasePolygon.AddPoint(vec_sub(vec_add(FOrigin, t), b));

  for i:=0 to FOwner.SideCount-1 do
  begin
    if FOwner.Sides[i] = Self then Continue;

    FBasePolygon.Clip(FOwner.Sides[i].Plane, EPSILON_ZERO);
  end;

  FOrigin := FBasePolygon.GetMassCenter;
end;

function TBrushSide.BuildSurfaceForPolygon(const Poly: TPolygon): TSurface;
const
  SNAP_FACTOR_INT   = 8;
  SNAP_FACTOR_FLOAT = 1 / SNAP_FACTOR_INT;
var
  i, j: Integer;
  surf: TPlanarSurface;
  vert: TOBSPVertex;
  p1, p2, p3, a, b: TVector3f;
  texmin: TVector2f;
  aabb: TAABB;
begin
  Result := nil;

  if Poly.Count < 3 then
    Exit;

  surf := TPlanarSurface.Create(Owner.Owner, Material.MaterialName);
  surf.Side := Self;
  FSurfaceList.Add(surf); // add reference to brush sides list
  Owner.Owner.AddSurface(surf); // add real-pointer to entity
  aabb_clear(aabb);
  texmin := vec_make(99999, 99999);
  // remove all colinear points and create a surface from the polygon
  for i:=0 to Poly.Count-1 do
  begin
    p1 := Poly.Points[i];
    p2 := Poly.Points[(i+1) mod Poly.Count];
    p3 := Poly.Points[(i+Poly.Count-1) mod Poly.Count];
    vec_normalizesafe(vec_sub(p2, p1), a);
    vec_normalizesafe(vec_sub(p1, p3), b);
    if vec_dot(a, b) < 0.999 then
    begin
      FillChar(vert, SizeOf(vert), 0);

      for j:=0 to 2 do
        vert.Position[j] :=
          SNAP_FACTOR_FLOAT * Floor(p1[j] * SNAP_FACTOR_INT + 0.5);

      vert.Tangent := FTangent;
      vert.Binormal := FBinormal;
      vert.Normal := FNormal;
      vert.TexCoord := vec_transform_st(vert.Position, FTexMatrix);

      texmin[0] := MinFloat(texmin[0], vert.TexCoord[0]);
      texmin[1] := MinFloat(texmin[1], vert.TexCoord[1]);

      aabb_addpoint(aabb, vert.Position);

      surf.AddVertex(vert);
    end;
  end;

  surf.AABB := aabb;

// bias the surface's texture coordinates as close to 0 as possible
  if not surf.Material.GlobalTexture then
  begin
    texmin[0] := Floor(texmin[0]);
    texmin[1] := Floor(texmin[1]);

    for i:=0 to surf.VertexCount-1 do
      surf.Vertices[i].TexCoord := vec_sub(surf.Vertices[i].TexCoord, texmin);
  end;

  Result := surf;
end;

procedure TBrushSide.ClearSurfaces;
begin
  FSurfaceList.Clear;
end;

constructor TBrushSide.Create(AOwner: TBrush;
                              Plane: TPlane;
                              MaterialName: String;
                              TexMatrix: TMatrix4f);
var p: TPlane;
begin
  FOwner := AOwner;
  FMaterialIndex := World.MaterialManager.AddMaterial(MaterialName);
  FVisible := True;
  FPlaneIndex := World.AddPlane(Plane);
  p := World.Planes[FPlaneIndex];
  FNormal := p.Normal;
  FOrigin := vec_scale(p.Normal, -p.Dist);

  FTexMatrix := TexMatrix;

  FTangent := vec_normalize(vec_make(FTexMatrix[0,0], FTexMatrix[1,0], FTexMatrix[2,0]));
  FBinormal := vec_normalize(vec_make(FTexMatrix[0,1], FTexMatrix[1,1], FTexMatrix[2,1]));
  FNormal := vec_normalize(vec_make(FTexMatrix[0,2], FTexMatrix[1,2], FTexMatrix[2,2]));

  FSurfaceList := TList.Create;

  FBasePolygon := TPolygon.Create(0);
  FVisiblePolygon := TPolygon.Create(0);
end;

destructor TBrushSide.Destroy;
begin
  ClearSurfaces;

  FBasePolygon.Free;
  FVisiblePolygon.Free;
  FOwner := nil;
  inherited;
end;

function TBrushSide.GetMaterial: PMaterial;
begin
  Result := World.MaterialManager.Materials[FMaterialIndex];
end;

function TBrushSide.GetPlane: TPlane;
begin
  Result := World.Planes[FPlaneIndex];
end;

function TBrushSide.GetSurface(Index: Integer): TSurface;
begin
  Result := TSurface(FSurfaceList.Items[Index]);
end;

function TBrushSide.GetSurfaceCount: Integer;
begin
  Result := FSurfaceList.Count;
end;

function TBrushSide.GetSurfaceIndex(const Surface: TSurface): Integer;
begin
  Result := FSurfaceList.IndexOf(Surface);
end;

function TBrushSide.GetWorld: TWorld;
begin
  Result := FOwner.World;
end;

procedure TBrushSide.RemoveSurface(Surf: TSurface);
begin
// free original surface and delete from entity list
  Owner.Owner.RemoveSurface(Surf);
// remove reference from brush side surface list  
  FSurfaceList.Delete(FSurfaceList.IndexOf(Surf));
end;

procedure TBrushSide.SetPlaneIndex(const Value: Integer);
begin
  FPlaneIndex := Value;
end;

procedure TBrushSide.SetSurface(Index: Integer; const Value: TSurface);
begin
  FSurfaceList.Items[Index] := Value;
end;

{ TBrush }

function TBrush.AddSide(const Plane: TPlane;
                        const Material: String;
                        const TexMatrix: TMatrix4f): TBrushSide;
begin
  Result := TBrushSide.Create(Self, Plane, Material, TexMatrix);
  FBrushSides.Add(Result);
end;

function TBrush.AddSide(const p1, p2, p3: TVector3f;
                        const Material: String;
                        const TexMatrix: TMatrix4f): TBrushSide;
begin
  Result := AddSide(plane_frompoints(p1, p2, p3), Material, TexMatrix);
end;

procedure TBrush.AddSideToList(const Side: TBrushSide);
begin
  FBrushSides.Add(Side);
end;

function TBrush.BuildBasePolygons: Boolean;
var 
  i: Integer;
  bbox: TAABB;
begin
  Result := False;
  aabb_clear(FAABB);

  for i:=0 to SideCount-1 do
  begin
    Sides[i].BuildBasePolygon;

    bbox := Sides[i].BasePolygon.GetAABB;
    aabb_addpoint(FAABB, bbox.Mins);
    aabb_addpoint(FAABB, bbox.Maxs);
  end;

  for i:=0 to 2 do
  begin
    if (FAABB.Maxs[i] > MAX_WORLD_COORD) or
       (FAABB.Mins[i] < MIN_WORLD_COORD) or
       (FAABB.Mins[i] >= FAABB.Maxs[i]) then
    Exit;
  end;

  Result := True;
end;

constructor TBrush.Create(AOwner: TEntity);
begin
  FBrushSides := TList.Create;

  FOwner := AOwner;
  FOpaque := True; // default value
end;

function TBrush.CreateCopy: TBrush;
var
  brush: TBrush;
  srcside, side: TBrushSide;
  i: Integer;
begin
// leave nil. So, we can skip adding to list
  brush := TBrush.Create(FOwner);
  for i:=0 to Self.SideCount-1 do
  begin
    srcside := Self.Sides[i];
    side := Brush.AddSide(srcside.Plane, srcside.Material.MaterialName, srcside.TextureMatrix);
    side.FBasePolygon.Assign(srcside.BasePolygon);
  end;

  brush.FOutputIndex := Self.OutputIndex;           
  brush.FOpaque := Self.Opaque;
  Result := brush;
end;

destructor TBrush.Destroy;
begin
  while FBrushSides.Count > 0 do
  begin
    TBrushSide(FBrushSides.Items[0]).Free;
    FBrushSides.Delete(0);
  end;

  FBrushSides.Free;
  FOwner := nil;
  inherited;
end;

function TBrush.GetSide(Index: Integer): TBrushSide;
begin
  Result := TBrushSide(FBrushSides.Items[Index]);
end;

function TBrush.GetSideCount: Integer;
begin
  Result := FBrushSides.Count;
end;

function TBrush.GetVolume: Single;
var
  i: Integer;
  corner: PVector3f;
  poly: TPolygon;
  volume, d: Single;
begin
  corner := nil;
  volume := 0;

  for i:=0 to SideCount-1 do
  begin
    if not Assigned(Sides[i].BasePolygon) then Continue;

    poly := Sides[i].BasePolygon;

    if not Assigned(corner) then
      corner := poly.GetPointAsAddress(0);

    d := plane_evaluatepoint(Sides[i].Plane, corner^);
    volume := volume + (poly.GetArea * d);
  end;

  Result := volume / 3;
end;

function TBrush.GetWorld: TWorld;
begin
  if Assigned(FOwner) then
    Result := FOwner.World
  else
    Result := nil;
end;

function TBrush.MostlyOnSide(Plane: TPlane): TSideClassify;
var
  max, d: Single;
  i, j: Integer;
  poly: TPolygon;
  side: TSideClassify;
begin
  side := scOn;
  max := 0;

  for i:=0 to SideCount-1 do
  begin
    poly := Sides[i].BasePolygon;
    if not Assigned(poly) then Continue;

    for j:=0 to poly.Count-1 do
    begin
      d := plane_evaluatepoint(Plane, poly.Points[j]);
      if (d > max) then
      begin
        max := d;
        side := scFront;
      end;

      if (-d > max) then
      begin
        max := -d;
        side := scBack;
      end;
    end;
  end;

  Result := side;
end;

procedure TBrush.SetSide(Index: Integer; const Value: TBrushSide);
begin
  FBrushSides.Items[Index] := Value;
end;

procedure TBrush.Split(Plane: TPlane; out Front, Back: TBrush);
var
  poly, frontpoly, backpoly: TPolygon;
  baseside, side: TBrushSide;
  d, front_dist, back_dist: Single;
  i, j: Integer;
begin
  Front := nil;
  Back := nil;

  front_dist := 0;
  back_dist := 0;

  for i:=0 to SideCount-1 do
  begin
    poly := Sides[i].BasePolygon;
    if not Assigned(poly) then
      Continue;

    for j:=0 to poly.Count-1 do
    begin
      d := plane_evaluatepoint(Plane, poly.Points[j]);

      if (d > 0) and (d > front_dist) then
        front_dist := d;

      if (d < 0) and (d < back_dist) then
        back_dist := d;
    end;
  end;

  if (front_dist < EPSILON_ON_SIDE) then // completely back side
  begin
    Back := Self.CreateCopy;
    Exit;
  end;

  if (back_dist > -EPSILON_ON_SIDE) then // completely front side
  begin
    Front := Self.CreateCopy;
    Exit;
  end;

  poly := TPolygon.Create(0);
  poly.GeneratePointsFromPlane(Plane);
  for i:=0 to SideCount-1 do
    poly.Clip(World.Planes[Sides[i].PlaneIndex xor 1], 0);

  if poly.IsTiny then
  begin
    case MostlyOnSide(Plane) of
      scFront: Front := CreateCopy;
      scBack : Back := CreateCopy;
    end;

    Exit;
  end;

  Front := TBrush.Create(FOwner);
  Back := TBrush.Create(FOwner);

  for i:=0 to SideCount-1 do
  begin
    baseside := Sides[i];
    if not Assigned(baseside.BasePolygon) then Continue;

    baseside.BasePolygon.Split(Plane, 0, frontpoly, backpoly);

    if Assigned(frontpoly) then
    begin
      side := Front.AddSide(baseside.Plane, baseside.Material.MaterialName, baseside.TextureMatrix);
      side.BasePolygon.Assign(frontpoly);
    end;

    if Assigned(backpoly) then
    begin
      side := Back.AddSide(baseside.Plane, baseside.Material.MaterialName, baseside.TextureMatrix);
      side.BasePolygon.Assign(backpoly);
    end;
  end;

  if Front.SideCount < 3 then
  begin
    Front.Free;
    Front := nil;
  end
  else
  begin
    baseside := Sides[0];
    side := Front.AddSide(Plane, baseside.Material.MaterialName, baseside.TextureMatrix);
    side.BasePolygon.Assign(poly);

    if Front.GetVolume < 1.0 then
    begin
      Front.Free;
      Front := nil;
    end;
  end;

  if Back.SideCount < 3 then
  begin
    Back.Free;
    Back := nil;
  end
  else
  begin
    baseside := Sides[0];
    side := Back.AddSide(plane_negate(Plane), baseside.Material.MaterialName, baseside.TextureMatrix);
    side.BasePolygon.Assign(poly);
    side.BasePolygon.Reserve;

    if Back.GetVolume < 1.0 then
    begin
      Back.Free;
      Back := nil;
    end;
  end;
end;

{ TBSPReference }

constructor TBSPReference.Create(AWorld: TWorld;
                                 Source: TPolygon;
                                 APlaneIndex: Integer);
begin
  FPolygon := TPolygon.Create(0);
  FPolygon.Assign(Source);
  FWorld := AWorld;
  FPlaneIndex := APlaneIndex;
end;

destructor TBSPReference.Destroy;
begin
  FPolygon.Free;
  inherited;
end;

function TBSPReference.GetPlane: TPlane;
begin
  Result := World.Planes[FPlaneIndex];
end;

{ TBSPReferenceList }

procedure TBSPReferenceList.Add(Ref: TBSPReference);
begin
  FList.Add(Ref);
end;

procedure TBSPReferenceList.Clear;
begin
{  while FList.Count > 0 do
  begin
    TBSPReference(FList.Items[0]).Free;
    FList.Delete(0);
  end;
}
  FList.Clear;
end;

constructor TBSPReferenceList.Create;
begin
  FList := TList.Create;
end;

procedure TBSPReferenceList.Delete(Ref: TBSPReference);
var idx: Integer;
begin
  idx := IndexOf(Ref);
  if idx >= 0 then
    FList.Delete(idx);

  if Assigned(ref) then
    ref.Free;
end;

destructor TBSPReferenceList.Destroy;
begin
  Clear;
  FList.Free;
  inherited;
end;

function TBSPReferenceList.GetCount: Integer;
begin
  Result := FList.Count;
end;

function TBSPReferenceList.GetReferences(Index: Integer): TBSPReference;
begin
  Result := TBSPReference(FList.Items[Index]);
end;

function TBSPReferenceList.IndexOf(Ref: TBSPReference): Integer;
begin
  Result := FList.IndexOf(Ref);
end;

procedure TBSPReferenceList.SetReferences(Index: Integer;
  const Value: TBSPReference);
begin
  FList.Items[Index] := Value;
end;

procedure TBSPReferenceList.UnCheckAll;
var i: Integer;
begin
  for i:=0 to FList.Count-1 do
    TBSPReference(FList.Items[i]).Checked := False;
end;

{ TBSPNode }

function TBSPNode.AddBrush(Brush: TBrush): Integer;
begin
  Result := FBrushList.Add(Brush);
end;

function TBSPNode.AddSurface(Surf: TSurface): Integer;
begin
  Result := FSurfaceList.Add(Surf);
end;

procedure TBSPNode.BuildNode;
var
  i: Integer;
  front, back: TPolygon;
  ref, newref: TBSPReference;
  frontlist, backlist: TBSPReferenceList;
  splitter: TPlane;
begin
  if not SelectSplitter(FPlaneIndex) then Exit;

  splitter := World.Planes[FPlaneIndex];
  frontlist := TBSPReferenceList.Create;
  backlist := TBSPReferenceList.Create;

  for i:=FReferenceList.Count-1 downto 0 do
  begin
    ref := FReferenceList.References[i];

    if ref.PlaneIndex = Self.PlaneIndex then
    begin
      FReferenceList.Delete(ref);
      Continue;
    end;

    case ref.Polygon.Classify(splitter, EPSILON_ON_SIDE) of
      scCross: begin
                 ref.Polygon.Split(splitter, 2 * EPSILON_ON_SIDE, front, back);

                 if Assigned(front) then
                 begin
                   newref := TBSPReference.Create(World, front, ref.PlaneIndex);
                   frontlist.Add(newref);
                   front.Free;
                   front := nil;
                 end;

                 if Assigned(back) then
                 begin
                   newref := TBSPReference.Create(World, back, ref.PlaneIndex);
                   backlist.Add(newref);
                   back.Free;
                   back := nil;
                 end;

                 FReferenceList.Delete(ref);
               end;
      scFront: frontlist.Add(ref);
      scBack:  backlist.Add(ref);
    end;
  end;

//  FReferenceList.Clear;

  FFrontChild := TBSPNode.Create(FWorld, Self, frontlist);
  FBackChild := TBSPNode.Create(FWorld, Self, backlist);

  FFrontChild.FAABB := FAABB;
  FBackChild.FAABB := FAABB;

  for i:=0 to 2 do
  begin
    if splitter.Normal[i] = 1 then
    begin
      FFrontChild.FAABB.Mins[i] := -splitter.Dist;
      FBackChild.FAABB.Maxs[i] := -splitter.Dist;
      Break;
    end;
  end;

  FFrontChild.BuildNode;
  FBackChild.BuildNode;
end;

constructor TBSPNode.Create(AWorld: TWorld;
                            AOwner: TBSPNode;
                            RefList: TBSPReferenceList);
var
  poly: TPolygon;
  i, j: Integer;
begin
  FWorld := AWorld;
  FOwner := AOwner;
  FOpaque := False;
  FReferenceList := RefList;
  FBrushList := TList.Create;
  FSurfaceList := TList.Create;
  FFrontChild := nil;
  FBackChild := nil;

  if not Assigned(FOwner) then
  begin
    aabb_clear(FAABB);
    for i:=0 to FReferenceList.Count-1 do
    begin
      poly := FReferenceList.References[i].Polygon;
      for j:=0 to poly.Count-1 do
        aabb_addpoint(FAABB, poly.Points[j]);
    end;
  end;
end;

destructor TBSPNode.Destroy;
begin
  FSurfaceList.Free;
  FBrushList.Free;
  FFrontChild.Free;
  FBackChild.Free;
  FOwner := nil;
  inherited;
end;

function TBSPNode.GetBrush(Index: Integer): TBrush;
begin
  Result := TBrush(FBrushList.Items[Index]);
end;

function TBSPNode.GetBrushCount: Integer;
begin
  Result := FBrushList.Count;
end;

function TBSPNode.GetIsLeaf: Boolean;
begin
  Result := (FFrontChild = nil) and
            (FBackChild = nil);
end;

function TBSPNode.GetPlane: TPlane;
begin
  Assert(not IsLeaf, 'At leafs splitter plane is always invalid');
  Result := World.Planes[FPlaneIndex];
end;

function TBSPNode.GetSurface(Index: Integer): TSurface;
begin
  Result := TSurface(FSurfaceList.Items[Index]);
end;

function TBSPNode.GetSurfaceCount: Integer;
begin
  Result := FSurfaceList.Count;
end;

function TBSPNode.IndexOfBrush(Brush: TBrush): Integer;
begin
  Result := FBrushList.IndexOf(Brush);
end;

function TBSPNode.IndexOfSurface(Surf: TSurface): Integer;
begin
  Result := FSurfaceList.IndexOf(Surf);
end;

function TBSPNode.LeafForPoint(Point: TVector3f): TBSPNode;
var d: Single;
begin
  if Self.IsLeaf then
  begin
    Result := Self;
    Exit;
  end;

  d := plane_evaluatepoint(Plane, Point);

  if (d >= 0) then
    Result := FrontChild.LeafForPoint(Point)
  else
    Result := BackChild.LeafForPoint(Point);
end;

function TBSPNode.SelectSplitter(out Splitter: Integer): Boolean;
const
  INITIAL_SCORE = -99999;

var
  i, j: Integer;
  score, bestscore: Integer;
  ref1, ref2: TBSPReference;
  classify: array[TSideClassify] of Integer;
  p: TPlane;
  dist: Single;
begin
  if FReferenceList.Count = 0 then
  begin
    Result := False;
    Exit;
  end;

  for i:=0 to 2 do
  begin
    if World.BlockSize[i] <= 0 then Continue;

    dist := World.BlockSize[i] * (Floor(FAABB.Mins[i] / World.BlockSize[i]) + 1);

    if FAABB.Maxs[i] > dist then
    begin
      vec_clear(p.Normal);
      p.Normal[i] := 1;
      p.Dist := -dist;
      Splitter := World.AddPlane(p);
      Result := True;
      Exit;
    end;
  end;

  bestscore := INITIAL_SCORE;

  FReferenceList.UnCheckAll;

  for i:=0 to FReferenceList.Count-1 do
  begin
    ref1 := FReferenceList.References[i];
    if ref1.Checked then
      Continue;

    FillChar(classify, SizeOf(classify), 0);

    for j:=0 to FReferenceList.Count-1 do
    begin
      ref2 := FReferenceList.References[j];

      if ref1.PlaneIndex = ref2.PlaneIndex then
      begin
        Inc(classify[scOn]);
        ref2.Checked := True;
        Continue;
      end;

      Inc(classify[ref2.Polygon.Classify(ref1.Plane, EPSILON_ON_SIDE)]);

      score := classify[scOn] - classify[scCross];

      if score > bestscore then
      begin
        bestscore := score;
        Splitter := ref1.PlaneIndex;
      end;
    end;
  end;

  Result := (bestscore <> INITIAL_SCORE);
end;

procedure TBSPNode.SetBrush(Index: Integer; const Value: TBrush);
begin
  FBrushList.Items[Index] := Value;
end;

procedure TBSPNode.SetSurface(Index: Integer; const Value: TSurface);
begin
  FSurfaceList.Items[Index] := Value;
end;

end.
