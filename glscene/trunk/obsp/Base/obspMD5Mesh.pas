//
//  Project     : OpenBSP Map Compiler
//  Unit        : obspMD5Mesh.pas
//  Description : Doom3 mesh model (md5mesh) loader for 
//                importing triangle meshes into map
//  History     :
//    09/12/04 - OT - Creation
//
unit obspMD5Mesh;

interface

uses Classes, SysUtils, obspBaseTypes, obspParser, obspMath, obspUtils;

type
  PMD5Triangle = ^TMD5Triangle;
  TMD5Triangle = packed record
    A, B, C: Integer;                // clock-wise order indicies
  end;

  PMD5Vertex = ^TMD5Vertex;
  TMD5Vertex = packed record
    UV: TVector2f;                   // texture coordinate
    BlendIndex: Integer;             // blended weight index
    BlendCount: Integer;             // blended weight count
  end;

  PMD5Weight = ^TMD5Weight;
  TMD5Weight = packed record
    JointIndex: Integer;             // joint index
    Weight: Single;                  // bias value
    Coord: TVector3f;                // xyz coordinates
  end;

  PMD5Joint = ^TMD5Joint;
  TMD5Joint = packed record
    ParentIndex: Integer;            // parent joint index (-1 means root)
    LocalRotation: TQuaternion;      // local rotation in quaternion
    LocalPosition: TVector3f;        // local position in affine space
    AbsoluteMatrix: TMatrix4f;       // absolute matrix
  end;

  TMD5Mesh = class
  private
    FMaterialName: String;
    FVertices: TList;
    FTriangles: TList;
    FWeights: TList;

    function GetTriangleCount: Integer;
    function GetVertexCount: Integer;
    function GetWeightCount: Integer;
  public
    constructor Create;
    destructor Destroy; override;

    procedure Clear;

    procedure SetTriangleCount(Count: Integer);
    procedure SetVertexCount(Count: Integer);
    procedure SetWeightCount(Count: Integer);

    function GetTriangle(Index: Integer): PMD5Triangle;
    function GetVertex(Index: Integer): PMD5Vertex;
    function GetWeight(Index: Integer): PMD5Weight;
    procedure SetVertex(Index: Integer; Vertex: PMD5Vertex);
    procedure SetTriangle(Index: Integer; Triangle: PMD5Triangle);
    procedure SetWeight(Index: Integer; Weight: PMD5Weight);

    property MaterialName: String read FMaterialName write FMaterialName;

    property VertexCount: Integer read GetVertexCount;
    property TriangleCount: Integer read GetTriangleCount;
    property WeightCount: Integer read GetWeightCount;
  end;

  TMD5Model = class
  private
    FParser: TTextParser;
    FCommandLine: String;
    FReportedMeshCount: Integer;
    FReportedJointCount: Integer;
    FMeshes: TList;
    FJoints: TList;

    function GetJointCount: Integer;
    function GetMeshCount: Integer;
  protected
    procedure ParseJoints;
    procedure ParseMesh;
    procedure ParseModel;
    procedure CalculateAbsoluteMatrix(ParentJoint: Integer);
  public
    constructor Create;
    destructor Destroy; override;

    function LoadFromStream(Stream: TStream): Boolean;
    function LoadFromFile(Filename: String): Boolean;
    procedure Clear;

    function AddMesh(Mesh: TMD5Mesh): Integer;
    function AddJoint(Joint: TMD5Joint): Integer;

    function GetMesh(Index: Integer): TMD5Mesh;
    procedure SetMesh(Index: Integer; const Value: TMD5Mesh);

    function GetJoint(Index: Integer): PMD5Joint;
    procedure SetJoint(Index: Integer; const Value: PMD5Joint);
    procedure CalculateAbsoluteMatrices;

    property CommandLine: String read FCommandLine write FCommandLine;

    property MeshCount: Integer read GetMeshCount;
    property JointCount: Integer read GetJointCount;
  end;

implementation

{ TMD5Mesh }

