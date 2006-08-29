//
//  Project     : OpenBSP Map Compiler
//  Unit        : obspBSP.pas
//  Description : BSP tree compiler
//  History     :
//    12/01/05 - OT - Fixed SubdivideSurfaces
//    29/08/04 - OT - Added FilterSurfacesIntoTree
//    27/08/04 - OT - Added SubdivideSurfaces
//    26/08/04 - OT - Added CullBrushSides
//    14/08/04 - OT - Fixed FilterStructuralBrushesIntoTree
//    08/08/04 - OT - Added FilterStructuralBrushesIntoTree
//    17/06/04 - OT - Map parsing code has moved to MapParser.pas
//    20/05/04 - OT - Creation
//
unit obspBSP;

interface

uses SysUtils, Classes, obspBaseTypes, obspBaseCompiler, obspMapParser,
  obspMapClasses, obspMath, obspPolygon, obspSurfPlanar;

type
  TBSPProcess = class(TBaseCompiler)
  private
    FMapParser: TMapParser;
    FWorkList: TList;
  protected
    procedure BuildStructuralBSPTree;
    procedure BuildVisibleBSPTree;
    procedure BuildSurfaces;
    procedure CullBrushSides;
    function FilterBrushIntoNode(Node: TBSPNode; Brush, OriginalBrush: TBrush): Integer;
    procedure FilterStructuralBrushesIntoTree;
    procedure FilterSurfacesIntoTree;
    function FilterPointIntoNode(Node: TBSPNode; Surface: TSurface; Point: TVector3f): Integer;
    function FilterPolygonIntoNode(Node: TBSPNode; Surface: TSurface; var Poly: TPolygon): Integer;
    procedure ClipSideIntoNode(Node: TBSPNode; Side: TBrushSide; Poly: TPolygon);
    procedure ClipSidesIntoTree;
    procedure FixTJunctions;
    function SubdivideSurface(Surf: TPlanarSurface; Poly: TPolygon;
                              Subdivisions: Single): Integer;
    procedure SubdivideSurfaces;
  public
    constructor Create(const AManager: TBaseCompilerManager;
                       const AOwner: TBaseCompilerObject); override;
    destructor Destroy; override;

    function Compile(const MapFile: String): Boolean;

    property MapParser: TMapParser read FMapParser;
  end;

implementation

uses obspFile, obspMaterial, obspMesh;

{ TBSPProcess }

procedure TBSPProcess.BuildStructuralBSPTree;
var
  ref: TBSPReference;
  reflist: TBSPReferenceList;
  i, j: Integer;
  side: TBrushSide;
begin
  StartWork('Building structural BSP tree...');

  reflist := TBSPReferenceList.Create;

  for i:=0 to World.WorldSpawn.BrushCount-1 do
  for j:=0 to World.WorldSpawn.Brushes[i].SideCount-1 do
  begin
    side := World.WorldSpawn.Brushes[i].Sides[j];

    ref := TBSPReference.Create(World,
                                side.BasePolygon,
                                side.PlaneIndex xor 1);
    reflist.Add(ref);
  end;

  if Assigned(World.HeadNode) then
    World.HeadNode.Free;

  World.HeadNode := TBSPNode.Create(World, nil, reflist);
  World.HeadNode.BuildNode;
  reflist.Free;

  EndWork;
end;

procedure TBSPProcess.BuildSurfaces;
var
  i: Integer;
  surfCount: Integer;
begin
  StartWork('Building surfaces...');

  surfCount := 0;

  for i:=0 to World.EntityCount-1 do
  begin
    World.Entities[i].BuildSurfaces;
    surfCount := surfCount + World.Entities[i].SurfaceCount;

    Progress(Trunc(100 * (i+1) / World.EntityCount));
  end;

  EndWork;

  PrintMessage('%6d surfaces created', [SurfCount]);
end;

procedure TBSPProcess.BuildVisibleBSPTree;
var
  ref: TBSPReference;
  reflist: TBSPReferenceList;
  i, j: Integer;
  side: TBrushSide;
