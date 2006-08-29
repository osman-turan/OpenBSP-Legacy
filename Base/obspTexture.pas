//
//  Project     : OpenBSP Map Compiler
//  Unit        : obspTexture.pas
//  Description : Texture utilities
//  History     :
//    01/11/04 - OT - Added LoadTGATexture function
//    12/09/04 - OT - Creation
//
unit obspTexture;

interface

uses SysUtils, Graphics, JPEG, obspBaseTypes, obspMath, obspTGA;

type
// 32-bits images
  PTexture = ^TTexture;
  TTexture = packed record
    Width, Height: Integer;
    Pixels: PVector4bArray;
  end;

// BGR(A) <=> RGB(A) routines
procedure SwapColor24(const Src, Dst: Pointer; const Size: Cardinal);
procedure SwapColor32(const Src, Dst: Pointer; const Count: Cardinal);

function SampleTexture(Texture: PTexture; ST: TVector2f): TVector4b;
function SampleTextureSmooth(Texture: PTexture; ST: TVector2f): TVector4b;

function LoadJPEGTexture(Filename: String; Texture: PTexture): Boolean;
function LoadTGATexture(Filename: String; Texture: PTexture): Boolean;

implementation

//------------------------------------------------------------------------------
// SwapColor24
//------------------------------------------------------------------------------
procedure SwapColor24(const Src, Dst: Pointer; const Size: Cardinal);
// Src -> EAX
// Dst -> EDX
// Size -> ECX
asm
        OR      ECX, ECX
        JZ      @@Exit

        PUSH    ESI
        PUSH    EDI

        MOV     ESI, EAX
        MOV     EDI, EDX

        CLD
        XOR     EAX, EAX
@@ProcessPixel:
        MOV     AL, [ESI+2]
        MOV     AH, [ESI+1]
        STOSW
        MOV     AL, [ESI]
        STOSB
        ADD     ESI, 3
        LOOP    @@ProcessPixel

        POP     EDI
        POP     ESI
@@Exit:
end;

//------------------------------------------------------------------------------
// SwapColor32
//------------------------------------------------------------------------------
procedure SwapColor32(const Src, Dst: Pointer; const Count: Cardinal);
// EAX stores Src
// EDX stores Dst
// ECX stores Count
asm
        OR      ECX, ECX
        JZ      @@Exit

        PUSH    ESI
        PUSH    EDI

        MOV     ESI, EAX
        MOV     EDI, EDX
        CLD
@@ProcessPixel:
        MOV     EAX, [ESI]
        SHL     EAX, 8
        MOV     AL, [ESI+3]
        BSWAP   EAX
        STOSD
        ADD     ESI, 4
        LOOP    @@ProcessPixel

        POP     EDI
        POP     ESI
@@Exit:
end;

function SampleTexture(Texture: PTexture; ST: TVector2f): TVector4b;
var
  x, y: Integer;
  coords: TVector2f;
begin
  vec_clear(Result);

  if not Assigned(Texture) then
    Exit;

  if not Assigned(Texture^.Pixels) then
    Exit;

// bias coordinates
  coords[0] := Abs(ST[0] - Trunc(ST[0]));
  coords[1] := Abs(ST[1] - Trunc(ST[1]));

// get offsets
  x := Trunc((Texture^.Width * coords[0]) + 0.5);
  x := x mod Texture^.Width;

  y := Trunc((Texture^.Width * coords[1]) + 0.5);
  y := y mod Texture^.Height;

// copy pixel
  Result := Texture^.Pixels[Texture.Width * y + x];
end;

function SampleTextureSmooth(Texture: PTexture; ST: TVector2f): TVector4b;
var
  x0, y0, x1, y1: Integer;
  pixels: array[0..3] of TVector4b;
  coords: TVector2f;
begin
  vec_clear(Result);

  if not Assigned(Texture) then
    Exit;

  if not Assigned(Texture^.Pixels) then
    Exit;

// bias coordinates
  coords[0] := Abs(ST[0] - Trunc(ST[0]));
  coords[1] := Abs(ST[1] - Trunc(ST[1]));

// get offsets
  x0 := Trunc((Texture^.Width * coords[0]) + 0.5);
  x0 := x0 mod Texture^.Width;

  y0 := Trunc((Texture^.Width * coords[1]) + 0.5);
  y0 := y0 mod Texture^.Height;

  x1 := (x0 + 1) mod Texture^.Width;
  y1 := (y0 + 1) mod Texture^.Height;

// copy pixel
  pixels[0] := Texture^.Pixels[Texture.Width * y0 + x0];
  pixels[1] := Texture^.Pixels[Texture.Width * y0 + x1];
  pixels[2] := Texture^.Pixels[Texture.Width * y1 + x1];
  pixels[3] := Texture^.Pixels[Texture.Width * y1 + x0];

  Result[0] := (pixels[0][0] + pixels[1][0] + pixels[2][0] + pixels[3][0]) shr 2;
  Result[1] := (pixels[0][1] + pixels[1][1] + pixels[2][1] + pixels[3][1]) shr 2;
  Result[2] := (pixels[0][2] + pixels[1][2] + pixels[2][2] + pixels[3][2]) shr 2;
  Result[3] := (pixels[0][3] + pixels[1][3] + pixels[2][3] + pixels[3][3]) shr 2;
end;

function LoadJPEGTexture(Filename: String; Texture: PTexture): Boolean;
var
  jpgImage: TJPEGImage;
  bitmap: TBitmap;
  y: Integer;
begin
  Result := False;

  if not FileExists(Filename) then Exit;

  jpgImage := TJPEGImage.Create;
  try
    jpgImage.LoadFromFile(Filename);

    bitmap := TBitmap.Create;
    bitmap.Width := jpgImage.Width;
    bitmap.Height := jpgImage.Height;
    bitmap.PixelFormat := pf32Bit;
    try
      bitmap.Canvas.Draw(0, 0, jpgImage);

      Texture.Width := bitmap.Width;
      Texture.Height := bitmap.Height;
      GetMem(Texture.Pixels, Texture.Width * Texture.Height * SizeOf(TVector4b));

      for y:=0 to bitmap.Height-1 do
        SwapColor32(bitmap.ScanLine[y], @Texture.Pixels[y * Texture.Width], bitmap.Width);
    finally
      bitmap.Free;
    end;

    Result := True;
  finally
    jpgImage.Free;
  end;
end;

function LoadTGATexture(Filename: String; Texture: PTexture): Boolean;
var
  tgaImage: TTGAImage;
begin
  Result := False;

  if not FileExists(Filename) then Exit;

  tgaImage := TTGAImage.Create;
  try
    if tgaImage.LoadFromFile(Filename) then
    begin
      Texture.Width := tgaImage.Width;
      Texture.Height := tgaImage.Height;
      GetMem(Texture.Pixels, Texture.Width * Texture.Height * SizeOf(TVector4b));

      Move(tgaImage.GetPixelsAsAddress^, Texture.Pixels^, tgaImage.Width * tgaImage.Height * 4);
      Result := True;
    end;
  finally
    tgaImage.Free;
  end;
end;

end.
