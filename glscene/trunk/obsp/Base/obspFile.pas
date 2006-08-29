//
//  Project     : OpenBSP Map Compiler
//  Unit        : obspFile.pas
//  Description : File types of OpenBSP
//  History     :
//    05/11/04 - OT - Added TLightGridPoint
//    29/10/04 - OT - Added LUMP_LIGHTARRAY for indexing LUMP_LIGHTGRID
//    19/10/04 - OT - 3th element of texture coordinates removed from TOBSPVertex
//                    LightmapIndex type converted to Integer from Cardinal
//                    LightmapScaling changed to LightmapVector because there 
//                      is no lightmap stretching anymore
//    07/10/04 - OT - Tangent and Binormal vectors removed from TOBSPPlane
//    17/06/04 - OT - Creation
//
unit obspFile;

interface

uses obspBaseTypes;

const
  OBSP_IDENTITY = //OBSP
    (Ord('O') or (Ord('B') shl 8) or (Ord('S') shl 16) or (Ord('P') shl 24));
  OBSP_VERSION = 1;

  LUMP_ENTITIES         = 0;
  LUMP_MODELS           = 1;
  LUMP_MATERIALS        = 2;
  LUMP_PLANES           = 3;
  LUMP_NODES            = 4;
  LUMP_LEAFS            = 5;
  LUMP_LBRUSHES         = 6;
  LUMP_LSURFACES        = 7;
  LUMP_BRUSHES          = 8;
  LUMP_BRUSHSIDES       = 9;
  LUMP_SURFACES         = 10;
  LUMP_ELEMENTS         = 11;
  LUMP_VERTICES         = 12;
  LUMP_FOGVOLUMES       = 13;
  LUMP_LIGHTMAPS        = 14;
  LUMP_LIGHTARRAY       = 15;
  LUMP_LIGHTGRID        = 16;
  LUMP_PVS              = 17;
  LUMP_PHS              = 18;

  MAX_OBSP_LUMP         = 19;

  SURF_TYPE_BAD         = 0;
  SURF_TYPE_PLANAR      = 1;
  SURF_TYPE_MESH        = 2;
  SURF_TYPE_PATCH       = 3;

type
  TOBSPLump = packed record
    Offset: Cardinal;                   // offset in file
    Length: Cardinal;                   // length of lump
  end;

  TOBSPHeader = packed record
    Identity: Cardinal;                 // must equal OBSP_IDENTITY
    Version: Cardinal;                  // must equal OBSP_VERSION
    Lumps: array[0..MAX_OBSP_LUMP-1] of TOBSPLump;
  end;

  POBSPPlane = ^TOBSPPlane;
  TOBSPPlane = packed record            // plane defination as "ax + by + cz + d = 0"
    Normal: TVector3f;
    Dist: Single;
  end;

  POBSPNode = ^TOBSPNode;
  TOBSPNode = packed record
    PlaneIndex: Cardinal;
    FrontChild: Integer;
    BackChild: Integer;
    Mins, Maxs: TVector3i;
  end;

  TOBSPLeaf = packed record
    Cluster: Integer;
    Area: Integer;
    FirstBrush, NumBrushes: Cardinal;
    FirstSurface, NumSurfaces: Cardinal;
    Mins, Maxs: TVector3i;
  end;

  POBSPVertex = ^TOBSPVertex;
  TOBSPVertex = packed record
    Position: TVector3f;                // vertex position
    TexCoord: TVector2f;                // 2D texture coordinate
    LM_TexCoord: TVector2f;             // lightmap coordinate
    Tangent: TVector3f;                 // tangent vector
    Binormal: TVector3f;                // binormal vector
    Normal: TVector3f;                  // normal vector
    Color: TVector4b;                   // color (RGBA)
  end;

  TOBSPSurface = packed record
    SurfaceType: Byte;                  // 0-bad 1-planar 2-triangle mesh 3-patch
    MaterialIndex: Cardinal;            // points LUMP_MATERIALS
    FogIndex: Integer;                  // points LUMP_FOGVOLUMES (-1 = none)
    LightmapIndex: Integer;             // points LUMP_LIGHTMAPS (-1 = nolightmap)
    LightmapOrigin: TVector3f;          // lightmap origin
    LightmapVector: TVector2f;          // lightmap S and T vectors
    LightmapRect: TRecti;               // lightmap pixel coordinates in lightmap
    FirstElement, NumElements: Cardinal;// element pointers
    FirstVertex, NumVertices: Cardinal; // vertex pointers
    PatchSize: array[0..1] of Integer;  // valid for patches
    Mins, Maxs: TVector3i;
  end;

  TOBSPBrushSide = packed record
    PlaneIndex: Cardinal;               // points LUMP_PLANES
    MaterialIndex: Cardinal;            // points LUMP_MATERIALS
    FirstSurface, NumSurfaces: Cardinal;// points LUMP_SURFACES
  end;

  TOBSPBrush = packed record
    FirstSide, NumSides: Cardinal;      // brush side pointers
  end;

  TOBSPFogVolume = packed record
    MaterialIndex: Cardinal;
    BrushIndex: Cardinal;
  end;

  TLightGridPoint = packed record
    Ambient: TVector3b;
    Directed: TVector3b;
    LatLong: TPackedNormal;
  end;

implementation

end.
