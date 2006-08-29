//
//  Project     : OpenBSP Map Compiler
//  Unit        : obspMath.pas
//  Description : Math routines
//  History:
//    23/10/04 - OT - New routines
//    08/10/04 - OT - mat_transpose added
//    11/07/04 - OT - TSphere support
//    25/06/04 - OT - Fixed vec_transform
//                    Added vec_length
//                    Added TriangleArea
//    22/06/04 - OT - Added new routines
//    21/06/04 - OT - Creation
//
unit obspMath;

interface

uses obspBaseTypes;

const
  EPSILON_ZERO                  = 0.0;
  EPSILON                       = 0.0001;
  EPSILON_ON_SIDE               = 0.1;
  EPSILON_VECTOR_COMPARE        = 0.00001;
  EPSILON_30                    = 1E-30;

  EPSILON_SNAP_PLANE_NORMAL     = 0.00001;
  EPSILON_SNAP_PLANE_DIST       = 0.01;

  MAX_WORLD_COORD               = +65536;
  MIN_WORLD_COORD               = -65536;

  NullVector2f: TVector2f = (0, 0);  
  NullVector3f: TVector3f = (0, 0, 0);

  IdentityQuaternion: TQuaternion = (ImagPart:(0,0,0); RealPart: 1);

  IdentityMatrix: TMatrix4f = ( (1, 0, 0, 0),
                                (0, 1, 0, 0),
                                (0, 0, 1, 0),
                                (0, 0, 0, 1) );

// generic math routines
function DegToRad(const Degrees: Single): Single;
function RadToDeg(const Radians: Single): Single;
function NormalizeAngle(Angle: Single) : Single;
function NormalizeDegAngle(Angle: Single) : Single;
function IsNAN(x: Single):Boolean;
function Sin(Const theta: Single): Single; register;
function Cos(Const theta: Single): Single; register;
procedure SinCos(const Theta: Single; var Sin, Cos: Single); register;
function ArcCos(const x: Single) : Single;
function ArcSin(const X: Single) : Single;
function ArcTan2(const Y, X : Single) : Single;
function Tan(const X: Single): Single; overload;
function Tan(const X: Extended): Extended; overload;
function CoTan(const X : Single) : Single;
function Log2(X: Single): Single;
function Abs(X: Single) : Single;
function Trunc(v: Single) : Integer;
function Frac(v: Single) : Single;
function Floor(v: Single) : Integer;
function Ceil(v: Single) : Integer;
function Power(const Base, Exponent: Single): Single;
function MinFloat(const f1, f2: Single): Single;
function MaxFloat(const f1, f2: Single): Single;
function Clamp(Value, minValue, maxValue: Integer): Integer; overload;
function Clamp(Value, minValue, maxValue: Single): Single; overload;
function Clamp(Value, minValue, maxValue: Double): Double; overload;
function NearestPower(Value: Integer): Integer;
function TriangleArea(const p1, p2, p3: TVector3f): Single;

// vector routines
procedure vec_clear(var v: TVector3f); overload;
procedure vec_clear(var v: TVector2x); overload;
procedure vec_clear(var v: TVector3x); overload;
procedure vec_clear(var v: TVector4b); overload;
procedure vec_clear(var v: TVector4i); overload;
function vec_equals(v1, v2: TVector3f): Boolean;
function vec_make(X, Y: Single): TVector2f; overload;
function vec_make(X, Y, Z: Single): TVector3f; overload;
function vec_make(X, Y, Z, W: Byte): TVector4b; overload;
function vec_DegToRad(V: TVector3f): TVector3f;
function vec_RadToDeg(V: TVector3f): TVector3f;
function vec_add(const v1: TVector2x; const v2: TVector2f): TVector2x; overload;
function vec_add(const v1, v2: TVector3f): TVector3f; overload;
function vec_add(const v1, v2: TVector3x): TVector3x; overload;
function vec_add(const v1: TVector3x; const v2: TVector3f): TVector3x; overload;
function vec_add(const v1: TVector4i; const v2: TVector4b): TVector4i; overload;
function vec_sub(const v1, v2: TVector2f): TVector2f; overload;
function vec_sub(const v1, v2: TVector3f): TVector3f; overload;
function vec_scale(const v: TVector2x; const Scale: Extended): TVector2f; overload;
function vec_scale(const v: TVector3f; const Scale: Single): TVector3f; overload;
function vec_scale(const v: TVector3x; const Scale: Extended): TVector3f; overload;
function vec_scale(const v: TVector4i; const Scale: Extended): TVector4b; overload;
function vec_multiply(const v1, v2: TVector3f): TVector3f;
function vec_abs(const v: TVector3f): TVector3f;
procedure vec_min(var v: TVector3f; const v1: TVector3f);
procedure vec_max(var v: TVector3f; const v1: TVector3f);
function vec_negate(v: TVector3f): TVector3f;
function vec_dot(const v1, v2: TVector3f): Single;
function vec_cross(const v1, v2: TVector3f): TVector3f;
function vec_length(const v: TVector3f): Single;
function vec_spacing(const v1, v2: TVector2f): Single; overload;
function vec_spacing(const v1, v2: TVector3f): Single; overload;
function vec_dist(v1, v2: TVector3f): Single;
function vec_lerp(v1, v2: TVector3f; t: Single): TVector3f;
function vec_combine(const v1, v2 : TVector3f; const scale : Single): TVector3f;
function vec_normalize(const v: TVector3f): TVector3f;
function vec_normalizecolor(color: TVector3f): TVector3f;
function vec_saturate(color: TVector3f): TVector3f;
function vec_normalizesafe(const inv: TVector3f; out outv: TVector3f): Single;
function vec_colinearpoints(p1, p2, p3: TVector3f): Boolean;
function vec_closestpointonedge(from, a, b: TVector3f): TVector3f;
procedure vec_tangentspace(const normal: TVector3f;
                           var tangent, binormal: TVector3f);
function vec_transform_st(const v: TVector3f; const mat: TMatrix4f): TVector2f;
function vec_transform(const v: TVector3f; const mat: TMatrix4f): TVector3f;

