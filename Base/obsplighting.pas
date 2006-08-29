//
//  Project     : OpenBSP Map Compiler
//  Unit        : obspLighting.pas
//  Description : Lighting
//  History     :
//    07/01/05 - OT - New lightmapping algorithm (extra subsampling)
//    04/11/04 - OT - DoMarkSurfaces code moved in PrepareLighting
//    03/11/04 - OT - Lights are saving to external file as "MapFile_LM0.bmp"
//    15/10/04 - OT - More faster lighting on linear lights
//    08/10/04 - OT - Fixed PerturbNormal routine
//                    A bit faster lighting
//    12/09/04 - OT - PerturbNormal added
//                    Bumpmapped lighting
//    27/08/04 - OT - Added light jittering
//                    Added light scale key (SoF2)
//    26/08/04 - OT - Added -nolightmap option
//    18/08/04 - OT - Fixed some thread-safe stuff
//    14/08/04 - OT - Added basic support for Doom3 light entities
//    10/08/04 - OT - Added linear light support
//    25/07/04 - OT - Added lightmap borders
//    13/07/04 - OT - Added multi-threading supports
//    03/07/04 - OT - Added extra lighting method
//    02/07/04 - OT - Lightmapping
//    27/06/04 - OT - Creation
//
unit obspLighting;

interface

uses SysUtils, Classes, obspBaseTypes, obspBaseCompiler, obspMapClasses,
  obspMultiThreading, Graphics, obspPolygon, obspTexture, obspTrace;

const
  DEFAULT_LIGHT_INHIBITRADIUS = 1.5;
  MIN_LIGHT_SUBSAMPLES        = 1;
  MAX_LIGHT_SUBSAMPLES        = 8;

type
  PLight = ^TLight;
  TLight = packed record
    Origin: TVector3f;
    LinearLight: Boolean;
    Photons: Single;
    Radius: Single;  // simulates Doom3 style lighting (ellipsoidal)
    NoShadows: Boolean; // act as Doom3 style light
    Color: TVector3f;
  end;

  PLightingWork = ^TLightingWork;
  TLightingWork = packed record
    Surface: TSurface;
    Lights: TList;
    TraceObj: TTraceObject;
    Bounds: TAABB;
  end;

  PLightmapSpot = ^TLightmapSpot;
  TLightmapSpot = array[0..MAX_LIGHTMAP_HEIGHT-1] of Integer;

  TLightingProcess = class(TBaseCompiler)
  private
    FLights: TList;
    FNumRayCasted: Integer;
    FCulledSurfCount: Integer;
    FWorkList: TList; // includes world surfaces
    FLightScale: Single;
    FAmbientColor: TVector3f;
    FLightmapSpots: array of TLightmapSpot; // count equals World.LightmapCount
    FSubSamples: Integer;
    FSaveLightmaps: Boolean;
    FNoShadows: Boolean;
    FNoLightmaps: Boolean;
    procedure SetSubSamples(Value: Integer);
  protected
  // returns lightmap index
    function AllocateLightmapBlock(const Width, Height: Integer;
                                   out Left, Top: Integer): Integer;

    procedure ClearLights;
    procedure PrepareLighting;

  // returns how many lights don't effect this point (in-shadow),
  // "Contribution" is sum of illumination (not normalized)
    function LightContributionToPoint(const Work: PLightingWork;
                                      const Origin, Normal: TVector3f;
                                      const NoShadows: Boolean;
                                      var Contribution: TVector3f): Integer;
    procedure DoCreateLightmapCoords(WorkIndex: Integer);
    procedure DoCreateTracingStructure(WorkIndex: Integer);
    procedure DoLightmapping(WorkIndex: Integer);
    procedure DoVertexLighting(WorkIndex: Integer);
    function PerturbNormal(Texture: PTexture;
                           TexCoord: TVector2f;
                           Tangent, Binormal, Normal: TVector3f;
                           out N: TVector3f): Boolean;
  public
    constructor Create(const AManager: TBaseCompilerManager;
                       const AOwner: TBaseCompilerObject); override;
    destructor Destroy; override;

    procedure LightWorld(const OutputFile: String);

    property NoLightmaps: Boolean read FNoLightmaps write FNoLightmaps;
    property SaveLightmaps: Boolean read FSaveLightmaps write FSaveLightmaps;
    property SubSamples: Integer read FSubSamples write SetSubSamples;
    property NoShadows: Boolean read FNoShadows write FNoShadows;
  end;

