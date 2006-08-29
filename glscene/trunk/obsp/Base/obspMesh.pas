//
//  Project     : OpenBSP Map Compiler
//  Unit        : obspMesh.pas
//  Description : Embedding routines for all triangle mesh surfaces into map
//  History     :
//    03/01/05 - OT - Added 3D Studio (3DS) file support
//    22/12/04 - OT - Added Quake3 MD3 Model support
//    10/12/04 - OT - Creation
//
unit obspMesh;

interface

uses SysUtils, obspMapClasses;

function EmbedTriangleMeshesIntoWorld(World: TWorld; GamePath: String): Integer;

implementation

uses obspBaseTypes, obspMath, obspFile, File3DS, Types3DS, obspMD3Mesh, obspMD5Mesh,
  obspSurfTriMesh, obspUtils;

// Generates all vertices tangents, binormals, normals
// (Assumes all tangent space vectors are zero vector)
// Also, creates bounding boxes and registers to world object
procedure FinishSurface(World: TWorld; Surf: TTriangleMeshSurface);
var
  i, j: Integer;
  dv: array[0..2] of POBSPVertex;
  stVec: array[0..1] of TVector3f;
  refCount: array of Integer;
  f: Extended;
  t1, t2, t3, t4: Single;
  normal: TVector3f;
begin
  SetLength(refCount, Surf.VertexCount);

  try
  // First Phase: Create tangent space vectors for each triangle and sum
    for i:=0 to (Surf.ElementCount div 3)-1 do
    begin
    // get draw vertex addresses
      for j:=0 to 2 do
        dv[j] := Surf.Vertices[ Surf.Elements[i*3+j] ];

    // calculate two mostly perpendicular edge directions
      stVec[0] := vec_sub(dv[0].Position, dv[1].Position);
      stVec[1] := vec_sub(dv[2].Position, dv[1].Position);

    // we have two edge directions, we can calculate the normal then
      normal := vec_cross(stVec[0], stVec[1]);
      vec_normalizesafe(normal, normal);

      t1 := (dv[1].TexCoord[1] - dv[0].TexCoord[1]);
      t2 := (dv[2].TexCoord[1] - dv[0].TexCoord[1]);
      t3 := (dv[1].TexCoord[0] - dv[0].TexCoord[0]);
      t4 := (dv[2].TexCoord[0] - dv[0].TexCoord[0]);

      for j:=0 to 2 do
      begin
        stVec[0][j] := (t1 * (dv[2].Position[j] - dv[0].Position[j]) - t2 * (dv[1].Position[j] - dv[0].Position[j]));
        stVec[1][j] := (t3 * (dv[2].Position[j] - dv[0].Position[j]) - t4 * (dv[1].Position[j] - dv[0].Position[j]));
      end;

    // keep s\t vectors orthogonal
      for j:=0 to 1 do
      begin
        f := -vec_dot(stVec[j], normal);
        stVec[j] := vec_combine(stVec[j], normal, f);
        vec_normalizesafe(stVec[j], stVec[j]);
      end;

    // inverse tangent vectors if needed
      if vec_dot( vec_cross(stvec[1], stvec[0]), normal) < 0 then
      begin
        vec_negate(stVec[0]);
        vec_negate(stVec[1]);
      end;

      for j:=0 to 2 do
      begin
        dv[j]^.Tangent := vec_add(dv[j].Tangent, stvec[0]);
        dv[j]^.Binormal := vec_add(dv[j].Binormal, stvec[1]);
        dv[j]^.Normal := vec_add(dv[j].Normal, normal);
        Inc(refCount[ Surf.Elements[i*3+j] ]);
      end;
    end;

  // Second Phase: Avarage tangent space vectors
    for i:=0 to Surf.VertexCount-1 do
    begin
      dv[0] := Surf.Vertices[i];

      f := 1 / refCount[i];

      for j:=0 to 2 do
      begin
        dv[0]^.Tangent[j]  := dv[0].Tangent[j] * f;
        dv[0]^.Binormal[j] := dv[0].Binormal[j] * f;
        dv[0]^.Normal[j]   := dv[0].Normal[j] * f;
      end;
    end;
  finally
    refCount := nil;
  end;

  Surf.CalcBounds;
  World.WorldSpawn.AddSurface(Surf);
end;

