//
//  Project     : OpenBSP Map Compiler
//  Unit        : obspTGA.pas
//  Description : Targa (TGA) image loader
//  History     :
//    06/11/04 - OT - Creation
//
unit obspTGA;

interface

uses SysUtils, Classes, obspBaseTypes;

const
  TARGA_NO_COLORMAP = 0;
  TARGA_COLORMAP = 1;

  TARGA_EMPTY_IMAGE = 0;
  TARGA_INDEXED_IMAGE = 1;
  TARGA_TRUECOLOR_IMAGE = 2;
  TARGA_BW_IMAGE = 3;
  TARGA_INDEXED_RLE_IMAGE = 9;
  TARGA_TRUECOLOR_RLE_IMAGE = 10;
  TARGA_BW_RLE_IMAGE = 11;

type
  TTargaHeader = packed record
    IDLength,
    ColorMapType,
    ImageType: Byte;
    ColorMapOrigin,
    ColorMapSize: Word;
    ColorMapEntrySize: Byte;
    XOrigin,
    YOrigin,
    Width,
    Height: Word;
    PixelSize: Byte;
    ImageDescriptor: Byte;
  end;


  TTGAImage = class
  private
    FHeader: TTargaHeader;
    FData: PVector4bArray;
    function GetHeight: Integer;
    function GetWidth: Integer;
  protected
    procedure DecodeRLE(Source, Dest: Pointer; FlipVertical: Boolean);
  public
    constructor Create;
    destructor Destroy; override;

    function LoadFromStream(Stream: TStream): Boolean;
    function LoadFromFile(Filename: String): Boolean;

    function GetPixelsAsAddress: Pointer;
    property Width: Integer read GetWidth;
    property Height: Integer read GetHeight;
  end;

implementation

{ TTGAImage }

constructor TTGAImage.Create;
begin
  FillChar(FHeader, SizeOf(TTargaHeader), 0);
  FData := nil;
end;

procedure TTGAImage.DecodeRLE(Source, Dest: Pointer; FlipVertical: Boolean);
var
  Color: TVector4b;
  SourcePtr,
  TargetPtr: PChar;
  PacketHeader: Byte;
  PacketSize, row, column: Integer;
begin
  SourcePtr := Source;
  row := FHeader.Height-1;

  case FHeader.PixelSize of
    24:
      while (row >= 0) do
      begin
        column := 0;
        if FlipVertical then
          TargetPtr := Pointer(Integer(Dest) + row * FHeader.Width * 4)
        else
          TargetPtr := Pointer(Integer(Dest) + (FHeader.Height-(row+1)) * FHeader.Width * 4);

        while (column < FHeader.Width) do
        begin
          PacketHeader := Byte(SourcePtr[0]);
          PacketSize := 1 + (PacketHeader and $7F); 
          Inc(SourcePtr);

          if PacketHeader > $7F then  // run-length packet
          begin
            Color[0] := Byte(SourcePtr[2]);
            Color[1] := Byte(SourcePtr[1]);
            Color[2] := Byte(SourcePtr[0]);
            Color[3] := $FF;
            Inc(SourcePtr, 3);

            while PacketSize > 0 do
            begin
              PVector4b(TargetPtr)^ := Color;
              Inc(TargetPtr, 4);
              Dec(PacketSize);
              Inc(column);

              if (column = FHeader.Width) then // run spans across rows
              begin
                column := 0;
                if row > 0 then
                  Dec(row)
                else
                  Exit;

                if FlipVertical then
                  TargetPtr := Pointer(Integer(Dest) + row * FHeader.Width * 4)
                else
                  TargetPtr := Pointer(Integer(Dest) + (FHeader.Height-(row+1)) * FHeader.Width * 4);
              end;
            end;
          end
          else                        // non run-length packet
          begin
            while PacketSize > 0 do
            begin
              TargetPtr[0] := SourcePtr[2];
              TargetPtr[1] := SourcePtr[1];
              TargetPtr[2] := SourcePtr[0];
              TargetPtr[3] := Char(255);

              Inc(SourcePtr, 3);
              Inc(TargetPtr, 4);
              Dec(PacketSize);
              Inc(column);

              if (column = FHeader.Width) then // pixel packet run spans across rows
              begin
                column := 0;
                if row > 0 then
                  Dec(row)
                else
                  Exit;

                if FlipVertical then
                  TargetPtr := Pointer(Integer(Dest) + row * FHeader.Width * 4)
                else
                  TargetPtr := Pointer(Integer(Dest) + (FHeader.Height-(row+1)) * FHeader.Width * 4);
              end;
            end;
          end;
        end;
      end;

    32:
      while (row >= 0) do
      begin
        column := 0;
        if FlipVertical then
          TargetPtr := Pointer(Integer(Dest) + row * FHeader.Width * 4)
        else
          TargetPtr := Pointer(Integer(Dest) + (FHeader.Height-(row+1)) * FHeader.Width * 4);

        while (column < FHeader.Width) do
        begin
          PacketHeader := Byte(SourcePtr[0]);
          PacketSize := 1 + (PacketHeader and $7F); 
          Inc(SourcePtr);

          if PacketHeader > $7F then  // run-length packet
          begin
            Color[0] := Byte(SourcePtr[2]);
            Color[1] := Byte(SourcePtr[1]);
            Color[2] := Byte(SourcePtr[0]);
            Color[3] := Byte(SourcePtr[3]);
            Inc(SourcePtr, 4);

            while PacketSize > 0 do
            begin
              PVector4b(TargetPtr)^ := Color;
              Inc(TargetPtr, 4);
              Dec(PacketSize);
              Inc(column);

              if (column = FHeader.Width) then // run spans across rows
              begin
                column := 0;
                if row > 0 then
                  Dec(row)
                else
                  Exit;

                if FlipVertical then
                  TargetPtr := Pointer(Integer(Dest) + row * FHeader.Width * 4)
                else
                  TargetPtr := Pointer(Integer(Dest) + (FHeader.Height-(row+1)) * FHeader.Width * 4);
              end;
            end;
          end
          else                        // non run-length packet
          begin
            while PacketSize > 0 do
            begin
              TargetPtr[0] := SourcePtr[2];
              TargetPtr[1] := SourcePtr[1];
              TargetPtr[2] := SourcePtr[0];
              TargetPtr[3] := SourcePtr[3];

              Inc(SourcePtr, 4);
              Inc(TargetPtr, 4);
              Dec(PacketSize);
              Inc(column);

              if (column = FHeader.Width) then // pixel packet run spans across rows
              begin
                column := 0;
                if row > 0 then
                  Dec(row)
                else
                  Exit;

                if FlipVertical then
                  TargetPtr := Pointer(Integer(Dest) + row * FHeader.Width * 4)
                else
                  TargetPtr := Pointer(Integer(Dest) + (FHeader.Height-(row+1)) * FHeader.Width * 4);
              end;
            end;
          end;
        end;
      end;
  end;
