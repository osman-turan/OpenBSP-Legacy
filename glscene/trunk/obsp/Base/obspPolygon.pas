//
//  Project     : OpenBSP Map Compiler
//  Unit        : obspPolygon.pas
//  Description : Polygon class
//  History:
//    02/11/04 - OT - Added GetAABB function
//    26/08/04 - OT - Added IsPointInside function
//    10/08/04 - OT - Added GetArea function
//    03/07/04 - OT - Creation
//
unit obspPolygon;

interface

uses obspBaseTypes;

type
  TPolygon = class
  private
    FPoints: array of TVector3f;
    FCount: Integer;
    function GetPoint(Index: Integer): TVector3f;
    procedure SetPoint(Index: Integer; const Value: TVector3f);
  protected
    procedure InternalClip(const Plane: TPlane;
                           const Epsilon: Single;
                           const Base, Clipped: TPolygon);
  public
    constructor Create(Count: Integer);
    destructor Destroy; override;
    procedure Assign(Source: TObject);

    procedure Reserve;
    function Classify(const Plane: TPlane;
                      const Epsilon: Single): TSideClassify;

    procedure Clip(const Plane: TPlane;
                   const Epsilon: Single;
                   out Clipped: TPolygon); overload;
    procedure Clip(const Plane: TPlane;
                   const Epsilon: Single); overload;
    procedure Clip(const Plane: TPlane;
                   const Poly: TPolygon;
                   const Epsilon: Single); overload;

    procedure Split(const Plane: TPlane;
                    const Epsilon: Single;
                    out Front, Back: TPolygon);
    function GetMassCenter: TVector3f;
    function GetArea: Single;
    function GetAABB: TAABB;
    function IsTiny: Boolean;
    function IsPointInside(P: TVector3f): Boolean;
    procedure GeneratePointsFromPlane(Plane: TPlane);
    function AddPoint(const Point: TVector3f): Integer;
    function GetPointAsAddress(Index: Integer): PVector3f;
    procedure Clear;

    property Points[Index: Integer]: TVector3f read GetPoint write SetPoint;
    property Count: Integer read FCount;
  end;

implementation

uses obspMath;

{ TPolygon }

function TPolygon.AddPoint(const Point: TVector3f): Integer;
begin
  Result := FCount;

  SetLength(FPoints, FCount+1);
  FPoints[FCount] := Point;
  Inc(FCount);
end;

procedure TPolygon.Assign(Source: TObject);
var
  i: Integer;
  poly: TPolygon;
begin
  if Source is TPolygon then
  begin
    poly := Source as TPolygon;
    FCount := poly.Count;
    SetLength(FPoints, FCount);

    for i:=0 to poly.Count-1 do
      FPoints[i] := poly.Points[i];
  end;
end;

function TPolygon.Classify(const Plane: TPlane;
const Epsilon: Single): TSideClassify;
var
  i: Integer;
  dist: Single;
  front, back: Boolean;
begin
  front := False;
  back := False;

  for i:=0 to FCount-1 do
  begin
    dist := plane_evaluatepoint(Plane, FPoints[i]);

    if dist < -Epsilon then
    begin
      if front then
      begin
        Result := scCross;
        Exit;
      end;

      back := True;
    end
    else if dist > Epsilon then
    begin
      if back then
      begin
        Result := scCross;
        Exit;
      end;

      front := True;
    end;
  end;

  if back then
    Result := scBack
  else if front then
    Result := scFront
  else Result := scOn;
end;

procedure TPolygon.Clear;
begin
  FCount := 0;
  FPoints := nil;
end;

procedure TPolygon.Clip(const Plane: TPlane; const Epsilon: Single);
var
  poly: TPolygon;
begin
  poly := TPolygon.Create(0);
  poly.Assign(Self);
  Clear;
  InternalClip(Plane, Epsilon, poly, Self);
  poly.Free;

  if FCount < 3 then
    Clear;
end;

procedure TPolygon.Clip(const Plane: TPlane; const Epsilon: Single;
out Clipped: TPolygon);
begin
  Clipped := TPolygon.Create(0);
  InternalClip(Plane, Epsilon, Self, Clipped);

  if Clipped.Count < 3 then
  begin
    Clipped.Free;
    Clipped := nil;
  end;
end;

procedure TPolygon.Clip(const Plane: TPlane; const Poly: TPolygon;
  const Epsilon: Single);
var
  i, j, k: Integer;
  p, dir: TVector3f;
  d: Single;
  sides: array of Boolean;
  outside: Boolean;
  tmpPoly: TPolygon;
