//
//  Project     : OpenBSP Map Compiler
//  Unit        : obspSurfPlanar.pas
//  Description : Includes planar surface class
//  History:
//    27/11/04 - OT - Creation
//
unit obspSurfPlanar;

interface

uses obspBaseTypes, obspMath, obspMapClasses;

type
  TPlanarSurface = class(TSurface)
  private
    FLightmapHeight: Integer;
    FLightmapOffsetY: Integer;
    FLightmapWidth: Integer;
    FLightmapOffsetX: Integer;
    FLightmapOrigin: TVector3f;
    FLightmapVectorS: Single;
    FLightmapVectorT: Single;
    FLightmapIndex: Integer;
    FSide: TBrushSide;
  protected
    procedure DoClear; override;
    procedure TriangulateAsFan;
    function TriangulateAsStrip: Boolean;
  public
    constructor Create(Owner: TEntity; MaterialName: String); override;

    procedure Triangulate;

    property LightmapIndex: Integer read FLightmapIndex write FLightmapIndex;
    property LightmapOrigin: TVector3f read FLightmapOrigin write FLightmapOrigin;
    property LightmapOffsetX: Integer read FLightmapOffsetX write FLightmapOffsetX;
    property LightmapOffsetY: Integer read FLightmapOffsetY write FLightmapOffsetY;
    property LightmapVectorS: Single read FLightmapVectorS write FLightmapVectorS;
    property LightmapVectorT: Single read FLightmapVectorT write FLightmapVectorT;
    property LightmapWidth: Integer read FLightmapWidth write FLightmapWidth;
    property LightmapHeight: Integer read FLightmapHeight write FLightmapHeight;

    property Side: TBrushSide read FSide write FSide;
  end;

implementation

uses obspFile;

{ TPlanarSurface }

constructor TPlanarSurface.Create(Owner: TEntity; MaterialName: String);
begin
  inherited;

  FSurfaceType := stPlanar;
end;

procedure TPlanarSurface.DoClear;
begin
  FLightmapHeight := 0;
  FLightmapOffsetY := 0;
  FLightmapWidth := 0;
  FLightmapOffsetX := 0;
  vec_clear(FLightmapOrigin);
  FLightmapVectorS := 0;
  FLightmapVectorT := 0;
  FLightmapIndex := -1;
  FSide := nil;
end;

procedure TPlanarSurface.Triangulate;
begin
  if not TriangulateAsStrip then
    TriangulateAsFan;
end;

procedure TPlanarSurface.TriangulateAsFan;
var
  midpoint: TOBSPVertex;
  i: Integer;
  t: Extended;
  sumPos: TVector3x;
  sumTexCoord: TVector2x;
  sumLMTexCoord: TVector2x;
  sumTangent: TVector3x;
  sumBinormal: TVector3x;
  sumNormal: TVector3x;
  sumColor: TVector4i;
begin
  FElements := nil;
  FElementCount := 0;

  if FVertexCount < 3 then
    Exit;

  vec_clear(sumPos);
  vec_clear(sumTexCoord);
  vec_clear(sumLMTexCoord);
  vec_clear(sumTangent);
  vec_clear(sumBinormal);
  vec_clear(sumNormal);
  vec_clear(sumColor);

  for i:=0 to FVertexCount-1 do
  begin
    sumPos        := vec_add(sumPos, FVertices[i].Position);
    sumTexCoord   := vec_add(sumTexCoord, FVertices[i].TexCoord);
    sumLMTexCoord := vec_add(sumLMTexCoord, FVertices[i].LM_TexCoord);
    sumTangent    := vec_add(sumTangent, FVertices[i].Tangent);
    sumBinormal   := vec_add(sumBinormal, FVertices[i].Binormal);
    sumNormal     := vec_add(sumNormal, FVertices[i].Normal);
    sumColor      := vec_add(sumColor, FVertices[i].Color);
  end;

  t := 1 / FVertexCount;
  midpoint.Position := vec_scale(sumPos, t);
  midpoint.TexCoord := vec_scale(sumTexCoord, t);
  midpoint.LM_TexCoord := vec_scale(sumLMTexCoord, t);
  midpoint.Tangent := vec_scale(sumTangent, t);
  midpoint.Binormal := vec_scale(sumBinormal, t);
  midpoint.Normal := vec_scale(sumNormal, t);
  midpoint.Color := vec_scale(sumColor, t);

  AddVertex(midpoint);

  FElementCount := (FVertexCount-1) * 3;
  SetLength(FElements, FElementCount);

  for i:=0 to FVertexCount-2 do
  begin
    FElements[i*3+0] := i;
    FElements[i*3+1] := (i+1) mod (FVertexCount-1);
    FElements[i*3+2] := FVertexCount-1;
  end;
