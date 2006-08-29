//
//  Project     : OpenBSP Map Compiler
//  Unit        : obspTrace.pas
//  Description : Ray-tracing class for lighting
//  History:
//    26/01/05 - OT - Creation
//
unit obspTrace;

interface

uses Classes, obspBaseTypes, obspFile, obspMath, obspMapClasses;

type
  TTraceObject = class
  private
    FOrigin: TVector3f;
    FTarget: TVector3f;
    FDirection: TVector3f;
    FDisplacement: TVector3f;
    FDistance: Single;
    FInhibitRadius: Single;
    FHitPoint: TVector3f;
    FOpaque: Boolean;
    FFraction: Single;
    FTraceBounds: TAABB;
    FTotalBounds: TAABB;
    FWorld: TWorld;
    FOccluders: TList;
    function GetOccluder(Index: Integer): TSurface;
    procedure SetOccluder(Index: Integer; const Value: TSurface);
    function GetOccluderCount: Integer;
  protected
    procedure CollectPotentialOccluders;
    procedure InternalTrace;
    function TraceOccluder(const Occluder: TSurface): Boolean;
  public
  // creates an potential occluders list within "Bounds"
    constructor Create(const AOwner: TWorld; const Bounds: TAABB);
    destructor Destroy; override;

    function Trace(const TraceStart, TraceEnd: TVector3f;
                   const TraceInhibitRadius: Single): Boolean; overload;
    function Trace(const TraceStart, TraceDirection: TVector3f;
                   const TraceDistance, TraceInhibitRadius: Single): Boolean; overload;

    function AddOccluder(Surf: TSurface): Integer;
    procedure DeleteOccluder(Index: Integer);
    function GetOccluderIndex(Surf: TSurface): Integer;
    procedure ClearOccluders;

    property Occluders[Index: Integer]: TSurface read GetOccluder write SetOccluder;
    property OccluderCount: Integer read GetOccluderCount;

    property Origin: TVector3f read FOrigin;
    property Target: TVector3f read FTarget;
    property Direction: TVector3f read FDirection;
    property Displacement: TVector3f read FDisplacement;
    property Distance: Single read FDistance;
    property InhibitRadius: Single read FInhibitRadius;
    property HitPoint: TVector3f read FHitPoint;   // trace contact point (valid if Opaque=True)
    property Opaque: Boolean read FOpaque;         // true if we hit something (Fraction can be <= 1.0)
    property Fraction: Single read FFraction;      // tracing percent [0, 1]
    property TraceBounds: TAABB read FTraceBounds; // current trace call bounds
    property TotalBounds: TAABB read FTotalBounds; // total (occluders + emitters) bounds
    property World: TWorld read FWorld;
  end;

implementation

{ TTraceObject }

function TTraceObject.AddOccluder(Surf: TSurface): Integer;
begin
  Result := FOccluders.Add(Surf);
end;

procedure TTraceObject.ClearOccluders;
begin
  FOccluders.Clear;
end;

procedure TTraceObject.CollectPotentialOccluders;
var
  i, j: Integer;
  surf: TSurface;
begin
  ClearOccluders;

  for i:=0 to World.EntityCount-1 do
  for j:=0 to World.Entities[i].SurfaceCount-1 do
  begin
    surf := World.Entities[i].Surfaces[j];
    if aabb_intersects(FTotalBounds, surf.AABB) then
      AddOccluder(surf);
  end;
end;

constructor TTraceObject.Create(const AOwner: TWorld; const Bounds: TAABB);
begin
  FWorld := AOwner;
  FTotalBounds := Bounds;
  FOccluders := TList.Create;

  CollectPotentialOccluders;
end;

procedure TTraceObject.DeleteOccluder(Index: Integer);
begin
  FOccluders.Delete(Index);
end;

destructor TTraceObject.Destroy;
begin
  FOccluders.Free;

  inherited;
end;

function TTraceObject.GetOccluder(Index: Integer): TSurface;
begin
  Result := TSurface(FOccluders.Items[Index]);
end;

function TTraceObject.GetOccluderCount: Integer;
begin
  Result := FOccluders.Count;
end;

function TTraceObject.GetOccluderIndex(Surf: TSurface): Integer;
begin
  Result := FOccluders.IndexOf(Surf);
end;

procedure TTraceObject.InternalTrace;
var i: Integer;
begin
// reset tracing info
  vec_clear(FHitPoint);
  FOpaque := False;
  FFraction := 1.0;

// early try out
  if OccluderCount = 0 then
    Exit;

// avoid divide-by-zero error and negative cases
  if FDistance < EPSILON then
    FDistance := EPSILON;

// check integrity
  FInhibitRadius := Clamp(FInhibitRadius, 0, FDistance - EPSILON);