begin
  tmpPoly := TPolygon.Create(0);

  for i:=0 to FCount-1 do
  begin
    p := Points[i];

    SetLength(sides, Poly.Count);

    outside := False;
    for j:=0 to Poly.Count-1 do
    begin
      dir := vec_normalize(vec_sub(Poly.Points[(j+1) mod Poly.Count],
                                   Poly.Points[j]));
      dir := vec_cross(Plane.Normal, dir);

      d := vec_dot(vec_sub(p, Poly.Points[j]), dir);
      if d >= Epsilon then
        outside := True;

      if d >= -Epsilon then
        sides[j] := True
      else
        sides[j] := False;
    end;

    if not outside then
      Continue;

    for j:=0 to Poly.Count-1 do
    begin
      if (not sides[j]) and (sides[(j+1) mod Poly.Count]) then
        Break;
    end;

    if j = Poly.Count then
      Continue;

    tmpPoly.Clear;
    tmpPoly.AddPoint(p);

    j := (j+1) mod Poly.Count;

    for k:=0 to Poly.Count-1 do
    begin
      if (sides[(j+k) mod Poly.Count]) and
         (sides[(j+k+1) mod Poly.Count]) then
        Continue;

      tmpPoly.AddPoint(Poly.Points[(j+k+1) mod Poly.Count]);
    end;

    Poly.Assign(tmpPoly);
  end;

  sides := nil;
  tmpPoly.Free;
end;

constructor TPolygon.Create(Count: Integer);
begin
  FCount := Count;
  SetLength(FPoints, FCount);
end;

destructor TPolygon.Destroy;
begin
  FPoints := nil;
  inherited;
end;

procedure TPolygon.GeneratePointsFromPlane(Plane: TPlane);
var b, t, org: TVector3f;
begin
  vec_tangentspace(Plane.Normal, t, b);

  b := vec_scale(b, MAX_WORLD_COORD);
  t := vec_scale(t, MAX_WORLD_COORD);
  org := vec_scale(Plane.Normal, -Plane.Dist);

  Clear;
  AddPoint(vec_add(vec_add(org, t), b));
  AddPoint(vec_add(vec_sub(org, t), b));
  AddPoint(vec_sub(vec_sub(org, t), b));
  AddPoint(vec_sub(vec_add(org, t), b));
end;

function TPolygon.GetArea: Single;
var i: Integer;
begin
  Result := 0;
  for i:=2 to FCount-1 do
    Result :=
      Result + 0.5 * vec_length(vec_cross(vec_sub(FPoints[i-1], FPoints[0]),
                                          vec_sub(FPoints[i], FPoints[0])));
end;

function TPolygon.GetAABB: TAABB;
var i: Integer;
begin
  aabb_clear(Result);
  for i:=0 to FCount-1 do
    aabb_addpoint(Result, FPoints[i]);
end;

function TPolygon.GetMassCenter: TVector3f;
var
  i: Integer;
  sum: array[0..2] of Extended;
  t: Extended;
begin
  sum[0] := 0;
  sum[1] := 0;
  sum[2] := 0;

  for i:=0 to FCount-1 do
  begin
    sum[0] := sum[0] + FPoints[i][0];
    sum[1] := sum[1] + FPoints[i][1];
    sum[2] := sum[2] + FPoints[i][2];
  end;

  t := 1 / FCount;
  Result[0] := sum[0] * t;
  Result[1] := sum[1] * t;
  Result[2] := sum[2] * t;
end;

function TPolygon.GetPoint(Index: Integer): TVector3f;
begin
  Result := FPoints[Index];
end;

function TPolygon.GetPointAsAddress(Index: Integer): PVector3f;
begin
  Result := @FPoints[Index];
end;

procedure TPolygon.InternalClip(const Plane: TPlane;
const Epsilon: Single; const Base, Clipped: TPolygon);
var
  i, j: Integer;
  f: Single;
  clippoint: TVector3f;
  p1, p2: TVector3f;
  dist: Single;
  counts: array[TSideClassify] of Integer;
  sides: array of TSideClassify;
  dists: array of Single;
begin
  if Base.Count = 0 then Exit;

  counts[scOn]    := 0;
  counts[scFront] := 0;
  counts[scBack]  := 0;
  counts[scCross] := 0;

  SetLength(sides, Base.Count+1);
  SetLength(dists, Base.Count+1);

// determine sides for each point
  for i:=0 to Base.Count-1 do
  begin
    dist := plane_evaluatepoint(Plane, Base.Points[i]);
    dists[i] := dist;

    if dist > Epsilon then
      sides[i] := scFront
    else if dist < -Epsilon then
      sides[i] := scBack
    else
      sides[i] := scOn;

    counts[sides[i]] := counts[sides[i]] + 1;
  end;

// completely back side?
  if (counts[scFront] = 0) then
  begin
    Clipped.Assign(Base);

    sides := nil;
    dists := nil;

    Exit;
  end;

// completely front side?
  if (counts[scBack] = 0) then
  begin
    sides := nil;
    dists := nil;

    Exit;
  end;

  sides[Base.Count] := sides[0];
  dists[Base.Count] := dists[0];

  for i:=0 to Base.Count-1 do
  begin
    p1 := Base.Points[i];

    if (sides[i] = scOn) then 
    begin
      Clipped.AddPoint(p1);
      Continue;
    end;

    if (sides[i] = scBack) then
      Clipped.AddPoint(p1);

    if (sides[i+1] = scOn) or (sides[i] = sides[i+1]) then
      Continue;

    p2 := Base.Points[(i+1) mod Base.Count];

    f := dists[i] / (dists[i]-dists[i+1]);

    for j:=0 to 2 do
    begin
      if Plane.Normal[j] = 1 then
        clippoint[j] := -Plane.Dist
      else if Plane.Normal[j] = -1 then
        clippoint[j] := Plane.Dist
      else
        clippoint[j] := p1[j] + (f * (p2[j] - p1[j]));
    end;

    Clipped.AddPoint(clippoint);
  end;