// 3d Studio (3DS) Mesh Embedding Routine
//
function Embed3DSMeshModel(World: TWorld; Filename: String; Frame: Integer; Location: TMatrix4f): Integer;
var
  surf: TTriangleMeshSurface;
  file3DS: TFile3DS;
  mesh3DS: PMesh3DS;
  vertFlags: array of Boolean;
  dv: TOBSPVertex;
  dvp: POBSPVertex;
  i, j, k, A, B, C, newA, newB, newC, minIndex, maxIndex, numVerts: Integer;
  numTriSurf: Integer;
begin
  numTriSurf := 0;
  Result := 0;

  file3DS := TFile3DS.Create;
  try
    file3DS.LoadFromFile(Filename);

    for i:=0 to file3DS.Objects.MeshCount-1 do
    begin
      mesh3DS := file3DS.Objects.Mesh[i];
      if mesh3DS.IsHidden or (mesh3DS.NVertices < 3) then Continue;
      if (mesh3DS.NTextVerts <= 0) then Continue; // we exactly need texture coordinates
      if (mesh3DS.NMats <= 0) then Continue;      // we exactly need material properties

    // create surfaces for each material group
      for j:=0 to mesh3DS.NMats-1 do
      begin
        surf := TTriangleMeshSurface.Create(World.WorldSpawn, mesh3DS.MatArray[j].NameStr);

      // determine mapping table
        minIndex := 99999999;
        maxIndex := -99999999;

        for k:=0 to mesh3DS.MatArray[j].NFaces-1 do
        begin
        // rotate CWW to CW order
          A := mesh3DS.FaceArray[mesh3DS.MatArray[j].FaceIndex[k]].V3;
          B := mesh3DS.FaceArray[mesh3DS.MatArray[j].FaceIndex[k]].V2;
          C := mesh3DS.FaceArray[mesh3DS.MatArray[j].FaceIndex[k]].V1;

          if minIndex > A then
            minIndex := A;

          if minIndex > B then
            minIndex := B;

          if minIndex > C then
            minIndex := C;

          if maxIndex < A then
            maxIndex := A;

          if maxIndex < B then
            maxIndex := B;

          if maxIndex < C then
            maxIndex := C;
        end;

        numVerts := (maxIndex - minIndex) + 1;
        SetLength(vertFlags, numVerts);
        FillChar(vertFlags[0], SizeOf(Boolean) * numVerts, 0);

        for k:=0 to numVerts-1 do
        begin
        // clear all vertex data and add to list
          dv.Position    := vec_make(0, 0, 0);
          dv.TexCoord    := vec_make(0, 0);
          dv.LM_TexCoord := vec_make(0, 0);
          dv.Tangent     := vec_make(0, 0, 0);
          dv.Binormal    := vec_make(0, 0, 0);
          dv.Normal      := vec_make(0, 0, 0);
          dv.Color       := vec_make(255, 255, 255, 255);         // default lighting value
          surf.AddVertex(dv);
        end;

        for k:=0 to mesh3DS.MatArray[j].NFaces-1 do
        begin
        // rotate CWW to CW order
          A := mesh3DS.FaceArray[mesh3DS.MatArray[j].FaceIndex[k]].V3;
          B := mesh3DS.FaceArray[mesh3DS.MatArray[j].FaceIndex[k]].V2;
          C := mesh3DS.FaceArray[mesh3DS.MatArray[j].FaceIndex[k]].V1;

          newA := A - minIndex;
          newB := B - minIndex;
          newC := C - minIndex;

          if not vertFlags[newA] then
          begin
            dvp := surf.Vertices[newA];
            dvp^.Position := vec_transform(vec_make(mesh3DS.VertexArray[A].X,
                                                    mesh3DS.VertexArray[A].Y,
                                                    mesh3DS.VertexArray[A].Z), Location);
          // invert V component
            dvp^.TexCoord := vec_make(mesh3DS.TextArray[A].U, 1 - mesh3DS.TextArray[A].V);

            vertFlags[newA] := True;
          end;

          if not vertFlags[newB] then
          begin
            dvp := surf.Vertices[newB];
            dvp^.Position := vec_transform(vec_make(mesh3DS.VertexArray[B].X,
                                                    mesh3DS.VertexArray[B].Y,
                                                    mesh3DS.VertexArray[B].Z), Location);
          // invert V component
            dvp^.TexCoord := vec_make(mesh3DS.TextArray[B].U, 1 - mesh3DS.TextArray[B].V);

            vertFlags[newB] := True;
          end;

          if not vertFlags[newC] then
          begin
            dvp := surf.Vertices[newC];
            dvp^.Position := vec_transform(vec_make(mesh3DS.VertexArray[C].X,
                                                    mesh3DS.VertexArray[C].Y,
                                                    mesh3DS.VertexArray[C].Z), Location);
          // invert V component                                                    
            dvp^.TexCoord := vec_make(mesh3DS.TextArray[C].U, 1 - mesh3DS.TextArray[C].V);

            vertFlags[newC] := True;
          end;

          surf.AddElement(newA, newB, newC);
        end;

      // finish surface
        FinishSurface(World, surf);
        Inc(numTriSurf);
      end;
    end;
  finally
    Result := numTriSurf;
    file3DS.Free;
  end;