implementation

uses obspMath, obspMaterial, obspSurfPlanar;

{ TLightingProcess }

function TLightingProcess.AllocateLightmapBlock(const Width,
  Height: Integer; out Left, Top: Integer): Integer;
var
  maxwidth, rowwidth: Integer;
  i, y, py: Integer;
  block: PLightmapSpot;
begin
// block other threads, because we may allocate new lightmaps
  LockMultiThreading;

  try
    for i:=0 to World.LightmapCount-1 do
    begin
      block := @FLightmapSpots[i];

      maxwidth := World.LightmapWidth;

      for y:=0 to World.LightmapHeight-Height do
      begin
        rowwidth := 0;

        for py:=0 to Height-1 do
        begin
          if block^[y+py] >= maxwidth then
            Break;

          if block^[y+py] > rowwidth then
            rowwidth := block^[y+py];
        end;

        if py = Height then
        begin
          Left := rowwidth;
          Top := y;
          maxwidth := rowwidth;
        end;
      end;

      if maxwidth + Width > World.LightmapWidth then
        Continue;

      for y:=0 to Height-1 do
        block^[Top+y] := maxwidth + Width;

      Result := i;
      UnlockMultiThreading;
      Exit;
    end;
  except
    UnlockMultiThreading;
  end;

  try
    Top := 0;
    Left := 0;
    Result := World.NewLightmap;
    SetLength(FLightmapSpots, World.LightmapCount);
    for y := 0 to Height-1 do
      FLightmapSpots[Result][y] := Width;
  finally
    UnlockMultiThreading;
  end;
end;

constructor TLightingProcess.Create(const AManager: TBaseCompilerManager;
  const AOwner: TBaseCompilerObject);
begin
  inherited;
  FSubSamples := 1;
  FNoShadows := False;
  FNoLightmaps := False;
  FLights := TList.Create;
end;

destructor TLightingProcess.Destroy;
begin
  ClearLights;
  FLights.Free;
  inherited;
end;

procedure TLightingProcess.DoCreateLightmapCoords(WorkIndex: Integer);
var
  Surf: TPlanarSurface;
  i, j: Integer;
  f, sampleSize: Single;
  p: TVector3f;
  mins, maxs, delta, coord: TVector2f;
  planes: array[0..1] of TPlane;
begin
  if PLightingWork(FWorkList.Items[WorkIndex])^.Surface.SurfaceType <> stPlanar then Exit;

  Surf := (PLightingWork(FWorkList.Items[WorkIndex])^.Surface as TPlanarSurface);

// Mostly, nearest axial axis is choosing for lightmap projection
// But, we use "real" tangent space lightmap projection
// So, lightmap quality must be much better than the others

// get S and T planes
  planes[0] := plane_make(Surf.Side.Tangent, Surf.Side.Origin);
  planes[1] := plane_make(Surf.Side.Binormal, Surf.Side.Origin);

// find surface "bounding rect" via testing each point with S and T planes
  for i:=0 to 1 do
  begin
    mins[i]:=MAX_WORLD_COORD;
    maxs[i]:=MIN_WORLD_COORD;
  end;

  for i:=0 to Surf.VertexCount-1 do
  begin
    for j:=0 to 1 do
    begin
      f := plane_evaluatepoint(planes[j], Surf.Vertices[i].Position);

      if f < mins[j] then
        mins[j] := f;

      if f > maxs[j] then
        maxs[j] := f;
    end;
  end;