begin
  StartWork('Building visible BSP tree...');

  reflist := TBSPReferenceList.Create;

  for i:=0 to World.WorldSpawn.BrushCount-1 do
  for j:=0 to World.WorldSpawn.Brushes[i].SideCount-1 do
  begin
    side := World.WorldSpawn.Brushes[i].Sides[j];

    if (cfNoDraw in side.Material.CompileFlags) then Continue;
    if side.Culled then Continue;
    if not side.Visible then Continue;
    if not Assigned(side.VisiblePolygon) then Continue;

    ref := TBSPReference.Create(World,
                                side.VisiblePolygon,
                                side.PlaneIndex xor 1);
    reflist.Add(ref);
  end;

  if Assigned(World.HeadNode) then
    World.HeadNode.Free;

  World.HeadNode := TBSPNode.Create(World, nil, reflist);
  World.HeadNode.BuildNode;
  reflist.Free;

  EndWork;
end;

procedure TBSPProcess.ClipSideIntoNode(Node: TBSPNode; Side: TBrushSide;
  Poly: TPolygon);
var front, back: TPolygon;
begin
  if not Assigned(Poly) then
    Exit;

  if not Node.IsLeaf then
  begin
    if Side.PlaneIndex = Node.PlaneIndex then
      ClipSideIntoNode(Node.FrontChild, Side, Poly)
    else if Side.PlaneIndex = (Node.PlaneIndex xor 1) then
      ClipSideIntoNode(Node.BackChild, Side, Poly)
    else
    begin
      Poly.Split(Node.Plane, EPSILON_ON_SIDE, front, back);
      Poly.Free;

      ClipSideIntoNode(Node.FrontChild, Side, front);
      ClipSideIntoNode(Node.BackChild, Side, back);
    end;
  end
  else
  begin
    if not Node.Opaque then
    begin
      if not Assigned(Side.VisiblePolygon) then
      begin
        Side.VisiblePolygon := TPolygon.Create(0);
        Side.VisiblePolygon.Assign(Side.BasePolygon);
      end;

      Poly.Clip(Side.Plane, Side.VisiblePolygon, EPSILON_ON_SIDE);
    end;

    Poly.Free;
  end;
end;

procedure TBSPProcess.ClipSidesIntoTree;
var
  j, k: Integer;
  side: TBrushSide;
  poly: TPolygon;
begin
  StartWork('Clipping brush sides into BSP tree...');

  for j:=0 to World.WorldSpawn.BrushCount-1 do
  for k:=0 to World.WorldSpawn.Brushes[j].SideCount-1 do
  begin
    side := World.WorldSpawn.Brushes[j].Sides[k];

      if (cfNoDraw in side.Material.CompileFlags) then Continue;
      if not side.Visible then Continue;
      if side.Culled then Continue;

      poly := TPolygon.Create(0);
      poly.Assign(side.BasePolygon);

      Side.VisiblePolygon := nil;
      ClipSideIntoNode(World.HeadNode, side, poly);

      if not Assigned(Side.VisiblePolygon) then
        Side.VisiblePolygon := TPolygon.Create(0);

      Side.VisiblePolygon.Assign(Side.BasePolygon);
  end;

  EndWork;
end;

function TBSPProcess.Compile(const MapFile: String): Boolean;
var
  i, j: Integer;
  surf: TSurface;
begin
  FWorkList := TList.Create;

  try
    FMapParser.ParseMapFile(MapFile);

    World.InitWorld;

    CullBrushSides;

    BuildStructuralBSPTree;

    FilterStructuralBrushesIntoTree;

    ClipSidesIntoTree;

    BuildVisibleBSPTree;

    FilterStructuralBrushesIntoTree;

    BuildSurfaces;

    SubdivideSurfaces;

    StartWork('Embedding triangle meshes into map...');
    i := EmbedTriangleMeshesIntoWorld(World, Manager.GamePath);
    EndWork;
    PrintMessage('  %d triangle surfaces embedded', [i]);

    FilterSurfacesIntoTree;

    for i:=0 to World.EntityCount-1 do
    for j:=0 to World.Entities[i].SurfaceCount-1 do
    begin
      surf := World.Entities[i].Surfaces[j];
      
      if surf.SurfaceType = stPlanar then
        (surf as TPlanarSurface).Triangulate;

      surf.CalcBounds;
    end;

  //  FixTJunctions;
  finally
    FWorkList.Free;
  end;

  Result := True;
end;

constructor TBSPProcess.Create(const AManager: TBaseCompilerManager;
                               const AOwner: TBaseCompilerObject);
