//
//  Project     : OpenBSP Map Compiler
//  Unit        : ConMain.pas
//  Description : Console interface
//  History     :
//    08/01/05 - OT - Removed -saturatelighting argument
//    13/07/04 - OT - Fixed small command-line parsing bug
//    03/07/04 - OT - Added -extralight command line parameter
//    18/06/04 - OT - Creation
//
unit ConMain;

interface

uses SysUtils;

type
  TConsoleCompiler = class
  private
    FProgress: Integer;
    FActiveWorkCount: Integer;
    FAppFilename: String;
  protected
    procedure PrintIntro;
    procedure PrintHelp;
    
    procedure EventStartWork(Sender: TObject;
                             const Msg: String);
    procedure EventEndWork(Sender: TObject;
                           const ElapsedTime: Extended);
    procedure EventProgress(Sender: TObject;
                            const Percent: Integer);
    procedure EventMessage(Sender: TObject;
                           const Msg: String);
    procedure EventError(Sender: TObject;
                         const Msg: String);
  public
    procedure Run;
  end;

implementation

uses obspCompiler, obspVersion, obspMultiThreading;

{ TConsoleCompiler }

procedure TConsoleCompiler.EventEndWork(Sender: TObject;
  const ElapsedTime: Extended);
var i: Integer;
begin
  Dec(FActiveWorkCount);

  if FProgress < 0 then FProgress := 0;

  for i:=FProgress+1 to 10 do
  begin
    if i >= 10 then
      Write(i)
    else
      Write(i, '..');
  end;

  Write(Format(' (%.3f secs)', [ElapsedTime]));

  Writeln;
  Sleep(1);
end;

procedure TConsoleCompiler.EventError(Sender: TObject; const Msg: String);
begin
  Writeln;
  Writeln(StringOfChar('-', 20)+'ERROR'+StringOfChar('-', 20));
  Writeln(Msg);
  Writeln(StringOfChar('-', 45));
end;

procedure TConsoleCompiler.EventMessage(Sender: TObject;
  const Msg: String);
begin
  Writeln(Msg);
end;

procedure TConsoleCompiler.EventProgress(Sender: TObject;
  const Percent: Integer);
var i, base, target: Integer;
begin
  target := Trunc(10 * (Percent / 100));

  if target <= FProgress then Exit;

  base := FProgress+1;
  for i:=base to target do
  begin
    FProgress := i;
    if i >= 10 then
      Write(i)
    else
      Write(i, '..');
  end;
end;

procedure TConsoleCompiler.EventStartWork(Sender: TObject;
  const Msg: String);
begin
  if FActiveWorkCount = 0 then
    Writeln;

  Writeln(StringOfChar(' ', FActiveWorkCount * 2) +
          '> '+
          Msg);

  FProgress := -1;

  Inc(FActiveWorkCount);
end;

procedure TConsoleCompiler.PrintHelp;
begin
  Writeln('Usage:');
  Writeln(Format('%s [Game Path] [Map Filename] [Options]', [FAppFilename]));
  Writeln;
  Writeln('Options:');
  Writeln('-nolightmaps         Disables lightmapping process (full bright)');
  Writeln('-disablemp           Disables multi-threaded processing');
  Writeln('-subsamples [x]      Changes subsampling amount in lightmapping');
  Writeln('-noshadows           Disables shadow casting');
  Writeln('-savelightmaps       Saves lightmaps to external bitmap files in output file directory');

  Writeln;
  Writeln('Example:');
  Writeln(Format('%s "C:\Game\Base" "C:\Game\Base\test.map" -subsamples 4 -savelightmaps', [FAppFilename]));
  Writeln;
end;

procedure TConsoleCompiler.PrintIntro;
begin
  Writeln('OpenBSP Map Compiler');
  Writeln(Format('Version: %s, %s', [APP_VERSION, APP_DATE]));
  Writeln('Powered by OpenBSP Community');
  Writeln;
  if IsMultiThreadingEnabled then
  begin
    Writeln('Multi-Threading Detected');
    Writeln;
  end;
end;

procedure TConsoleCompiler.Run;
var
  MapFile, Option, GamePath: String;
  CompObj: TCompiler;
  i: Integer;
begin
  FAppFilename := ExtractFilename(ParamStr(0));

  PrintIntro;

  if ParamCount < 2 then
  begin
    PrintHelp;
    Exit;
  end;

  GamePath := IncludeTrailingBackslash(ExpandFilename(ParamStr(1)));
  MapFile := ExpandFilename(ParamStr(2));

  if not FileExists(MapFile) then
  begin
    Writeln('File not found: ', MapFile);
    Exit;
  end;

  CompObj := TCompiler.Create;
  CompObj.OnStartWork := EventStartWork;
  CompObj.OnEndWork := EventEndWork;
  CompObj.OnProgress := EventProgress;
  CompObj.OnMessage := EventMessage;
  CompObj.OnError := EventError;
  CompObj.GamePath := GamePath;

  i := 3;
  while i <= ParamCount do
  begin
    Option := ParamStr(i);

    if SameText(Option, '-disablemp') then
    begin
      CompObj.DisableMP := True;
      Writeln('Multi-Processing disabled');
    end
    else if SameText(Option, '-nolightmaps') then
    begin
      CompObj.Lighting.NoLightmaps := True;
      Writeln('Lightmapping disabled');
    end
    else if SameText(Option, '-subsamples') then
    begin
      Inc(i);
      if i > ParamCount then
      begin
        Writeln('Expected parameter: ', Option);
        Break;
      end;

      CompObj.Lighting.SubSamples := StrToIntDef(ParamStr(i), 1);
      Writeln('Lightmapping subsamples: ', CompObj.Lighting.SubSamples);
    end
    else if SameText(Option, '-savelightmaps') then
    begin
      CompObj.Lighting.SaveLightmaps := True;
      Writeln('Save lightmaps enabled');
    end
    else if SameText(Option, '-noshadows') then
    begin
      CompObj.Lighting.NoShadows := True;
      Writeln('Shadow casting disabled');
    end
    else
    begin
      Writeln('Invalid parameter: ', Option);
      Writeln;
      PrintHelp;
      Exit;
    end;

    Inc(i);
  end;

  try
    if CompObj.Compile(MapFile) then
    begin
      Writeln;
      Writeln('Compiling was successfully completed');
    end
    else
    begin
      Writeln;
      Writeln('Compiling was failed');
    end;
  finally
    CompObj.Free;
  end;
end;

end.