// find lightmap origin
  p := vec_combine(Surf.Side.Origin, Surf.Side.Tangent, mins[0]);
  Surf.LightmapOrigin := vec_combine(p, Surf.Side.Binormal, mins[1]);

// get lightmapping density
  delta[0] := (maxs[0]-mins[0]);
  delta[1] := (maxs[1]-mins[1]);

// determine sampling size
  if Surf.Material.LightmapSampleSize > 0 then
    sampleSize := Surf.Material.LightmapSampleSize
  else
    sampleSize := World.LightmapSampleSize;

// feed lightmap parameters to surface
  Surf.LightmapWidth := Trunc(delta[0] / sampleSize);
  Surf.LightmapHeight := Trunc(delta[1] / sampleSize);

// leave one pixel border for avoiding texture filtering artifacts
  if Surf.LightmapWidth <= 0 then
    Surf.LightmapWidth := 1
  else if (Surf.LightmapWidth + 2) > World.LightmapWidth then
    Surf.LightmapWidth := World.LightmapWidth - 2;

  if Surf.LightmapHeight <= 0 then
    Surf.LightmapHeight := 1
  else if (Surf.LightmapHeight + 2) > World.LightmapHeight then
    Surf.LightmapHeight := World.LightmapHeight - 2;
    
// allocate a new lightmap if necessary
  if FNoLightmaps then // full bright lightmap
  begin
    Surf.LightmapIndex := 0; // point full bright lightmap
    i := 0;
    j := 0;
  end
  else
    Surf.LightmapIndex := AllocateLightmapBlock(Surf.LightmapWidth + 2, Surf.LightmapHeight + 2, i, j);

// locate in the lightmap
  Surf.LightmapOffsetX := i + 1;
  Surf.LightmapOffsetY := j + 1;
  Surf.LightmapVectorS := sampleSize;
  Surf.LightmapVectorT := sampleSize;

// move S and T vectors to lightmap origin in world space
  planes[0] := plane_make(Surf.Side.Tangent, Surf.LightmapOrigin);
  planes[1] := plane_make(Surf.Side.Binormal, Surf.LightmapOrigin);

// generate lightmap coordinates with S and T planes
  for i:=0 to Surf.VertexCount-1 do
  begin
    p := Surf.Vertices[i].Position;

    coord[0] := (plane_evaluatepoint(planes[0], p) / delta[0]);
    coord[1] := (plane_evaluatepoint(planes[1], p) / delta[1]);

    coord[0] := (Surf.LightmapOffsetX + (coord[0] * Surf.LightmapWidth)) / World.LightmapWidth;
    coord[1] := (Surf.LightmapOffsetY + (coord[1] * Surf.LightmapHeight)) / World.LightmapHeight;

    Surf.Vertices[i].LM_TexCoord := coord;
  end;
end;

procedure TLightingProcess.DoCreateTracingStructure(WorkIndex: Integer);
var
  work: PLightingWork;
  light: PLight;
  surf: TSurface;
  f: Single;
  plane1, plane2: TPlane;
  i, p1, p2: Integer;
begin
  work := PLightingWork(FWorkList.Items[WorkIndex]);