// build the culling bound
  aabb_clear(FTraceBounds);
  aabb_addpoint(FTraceBounds, FOrigin);
  aabb_addpoint(FTraceBounds, FTarget);

// extend a bit the bounds
  FTraceBounds.Mins := vec_sub(FTraceBounds.Mins, vec_make(1.0, 1.0, 1.0));
  FTraceBounds.Maxs := vec_add(FTraceBounds.Maxs, vec_make(1.0, 1.0, 1.0));

// trace with all surfaces
  for i:=0 to OccluderCount-1 do
  begin
    if TraceOccluder(Occluders[i]) then Break;

    if FOpaque then Break;
  end;

// do some clearing
  if not FOpaque then
    FFraction := 1.0;
end;

procedure TTraceObject.SetOccluder(Index: Integer; const Value: TSurface);
begin
  FOccluders.Items[Index] := Value;
end;

function TTraceObject.Trace(const TraceStart, TraceEnd: TVector3f;
  const TraceInhibitRadius: Single): Boolean;
begin
// prepare arguments
  FOrigin := TraceStart;
  FTarget := TraceEnd;
  FDisplacement := vec_sub(FTarget, FOrigin);
  FDistance := vec_normalizesafe(FDisplacement, FDirection);
  FInhibitRadius :=TraceInhibitRadius;

// call internal trace routine
  InternalTrace;

// occluded?
  Result := FOpaque;
end;

function TTraceObject.Trace(const TraceStart, TraceDirection: TVector3f;
  const TraceDistance, TraceInhibitRadius: Single): Boolean;
begin
// prepare arguments
  FOrigin := TraceStart;
  FDirection := TraceDirection;
  FDistance := TraceDistance;
  FInhibitRadius := TraceInhibitRadius;
  FDisplacement := vec_scale(FDirection, FDistance);
  FTarget := vec_add(FOrigin, FDisplacement);

// call internal trace routine
  InternalTrace;

// occluded?
  Result := FOpaque;
end;

function TTraceObject.TraceOccluder(const Occluder: TSurface): Boolean;

const
  BARY_EPSILON        = 0.01;
  ASLF_EPSILON        = 0.0001;
  COPLANAR_EPSILON    = 0.25;
  NEAR_SHADOW_EPSILON = 1.5;
  SELF_SHADOW_EPSILON = 0.5;

var
  i: Integer;
  dv1, dv2, dv3: POBSPVertex;
  edge1, edge2: TVector3f;
  tvec, pvec, qvec: TVector3f;
  det, invDet, depth, u, v: Single;
begin
  Result := False;

// test bounds
  if not aabb_Intersects(FTraceBounds, Occluder.AABB) then Exit;

// give a last chance before triangle level tracing
  if not aabb_LineIntersects(Occluder.AABB, FOrigin, FTarget) then Exit;

// trace surface at triangle level
  for i:=0 to (Occluder.ElementCount div 3)-1 do
  begin
    dv1 := Occluder.Vertices[Occluder.Elements[i*3+0]];
    dv2 := Occluder.Vertices[Occluder.Elements[i*3+1]];
    dv3 := Occluder.Vertices[Occluder.Elements[i*3+2]];

    edge1 := vec_sub(dv2.Position, dv1.Position);
    edge2 := vec_sub(dv3.Position, dv1.Position);

  // begin calculating determinant - also used to calculate u parameter
    pvec := vec_cross(FDirection, edge2);

  // if determinant is near zero, trace lies in plane of triangle
    det := vec_dot(edge1, pvec);
	
  // the non-culling branch
    if Abs(det) < COPLANAR_EPSILON then
      Continue;

    invDet := 1.0 / det;

  // calculate distance from first vertex to ray origin
    tvec := vec_sub(FOrigin, dv1.Position);
	
  // calculate u parameter and test bounds
    u := vec_dot(tvec, pvec) * invDet;
    if (u < -BARY_EPSILON) or (u > (1.0 + BARY_EPSILON)) then
      Continue;
	
  // prepare to test v parameter
    qvec := vec_cross(tvec, edge1);

  // calculate v parameter and test bounds
    v := vec_dot(FDirection, qvec) * invDet;
    if (v < -BARY_EPSILON) or ((u + v) > (1.0 + BARY_EPSILON)) then
      Continue;

  // calculate t (depth)
    depth := vec_dot(edge2, qvec) * invDet;
    if (depth <= FInhibitRadius) or (depth >= FDistance) then
      Continue;
{
  // hitpoint is really close to trace origin?
    if (depth <= SELF_SHADOW_EPSILON) then
      Continue;
}
    FHitPoint := vec_combine(FOrigin, FDirection, depth);
    FFraction := Clamp(depth / FDistance, 0, 1); // avoid FPU rounding
    FOpaque := True;
    Result := True;
    Break;
  end;
end;

end.