end;

function TPolygon.IsPointInside(P: TVector3f): Boolean;
var
  i: Integer;
  normal: TVector3f;
  edge: TPlane;
begin
  Result := False;

  if FCount < 3 then Exit;

  normal := plane_normal(FPoints[0], FPoints[1], FPoints[2]);

  for i:=0 to FCount-1 do
  begin
    edge.Normal := vec_normalize(vec_cross(normal, vec_sub(FPoints[(i+1) mod FCount], FPoints[i])));
    edge.Dist := -vec_dot(FPoints[i], edge.Normal);

    if plane_evaluatepoint(edge, P) > 0 then
      Exit;
  end;

  Result := True;
end;

function TPolygon.IsTiny: Boolean;
const EDGE_LENGTH = 0.2;
var
  i: Integer;
  edges: Integer;
begin
  Result := True;

  edges := 0;
  for i:=0 to FCount-1 do
  if vec_length(vec_sub(FPoints[(i+1) mod FCount], FPoints[i])) > EDGE_LENGTH then
  begin
    Inc(edges);
    if edges >= 3 then
    begin
      Result := False;
      Exit;
    end;
  end;
end;

procedure TPolygon.Reserve;
var
  OldPoints: array of TVector3f;
  i: Integer;
begin
  SetLength(OldPoints, FCount);
  Move(FPoints[0], OldPoints[0], FCount * SizeOf(TVector3f));
  for i:=0 to FCount-1 do
    FPoints[i] := OldPoints[FCount-i-1];

  OldPoints := nil;
end;

procedure TPolygon.SetPoint(Index: Integer; const Value: TVector3f);
begin
  FPoints[Index] := Value;
end;

procedure TPolygon.Split(const Plane: TPlane; const Epsilon: Single;
out Front, Back: TPolygon);
var
  i, j: Integer;
  f, dist: Single;
  clippoint: TVector3f;
  p1, p2: TVector3f;
  counts: array[TSideClassify] of Integer;
  sides: array of TSideClassify;
  dists: array of Single;
begin
  Front := nil;
  Back := nil;

  if FCount = 0 then Exit;

  counts[scOn]    := 0;
  counts[scFront] := 0;
  counts[scBack]  := 0;
  counts[scCross] := 0;

  SetLength(sides, FCount+1);
  SetLength(dists, FCount+1);

// determine sides for each point
  for i:=0 to FCount-1 do
  begin
    dist := plane_evaluatepoint(Plane, FPoints[i]);
    dists[i] := dist;

    if dist > Epsilon then
      sides[i] := scFront
    else if dist < -Epsilon then
      sides[i] := scBack
    else
      sides[i] := scOn;

    counts[sides[i]] := counts[sides[i]] + 1;
  end;

// completely back side?
  if (counts[scFront] = 0) then
  begin
    Back := TPolygon.Create(0);
    Back.Assign(Self);

    sides := nil;
    dists := nil;

    Exit;
  end;

// completely front side?
  if (counts[scBack] = 0) then
  begin
    Front := TPolygon.Create(0);
    Front.Assign(Self);

    sides := nil;
    dists := nil;

    Exit;
  end;

  sides[FCount] := sides[0];
  dists[FCount] := dists[0];

  Front := TPolygon.Create(0);
  Back := TPolygon.Create(0);

  for i:=0 to FCount-1 do
  begin
    p1 := FPoints[i];

    if (sides[i] = scOn) then
    begin
      Front.AddPoint(p1);
      Back.AddPoint(p1);
      Continue;
    end;

    if (sides[i] = scFront) then
      Front.AddPoint(p1);

    if (sides[i] = scBack) then
      Back.AddPoint(p1);

    if (sides[i+1] = scOn) or (sides[i+1] = sides[i]) then
      Continue;

    p2 := FPoints[(i+1) mod FCount];

    f := dists[i] / (dists[i] - dists[i+1]);

    for j:=0 to 2 do
    begin
      if Plane.Normal[j] = 1 then
        clippoint[j] := -Plane.Dist
      else if Plane.Normal[j] = -1 then
        clippoint[j] := Plane.Dist
      else
        clippoint[j] := p1[j] + (f * (p2[j] - p1[j]));
    end;

    Front.AddPoint(clippoint);
    Back.AddPoint(clippoint);
  end;

  if Back.Count < 3 then
  begin
    Back.Free;
    Back := nil;
  end;

  if Front.Count < 3 then
  begin
    Front.Free;
    Front := nil;
  end;

  sides := nil;
  dists := nil;
end;

end.