// mark this surface by all affected lights
  for i:=0 to FLights.Count-1 do
  begin
    light := PLight(FLights.Items[i]);

  // back-faced lights
    if (work.Surface.SurfaceType = stPlanar) then
    begin
      plane1 := (work.Surface as TPlanarSurface).Side.Plane;
      f := plane_evaluatepoint(plane1, light^.Origin);

    // on true side?
      if (f >= 0) then
      begin
      // Linear light? Check it with light bound
        if (light.LinearLight) then
        begin
          if (f < light.Radius) then
          begin
            work.Lights.Add(light);
            aabb_addpoint(work.Bounds, light.Origin);
          end;
        end
        else
        begin
          work.Lights.Add(light);
          aabb_addpoint(work.Bounds, light.Origin);
        end;
      end;
    end
    else
    begin
      work.Lights.Add(light);
      aabb_addpoint(work.Bounds, light.Origin);
    end;
  end;

  // setup trace object
  work.TraceObj := TTraceObject.Create(World, work.Bounds);

  // cull some surfaces
  if work.Surface.SurfaceType = stPlanar then
  begin
    for i:=work.TraceObj.OccluderCount-1 downto 0 do
    begin
      surf := work.TraceObj.Occluders[i];
      if surf.SurfaceType <> stPlanar then Continue;

      p1 := (work.Surface as TPlanarSurface).Side.PlaneIndex;
      p2 := (surf as TPlanarSurface).Side.PlaneIndex;
      plane1 := World.Planes[p1];
      plane2 := World.Planes[p2];

    // c planes can't cast shadows
      if p1 = p2 then
        work.TraceObj.DeleteOccluder(i)
      else if (vec_dot(plane1.Normal, plane2.Normal) > 0.999) and
              (plane1.Dist < plane2.Dist) then
        work.TraceObj.DeleteOccluder(i);
    end;
  end;

  if work.Lights.Count = 0 then
    LockedIncrement(FCulledSurfCount); // any light doesn't effect this surface lighting
end;

procedure TLightingProcess.DoLightmapping(WorkIndex: Integer);
var
  i: Integer;
  offsetS, offsetT, samplingFactor, factorS, factorT: Single;
  x, y, px, py, subx, suby, samples, occludedLights: Integer;
  origin, uv, color, luxel, normal: TVector3f;
  st: TVector2f;
  border: TVector3b;
  block: PVector3bArray;
  work: PLightingWork;
  side: TBrushSide;
  surf: TPlanarSurface;
  normalmapped: Boolean;