end;

// Quake 3 MD3 Mesh Model Embedding Routine
//
function EmbedMD3MeshModel(World: TWorld; Filename: String; Frame: Integer; Location: TMatrix4f): Integer;
var
  model: TMD3Model;
  mesh: TMD3Mesh;
  surf: TTriangleMeshSurface;
  shader: PMD3Shader;
  tri: PMD3Triangle;
  vert: PMD3XYZNormal;
  uv: PMD3ST;
  dv: TOBSPVertex;
  i, j: Integer;
  numTriSurf: Integer;
begin
  numTriSurf := 0;
  Result := 0;

// create temporary model holder
  model := TMD3Model.Create;

// try to load geometry with frames
  if not model.LoadFromFile(Filename) then
  begin
    model.Free;
    Exit;
  end;

// clamp frame
  if Frame < 0 then
    Frame := 0
  else if Frame >= model.FrameCount then
    Frame := model.FrameCount-1;

  try
  // convert MD3 Mesh geometry to triangle mesh surface
    for i:=0 to model.MeshCount-1 do
    begin
      mesh := model.GetMesh(i);
      shader := mesh.GetShader(0); // grab first skin
      surf := TTriangleMeshSurface.Create(World.WorldSpawn, Trim(StrPas(PChar(@shader.Name[0]))));

    // add triangles
      for j:=0 to mesh.TriangleCount-1 do
      begin
        tri := mesh.GetTriangle(j);
        surf.AddElement(tri.Indexes[0], tri.Indexes[1], tri.Indexes[2]);
      end;

    // grab the frame and add vertices
      for j:=0 to mesh.VertexCount-1 do
      begin
        vert := mesh.GetVertex(Frame, j);
        uv := mesh.GetTexCoord(j);

      // emit draw vertex
        dv.Position    := vec_transform(vec_make(vert.XYZ[0] * MD3_XYZ_SCALE, // emit vertex position
                                                 vert.XYZ[1] * MD3_XYZ_SCALE,
                                                 vert.XYZ[2] * MD3_XYZ_SCALE), Location);
        dv.TexCoord    := vec_make(uv.ST[0], uv.ST[1]);         // emit texture coordinate
        dv.LM_TexCoord := vec_make(0, 0);                       // triangle mesh surfaces don't use lightmapping
        dv.Tangent     := vec_make(0, 0, 0);                    // invalid tangent vector at the beginning
        dv.Binormal    := vec_make(0, 0, 0);                    // invalid binormal vector at the beginning
        dv.Normal      := vec_make(0, 0, 0);                    // invalid normal vector at the beginning
        dv.Color       := vec_make(255, 255, 255, 255);         // default lighting value
        surf.AddVertex(dv);
      end;

    // finish surface
      FinishSurface(World, surf);
      Inc(numTriSurf);
    end;
  finally
    Result := numTriSurf;
    model.Free;
  end;
end;

// Doom 3 MD5 Mesh Model Embedding Routine (Ignores Frame Argument)
//
function EmbedMD5MeshModel(World: TWorld; Filename: String; Frame: Integer; Location: TMatrix4f): Integer;
var 
  model: TMD5Model;
  mesh: TMD5Mesh;
  i, j, k: Integer;
  surf: TTriangleMeshSurface;
  vert: PMD5Vertex;
  weight: PMD5Weight;
  tri: PMD5Triangle;
  joint: PMD5Joint;
  pos: TVector3f;
  dv: TOBSPVertex;
  mat: TMatrix4f;
  numTriSurf: Integer;
begin
  numTriSurf := 0;
  Result := 0;

// create temporary model holder
  model := TMD5Model.Create;