begin
  inherited;
  FMapParser := TMapParser.Create(Manager, Self);
end;

procedure TBSPProcess.CullBrushSides;
var
  i, j, k, l, m: Integer;
  hiddenSides: Integer;
  b1, b2: TBrush;
  side1, side2: TBrushSide;
  intersected: Boolean;
begin
  StartWork('Culling hidden brush sides...');

  hiddenSides := 0;

  for i:=0 to World.WorldSpawn.BrushCount-1 do
  begin
    b1 := World.WorldSpawn.Brushes[i];

    if b1.SideCount < 1 then
      Continue;

    for j:=0 to World.WorldSpawn.BrushCount-1 do
    begin
      b2 := World.WorldSpawn.Brushes[j];

      if b1 = b2 then Continue;

      if b2.SideCount < 1 then
        Continue;

      // AABB check
      if not aabb_intersects(b1.AABB, b2.AABB) then Continue;

      for k:=0 to b1.SideCount-1 do
      begin
        side1 := b1.Sides[k];

        if side1.Culled then Continue;
        if (cfNoDraw in side1.Material.CompileFlags) then Continue;
        if (cfTranslucent in side1.Material.CompileFlags) then Continue;
        if not side1.Visible then Continue;

        intersected := False;

        for l:=0 to b2.SideCount-1 do
        begin
          side2 := b2.Sides[l];

          if (cfNoDraw in side2.Material.CompileFlags) then Continue;
          if (cfTranslucent in side2.Material.CompileFlags) then Continue;
          if not side2.Visible then Continue;

          if (side1.PlaneIndex xor 1) <> (side2.PlaneIndex) then Continue;

          for m:=0 to side1.BasePolygon.Count-1 do
          begin
            if not side2.BasePolygon.IsPointInside(side1.BasePolygon.Points[m]) then
              Break;
          end;

          if m = side1.BasePolygon.Count then
          begin
            intersected := True;
            Break;
          end;
        end;

        if intersected then
        begin
          side1.Culled := True;
          Inc(hiddenSides);
        end;
      end;
    end;

    Progress(Trunc(100 * (i+1) / World.WorldSpawn.BrushCount));
  end;

  EndWork;

  PrintMessage('%6d hidden sides culled', [hiddenSides]);
end;

destructor TBSPProcess.Destroy;
begin
  FMapParser.Free;
  inherited;
end;

function TBSPProcess.FilterBrushIntoNode(Node: TBSPNode; Brush,
  OriginalBrush: TBrush): Integer;
var front, back: TBrush;
begin
  Result := 0;

  if not Assigned(Brush) then Exit;

  if Node.IsLeaf then
  begin
    if Node.IndexOfBrush(OriginalBrush) < 0 then
      Node.AddBrush(OriginalBrush);

    if Brush.Opaque then
      Node.Opaque := True;

    Brush.Free; // don't forget saving memory

    Result := 1;
  end
  else
  begin
    Brush.Split(Node.Plane, front, back);
    Brush.Free;

    Result := FilterBrushIntoNode(Node.FrontChild, front, OriginalBrush) +
              FilterBrushIntoNode(Node.BackChild, back, OriginalBrush);
  end;
end;

function TBSPProcess.FilterPointIntoNode(Node: TBSPNode;
  Surface: TSurface; Point: TVector3f): Integer;
var
  d: Single;
  refs: Integer;
begin
  Result := 0;

  if Node.IsLeaf then
  begin
    if Node.IndexOfSurface(Surface) < 0 then
      Node.AddSurface(Surface);

    Exit;
  end;

  d := plane_evaluatepoint(Node.Plane, Point);
  refs := 0;

  if (d >= -EPSILON_ON_SIDE) then
    refs := FilterPointIntoNode(Node.FrontChild, Surface, Point)
  else if (d <= EPSILON_ON_SIDE) then
    refs := FilterPointIntoNode(Node.BackChild, Surface, Point);

  Result := refs;
end;

function TBSPProcess.FilterPolygonIntoNode(Node: TBSPNode;
  Surface: TSurface; var Poly: TPolygon): Integer;
var
  planeIndex, refs: Integer;
  front, back: TPolygon;