begin
  work := PLightingWork(FWorkList.Items[WorkIndex]);
  if work^.Surface.SurfaceType <> stPlanar then Exit;

  surf := (work^.Surface as TPlanarSurface);
  side := surf.Side;

  block := World.Lightmaps[Surf.LightmapIndex];

  if work^.Lights.Count > 0 then
  begin
    normalmapped := ((Side.Material.Normalmap.Width > 0) and
                     (Side.Material.Normalmap.Height > 0) and
                     (Assigned(Side.Material.Normalmap.Pixels)));

    samplingFactor := (1 / FSubSamples);
    factorS := Surf.LightmapVectorS * samplingFactor;
    factorT := Surf.LightmapVectorT * samplingFactor;
    offsetS := factorS * 0.5;
    offsetT := factorT * 0.5;

    for y:=0 to Surf.LightmapHeight-1 do
    for x:=0 to Surf.LightmapWidth-1 do
    begin
      vec_clear(color);
      samples := 0;

      for suby := 0 to FSubSamples-1 do
      begin
        for subx := 0 to FSubSamples-1 do
        begin
          origin := vec_combine(Surf.LightmapOrigin, Side.Tangent, (x * FSubSamples + subx) * factorS + offsetS);
          origin := vec_combine(origin, Side.Binormal, (y * FSubSamples + suby) * factorT + offsetT);

          if normalmapped then
          begin
            uv := vec_transform(origin, side.TextureMatrix);
            st[0] := uv[0];
            st[1] := uv[1];

            if not PerturbNormal(@Side.Material.Normalmap, st, Side.Tangent, Side.Binormal, Side.Normal, normal) then
              normal := side.Normal;
          end
          else
            normal := side.Normal;

        // trace againts all geometry
          occludedLights := LightContributionToPoint(work, origin, normal, FNoShadows, luxel);

          if Surf.Material.SaturateLighting then
            luxel := vec_saturate(luxel)
          else
            luxel := vec_normalizecolor(luxel);

          color := vec_add(color, luxel);

          Inc(samples);
        end;
      end;

      if samples > 0 then
        color := vec_scale(color, 1 / samples);

      px := x + Surf.LightmapOffsetX;
      py := y + Surf.LightmapOffsetY;
 
      block^[py * World.LightmapWidth + px][0] := Trunc(color[0] * 255);
      block^[py * World.LightmapWidth + px][1] := Trunc(color[1] * 255);
      block^[py * World.LightmapWidth + px][2] := Trunc(color[2] * 255);

      border := block^[py * World.LightmapWidth + px];

    // copy lines
      if (x = 0) then
        block^[py * World.LightmapWidth + px-1] := border
      else if (x = Surf.LightmapWidth-1) then
        block^[py * World.LightmapWidth + px+1] := border;

      if (y = 0) then
        block^[(py-1) * World.LightmapWidth + px] := border
      else if (y = Surf.LightmapHeight-1) then
        block^[(py+1) * World.LightmapWidth + px] := border;

    // check corners
      if (x = 0) and (y = 0) then
        block^[(py-1) * World.LightmapWidth + px-1] := border
      else if (x = Surf.LightmapWidth-1) and (y = 0) then
        block^[(py-1) * World.LightmapWidth + px+1] := border
      else if (x = Surf.LightmapWidth-1) and (y = Surf.LightmapHeight-1) then
        block^[(py+1) * World.LightmapWidth + px+1] := border
      else if (x = 0) and (y = Surf.LightmapHeight-1) then
        block^[(py+1) * World.LightmapWidth + px-1] := border;
    end;
  end
  else
  begin
    border[0] := Trunc(FAmbientColor[0] * 255);
    border[1] := Trunc(FAmbientColor[1] * 255);
    border[2] := Trunc(FAmbientColor[2] * 255);

    for y:=-1 to Surf.LightmapHeight do
    for x:=-1 to Surf.LightmapWidth do
    begin
      px := x + Surf.LightmapOffsetX;
      py := y + Surf.LightmapOffsetY;

      PWord(@block^[py * World.LightmapWidth + px])^ := PWord(@border[0])^;
      block^[py * World.LightmapWidth + px][2] := border[2];
    end;
  end;
end;

procedure TLightingProcess.DoVertexLighting(WorkIndex: Integer);
var
  i: Integer;
  color: TVector3f;
  surf: TSurface;
  work: PLightingWork;
begin
  work := PLightingWork(FWorkList.Items[WorkIndex]);
  surf := work^.Surface;
  for i:=0 to surf.VertexCount-1 do
  begin
    LightContributionToPoint(work, surf.Vertices[i].Position,
                             surf.Vertices[i].Normal, True, color);

    if surf.Material.SaturateLighting then
      color := vec_saturate(color)
    else
      color := vec_normalizecolor(color);

    surf.Vertices[i].Color[0] := Trunc(color[0] * 255);
    surf.Vertices[i].Color[1] := Trunc(color[1] * 255);
    surf.Vertices[i].Color[2] := Trunc(color[2] * 255);
    surf.Vertices[i].Color[3] := 255;
  end;
end;

function TLightingProcess.LightContributionToPoint(const Work: PLightingWork;
  const Origin, Normal: TVector3f; const NoShadows: Boolean;
  var Contribution: TVector3f): Integer;
var
  i: Integer;
  light: PLight;
  f, dist: Single;
  delta, sum, dir: TVector3f;
  occluded: Integer;
