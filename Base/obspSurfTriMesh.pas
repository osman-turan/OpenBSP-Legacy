//
//  Project     : OpenBSP Map Compiler
//  Unit        : obspSurfTriMesh.pas
//  Description : Includes triangle mesh surface class
//  History:
//    27/11/04 - OT - Creation
//
unit obspSurfTriMesh;

interface

uses obspMapClasses;

type
  TTriangleMeshSurface = class(TSurface)
  protected
    procedure DoClear; override;
  public
    constructor Create(Owner: TEntity; MaterialName: String); override;
  end;

implementation

{ TTriangleMeshSurface }

constructor TTriangleMeshSurface.Create(Owner: TEntity; MaterialName: String);
begin
  inherited;

  FSurfaceType := stTriangleMesh;
end;

procedure TTriangleMeshSurface.DoClear;
begin
// nothing
end;

end.
