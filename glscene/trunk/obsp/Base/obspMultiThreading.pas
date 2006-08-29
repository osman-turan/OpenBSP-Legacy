//
//  Project     : OpenBSP Map Compiler
//  Unit        : obspMultiThreading.pas
//  Description : Multi-Threading management
//  History     :
//    21/08/04 - OT - Added IsMultiThreadingActive
//    20/08/04 - OT - Fixed problem about disabling MP
//    18/08/04 - OT - Added some thread-safe routines
//    05/08/04 - OT - Added option for disabling multi-processing
//    21/07/04 - OT - Some minor changes
//    13/07/04 - OT - Creation
//
unit obspMultiThreading;

interface

uses Windows, Classes;

type
  TThreadProgressEvent = procedure(const Percent: Integer) of object;
  TThreadWorkEvent = procedure(WorkIndex: Integer) of object;

function GetProcessorCount: Integer;
function IsMultiThreadingActive: Boolean;
function IsMultiThreadingEnabled: Boolean;
procedure LockMultiThreadedProcessing;
procedure UnlockMultiThreadedProcessing;
procedure RunWorkOnMultiThreading(ProgressProc: TThreadProgressEvent; // can be nil
                                  WorkProc: TThreadWorkEvent; // must be valid
                                  WorkCount: Integer;
                                  DisableMP: Boolean = False);

implementation

type
  TWorkThread = class(TThread)
  private
    FOnWork: TThreadWorkEvent;
    FWorkFinished: Boolean;
    FActiveWork: Integer;
    FOnProgress: TThreadProgressEvent;
    procedure UpdateWork;
  protected
    procedure Execute; override;
  public
    constructor Create(WorkEvent: TThreadWorkEvent;
                       ProgressEvent: TThreadProgressEvent;
                       NumWorks: Integer);

    property ActiveWork: Integer read FActiveWork;
    property WorkFinished: Boolean read FWorkFinished;

    property OnWork: TThreadWorkEvent read FOnWork;
    property OnProgress: TThreadProgressEvent read FOnProgress;
  end;

const
  MAX_THREADS = 64;

var
  GlobalLock: TRTLCriticalSection;
  ProcessorCount: Integer;
  ActiveThreadCount: Integer;
  ThreadWorkIndex: Integer;
  ThreadWorkCount: Integer;

{ TWorkThread }

constructor TWorkThread.Create(WorkEvent: TThreadWorkEvent;
                               ProgressEvent: TThreadProgressEvent;
                               NumWorks: Integer);
begin
  FOnWork := WorkEvent;
  FOnProgress := ProgressEvent;
  FWorkFinished := False;
  FActiveWork := 0;

  inherited Create(False);
end;

procedure TWorkThread.Execute;
begin
  while not Terminated do
  begin
    Synchronize(UpdateWork);

    if FWorkFinished then
      Break;

    if Assigned(FOnWork) then
    begin
      try
        FOnWork(FActiveWork);
      except
        FWorkFinished := True;
      end;
    end;
  end;
end;

procedure TWorkThread.UpdateWork;
begin
  if ThreadWorkIndex < ThreadWorkCount then
  begin
    if Assigned(FOnProgress) then
      FOnProgress(Trunc(100 * (ThreadWorkIndex+1) / ThreadWorkCount));

    FActiveWork := ThreadWorkIndex;
    Inc(ThreadWorkIndex);
  end
  else
    FWorkFinished := True;
end;

function GetProcessorCount: Integer;
begin
  Result := ProcessorCount;
end;

function IsMultiThreadingActive: Boolean;
begin
  Result := (ActiveThreadCount > 1);
end;

function IsMultiThreadingEnabled: Boolean;
var
  SysInfo: TSystemInfo;
begin
  if ProcessorCount < 0 then
  begin
    GetSystemInfo(SysInfo);

    ProcessorCount := SysInfo.dwNumberOfProcessors;

    if ProcessorCount > MAX_THREADS then
      ProcessorCount := MAX_THREADS
    else if ProcessorCount < 1 then
      ProcessorCount := 1;
  end;

  Result := (ProcessorCount > 1);
end;

procedure LockMultiThreadedProcessing;
begin
  if IsMultiThreadingActive then
    EnterCriticalSection(GlobalLock);
end;

procedure UnlockMultiThreadedProcessing;
begin
  if IsMultiThreadingActive then
    LeaveCriticalSection(GlobalLock);
end;

procedure RunWorkOnMultiThreading(ProgressProc: TThreadProgressEvent; // can be nil
                                  WorkProc: TThreadWorkEvent; // must be valid
                                  WorkCount: Integer;
                                  DisableMP: Boolean = False);
var
  i: Integer;
  Threads: array[0..MAX_THREADS-1] of TWorkThread;
begin
  if (not DisableMP) and (IsMultiThreadingEnabled) then
  begin
    ActiveThreadCount := ProcessorCount;
    InitializeCriticalSection(GlobalLock);
  end
  else
    ActiveThreadCount := 1;

  ThreadWorkIndex := 0;
  ThreadWorkCount := WorkCount;

  try
    if ActiveThreadCount > 1 then       // run at multi-threading
    begin
      for i:=0 to ActiveThreadCount-1 do
        Threads[i] := TWorkThread.Create(WorkProc, ProgressProc, WorkCount);

      for i:=0 to ActiveThreadCount-1 do
      begin
        Threads[i].WaitFor;
        Threads[i].Free;
        Threads[i] := nil;
      end;
    end
    else                          // run directly
    begin
      for i:=0 to ThreadWorkCount-1 do
      begin
        if Assigned(WorkProc) then
          WorkProc(i);

        if Assigned(ProgressProc) then
          ProgressProc(Trunc(100 * (i+1) / ThreadWorkCount));
      end;
    end;
  finally
    if (ActiveThreadCount > 1) then
      DeleteCriticalSection(GlobalLock);

    ActiveThreadCount := 0;  
  end;
end;

initialization
  ProcessorCount := -1;
  ActiveThreadCount := -1;

end.