begin
  LockedIncrement(FNumRayCasted, Work.Lights.Count); //thread-safe increment

  sum := FAmbientColor;
  occluded := 0;

  for i:=0 to Work.Lights.Count-1 do
  begin
    light := PLight(Work.Lights.Items[i]);

  // back faced point
    if vec_dot(light.Origin, Normal) - vec_dot(Origin, Normal) < 0 then
      Continue;

  // calculate delta and direction
    delta := vec_sub(light.Origin, Origin);
    dist := vec_normalizesafe(delta, dir);

    if (light.LinearLight) and (dist > light.Radius) then // fast reject for linear lights
      Continue;

    if (not NoShadows) and (not light.NoShadows) then
    begin
    // run trace
      if Work.TraceObj.Trace(Origin, dir, dist, DEFAULT_LIGHT_INHIBITRADIUS) then
      begin
      // occluded by the geometry
        Inc(occluded);
        Continue;
      end;
    end;

  // real illumination equation for point lights -> (I / (d ^ 2) * cosx)
  // quadratic linear falloff -> (1 - ((d ^ 2) / (r ^ 2)))
    if light.LinearLight then
      f := 1 - ((dist * dist) / (light.Radius * light.Radius))
    else
      f := (light.Photons / (dist * dist));

  // shade illumination by the angle
    f := f * vec_dot(dir, Normal);

    if f <= 0 then
      Continue;

    sum := vec_combine(sum, light.Color, f);
  end;

  Contribution := sum;
  Result := occluded;
end;

procedure TLightingProcess.LightWorld(const OutputFile: String);
var
  i, x, y: Integer;
  candidateCount: Integer;
  avgOccluder: Extended;
  sumOccluder: Int64; // must be in high range
  pDest, pSrc: PVector3bArray;
  work: PLightingWork;
  bitmap: TBitmap;
begin
  FWorkList := TList.Create;
  World.ClearLightmaps;
// In q3map light scaling is 7500
// But, we are using [0..1] range
// instead of [0..255] for lighting
  FLightScale := 7500 / 255;

  PrepareLighting;

  FCulledSurfCount := 0;

  RunWorkOnMultiThreading('Creating tracing structure...',
                          'Finished',
                          FWorkList.Count,
                          DoCreateTracingStructure,
                          Manager.DisableMP);

// emit some statistics
  sumOccluder := 0;
  for i:=0 to FWorkList.Count-1 do
  begin
    work := PLightingWork(FWorkList.Items[i]);
    if (work.Lights.Count = 0) then Continue;

    sumOccluder := sumOccluder + work.TraceObj.OccluderCount;
  end;

  candidateCount := (FWorkList.Count - FCulledSurfCount);
  avgOccluder := sumOccluder / candidateCount;
  PrintMessage('%5d surfaces for direct lighting', [candidateCount]);
  PrintMessage('%5d surfaces culled', [FCulledSurfCount]);
  PrintMessage('%5d avarage occluder per surface (%.1f%%)', [Round(avgOccluder), (avgOccluder / candidateCount) * 100]);

  FNumRayCasted := 0;

  RunWorkOnMultiThreading('Vertex Lighting...',
                          'Finished',
                          FWorkList.Count,
                          DoVertexLighting,
                          Manager.DisableMP);

  PrintMessage('%8d rays casted', [FNumRayCasted]);

  if FNoLightmaps then
  begin
    AllocateLightmapBlock(World.LightmapWidth, World.LightmapHeight, x, y);
    pDest := World.Lightmaps[0];
    FillChar(pDest^, World.LightmapWidth * World.LightmapHeight * 3, 255);
  end;

  RunWorkOnMultiThreading('Preparing surfaces for lightmapping...',
                          'Finished',
                          FWorkList.Count,
                          DoCreateLightmapCoords,
                          Manager.DisableMP);
  PrintMessage('%8d lightmaps allocated', [World.LightmapCount]);

  if not FNoLightmaps then
  begin
    FNumRayCasted := 0;

    RunWorkOnMultiThreading('Lightmapping...',
                            'Finished',
                            FWorkList.Count,
                            DoLightmapping,
                            Manager.DisableMP);

    PrintMessage('%8d rays casted', [FNumRayCasted]);
  end;