// plane routines
function plane_normal(p1, p2, p3: TVector3f): TVector3f;
function plane_frompoints(const p1, p2, p3: TVector3f): TPlane;
function plane_make(normal, point: TVector3f): TPlane;
function plane_evaluatepoint(const plane: TPlane; const p: TVector3f): Single;
function plane_snap(const plane: TPlane): TPlane;
function plane_negate(const plane: TPlane): TPlane;
function plane_offset(Plane: TPlane; Position: TVector3f): TPlane;

// Sphere routines
function sphere_make(aabb: TAABB): TSphere;
function sphere_lineintersect(sphere: TSphere; p1, p2: TVector3f): Boolean;

// AABB routines
procedure aabb_clear(var aabb: TAABB);
procedure aabb_addpoint(var aabb: TAABB; p: TVector3f);
function aabb_Intersects(const AABB1, AABB2: TAABB): Boolean;
function aabb_LineIntersects(const AABB: TAABB;
                             const StartPoint, EndPoint: TVector3f): Boolean;

// matrix routines
procedure mat_Identity(var mat: TMatrix4f);
procedure mat_Transpose(var M: TMatrix4f);
function mat_Multiply(const M1, M2 : TMatrix4f) : TMatrix4f;
function mat_FromQuaternion(Quat: TQuaternion): TMatrix4f;
procedure mat_SetTranslation(var M: TMatrix4f; Translation: TVector3f);
function mat_CreateRotationMatrix(Angles: TVector3f): TMatrix4f;
function mat_CreateRotationMatrixX(Angle: Single): TMatrix4f;
function mat_CreateRotationMatrixY(Angle: Single): TMatrix4f;
function mat_CreateRotationMatrixZ(Angle: Single): TMatrix4f;
function mat_CreateScaleMatrix(Scale: Single): TMatrix4f; overload;
function mat_CreateScaleMatrix(Scale: TVector3f): TMatrix4f; overload;

// quaternion routines
function quat_Magnitude(Quat: TQuaternion): Single;
procedure quat_Normalize(var Quat: TQuaternion);

implementation

const
  cPI       : Single = 3.141592653;
  c2PI      : Single = 6.283185306;
  cPIdiv2   : Single = 1.570796326;
  cPIdiv180 : Single = 0.017453292;
  c180divPI : Single = 57.29577952;
  cInv2PI :   Single = 1/6.283185307;
  cInv360 :   Single = 1/360;
  c180 :      Single = 180;
  c360 :      Single = 360;

  cHalf : Single = 0.5;
  cOne  : Single = 1.0;
  cTwo  : Single = 2.0;
  cwChop : Word = $1F3F;

//------------------------------------------------------------------------------
// GENERIC MATH ROUTINES
//------------------------------------------------------------------------------

function DegToRad(const Degrees: Single): Single; register;
asm
//  Result:=Degrees * cPIdiv180;
  fld dword ptr [ebp+8]
  fmul cPIdiv180
end;

function RadToDeg(const Radians: Single): Single; register;
asm
//   Result:=Radians * c180divPI;
  fld dword ptr [ebp+8]
  fmul c180divPI
end;

function NormalizeAngle(Angle: Single): Single;
begin
  Result:=angle-Int(angle*cInv2PI)*c2PI;
  if Result>PI then
    Result:=Result-2*PI
  else if Result<-PI then
    Result:=Result+2*PI;
end;

function NormalizeDegAngle(Angle: Single): Single;
begin
  Result:=angle-Int(angle*cInv360)*c360;
  if Result>c180 then
    Result:=Result-c360
  else if Result<-c180 then
    Result:=Result+c360;
end;

function IsNAN(x: Single): Boolean;
Begin
  Result := ((PLongWord(@x)^ and $7F800000)  = $7F800000) and
            ((PLongWord(@x)^ and $007FFFFF) <> $00000000);
End;

function Sin(Const theta: Single): Single; register;
asm
  FLD theta
  FSIN
End;

function Cos(Const theta: Single): Single; register;
asm
  FLD theta
  FCOS
End;

procedure SinCos(const Theta: Single; var Sin, Cos: Single); register;
asm
  fld theta
  fsincos
  fstp dword ptr [edx]
  fstp dword ptr [eax]
end;

function ArcCos(const x : Single): Single; register;
// Result:=ArcTan2(Sqrt(c1 - X * X), X);
asm
  FLD   X
  FMUL  ST, ST
  FSUBR cOne
  FSQRT
  FLD   X
  FPATAN
end;

function ArcSin(const x : Single) : Single;
//   Result:=ArcTan2(X, Sqrt(1 - X * X))
asm
  FLD   X
  FLD   ST
  FMUL  ST, ST
  FSUBR cOne
  FSQRT
  FPATAN
end;

function ArcTan2(const y, x : Single) : Single;
asm
  FLD  Y
  FLD  X
  FPATAN
end;

function Tan(const x: Single): Single;
asm
  FLD  X
  FPTAN
  FSTP ST(0)      // FPTAN pushes 1.0 after result
end;

function Tan(const x: Extended): Extended;
asm
  FLD  X
  FPTAN
  FSTP ST(0)      // FPTAN pushes 1.0 after result
end;

function CoTan(const x : Single) : Single;
asm
  FLD  X
  FPTAN
  FDIVRP
end;

function Log2(X: Single): Single;
asm
  FLD1
  FLD X
  FYL2X
end;

function Abs(X : Single) : Single;
asm
  FLD X
  FABS
End;

function Trunc(v : Single) : Integer; register;
asm
  SUB     ESP,8
  FSTCW   [ESP]
  FLDCW   cwChop
  FLD     v
  FISTP   dword ptr [ESP+4]
  FLDCW   [ESP]
  POP     ECX
  POP     EAX
end;

function Frac(v : Single) : Single;
asm
  SUB     ESP,4
  FSTCW   [ESP]
  FLDCW   cwChop
  FLD     v
  FLD     ST
  FRNDINT
  FSUB
  FLDCW   [ESP]
  ADD     ESP,4
