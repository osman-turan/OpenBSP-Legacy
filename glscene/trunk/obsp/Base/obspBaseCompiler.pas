//
//  Project     : OpenBSP Map Compiler
//  Unit        : obspBaseCompiler.pas
//  Description : Base compiler class
//  History     :
//    11/10/04 - OT - Timing functions added (StartTiming & EndTiming)
//    18/08/04 - OT - Added some thread-safe routines
//    09/06/04 - OT - Creation
//
unit obspBaseCompiler;

interface

uses SysUtils, Windows, Classes, obspMapClasses, obspMultiThreading;

type
// Compiler base class
  TCompilerProgressEvent = procedure(Sender: TObject;
                                     const Percent: Integer) of object;
  TCompilerStartWorkEvent = procedure(Sender: TObject;
                                      const Msg: String) of object;
  TCompilerEndWorkEvent = procedure(Sender: TObject;
                                    const ElapsedTime: Extended) of object;
  TCompilerMessageEvent = procedure(Sender: TObject;
                                    const Msg: String) of object;
  TCompilerErrorEvent = procedure(Sender: TObject;
                                  const Msg: String) of object;

  TBaseCompilerManager    = class;
  TBaseCompiler       = class;
  TBaseCompilerObject = class;

  TBaseCompilerObject = class
  private
    FOwner: TBaseCompilerObject;
    FWorkCount: Integer;
    FStartTime: Int64;

    FOnProgress: TCompilerProgressEvent;
    FOnEndWork: TCompilerEndWorkEvent;
    FOnStartWork: TCompilerStartWorkEvent;
    FOnMessage: TCompilerMessageEvent;
    FOnError: TCompilerErrorEvent;
    procedure EventThreadProgress(const Percent: Integer);
    procedure EventProgress(Sender: TObject;
                            const Percent: Integer);
    procedure EventStartWork(Sender: TObject;
                             const Msg: String);
    procedure EventEndWork(Sender: TObject;
                           const ElapsedTime: Extended);
    procedure EventMessage(Sender: TObject;
                           const Msg: String);
    procedure EventError(Sender: TObject;
                         const Msg: String);
    function GetWorld: TWorld;
  protected
    procedure AddChildCompiler(const Child: TBaseCompilerObject);

    procedure LockMultiThreading;
    procedure UnlockMultiThreading;
    function LockedIncrement(var I: Integer; Delta: Integer = 1): Integer;
    function LockedDecrement(var I: Integer; Delta: Integer = 1): Integer;
    procedure RunWorkOnMultiThreading(const StartMsg, EndMsg: String;
                                      const WorkCount: Integer;
                                      WorkProc: TThreadWorkEvent;
                                      DisableMP: Boolean = False);
    function StartTiming: Int64;
    function EndTiming(StartTime: Int64): Extended;
    procedure StartWork(const Msg: String);
    procedure EndWork;
    procedure Progress(const Percent: Integer);
    procedure PrintMessage(const Msg: String); overload;
    procedure PrintMessage(const Msg: String; const Args: array of const); overload;
    procedure Error(const Msg: String); overload;
    procedure Error(const Msg: String; const Args: array of const); overload;

    constructor CreateOwned(const AOwner: TBaseCompilerObject); virtual;
    function GetWorldObject: TWorld; dynamic; abstract;
  public
    destructor Destroy; override;

    property WorkCount: Integer read FWorkCount;
    property OnStartWork: TCompilerStartWorkEvent read FOnStartWork write FOnStartWork;
    property OnEndWork: TCompilerEndWorkEvent read FOnEndWork write FOnEndWork;
    property OnProgress: TCompilerProgressEvent read FOnProgress write FOnProgress;
    property OnMessage: TCompilerMessageEvent read FOnMessage write FOnMessage;
    property OnError: TCompilerErrorEvent read FOnError write FOnError;

    property Owner: TBaseCompilerObject read FOwner;
    property World: TWorld read GetWorld;
  end;

  TBaseCompiler = class(TBaseCompilerObject)
  private
    FManager: TBaseCompilerManager;
  protected
    function GetWorldObject: TWorld; override;
  public
    constructor Create(const AManager: TBaseCompilerManager;
                       const AOwner: TBaseCompilerObject); virtual;

    property Manager: TBaseCompilerManager read FManager;
  end;

  TBaseCompilerManager = class(TBaseCompilerObject)
  private
    FWorld: TWorld;
    FDisableMP: Boolean;
    FGamePath: String;
  protected
    FMapFile: String;
    function GetWorldObject: TWorld; override;
  public
    constructor Create; virtual;
    destructor Destroy; override;

    function Compile(const MapFilename: String): Boolean; dynamic; abstract;

    property GamePath: String read FGamePath write FGamePath;
    property MapFile: String read FMapFile;
    property DisableMP: Boolean read FDisableMP write FDisableMP;
  end;

implementation

var
  vInvPerfFreq: Extended;

{ TBaseCompilerObject }

procedure TBaseCompilerObject.AddChildCompiler(const Child: TBaseCompilerObject);
begin
  Child.OnProgress := EventProgress;
  Child.OnStartWork := EventStartWork;
  Child.OnEndWork := EventEndWork;
  Child.OnMessage := EventMessage;
  Child.OnError := EventError;
end;

constructor TBaseCompilerObject.CreateOwned(
  const AOwner: TBaseCompilerObject);