end;

function TPlanarSurface.TriangulateAsStrip: Boolean;
const MIN_STRIP_AREA = 8;
var
  i, r, rotate, least, ni, A, B, C: Integer;
  p1, p2: TVector3f;
begin
  Result := False;

  if FVertexCount = 0 then Exit;

// is this a simple triangle?
  if FVertexCount = 3 then
  begin
    FElementCount := 3;
    SetLength(FElements, FElementCount);

    FElements[0] := 0;
    FElements[1] := 1;
    FElements[2] := 2;

    Result := True;
  end
  else
  begin
  // find smallest coordinate
    least := 0;
    for i:=0 to FVertexCount-1 do
    begin
      p1 := FVertices[i].Position;
      p2 := FVertices[least].Position;

      if (p1[0] < p2[0]) or
         ((p1[0] = p2[0]) and (p1[1] < p2[1])) or
         ((p1[0] = p2[0]) and (p1[1] = p2[1]) and (p1[2] < p2[2])) then
        least := i;
    end;

    FElementCount := (FVertexCount-2) * 3;
    SetLength(FElements, FElementCount);

  // try all possible orderings of the points looking for a non-degenerate strip order

    ni := 0;
    for r:=0 to FVertexCount-1 do
    begin
    // set rotation
      rotate := (r + least) mod FVertexCount;

    // walk the winding in both directions
      i := 0;
      while (i < (FVertexCount - 2 - i)) do
      begin
      // create elements
        A := (FVertexCount - 1 - i + rotate) mod FVertexCount;
        B := (i + rotate) mod FVertexCount;
        C := (FVertexCount - 2 - i + rotate) mod FVertexCount;

      // test triangle
        if (FVertexCount > 4) and (TriangleArea(FVertices[A].Position,
                                                FVertices[B].Position,
                                                FVertices[C].Position) < MIN_STRIP_AREA) then
          Break;

        FElements[ni+0] := A;
        FElements[ni+1] := B;
        FElements[ni+2] := C;
        Inc(ni, 3);

      // end of strip?
        if (i+1) <> (FVertexCount - 1 - i) then
        begin
        // create elements
          A := (FVertexCount - 2 - i + rotate) mod FVertexCount;
          B := (i + rotate) mod FVertexCount;
          C := (i + 1 + rotate) mod FVertexCount;

        // test triangle
          if (FVertexCount > 4) and (TriangleArea(FVertices[A].Position,
                                                  FVertices[B].Position,
                                                  FVertices[C].Position) < MIN_STRIP_AREA) then
            Break;

          FElements[ni+0] := A;
          FElements[ni+1] := B;
          FElements[ni+2] := C;
          Inc(ni, 3);
        end;

        Inc(i);
      end;

    // valid strip order?
      if (ni = FElementCount) then
      begin
        Result := True;
        Break;
      end;
    end;

  // any triangle degenerated?
    if ni < FElementCount then
      ClearElements;
  end;


{  Result := False;
  FElements := nil;
  FElementCount := 0;
  if FVertexCount < 3 then Exit;

  FElementCount := (FVertexCount-2) * 3;
  SetLength(FElements, FElementCount);

  for i:=2 to FVertexCount-1 do
  begin
    FElements[(i-2)*3+0] := 0;
    FElements[(i-2)*3+1] := i-1;
    FElements[(i-2)*3+2] := i;

    if TriangleArea(FVertices[FElements[(i-2)*3+0]].Position,
                    FVertices[FElements[(i-2)*3+1]].Position,
                    FVertices[FElements[(i-2)*3+2]].Position) < MIN_STRIP_AREA then
    begin
      ClearElements;
      Exit;
    end;
  end;

  Result := True;}
end;

end.