end;

function Floor(v : Single) : Integer;
begin
  if Frac(v) < 0 then
    Result:=Trunc(v)-1
  else
    Result:=Trunc(v);
end;

function Ceil(v : Single) : Integer;
begin
  if Frac(v) > 0 then
    Result:=Trunc(v)+1
  else
    Result:=Trunc(v);
end;

function Power(const Base, Exponent: Single): Single;
begin
  If Exponent = 0.0 then
    Result := 1.0 else
  If (Base = 0.0) and (Exponent > 0.0) then
    Result := 0.0 else
  Result := Exp(Exponent * Ln(Base));
end;

function MinFloat(const f1, f2: Single): Single;
begin
  if f1 < f2 then
    Result := f1
  else Result := f2;
end;

function MaxFloat(const f1, f2: Single): Single;
begin
  if f1 > f2 then
    Result := f1
  else Result := f2;
end;

function Clamp(Value, minValue, maxValue: Integer): Integer;
begin
  if Value > maxValue then
    Result := maxValue
  else if Value < minValue then
    Result := minValue
  else
    Result := Value;
end;

function Clamp(Value, minValue, maxValue: Single): Single;
begin
  if Value > maxValue then
    Result := maxValue
  else if Value < minValue then
    Result := minValue
  else
    Result := Value;
end;

function Clamp(Value, minValue, maxValue: Double): Double; 
begin
  if Value > maxValue then
    Result := maxValue
  else if Value < minValue then
    Result := minValue
  else
    Result := Value;
end;

function NearestPower(Value: Integer): Integer;
var i: Cardinal;
begin
  Result := 0;
  // Error!
  if (Value = 0) then Exit;

  i:=1;

  while True do
  begin
    if Value = 1 then
    begin
      Result := i;
      Exit;
    end
    else if Value = 3 then
    begin
      Result := i * 4;
      Exit;
    end;

    Value := Value div 2; //shr 1;
    i := i * 2;
  end;
end;

function TriangleArea(const p1, p2, p3: TVector3f): Single;
begin
   Result := 0.5 * vec_length(vec_cross(vec_sub(p2, p1),
                                        vec_sub(p3, p1)));
end;

//------------------------------------------------------------------------------
// VECTOR ROUTINES
//------------------------------------------------------------------------------

procedure vec_clear(var v: TVector3f);
asm
  XOR EDX, EDX
  MOV [EAX], EDX
  MOV [EAX+4], EDX
  MOV [EAX+8], EDX
end;

procedure vec_clear(var v: TVector2x);
begin
  v[0] := 0;
  v[1] := 0;
end;

procedure vec_clear(var v: TVector3x);
begin
  v[0] := 0;
  v[1] := 0;
  v[2] := 0;
end;

procedure vec_clear(var v: TVector4b);
asm
  XOR EDX, EDX
  MOV [EAX], EDX
end;

procedure vec_clear(var v: TVector4i);
asm
  XOR EDX, EDX
  MOV [EAX], EDX
  MOV [EAX+4], EDX
  MOV [EAX+8], EDX
  MOV [EAX+12], EDX
end;

function vec_equals(v1, v2: TVector3f): Boolean;
begin
  Result := (Abs(v1[0]-v2[0]) < EPSILON_VECTOR_COMPARE) and
            (Abs(v1[1]-v2[1]) < EPSILON_VECTOR_COMPARE) and
            (Abs(v1[2]-v2[2]) < EPSILON_VECTOR_COMPARE);
end;

function vec_make(X, Y: Single): TVector2f;
begin
  Result[0] := X;
  Result[1] := Y;
end;

function vec_make(X, Y, Z: Single): TVector3f;
begin
  Result[0] := X;
  Result[1] := Y;
  Result[2] := Z;
end;

function vec_make(X, Y, Z, W: Byte): TVector4b;
begin
  Result[0] := X;
  Result[1] := Y;
  Result[2] := Z;
  Result[3] := W;
end;

function vec_DegToRad(V: TVector3f): TVector3f;
begin
  Result[0] := DegToRad(V[0]);
  Result[1] := DegToRad(V[1]);
  Result[2] := DegToRad(V[2]);
end;

function vec_RadToDeg(V: TVector3f): TVector3f;
begin
  Result[0] := RadToDeg(V[0]);
  Result[1] := RadToDeg(V[1]);
  Result[2] := RadToDeg(V[2]);
end;

function vec_add(const v1: TVector2x; const v2: TVector2f): TVector2x;
begin
  Result[0] := v1[0] + v2[0];
  Result[1] := v1[1] + v2[1];
end;

function vec_add(const v1, v2: TVector3f): TVector3f;
// EAX contains address of V1
// EDX contains address of V2
// ECX contains the result
// Result = v1 + v2
asm
  FLD DWORD PTR [EAX]
  FADD DWORD PTR [EDX]
  FSTP DWORD PTR [ECX]

  FLD DWORD PTR [EAX+4]
  FADD DWORD PTR [EDX+4]
  FSTP DWORD PTR [ECX+4]

  FLD DWORD PTR [EAX+8]
  FADD DWORD PTR [EDX+8]
  FSTP DWORD PTR [ECX+8]
end;

function vec_add(const v1: TVector3x; const v2: TVector3f): TVector3x;
begin
  Result[0] := v1[0] + v2[0];
  Result[1] := v1[1] + v2[1];
  Result[2] := v1[2] + v2[2];
end;

function vec_add(const v1, v2: TVector3x): TVector3x;
begin
  Result[0] := v1[0] + v2[0];
  Result[1] := v1[1] + v2[1];
  Result[2] := v1[2] + v2[2];
end;

function vec_add(const v1: TVector4i; const v2: TVector4b): TVector4i;
begin
  Result[0] := v1[0] + v2[0];
  Result[1] := v1[1] + v2[1];
  Result[2] := v1[2] + v2[2];
  Result[3] := v1[3] + v2[3];
end;

