//
//  Project     : OpenBSP Map Compiler
//  Unit        : obspBaseTypes.pas
//  Description : Base types
//  History     :
//    10/12/04 - OT - TQuaternion added
//    11/07/04 - OT - TSphere added
//    09/06/04 - OT - Creation
//
unit obspBaseTypes;

interface

type
  TSideClassify = (scOn, scCross, scFront, scBack);
// Math types
  TVector2f = array[0..1] of Single;
  TVector2x = array[0..1] of Extended;

  TVector3f = array[0..2] of Single;
  TVector3x = array[0..2] of Extended;
  TVector3b = array[0..2] of Byte;
  TVector3i = array[0..2] of Integer;

  TVector4f = array[0..3] of Single;
  TVector4x = array[0..3] of Extended;
  TVector4b = array[0..3] of Byte;
  TVector4i = array[0..3] of Integer;

  TRecti = array[0..3] of Integer;

  TMatrix4f = array[0..3] of TVector4f;

  TPackedNormal = array[0..1] of Byte;

  PPlane = ^TPlane;
  TPlane = packed record
    Normal: TVector3f;
    Dist: Single;
  end;

  TQuaternion = record
    ImagPart: TVector3f;
    RealPart: Single;
  end;

  TSphere = packed record
    Origin: TVector3f;
    Radius: Single;
  end;

  PAABB = ^TAABB;
  TAABB = packed record
    Mins: TVector3f;
    Maxs: TVector3f;
  end;

  PVector2f = ^TVector2f;
  PVector3f = ^TVector3f;
  PVector4b = ^TVector4b;

  PSingleArray = ^TSingleArray;
  TSingleArray = array[0..MAXINT shr 3] of Single;

  PVector3bArray = ^TVector3bArray;
  TVector3bArray = array[0..MAXINT shr 2] of TVector3b;

  PVector4bArray = ^TVector4bArray;
  TVector4bArray = array[0..MAXINT shr 3] of TVector4b;

  PCardinalArray = ^TCardinalArray;
  TCardinalArray = array[0..MAXINT shr 3] of Cardinal;

implementation

end.