begin
  Result := 0;

  if not Assigned(Poly) then Exit;

  if Node.IsLeaf then
  begin
    if Node.IndexOfSurface(Surface) < 0 then
    begin
      Node.AddSurface(Surface);
      Result := 1;
    end;

    Poly.Free;
    Poly := nil;
    Exit;
  end;

  if (Surface.SurfaceType = stPlanar) then
  begin
    planeIndex := (Surface as TPlanarSurface).Side.PlaneIndex;

    if planeIndex = Node.PlaneIndex then
    begin
      Result := FilterPolygonIntoNode(Node.FrontChild, Surface, Poly);
      Exit;
    end
    else if planeIndex = (Node.PlaneIndex xor 1) then
    begin
      Result := FilterPolygonIntoNode(Node.BackChild, Surface, Poly);
      Exit;
    end;
  end;

  Poly.Split(Node.Plane, EPSILON_ON_SIDE, front, back);
  Poly.Free;
  Poly := nil;

  refs := FilterPolygonIntoNode(Node.FrontChild, Surface, front);
  refs := refs + FilterPolygonIntoNode(Node.BackChild, Surface, back);
  Result := refs;
end;

procedure TBSPProcess.FilterStructuralBrushesIntoTree;
var
  j, k: Integer;
  brush, newbrush: TBrush;
  clusterRefs, culledCount: Integer;
begin
  StartWork('Filtering structural brushes into BSP tree...');

// We are not really cutting brushes into tree
// Just detecting brush places
// Also, we are ignoring too small brush fragment in BSP tree
  clusterRefs := 0;
  culledCount := 0;

  for j:=0 to World.WorldSpawn.BrushCount-1 do
  begin
    brush := World.WorldSpawn.Brushes[j];
    newbrush := brush.CreateCopy;

    k := FilterBrushIntoNode(World.HeadNode, newbrush, brush);
    Inc(clusterRefs, k);

    if k <= 0 then
    begin
      for k:=0 to brush.SideCount-1 do
      if Assigned(brush.Sides[k].BasePolygon) then
      begin
        brush.Sides[k].Visible := False;
        Inc(culledCount);
      end;
    end;

  end;

  EndWork;

  PrintMessage('%6d cluster references', [clusterRefs]);
  PrintMessage('%6d sides culled', [culledCount]);
end;

procedure TBSPProcess.FilterSurfacesIntoTree;
var
  i, j: Integer;
  surf: TSurface;
  poly: TPolygon;
begin
  StartWork('Filtering surfaces into BSP tree...');

  for i:=0 to World.WorldSpawn.SurfaceCount-1 do
  begin
    surf := World.WorldSpawn.Surfaces[i];

    if (cfNoDraw in surf.Material.CompileFlags) then Continue;

    case surf.SurfaceType of
      stPlanar:
        begin
          poly := surf.GetPolygon;
          FilterPolygonIntoNode(World.HeadNode, surf, poly);
        end;

      stTriangleMesh:
        begin
        // filter each triangle into nodes
          for j:=0 to (surf.ElementCount div 3)-1 do
          begin
            poly := TPolygon.Create(3);
            poly.Points[0] := surf.Vertices[surf.Elements[j*3+0]].Position;
            poly.Points[1] := surf.Vertices[surf.Elements[j*3+1]].Position;
            poly.Points[2] := surf.Vertices[surf.Elements[j*3+2]].Position;

            FilterPolygonIntoNode(World.HeadNode, surf, poly);
          end;

        // also, filter all points
          for j:=0 to surf.VertexCount-1 do
            FilterPointIntoNode(World.HeadNode, surf, surf.Vertices[j].Position);
        end;

      stPatch:
        begin
        end;
    end;
  end;

  EndWork;
end;

procedure TBSPProcess.FixTJunctions;

const
  EPSILON_TJUNC = 0.0001;

type
  PEdge = ^TEdge;
  TEdge = packed record
    Binormal,
    Tangent,
    Normal: TPlane;
    Origin: TVector3f;
    DeltaList: PSingleArray;
    DeltaCount: Integer;
  end;

var EdgeList: TList;

var
  i, j, k, l, m: Integer;
  Surf: TSurface;