procedure TMD5Mesh.Clear;
var p: Pointer;
begin
  while FVertices.Count > 0 do
  begin
    p := FVertices.Items[0];
    FreeMem(p);
    FVertices.Delete(0);
  end;

  while FTriangles.Count > 0 do
  begin
    p := FTriangles.Items[0];
    FreeMem(p);
    FTriangles.Delete(0);
  end;

  while FWeights.Count > 0 do
  begin
    p := FWeights.Items[0];
    FreeMem(p);
    FWeights.Delete(0);
  end;

  FMaterialName := '';
end;

constructor TMD5Mesh.Create;
begin
  FVertices := TList.Create;
  FTriangles := TList.Create;
  FWeights := TList.Create;

  Clear;
end;

destructor TMD5Mesh.Destroy;
begin
  Clear;

  FVertices.Free;
  FTriangles.Free;
  FWeights.Free;

  inherited;
end;

function TMD5Mesh.GetTriangle(Index: Integer): PMD5Triangle;
begin
  Result := PMD5Triangle(FTriangles.Items[Index]);
end;

function TMD5Mesh.GetTriangleCount: Integer;
begin
  Result := FTriangles.Count;
end;

function TMD5Mesh.GetVertex(Index: Integer): PMD5Vertex;
begin
  Result := PMD5Vertex(FVertices.Items[Index]);
end;

function TMD5Mesh.GetVertexCount: Integer;
begin
  Result := FVertices.Count;
end;

function TMD5Mesh.GetWeight(Index: Integer): PMD5Weight;
begin
  Result := PMD5Weight(FWeights.Items[Index]);
end;

function TMD5Mesh.GetWeightCount: Integer;
begin
  Result := FWeights.Count;
end;

procedure TMD5Mesh.SetTriangle(Index: Integer; Triangle: PMD5Triangle);
begin
  PMD5Triangle(FTriangles.Items[Index])^ := Triangle^;
end;

procedure TMD5Mesh.SetTriangleCount(Count: Integer);
var
  tri: PMD5Triangle;
  i: Integer;
begin
  for i:=0 to Count-1 do
  begin
    GetMem(tri, SizeOf(TMD5Triangle));
    FillChar(tri^, SizeOf(TMD5Triangle), 0);
    FTriangles.Add(tri);
  end;
end;

procedure TMD5Mesh.SetVertex(Index: Integer; Vertex: PMD5Vertex);
begin
  PMD5Vertex(FVertices.Items[Index])^ := Vertex^;
end;

procedure TMD5Mesh.SetVertexCount(Count: Integer);
var
  vert: PMD5Vertex;
  i: Integer;
begin
  for i:=0 to Count-1 do
  begin
    GetMem(vert, SizeOf(TMD5Vertex));
    FillChar(vert^, SizeOf(TMD5Vertex), 0);
    FVertices.Add(vert);
  end;
end;

procedure TMD5Mesh.SetWeight(Index: Integer; Weight: PMD5Weight);
begin
  PMD5Weight(FWeights.Items[Index])^ := Weight^;
end;

procedure TMD5Mesh.SetWeightCount(Count: Integer);
var
  w: PMD5Weight;
  i: Integer;
begin
  for i:=0 to Count-1 do
  begin
    GetMem(w, SizeOf(TMD5Weight));
    FillChar(w^, SizeOf(TMD5Weight), 0);
    FWeights.Add(w);
  end;
end;

{ TMD5Model }

function TMD5Model.AddJoint(Joint: TMD5Joint): Integer;
var j: PMD5Joint;
begin
  GetMem(j, SizeOf(TMD5Joint));
  j^ := Joint;
  Result := FJoints.Add(j);
end;

function TMD5Model.AddMesh(Mesh: TMD5Mesh): Integer;
begin
  Result := FMeshes.Add(Mesh);
end;

procedure TMD5Model.CalculateAbsoluteMatrices;
begin
  CalculateAbsoluteMatrix(-1);  // recursively calculate from the root
end;

procedure TMD5Model.CalculateAbsoluteMatrix(ParentJoint: Integer);
var
  i: Integer;
  child, parent: PMD5Joint;
  m: TMatrix4f;