function vec_sub(const v1, v2: TVector2f): TVector2f;
// EAX contains address of V1
// EDX contains address of V2
// ECX contains the result
// Result = v1 - v2
asm
  FLD DWORD PTR [EAX]
  FSUB DWORD PTR [EDX]
  FSTP DWORD PTR [ECX]

  FLD DWORD PTR [EAX+4]
  FSUB DWORD PTR [EDX+4]
  FSTP DWORD PTR [ECX+4]
end;

function vec_sub(const v1, v2: TVector3f): TVector3f;
// EAX contains address of V1
// EDX contains address of V2
// ECX contains the result
// Result = v1 - v2
asm
  FLD DWORD PTR [EAX]
  FSUB DWORD PTR [EDX]
  FSTP DWORD PTR [ECX]

  FLD DWORD PTR [EAX+4]
  FSUB DWORD PTR [EDX+4]
  FSTP DWORD PTR [ECX+4]

  FLD DWORD PTR [EAX+8]
  FSUB DWORD PTR [EDX+8]
  FSTP DWORD PTR [ECX+8]
end;

function vec_scale(const v: TVector2x; const Scale: Extended): TVector2f;
begin
  Result[0] := v[0] * Scale;
  Result[1] := v[1] * Scale;
end;

function vec_scale(const v: TVector3f; const Scale: Single): TVector3f;
// EAX contains address of V
// EBP+8 contains address of scale
// EDX contains the result
// Result = v * scale
asm
  FLD  DWORD PTR [EAX]
  FMUL DWORD PTR [EBP+8]
  FSTP DWORD PTR [EDX]
  FLD  DWORD PTR [EAX+4]
  FMUL DWORD PTR [EBP+8]
  FSTP DWORD PTR [EDX+4]
  FLD  DWORD PTR [EAX+8]
  FMUL DWORD PTR [EBP+8]
  FSTP DWORD PTR [EDX+8]
end;

function vec_scale(const v: TVector3x; const Scale: Extended): TVector3f;
begin
  Result[0] := v[0] * Scale;
  Result[1] := v[1] * Scale;
  Result[2] := v[2] * Scale;
end;

function vec_scale(const v: TVector4i; const Scale: Extended): TVector4b;
begin
  Result[0] := Trunc(v[0] * Scale);
  Result[1] := Trunc(v[1] * Scale);
  Result[2] := Trunc(v[2] * Scale);
  Result[3] := Trunc(v[3] * Scale);
end;

function vec_multiply(const v1, v2: TVector3f): TVector3f;
asm
  FLD DWORD PTR [EAX]
  FMUL DWORD PTR [EDX]
  FSTP DWORD PTR [ECX]

  FLD DWORD PTR [EAX+4]
  FMUL DWORD PTR [EDX+4]
  FSTP DWORD PTR [ECX+4]

  FLD DWORD PTR [EAX+8]
  FMUL DWORD PTR [EDX+8]
  FSTP DWORD PTR [ECX+8]
end;

function vec_abs(const v: TVector3f): TVector3f;
// EAX contains address of V
// EDX contains address of Result
asm
  FLD DWORD PTR [EAX]
  FABS
  FSTP DWORD PTR [EDX]

  FLD DWORD PTR [EAX+4]
  FABS
  FSTP DWORD PTR [EDX+4]

  FLD DWORD PTR [EAX+8]
  FABS
  FSTP DWORD PTR [EDX+8]
end;

procedure vec_min(var v: TVector3f; const v1: TVector3f);
begin
  if v1[0]<v[0] then v[0]:=v1[0];
  if v1[1]<v[1] then v[1]:=v1[1];
  if v1[2]<v[2] then v[2]:=v1[2];
end;

procedure vec_max(var v: TVector3f; const v1: TVector3f);
begin
  if v1[0]>v[0] then v[0]:=v1[0];
  if v1[1]>v[1] then v[1]:=v1[1];
  if v1[2]>v[2] then v[2]:=v1[2];
end;

function vec_negate(v: TVector3f): TVector3f;
// EAX contains address of v
// EDX contains address of Result
asm
  FLD DWORD PTR [EAX]
  FCHS
  FSTP DWORD PTR [EDX]

  FLD DWORD PTR [EAX+4]
  FCHS
  FSTP DWORD PTR [EDX+4]

  FLD DWORD PTR [EAX+8]
  FCHS
  FSTP DWORD PTR [EDX+8]
end;

function vec_dot(const v1, v2: TVector3f): Single;
// EAX contains address of V1
// EDX contains address of V2
// ST(0) contains the result
// Result := (v1[0] * v2[0]) + (v1[1] * v2[1]) + (v1[2] * v2[2]);
asm
  FLD DWORD PTR [EAX]
  FMUL DWORD PTR [EDX]
  FLD DWORD PTR [EAX + 4]
  FMUL DWORD PTR [EDX + 4]
  FADDP
  FLD DWORD PTR [EAX + 8]
  FMUL DWORD PTR [EDX + 8]
  FADDP
end;

function vec_cross(const v1, v2: TVector3f): TVector3f;
begin
  Result[0] := v1[1] * v2[2] - v1[2] * v2[1];
  Result[1] := v1[2] * v2[0] - v1[0] * v2[2];
  Result[2] := v1[0] * v2[1] - v1[1] * v2[0];
end;

function vec_length(const v: TVector3f): Single;
// EAX contains address of V
// result is passed in ST(0)
asm
  FLD  DWORD PTR [EAX]
  FMUL ST, ST
  FLD  DWORD PTR [EAX+4]
  FMUL ST, ST
  FADDP
  FLD  DWORD PTR [EAX+8]
  FMUL ST, ST
  FADDP
  FSQRT
end;

function vec_spacing(const v1, v2: TVector2f): Single; overload;
// EAX contains address of v1
// EDX contains highest of v2
// Result  is passed on the stack
// Result:=Abs(v2.S-v1.S)+Abs(v2.T-v1.T);
asm
  FLD  DWORD PTR [EAX]
  FSUB DWORD PTR [EDX]
  FABS
  FLD  DWORD PTR [EAX+4]
  FSUB DWORD PTR [EDX+4]
  FABS
  FADD