// save memory  
  ClearLights;
  FLightmapSpots := nil;
  
  while FWorkList.Count > 0 do
  begin
    work := PLightingWork(FWorkList.Items[0]);
    work^.TraceObj.Free;
    work^.Lights.Free;
    FWorkList.Delete(0);
  end;

  FWorkList.Free;

// save lightmaps if necessary
  if FSaveLightmaps then
  begin
    StartWork('Saving lightmaps...');
    bitmap := TBitmap.Create;
    bitmap.Width := World.LightmapWidth;
    bitmap.Height := World.LightmapHeight;
    bitmap.PixelFormat := pf32bit;

    for i:=0 to World.LightmapCount-1 do
    begin
      for y:=0 to World.LightmapHeight-1 do
      begin
        pSrc := @World.Lightmaps[i][y * World.LightmapWidth];
        pDest := bitmap.ScanLine[y];
        for x:=0 to World.LightmapWidth-1 do
        begin
          pDest^[x][0] := pSrc^[x][2];
          pDest^[x][1] := pSrc^[x][1];
          pDest^[x][2] := pSrc^[x][0];
        end;
      end;

      bitmap.SaveToFile(ChangeFileExt(OutputFile, Format('_LM%d.bmp', [i])));
      Progress(Trunc(100 * (i+1) / World.LightmapCount));
    end;

    bitmap.Free;
    EndWork;
  end;
end;

function TLightingProcess.PerturbNormal(Texture: PTexture;
  TexCoord: TVector2f; Tangent, Binormal,
  Normal: TVector3f; out N: TVector3f): Boolean;
const
  PERTURB_FACTOR = 1 / 127.5;
var
  pixel: TVector4b;
  bump: TVector3f;
begin
  Result := False;

  if not Assigned(Texture) then Exit;
  
  if (Texture.Width <= 0) or
     (Texture.Height <= 0) or
      not Assigned(Texture.Pixels) then
    Exit;

  pixel := SampleTexture(Texture, TexCoord);

// remap normal from [0, 255] to [-1, +1]
  bump[0] := (pixel[0] - 127) * PERTURB_FACTOR;
  bump[1] := (pixel[1] - 127) * PERTURB_FACTOR;
  bump[2] := (pixel[2] - 127) * PERTURB_FACTOR;

// transform bump
  N[0] := bump[0] * Tangent[0] + bump[1] * Binormal[0] + bump[2] * Normal[0];
  N[1] := bump[0] * Tangent[1] + bump[1] * Binormal[1] + bump[2] * Normal[1];
  N[2] := bump[0] * Tangent[2] + bump[1] * Binormal[2] + bump[2] * Normal[2];

  Result := (vec_normalizesafe(N, N) > 0);
end;

procedure TLightingProcess.ClearLights;
var P: Pointer;
begin
  while FLights.Count > 0 do
  begin
    P := FLights.Items[0];
    FreeMem(P);
    FLights.Delete(0);
  end;
end;

procedure TLightingProcess.PrepareLighting;
var
  i, j: Integer;
  work: PLightingWork;
  light, light2: PLight;
  ent: TEntity;
  radius: TVector3f;
  intensity, f, deviance: Single;
  numSamples: Integer;
begin
  StartWork('Preparing world for lighting...');
  ClearLights;
  FWorkList.Clear;

