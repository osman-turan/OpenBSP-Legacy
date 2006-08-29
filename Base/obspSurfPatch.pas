//
//  Project     : OpenBSP Map Compiler
//  Unit        : obspSurfPatch.pas
//  Description : Includes patch surface class
//  History:
//    27/11/04 - OT - Creation
//
unit obspSurfPatch;

interface

uses obspBaseTypes, obspFile, obspMapClasses, obspMath;

type
  TPatchSurface = class(TSurface)
  private
    FControlPoints: array of TOBSPVertex;
    FControlPointCount: Integer;
    FPatchWidth: Integer;
    FPatchHeight: Integer;
    FLightmapIndex: Integer;
    FLightmapOffsetY: Integer;
    FLightmapOffsetX: Integer;
    FLightmapHeight: Integer;
    FLightmapWidth: Integer;
    function GetControlPoint(Index: Integer): POBSPVertex;
    procedure SetControlPoint(Index: Integer; const Value: POBSPVertex);
  protected
    procedure DoClear; override;
  public
    constructor Create(Owner: TEntity; MaterialName: String); override;

    procedure AddControlPoint(Position: TVector3f; TexCoord: TVector2f);
    function GetControlPointsAsAddress: Pointer;

    property LightmapIndex: Integer read FLightmapIndex write FLightmapIndex;
    property LightmapOffsetX: Integer read FLightmapOffsetX write FLightmapOffsetX;
    property LightmapOffsetY: Integer read FLightmapOffsetY write FLightmapOffsetY;
    property LightmapWidth: Integer read FLightmapWidth write FLightmapWidth;
    property LightmapHeight: Integer read FLightmapHeight write FLightmapHeight;

    property ControlPoints[Index: Integer]: POBSPVertex read GetControlPoint write SetControlPoint;
    property ControlPointCount: Integer read FControlPointCount;
    property PatchWidth: Integer read FPatchWidth write FPatchWidth;
    property PatchHeight: Integer read FPatchHeight write FPatchHeight;
  end;

implementation

{ TPatchSurface }

procedure TPatchSurface.AddControlPoint(Position: TVector3f; TexCoord: TVector2f);
var vert: POBSPVertex;
begin
  SetLength(FControlPoints, FControlPointCount+1);
  vert := @FControlPoints[FControlPointCount];

  FillChar(vert^, SizeOf(TOBSPVerteX), 0);
  vert.Position := Position;
  vert.TexCoord := TexCoord;

  Inc(FControlPointCount);
end;

constructor TPatchSurface.Create(Owner: TEntity; MaterialName: String);
begin
  inherited;

  FSurfaceType := stPatch;
end;

procedure TPatchSurface.DoClear;
begin
  FLightmapHeight := 0;
  FLightmapOffsetY := 0;
  FLightmapWidth := 0;
  FLightmapOffsetX := 0;
  FLightmapIndex := -1;

  FPatchWidth := 0;
  FPatchHeight := 0;
  FControlPoints := nil;
  FControlPointCount := 0;
end;

function TPatchSurface.GetControlPoint(Index: Integer): POBSPVertex;
begin
  Result := @FControlPoints[Index];
end;

function TPatchSurface.GetControlPointsAsAddress: Pointer;
begin
  Result := FControlPoints;
end;

procedure TPatchSurface.SetControlPoint(Index: Integer; const Value: POBSPVertex);
begin
  FControlPoints[Index] := Value^;
end;

end.