end;

function vec_spacing(const v1, v2: TVector3f): Single; overload;
// EAX contains address of v1
// EDX contains highest of v2
// Result  is passed on the stack
// Result:=Abs(v2[0]-v1[0])+Abs(v2[1]-v1[1])+Abs(v2[2]-v1[2]);
asm
  FLD  DWORD PTR [EAX]
  FSUB DWORD PTR [EDX]
  FABS
  FLD  DWORD PTR [EAX+4]
  FSUB DWORD PTR [EDX+4]
  FABS
  FADD
  FLD  DWORD PTR [EAX+8]
  FSUB DWORD PTR [EDX+8]
  FABS
  FADD
end;

function vec_dist(v1, v2: TVector3f): Single;
// EAX contains address of v1
// EDX contains highest of v2
// Result  is passed on the stack
asm
  FLD  DWORD PTR [EAX]
  FSUB DWORD PTR [EDX]
  FMUL ST, ST
  FLD  DWORD PTR [EAX+4]
  FSUB DWORD PTR [EDX+4]
  FMUL ST, ST
  FADD
  FLD  DWORD PTR [EAX+8]
  FSUB DWORD PTR [EDX+8]
  FMUL ST, ST
  FADD
  FSQRT
end;

function vec_lerp(v1, v2: TVector3f; t: Single): TVector3f;
begin
  Result[0] := v1[0] + (v2[0] - v1[0]) * t;
  Result[1] := v1[1] + (v2[1] - v1[1]) * t;
  Result[2] := v1[2] + (v2[2] - v1[2]) * t;
end;

function vec_combine(const v1, v2 : TVector3f; const scale : Single): TVector3f;
// EAX contains address of v1
// EDX contains address of v2
// EBP+8 contains address of scale
// ECX contains address of Result
asm
  FLD  DWORD PTR [EDX]
  FMUL DWORD PTR [EBP+8]
  FADD DWORD PTR [EAX]
  FSTP DWORD PTR [ECX]

  FLD  DWORD PTR [EDX+4]
  FMUL DWORD PTR [EBP+8]
  FADD DWORD PTR [EAX+4]
  FSTP DWORD PTR [ECX+4]

  FLD  DWORD PTR [EDX+8]
  FMUL DWORD PTR [EBP+8]
  FADD DWORD PTR [EAX+8]
  FSTP DWORD PTR [ECX+8]
end;

function vec_normalize(const v: TVector3f): TVector3f;
// EAX contains address of V1
// EDX contains the result
// Result:=v * (1 / (v * v) )
asm
  FLD  DWORD PTR [EAX]
  FMUL ST, ST
  FLD  DWORD PTR [EAX+4]
  FMUL ST, ST
  FADD
  FLD  DWORD PTR [EAX+8]
  FMUL ST, ST
  FADD
  FSQRT

  FLD1
  FDIVR
  FLD  ST
  FMUL DWORD PTR [EAX]
  FSTP DWORD PTR [EDX]
  FLD  ST
  FMUL DWORD PTR [EAX+4]
  FSTP DWORD PTR [EDX+4]
  FMUL DWORD PTR [EAX+8]
  FSTP DWORD PTR [EDX+8]
end;

function vec_normalizecolor(color: TVector3f): TVector3f;
var max: Single;
begin
  max := color[0];
  if color[1] > max then
    max := color[1];
  if color[2] > max then
    max := color[2];

  if max > 1 then
    Result := vec_scale(color, 1 / max)
  else
    Result := color;
end;

function vec_saturate(color: TVector3f): TVector3f;
begin
  if color[0] < 0.0 then
    Result[0] := 0.0
  else if color[0] > 1.0 then
    Result[0] := 1.0
  else
    Result[0] := color[0];

  if color[1] < 0.0 then
    Result[1] := 0.0
  else if color[1] > 1.0 then
    Result[1] := 1.0
  else
    Result[1] := color[1];

  if color[2] < 0.0 then
    Result[2] := 0.0
  else if color[2] > 1.0 then
    Result[2] := 1.0
  else
    Result[2] := color[2];
end;

function vec_normalizesafe(const inv: TVector3f; out outv: TVector3f): Single;
var len: Single;
begin
  len := vec_length(inv);
  if len = 0 then
  begin
    vec_clear(outv);
    Result := 0;
    Exit;
  end;

  Result := len;
  len := 1/len;
  outv[0] := inv[0] * len;
  outv[1] := inv[1] * len;
  outv[2] := inv[2] * len;
end;

function vec_colinearpoints(p1, p2, p3: TVector3f): Boolean;
var a, b, dir: TVector3f;
begin
  if vec_normalizesafe(vec_sub(p3, p1), dir) = 0 then
  begin
    Result := False;
    Exit;
  end;

  a := vec_sub(p2, p1);
  b := vec_scale(dir, vec_dot(a, dir));
  Result := (vec_length(vec_sub(a, b)) < EPSILON_ON_SIDE);
end;

function vec_closestpointonedge(from, a, b: TVector3f): TVector3f;
var
  v1, v2: TVector3f;
  d, t: Single;
begin
  v1 := vec_sub(from, a);
  d := vec_normalizesafe(vec_sub(b, a), v2);
  t := vec_dot(v2, v1);

  if (t <= 0) then
    Result := a
  else if (t >= d) then
    Result := b
  else
    Result := vec_combine(a, v2, t);
end;

procedure vec_tangentspace(const normal: TVector3f;
                           var tangent, binormal: TVector3f);
var
  majoraxis: Integer;
  n: TVector3f;
  f: Single;
begin
  n := vec_abs(normal);
  majoraxis := 0;
// find major axis
  if n[1] > n[majoraxis] then
    majoraxis := 1;

  if n[2] > n[majoraxis] then
    majoraxis := 2;
// prepare up vector
  vec_clear(binormal);
  if majoraxis = 2 then
    binormal[0] := 1
  else
    binormal[2] := 1;
// build up and right vectors
  f := -vec_dot(binormal, normal);
  binormal := vec_normalize(vec_combine(binormal, normal, f));
  tangent := vec_cross(normal, binormal);