begin
  StartWork('Fixing tjunctions...');

  EdgeList := TList.Create;

  try
    for i:=0 to World.EntityCount-1 do
    for j:=0 to World.Entities[i].BrushCount-1 do
    for k:=0 to World.Entities[i].Brushes[j].SideCount-1 do
    for l:=0 to World.Entities[i].Brushes[j].Sides[k].SurfaceCount-1 do
    begin
      Surf := World.Entities[i].Brushes[j].Sides[k].Surfaces[l];
{      if Surf.VertexCount-1 do
      AddEdge(}
    end;
  finally
    EdgeList.Free;
  end;

  EndWork;
(*
  PJuncCandidate = ^TJuncCandidate;
  TJuncCandidate = packed record
    Surf: TSurface;
    OriginalElems: PCardinalArray;
    NumElems: Integer;
  end;

var
  CandidateList: TList;

  function AddLerpIfDistinct(Candidate, Test: PJuncCandidate; iA, iB, iMid: Integer): Integer;
  var
    midNormal,
    midBinormal,
    midTangent: TVector3f;
    midColor: TVector4b;
    midTexCoord: TVector3f;
    midLMCoord: TVector2f;
    f: Single;
    spawn: Boolean;
    vert: TOBSPVertex;
    Surf1, Surf2: TSurface;
  begin
    Result := -1;

    Surf1 := Candidate.Surf;
    Surf2 := Test.Surf;

    f := vec_dist(Surf1.Vertices[iA].Position,
                  Surf2.Vertices[iMid].Position) /
         vec_dist(Surf1.Vertices[iA].Position,
                  Surf1.Vertices[iB].Position);

    spawn := False;

    midNormal := vec_lerp(Surf1.Vertices[iA].Normal, Surf1.Vertices[iB].Normal, f);
    spawn := (vec_spacing(midNormal, Surf2.Vertices[iMid].Normal) > EPSILON_TJUNC);

    midBinormal := vec_lerp(Surf1.Vertices[iA].Binormal, Surf1.Vertices[iB].Binormal, f);
    spawn := spawn or (vec_spacing(midBinormal, Surf2.Vertices[iMid].Binormal) > EPSILON_TJUNC);

    midTangent := vec_lerp(Surf1.Vertices[iA].Tangent, Surf1.Vertices[iB].Tangent, f);
    spawn := spawn or (vec_spacing(midTangent, Surf2.Vertices[iMid].Tangent) > EPSILON_TJUNC);

    midTexCoord := vec_lerp(Surf1.Vertices[iA].TexCoord, Surf1.Vertices[iB].TexCoord, f);
    spawn := spawn or (vec_spacing(midTexCoord, Surf2.Vertices[iMid].TexCoord) > EPSILON_TJUNC);

     vert.Position := Test.Surf.Vertices[iMid].Position;
    vert.TexCoord := midTexCoord;
      vert.LM_TexCoord := NullVector2f;
      vert.Tangent := midTangent;
      vert.Binormal := midBinormal;
      vert.Normal := midNormal;
      vert.Color := vec_make(255, 255, 255, 255);

      Result := Candidate.Surf.AddVertex(vert);
  end;

  function FindTJunction(Candidate: PJuncCandidate; iA, iB, iC: Integer; out Junc: Integer): Boolean;
  var
    i, j: Integer;
    item: PJuncCandidate;
    vA, vB, vC, test: PVector3f;
    boxMin, boxMax, vector, invVector: TVector3f;
    f: TVector3f;
  begin
    Result := False;

    vA := @Candidate.Surf.Vertices[Candidate.OriginalElems[iA]].Position;
    vB := @Candidate.Surf.Vertices[Candidate.OriginalElems[iB]].Position;
    vC := @Candidate.Surf.Vertices[Candidate.OriginalElems[iC]].Position;

  // compute bounding box of the segment
    boxMin:=vA^;
    vec_min(boxMin, vB^);
    boxMax:=vA^;
    vec_max(boxMax, vB^);

  // compute extent and its inversion
    vector := vec_sub(vB^, vA^);
    for i:=0 to 2 do
      if vector[i] <> 0 then
        invVector[i]:= 1 / vector[i]
      else
        invVector[i]:=0;

  // lookup all candidates
    for i:=0 to CandidateList.Count-1 do
    begin
      item := CandidateList.Items[i];

      if item = Candidate then Continue;

      for j:=0 to item.NumElems-1 do
      begin
        test := @item.Surf.Vertices[item.OriginalElems[j]].Position;

     {   if vec_equals(test^, vA^) or
           vec_equals(test^, vB^) or
           vec_equals(test^, vC^) then Continue;  }

        if (test^[0] > boxMin[0]) and (test^[1] > boxMin[1]) and (test^[2] > boxMin[2]) and
           (test^[0] < boxMax[0]) and (test^[1] < boxMax[1]) and (test^[2] < boxMax[2]) then
        begin
          f := vec_multiply(vec_sub(test^, vA^), invVector);

          if (Abs(f[0]-f[1]) < EPSILON_TJUNC) and
             (Abs(f[0]-f[2]) < EPSILON_TJUNC) and
             (Abs(f[1]-f[2]) < EPSILON_TJUNC) then
          begin
            Result := True;
            Junc := AddLerpIfDistinct(Candidate, item, iA, iB, j);
            Break;
          end;
        end;
      end;
    end;
  end;

var
  i, j, k, l, m, n, tj: Integer;
  NumElems: Cardinal;
  MarkList: TList;
  Surf: TSurface;
  candidate: PJuncCandidate;
begin
  StartWork('Fixing TJunctions...');

  CandidateList := TList.Create;
  MarkList := TList.Create;

  try
    for i:=0 to World.EntityCount-1 do
    for j:=0 to World.Entities[i].BrushCount-1 do
    for k:=0 to World.Entities[i].Brushes[j].SideCount-1 do
    for l:=0 to World.Entities[i].Brushes[j].Sides[k].SurfaceCount-1 do
    begin
      Surf := World.Entities[i].Brushes[j].Sides[k].Surfaces[l];

      GetMem(candidate, SizeOf(TJuncCandidate));
      candidate.Surf := Surf;
      candidate.NumElems := Surf.ElementCount;
      GetMem(candidate.OriginalElems, candidate.NumElems * SizeOf(Cardinal));
      Move(Surf.GetElementsAsAddress^, candidate.OriginalElems^, candidate.NumElems * SizeOf(Cardinal));
      CandidateList.Add(candidate);

      Inc(NumElems, candidate.NumElems);
    end;

    for i:=0 to CandidateList.Count-1 do
    begin
      Surf := PJuncCandidate(CandidateList.Items[i])^.Surf;

      MarkList.Clear;
      for j:=0 to Surf.ElementCount-1 do
        MarkList.Add(Pointer(1));

      j:=0;
      while j < Surf.ElementCount do
      begin
        if Cardinal(MarkList.Items[j]) <> 0 then
        begin
          if FindTJunction(candidate,
                           Surf.Elements[j+0],
                           Surf.Elements[j+1],
                           Surf.Elements[j+2],
                           tj) then
          begin
            Surf.AddElement(tj, Surf.Elements[j+1], Surf.Elements[j+2]);
            MarkList.Add(Pointer(1));
            MarkList.Add(Pointer(1));
            MarkList.Add(Pointer(0));
            Surf.Elements[j+1] := tj;
            MarkList.Items[j+1] := Pointer(0);
            Continue;
          end;
        end;

        if Cardinal(MarkList.Items[j+1]) <> 0 then
        begin
          if FindTJunction(candidate,
                           Surf.Elements[j+1],
                           Surf.Elements[j+2],
                           Surf.Elements[j+0],
                           tj) then
          begin
            Surf.AddElement(tj, Surf.Elements[j+2], Surf.Elements[j+0]);
            MarkList.Add(Pointer(1));
            MarkList.Add(Pointer(1));
            MarkList.Add(Pointer(0));
            Surf.Elements[j+2] := tj;
            MarkList.Items[j+2] := Pointer(0);
            Continue;
          end;
        end;

        if Cardinal(MarkList.Items[j+2]) <> 0 then
        begin
          if FindTJunction(candidate,
                           Surf.Elements[j+2],
                           Surf.Elements[j+0],
                           Surf.Elements[j+1],
                           tj) then
          begin
            Surf.AddElement(tj, Surf.Elements[j+0], Surf.Elements[j+1]);
            MarkList.Add(Pointer(1));
            MarkList.Add(Pointer(1));
            MarkList.Add(Pointer(0));
            Surf.Elements[j] := tj;
            MarkList.Items[j] := Pointer(0);
            Continue;
          end;
        end;

        Inc(j, 3);
      end;

      Progress(Trunc(100 * (i+1) / CandidateList.Count-1)));
    end;
  finally
  // we are eating too much memory, so don't forget free some stuff
    while CandidateList.Count > 0 do
    begin
      candidate := CandidateList.Items[0];
      if Assigned(candidate) then
      begin
        if Assigned(candidate^.OriginalElems) then
          FreeMem(candidate^.OriginalElems);

        FreeMem(candidate);
      end;
      CandidateList.Delete(0);
    end;

    CandidateList.Free;
    MarkList.Free;
  end;

  EndWork; *)