begin
  FOwner := AOwner;
  if Assigned(FOwner) then
    FOwner.AddChildCompiler(Self);
end;

destructor TBaseCompilerObject.Destroy;
begin
  FOwner := nil;
  inherited;
end;

function TBaseCompilerObject.EndTiming(StartTime: Int64): Extended;
var time: Int64;
begin
  QueryPerformanceCounter(time);
  Result := (time - StartTime) * vInvPerfFreq;
end;

procedure TBaseCompilerObject.EndWork;
var time: Int64;
begin
  Dec(FWorkCount);
  QueryPerformanceCounter(time);
  if Assigned(FOnEndWork) then
    FOnEndWork(Self, (time - FStartTime) * vInvPerfFreq);
end;

procedure TBaseCompilerObject.Error(const Msg: String);
begin
  if Assigned(FOnError) then
    FOnError(Self, Msg);

  Abort;
end;

procedure TBaseCompilerObject.Error(const Msg: String;
  const Args: array of const);
begin
  Error(Format(Msg, Args));
end;

procedure TBaseCompilerObject.EventEndWork(Sender: TObject; const ElapsedTime: Extended);
begin
  Dec(FWorkCount);
  if Assigned(FOnEndWork) then
    FOnEndWork(Sender, ElapsedTime);
end;

procedure TBaseCompilerObject.EventError(Sender: TObject; const Msg: String);
begin
  if Assigned(FOnError) then
    FOnError(Sender, Msg);
end;

procedure TBaseCompilerObject.EventMessage(Sender: TObject; const Msg: String);
begin
  if Assigned(FOnMessage) then
    FOnMessage(Sender, Msg);
end;

procedure TBaseCompilerObject.EventProgress(Sender: TObject; const Percent: Integer);
begin
  if Assigned(FOnProgress) then
  begin
    if FWorkCount > 0 then
      FOnProgress(Sender, Percent div FWorkCount)
    else
      FOnProgress(Sender, Percent);
  end;
end;

procedure TBaseCompilerObject.EventStartWork(Sender: TObject; const Msg: String);
begin
  Inc(FWorkCount);
  if Assigned(FOnStartWork) then
    FOnStartWork(Sender, Msg);
end;

procedure TBaseCompilerObject.PrintMessage(const Msg: String);
begin
  if Assigned(FOnMessage) then
    FOnMessage(Self, Msg);
end;

function TBaseCompilerObject.GetWorld: TWorld;
begin
  Result := GetWorldObject;
end;

procedure TBaseCompilerObject.PrintMessage(const Msg: String;
  const Args: array of const);
begin
  PrintMessage(Format(Msg, Args));
end;

procedure TBaseCompilerObject.Progress(const Percent: Integer);
begin
  if Assigned(FOnProgress) then
    FOnProgress(Self, Percent);
end;

function TBaseCompilerObject.StartTiming: Int64;
begin
  QueryPerformanceCounter(Result);
end;

procedure TBaseCompilerObject.StartWork(const Msg: String);
begin
  Inc(FWorkCount);
  QueryPerformanceCounter(FStartTime);
  if Assigned(FOnStartWork) then
    FOnStartWork(Self, Msg);
  Progress(0);
end;

procedure TBaseCompilerObject.RunWorkOnMultiThreading(const StartMsg,
  EndMsg: String; const WorkCount: Integer; WorkProc: TThreadWorkEvent;
  DisableMP: Boolean = False);
begin
  StartWork(StartMsg);
  obspMultiThreading.RunWorkOnMultiThreading(EventThreadProgress,
                                             WorkProc,
                                             WorkCount,
                                             DisableMP);
  EndWork;
end;

procedure TBaseCompilerObject.EventThreadProgress(const Percent: Integer);
begin
  Progress(Percent);
end;

procedure TBaseCompilerObject.LockMultiThreading;
begin
  LockMultiThreadedProcessing;
end;

procedure TBaseCompilerObject.UnlockMultiThreading;
begin
  UnlockMultiThreadedProcessing;
end;

function TBaseCompilerObject.LockedDecrement(var I: Integer;
  Delta: Integer): Integer;
// EDX -> I
// ECX -> Delta
// EAX -> Result
asm
        NEG     ECX
  LOCK  XADD    [EDX], ECX
        MOV     EAX, EDX
end;

function TBaseCompilerObject.LockedIncrement(var I: Integer;
  Delta: Integer): Integer;
// EDX -> I
// ECX -> Delta
// EAX -> Result
asm
  LOCK  XADD    [EDX], ECX
        MOV     EAX, [EDX]
end;

{ TBaseCompilerManager }

constructor TBaseCompilerManager.Create;
begin
  inherited Create;
  FWorld := TWorld.Create;
end;

destructor TBaseCompilerManager.Destroy;
begin
  FWorld.Free;
  inherited;
end;

function TBaseCompilerManager.GetWorldObject: TWorld;
begin
  Result := FWorld;
end;

{ TBaseCompiler }

constructor TBaseCompiler.Create(const AManager: TBaseCompilerManager;
                                 const AOwner: TBaseCompilerObject);
begin
  inherited CreateOwned(AOwner);
  FManager := AManager;
end;

function TBaseCompiler.GetWorldObject: TWorld;
begin
  Result := FManager.World;
end;

var temp: Int64;
initialization
  QueryPerformanceFrequency(temp);
  vInvPerfFreq := 1 / temp;

end.
