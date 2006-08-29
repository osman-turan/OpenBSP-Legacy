//
//  Project     : OpenBSP Map Compiler
//  Unit        : obspUtils.pas
//  Description : Utility function
//  History:
//    24/07/04 - OT - Generic QuickSort routine added
//    18/06/04 - OT - Creation
//
unit obspUtils;

interface

type
  TQSortCompFunc = function(Argument1, Argument2: Pointer): Integer;

function TryStrToFloatGeneric(const strValue : String; out Val: Extended): Boolean;
procedure QuickSort(Base: Pointer; ElementSize, Count: Cardinal; CompareFunc: TQSortCompFunc);
function ConvertDosPathToUnixPath(Path: String): String;
function ConvertUnixPathToDosPath(Path: String): String;

implementation

// taken from GLScene (Eric Grange - www.glscene.org)
function TryStrToFloatGeneric(const strValue : String; out val : Extended): Boolean;
var
   i, j, divider, lLen, exponent : Integer;
   c : Char;
   v : Extended;
begin
   if strValue='' then begin
      Result:=False;
      Exit;
   end else v:=0;
   lLen:=Length(strValue);
   while (lLen>0) and (strValue[lLen]=' ') do Dec(lLen);
   divider:=lLen+1;
   exponent:=0;
	for i:=1 to lLen do begin
      c:=strValue[i];
      case c of
         ' ' : if v<>0 then begin
            Result:=False;
            Exit;
         end;
         '0'..'9' : v:=(v*10)+Integer(c)-Integer('0');
         ',', '.' : begin
            if (divider>lLen) then
               divider:=i+1
            else begin
               Result:=False;
               Exit;
            end;
         end;
         '-', '+' : if i>1 then begin
            Result:=False;
            Exit;
         end;
         'e', 'E' : begin
            if i+1>lLen then begin
               Result:=False;
               Exit;
            end;
            for j:=i+1 to lLen do begin
               c:=strValue[j];
               case c of
                  '-', '+' : if j<>i+1 then begin
         				Result:=False;
                     Exit;
                  end;
                  '0'..'9' : exponent:=(exponent*10)+Integer(c)-Integer('0');
               else
                  Result:=False;
                  Exit;
               end;
            end;
            if strValue[i+1]<>'-' then
               exponent:=-exponent;
            exponent:=exponent-1;
            lLen:=i;
            if divider>lLen then
               divider:=lLen;
            Break;
         end;
		else
         Result:=False;
         Exit;
      end;
   end;
   divider:=lLen-divider+exponent+1;
   if strValue[1]='-' then begin
      v:=-v;
   end;
   if divider<>0 then
      v:=v*Exp(-divider*Ln(10));
   val:=v;
   Result:=True;
end;

// taken from Quantum Engine (Osman Turan)
procedure qsort_r(Base: Pointer; ElementSize: Integer; CompareFunc: TQSortCompFunc;
  Left, Right: Integer; TempBuffer1, TempBuffer2: Pointer);
var
  Lo, Hi: Integer;
  P: Pointer;
begin
  Lo := Left;
  Hi := Right;
  P := Pointer(Integer(Base) + ((Lo + Hi) div 2) * ElementSize);
  Move(P^, TempBuffer2^, ElementSize);
  repeat
    while CompareFunc(Pointer(Integer(Base) + Lo * ElementSize), TempBuffer2) < 0 do Inc(Lo);
    while CompareFunc(Pointer(Integer(Base) + Hi * ElementSize), TempBuffer2) > 0 do Dec(Hi);
    if Lo <= Hi then
    begin
      Move(Pointer(Integer(Base) + Lo * ElementSize)^, TempBuffer1^, ElementSize);
      Move(Pointer(Integer(Base) + Hi * ElementSize)^, Pointer(Integer(Base) + Lo * ElementSize)^, ElementSize);
      Move(TempBuffer1^, Pointer(Integer(Base) + Hi * ElementSize)^, ElementSize);
      Inc(Lo);
      Dec(Hi);
    end;
  until Lo > Hi;

  if Hi > Left then qsort_r(Base, ElementSize, CompareFunc, Left, Hi, TempBuffer1, TempBuffer2);
  if Lo < Right then qsort_r(Base, ElementSize, CompareFunc, Lo, Right, TempBuffer1, TempBuffer2);
end;

procedure QuickSort(Base: Pointer; ElementSize, Count: Cardinal; CompareFunc: TQSortCompFunc);
var p1, p2: Pointer;
begin
  GetMem(p1, ElementSize);
  GetMem(p2, ElementSize);

  qsort_r(Base, ElementSize, CompareFunc, 0, Count-1, p1, p2);

  FreeMem(p1, ElementSize);
  FreeMem(p2, ElementSize);
end;

function ConvertDosPathToUnixPath(Path: String): String;
var
  i, len: Integer;
  s: String;
begin
  len := Length(Path);
  SetLength(s, len);
  
  for i:=1 to len do
  begin
    if Path[i] = '\' then
      s[i] := '/'
    else
      s[i] := Path[i];
  end;

  Result := s;
end;

function ConvertUnixPathToDosPath(Path: String): String;
var
  i, len: Integer;
  s: String;
begin
  len := Length(Path);
  SetLength(s, len);
  
  for i:=1 to len do
  begin
    if Path[i] = '/' then
      s[i] := '\'
    else
      s[i] := Path[i];
  end;

  Result := s;
end;

end.
