//
//  Project     : OpenBSP Map Compiler
//  Unit        : obspParser.pas
//  Description : Quake style script parser
//  History:
//    04/11/04 - OT - Added "/* */" comments support  
//    21/07/04 - OT - Added "#" and ";" comments support
//    21/06/04 - OT - Parsing skeleton has changed
//    09/06/04 - OT - Fixed incorrect parsing
//    20/05/04 - OT - Creation
//
unit obspParser;

interface

uses SysUtils, Classes;

type
  TTextParser = class
  private
    FSource: String;
    FSize: Integer;
    FToken: String;
    FPos: Integer;
    FLine: Integer;
    FTokenReady: Boolean;
  protected
    procedure ResetParser;
  public
    constructor Create;
    destructor Destroy; override;

    function GetNextToken: Boolean;
    procedure UnGetToken;
    function TokenAvailable: Boolean;
    procedure SkipLine;

    procedure LoadFromFile(const Filename: String);
    procedure LoadFromStream(const Stream: TStream);
    procedure LoadFromString(const S: String);

    property Token: String read FToken;
    property Position: Integer read FPos;
    property Line: Integer read FLine;
    property Size: Integer read FSize;
  end;

implementation

{ TTextParser }

// TTextParser.Create
//
constructor TTextParser.Create;
begin
  ResetParser;
end;

// TTextParser.Destroy
//
destructor TTextParser.Destroy;
begin
  FSource := '';
  inherited;
end;

// TTextParser.GetNextToken
//
function TTextParser.GetNextToken: Boolean;
var Start: Integer;
begin
  if FTokenReady then
  begin
    FTokenReady := False;
    Result := True;
    Exit;
  end;

  Result := False;

  while FPos <= FSize do
  begin
    case FSource[FPos] of
      #0..#32: begin
                 if FPos > FSize then Exit;
                 case FSource[FPos] of
                   #10: Inc(FLine);
                   #13: begin
                          if FPos+1 <= FSize then
                          begin
                            if FSource[FPos+1] = #10 then
                              Inc(FPos);
                          end;

                        Inc(FLine);
                      end;
                 end;

                 Inc(FPos);
               end;

      ';', '#':begin
                 Inc(FPos);

                 while FPos <= FSize do
                   case FSource[FPos] of
                     #10: begin
                            Inc(FLine);
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

                            Inc(FLine);
                            Break;
                          end;
                   else
                     Inc(FPos);
                   end;
               end;
      '/':     begin
                 Inc(FPos);
                 if FPos <= FSize then
                 begin
                   case FSource[FPos] of
                     '/': begin
                            Inc(FPos);

                            while FPos <= FSize do
                            case FSource[FPos] of
                              #10: begin
                                     Inc(FLine);
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

                                     Inc(FLine);
                                     Break;
                                   end;
                              else
                                Inc(FPos);
                            end;
                          end;
                     '*': begin
                            Inc(FPos);

                            while FPos <= FSize do
                            case FSource[FPos] of
                              #10: begin
                                     Inc(FLine);
                                     Inc(FPos);
                                   end;
                              #13: begin
                                     Inc(FPos);
                                     if FPos <= FSize then
                                     begin
                                       if FSource[FPos] = #10 then
                                         Inc(FPos);
                                     end;

                                     Inc(FLine);
                                   end;
                              '*': begin
                                     Inc(FPos);
                                     if FPos <= FSize then
                                     begin
                                       if FSource[FPos] = '/' then
                                       begin
                                         Inc(FPos);
                                         Break;
                                       end;
                                     end;
                                   end;
                              else
                                Inc(FPos);
                            end;
                          end;
                   end;
                 end;
               end;
      '"':     begin
                 Inc(FPos);
                 Start := FPos;

                 while FPos <= FSize do
                 begin
                   if FSource[FPos] = '"' then Break;
                   Inc(FPos);
                 end;

                 FToken := Copy(FSource, Start, FPos-Start);

                 Inc(FPos);

                 Result := True;
                 Break;
               end;
    else
      begin
        Start := FPos;

        while (FSource[FPos] > #32) and (FSource[FPos] <> ';') do
        begin
          Inc(FPos);
          if FPos > FSize then Break;
        end;

        FToken := Copy(FSource, Start, FPos-Start);

        Result := True;
        Break;
      end;
    end;
  end;
end;

// TTextParser.LoadFromFile
//
procedure TTextParser.LoadFromFile(const Filename: String);
var f: TFileStream;
begin
  f := TFileStream.Create(Filename, fmOpenRead or fmShareDenyWrite);
  try
    LoadFromStream(f);
  finally
    f.Free;
  end;
end;

// TTextParser.LoadFromStream
//
procedure TTextParser.LoadFromStream(const Stream: TStream);
begin
  FSize := Stream.Size - Stream.Position;
  SetLength(FSource, FSize);
  Stream.ReadBuffer(FSource[1], FSize);
  FSize := Length(FSource);  

  ResetParser;
end;

// TTextParser.LoadFromString
//
procedure TTextParser.LoadFromString(const S: String);
begin
  FSource := S;
  FSize := Length(FSource);

  ResetParser;
end;

// TTextParser.ResetParser
//
procedure TTextParser.ResetParser;
begin
  FPos := 1;
  FLine := 1;
end;

procedure TTextParser.SkipLine;
begin
  while TokenAvailable do
  begin
    if not GetNextToken then
      Exit;
  end;
end;

function TTextParser.TokenAvailable: Boolean;
var oldline: Integer;
begin
  oldline := Line;

  if not GetNextToken then
  begin
    Result := False;
    Exit;
  end;

  UnGetToken;

  Result := (oldline = Line);
end;

procedure TTextParser.UnGetToken;
begin
  FTokenReady := True;
end;

end.
