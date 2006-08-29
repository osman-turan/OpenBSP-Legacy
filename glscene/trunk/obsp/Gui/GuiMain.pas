//
//  Project     : OpenBSP Map Compiler
//  Unit        : GuiMain.pas
//  Description : GUI interface
//  History     :
//    05/02/05 - OT - Added configuration saving
//    08/01/05 - OT - Removed -saturatelighting argument
//    05/08/04 - OT - UI has changed
//    09/06/04 - OT - Added time based updating
//    20/05/04 - OT - Creation
//
unit GuiMain;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ExtCtrls, Menus, Buttons, obspCompiler, ComCtrls, FileCtrl,
  Spin, IniFiles
  {$IFDEF VER150}
  ,XPMan
  {$ENDIF}
  ;

type
  TFormMain = class(TForm)
    EMapFile: TEdit;
    LblInputFile: TLabel;
    BtnOpenInput: TBitBtn;
    Console: TMemo;
    OpenMapDialog: TOpenDialog;
    BtnCompile: TBitBtn;
    PBWork: TProgressBar;
    LblStatus: TLabel;
    Label1: TLabel;
    EGameFolder: TEdit;
    BitBtn1: TBitBtn;
    GroupBox1: TGroupBox;
    LVOptions: TListView;
    Label2: TLabel;
    SESubSampling: TSpinEdit;
    procedure FormCreate(Sender: TObject);
    procedure BtnOpenInputClick(Sender: TObject);
    procedure BtnCompileClick(Sender: TObject);
    procedure BitBtn1Click(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
    FWorkingPath: String;
    FCompiler: TCompiler;
    FLastUpdate: Cardinal;
    FActiveWorkCount: Integer;
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
  end;

var
  FormMain: TFormMain;

implementation

{$R *.dfm}

uses obspVersion, obspLighting, obspMultiThreading;

const
  CONFIG_FILENAME = 'Config.cfg';
  CONFIG_SECTION  = 'OpenBSP Compiler';
  CONFIG_GAMEPATH = 'GamePath';
  CONFIG_LASTMAP  = 'LastMap';

procedure TFormMain.FormCreate(Sender: TObject);
var
  cfgFile: TIniFile;
  s: String;
begin
  FWorkingPath := ExtractFilePath(Application.ExeName);

  cfgFile := TIniFile.Create(FWorkingPath + CONFIG_FILENAME);
  try
    s := cfgFile.ReadString(CONFIG_SECTION, CONFIG_LASTMAP, '..\Media\maps\doom3_test.map');
    EMapFile.Text := ExpandFileName(s);
    s := cfgFile.ReadString(CONFIG_SECTION, CONFIG_GAMEPATH, '..\Media\');
    EGameFolder.Text := ExpandFileName(s);
  finally
    cfgFile.Free;
  end;

  Console.Lines.Add('OpenBSP Map Compiler');
  Console.Lines.Add(Format('Version: %s, %s', [APP_VERSION, APP_DATE]));
  Console.Lines.Add('Powered by OpenBSP Community');
  Console.Lines.Add('');
  if IsMultiThreadingEnabled then
  begin
    Console.Lines.Add('Multi-Threading Detected');
    Console.Lines.Add('');
  end;
  FCompiler := TCompiler.Create;
  FCompiler.OnStartWork := EventStartWork;
  FCompiler.OnEndWork := EventEndWork;
  FCompiler.OnProgress := EventProgress;
  FCompiler.OnMessage := EventMessage;
  FCompiler.OnError := EventError;

// set clamping values
  SESubSampling.MinValue := MIN_LIGHT_SUBSAMPLES;
  SESubSampling.MaxValue := MAX_LIGHT_SUBSAMPLES;
end;

procedure TFormMain.BtnOpenInputClick(Sender: TObject);
begin
  if OpenMapDialog.Execute then
    EMapFile.Text := OpenMapDialog.FileName;
end;

procedure TFormMain.BtnCompileClick(Sender: TObject);
begin
  FCompiler.DisableMP := LVOptions.Items.Item[0].Checked;
  FCompiler.Lighting.NoLightmaps := LVOptions.Items.Item[1].Checked;
  FCompiler.Lighting.NoShadows := LVOptions.Items.Item[2].Checked;
  FCompiler.Lighting.SaveLightmaps := LVOptions.Items.Item[3].Checked;
  FCompiler.Lighting.SubSamples := SESubSampling.Value;

  FCompiler.GamePath := EGameFolder.Text;

  if FCompiler.Compile(EMapFile.Text) then
  begin
    Console.Lines.Add('');
    Console.Lines.Add('Compiling was successfully completed');
  end
  else
  begin
    Console.Lines.Add('');
    Console.Lines.Add('Compiling was failed')
  end;
end;

procedure TFormMain.EventEndWork(Sender: TObject; const ElapsedTime: Extended);
begin
  Dec(FActiveWorkCount);
  if FActiveWorkCount = 0 then
    PBWork.Position := 100;

  Console.Lines.Add(Format('Finished: %.3f secs', [ElapsedTime]));
  LblStatus.Caption := 'Finished';
  Application.ProcessMessages;
end;

procedure TFormMain.EventProgress(Sender: TObject; const Percent: Integer);
begin
  if GetTickCount - FLastUpdate < 100 then Exit;

  FLastUpdate := GetTickCount;
  PBWork.Position := Percent;
end;

procedure TFormMain.EventStartWork(Sender: TObject; const Msg: String);
begin
  if FActiveWorkCount = 0 then
    Console.Lines.Add('');

  Console.Lines.Add(StringOfChar(' ', FActiveWorkCount * 2) +
                    '> '+
                    Msg);
  LblStatus.Caption := Msg;
  Application.ProcessMessages;

  Inc(FActiveWorkCount);
end;

procedure TFormMain.EventMessage(Sender: TObject; const Msg: String);
begin
  Console.Lines.Add(StringOfChar(' ', FActiveWorkCount * 2) + Msg);
  Console.Update;
end;

procedure TFormMain.EventError(Sender: TObject; const Msg: String);
begin
  Console.Lines.Add('');
  Console.Lines.Add(StringOfChar('-', 20)+'ERROR'+StringOfChar('-', 20));
  Console.Lines.Add(Msg);
  Console.Lines.Add(StringOfChar('-', 45));
  LblStatus.Caption := 'An error has occured';
end;

procedure TFormMain.BitBtn1Click(Sender: TObject);
var dir: String;
begin
  if SelectDirectory('Select game folder:', '', dir) then
    EGameFolder.Text := IncludeTrailingBackslash(dir);
end;

procedure TFormMain.FormDestroy(Sender: TObject);
var cfgFile: TIniFile;
begin
  cfgFile := TIniFile.Create(FWorkingPath + CONFIG_FILENAME);
  try
    cfgFile.WriteString(CONFIG_SECTION, CONFIG_LASTMAP, EMapFile.Text);
    cfgFile.WriteString(CONFIG_SECTION, CONFIG_GAMEPATH, EGameFolder.Text);
  finally
    cfgFile.Free;
  end;
end;

end.