end;

function TBSPProcess.SubdivideSurface(Surf: TPlanarSurface; Poly: TPolygon;
  Subdivisions: Single): Integer;
var
  axis, n: Integer;
  origin: TVector3f;
  plane: TPlane;
  deltaMin, deltaMax: Single;
  aabb: TAABB;
  front, back, newPoly: TPolygon;
begin
  Result := 0;

  newPoly := Poly;

  aabb := Poly.GetAABB;

  axis := 0;
  while axis < 3 do
  begin
    deltaMin := Floor(aabb.Mins[axis] / Subdivisions) * Subdivisions;
    deltaMax := Ceil(aabb.Maxs[axis] / Subdivisions) * Subdivisions;

    if (deltaMax - deltaMin) > Subdivisions then
    begin
      vec_clear(origin);
      vec_clear(plane.Normal);
      origin[axis] := deltaMin + Subdivisions;
      plane.Normal[axis] := -1;
      plane.Dist := -vec_dot(origin, plane.Normal);

      Poly.Split(plane, EPSILON_ON_SIDE, front, back);

      if not Assigned(front) then
        newPoly := back
      else if not Assigned(back) then
        newPoly := front
      else
      begin
        n := SubdivideSurface(Surf, front, Subdivisions);
        n := n + SubdivideSurface(Surf, back, Subdivisions);
        Result := n;
        Exit;
      end;
    end;

    Inc(axis);
  end;

  if Assigned(newPoly) then
  begin
    Surf.Side.BuildSurfaceForPolygon(newPoly);
    Result := 1;
    newPoly.Free;
  end;