begin
  for i:=0 to JointCount-1 do
  begin
    child := GetJoint(i);

    if child.ParentIndex = ParentJoint then
    begin
      if ParentJoint > -1 then
      begin
        parent := GetJoint(ParentJoint);

      // build local matrix
        m := mat_FromQuaternion(child.LocalRotation);
        mat_SetTranslation(m, child.LocalPosition);

      // multiply with parent absolute matrix
        child.AbsoluteMatrix := mat_multiply(m, parent.AbsoluteMatrix);
      end
      else
        mat_Identity(child.AbsoluteMatrix);

      CalculateAbsoluteMatrix(i);
    end;
  end;
end;

procedure TMD5Model.Clear;
var 
  mesh: TMD5Mesh;
  joint: PMD5Joint;
begin
  while FMeshes.Count > 0 do
  begin
    mesh := TMD5Mesh(FMeshes.Items[0]);
    mesh.Free;
    FMeshes.Delete(0);
  end;

  while FJoints.Count > 0 do
  begin
    joint := PMD5Joint(FJoints.Items[0]);
    FreeMem(joint);
    FJoints.Delete(0);
  end;
end;

constructor TMD5Model.Create;
begin
  FMeshes := TList.Create;
  FJoints := TList.Create;
  FParser := TTextParser.Create;
  Clear;
end;

destructor TMD5Model.Destroy;
begin
  FParser.Free;
  Clear;
  FMeshes.Free;
  FJoints.Free;
  inherited;
end;

function TMD5Model.GetJoint(Index: Integer): PMD5Joint;
begin
  Result := PMD5Joint(FJoints.Items[Index]);
end;

function TMD5Model.GetJointCount: Integer;
begin
  Result := FJoints.Count;
end;

function TMD5Model.GetMesh(Index: Integer): TMD5Mesh;
begin
  Result := TMD5Mesh(FMeshes.Items[Index]);
end;

function TMD5Model.GetMeshCount: Integer;
begin
  Result := FMeshes.Count;
end;

function TMD5Model.LoadFromFile(Filename: String): Boolean;
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

function TMD5Model.LoadFromStream(Stream: TStream): Boolean;
begin
  Result := False;

  Clear;
  FParser.LoadFromStream(Stream);
  ParseModel;

  if (FReportedJointCount = FJoints.Count) and
     (FReportedMeshCount = FMeshes.Count) then
    Result := True;
end;

procedure TMD5Model.ParseJoints;
var
  joint: TMD5Joint;
  q_def: TVector3f;
  f: Extended;
begin
// read bracket
  if not FParser.GetNextToken then Exit;
  if FParser.Token <> '{' then Exit;

// read all joints
  while true do
  begin
  // "origin"	-1 ( 0 0 0 ) ( -1.091179 0.485826 -1.696547 )

  // Read joint name. This is unnecessary in compiler. So, skip it
    if not FParser.GetNextToken then Break;
    if FParser.Token = '}' then Break;

  // read parent joint index
    if not FParser.GetNextToken then Break;
    if not TryStrToFloatGeneric(FParser.Token, f) then Break;
    joint.ParentIndex := Trunc(f);

  // read rotation (quaternion defination)
    if not FParser.GetNextToken then Break;
    if FParser.Token <> '(' then Break;

    if not FParser.GetNextToken then Break;
    if not TryStrToFloatGeneric(FParser.Token, f) then Break;
    q_def[0] := f;

    if not FParser.GetNextToken then Break;
    if not TryStrToFloatGeneric(FParser.Token, f) then Break;
    q_def[1] := f;

    if not FParser.GetNextToken then Break;
    if not TryStrToFloatGeneric(FParser.Token, f) then Break;
    q_def[2] := f;

    if not FParser.GetNextToken then Break;
    if FParser.Token <> ')' then Break;

  // read position
    if not FParser.GetNextToken then Break;
    if FParser.Token <> '(' then Break;

    if not FParser.GetNextToken then Break;
    if not TryStrToFloatGeneric(FParser.Token, f) then Break;
    joint.LocalPosition[0] := f;

    if not FParser.GetNextToken then Break;
    if not TryStrToFloatGeneric(FParser.Token, f) then Break;
    joint.LocalPosition[1] := f;

    if not FParser.GetNextToken then Break;
    if not TryStrToFloatGeneric(FParser.Token, f) then Break;
    joint.LocalPosition[2] := f;

    if not FParser.GetNextToken then Break;
    if FParser.Token <> ')' then Break;

  // skip rest of line
    FParser.SkipLine;

  // solve quaternion defination (aka compressed quaternion)
  // and build joint rotation based the quaternion
    joint.LocalRotation.ImagPart[0] := q_def[0];
    joint.LocalRotation.ImagPart[1] := q_def[1];
    joint.LocalRotation.ImagPart[2] := q_def[2];
    joint.LocalRotation.RealPart := 1.0 - vec_dot(q_def, q_def);
    if joint.LocalRotation.RealPart < 0 then
      joint.LocalRotation.RealPart := 0
    else
      joint.LocalRotation.RealPart := Sqrt(joint.LocalRotation.RealPart);

    AddJoint(joint);
  end;
