//
//  Project     : OpenBSP Map Compiler
//  Unit        : obspCompiler.pas
//  Description : Main Compiler (manages BSP, Visibility and Lighting)
//  History     :
//    09/06/04 - OT - Added support for TBaseCompiler
//    20/05/04 - OT - Creation
//
unit obspCompiler;

interface

uses SysUtils, Classes, obspBaseCompiler, obspBSP, obspLighting,
  obspMapClasses;

type
  TCompiler = class(TBaseCompilerManager)
  private
    FBSPProcess: TBSPProcess;
    FLighting: TLightingProcess;
  public
    constructor Create; override;
    destructor Destroy; override;

    function Compile(const MapFilename: String): Boolean; override;

    property Lighting: TLightingProcess read FLighting;
  end;

implementation

uses obspFile;

{ TCompiler }

function TCompiler.Compile(const MapFilename: String): Boolean;
var
  bspfile: String;
  len: Integer;
  t: Int64;
begin

  PrintMessage('Game Path: %s', [GamePath]);
  PrintMessage('Map File : %s', [MapFilename]);
  PrintMessage('');

  Result := False;
  FMapFile := MapFilename;
  bspfile := ChangeFileExt(MapFile, '.obsp');

  Randomize; // initialize random routine

  World.Clear;
  World.MaterialManager.TexturePath := GamePath;

  t := StartTiming;

  StartWork('Loading materials...');
  World.MaterialManager.AddMaterialPath(GamePath + 'scripts');
  World.MaterialManager.AddMaterialPath(GamePath + 'materials');  
  EndWork;
  PrintMessage('%5d materials loaded', [World.MaterialManager.MaterialCount]);

  if not FBSPProcess.Compile(MapFile) then Exit;
  FLighting.LightWorld(bspfile);
  StartWork('Writing BSP file...');
  try
    len := World.SaveToFile(bspfile);
  except
    Compile(MapFilename);
  end;
  EndWork;
  PrintMessage('  %d KB map size', [len div 1024]);

  World.Clear;

  PrintMessage('');
  PrintMessage('Total Compiling Time: %.3f secs', [EndTiming(t)]);

  Result := True;

end;

constructor TCompiler.Create;
begin
  inherited;

  FBSPProcess := TBSPProcess.Create(Self, Self);
  FLighting := TLightingProcess.Create(Self, Self);
end;

destructor TCompiler.Destroy;
begin
  FLighting.Free;
  FBSPProcess.Free;
  inherited;
end;

end.