end;

function vec_transform_st(const v: TVector3f; const mat: TMatrix4f): TVector2f;
begin
  Result[0] := v[0] * mat[0, 0] + v[1] * mat[1, 0] + v[2] * mat[2, 0] + mat[3, 0];
  Result[1] := v[0] * mat[0, 1] + v[1] * mat[1, 1] + v[2] * mat[2, 1] + mat[3, 1];
end;

function vec_transform(const v: TVector3f; const mat: TMatrix4f): TVector3f;
begin
  Result[0] := v[0] * mat[0, 0] + v[1] * mat[1, 0] + v[2] * mat[2, 0] + mat[3, 0];
  Result[1] := v[0] * mat[0, 1] + v[1] * mat[1, 1] + v[2] * mat[2, 1] + mat[3, 1];
  Result[2] := v[0] * mat[0, 2] + v[1] * mat[1, 2] + v[2] * mat[2, 2] + mat[3, 2];
end;

//------------------------------------------------------------------------------
// PLANE ROUTINES
//------------------------------------------------------------------------------

function plane_normal(p1, p2, p3: TVector3f): TVector3f;
Begin
// the normal will point out of the clock for clockwise ordered points
  Result := vec_normalize(vec_cross(vec_sub(p1, p2), vec_sub(p3, p1)));
End;

function plane_frompoints(const p1, p2, p3: TVector3f): TPlane;
begin
  Result := plane_make(plane_normal(p1, p2, p3), p1);
end;

function plane_make(normal, point: TVector3f): TPlane;
begin
  Result.Normal := normal;
  Result.Dist := -vec_dot(normal, point);
end;

function plane_evaluatepoint(const plane: TPlane; const p: TVector3f): Single; register;
// EAX contains address of plane
// EDX contains address of point
// result is stored in ST(0)
asm
  FLD DWORD PTR [EAX]
  FMUL DWORD PTR [EDX]
  FLD DWORD PTR [EAX + 4]
  FMUL DWORD PTR [EDX + 4]
  FADDP
  FLD DWORD PTR [EAX + 8]
  FMUL DWORD PTR [EDX + 8]
  FADDP
  FLD DWORD PTR [EAX + 12]
  FADDP
end;

function plane_snap(const plane: TPlane): TPlane;
var i: Integer;
begin
  Result := plane;
  for i:=0 to 2 do
  begin
    if Abs(plane.Normal[i]-1) < EPSILON_SNAP_PLANE_NORMAL then
    begin
      vec_clear(Result.Normal);
      Result.Normal[i] := 1;
      Break;
    end
    else if Abs(plane.Normal[i]-(-1)) < EPSILON_SNAP_PLANE_NORMAL then
    begin
      vec_clear(Result.Normal);
      Result.Normal[i] := -1;
      Break;
    end
  end;

  if Abs(plane.Dist - Floor(plane.Dist+0.5)) < EPSILON_SNAP_PLANE_DIST then
    Result.Dist := Floor(plane.Dist+0.5);
end;

function plane_negate(const plane: TPlane): TPlane;
// EAX contains address of V1
// EDX contains the result
// Result := -plane
asm
  FLD DWORD PTR [EAX]
  FCHS
  FSTP DWORD PTR [EDX]

  FLD DWORD PTR [EAX+4]
  FCHS
  FSTP DWORD PTR [EDX+4]

  FLD DWORD PTR [EAX+8]
  FCHS
  FSTP DWORD PTR [EDX+8]

  FLD DWORD PTR [EAX+12]
  FCHS
  FSTP DWORD PTR [EDX+12]
end;

function plane_offset(Plane: TPlane; Position: TVector3f): TPlane;
begin
  Result.Normal := Plane.Normal;
  Result.Dist := -(Plane.Dist + vec_dot(Plane.Normal, Position));
end;

//------------------------------------------------------------------------------
// SPHERE ROUTINES
//------------------------------------------------------------------------------
function sphere_make(aabb: TAABB): TSphere;
var v: TVector3f;
begin
  v := vec_add(aabb.Mins, aabb.Maxs);
  Result.Origin := vec_scale(v, 0.5);
  Result.Radius := vec_dist(Result.Origin, aabb.Maxs);
end;

function sphere_lineintersect(sphere: TSphere; p1, p2: TVector3f): Boolean;
var
  v, dir: TVector3f;
  d, len: Single;
begin
  dir := vec_sub(p2, p1);
  len := vec_normalizesafe(dir, dir);

  v := vec_sub(sphere.Origin, p1);
  d := vec_dot(v, dir);

  Result := False;

  if d > len + sphere.Radius then Exit;
  if d < -sphere.Radius then Exit;

  len := vec_dist(vec_combine(p1, dir, d), sphere.Origin);

  if len > sphere.Radius then Exit;

  Result := True;
end;

//------------------------------------------------------------------------------
// AABB ROUTINES
//------------------------------------------------------------------------------
procedure aabb_clear(var aabb: TAABB);
begin
  aabb.Mins := vec_make(MAX_WORLD_COORD, MAX_WORLD_COORD, MAX_WORLD_COORD);
  aabb.Maxs := vec_make(MIN_WORLD_COORD, MIN_WORLD_COORD, MIN_WORLD_COORD);
end;

procedure aabb_addpoint(var aabb: TAABB; p: TVector3f);
var i: Integer;
begin
  for i:=0 to 2 do
  begin
    if p[i] > aabb.Maxs[i] then
      aabb.Maxs[i] := p[i];

    if p[i] < aabb.Mins[i] then
      aabb.Mins[i] := p[i];
  end;
end;

function aabb_Intersects(const AABB1, AABB2: TAABB): Boolean;
begin
  Result := not
   ((AABB1.Mins[0]>AABB2.Maxs[0]) or
    (AABB1.Mins[1]>AABB2.Maxs[1]) or
    (AABB1.Mins[2]>AABB2.Maxs[2]) or

    (AABB2.Mins[0]>AABB1.Maxs[0]) or
    (AABB2.Mins[1]>AABB1.Maxs[1]) or
    (AABB2.Mins[2]>AABB1.Maxs[2]));