end;

procedure TMD5Model.ParseMesh;
var
  token: String;
  mesh: TMD5Mesh;
  vert: TMD5Vertex;
  tri: TMD5Triangle;
  weight: TMD5Weight;
  i, idx: Integer;
  f: Extended;
begin
// read bracket
  if not FParser.GetNextToken then Exit;
  if FParser.Token <> '{' then Exit;

  mesh := TMD5Mesh.Create;
  AddMesh(mesh);

// read mesh
  while true do
  begin
    if not FParser.GetNextToken then Break;
    if FParser.Token = '}' then Break;

    token := LowerCase(FParser.Token);

    if token = 'shader' then
    begin
      if not FParser.GetNextToken then Break;
      mesh.MaterialName := FParser.Token;
    end
    else if token = 'numverts' then
    begin
    // vert 0 ( 0.027778 0.125000 ) 0 1

      if not FParser.GetNextToken then Break;
      if not TryStrToFloatGeneric(FParser.Token, f) then Break;
      mesh.SetVertexCount(Trunc(f));

      for i:=0 to mesh.VertexCount-1 do
      begin
        if not FParser.GetNextToken then Break;
        if LowerCase(FParser.Token) <> 'vert' then Break;

        if not FParser.GetNextToken then Break;
        if not TryStrToFloatGeneric(FParser.Token, f) then Break;
        idx := Trunc(f);

        if not FParser.GetNextToken then Break;
        if FParser.Token <> '(' then Break;

        if not FParser.GetNextToken then Break;
        if not TryStrToFloatGeneric(FParser.Token, f) then Break;
        vert.UV[0] := f;

        if not FParser.GetNextToken then Break;
        if not TryStrToFloatGeneric(FParser.Token, f) then Break;
        vert.UV[1] := f;

        if not FParser.GetNextToken then Break;
        if FParser.Token <> ')' then Break;

        if not FParser.GetNextToken then Break;
        if not TryStrToFloatGeneric(FParser.Token, f) then Break;
        vert.BlendIndex := Trunc(f);

        if not FParser.GetNextToken then Break;
        if not TryStrToFloatGeneric(FParser.Token, f) then Break;
        vert.BlendCount := Trunc(f);

      // skip rest of line
        FParser.SkipLine;

      // set vertex
        mesh.SetVertex(idx, @vert);
      end;
    end
    else if token = 'numtris' then
    begin
    // tri 0 2 1 0

      if not FParser.GetNextToken then Break;
      if not TryStrToFloatGeneric(FParser.Token, f) then Break;
      mesh.SetTriangleCount(Trunc(f));

      for i:=0 to mesh.TriangleCount-1 do
      begin
        if not FParser.GetNextToken then Break;
        if LowerCase(FParser.Token) <> 'tri' then Break;

        if not FParser.GetNextToken then Break;
        if not TryStrToFloatGeneric(FParser.Token, f) then Break;
        idx := Trunc(f);

        if not FParser.GetNextToken then Break;
        if not TryStrToFloatGeneric(FParser.Token, f) then Break;
        tri.A := Trunc(f);

        if not FParser.GetNextToken then Break;
        if not TryStrToFloatGeneric(FParser.Token, f) then Break;
        tri.B := Trunc(f);

        if not FParser.GetNextToken then Break;
        if not TryStrToFloatGeneric(FParser.Token, f) then Break;
        tri.C := Trunc(f);

      // skip rest of line
        FParser.SkipLine;

      // set triangle
        mesh.SetTriangle(idx, @tri);
      end;
    end
    else if token = 'numweights' then
    begin
    // weight 0 0 1 ( 24.000502 -0.000237 -192.000992 )

      if not FParser.GetNextToken then Break;
      if not TryStrToFloatGeneric(FParser.Token, f) then Break;
      mesh.SetWeightCount(Trunc(f));

      for i:=0 to mesh.WeightCount-1 do
      begin
        if not FParser.GetNextToken then Break;
        if LowerCase(FParser.Token) <> 'weight' then Break;

        if not FParser.GetNextToken then Break;
        if not TryStrToFloatGeneric(FParser.Token, f) then Break;
        idx := Trunc(f);

        if not FParser.GetNextToken then Break;
        if not TryStrToFloatGeneric(FParser.Token, f) then Break;
        weight.JointIndex := Trunc(f);

        if not FParser.GetNextToken then Break;
        if not TryStrToFloatGeneric(FParser.Token, f) then Break;
        weight.Weight := f;

        if not FParser.GetNextToken then Break;
        if FParser.Token <> '(' then Break;

        if not FParser.GetNextToken then Break;
        if not TryStrToFloatGeneric(FParser.Token, f) then Break;
        weight.Coord[0] := f;

        if not FParser.GetNextToken then Break;
        if not TryStrToFloatGeneric(FParser.Token, f) then Break;
        weight.Coord[1] := f;

        if not FParser.GetNextToken then Break;
        if not TryStrToFloatGeneric(FParser.Token, f) then Break;
        weight.Coord[2] := f;

        if not FParser.GetNextToken then Break;
        if FParser.Token <> ')' then Break;

      // skip rest of line
        FParser.SkipLine;

      // set weight
        mesh.SetWeight(idx, @weight);
      end;
   end
    else
      FParser.SkipLine;
  end;
