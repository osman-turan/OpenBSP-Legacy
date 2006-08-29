unit obspOBJMesh;

interface

uses Classes;

// OBJ file line tags.
const
  OBJ_TAG_VERTEX            = 'v';
  OBJ_TAG_TEXCOORD          = 'vt';
  OBJ_TAG_NORMAL            = 'vn';
  OBJ_TAG_GROUP             = 'g';
  OBJ_TAG_FACE              = 'f';
  OBJ_TAG_MATERIAL          = 'usemtl';
  OBJ_TAG_MATERIALLIB       = 'mtllib';
  OBJ_TAG_COMMENT           = '#';
  OBJ_TAG_ALTERNATECOMMENT  = '$';

type
  POBJVertex = ^TOBJVertex;
  TOBJVertex = packed record
    Position: TVector3f;
    TexCoord: TVector2f;
  end;

  TOBJMesh = class
  private
    FMeshName: String;
    FVertexCount: Integer;
    FMaterialName: String;
  public
    constructor Create;
    destructor Destroy; override;

    procedure AddPoint(V: TVector3f);
    procedure AddTexCoord(ST: TVector2f);
    procedure AddVertex(PointIndex, TexCoordIndex: Integer);

    property MeshName: String read FMeshName write FMeshName;
    property MaterialName: String read FMaterialName write FMaterialName;
    property PointCount: Integer read FPointCount;
    property TexCoordCount: Integer read FTexCoordCount;
    property VertexCount: Integer read FVertexCount;
  end;

  TOBJModel = class
  private
    FMeshes: TList;
    FSource: String;
    FSize: Integer;
    FPos: Integer;
    FLine: String;
    FLineNo: Integer;
    function GetMeshCount: Integer;
  protected
    procedure Clear;
    function NextToken(var S: String; Delimiter: Char): String;
    procedure ParseFace;
    procedure ParseModel;
    function ParseVector: TVector3f;
    procedure ReadLine;
  public
    constructor Create;
    destructor Destroy; override;

    function LoadFromStream(Stream: TStream): Boolean;
    function LoadFromFile(Filename: String): Boolean;

    property MeshCount: Integer read GetMeshCount;
  end;

implementation

{ TOBJModel }

constructor TOBJModel.Create;
begin
  FMeshes := TList.Create;
  Clear;
end;

destructor TOBJModel.Destroy;
begin
  Clear;
  FMeshes.Free;

  inherited;
end;

procedure TOBJModel.Clear;
var mesh: TOBJMesh;
begin
  FSource:=nil;
  FSize:=0;
  FPos:=1;

  while (FMeshes.Count > 0) do
  begin
    mesh := TOBJMesh(FMeshes.Items[0]);
    mesh.Free;
    FMeshes.Delete(0);
  end;
end;

function TOBJModel.GetMeshCount: Integer;
begin
  Result := FMeshes.Count;
end;

function TOBJModel.LoadFromFile(Filename: String): Boolean;
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

function TOBJModel.LoadFromStream(Stream: TStream): Boolean;
var command: String;
begin
  Result := False;

  try
    Clear;
    FSize := Stream.Size;
    SetLength(FSource, FSize);
    Stream.Read(PChar(FSource)^, FSize);
    ParseModel;
    Result := True;
  finally
    FSource := nil;
  end;
end;

function TOBJModel.NextToken(var s : String; delimiter : Char) : String;
var p : Integer;
begin
  p := Pos(Delimiter, s);

  if p=0 then
  begin
    Result:=s;
    s:='';
  end
  else
  begin
    Result:=copy(s, 1, p-1);
    s:=TrimLeft(Copy(s, p+1, Length(s)-p);
  end;
end;

procedure TOBJModel.ParseFace;

  procedure AddFaceVertex(faceVertices : String);
  var
    s : String;
    vIdx, tIdx, nIdx : Integer;

    function GetIndex(Count : Integer) : Integer;
    begin
      s:=NextToken(FaceVertices, '/');
      Result:=StrToIntDef(s, 0);

      if Result=0 then
        // Missing
        Result:=-1
      else if Result<0 then
        // Relative, make absolute. "-1" means last, "-2" second last.
        Result:=Count+Result
      end else
        // Absolute, correct for zero-base.
        Dec(Result);
    end;

  begin
    vIdx:=GetIndex(FCurrentMesh.VertexCount);
    tIdx:=GetIndex(FCurrentMesh.TexCoordCount);
    nIdx:=GetIndex(0); // ignore normals

    FCurrentMesh.AddVertex(vIdx, tIdx);
  end;

var s: String;
begin
  try
    while FLine<>'' do
    begin
      s := NextToken(FLine, ' ');
      AddFaceVertex(s);
    end;
  finally
    FCurrentMesh.PolygonComplete;
  end;
end;

procedure TOBJModel.ParseModel;
var v: TVector3f;
begin
  try
    while FPos <= FSize do
    begin
      ReadLine;
      if FLine='' then
        Continue; { Skip blank line }
      if (FLine[1] = OBJ_TAG_COMMENT) or 
         (FLine[1] = OBJ_TAG_ALTERNATECOMMENT) then
        Continue; { Skip comment and alternate comment }

      command:=LowerCase(NextToken(FLine, ' '));

      if command=OBJ_TAG_VERTEX then
      begin
        v := ParseVector;
        FCurrentMesh.AddVertex(v);
      end
      else if command=OBJ_TAG_TEXCOORD then
      begin
        v := ParseVector;
        FCurrentMesh.AddVertex(PVector2f(@v[0])^);
      end
      else if command=OBJ_TAG_GROUP then
      begin
        { Only the first name on the line, multiple groups not supported. }
        SetCurrentFaceGroup(NextToken(FLine, ' '), curMtlName);
      end
      else if command=OBJ_TAG_FACE then
      begin
        ReadFace(curMtlName);
      end
      else if command=OBJ_TAG_MATERIALLIB then
      begin
        objMtlFileName:=NextToken(FLine, ' ');
      end
      else if command=OBJ_TAG_MATERIAL then
      begin
        curMtlName:=GetOrAllocateMaterial(objMtlFileName, NextToken(FLine, ' '));

        if not Assigned(FCurrentMesh) then
          SetCurrentFaceGroup('', curMtlName)
        else
          SetCurrentFaceGroup(faceGroup.FName, curMtlName);
      end
      else if command=OBJ_TAG_NORMAL then
      begin
        // Ignore normals. Because, we will build smooth and transformed normals later
      end;
    end;
  finally
  end;
end;

function TOBJModel.ParseVector: TVector3f;
var
  i: Integer;
  s: String;
  f: Extended;
  v: TVector3f;
begin
  vec_clear(v);

  i := 0;

  while (FLine <> '') and (i < 3) do
  begin
    s := NextToken(FLine, ' ');

    if not TryStrToFloatGeneric(s, f) then Break;

    v[i] := f;

    Inc(i);
  end;

  Result := v;
end;

procedure TOBJModel.ReadLine;
var i, start, count: Integer;
begin
  Inc(FLineNo);

  count := 0;
  start := FPos;

  while FPos <= FSize do
  begin
    case FSource[FPos] of
      #10: begin
             Inc(FPos);
             Break;
           end;
      #13: begin
             Inc(FPos);
             if FPos <= FSize then
             begin
               if FSource[FPos] = #10 then
                 Inc(FPos);
             end;

             Break;
           end;
    end;

    Inc(FPos);
    Inc(count);
  end;

  FLine := Trim(Copy(FSource, start, count));
end;

end.