end;

function aabb_LineIntersects(const AABB: TAABB; const StartPoint, EndPoint: TVector3f): Boolean;
var
  dir, lineDir, ld, lineCenter, center, extents, cross: TVector3f;
begin
  Result := False;

  center := vec_scale(vec_add(AABB.Mins, AABB.Maxs), 0.5);
  extents := vec_sub(AABB.Maxs, center);
  lineDir := vec_scale(vec_sub(EndPoint, StartPoint), 0.5);
  lineCenter := vec_add(StartPoint, lineDir);
  dir := vec_sub(lineCenter, center);

  ld[0] := Abs(lineDir[0]);
  if Abs(dir[0]) > (extents[0] + ld[0]) then Exit;

  ld[1] := Abs(lineDir[1]);
  if Abs(dir[1]) > (extents[1] + ld[1]) then Exit;

  ld[2] := Abs(lineDir[2]);
  if Abs(dir[2]) > (extents[2] + ld[2]) then Exit;

  cross := vec_cross(lineDir, dir);

  if Abs(cross[0]) > ((extents[1] * ld[2]) + (extents[2] * ld[1])) then Exit;

  if Abs(cross[1]) > ((extents[0] * ld[2]) + (extents[2] * ld[0])) then Exit;

  if Abs(cross[2]) > ((extents[0] * ld[1]) + (extents[1] * ld[0])) then Exit;

  Result := True;
end;

//------------------------------------------------------------------------------
// MATRIX ROUTINES
//------------------------------------------------------------------------------
procedure mat_identity(var mat: TMatrix4f);
begin
  mat[0,0] := 1;
  mat[0,1] := 0;
  mat[0,2] := 0;
  mat[0,3] := 0;

  mat[1,0] := 0;
  mat[1,1] := 1;
  mat[1,2] := 0;
  mat[1,3] := 0;

  mat[2,0] := 0;
  mat[2,1] := 0;
  mat[2,2] := 1;
  mat[2,3] := 0;

  mat[3,0] := 0;
  mat[3,1] := 0;
  mat[3,2] := 0;
  mat[3,3] := 1;
end;

procedure mat_transpose(var M: TMatrix4f);
var
  f : Single;
begin
  f:=M[0, 1]; M[0, 1]:=M[1, 0]; M[1, 0]:=f;
  f:=M[0, 2]; M[0, 2]:=M[2, 0]; M[2, 0]:=f;
  f:=M[0, 3]; M[0, 3]:=M[3, 0]; M[3, 0]:=f;
  f:=M[1, 2]; M[1, 2]:=M[2, 1]; M[2, 1]:=f;
  f:=M[1, 3]; M[1, 3]:=M[3, 1]; M[3, 1]:=f;
  f:=M[2, 3]; M[2, 3]:=M[3, 2]; M[3, 2]:=f;
end;

function mat_multiply(const M1, M2 : TMatrix4f) : TMatrix4f;
Begin
  Result[0,0]:=M1[0,0]*M2[0,0]+M1[0,1]*M2[1,0]+M1[0,2]*M2[2,0]+M1[0,3]*M2[3,0];
  Result[0,1]:=M1[0,0]*M2[0,1]+M1[0,1]*M2[1,1]+M1[0,2]*M2[2,1]+M1[0,3]*M2[3,1];
  Result[0,2]:=M1[0,0]*M2[0,2]+M1[0,1]*M2[1,2]+M1[0,2]*M2[2,2]+M1[0,3]*M2[3,2];
  Result[0,3]:=M1[0,0]*M2[0,3]+M1[0,1]*M2[1,3]+M1[0,2]*M2[2,3]+M1[0,3]*M2[3,3];
  Result[1,0]:=M1[1,0]*M2[0,0]+M1[1,1]*M2[1,0]+M1[1,2]*M2[2,0]+M1[1,3]*M2[3,0];
  Result[1,1]:=M1[1,0]*M2[0,1]+M1[1,1]*M2[1,1]+M1[1,2]*M2[2,1]+M1[1,3]*M2[3,1];
  Result[1,2]:=M1[1,0]*M2[0,2]+M1[1,1]*M2[1,2]+M1[1,2]*M2[2,2]+M1[1,3]*M2[3,2];
  Result[1,3]:=M1[1,0]*M2[0,3]+M1[1,1]*M2[1,3]+M1[1,2]*M2[2,3]+M1[1,3]*M2[3,3];
  Result[2,0]:=M1[2,0]*M2[0,0]+M1[2,1]*M2[1,0]+M1[2,2]*M2[2,0]+M1[2,3]*M2[3,0];
  Result[2,1]:=M1[2,0]*M2[0,1]+M1[2,1]*M2[1,1]+M1[2,2]*M2[2,1]+M1[2,3]*M2[3,1];
  Result[2,2]:=M1[2,0]*M2[0,2]+M1[2,1]*M2[1,2]+M1[2,2]*M2[2,2]+M1[2,3]*M2[3,2];
  Result[2,3]:=M1[2,0]*M2[0,3]+M1[2,1]*M2[1,3]+M1[2,2]*M2[2,3]+M1[2,3]*M2[3,3];
  Result[3,0]:=M1[3,0]*M2[0,0]+M1[3,1]*M2[1,0]+M1[3,2]*M2[2,0]+M1[3,3]*M2[3,0];
  Result[3,1]:=M1[3,0]*M2[0,1]+M1[3,1]*M2[1,1]+M1[3,2]*M2[2,1]+M1[3,3]*M2[3,1];
  Result[3,2]:=M1[3,0]*M2[0,2]+M1[3,1]*M2[1,2]+M1[3,2]*M2[2,2]+M1[3,3]*M2[3,2];
  Result[3,3]:=M1[3,0]*M2[0,3]+M1[3,1]*M2[1,3]+M1[3,2]*M2[2,3]+M1[3,3]*M2[3,3];
end;