end;

procedure TBSPProcess.SubdivideSurfaces;
var
  i, j: Integer;
  surf: TPlanarSurface;
  poly: TPolygon;
  tessSize, sampleSize: Single;
  surfList: TList;
  oldSurfCount, newSurfCount: Integer;
begin
  StartWork('Subdividing surfaces...');

  oldSurfCount := 0;
  newSurfCount := 0;

  surfList := TList.Create;

  try
  // cache surface pointers in the list
    for i:=0 to World.EntityCount-1 do
    begin
      for j:=0 to World.Entities[i].SurfaceCount-1 do
      begin
        if World.Entities[i].Surfaces[j].SurfaceType <> stPlanar then Continue;

        surfList.Add(World.Entities[i].Surfaces[j]);
      end;

      oldSurfCount := oldSurfCount + World.Entities[i].SurfaceCount;
    end;

  // use "fixed" size surface reference list for accessing original surfaces
    for i:=0 to surfList.Count-1 do
    begin
      surf := (TSurface(surfList.Items[i]) as TPlanarSurface);

      poly := surf.GetPolygon;

  // determine lightmap sampling size
    if surf.Material.LightmapSampleSize > 0 then
      sampleSize := surf.Material.LightmapSampleSize
    else
      sampleSize := World.LightmapSampleSize;

    // don't forget one pixel lightmap borders!!!
      tessSize := MinFloat((World.LightmapWidth-2) * sampleSize,
                           (World.LightmapHeight-2) * sampleSize);
      if tessSize > surf.Material.Subdivisions then
        tessSize := surf.Material.Subdivisions;

      if tessSize < 1 then
        tessSize := 1;

      newSurfCount := newSurfCount + SubdivideSurface(surf, poly, tessSize);

      surf.Side.RemoveSurface(surf);

      Progress(Trunc(100 * (i+1) / surfList.Count));
    end;
  finally
    surfList.Free;
  end;

  EndWork;
  PrintMessage('%6d new surfaces created', [newSurfCount-oldSurfCount]);
end;

end.