// try to load geometry
  if not model.LoadFromFile(Filename) then
  begin
    model.Free;
    Exit;
  end;

  try
  // build absolute matrix based on base frame
    model.CalculateAbsoluteMatrices;

  // convert MD5 Mesh geometry to triangle mesh surface
    for i:=0 to model.MeshCount-1 do
    begin
      mesh := model.GetMesh(i);
      surf := TTriangleMeshSurface.Create(World.WorldSpawn, mesh.MaterialName);

    // add triangles
      for j:=0 to mesh.TriangleCount-1 do
      begin
        tri := mesh.GetTriangle(j);
        surf.AddElement(tri.A, tri.B, tri.C);
      end;

    // add blended vertices
      for j:=0 to mesh.VertexCount-1 do
      begin
        vert := mesh.GetVertex(j);

      // get smooth position
        vec_clear(pos);

        for k:=0 to vert.BlendCount-1 do
        begin
          weight := mesh.GetWeight(vert.BlendIndex + k);

          if weight.JointIndex >= 0 then
          begin
            joint := model.GetJoint(weight.JointIndex);
            mat := joint.AbsoluteMatrix;
          end
          else
            mat_identity(mat);

          pos := vec_combine(pos, vec_transform(weight.Coord, mat), weight.Weight);
        end;

        pos := vec_transform(pos, Location);

      // emit draw vertex
        dv.Position    := pos;                          // emit blended vertex position
        dv.TexCoord    := vert.UV;                      // emit texture coordinate
        dv.LM_TexCoord := vec_make(0, 0);               // triangle mesh surfaces doesn't use lightmapping
        dv.Tangent     := vec_make(0, 0, 0);            // invalid tangent vector at the beginning
        dv.Binormal    := vec_make(0, 0, 0);            // invalid binormal vector at the beginning
        dv.Normal      := vec_make(0, 0, 0);            // invalid normal vector at the beginning
        dv.Color       := vec_make(255, 255, 255, 255); // default lighting value
        surf.AddVertex(dv);
      end;

    // finish surface
      FinishSurface(World, surf);
      Inc(numTriSurf);
    end;
  finally
    Result := numTriSurf;
    model.Free;
  end;
end;

// Embeds all meshes which pointed by misc_model in map
//
function EmbedTriangleMeshesIntoWorld(World: TWorld; GamePath: String): Integer;
var
  i: Integer;
  entity: TEntity;
  modelname, ext: String;
  frame: Integer;
  mat: TMatrix4f;
  numTriSurf: Integer;
begin
  numTriSurf := 0;

  for i:=0 to World.EntityCount-1 do
  begin
    entity := World.Entities[i];

    if LowerCase(entity.ValueForKey('classname')) <> 'misc_model' then Continue;

    if not entity.IsKeyExists('model') then Continue;

    modelname := GamePath + ConvertUnixPathToDosPath(entity.ValueForKey('model'));
    ext := LowerCase(ExtractFileExt(modelname));

    if not FileExists(modelname) then Continue;

    mat_Identity(mat);

  // do scaling if needed
    if entity.IsKeyExists('scale_vec') then
      mat := mat_CreateScaleMatrix(entity.VectorForKey('scale_vec'))
    else if entity.IsKeyExists('scale') then
      mat := mat_CreateScaleMatrix(entity.FloatForKey('scale'));

  // rotation keys overriding order -> rotation, angles, angle
    if entity.IsKeyExists('rotation') then
      mat := mat_Multiply(entity.Matrix3x3ForKey('rotation'), mat)
    else if entity.IsKeyExists('angles') then
      mat := mat_Multiply(mat_CreateRotationMatrix(vec_DegToRad(entity.VectorForKey('angles'))), mat)
    else if entity.IsKeyExists('angle') then
      mat := mat_Multiply(mat_CreateRotationMatrixZ(DegToRad(entity.FloatForKey('angle'))), mat);

  // apply translation
    if entity.IsKeyExists('origin') then
      mat_SetTranslation(mat, entity.VectorForKey('origin'));

  // grab the frame
    if entity.IsKeyExists('_frame') then
      frame := entity.IntForKey('_frame')
    else
      frame := 0; // grab first frame by default

    if ext = '.3ds' then // 3D Studio File (3DS)
      numTriSurf := numTriSurf + Embed3DSMeshModel(World, modelname, frame, mat)
    else if ext = '.md3' then // Quake3 MD3 Mesh Model
      numTriSurf := numTriSurf + EmbedMD3MeshModel(World, modelname, frame, mat)
    else if ext = '.md5mesh' then // Doom3 MD5 Mesh Model
      numTriSurf := numTriSurf + EmbedMD5MeshModel(World, modelname, frame, mat);
  end;

  Result := numTriSurf;
end;

end.