function mat_FromQuaternion(Quat: TQuaternion): TMatrix4f;
var
  x, y, z, w, xx, xy, xz, xw, yy, yz, yw, zz, zw: Single;
begin
  quat_Normalize(Quat);

  x := Quat.ImagPart[0];
  y := Quat.ImagPart[1];
  z := Quat.ImagPart[2];
  w := Quat.RealPart;

  xx := x * x;
  xy := x * y;
  xz := x * z;
  xw := x * w;
  yy := y * y;
  yz := y * z;
  yw := y * w;
  zz := z * z;
  zw := z * w;

  Result[0, 0] := 1 - 2 * ( yy + zz );
  Result[1, 0] :=     2 * ( xy - zw );
  Result[2, 0] :=     2 * ( xz + yw );
  Result[3, 0] := 0;
  Result[0, 1] :=     2 * ( xy + zw );
  Result[1, 1] := 1 - 2 * ( xx + zz );
  Result[2, 1] :=     2 * ( yz - xw );
  Result[3, 1] := 0;
  Result[0, 2] :=     2 * ( xz - yw );
  Result[1, 2] :=     2 * ( yz + xw );
  Result[2, 2] := 1 - 2 * ( xx + yy );
  Result[3, 2] := 0;
  Result[0, 3] := 0;
  Result[1, 3] := 0;
  Result[2, 3] := 0;
  Result[3, 3] := 1;
end;

procedure mat_SetTranslation(var M: TMatrix4f; Translation: TVector3f);
begin
  M[3, 0] := Translation[0];
  M[3, 1] := Translation[1];
  M[3, 2] := Translation[2];
end;

function mat_CreateRotationMatrix(Angles: TVector3f): TMatrix4f;
var cx, sx, cy, sy, cz, sz: Single;
begin
  SinCos(angles[0], sx, cx);
  SinCos(angles[1], sy, cy);
  SinCos(angles[2], sz, cz);

  Result[0, 0] := cy * cz;
  Result[0, 1] := cy * sz;
  Result[0, 2] :=-sy;
  Result[0, 3] := 0;

  Result[1, 0] := sx * sy * cz - cx * sz;
  Result[1, 1] := sx * sy * sz + cx * cz;
  Result[1, 2] := sx * cy;
  Result[1, 3] := 0;

  Result[2, 0] := cx * sy * cz + sx * sz;
  Result[2, 1] := cx * sy * sz - sx * cz;
  Result[2, 2] := cx * cy;
  Result[2, 3] := 0;

  Result[3, 0] := 0;
  Result[3, 1] := 0;
  Result[3, 2] := 0;
  Result[3, 3] := 1;
end;

function mat_CreateRotationMatrixX(Angle: Single): TMatrix4f;
var sine, cosine: Single;
begin
  SinCos(Angle, sine, cosine);

  Result[0, 0] := 1;
  Result[0, 1] := 0;
  Result[0, 2] := 0;
  Result[0, 3] := 0;

  Result[1, 0] := 0;
  Result[1, 1] := cosine;
  Result[1, 2] := sine;
  Result[1, 3] := 0;

  Result[2, 0] := 0;
  Result[2, 1] := -sine;
  Result[2, 2] := cosine;
  Result[2, 3] := 0;

  Result[3, 0] := 0;
  Result[3, 1] := 0;
  Result[3, 2] := 0;
  Result[3, 3] := 1;
end;

function mat_CreateRotationMatrixY(Angle: Single): TMatrix4f;
var sine, cosine: Single;
begin
  SinCos(Angle, sine, cosine);

  Result[0, 0] := cosine;
  Result[0, 1] := 0;
  Result[0, 2] := -sine;
  Result[0, 3] := 0;

  Result[1, 0] := 0;
  Result[1, 1] := 1;
  Result[1, 2] := 0;
  Result[1, 3] := 0;

  Result[2, 0] := sine;
  Result[2, 1] := 0;
  Result[2, 2] := cosine;
  Result[2, 3] := 0;

  Result[3, 0] := 0;
  Result[3, 1] := 0;
  Result[3, 2] := 0;
  Result[3, 3] := 1;
end;

function mat_CreateRotationMatrixZ(Angle: Single): TMatrix4f;
var sine, cosine: Single;
begin
  SinCos(Angle, sine, cosine);

  Result[0, 0] := cosine;
  Result[0, 1] := sine;
  Result[0, 2] := 0;
  Result[0, 3] := 0;

  Result[1, 0] := -sine;
  Result[1, 1] := cosine;
  Result[1, 2] := 0;
  Result[1, 3] := 0;

  Result[2, 0] := 0;
  Result[2, 1] := 0;
  Result[2, 2] := 1;
  Result[2, 3] := 0;

  Result[3, 0] := 0;
  Result[3, 1] := 0;
  Result[3, 2] := 0;
  Result[3, 3] := 1;
end;

function mat_CreateScaleMatrix(Scale: Single): TMatrix4f;
begin
  mat_Identity(Result);

  Result[0, 0] := Scale;
  Result[1, 1] := Scale;
  Result[2, 2] := Scale;
end;

function mat_CreateScaleMatrix(Scale: TVector3f): TMatrix4f;
begin
  mat_Identity(Result);

  Result[0, 0] := Scale[0];
  Result[1, 1] := Scale[1];
  Result[2, 2] := Scale[2];
end;

//------------------------------------------------------------------------------
// QUATERNION ROUTINES
//------------------------------------------------------------------------------
function quat_Magnitude(Quat: TQuaternion): Single;
begin
  Result := Sqrt(vec_dot(Quat.ImagPart, Quat.ImagPart) + Sqr(Quat.RealPart));
end;

procedure quat_Normalize(var Quat: TQuaternion);
var m, f: Single;
begin
  m := quat_Magnitude(Quat);

  if m > EPSILON_30 then
  begin
    f := 1 / m;
    Quat.ImagPart := vec_scale(Quat.ImagPart, f);
    Quat.RealPart := Quat.RealPart * f;
  end
  else
    Quat := IdentityQuaternion;
end;

initialization
  Set8087CW($133F); // use extended precision + no exception

end.