end;

procedure TMD5Model.ParseModel;
var 
  token: String;
  f: Extended;
begin
// read header
  if not FParser.GetNextToken then Exit;
  if not SameText(FParser.Token, 'MD5Version') then Exit;

// read version
  if not FParser.GetNextToken then Exit;
  if not SameText(FParser.Token, '10') then Exit;

// read rest of file
  while true do
  begin
    if not FParser.GetNextToken then Break;

    token := LowerCase(FParser.Token);

    if token = 'commandline' then         // commandline
    begin
      if not FParser.GetNextToken then Break;
      FCommandLine := FParser.Token;
    end
    else if token = 'numjoints' then      // numJoints
    begin
      if not FParser.GetNextToken then Break;
      if not TryStrToFloatGeneric(FParser.Token, f) then Break;
      FReportedJointCount := Trunc(f);
    end
    else if token = 'nummeshes' then      // numMeshes
    begin
      if not FParser.GetNextToken then Break;
      if not TryStrToFloatGeneric(FParser.Token, f) then Break;
      FReportedMeshCount := Trunc(f);
    end
    else if token = 'joints' then         // joints
      ParseJoints
    else if token = 'mesh' then           // mesh
      ParseMesh
    else
      FParser.SkipLine;
  end;
end;

procedure TMD5Model.SetJoint(Index: Integer; const Value: PMD5Joint);
begin
  PMD5Joint(FJoints.Items[Index])^ := Value^;
end;

procedure TMD5Model.SetMesh(Index: Integer; const Value: TMD5Mesh);
begin
  FMeshes.Items[Index] := Value;
end;

end.