// take worldspawn arguments
  FAmbientColor := World.WorldSpawn.VectorForKey('_color');
  FAmbientColor := vec_normalizecolor(vec_scale(FAmbientColor, World.WorldSpawn.FloatForKey('ambient') / 255));

  for i:=0 to World.EntityCount-1 do
  begin
    ent := World.Entities[i];
    if SameText(ent.ValueForKey('classname'), 'light') then
    begin
      GetMem(light, SizeOf(TLight));
      FLights.Add(light);
      FillChar(light^, SizeOf(TLight), 0);

    // default values
      intensity := 300; // Quake3 default
      deviance := 0;
      numSamples := 1;

      light^.Origin := ent.VectorForKey('origin');

    // decide lighting model
      if ent.IsKeyExists('light_radius') then // Doom3
      begin
        radius := ent.VectorForKey('light_radius');
        light^.Radius := MaxFloat(radius[0], radius[1]);
        light^.Radius := MaxFloat(radius[2], light^.Radius);
        light^.LinearLight := True;
      end
      else if ent.IsKeyExists('light') then // Quake3
        intensity := ent.FloatForKey('light')
      else if ent.IsKeyExists('_light') then // Quake3
        intensity := ent.FloatForKey('_light');

    // get Quake3 lighting flag
      if not ent.IsKeyExists('spawnflags') then
      begin
        light^.LinearLight := (ent.IntForKey('spawnflags') and $01) <> 0;
        light^.Radius := intensity;
      end
      else
        light^.LinearLight := False;

    // get light color
      if ent.IsKeyExists('_color') then
        light^.Color := vec_normalizecolor(ent.VectorForKey('_color'))
      else if ent.IsKeyExists('color') then
        light^.Color := vec_normalizecolor(ent.VectorForKey('color'))
      else
        light^.Color := vec_make(1.0, 1.0, 1.0);

    // get Doom3 specific noshadows parameter
      if ent.IsKeyExists('noshadows') then
        light^.NoShadows := (ent.IntForKey('noshadows') <> 0);

    // get lighting scale factor (SOF2)
      f := ent.FloatForKey('scale');
      if f <= 0 then
        f := 1;

      intensity := intensity * f;

    // get deviance and samples
      if ent.IsKeyExists('_deviance') then
        deviance := ent.FloatForKey('_deviance')
      else if ent.IsKeyExists('_deviation') then
        deviance := ent.FloatForKey('_deviation')
      else if ent.IsKeyExists('_jitter') then
        deviance := ent.FloatForKey('_jitter');

      if ent.IsKeyExists('_samples') then
        numSamples := ent.IntForKey('_samples');

      if (deviance < 0) or (numSamples < 1) then
      begin
        deviance := 0;
        numSamples := 1;
      end;

      intensity := intensity / numSamples;

    // calculate photon density
      intensity := intensity * FLightScale;
      light^.Photons := intensity;

    // jitter the light
      for j:=1 to numSamples-1 do
      begin
      // create a light
        GetMem(light2, SizeOf(TLight));
        FLights.Add(light2);
        FillChar(light2^, SizeOf(TLight), 0);		

        Move(light^, light2^, SizeOf(TLight));

      // jitter it
        light2^.Origin[0] := light^.Origin[0] + (Random * 2.0 - 1.0) * deviance;
        light2^.Origin[1] := light^.Origin[1] + (Random * 2.0 - 1.0) * deviance;
        light2^.Origin[2] := light^.Origin[2] + (Random * 2.0 - 1.0) * deviance;
      end;
    end;

  // prepare surfaces
    for j:=0 to ent.SurfaceCount-1 do
    begin
      if not (cfNoLightmap in ent.Surfaces[j].Material.CompileFlags) then
      begin
        GetMem(work, SizeOf(TLightingWork));
        work^.Surface := ent.Surfaces[j];
        work^.Lights := TList.Create;
        work^.TraceObj := nil; // don't create trace object by default
        aabb_clear(work^.Bounds);
        aabb_addpoint(work^.Bounds, work^.Surface.AABB.Mins);
        aabb_addpoint(work^.Bounds, work^.Surface.AABB.Maxs);
        FWorkList.Add(work);
      end;
    end;

    Progress(Trunc(100 * (i+1) / World.EntityCount));
  end;

  EndWork;

  PrintMessage('%5d point lights', [FLights.Count]);
end;

procedure TLightingProcess.SetSubSamples(Value: Integer);
begin
  if FSubSamples <> Value then
    FSubSamples := Clamp(Value, MIN_LIGHT_SUBSAMPLES, MAX_LIGHT_SUBSAMPLES);
end;

end.