end;

destructor TTGAImage.Destroy;
begin
  if Assigned(FData) then
    FreeMem(FData);
  inherited;
end;

function TTGAImage.GetHeight: Integer;
begin
  Result := FHeader.Height;
end;

function TTGAImage.GetPixelsAsAddress: Pointer;
begin
  Result := FData;
end;

function TTGAImage.GetWidth: Integer;
begin
  Result := FHeader.Width;
end;

function TTGAImage.LoadFromFile(Filename: String): Boolean;
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

function TTGAImage.LoadFromStream(Stream: TStream): Boolean;
var
  Buffer: PChar;
  i, x: Integer;
  LineSize: Integer;
  LineBuffer: PByteArray;
  Row: PVector4bArray;
  FlipV: Boolean;
begin
  Result := False;
  FillChar(FHeader, SizeOf(TTargaHeader), 0);

// read header
  Stream.Read(FHeader, SizeOf(TTargaHeader));
  FlipV := (FHeader.ImageDescriptor and $20) <> 0;
  FHeader.ImageDescriptor := FHeader.ImageDescriptor and $0F;

// skip image ID
  if FHeader.IDLength > 0 then
    Stream.Seek(FHeader.IDLength, soFromCurrent);

  if (FHeader.ColorMapType <> TARGA_NO_COLORMAP) then Exit; // Colormap not supported

  LineSize := FHeader.Width * (FHeader.PixelSize div 8);
  GetMem(LineBuffer, LineSize);
  ReallocMem(FData, FHeader.Width * FHeader.Height * SizeOf(TVector4b));
  FillChar(FData^, FHeader.Width * FHeader.Height * SizeOf(TVector4b), 0);

  try
    case FHeader.ImageType of
      TARGA_EMPTY_IMAGE:          // nothing to do here
        ;
      TARGA_BW_IMAGE:             // Uncompressed gray scale image
        begin
          for i:=0 to FHeader.Height-1 do
          begin
            Stream.ReadBuffer(LineBuffer^, LineSize);
            if FlipV then
              Row := @FData[(FHeader.Height - (I + 1)) * FHeader.Width]
            else
              Row := @FData[I * FHeader.Width];

            for x:=0 to FHeader.Width-1 do
            begin
              Row[x][0] := LineBuffer[x];
              Row[x][1] := LineBuffer[x];
              Row[x][2] := LineBuffer[x];
              Row[x][3] := 255;
            end;
          end;
        end;
      TARGA_TRUECOLOR_IMAGE:       // Uncompressed RGB(A) image
        begin
          case FHeader.PixelSize of
            24: begin
                  for i:=0 to FHeader.Height-1 do
                  begin
                    Stream.ReadBuffer(LineBuffer^, LineSize);
                    if FlipV then
                      Row := @FData[(FHeader.Height - (i + 1)) * FHeader.Width]
                    else
                      Row := @FData[i * FHeader.Width];
  
                    for x:=0 to FHeader.Width-1 do
                    begin
                      Row[x][0] := LineBuffer[x*3+2];
                      Row[x][1] := LineBuffer[x*3+1];
                      Row[x][2] := LineBuffer[x*3+0];
                      Row[x][3] := 255;
                    end;
                  end;
                end;
            32: begin
                  for i:=0 to FHeader.Height-1 do
                  begin
                    Stream.ReadBuffer(LineBuffer^, LineSize);
                    if FlipV then
                      Row := @FData[(FHeader.Height - (i + 1)) * FHeader.Width]
                    else
                      Row := @FData[i * FHeader.Width];
  
                    for x:=0 to FHeader.Width-1 do
                    begin
                      Row[x][0] := LineBuffer[x*4+2];
                      Row[x][1] := LineBuffer[x*4+1];
                      Row[x][2] := LineBuffer[x*4+0];
                      Row[x][3] := LineBuffer[x*4+3];
                    end;
                  end;
                end;
          end;
        end;
      TARGA_TRUECOLOR_RLE_IMAGE:
        begin
          Buffer := nil; // shut-up compiler
          try
            GetMem(Buffer, FHeader.Height * LineSize);
            Stream.Read(Buffer^, FHeader.Height * LineSize);
            DecodeRLE(Buffer, FData, FlipV);
          finally
            if Assigned(Buffer) then FreeMem(Buffer);
          end;
        end;
    end;

    Result := True;
  finally
    FreeMem(LineBuffer);
  end;
end;

end.
