{ BigInts - arbitrary precision integers for Unleashed Pascal

 Two value types with full operator coverage and no size limit:
   UBigInt - unsigned big integer (raises ERangeError on negative results)
   BigInt  - signed big integer, two's complement semantics for bitwise ops }

{ Copyright (c) 2026 @fibodevy / https://github.com/fibodevy
  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/ }

unit BigInts;

{$mode unleashed}

// asm inner loops on x86_64; comment out to build the fully portable pure
// Pascal core (32-bit limbs) on every target
{$define USEASM}

{$if defined(CPUX86_64) and defined(USEASM)}{$define BIGINT_ASM}{$endif}

// limb arithmetic relies on modular 32-bit/64-bit wraparound
{$q-}{$r-}

// dynamic array locals are nil-initialized by the compiler and tuple
// destructuring discards are intentional; these flow hints are noise here
{$warn 5089 off}{$warn 5091 off}{$warn 5092 off}{$warn 5093 off}{$warn 5094 off}{$warn 5027 off}

interface

uses SysUtils;

type
  // raised for domain errors: negative exponent, no modular inverse, ...
  // (div by zero raises EDivByZero, overflows in conversions raise ERangeError,
  // parse errors raise EConvertError - same classes plain integers use)
  EBigIntError = class(Exception);

  // generator behind random/randomBelow/randomRange/randomPrime; rngSystem is
  // the RandSeed-driven System.Random stream, rngOS reads OS entropy per call
  TBigIntRngAlgo = (rngXoshiro256ss, rngPcg64, rngSplitMix64, rngSystem, rngOS);

  // internal storage: little-endian array of limbs (64-bit on x86_64, 32-bit
  // elsewhere), highest limb nonzero, nil = 0
  {$ifdef BIGINT_ASM}
  TBigIntLimb = QWord;
  {$else}
  TBigIntLimb = DWord;
  {$endif}
  TBigIntLimbs = array of TBigIntLimb;

  { UBigInt - unsigned arbitrary precision integer }

  UBigInt = record
  private
    fLimbs: TBigIntLimbs;
    function getBitProp(i: LongWord): boolean; inline;
    procedure putBitProp(i: LongWord; v: boolean); inline;
  public
    // conversions in (negative values raise ERangeError)
    class operator :=(x: Int64): UBigInt;
    class operator :=(x: QWord): UBigInt;
    class operator :=(const s: string): UBigInt;
    class operator explicit(d: Double): UBigInt;
    // exact integer paths for typecasts, so UBigInt(q) never rounds via Double
    class operator explicit(x: Int64): UBigInt;
    class operator explicit(x: QWord): UBigInt;
    // conversions out (values that do not fit raise ERangeError)
    class operator explicit(const a: UBigInt): Int64;
    class operator explicit(const a: UBigInt): QWord;
    class operator explicit(const a: UBigInt): LongInt;
    class operator explicit(const a: UBigInt): LongWord;
    class operator explicit(const a: UBigInt): Double;
    class operator explicit(const a: UBigInt): string;
    // arithmetic
    class operator +(const a, b: UBigInt): UBigInt;
    class operator +(const a: UBigInt; b: Int64): UBigInt;
    class operator +(a: Int64; const b: UBigInt): UBigInt;
    class operator -(const a, b: UBigInt): UBigInt;
    class operator -(const a: UBigInt; b: Int64): UBigInt;
    class operator -(a: Int64; const b: UBigInt): UBigInt;
    class operator *(const a, b: UBigInt): UBigInt;
    class operator *(const a: UBigInt; b: Int64): UBigInt;
    class operator *(a: Int64; const b: UBigInt): UBigInt;
    class operator div(const a, b: UBigInt): UBigInt;
    class operator div(const a: UBigInt; b: Int64): UBigInt;
    class operator mod(const a, b: UBigInt): UBigInt;
    class operator mod(const a: UBigInt; b: Int64): UBigInt;
    // "/" is integer division here, same thing as div (C-family convention)
    class operator /(const a, b: UBigInt): UBigInt;
    class operator **(const a, b: UBigInt): UBigInt;
    class operator **(const a: UBigInt; e: Int64): UBigInt;
    class operator inc(const a: UBigInt): UBigInt;
    class operator dec(const a: UBigInt): UBigInt;
    // shifts (negative count raises ERangeError)
    class operator shl(const a: UBigInt; n: Int64): UBigInt;
    class operator shr(const a: UBigInt; n: Int64): UBigInt;
    // bitwise ("not" is intentionally absent: the infinite-width complement of an
    // unsigned value is not representable - use BigInt or complement(width))
    class operator and(const a, b: UBigInt): UBigInt;
    class operator or(const a, b: UBigInt): UBigInt;
    class operator xor(const a, b: UBigInt): UBigInt;
    // comparisons
    class operator =(const a, b: UBigInt): boolean;
    class operator =(const a: UBigInt; b: Int64): boolean;
    class operator =(a: Int64; const b: UBigInt): boolean;
    class operator <>(const a, b: UBigInt): boolean;
    class operator <>(const a: UBigInt; b: Int64): boolean;
    class operator <>(a: Int64; const b: UBigInt): boolean;
    class operator <(const a, b: UBigInt): boolean;
    class operator <(const a: UBigInt; b: Int64): boolean;
    class operator <(a: Int64; const b: UBigInt): boolean;
    class operator <=(const a, b: UBigInt): boolean;
    class operator <=(const a: UBigInt; b: Int64): boolean;
    class operator <=(a: Int64; const b: UBigInt): boolean;
    class operator >(const a, b: UBigInt): boolean;
    class operator >(const a: UBigInt; b: Int64): boolean;
    class operator >(a: Int64; const b: UBigInt): boolean;
    class operator >=(const a, b: UBigInt): boolean;
    class operator >=(const a: UBigInt; b: Int64): boolean;
    class operator >=(a: Int64; const b: UBigInt): boolean;

    // formatting
    function toString: string;
    function toString(base: integer): string;
    function toHex: string;
    function toBin: string;
    function toOct: string;
    // numeric conversions (raise ERangeError when the value does not fit)
    function toInt64: Int64;
    function toQWord: QWord;
    function toInteger: LongInt;
    function toCardinal: LongWord;
    function toDouble: Double;
    function fitsInInt64: boolean;
    function fitsInQWord: boolean;
    function fitsInInteger: boolean;
    function fitsInCardinal: boolean;
    // predicates
    function isZero: boolean;
    function isOne: boolean;
    function isEven: boolean;
    function isOdd: boolean;
    function isPowerOfTwo: boolean;
    function sign: integer;
    // bit access
    function bitLength: LongWord;
    function popCount: LongWord;
    function lowestSetBit: Int64;
    function testBit(i: LongWord): boolean;
    procedure setBit(i: LongWord);
    procedure clearBit(i: LongWord);
    procedure flipBit(i: LongWord);
    // complement of the low "width" bits (finite-width bitwise not)
    function complement(width: LongWord): UBigInt;
    property bits[i: LongWord]: boolean read getBitProp write putBitProp;
    // comparison helpers
    function compare(const other: UBigInt): integer;
    function equals(const other: UBigInt): boolean;
    function min(const other: UBigInt): UBigInt;
    function max(const other: UBigInt): UBigInt;
    // division helpers
    function divMod(const d: UBigInt): (q, r: UBigInt);
    function ceilDiv(const d: UBigInt): UBigInt;
    // misc
    procedure swap(var other: UBigInt);
    // parsing (auto-detects prefixes: $ 0x hex, % 0b binary, & 0o octal; "_" separators allowed)
    class function parse(const s: string): UBigInt; static;
    class function parse(const s: string; base: integer): UBigInt; static;
    class function tryParse(const s: string; out v: UBigInt): boolean; static;
    class function tryParse(const s: string; base: integer; out v: UBigInt): boolean; static;
    // bytes, little/big endian magnitude; zero gives an empty array
    function toBytesLE: TBytes;
    function toBytesBE: TBytes;
    class function fromBytesLE(const bytes: TBytes): UBigInt; static;
    class function fromBytesBE(const bytes: TBytes): UBigInt; static;
    // misc
    function digitCount: LongWord;
    function toStringGrouped(sep: char = '_'; groupSize: integer = 3): string;
    function hashCode: DWord;
    // constants and generators
    class function zero: UBigInt; static;
    class function one: UBigInt; static;
    class function two: UBigInt; static;
    class function ten: UBigInt; static;
    class function pow2(n: LongWord): UBigInt; static;
    class function random(bits: LongWord): UBigInt; static;
    class function randomBelow(const bound: UBigInt): UBigInt; static;
    class function randomRange(const lo, hi: UBigInt): UBigInt; static;
  end;

  { BigInt - signed arbitrary precision integer, sign-magnitude storage;
    bitwise operators and bit access use two's complement semantics with
    infinite sign extension (like Python ints), div/mod truncate like Pascal }

  BigInt = record
  private
    fLimbs: TBigIntLimbs;
    fNeg: boolean;
    function getBitProp(i: LongWord): boolean; inline;
    procedure putBitProp(i: LongWord; v: boolean); inline;
  public
    // conversions in
    class operator :=(x: Int64): BigInt;
    class operator :=(x: QWord): BigInt;
    class operator :=(const s: string): BigInt;
    class operator :=(const u: UBigInt): BigInt;
    class operator explicit(d: Double): BigInt;
    // exact integer paths for typecasts, so BigInt(q) never rounds via Double
    class operator explicit(x: Int64): BigInt;
    class operator explicit(x: QWord): BigInt;
    // conversions out (values that do not fit raise ERangeError)
    class operator explicit(const a: BigInt): Int64;
    class operator explicit(const a: BigInt): QWord;
    class operator explicit(const a: BigInt): LongInt;
    class operator explicit(const a: BigInt): LongWord;
    class operator explicit(const a: BigInt): Double;
    class operator explicit(const a: BigInt): string;
    class operator explicit(const a: BigInt): UBigInt;
    // arithmetic
    class operator +(const a, b: BigInt): BigInt;
    class operator +(const a: BigInt; b: Int64): BigInt;
    class operator +(a: Int64; const b: BigInt): BigInt;
    class operator -(const a, b: BigInt): BigInt;
    class operator -(const a: BigInt; b: Int64): BigInt;
    class operator -(a: Int64; const b: BigInt): BigInt;
    class operator *(const a, b: BigInt): BigInt;
    class operator *(const a: BigInt; b: Int64): BigInt;
    class operator *(a: Int64; const b: BigInt): BigInt;
    class operator div(const a, b: BigInt): BigInt;
    class operator div(const a: BigInt; b: Int64): BigInt;
    class operator mod(const a, b: BigInt): BigInt;
    class operator mod(const a: BigInt; b: Int64): BigInt;
    // "/" is integer division here, same thing as div (C-family convention)
    class operator /(const a, b: BigInt): BigInt;
    class operator **(const a, b: BigInt): BigInt;
    class operator **(const a: BigInt; e: Int64): BigInt;
    class operator inc(const a: BigInt): BigInt;
    class operator dec(const a: BigInt): BigInt;
    // unary
    class operator -(const a: BigInt): BigInt;
    class operator +(const a: BigInt): BigInt;
    // shifts: shl keeps the sign, shr is arithmetic (rounds toward -infinity)
    class operator shl(const a: BigInt; n: Int64): BigInt;
    class operator shr(const a: BigInt; n: Int64): BigInt;
    // bitwise, two's complement with infinite sign extension; not x = -x-1
    class operator and(const a, b: BigInt): BigInt;
    class operator or(const a, b: BigInt): BigInt;
    class operator xor(const a, b: BigInt): BigInt;
    class operator not(const a: BigInt): BigInt;
    // comparisons
    class operator =(const a, b: BigInt): boolean;
    class operator =(const a: BigInt; b: Int64): boolean;
    class operator =(a: Int64; const b: BigInt): boolean;
    class operator <>(const a, b: BigInt): boolean;
    class operator <>(const a: BigInt; b: Int64): boolean;
    class operator <>(a: Int64; const b: BigInt): boolean;
    class operator <(const a, b: BigInt): boolean;
    class operator <(const a: BigInt; b: Int64): boolean;
    class operator <(a: Int64; const b: BigInt): boolean;
    class operator <=(const a, b: BigInt): boolean;
    class operator <=(const a: BigInt; b: Int64): boolean;
    class operator <=(a: Int64; const b: BigInt): boolean;
    class operator >(const a, b: BigInt): boolean;
    class operator >(const a: BigInt; b: Int64): boolean;
    class operator >(a: Int64; const b: BigInt): boolean;
    class operator >=(const a, b: BigInt): boolean;
    class operator >=(const a: BigInt; b: Int64): boolean;
    class operator >=(a: Int64; const b: BigInt): boolean;

    // formatting (negative values get a leading "-", also in hex/bin/oct)
    function toString: string;
    function toString(base: integer): string;
    function toHex: string;
    function toBin: string;
    function toOct: string;
    // numeric conversions (raise ERangeError when the value does not fit)
    function toInt64: Int64;
    function toQWord: QWord;
    function toInteger: LongInt;
    function toCardinal: LongWord;
    function toDouble: Double;
    function toUBigInt: UBigInt;
    function fitsInInt64: boolean;
    function fitsInQWord: boolean;
    function fitsInInteger: boolean;
    function fitsInCardinal: boolean;
    // predicates
    function isZero: boolean;
    function isOne: boolean;
    function isEven: boolean;
    function isOdd: boolean;
    function isNegative: boolean;
    function isPositive: boolean;
    function isPowerOfTwo: boolean;
    function sign: integer;
    // sign helpers
    function abs: BigInt;
    function magnitude: UBigInt;
    procedure negate;
    // bit access in two's complement (testBit of a negative sees infinite ones)
    function bitLength: LongWord;
    function popCount: LongWord;
    function lowestSetBit: Int64;
    function testBit(i: LongWord): boolean;
    procedure setBit(i: LongWord);
    procedure clearBit(i: LongWord);
    procedure flipBit(i: LongWord);
    property bits[i: LongWord]: boolean read getBitProp write putBitProp;
    // comparison helpers
    function compare(const other: BigInt): integer;
    function equals(const other: BigInt): boolean;
    function min(const other: BigInt): BigInt;
    function max(const other: BigInt): BigInt;
    // division helpers: divMod truncates (like div/mod), floor variants round
    // toward -infinity (like Python), ceilDiv rounds toward +infinity
    function divMod(const d: BigInt): (q, r: BigInt);
    function floorDiv(const d: BigInt): BigInt;
    function floorMod(const d: BigInt): BigInt;
    function ceilDiv(const d: BigInt): BigInt;
    // misc
    procedure swap(var other: BigInt);
    // parsing (sign plus the same prefixes and separators as UBigInt)
    class function parse(const s: string): BigInt; static;
    class function parse(const s: string; base: integer): BigInt; static;
    class function tryParse(const s: string; out v: BigInt): boolean; static;
    class function tryParse(const s: string; base: integer; out v: BigInt): boolean; static;
    // bytes: minimal two's complement with sign bit, like Java toByteArray
    function toBytesLE: TBytes;
    function toBytesBE: TBytes;
    class function fromBytesLE(const bytes: TBytes): BigInt; static;
    class function fromBytesBE(const bytes: TBytes): BigInt; static;
    // misc
    function digitCount: LongWord;
    function toStringGrouped(sep: char = '_'; groupSize: integer = 3): string;
    function hashCode: DWord;
    // constants and generators
    class function zero: BigInt; static;
    class function one: BigInt; static;
    class function two: BigInt; static;
    class function ten: BigInt; static;
    class function minusOne: BigInt; static;
    class function pow2(n: LongWord): BigInt; static;
    class function random(bits: LongWord): BigInt; static;
    class function randomBelow(const bound: BigInt): BigInt; static;
    class function randomRange(const lo, hi: BigInt): BigInt; static;
  end;

  // declared after both records so UBigInt can offer a BigInt-returning method
  TUBigIntBridge = record helper for UBigInt
    function toBigInt: BigInt;
  end;

var
  // limb count above which multiplication and squaring switch from schoolbook
  // to Karatsuba; exposed for tuning and testing
  BigIntKaratsubaThreshold: integer = {$ifdef BIGINT_ASM} 80 {$else} 48 {$endif};

  // limb count above which balanced multiplication and squaring switch from
  // Karatsuba to Toom-3; exposed for tuning and testing
  BigIntToom3Threshold: integer = 200;

  // generator used by random/randomBelow/randomRange/randomPrime
  BigIntRngAlgo: TBigIntRngAlgo = rngXoshiro256ss;

// deterministic seeding of every generator (also sets RandSeed for rngSystem)
procedure BigIntRandomSeed(seed: QWord);
// seed all generators from OS entropy
procedure BigIntRandomize;

implementation

uses
  Math;

const
  DIGIT_CHARS = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';

type
  TLimb = TBigIntLimb;
  TLimbs = TBigIntLimbs;

// ---------------------------------------------------------------------------
// small helpers
// ---------------------------------------------------------------------------

function MinS(a, b: SizeInt): SizeInt; inline;
begin
  result := if a < b then a else b;
end;

function MaxS(a, b: SizeInt): SizeInt; inline;
begin
  result := if a > b then a else b;
end;

// two's complement magnitude of a negative Int64, safe for Low(Int64)
function NegAbs64(x: Int64): QWord; inline;
begin
  result := (not QWord(x)) + 1;
end;

procedure RaiseDivByZero;
begin
  raise EDivByZero.Create('big integer division by zero');
end;

procedure RaiseNegativeUnsigned;
begin
  raise ERangeError.Create('UBigInt cannot hold a negative value');
end;

procedure RaiseParseError(const s: string);
begin
  raise EConvertError.Create($'"{s}" is not a valid big integer value');
end;

// ---------------------------------------------------------------------------
// limb core: little-endian arrays of limbs, highest limb nonzero
// ---------------------------------------------------------------------------

{$pointermath on}
{$ifdef BIGINT_ASM}{$asmmode intel}{$endif}

const
{$ifdef BIGINT_ASM}
  LIMB_BITS = 64;
  LIMB_SHIFT = 6;               // shl/shr LIMB_SHIFT = mul/div by LIMB_BITS
{$else}
  LIMB_BITS = 32;
  LIMB_SHIFT = 5;               // shl/shr LIMB_SHIFT = mul/div by LIMB_BITS
{$endif}
  LIMB_MASK = LIMB_BITS - 1;
  LIMB_BYTES = LIMB_BITS div 8;
  BYTES_SHIFT = LIMB_SHIFT - 3; // byte index -> limb index
  BYTES_MASK = LIMB_BYTES - 1;
  LIMBS_PER_QWORD = 64 div LIMB_BITS;

type
  PLimb = ^TLimb;

{$ifdef BIGINT_ASM}

// x86_64 primitives: win64 ABI (rcx, rdx, r8, r9), only volatile registers,
// carry chains kept live across iterations (lea/dec/jnz preserve CF)

function LimbBsr(x: TLimb): LongWord; inline;
begin
  result := BsrQWord(x);
end;

function LimbBsf(x: TLimb): LongWord; inline;
begin
  result := BsfQWord(x);
end;

// 2-limb product of a * b
procedure UMulLimb(a, b: TLimb; out hi, lo: TLimb); assembler; nostackframe;
asm
  mov rax, rcx
  mul rdx       // rdx:rax = a * b
  mov [r8], rdx
  mov [r9], rax
end;

// (hi:lo) div d and its remainder, caller guarantees hi < d
function UDivLimb(hi, lo, d: TLimb; out rem: TLimb): TLimb; assembler; nostackframe;
asm
  mov rax, rdx
  mov rdx, rcx
  div r8        // rax = quotient, rdx = remainder
  mov [r9], rdx
end;

// mpn-style row primitives: fixed-length limb runs behind raw pointers with
// the carry/borrow returned to the caller; rp may alias ap (and bp)

// rp := ap + bp over n limbs, returns carry
function MpnAddN(rp, ap, bp: PLimb; n: SizeInt): TLimb; assembler; nostackframe;
asm
  xor eax, eax       // rax = 0, CF = 0
  test r9, r9
  jz @done
@loop:
  mov r10, [rdx]
  adc r10, [r8]
  mov [rcx], r10
  lea rdx, [rdx + 8]
  lea r8, [r8 + 8]
  lea rcx, [rcx + 8]
  dec r9
  jnz @loop
  setc al
@done:
end;

// rp := ap - bp over n limbs, returns borrow
function MpnSubN(rp, ap, bp: PLimb; n: SizeInt): TLimb; assembler; nostackframe;
asm
  xor eax, eax
  test r9, r9
  jz @done
@loop:
  mov r10, [rdx]
  sbb r10, [r8]
  mov [rcx], r10
  lea rdx, [rdx + 8]
  lea r8, [r8 + 8]
  lea rcx, [rcx + 8]
  dec r9
  jnz @loop
  setc al
@done:
end;

// rp := ap + b with carry propagation, returns the final carry
function MpnAdd1(rp, ap: PLimb; n: SizeInt; b: TLimb): TLimb; assembler; nostackframe;
asm
  mov rax, r9        // carry
  test r8, r8
  jz @done
@loop:
  mov r10, [rdx]
  add r10, rax
  mov [rcx], r10
  mov eax, 0
  adc rax, 0         // rax = carry out
  lea rdx, [rdx + 8]
  lea rcx, [rcx + 8]
  dec r8
  jz @done
  test rax, rax
  jnz @loop
  // carry is dead: copy the tail unless the run is in place
  cmp rcx, rdx
  je @done
@copy:
  mov r10, [rdx]
  mov [rcx], r10
  lea rdx, [rdx + 8]
  lea rcx, [rcx + 8]
  dec r8
  jnz @copy
@done:
end;

// rp := ap - b with borrow propagation, returns the final borrow
function MpnSub1(rp, ap: PLimb; n: SizeInt; b: TLimb): TLimb; assembler; nostackframe;
asm
  mov rax, r9        // borrow
  test r8, r8
  jz @done
@loop:
  mov r10, [rdx]
  sub r10, rax
  mov [rcx], r10
  mov eax, 0
  adc rax, 0         // rax = borrow out
  lea rdx, [rdx + 8]
  lea rcx, [rcx + 8]
  dec r8
  jz @done
  test rax, rax
  jnz @loop
  cmp rcx, rdx
  je @done
@copy:
  mov r10, [rdx]
  mov [rcx], r10
  lea rdx, [rdx + 8]
  lea rcx, [rcx + 8]
  dec r8
  jnz @copy
@done:
end;

// rp := ap * b, returns the high limb
function MpnMul1(rp, ap: PLimb; n: SizeInt; b: TLimb): TLimb; assembler; nostackframe;
asm
  mov r10, rdx       // ap (mul clobbers rdx)
  xor r11d, r11d     // carry
  test r8, r8
  jz @done
@loop:
  mov rax, [r10]
  mul r9             // rdx:rax = ap[i] * b
  add rax, r11
  adc rdx, 0
  mov [rcx], rax
  mov r11, rdx
  lea r10, [r10 + 8]
  lea rcx, [rcx + 8]
  dec r8
  jnz @loop
@done:
  mov rax, r11
end;

// rp += ap * b, returns the carry limb (plain mul/adc variant)
function MpnAddMul1Gen(rp, ap: PLimb; n: SizeInt; b: TLimb): TLimb; assembler; nostackframe;
asm
  mov r10, rdx
  xor r11d, r11d
  test r8, r8
  jz @done
@loop:
  mov rax, [r10]
  mul r9
  add rax, r11
  adc rdx, 0
  add [rcx], rax     // rp[i] += low, CF = carry
  adc rdx, 0
  mov r11, rdx
  lea r10, [r10 + 8]
  lea rcx, [rcx + 8]
  dec r8
  jnz @loop
@done:
  mov rax, r11
end;

// rp += ap * b via mulx with independent adcx/adox carry chains, two limbs
// per pass; counter control uses lea + jrcxz to leave both chains untouched
function MpnAddMul1Adx(rp, ap: PLimb; n: SizeInt; b: TLimb): TLimb; assembler; nostackframe;
asm
  mov r10, rdx             // ap
  mov rdx, r9              // b, implicit mulx operand
  mov r9, rcx
  mov rcx, r8              // n
  mov r8, r9               // rp
  xor r11d, r11d           // hi_prev = 0
  shr rcx, 1               // pair count, CF = odd limb flag
  jnc @even
  // peel the odd limb with plain add/adc, the chains are not live yet
  mulx r11, rax, [r10]
  add rax, [r8]
  adc r11, 0
  mov [r8], rax
  lea r10, [r10 + 8]
  lea r8, [r8 + 8]
@even:
  test al, al              // CF = 0, OF = 0: both chains start clean
  jrcxz @fold
@loop:
  mulx r9, rax, [r10]
  adcx rax, r11            // CF chain: previous high limb
  adox rax, [r8]           // OF chain: rp accumulation
  mov [r8], rax
  mulx r11, rax, [r10 + 8]
  adcx rax, r9
  adox rax, [r8 + 8]
  mov [r8 + 8], rax
  lea r10, [r10 + 16]
  lea r8, [r8 + 16]
  lea rcx, [rcx - 1]
  jrcxz @fold
  jmp @loop
@fold:
  // carry limb = hi_prev + CF + OF, mathematically below the limb base
  mov rax, r11
  mov r9d, 0
  adcx rax, r9
  adox rax, r9
end;

// cpuid leaf 7: ebx bit 8 = BMI2 (mulx), bit 19 = ADX (adcx/adox)
function CpuHasAdx: boolean; assembler; nostackframe;
asm
  push rbx
  mov eax, 0
  cpuid
  cmp eax, 7
  jb @no
  mov eax, 7
  xor ecx, ecx
  cpuid
  mov eax, ebx
  mov edx, ebx
  shr eax, 8
  shr edx, 19
  and eax, edx
  and eax, 1
  jmp @out
@no:
  xor eax, eax
@out:
  pop rbx
end;

var
  UseAdx: boolean = false; // set from cpuid in the unit initialization

// rp += ap * b, returns the carry limb
function MpnAddMul1(rp, ap: PLimb; n: SizeInt; b: TLimb): TLimb; inline;
begin
  result := if UseAdx then MpnAddMul1Adx(rp, ap, n, b) else MpnAddMul1Gen(rp, ap, n, b);
end;

// rp -= ap * b, returns the borrow limb
function MpnSubMul1(rp, ap: PLimb; n: SizeInt; b: TLimb): TLimb; assembler; nostackframe;
asm
  mov r10, rdx
  xor r11d, r11d
  test r8, r8
  jz @done
@loop:
  mov rax, [r10]
  mul r9
  add rax, r11
  adc rdx, 0
  sub [rcx], rax     // rp[i] -= low, CF = borrow
  adc rdx, 0
  mov r11, rdx
  lea r10, [r10 + 8]
  lea rcx, [rcx + 8]
  dec r8
  jnz @loop
@done:
  mov rax, r11
end;

// rp := ap shl cnt for cnt in 1..LIMB_BITS-1, walks high to low so rp may
// alias ap; returns the bits shifted out of the top
function MpnLshift(rp, ap: PLimb; n: SizeInt; cnt: integer): TLimb; assembler; nostackframe;
asm
  mov r11, rcx               // rp
  mov ecx, r9d               // cl = cnt
  xor r9d, r9d
  mov r10, [rdx + r8*8 - 8]
  shld r9, r10, cl           // bits shifted out of the top
@loop:
  cmp r8, 1
  jle @last
  mov rax, [rdx + r8*8 - 8]
  mov r10, [rdx + r8*8 - 16]
  shld rax, r10, cl
  mov [r11 + r8*8 - 8], rax
  dec r8
  jmp @loop
@last:
  mov rax, [rdx]
  shl rax, cl
  mov [r11], rax
  mov rax, r9
end;

// rp := ap shr cnt for cnt in 1..LIMB_BITS-1, walks low to high so rp may alias ap
procedure MpnRshift(rp, ap: PLimb; n: SizeInt; cnt: integer); assembler; nostackframe;
asm
  mov r11, rcx               // rp
  mov ecx, r9d               // cl = cnt
  xor r10d, r10d             // i
@loop:
  lea rax, [r10 + 1]
  cmp rax, r8
  jge @last
  mov rax, [rdx + r10*8]
  mov r9,  [rdx + r10*8 + 8]
  shrd rax, r9, cl
  mov [r11 + r10*8], rax
  inc r10
  jmp @loop
@last:
  mov rax, [rdx + r8*8 - 8]
  shr rax, cl
  mov [r11 + r8*8 - 8], rax
end;

{$else}

// portable 32-bit primitives: carries ride in the top half of QWord temps

function LimbBsr(x: TLimb): LongWord; inline;
begin
  result := BsrDWord(x);
end;

function LimbBsf(x: TLimb): LongWord; inline;
begin
  result := BsfDWord(x);
end;

// 2-limb product of a * b
procedure UMulLimb(a, b: TLimb; out hi, lo: TLimb); inline;
begin
  var p := QWord(a) * b;
  lo := TLimb(p);
  hi := TLimb(p shr 32);
end;

// (hi:lo) div d and its remainder, caller guarantees hi < d
function UDivLimb(hi, lo, d: TLimb; out rem: TLimb): TLimb; inline;
begin
  var cur := (QWord(hi) shl 32) or lo;
  result := TLimb(cur div d);
  rem := TLimb(cur mod d);
end;

// mpn-style row primitives: fixed-length limb runs behind raw pointers with
// the carry/borrow returned to the caller; rp may alias ap (and bp)

// rp := ap + bp over n limbs, returns carry
function MpnAddN(rp, ap, bp: PLimb; n: SizeInt): TLimb;
begin
  var carry: QWord := 0;
  for var i := 0 to n - 1 do begin
    carry := carry + ap[i] + bp[i];
    rp[i] := TLimb(carry);
    carry := carry shr 32;
  end;
  result := TLimb(carry);
end;

// rp := ap - bp over n limbs, returns borrow
function MpnSubN(rp, ap, bp: PLimb; n: SizeInt): TLimb;
begin
  var borrow: QWord := 0;
  for var i := 0 to n - 1 do begin
    var t := QWord(ap[i]) - bp[i] - borrow;
    rp[i] := TLimb(t);
    borrow := (t shr 32) and 1;
  end;
  result := TLimb(borrow);
end;

// rp := ap + b with carry propagation, returns the final carry
function MpnAdd1(rp, ap: PLimb; n: SizeInt; b: TLimb): TLimb;
begin
  var carry := b;
  var i: SizeInt := 0;
  while (carry <> 0) and (i < n) do begin
    var s: TLimb := ap[i] + carry;
    carry := TLimb(ord(s < carry));
    rp[i] := s;
    inc(i);
  end;
  if (i < n) and (rp <> ap) then Move(ap[i], rp[i], (n - i) * SizeOf(TLimb));
  result := carry;
end;

// rp := ap - b with borrow propagation, returns the final borrow
function MpnSub1(rp, ap: PLimb; n: SizeInt; b: TLimb): TLimb;
begin
  var borrow := b;
  var i: SizeInt := 0;
  while (borrow <> 0) and (i < n) do begin
    var d: TLimb := ap[i] - borrow;
    borrow := TLimb(ord(d > ap[i]));
    rp[i] := d;
    inc(i);
  end;
  if (i < n) and (rp <> ap) then Move(ap[i], rp[i], (n - i) * SizeOf(TLimb));
  result := borrow;
end;

// rp := ap * b, returns the high limb
function MpnMul1(rp, ap: PLimb; n: SizeInt; b: TLimb): TLimb;
begin
  var carry: QWord := 0;
  for var i := 0 to n - 1 do begin
    carry := QWord(ap[i]) * b + carry;
    rp[i] := TLimb(carry);
    carry := carry shr 32;
  end;
  result := TLimb(carry);
end;

// rp += ap * b, returns the carry limb
function MpnAddMul1(rp, ap: PLimb; n: SizeInt; b: TLimb): TLimb;
begin
  var carry: QWord := 0;
  for var i := 0 to n - 1 do begin
    carry := QWord(rp[i]) + QWord(ap[i]) * b + carry;
    rp[i] := TLimb(carry);
    carry := carry shr 32;
  end;
  result := TLimb(carry);
end;

// rp -= ap * b, returns the borrow limb
function MpnSubMul1(rp, ap: PLimb; n: SizeInt; b: TLimb): TLimb;
begin
  var carry: QWord := 0;
  for var i := 0 to n - 1 do begin
    var p := QWord(ap[i]) * b + carry;
    var t := QWord(rp[i]) - TLimb(p);
    rp[i] := TLimb(t);
    carry := (p shr 32) + ((t shr 32) and 1);
  end;
  result := TLimb(carry);
end;

// rp := ap shl cnt for cnt in 1..LIMB_BITS-1, walks high to low so rp may
// alias ap; returns the bits shifted out of the top
function MpnLshift(rp, ap: PLimb; n: SizeInt; cnt: integer): TLimb;
begin
  var inv := LIMB_BITS - cnt;
  result := ap[n - 1] shr inv;
  for var i := n - 1 downto 1 do rp[i] := (ap[i] shl cnt) or (ap[i - 1] shr inv);
  rp[0] := ap[0] shl cnt;
end;

// rp := ap shr cnt for cnt in 1..LIMB_BITS-1, walks low to high so rp may alias ap
procedure MpnRshift(rp, ap: PLimb; n: SizeInt; cnt: integer);
begin
  var inv := LIMB_BITS - cnt;
  for var i := 0 to n - 2 do rp[i] := (ap[i] shr cnt) or (ap[i + 1] shl inv);
  rp[n - 1] := ap[n - 1] shr cnt;
end;

{$endif}

// compare two limb runs of equal length n
function MpnCmp(ap, bp: PLimb; n: SizeInt): integer;
begin
  for var i := n - 1 downto 0 do
    if ap[i] <> bp[i] then exit(if ap[i] < bp[i] then -1 else 1);
  result := 0;
end;

type
  // matches the RTL dynarray header (rtl/inc/dynarr.inc: tdynarray)
  PDynArrayHeader = ^TDynArrayHeader;
  TDynArrayHeader = record
    refcount: PtrInt;
    high: PtrInt;
  end;

// fresh limb array built directly on the heap with an UNINITIALIZED payload;
// only for buffers where the caller writes every limb before they escape,
// skips the zero fill and the SetLength dispatch (a large share of the cost
// of small operations); the array is a normal dynarray afterwards
function LNew(n: SizeInt): TLimbs;
begin
  result := nil;
  if n <= 0 then exit;
  var p := PDynArrayHeader(GetMem(SizeOf(TDynArrayHeader) + n * SizeOf(TLimb)));
  p^.refcount := 1;
  p^.high := n - 1;
  Pointer(result) := PByte(p) + SizeOf(TDynArrayHeader);
end;

// same, zero-filled
function LNewZ(n: SizeInt): TLimbs;
begin
  result := LNew(n);
  if n > 0 then FillChar(Pointer(result)^, n * SizeOf(TLimb), 0);
end;

// trim leading (highest) zero limbs
procedure LNorm(var a: TLimbs);
begin
  var n := Length(a);
  while (n > 0) and (a[n - 1] = 0) do dec(n);
  if n <> Length(a) then SetLength(a, n);
end;

function LToQWord(const a: TLimbs): QWord; inline;
begin
  {$if LIMB_BITS = 64}
  result := if Length(a) > 0 then a[0] else 0;
  {$else}
  result := 0;
  if Length(a) > 0 then result := a[0];
  if Length(a) > 1 then result := result or (QWord(a[1]) shl 32);
  {$endif}
end;

function LFromQWord(q: QWord): TLimbs;
begin
  if q = 0 then exit(nil);
  {$if LIMB_BITS = 64}
  result := LNew(1);
  result[0] := q;
  {$else}
  if q <= High(TLimb) then begin
    result := LNew(1);
    result[0] := TLimb(q);
  end else begin
    result := LNew(2);
    result[0] := TLimb(q);
    result[1] := TLimb(q shr 32);
  end;
  {$endif}
end;

// 64 bits of a starting at bit pos, caller guarantees pos + 64 <= bit length
function LExtract64(const a: TLimbs; pos: LongWord): QWord;
begin
  result := 0;
  var limb := SizeInt(pos shr LIMB_SHIFT);
  var off := integer(pos and LIMB_MASK);
  var got := 0;
  while (got < 64) and (limb < Length(a)) do begin
    result := result or (QWord(a[limb] shr off) shl got);
    inc(got, LIMB_BITS - off);
    off := 0;
    inc(limb);
  end;
end;

// k bits of a starting at bit pos (k <= 6), bits past the top read as zero
function LGetBits(const a: TLimbs; pos: LongWord; k: integer): LongWord;
begin
  var limb := SizeInt(pos shr LIMB_SHIFT);
  if limb >= Length(a) then exit(0);
  var off := integer(pos and LIMB_MASK);
  var v: QWord := a[limb] shr off;
  if (off + k > LIMB_BITS) and (limb + 1 < Length(a)) then v := v or (QWord(a[limb + 1]) shl (LIMB_BITS - off));
  result := LongWord(v) and LongWord((1 shl k) - 1);
end;

function LCmp(const a, b: TLimbs): integer;
begin
  if Length(a) <> Length(b) then exit(if Length(a) < Length(b) then -1 else 1);
  for var i := Length(a) - 1 downto 0 do
    if a[i] <> b[i] then exit(if a[i] < b[i] then -1 else 1);
  result := 0;
end;

function LCmpQ(const a: TLimbs; q: QWord): integer;
begin
  if Length(a) > LIMBS_PER_QWORD then exit(1);
  var av := LToQWord(a);
  if av < q then exit(-1);
  if av > q then exit(1);
  result := 0;
end;

// all TLimbs-returning routines build into a fresh local and assign the result
// at the very end: the hidden result may alias an input (x := LAdd(x, y))
function LAdd(const a, b: TLimbs): TLimbs;
var
  res: TLimbs;
begin
  var la := Length(a);
  var lb := Length(b);
  if (la <= 2) and (lb <= 2) then begin
    // two-limb fast path: exact-size allocation, no trim
    var a0: TLimb := if la > 0 then a[0] else 0;
    var a1: TLimb := if la > 1 then a[1] else 0;
    var b1: TLimb := if lb > 1 then b[1] else 0;
    var s0: TLimb := a0 + (if lb > 0 then b[0] else 0);
    var c: TLimb := TLimb(ord(s0 < a0));
    var s1: TLimb := a1 + b1;
    var c1: TLimb := TLimb(ord(s1 < a1));
    s1 := s1 + c;
    c1 := c1 + TLimb(ord(s1 < c));
    if c1 <> 0 then begin
      res := LNew(3);
      res[0] := s0;
      res[1] := s1;
      res[2] := 1;
    end else if s1 <> 0 then begin
      res := LNew(2);
      res[0] := s0;
      res[1] := s1;
    end else if s0 <> 0 then begin
      res := LNew(1);
      res[0] := s0;
    end;
    exit(res);
  end;
  if la < lb then exit(LAdd(b, a));
  if lb = 0 then exit(Copy(a));
  res := LNew(la + 1);
  var carry := MpnAddN(@res[0], @a[0], @b[0], lb);
  res[la] := MpnAdd1(@res[lb], @a[lb], la - lb, carry);
  LNorm(res);
  result := res;
end;

// a - b, caller guarantees a >= b
function LSub(const a, b: TLimbs): TLimbs;
var
  res: TLimbs;
begin
  var la := Length(a);
  var lb := Length(b);
  if la <= 2 then begin
    // b is no longer than a here
    var a1: TLimb := if la > 1 then a[1] else 0;
    var d0: TLimb := if la > 0 then a[0] else 0;
    var b0: TLimb := if lb > 0 then b[0] else 0;
    var brw: TLimb := TLimb(ord(d0 < b0));
    d0 := d0 - b0;
    var d1: TLimb := a1 - (if lb > 1 then b[1] else 0) - brw;
    if d1 <> 0 then begin
      res := LNew(2);
      res[0] := d0;
      res[1] := d1;
    end else if d0 <> 0 then begin
      res := LNew(1);
      res[0] := d0;
    end;
    exit(res);
  end;
  if lb = 0 then exit(Copy(a));
  res := LNew(la);
  var borrow := MpnSubN(@res[0], @a[0], @b[0], lb);
  MpnSub1(@res[lb], @a[lb], la - lb, borrow);
  LNorm(res);
  result := res;
end;

// a - b with underflow check
function LSubChecked(const a, b: TLimbs): TLimbs;
begin
  if LCmp(a, b) < 0 then RaiseNegativeUnsigned;
  result := LSub(a, b);
end;

function LMulBasic(const a, b: TLimbs): TLimbs;
var
  res: TLimbs;
begin
  var la := Length(a);
  var lb := Length(b);
  if (la = 0) or (lb = 0) then exit(nil);
  if (la = 1) and (lb = 1) then begin
    var hi, lo: TLimb;
    UMulLimb(a[0], b[0], hi, lo);
    if hi <> 0 then begin
      res := LNew(2);
      res[0] := lo;
      res[1] := hi;
    end else begin
      res := LNew(1);
      res[0] := lo;
    end;
    exit(res);
  end;
  if la < lb then exit(LMulBasic(b, a));
  if la = 2 then begin
    // 2x1 and 2x2 by hand: exact-size result, no trim
    var h0, l0, h1, l1: TLimb;
    UMulLimb(a[0], b[0], h0, l0);
    UMulLimb(a[1], b[0], h1, l1);
    var r1: TLimb := h0 + l1;
    var c: TLimb := TLimb(ord(r1 < h0));
    var r2: TLimb := h1 + c;
    var r3: TLimb := 0;
    if lb = 2 then begin
      var hx, lx: TLimb;
      UMulLimb(a[0], b[1], hx, lx);
      r1 := r1 + lx;
      c := TLimb(ord(r1 < lx));
      r2 := r2 + c;
      c := TLimb(ord(r2 < c));
      var t: TLimb := r2 + hx;
      c := c + TLimb(ord(t < hx));
      r2 := t;
      UMulLimb(a[1], b[1], hx, lx);
      t := r2 + lx;
      c := c + TLimb(ord(t < lx));
      r2 := t;
      r3 := hx + c; // cannot wrap: the true product stays below B^4
    end;
    if r3 <> 0 then begin
      res := LNew(4);
      res[3] := r3;
      res[2] := r2;
    end else if r2 <> 0 then begin
      res := LNew(3);
      res[2] := r2;
    end else res := LNew(2);
    res[0] := l0;
    res[1] := r1;
    exit(res);
  end;
  // one mul_1 row, then addmul_1 rows with the longer operand innermost;
  // the row order writes every limb before it is read, no zero fill needed
  res := LNew(la + lb);
  res[la] := MpnMul1(@res[0], @a[0], la, b[0]);
  for var j := 1 to lb - 1 do res[la + j] := MpnAddMul1(@res[j], @a[0], la, b[j]);
  LNorm(res);
  result := res;
end;

// schoolbook squaring: cross products once, doubled, plus the diagonal
function LSqrBasic(const a: TLimbs): TLimbs;
var
  res: TLimbs;
begin
  var la := Length(a);
  if la = 0 then exit(nil);
  if la = 1 then begin
    var hi, lo: TLimb;
    UMulLimb(a[0], a[0], hi, lo);
    if hi <> 0 then begin
      res := LNew(2);
      res[0] := lo;
      res[1] := hi;
    end else begin
      res := LNew(1);
      res[0] := lo;
    end;
    exit(res);
  end;
  res := LNewZ(2 * la);
  if la > 1 then begin
    res[la] := MpnMul1(@res[1], @a[1], la - 1, a[0]);
    for var i := 1 to la - 2 do res[la + i] := MpnAddMul1(@res[2 * i + 1], @a[i + 1], la - 1 - i, a[i]);
    // double the cross part
    MpnLshift(@res[0], @res[0], 2 * la, 1);
  end;
  // add the diagonal squares, tracking a single-bit carry between pairs
  var cy: TLimb := 0;
  for var i := 0 to la - 1 do begin
    var hi, lo: TLimb;
    UMulLimb(a[i], a[i], hi, lo);
    var s: TLimb := res[2 * i] + cy;
    var c: TLimb := TLimb(ord(s < cy));
    s := s + lo;
    c := c + TLimb(ord(s < lo));
    res[2 * i] := s;
    var t: TLimb := res[2 * i + 1] + c;
    cy := TLimb(ord(t < c));
    t := t + hi;
    cy := cy + TLimb(ord(t < hi));
    res[2 * i + 1] := t;
  end;
  LNorm(res);
  result := res;
end;

function LMul(const a, b: TLimbs): TLimbs; forward;
function LSqr(const a: TLimbs): TLimbs; forward;
function LShl(const a: TLimbs; n: LongWord): TLimbs; forward;
function LShr(const a: TLimbs; n: LongWord): TLimbs; forward;
function LDivModW(const a: TLimbs; w: TLimb; out rem: TLimb): TLimbs; forward;

// normalized copy of a[start..start+count-1]
function LSlice(const a: TLimbs; start, count: SizeInt): TLimbs;
begin
  if start >= Length(a) then exit(nil);
  result := Copy(a, start, MinS(count, Length(a) - start));
  LNorm(result);
end;

// acc[offset..] += x; the total is known to fit in acc, so no carry escapes
procedure LAddInto(var acc: TLimbs; const x: TLimbs; offset: SizeInt);
begin
  var lx := Length(x);
  if lx = 0 then exit;
  var carry := MpnAddN(@acc[offset], @acc[offset], @x[0], lx);
  if carry <> 0 then MpnAdd1(@acc[offset + lx], @acc[offset + lx], Length(acc) - offset - lx, carry);
end;

// Karatsuba: a*b = z2*B^2m + (z1-z0-z2)*B^m + z0 with three half-size products
function LMulKara(const a, b: TLimbs): TLimbs;
var
  res: TLimbs;
begin
  var la := Length(a);
  var lb := Length(b);
  var m := (MaxS(la, lb) + 1) shr 1;
  var a0 := LSlice(a, 0, m);
  var a1 := LSlice(a, m, la);
  var b0 := LSlice(b, 0, m);
  var b1 := LSlice(b, m, lb);
  var z0 := LMul(a0, b0);
  var z2 := LMul(a1, b1);
  var zm := LMul(LAdd(a0, a1), LAdd(b0, b1));
  zm := LSub(zm, z0);
  zm := LSub(zm, z2);
  res := LNewZ(la + lb);
  LAddInto(res, z0, 0);
  LAddInto(res, zm, m);
  LAddInto(res, z2, 2 * m);
  LNorm(res);
  result := res;
end;

function LSqrKara(const a: TLimbs): TLimbs;
var
  res: TLimbs;
begin
  var la := Length(a);
  var m := (la + 1) shr 1;
  var a0 := LSlice(a, 0, m);
  var a1 := LSlice(a, m, la);
  var z0 := LSqr(a0);
  var z2 := LSqr(a1);
  var zm := LShl(LMul(a0, a1), 1);
  res := LNewZ(2 * la);
  LAddInto(res, z0, 0);
  LAddInto(res, zm, m);
  LAddInto(res, z2, 2 * m);
  LNorm(res);
  result := res;
end;

// exact division by 3 for the Toom-3 interpolation
function DivExact3(const x: TLimbs): TLimbs;
var
  rem: TLimb;
begin
  result := LDivModW(x, 3, rem);
end;

// Toom-3: split into three k-limb parts, evaluate at 0, 1, -1, 2 and
// infinity, recombine five recursive products instead of nine
function LMulToom3(const a, b: TLimbs): TLimbs;
var
  res: TLimbs;
begin
  var la := Length(a);
  var lb := Length(b);
  var k := (MaxS(la, lb) + 2) div 3;
  var a0 := LSlice(a, 0, k);
  var a1 := LSlice(a, k, k);
  var a2 := LSlice(a, 2 * k, la);
  var b0 := LSlice(b, 0, k);
  var b1 := LSlice(b, k, k);
  var b2 := LSlice(b, 2 * k, lb);
  var a02 := LAdd(a0, a2);
  var b02 := LAdd(b0, b2);
  var v0 := LMul(a0, b0);
  var v1 := LMul(LAdd(a02, a1), LAdd(b02, b1));
  var vinf := LMul(a2, b2);
  // the -1 evaluations can go negative: carry their signs separately
  var aNeg := LCmp(a02, a1) < 0;
  var bNeg := LCmp(b02, b1) < 0;
  var am1 := if aNeg then LSub(a1, a02) else LSub(a02, a1);
  var bm1 := if bNeg then LSub(b1, b02) else LSub(b02, b1);
  var vm1 := LMul(am1, bm1);
  var vm1Neg := aNeg xor bNeg;
  var v2 := LMul(LAdd(LAdd(a0, LShl(a1, 1)), LShl(a2, 2)), LAdd(LAdd(b0, LShl(b1, 1)), LShl(b2, 2)));
  // interpolation; every value below is a nonnegative coefficient combination
  var t3 := DivExact3(if vm1Neg then LAdd(v2, vm1) else LSub(v2, vm1));
  var t1 := LShr(if vm1Neg then LAdd(v1, vm1) else LSub(v1, vm1), 1);
  var t2 := LSub(v1, v0);
  t3 := LShr(LSub(t3, t2), 1);
  t2 := LSub(t2, t1);
  var c3 := LSub(t3, LShl(vinf, 1));
  var c1 := LSub(t1, c3);
  var c2 := LSub(t2, vinf);
  res := LNewZ(la + lb);
  LAddInto(res, v0, 0);
  LAddInto(res, c1, k);
  LAddInto(res, c2, 2 * k);
  LAddInto(res, c3, 3 * k);
  LAddInto(res, vinf, 4 * k);
  LNorm(res);
  result := res;
end;

function LSqrToom3(const a: TLimbs): TLimbs;
var
  res: TLimbs;
begin
  var la := Length(a);
  var k := (la + 2) div 3;
  var a0 := LSlice(a, 0, k);
  var a1 := LSlice(a, k, k);
  var a2 := LSlice(a, 2 * k, la);
  var a02 := LAdd(a0, a2);
  var v0 := LSqr(a0);
  var v1 := LSqr(LAdd(a02, a1));
  var vinf := LSqr(a2);
  // squaring makes the -1 evaluation sign-free
  var vm1 := LSqr(if LCmp(a02, a1) < 0 then LSub(a1, a02) else LSub(a02, a1));
  var v2 := LSqr(LAdd(LAdd(a0, LShl(a1, 1)), LShl(a2, 2)));
  var t3 := DivExact3(LSub(v2, vm1));
  var t1 := LShr(LSub(v1, vm1), 1);
  var t2 := LSub(v1, v0);
  t3 := LShr(LSub(t3, t2), 1);
  t2 := LSub(t2, t1);
  var c3 := LSub(t3, LShl(vinf, 1));
  var c1 := LSub(t1, c3);
  var c2 := LSub(t2, vinf);
  res := LNewZ(2 * la);
  LAddInto(res, v0, 0);
  LAddInto(res, c1, k);
  LAddInto(res, c2, 2 * k);
  LAddInto(res, c3, 3 * k);
  LAddInto(res, vinf, 4 * k);
  LNorm(res);
  result := res;
end;

function LMul(const a, b: TLimbs): TLimbs;
begin
  var mn := MinS(Length(a), Length(b));
  if mn < BigIntKaratsubaThreshold then exit(LMulBasic(a, b));
  if (mn >= BigIntToom3Threshold) and (MaxS(Length(a), Length(b)) < 2 * mn) then exit(LMulToom3(a, b));
  result := LMulKara(a, b);
end;

function LSqr(const a: TLimbs): TLimbs;
begin
  var la := Length(a);
  if la < BigIntKaratsubaThreshold then exit(LSqrBasic(a));
  if la >= BigIntToom3Threshold then exit(LSqrToom3(a));
  result := LSqrKara(a);
end;

// a * w for a single-limb factor
function LMulW(const a: TLimbs; w: TLimb): TLimbs;
var
  res: TLimbs;
begin
  var la := Length(a);
  if (la = 0) or (w = 0) then exit(nil);
  res := LNew(la + 1);
  res[la] := MpnMul1(@res[0], @a[0], la, w);
  LNorm(res);
  result := res;
end;

function LMulQ(const a: TLimbs; q: QWord): TLimbs;
begin
  {$if LIMB_BITS = 64}
  result := LMulW(a, q);
  {$else}
  if q <= High(TLimb) then exit(LMulW(a, TLimb(q)));
  result := LMul(a, LFromQWord(q));
  {$endif}
end;

// a := a * m + addv (used by the parser), a must not be shared
procedure LMulAddWInPlace(var a: TLimbs; m, addv: TLimb);
begin
  var la := Length(a);
  var carry: TLimb := addv;
  for var i := 0 to la - 1 do begin
    var hi, lo: TLimb;
    UMulLimb(a[i], m, hi, lo);
    lo := lo + carry;
    a[i] := lo;
    carry := hi + TLimb(ord(lo < carry));
  end;
  if carry <> 0 then begin
    SetLength(a, la + 1);
    a[la] := carry;
  end;
end;

// divide a[0..alen-1] by w in place, return remainder; caller trims alen
function LDivWInPlaceLen(var a: TLimbs; var alen: SizeInt; w: TLimb): TLimb;
begin
  var rem: TLimb := 0;
  for var i := alen - 1 downto 0 do a[i] := UDivLimb(rem, a[i], w, rem);
  while (alen > 0) and (a[alen - 1] = 0) do dec(alen);
  result := rem;
end;

function LDivModW(const a: TLimbs; w: TLimb; out rem: TLimb): TLimbs;
var
  res: TLimbs;
begin
  res := LNew(Length(a));
  var r: TLimb := 0;
  for var i := Length(a) - 1 downto 0 do res[i] := UDivLimb(r, a[i], w, r);
  rem := r;
  LNorm(res);
  result := res;
end;

// full division, Knuth algorithm D; v <> 0 guaranteed by callers
// q and r are out params, so callers must pass fresh locals, never anything
// that may alias u or v (managed out params are finalized on entry)
procedure LDivMod(const u, v: TLimbs; out q, r: TLimbs);
var
  un, vn: TLimbs;
  rw: TLimb;
begin
  var n := Length(v);
  if LCmp(u, v) < 0 then begin
    q := nil;
    r := Copy(u);
    exit;
  end;
  if n = 1 then begin
    q := LDivModW(u, v[0], rw);
    r := LFromQWord(rw);
    exit;
  end;
  var m := Length(u);
  // normalize so the top bit of vn[n-1] is set
  var s := LIMB_MASK - integer(LimbBsr(v[n - 1]));
  vn := LNew(n);
  un := LNew(m + 1);
  if s = 0 then begin
    Move(v[0], vn[0], n * SizeOf(TLimb));
    Move(u[0], un[0], m * SizeOf(TLimb));
    un[m] := 0;
  end else begin
    MpnLshift(@vn[0], @v[0], n, s);
    un[m] := MpnLshift(@un[0], @u[0], m, s);
  end;
  q := LNew(m - n + 1);
  var vTop := vn[n - 1];
  var vNext := vn[n - 2];
  for var j := m - n downto 0 do begin
    // estimate the quotient digit from the top limbs
    var qhat, rhat: TLimb;
    var doneAdjust := false;
    if un[j + n] = vTop then begin
      qhat := High(TLimb);
      rhat := un[j + n - 1] + vTop;
      doneAdjust := rhat < vTop; // rhat overflowed a limb: the adjust condition is already false
    end else qhat := UDivLimb(un[j + n], un[j + n - 1], vTop, rhat);
    while not doneAdjust do begin
      var phi, plo: TLimb;
      UMulLimb(qhat, vNext, phi, plo);
      if (phi < rhat) or ((phi = rhat) and (plo <= un[j + n - 2])) then break;
      dec(qhat);
      rhat := rhat + vTop;
      doneAdjust := rhat < vTop;
    end;
    // multiply and subtract; an estimate one too large shows up as a borrow
    var borrow := MpnSubMul1(@un[j], @vn[0], n, qhat);
    var top := un[j + n];
    un[j + n] := top - borrow;
    if top < borrow then begin
      // add back
      dec(qhat);
      un[j + n] := un[j + n] + MpnAddN(@un[j], @un[j], @vn[0], n);
    end;
    q[j] := qhat;
  end;
  LNorm(q);
  // denormalize the remainder
  r := LNew(n);
  if s = 0 then Move(un[0], r[0], n * SizeOf(TLimb))
  else MpnRshift(@r[0], @un[0], n, s);
  LNorm(r);
end;

function LShl(const a: TLimbs; n: LongWord): TLimbs;
var
  res: TLimbs;
begin
  var la := Length(a);
  if la = 0 then exit(nil);
  if n = 0 then exit(Copy(a));
  var limbShift := SizeInt(n shr LIMB_SHIFT);
  var bitShift := integer(n and LIMB_MASK);
  res := LNew(la + limbShift + 1);
  if limbShift > 0 then FillChar(res[0], limbShift * SizeOf(TLimb), 0);
  if bitShift = 0 then begin
    Move(a[0], res[limbShift], la * SizeOf(TLimb));
    res[la + limbShift] := 0;
  end else res[la + limbShift] := MpnLshift(@res[limbShift], @a[0], la, bitShift);
  LNorm(res);
  result := res;
end;

function LShr(const a: TLimbs; n: LongWord): TLimbs;
var
  res: TLimbs;
begin
  var la := Length(a);
  if la = 0 then exit(nil);
  if n = 0 then exit(Copy(a));
  var limbShift := SizeInt(n shr LIMB_SHIFT);
  if limbShift >= la then exit(nil);
  var bitShift := integer(n and LIMB_MASK);
  var rl := la - limbShift;
  res := LNew(rl);
  if bitShift = 0 then Move(a[limbShift], res[0], rl * SizeOf(TLimb))
  else MpnRshift(@res[0], @a[limbShift], rl, bitShift);
  LNorm(res);
  result := res;
end;

function LAnd(const a, b: TLimbs): TLimbs;
var
  res: TLimbs;
begin
  var n := MinS(Length(a), Length(b));
  SetLength(res, n);
  for var i := 0 to n - 1 do res[i] := a[i] and b[i];
  LNorm(res);
  result := res;
end;

function LOr(const a, b: TLimbs): TLimbs;
var
  res: TLimbs;
begin
  if Length(a) < Length(b) then exit(LOr(b, a));
  res := Copy(a);
  for var i := 0 to Length(b) - 1 do res[i] := res[i] or b[i];
  result := res;
end;

function LXor(const a, b: TLimbs): TLimbs;
var
  res: TLimbs;
begin
  if Length(a) < Length(b) then exit(LXor(b, a));
  res := Copy(a);
  for var i := 0 to Length(b) - 1 do res[i] := res[i] xor b[i];
  LNorm(res);
  result := res;
end;

function LBitLen(const a: TLimbs): LongWord;
begin
  var la := Length(a);
  if la = 0 then exit(0);
  result := LongWord(la - 1) * LIMB_BITS + LimbBsr(a[la - 1]) + 1;
end;

function LTestBit(const a: TLimbs; i: LongWord): boolean;
begin
  var limb := SizeInt(i shr LIMB_SHIFT);
  if limb >= Length(a) then exit(false);
  result := (a[limb] shr (i and LIMB_MASK)) and 1 <> 0;
end;

// ---------------------------------------------------------------------------
// string conversion core
// ---------------------------------------------------------------------------

// bits per digit for power-of-two bases, 0 otherwise
function Pow2BaseBits(base: integer): integer;
begin
  result := case base of
    2: 1;
    4: 2;
    8: 3;
    16: 4;
    32: 5;
  else 0;
end;

// digits of a power-of-two base extracted straight from the bits
function LToPow2Base(const a: TLimbs; bpd: integer): string;
begin
  var totalBits := LBitLen(a);
  var digits := SizeInt((QWord(totalBits) + LongWord(bpd) - 1) div LongWord(bpd));
  var mask := TLimb((1 shl bpd) - 1);
  SetLength(result, digits);
  var la := Length(a);
  for var d := 0 to digits - 1 do begin
    var bitPos := QWord(d) * LongWord(bpd);
    var limb := SizeInt(bitPos shr LIMB_SHIFT);
    var off := integer(bitPos and LIMB_MASK);
    var v := a[limb] shr off;
    if (off + bpd > LIMB_BITS) and (limb + 1 < la) then v := v or (a[limb + 1] shl (LIMB_BITS - off));
    result[digits - d] := DIGIT_CHARS[(v and mask) + 1];
  end;
end;

const
  // digit counts below which base conversion stays on the linear algorithms
  TOSTR_DC_DIGITS = 400;
  PARSE_DC_DIGITS = 400;

// linear conversion core: right-align the digits of a into buf[0..nd-1] and
// left-pad with zeros; a is a scratch copy this routine destroys
procedure LToBaseLinear(a: TLimbs; base: integer; chunkBase: TLimb; chunkLen: integer; buf: PAnsiChar; nd: SizeInt);
begin
  var p := nd - 1;
  var alen := Length(a);
  while alen > 0 do begin
    var rem := LDivWInPlaceLen(a, alen, chunkBase);
    if alen > 0 then
      for var i := 1 to chunkLen do begin
        buf[p] := DIGIT_CHARS[rem mod TLimb(base) + 1];
        rem := rem div TLimb(base);
        dec(p);
      end
    else
      repeat
        buf[p] := DIGIT_CHARS[rem mod TLimb(base) + 1];
        rem := rem div TLimb(base);
        dec(p);
      until rem = 0;
  end;
  while p >= 0 do begin
    buf[p] := '0';
    dec(p);
  end;
end;

// divide-and-conquer digits writer: split off the low base^k digits with one
// division against a precomputed power, recurse into both halves
procedure LToBaseRec(const a: TLimbs; base: integer; chunkBase: TLimb; chunkLen: integer; buf: PAnsiChar; nd: SizeInt; const pows: array of TLimbs; level: integer);
var
  q, r: TLimbs;
begin
  if (level < 0) or (nd <= TOSTR_DC_DIGITS) then begin
    LToBaseLinear(Copy(a), base, chunkBase, chunkLen, buf, nd);
    exit;
  end;
  var k := chunkLen shl level;
  if k >= nd then begin
    LToBaseRec(a, base, chunkBase, chunkLen, buf, nd, pows, level - 1);
    exit;
  end;
  LDivMod(a, pows[level], q, r);
  LToBaseRec(q, base, chunkBase, chunkLen, buf, nd - k, pows, level - 1);
  LToBaseRec(r, base, chunkBase, chunkLen, buf + (nd - k), k, pows, level - 1);
end;

// generic base conversion; large numbers go through divide-and-conquer
function LToBase(const a: TLimbs; base: integer): string;
var
  pows: array of TLimbs;
begin
  if Length(a) = 0 then exit('0');
  var bpd := Pow2BaseBits(base);
  if bpd > 0 then exit(LToPow2Base(a, bpd));
  // chunkBase = base^chunkLen, the largest power fitting a limb
  var chunkBase: TLimb := base;
  var chunkLen := 1;
  while chunkBase <= High(TLimb) div TLimb(base) do begin
    chunkBase := chunkBase * TLimb(base);
    inc(chunkLen);
  end;
  // tight digit count upper bound keeps the recursion splits balanced
  var cap := SizeInt(Trunc(LBitLen(a) / Log2(base))) + 2;
  var buf: string;
  SetLength(buf, cap);
  if cap <= TOSTR_DC_DIGITS then LToBaseLinear(Copy(a), base, chunkBase, chunkLen, PAnsiChar(buf), cap)
  else begin
    // pows[i] = chunkBase^(2^i), enough levels to split cap in half
    var maxLevel := -1;
    var k: SizeInt := chunkLen;
    while k < cap do begin
      inc(maxLevel);
      k := k * 2;
    end;
    SetLength(pows, maxLevel + 1);
    pows[0] := LFromQWord(chunkBase);
    for var i := 1 to maxLevel do pows[i] := LSqr(pows[i - 1]);
    LToBaseRec(a, base, chunkBase, chunkLen, PAnsiChar(buf), cap, pows, maxLevel);
  end;
  // strip the leading zero padding
  var p := 1;
  while (p < cap) and (buf[p] = '0') do inc(p);
  result := Copy(buf, p, cap - p + 1);
end;

// digit values collected from a validated string
function CollectDigits(const s: string; start: SizeInt; base: integer; out digits: TBytes): boolean;
begin
  SetLength(digits, Length(s) - start + 1);
  var count: SizeInt := 0;
  for var i := start to Length(s) do begin
    var c: char := s[i];
    if c = '_' then continue;
    var v: integer := case c of
      '0'..'9': Ord(c) - Ord('0');
      'A'..'Z': Ord(c) - Ord('A') + 10;
      'a'..'z': Ord(c) - Ord('a') + 10;
    else 99;
    if v >= base then exit(false);
    digits[count] := byte(v);
    inc(count);
  end;
  SetLength(digits, count);
  result := count > 0;
end;

// linear parse core: chunked multiply-add over count digit values
function LFromDigitsLinear(digits: PByte; count: SizeInt; base: integer; chunkBase: TLimb; chunkLen: integer): TLimbs;
begin
  result := nil;
  var pos: SizeInt := 0;
  var firstLen := count mod chunkLen;
  if firstLen > 0 then begin
    var v: TLimb := 0;
    var mult: TLimb := 1;
    for var i := 1 to firstLen do begin
      v := v * TLimb(base) + digits[pos];
      mult := mult * TLimb(base);
      inc(pos);
    end;
    LMulAddWInPlace(result, mult, v);
  end;
  while pos < count do begin
    var v: TLimb := 0;
    for var i := 1 to chunkLen do begin
      v := v * TLimb(base) + digits[pos];
      inc(pos);
    end;
    LMulAddWInPlace(result, chunkBase, v);
  end;
end;

// divide-and-conquer parse: value = high * chunkBase^(2^level slice) + low
function LFromDigitsRec(digits: PByte; count: SizeInt; base: integer; chunkBase: TLimb; chunkLen: integer; const pows: array of TLimbs; level: integer): TLimbs;
begin
  if (level < 0) or (count <= PARSE_DC_DIGITS) then exit(LFromDigitsLinear(digits, count, base, chunkBase, chunkLen));
  var k := chunkLen shl level;
  if k >= count then exit(LFromDigitsRec(digits, count, base, chunkBase, chunkLen, pows, level - 1));
  var high := LFromDigitsRec(digits, count - k, base, chunkBase, chunkLen, pows, level - 1);
  var low := LFromDigitsRec(digits + (count - k), k, base, chunkBase, chunkLen, pows, level - 1);
  result := LAdd(LMul(high, pows[level]), low);
end;

function LFromDigits(const digits: TBytes; base: integer): TLimbs;
var
  pows: array of TLimbs;
begin
  result := nil;
  var count := Length(digits);
  var bpd := Pow2BaseBits(base);
  if bpd > 0 then begin
    var totalBits := QWord(count) * LongWord(bpd);
    SetLength(result, SizeInt((totalBits + LIMB_MASK) shr LIMB_SHIFT));
    var bitPos: QWord := 0;
    for var i := count - 1 downto 0 do begin
      var v := TLimb(digits[i]);
      var limb := SizeInt(bitPos shr LIMB_SHIFT);
      var off := integer(bitPos and LIMB_MASK);
      result[limb] := result[limb] or (v shl off);
      if (off + bpd > LIMB_BITS) and (limb + 1 < Length(result)) then result[limb + 1] := result[limb + 1] or (v shr (LIMB_BITS - off));
      bitPos := bitPos + LongWord(bpd);
    end;
    LNorm(result);
    exit;
  end;
  // generic bases: chunked multiply-add, divide-and-conquer when long
  var chunkBase: TLimb := base;
  var chunkLen := 1;
  while chunkBase <= High(TLimb) div TLimb(base) do begin
    chunkBase := chunkBase * TLimb(base);
    inc(chunkLen);
  end;
  if count <= PARSE_DC_DIGITS then exit(LFromDigitsLinear(@digits[0], count, base, chunkBase, chunkLen));
  var maxLevel := -1;
  var k: SizeInt := chunkLen;
  while k < count do begin
    inc(maxLevel);
    k := k * 2;
  end;
  SetLength(pows, maxLevel + 1);
  pows[0] := LFromQWord(chunkBase);
  for var i := 1 to maxLevel do pows[i] := LSqr(pows[i - 1]);
  result := LFromDigitsRec(@digits[0], count, base, chunkBase, chunkLen, pows, maxLevel);
end;

// parse core: base = 0 auto-detects prefixes ($ 0x hex, % 0b bin, & 0o oct)
function TryParseLimbs(const s: string; base: integer; out limbs: TLimbs; out neg: boolean): boolean;
begin
  limbs := nil;
  neg := false;
  var i: SizeInt := 1;
  var len := Length(s);
  while (i <= len) and (s[i] in [' ', #9]) do inc(i);
  while (len >= i) and (s[len] in [' ', #9]) do dec(len);
  if i > len then exit(false);
  if s[i] in ['+', '-'] then begin
    neg := s[i] = '-';
    inc(i);
  end;
  if base = 0 then begin
    base := 10;
    if i <= len then
      match s[i] of
        '$': begin base := 16; inc(i); end;
        '%': begin base := 2; inc(i); end;
        '&': begin base := 8; inc(i); end;
        '0': if i < len then
          match s[i + 1] of
            'x', 'X': begin base := 16; inc(i, 2); end;
            'b', 'B': begin base := 2; inc(i, 2); end;
            'o', 'O': begin base := 8; inc(i, 2); end;
          end;
      end;
  end;
  var digits: TBytes;
  if not CollectDigits(Copy(s, 1, len), i, base, digits) then exit(false);
  limbs := LFromDigits(digits, base);
  result := true;
end;

// ---------------------------------------------------------------------------
// UBigInt
// ---------------------------------------------------------------------------

class operator UBigInt.:=(x: Int64): UBigInt;
begin
  if x < 0 then RaiseNegativeUnsigned;
  result.fLimbs := LFromQWord(QWord(x));
end;

class operator UBigInt.:=(x: QWord): UBigInt;
begin
  result.fLimbs := LFromQWord(x);
end;

class operator UBigInt.:=(const s: string): UBigInt;
begin
  result := UBigInt.parse(s);
end;

class operator UBigInt.explicit(d: Double): UBigInt;
begin
  if IsNan(d) or IsInfinite(d) then raise EConvertError.Create('cannot convert NaN or Inf to UBigInt');
  if d <= -1.0 then RaiseNegativeUnsigned;
  if System.Abs(d) < 1.0 then exit(default(UBigInt));
  var mantissa: Double;
  var exponent: integer;
  Frexp(d, mantissa, exponent);
  // mantissa in [0.5, 1); 53 significant bits, scaled to an integer
  var q := QWord(Trunc(mantissa * 9007199254740992.0)); // 2^53
  var e := exponent - 53;
  result.fLimbs := LFromQWord(q);
  if e > 0 then result.fLimbs := LShl(result.fLimbs, LongWord(e))
  else if e < 0 then result.fLimbs := LShr(result.fLimbs, LongWord(-e));
end;

class operator UBigInt.explicit(x: Int64): UBigInt;
begin
  if x < 0 then RaiseNegativeUnsigned;
  result.fLimbs := LFromQWord(QWord(x));
end;

class operator UBigInt.explicit(x: QWord): UBigInt;
begin
  result.fLimbs := LFromQWord(x);
end;

class operator UBigInt.explicit(const a: UBigInt): Int64;
begin
  result := a.toInt64;
end;

class operator UBigInt.explicit(const a: UBigInt): QWord;
begin
  result := a.toQWord;
end;

class operator UBigInt.explicit(const a: UBigInt): LongInt;
begin
  result := a.toInteger;
end;

class operator UBigInt.explicit(const a: UBigInt): LongWord;
begin
  result := a.toCardinal;
end;

class operator UBigInt.explicit(const a: UBigInt): Double;
begin
  result := a.toDouble;
end;

class operator UBigInt.explicit(const a: UBigInt): string;
begin
  result := a.toString;
end;

class operator UBigInt.+(const a, b: UBigInt): UBigInt;
begin
  result.fLimbs := LAdd(a.fLimbs, b.fLimbs);
end;

class operator UBigInt.+(const a: UBigInt; b: Int64): UBigInt;
begin
  if b >= 0 then result.fLimbs := LAdd(a.fLimbs, LFromQWord(QWord(b)))
  else result.fLimbs := LSubChecked(a.fLimbs, LFromQWord(NegAbs64(b)));
end;

class operator UBigInt.+(a: Int64; const b: UBigInt): UBigInt;
begin
  result := b + a;
end;

class operator UBigInt.-(const a, b: UBigInt): UBigInt;
begin
  result.fLimbs := LSubChecked(a.fLimbs, b.fLimbs);
end;

class operator UBigInt.-(const a: UBigInt; b: Int64): UBigInt;
begin
  if b >= 0 then result.fLimbs := LSubChecked(a.fLimbs, LFromQWord(QWord(b)))
  else result.fLimbs := LAdd(a.fLimbs, LFromQWord(NegAbs64(b)));
end;

class operator UBigInt.-(a: Int64; const b: UBigInt): UBigInt;
begin
  if a < 0 then RaiseNegativeUnsigned;
  result.fLimbs := LSubChecked(LFromQWord(QWord(a)), b.fLimbs);
end;

class operator UBigInt.*(const a, b: UBigInt): UBigInt;
begin
  result.fLimbs := LMul(a.fLimbs, b.fLimbs);
end;

class operator UBigInt.*(const a: UBigInt; b: Int64): UBigInt;
begin
  if b < 0 then begin
    if Length(a.fLimbs) <> 0 then RaiseNegativeUnsigned;
    exit(default(UBigInt));
  end;
  result.fLimbs := LMulQ(a.fLimbs, QWord(b));
end;

class operator UBigInt.*(a: Int64; const b: UBigInt): UBigInt;
begin
  result := b * a;
end;

class operator UBigInt.div(const a, b: UBigInt): UBigInt;
var
  q, r: TLimbs;
begin
  if Length(b.fLimbs) = 0 then RaiseDivByZero;
  LDivMod(a.fLimbs, b.fLimbs, q, r);
  result.fLimbs := q;
end;

class operator UBigInt.div(const a: UBigInt; b: Int64): UBigInt;
var
  rw: TLimb;
  {$if LIMB_BITS = 32}
  q, r: TLimbs;
  {$endif}
begin
  if b = 0 then RaiseDivByZero;
  if b < 0 then begin
    if Length(a.fLimbs) <> 0 then RaiseNegativeUnsigned;
    exit(default(UBigInt));
  end;
  {$if LIMB_BITS = 64}
  result.fLimbs := LDivModW(a.fLimbs, TLimb(b), rw);
  {$else}
  if QWord(b) <= High(TLimb) then result.fLimbs := LDivModW(a.fLimbs, TLimb(b), rw)
  else begin
    LDivMod(a.fLimbs, LFromQWord(QWord(b)), q, r);
    result.fLimbs := q;
  end;
  {$endif}
end;

class operator UBigInt.mod(const a, b: UBigInt): UBigInt;
var
  q, r: TLimbs;
begin
  if Length(b.fLimbs) = 0 then RaiseDivByZero;
  LDivMod(a.fLimbs, b.fLimbs, q, r);
  result.fLimbs := r;
end;

class operator UBigInt.mod(const a: UBigInt; b: Int64): UBigInt;
var
  rw: TLimb;
  {$if LIMB_BITS = 32}
  q, r: TLimbs;
  {$endif}
begin
  if b = 0 then RaiseDivByZero;
  // remainder of a nonnegative dividend is nonnegative for either divisor sign
  var m: QWord := if b > 0 then QWord(b) else NegAbs64(b);
  {$if LIMB_BITS = 64}
  LDivModW(a.fLimbs, TLimb(m), rw);
  result.fLimbs := LFromQWord(rw);
  {$else}
  if m <= High(TLimb) then begin
    LDivModW(a.fLimbs, TLimb(m), rw);
    result.fLimbs := LFromQWord(rw);
  end else begin
    LDivMod(a.fLimbs, LFromQWord(m), q, r);
    result.fLimbs := r;
  end;
  {$endif}
end;

class operator UBigInt./(const a, b: UBigInt): UBigInt;
begin
  result := a div b;
end;

// binary exponentiation
function UPowQ(const base: TLimbs; e: QWord): TLimbs;
var
  acc, b: TLimbs;
begin
  b := Copy(base);
  acc := [1];
  while e > 0 do begin
    if e and 1 <> 0 then acc := LMul(acc, b);
    e := e shr 1;
    if e > 0 then b := LSqr(b);
  end;
  result := acc;
end;

class operator UBigInt.**(const a, b: UBigInt): UBigInt;
begin
  if Length(b.fLimbs) = 0 then begin
    // x^0 = 1, including 0^0
    result.fLimbs := [1];
    exit;
  end;
  if Length(a.fLimbs) = 0 then exit(default(UBigInt));
  if a.isOne then exit(a);
  result.fLimbs := UPowQ(a.fLimbs, b.toQWord);
end;

class operator UBigInt.**(const a: UBigInt; e: Int64): UBigInt;
begin
  if e < 0 then raise EBigIntError.Create('negative exponent for integer power');
  if e = 0 then begin
    result.fLimbs := [1];
    exit;
  end;
  if Length(a.fLimbs) = 0 then exit(default(UBigInt));
  result.fLimbs := UPowQ(a.fLimbs, QWord(e));
end;

class operator UBigInt.inc(const a: UBigInt): UBigInt;
begin
  result := a + 1;
end;

class operator UBigInt.dec(const a: UBigInt): UBigInt;
begin
  result := a - 1;
end;

class operator UBigInt.shl(const a: UBigInt; n: Int64): UBigInt;
begin
  if n < 0 then raise ERangeError.Create('negative shift count');
  if Length(a.fLimbs) = 0 then exit(default(UBigInt));
  if n > High(LongWord) then raise EBigIntError.Create('shift count out of range');
  result.fLimbs := LShl(a.fLimbs, LongWord(n));
end;

class operator UBigInt.shr(const a: UBigInt; n: Int64): UBigInt;
begin
  if n < 0 then raise ERangeError.Create('negative shift count');
  if n > High(LongWord) then exit(default(UBigInt));
  result.fLimbs := LShr(a.fLimbs, LongWord(n));
end;

class operator UBigInt.and(const a, b: UBigInt): UBigInt;
begin
  result.fLimbs := LAnd(a.fLimbs, b.fLimbs);
end;

class operator UBigInt.or(const a, b: UBigInt): UBigInt;
begin
  result.fLimbs := LOr(a.fLimbs, b.fLimbs);
end;

class operator UBigInt.xor(const a, b: UBigInt): UBigInt;
begin
  result.fLimbs := LXor(a.fLimbs, b.fLimbs);
end;

class operator UBigInt.=(const a, b: UBigInt): boolean;
begin
  result := LCmp(a.fLimbs, b.fLimbs) = 0;
end;

class operator UBigInt.=(const a: UBigInt; b: Int64): boolean;
begin
  result := (b >= 0) and (LCmpQ(a.fLimbs, QWord(b)) = 0);
end;

class operator UBigInt.=(a: Int64; const b: UBigInt): boolean;
begin
  result := b = a;
end;

class operator UBigInt.<>(const a, b: UBigInt): boolean;
begin
  result := LCmp(a.fLimbs, b.fLimbs) <> 0;
end;

class operator UBigInt.<>(const a: UBigInt; b: Int64): boolean;
begin
  result := not (a = b);
end;

class operator UBigInt.<>(a: Int64; const b: UBigInt): boolean;
begin
  result := not (b = a);
end;

class operator UBigInt.<(const a, b: UBigInt): boolean;
begin
  result := LCmp(a.fLimbs, b.fLimbs) < 0;
end;

class operator UBigInt.<(const a: UBigInt; b: Int64): boolean;
begin
  result := (b > 0) and (LCmpQ(a.fLimbs, QWord(b)) < 0);
end;

class operator UBigInt.<(a: Int64; const b: UBigInt): boolean;
begin
  result := (a < 0) or (LCmpQ(b.fLimbs, QWord(a)) > 0);
end;

class operator UBigInt.<=(const a, b: UBigInt): boolean;
begin
  result := LCmp(a.fLimbs, b.fLimbs) <= 0;
end;

class operator UBigInt.<=(const a: UBigInt; b: Int64): boolean;
begin
  result := (b >= 0) and (LCmpQ(a.fLimbs, QWord(b)) <= 0);
end;

class operator UBigInt.<=(a: Int64; const b: UBigInt): boolean;
begin
  result := (a < 0) or (LCmpQ(b.fLimbs, QWord(a)) >= 0);
end;

class operator UBigInt.>(const a, b: UBigInt): boolean;
begin
  result := LCmp(a.fLimbs, b.fLimbs) > 0;
end;

class operator UBigInt.>(const a: UBigInt; b: Int64): boolean;
begin
  result := (b < 0) or (LCmpQ(a.fLimbs, QWord(b)) > 0);
end;

class operator UBigInt.>(a: Int64; const b: UBigInt): boolean;
begin
  result := (a > 0) and (LCmpQ(b.fLimbs, QWord(a)) < 0);
end;

class operator UBigInt.>=(const a, b: UBigInt): boolean;
begin
  result := LCmp(a.fLimbs, b.fLimbs) >= 0;
end;

class operator UBigInt.>=(const a: UBigInt; b: Int64): boolean;
begin
  result := (b < 0) or (LCmpQ(a.fLimbs, QWord(b)) >= 0);
end;

class operator UBigInt.>=(a: Int64; const b: UBigInt): boolean;
begin
  result := (a >= 0) and (LCmpQ(b.fLimbs, QWord(a)) <= 0);
end;

function UBigInt.toString: string;
begin
  result := LToBase(fLimbs, 10);
end;

function UBigInt.toString(base: integer): string;
begin
  if (base < 2) or (base > 36) then raise EBigIntError.Create($'invalid base {base}, expected 2..36');
  result := LToBase(fLimbs, base);
end;

function UBigInt.toHex: string;
begin
  result := LToBase(fLimbs, 16);
end;

function UBigInt.toBin: string;
begin
  result := LToBase(fLimbs, 2);
end;

function UBigInt.toOct: string;
begin
  result := LToBase(fLimbs, 8);
end;

function UBigInt.toInt64: Int64;
begin
  if not fitsInInt64 then raise ERangeError.Create('UBigInt value does not fit in Int64');
  result := Int64(LToQWord(fLimbs));
end;

function UBigInt.toQWord: QWord;
begin
  if not fitsInQWord then raise ERangeError.Create('UBigInt value does not fit in QWord');
  result := LToQWord(fLimbs);
end;

function UBigInt.toInteger: LongInt;
begin
  if not fitsInInteger then raise ERangeError.Create('UBigInt value does not fit in Integer');
  result := LongInt(LToQWord(fLimbs));
end;

function UBigInt.toCardinal: LongWord;
begin
  if not fitsInCardinal then raise ERangeError.Create('UBigInt value does not fit in Cardinal');
  result := LongWord(LToQWord(fLimbs));
end;

function UBigInt.toDouble: Double;
begin
  var bits := bitLength;
  if bits = 0 then exit(0.0);
  if bits <= 64 then exit(LToQWord(fLimbs));
  // top 64 bits with a sticky low bit, scaled by the dropped bit count
  var e := integer(bits) - 64;
  var q := LExtract64(fLimbs, LongWord(e));
  var limb := SizeInt(LongWord(e) shr LIMB_SHIFT);
  var off := integer(LongWord(e) and LIMB_MASK);
  var sticky := false;
  for var i := 0 to limb - 1 do
    if fLimbs[i] <> 0 then begin
      sticky := true;
      break;
    end;
  if (not sticky) and (off > 0) then sticky := fLimbs[limb] and ((TLimb(1) shl off) - 1) <> 0;
  if sticky then q := q or 1;
  result := ldexp(Double(q), e);
end;

function UBigInt.fitsInInt64: boolean;
begin
  result := (Length(fLimbs) <= LIMBS_PER_QWORD) and (LToQWord(fLimbs) <= QWord(High(Int64)));
end;

function UBigInt.fitsInQWord: boolean;
begin
  result := Length(fLimbs) <= LIMBS_PER_QWORD;
end;

function UBigInt.fitsInInteger: boolean;
begin
  result := (Length(fLimbs) <= 1) and (LToQWord(fLimbs) <= QWord(High(LongInt)));
end;

function UBigInt.fitsInCardinal: boolean;
begin
  result := (Length(fLimbs) <= 1) and (LToQWord(fLimbs) <= QWord(High(LongWord)));
end;

function UBigInt.isZero: boolean;
begin
  result := Length(fLimbs) = 0;
end;

function UBigInt.isOne: boolean;
begin
  result := (Length(fLimbs) = 1) and (fLimbs[0] = 1);
end;

function UBigInt.isEven: boolean;
begin
  result := (Length(fLimbs) = 0) or (fLimbs[0] and 1 = 0);
end;

function UBigInt.isOdd: boolean;
begin
  result := (Length(fLimbs) > 0) and (fLimbs[0] and 1 = 1);
end;

function UBigInt.isPowerOfTwo: boolean;
begin
  result := popCount = 1;
end;

function UBigInt.sign: integer;
begin
  result := if Length(fLimbs) = 0 then 0 else 1;
end;

function UBigInt.bitLength: LongWord;
begin
  result := LBitLen(fLimbs);
end;

function UBigInt.popCount: LongWord;
begin
  result := 0;
  for var i := 0 to Length(fLimbs) - 1 do result := result + PopCnt(fLimbs[i]);
end;

function UBigInt.lowestSetBit: Int64;
begin
  for var i := 0 to Length(fLimbs) - 1 do
    if fLimbs[i] <> 0 then exit(Int64(i) * LIMB_BITS + LimbBsf(fLimbs[i]));
  result := -1;
end;

function UBigInt.testBit(i: LongWord): boolean;
begin
  result := LTestBit(fLimbs, i);
end;

procedure UBigInt.setBit(i: LongWord);
begin
  var limb := SizeInt(i shr LIMB_SHIFT);
  SetLength(fLimbs, MaxS(Length(fLimbs), limb + 1)); // also un-shares the array
  fLimbs[limb] := fLimbs[limb] or (TLimb(1) shl (i and LIMB_MASK));
end;

procedure UBigInt.clearBit(i: LongWord);
begin
  var limb := SizeInt(i shr LIMB_SHIFT);
  if limb >= Length(fLimbs) then exit;
  SetLength(fLimbs, Length(fLimbs));
  fLimbs[limb] := fLimbs[limb] and not (TLimb(1) shl (i and LIMB_MASK));
  LNorm(fLimbs);
end;

procedure UBigInt.flipBit(i: LongWord);
begin
  var limb := SizeInt(i shr LIMB_SHIFT);
  SetLength(fLimbs, MaxS(Length(fLimbs), limb + 1));
  fLimbs[limb] := fLimbs[limb] xor (TLimb(1) shl (i and LIMB_MASK));
  LNorm(fLimbs);
end;

function UBigInt.complement(width: LongWord): UBigInt;
var
  res: TLimbs;
begin
  if width = 0 then exit(default(UBigInt));
  var n := SizeInt((QWord(width) + LIMB_MASK) shr LIMB_SHIFT);
  SetLength(res, n);
  for var i := 0 to n - 1 do res[i] := if i < Length(fLimbs) then not fLimbs[i] else High(TLimb);
  // mask off bits above width
  var topBits := integer(width and LIMB_MASK);
  if topBits <> 0 then res[n - 1] := res[n - 1] and (High(TLimb) shr (LIMB_BITS - topBits));
  LNorm(res);
  result.fLimbs := res;
end;

function UBigInt.getBitProp(i: LongWord): boolean;
begin
  result := testBit(i);
end;

procedure UBigInt.putBitProp(i: LongWord; v: boolean);
begin
  if v then setBit(i) else clearBit(i);
end;

function UBigInt.compare(const other: UBigInt): integer;
begin
  result := LCmp(fLimbs, other.fLimbs);
end;

function UBigInt.equals(const other: UBigInt): boolean;
begin
  result := LCmp(fLimbs, other.fLimbs) = 0;
end;

function UBigInt.min(const other: UBigInt): UBigInt;
begin
  result := if LCmp(fLimbs, other.fLimbs) <= 0 then self else other;
end;

function UBigInt.max(const other: UBigInt): UBigInt;
begin
  result := if LCmp(fLimbs, other.fLimbs) >= 0 then self else other;
end;

function UBigInt.divMod(const d: UBigInt): (q, r: UBigInt);
var
  qq, rr: UBigInt;
begin
  if Length(d.fLimbs) = 0 then RaiseDivByZero;
  LDivMod(fLimbs, d.fLimbs, qq.fLimbs, rr.fLimbs);
  exit(qq, rr);
end;

function UBigInt.ceilDiv(const d: UBigInt): UBigInt;
begin
  var (q, r) := divMod(d);
  result := if r.isZero then q else q + 1;
end;

procedure UBigInt.swap(var other: UBigInt);
begin
  SwapValues(fLimbs, other.fLimbs);
end;

class function UBigInt.parse(const s: string): UBigInt;
begin
  if not tryParse(s, result) then RaiseParseError(s);
end;

class function UBigInt.parse(const s: string; base: integer): UBigInt;
begin
  if not tryParse(s, base, result) then RaiseParseError(s);
end;

class function UBigInt.tryParse(const s: string; out v: UBigInt): boolean;
var
  neg: boolean;
begin
  result := TryParseLimbs(s, 0, v.fLimbs, neg);
  if result and neg and (Length(v.fLimbs) <> 0) then begin
    v.fLimbs := nil;
    result := false;
  end;
end;

class function UBigInt.tryParse(const s: string; base: integer; out v: UBigInt): boolean;
var
  neg: boolean;
begin
  if (base < 2) or (base > 36) then raise EBigIntError.Create($'invalid base {base}, expected 2..36');
  result := TryParseLimbs(s, base, v.fLimbs, neg);
  if result and neg and (Length(v.fLimbs) <> 0) then begin
    v.fLimbs := nil;
    result := false;
  end;
end;

// ---------------------------------------------------------------------------
// advanced math
// ---------------------------------------------------------------------------

function GroupDigits(const s: string; sep: char; group: integer): string;
begin
  if group <= 0 then exit(s);
  var start := if (s <> '') and (s[1] = '-') then 2 else 1;
  var digits := Length(s) - start + 1;
  if digits <= group then exit(s);
  var seps := (digits - 1) div group;
  SetLength(result, Length(s) + seps);
  var src := Length(s);
  var dst := Length(result);
  var run := 0;
  while src >= start do begin
    result[dst] := s[src];
    dec(src);
    dec(dst);
    inc(run);
    if (run = group) and (src >= start) then begin
      result[dst] := sep;
      dec(dst);
      run := 0;
    end;
  end;
  if start = 2 then result[1] := '-';
end;

function UBigInt.toBytesLE: TBytes;
var
  res: TBytes;
begin
  var n := SizeInt((QWord(bitLength) + 7) shr 3);
  SetLength(res, n);
  for var i := 0 to n - 1 do res[i] := byte(fLimbs[i shr BYTES_SHIFT] shr ((i and BYTES_MASK) * 8));
  result := res;
end;

function UBigInt.toBytesBE: TBytes;
var
  res: TBytes;
begin
  var n := SizeInt((QWord(bitLength) + 7) shr 3);
  SetLength(res, n);
  for var i := 0 to n - 1 do res[n - 1 - i] := byte(fLimbs[i shr BYTES_SHIFT] shr ((i and BYTES_MASK) * 8));
  result := res;
end;

class function UBigInt.fromBytesLE(const bytes: TBytes): UBigInt;
var
  res: TLimbs;
begin
  var n := Length(bytes);
  SetLength(res, (n + BYTES_MASK) shr BYTES_SHIFT);
  for var i := 0 to n - 1 do res[i shr BYTES_SHIFT] := res[i shr BYTES_SHIFT] or (TLimb(bytes[i]) shl ((i and BYTES_MASK) * 8));
  LNorm(res);
  result.fLimbs := res;
end;

class function UBigInt.fromBytesBE(const bytes: TBytes): UBigInt;
var
  res: TLimbs;
begin
  var n := Length(bytes);
  SetLength(res, (n + BYTES_MASK) shr BYTES_SHIFT);
  for var i := 0 to n - 1 do res[i shr BYTES_SHIFT] := res[i shr BYTES_SHIFT] or (TLimb(bytes[n - 1 - i]) shl ((i and BYTES_MASK) * 8));
  LNorm(res);
  result.fLimbs := res;
end;

function UBigInt.digitCount: LongWord;
begin
  result := LongWord(Length(LToBase(fLimbs, 10)));
end;

function UBigInt.toStringGrouped(sep: char; groupSize: integer): string;
begin
  result := GroupDigits(toString, sep, groupSize);
end;

function UBigInt.hashCode: DWord;
begin
  // FNV-1a over 32-bit chunks, identical result for either limb width
  result := 2166136261;
  for var i := 0 to Length(fLimbs) - 1 do begin
    result := (result xor DWord(fLimbs[i])) * 16777619;
    {$if LIMB_BITS = 64}
    result := (result xor DWord(fLimbs[i] shr 32)) * 16777619;
    {$endif}
  end;
end;

class function UBigInt.zero: UBigInt;
begin
  result := default(UBigInt);
end;

class function UBigInt.one: UBigInt;
begin
  result.fLimbs := LFromQWord(1);
end;

class function UBigInt.two: UBigInt;
begin
  result.fLimbs := LFromQWord(2);
end;

class function UBigInt.ten: UBigInt;
begin
  result.fLimbs := LFromQWord(10);
end;

class function UBigInt.pow2(n: LongWord): UBigInt;
begin
  result.fLimbs := LShl(LFromQWord(1), n);
end;

// ---------------------------------------------------------------------------
// random generators
// ---------------------------------------------------------------------------

var
  // deterministic nonzero defaults, so unseeded runs reproduce (like RandSeed = 0)
  xoshiroState: array[4] of QWord = ($01D353E5F3993BB0, $7B9C0DF6CB193B20, QWord($FDFCAA91110765B6), $2D24CBE0D19C4C17);
  pcgHi: QWord = $0DA3E39CB94B95BB;
  pcgLo: QWord = QWord($853C49E6748FEA9B);
  splitmixState: QWord = QWord($9E3779B97F4A7C15);

function SplitMix64(var s: QWord): QWord;
begin
  s := s + QWord($9E3779B97F4A7C15);
  var z := s;
  z := (z xor (z shr 30)) * QWord($BF58476D1CE4E5B9);
  z := (z xor (z shr 27)) * QWord($94D049BB133111EB);
  result := z xor (z shr 31);
end;

function RotL64(x: QWord; k: integer): QWord; inline;
begin
  result := (x shl k) or (x shr (64 - k));
end;

// xoshiro256** by Blackman/Vigna
function XoshiroNext: QWord;
begin
  result := RotL64(xoshiroState[1] * 5, 7) * 9;
  var t := xoshiroState[1] shl 17;
  xoshiroState[2] := xoshiroState[2] xor xoshiroState[0];
  xoshiroState[3] := xoshiroState[3] xor xoshiroState[1];
  xoshiroState[1] := xoshiroState[1] xor xoshiroState[2];
  xoshiroState[0] := xoshiroState[0] xor xoshiroState[3];
  xoshiroState[2] := xoshiroState[2] xor t;
  xoshiroState[3] := RotL64(xoshiroState[3], 45);
end;

// portable 64x64 -> 128 product (independent of the limb width)
procedure Mul64x64(a, b: QWord; out hi, lo: QWord);
begin
  var a0 := a and $FFFFFFFF;
  var a1 := a shr 32;
  var b0 := b and $FFFFFFFF;
  var b1 := b shr 32;
  var p00 := a0 * b0;
  var p10 := a1 * b0 + (p00 shr 32);
  var p01 := a0 * b1 + (p10 and $FFFFFFFF);
  hi := a1 * b1 + (p10 shr 32) + (p01 shr 32);
  lo := (p01 shl 32) or (p00 and $FFFFFFFF);
end;

// PCG XSL-RR 128/64 with the reference multiplier and stream
function PcgNext: QWord;
const
  mHi = QWord($2360ED051FC65DA4);
  mLo = QWord($4385DF649FCCF645);
  aHi = QWord($5851F42D4C957F2D);
  aLo = QWord($14057B7EF767814F);
begin
  var oldHi := pcgHi;
  var oldLo := pcgLo;
  // 128-bit state * mult + inc
  var hi, lo: QWord;
  Mul64x64(oldLo, mLo, hi, lo);
  hi := hi + oldHi * mLo + oldLo * mHi;
  var newLo := lo + aLo;
  if newLo < lo then inc(hi);
  pcgHi := hi + aHi;
  pcgLo := newLo;
  // output from the pre-advance state
  var rot := integer(oldHi shr 58);
  var x := oldHi xor oldLo;
  result := (x shr rot) or (x shl ((64 - rot) and 63));
end;

{$ifdef windows}
// RtlGenRandom, the loader-light OS entropy source
function SystemFunction036(buffer: Pointer; len: LongWord): ByteBool; stdcall; external 'advapi32' name 'SystemFunction036';
{$endif}

procedure OsEntropy(buf: PByte; len: SizeInt);
begin
  {$ifdef windows}
  if SystemFunction036(buf, LongWord(len)) then exit;
  {$else}
  var h := FileOpen('/dev/urandom', fmOpenRead);
  if h <> THandle(-1) then begin
    var got := FileRead(h, buf^, len);
    FileClose(h);
    if got = len then exit;
  end;
  {$endif}
  // last-resort fallback: time-mixed splitmix stream
  var s := QWord(GetTickCount64) xor (QWord(PtrUInt(buf)) shl 24);
  for var i := 0 to len - 1 do buf[i] := byte(SplitMix64(s) shr 13);
end;

function OsEntropy64: QWord;
begin
  OsEntropy(@result, SizeOf(result));
end;

procedure BigIntRandomSeed(seed: QWord);
begin
  splitmixState := seed;
  var s := seed;
  for var i := 0 to 3 do xoshiroState[i] := SplitMix64(s);
  // xoshiro must never sit in the all-zero state
  if (xoshiroState[0] or xoshiroState[1] or xoshiroState[2] or xoshiroState[3]) = 0 then xoshiroState[0] := QWord($9E3779B97F4A7C15);
  pcgLo := SplitMix64(s);
  pcgHi := SplitMix64(s);
  RandSeed := LongInt(seed xor (seed shr 32));
end;

procedure BigIntRandomize;
begin
  BigIntRandomSeed(OsEntropy64);
end;

function RngNext64: QWord;
begin
  result := case BigIntRngAlgo of
    rngPcg64: PcgNext;
    rngSplitMix64: SplitMix64(splitmixState);
    rngOS: OsEntropy64;
  else XoshiroNext;
end;

// one limb of bits from the selected generator
function RandomLimb: TLimb;
begin
  if BigIntRngAlgo = rngSystem then begin
    // the historical System.Random layout: 16-bit pieces, low half first
    result := (TLimb(System.Random($10000)) shl 16) or TLimb(System.Random($10000));
    {$if LIMB_BITS = 64}
    result := result or (((TLimb(System.Random($10000)) shl 16) or TLimb(System.Random($10000))) shl 32);
    {$endif}
    exit;
  end;
  result := TLimb(RngNext64);
end;

class function UBigInt.random(bits: LongWord): UBigInt;
var
  res: TLimbs;
begin
  if bits = 0 then exit(default(UBigInt));
  var n := SizeInt((QWord(bits) + LIMB_MASK) shr LIMB_SHIFT);
  SetLength(res, n);
  for var i := 0 to n - 1 do res[i] := RandomLimb;
  var top := bits and LIMB_MASK;
  if top <> 0 then res[n - 1] := res[n - 1] and (High(TLimb) shr (LIMB_BITS - top));
  LNorm(res);
  result.fLimbs := res;
end;

class function UBigInt.randomBelow(const bound: UBigInt): UBigInt;
begin
  if bound.isZero then raise EBigIntError.Create('randomBelow needs a positive bound');
  // rejection sampling: below two expected draws
  var bits := bound.bitLength;
  repeat
    result := random(bits);
  until result < bound;
end;

class function UBigInt.randomRange(const lo, hi: UBigInt): UBigInt;
begin
  if lo > hi then raise EBigIntError.Create('randomRange needs lo <= hi');
  result := lo + randomBelow(hi - lo + 1);
end;

// ---------------------------------------------------------------------------
// BigInt
// ---------------------------------------------------------------------------

function LPopCount(const a: TLimbs): LongWord;
begin
  result := 0;
  for var i := 0 to Length(a) - 1 do result := result + PopCnt(a[i]);
end;

function BFromI64(x: Int64): BigInt;
begin
  if x >= 0 then begin
    result.fLimbs := LFromQWord(QWord(x));
    result.fNeg := false;
  end else begin
    result.fLimbs := LFromQWord(NegAbs64(x));
    result.fNeg := true;
  end;
end;

// signed add of two sign/magnitude pairs
function SAddPair(const am: TLimbs; an: boolean; const bm: TLimbs; bn: boolean): BigInt;
var
  m: TLimbs;
begin
  if an = bn then begin
    m := LAdd(am, bm);
    result.fLimbs := m;
    result.fNeg := an and (Length(m) > 0);
    exit;
  end;
  var c := LCmp(am, bm);
  if c = 0 then exit(default(BigInt));
  if c > 0 then begin
    m := LSub(am, bm);
    result.fLimbs := m;
    result.fNeg := an;
  end else begin
    m := LSub(bm, am);
    result.fLimbs := m;
    result.fNeg := bn;
  end;
end;

function SMulPair(const am: TLimbs; an: boolean; const bm: TLimbs; bn: boolean): BigInt;
var
  m: TLimbs;
begin
  m := LMul(am, bm);
  result.fLimbs := m;
  result.fNeg := (an xor bn) and (Length(m) > 0);
end;

// truncated division: quotient toward zero, remainder takes the dividend sign
procedure SDivModPair(const am: TLimbs; an: boolean; const bm: TLimbs; bn: boolean; out q, r: BigInt);
var
  qm, rm: TLimbs;
begin
  LDivMod(am, bm, qm, rm);
  q.fLimbs := qm;
  q.fNeg := (an xor bn) and (Length(qm) > 0);
  r.fLimbs := rm;
  r.fNeg := an and (Length(rm) > 0);
end;

function BCmp(const a, b: BigInt): integer;
begin
  if a.fNeg <> b.fNeg then exit(if a.fNeg then -1 else 1);
  var c := LCmp(a.fLimbs, b.fLimbs);
  result := if a.fNeg then -c else c;
end;

function BCmpI64(const a: BigInt; v: Int64): integer;
begin
  var sa := if Length(a.fLimbs) = 0 then 0 else if a.fNeg then -1 else 1;
  var sv := if v > 0 then 1 else if v < 0 then -1 else 0;
  if sa <> sv then exit(if sa < sv then -1 else 1);
  if sa = 0 then exit(0);
  var c := LCmpQ(a.fLimbs, if v > 0 then QWord(v) else NegAbs64(v));
  result := if sa < 0 then -c else c;
end;

// lowest nonzero limb index, -1 for zero
function LLowestNZ(const m: TLimbs): SizeInt;
begin
  for var i := 0 to Length(m) - 1 do
    if m[i] <> 0 then exit(i);
  result := -1;
end;

// i-th limb of the infinite two's complement form of (m, neg)
function TCLimbAt(const m: TLimbs; neg: boolean; lowNZ, i: SizeInt): TLimb; inline;
begin
  if not neg then result := if i < Length(m) then m[i] else 0
  else if i < lowNZ then result := 0
  else if i = lowNZ then result := (not m[i]) + 1
  else if i < Length(m) then result := not m[i]
  else result := High(TLimb);
end;

// negate a two's complement limb array in place (not + 1): limbs below the
// lowest nonzero one stay zero, that one negates, everything above inverts
procedure LTCNegateInPlace(var a: TLimbs);
begin
  var i := 0;
  while (i < Length(a)) and (a[i] = 0) do inc(i);
  if i >= Length(a) then exit;
  a[i] := TLimb(0) - a[i];
  for var j := i + 1 to Length(a) - 1 do a[j] := not a[j];
end;

type
  TBitOp = (boAnd, boOr, boXor);

function BBitOp(const a, b: BigInt; op: TBitOp): BigInt;
var
  res: TLimbs;
begin
  var la := Length(a.fLimbs);
  var lb := Length(b.fLimbs);
  // one limb above both operands captures the sign extension
  var n := MaxS(la, lb) + 1;
  var lowA := LLowestNZ(a.fLimbs);
  var lowB := LLowestNZ(b.fLimbs);
  SetLength(res, n);
  for var i := 0 to n - 1 do begin
    var x := TCLimbAt(a.fLimbs, a.fNeg, lowA, i);
    var y := TCLimbAt(b.fLimbs, b.fNeg, lowB, i);
    res[i] := case op of
      boAnd: x and y;
      boOr: x or y;
      boXor: x xor y;
    end;
  end;
  // the top limb came out either all zeros or all ones
  var neg := res[n - 1] <> 0;
  if neg then LTCNegateInPlace(res);
  LNorm(res);
  result.fLimbs := res;
  result.fNeg := neg and (Length(res) > 0);
end;

// any nonzero bit among the n lowest bits (the bits a shr n drops)
function LAnyDroppedBits(const a: TLimbs; n: LongWord): boolean;
begin
  var limbShift := SizeInt(n shr LIMB_SHIFT);
  var bitShift := n and LIMB_MASK;
  for var i := 0 to MinS(limbShift, Length(a)) - 1 do
    if a[i] <> 0 then exit(true);
  if (bitShift > 0) and (limbShift < Length(a)) then exit(a[limbShift] and ((TLimb(1) shl bitShift) - 1) <> 0);
  result := false;
end;

class operator BigInt.:=(x: Int64): BigInt;
begin
  result := BFromI64(x);
end;

class operator BigInt.:=(x: QWord): BigInt;
begin
  result.fLimbs := LFromQWord(x);
  result.fNeg := false;
end;

class operator BigInt.:=(const s: string): BigInt;
begin
  result := BigInt.parse(s);
end;

class operator BigInt.:=(const u: UBigInt): BigInt;
begin
  result.fLimbs := u.fLimbs;
  result.fNeg := false;
end;

class operator BigInt.explicit(d: Double): BigInt;
var
  u: UBigInt;
begin
  if IsNan(d) or IsInfinite(d) then raise EConvertError.Create('cannot convert NaN or Inf to BigInt');
  if d < 0 then begin
    u := UBigInt(-d);
    result.fLimbs := u.fLimbs;
    result.fNeg := Length(u.fLimbs) > 0;
  end else begin
    u := UBigInt(d);
    result.fLimbs := u.fLimbs;
    result.fNeg := false;
  end;
end;

class operator BigInt.explicit(x: Int64): BigInt;
begin
  result := BFromI64(x);
end;

class operator BigInt.explicit(x: QWord): BigInt;
begin
  result.fLimbs := LFromQWord(x);
  result.fNeg := false;
end;

class operator BigInt.explicit(const a: BigInt): Int64;
begin
  result := a.toInt64;
end;

class operator BigInt.explicit(const a: BigInt): QWord;
begin
  result := a.toQWord;
end;

class operator BigInt.explicit(const a: BigInt): LongInt;
begin
  result := a.toInteger;
end;

class operator BigInt.explicit(const a: BigInt): LongWord;
begin
  result := a.toCardinal;
end;

class operator BigInt.explicit(const a: BigInt): Double;
begin
  result := a.toDouble;
end;

class operator BigInt.explicit(const a: BigInt): string;
begin
  result := a.toString;
end;

class operator BigInt.explicit(const a: BigInt): UBigInt;
begin
  result := a.toUBigInt;
end;

class operator BigInt.+(const a, b: BigInt): BigInt;
begin
  result := SAddPair(a.fLimbs, a.fNeg, b.fLimbs, b.fNeg);
end;

class operator BigInt.+(const a: BigInt; b: Int64): BigInt;
begin
  result := SAddPair(a.fLimbs, a.fNeg, LFromQWord(if b >= 0 then QWord(b) else NegAbs64(b)), b < 0);
end;

class operator BigInt.+(a: Int64; const b: BigInt): BigInt;
begin
  result := b + a;
end;

class operator BigInt.-(const a, b: BigInt): BigInt;
begin
  result := SAddPair(a.fLimbs, a.fNeg, b.fLimbs, not b.fNeg);
end;

class operator BigInt.-(const a: BigInt; b: Int64): BigInt;
begin
  result := SAddPair(a.fLimbs, a.fNeg, LFromQWord(if b >= 0 then QWord(b) else NegAbs64(b)), b >= 0);
end;

class operator BigInt.-(a: Int64; const b: BigInt): BigInt;
begin
  result := SAddPair(LFromQWord(if a >= 0 then QWord(a) else NegAbs64(a)), a < 0, b.fLimbs, not b.fNeg);
end;

class operator BigInt.*(const a, b: BigInt): BigInt;
begin
  result := SMulPair(a.fLimbs, a.fNeg, b.fLimbs, b.fNeg);
end;

class operator BigInt.*(const a: BigInt; b: Int64): BigInt;
begin
  result := SMulPair(a.fLimbs, a.fNeg, LFromQWord(if b >= 0 then QWord(b) else NegAbs64(b)), b < 0);
end;

class operator BigInt.*(a: Int64; const b: BigInt): BigInt;
begin
  result := b * a;
end;

class operator BigInt.div(const a, b: BigInt): BigInt;
var
  q, r: BigInt;
begin
  if Length(b.fLimbs) = 0 then RaiseDivByZero;
  SDivModPair(a.fLimbs, a.fNeg, b.fLimbs, b.fNeg, q, r);
  result := q;
end;

class operator BigInt.div(const a: BigInt; b: Int64): BigInt;
begin
  result := a div BFromI64(b);
end;

class operator BigInt.mod(const a, b: BigInt): BigInt;
var
  q, r: BigInt;
begin
  if Length(b.fLimbs) = 0 then RaiseDivByZero;
  SDivModPair(a.fLimbs, a.fNeg, b.fLimbs, b.fNeg, q, r);
  result := r;
end;

class operator BigInt.mod(const a: BigInt; b: Int64): BigInt;
begin
  result := a mod BFromI64(b);
end;

class operator BigInt./(const a, b: BigInt): BigInt;
begin
  result := a div b;
end;

class operator BigInt.**(const a, b: BigInt): BigInt;
var
  m: TLimbs;
begin
  if b.fNeg then raise EBigIntError.Create('negative exponent for integer power');
  if Length(b.fLimbs) = 0 then begin
    result.fLimbs := LFromQWord(1);
    result.fNeg := false;
    exit;
  end;
  if Length(a.fLimbs) = 0 then exit(default(BigInt));
  m := UPowQ(a.fLimbs, b.toQWord);
  result.fLimbs := m;
  result.fNeg := a.fNeg and (b.fLimbs[0] and 1 = 1);
end;

class operator BigInt.**(const a: BigInt; e: Int64): BigInt;
var
  m: TLimbs;
begin
  if e < 0 then raise EBigIntError.Create('negative exponent for integer power');
  if e = 0 then begin
    result.fLimbs := LFromQWord(1);
    result.fNeg := false;
    exit;
  end;
  if Length(a.fLimbs) = 0 then exit(default(BigInt));
  m := UPowQ(a.fLimbs, QWord(e));
  result.fLimbs := m;
  result.fNeg := a.fNeg and (e and 1 = 1);
end;

class operator BigInt.inc(const a: BigInt): BigInt;
begin
  result := a + 1;
end;

class operator BigInt.dec(const a: BigInt): BigInt;
begin
  result := a - 1;
end;

class operator BigInt.-(const a: BigInt): BigInt;
begin
  result.fLimbs := a.fLimbs;
  result.fNeg := (not a.fNeg) and (Length(a.fLimbs) > 0);
end;

class operator BigInt.+(const a: BigInt): BigInt;
begin
  result := a;
end;

class operator BigInt.shl(const a: BigInt; n: Int64): BigInt;
var
  m: TLimbs;
begin
  if n < 0 then raise ERangeError.Create('negative shift count');
  if Length(a.fLimbs) = 0 then exit(default(BigInt));
  if n > High(LongWord) then raise EBigIntError.Create('shift count out of range');
  m := LShl(a.fLimbs, LongWord(n));
  result.fLimbs := m;
  result.fNeg := a.fNeg;
end;

class operator BigInt.shr(const a: BigInt; n: Int64): BigInt;
var
  m: TLimbs;
begin
  if n < 0 then raise ERangeError.Create('negative shift count');
  if Length(a.fLimbs) = 0 then exit(default(BigInt));
  if not a.fNeg then begin
    if n > High(LongWord) then exit(default(BigInt));
    m := LShr(a.fLimbs, LongWord(n));
    result.fLimbs := m;
    result.fNeg := false;
    exit;
  end;
  // negative: arithmetic shift rounds toward -infinity
  if n > High(LongWord) then begin
    result.fLimbs := LFromQWord(1);
    result.fNeg := true;
    exit;
  end;
  m := LShr(a.fLimbs, LongWord(n));
  if LAnyDroppedBits(a.fLimbs, LongWord(n)) then m := LAdd(m, LFromQWord(1));
  result.fLimbs := m;
  result.fNeg := Length(m) > 0;
end;

class operator BigInt.and(const a, b: BigInt): BigInt;
begin
  result := BBitOp(a, b, boAnd);
end;

class operator BigInt.or(const a, b: BigInt): BigInt;
begin
  result := BBitOp(a, b, boOr);
end;

class operator BigInt.xor(const a, b: BigInt): BigInt;
begin
  result := BBitOp(a, b, boXor);
end;

class operator BigInt.not(const a: BigInt): BigInt;
var
  m: TLimbs;
begin
  if a.fNeg then begin
    // not(-m) = m - 1
    m := LSub(a.fLimbs, LFromQWord(1));
    result.fLimbs := m;
    result.fNeg := false;
  end else begin
    // not(m) = -(m + 1)
    m := LAdd(a.fLimbs, LFromQWord(1));
    result.fLimbs := m;
    result.fNeg := true;
  end;
end;

class operator BigInt.=(const a, b: BigInt): boolean;
begin
  result := BCmp(a, b) = 0;
end;

class operator BigInt.=(const a: BigInt; b: Int64): boolean;
begin
  result := BCmpI64(a, b) = 0;
end;

class operator BigInt.=(a: Int64; const b: BigInt): boolean;
begin
  result := BCmpI64(b, a) = 0;
end;

class operator BigInt.<>(const a, b: BigInt): boolean;
begin
  result := BCmp(a, b) <> 0;
end;

class operator BigInt.<>(const a: BigInt; b: Int64): boolean;
begin
  result := BCmpI64(a, b) <> 0;
end;

class operator BigInt.<>(a: Int64; const b: BigInt): boolean;
begin
  result := BCmpI64(b, a) <> 0;
end;

class operator BigInt.<(const a, b: BigInt): boolean;
begin
  result := BCmp(a, b) < 0;
end;

class operator BigInt.<(const a: BigInt; b: Int64): boolean;
begin
  result := BCmpI64(a, b) < 0;
end;

class operator BigInt.<(a: Int64; const b: BigInt): boolean;
begin
  result := BCmpI64(b, a) > 0;
end;

class operator BigInt.<=(const a, b: BigInt): boolean;
begin
  result := BCmp(a, b) <= 0;
end;

class operator BigInt.<=(const a: BigInt; b: Int64): boolean;
begin
  result := BCmpI64(a, b) <= 0;
end;

class operator BigInt.<=(a: Int64; const b: BigInt): boolean;
begin
  result := BCmpI64(b, a) >= 0;
end;

class operator BigInt.>(const a, b: BigInt): boolean;
begin
  result := BCmp(a, b) > 0;
end;

class operator BigInt.>(const a: BigInt; b: Int64): boolean;
begin
  result := BCmpI64(a, b) > 0;
end;

class operator BigInt.>(a: Int64; const b: BigInt): boolean;
begin
  result := BCmpI64(b, a) < 0;
end;

class operator BigInt.>=(const a, b: BigInt): boolean;
begin
  result := BCmp(a, b) >= 0;
end;

class operator BigInt.>=(const a: BigInt; b: Int64): boolean;
begin
  result := BCmpI64(a, b) >= 0;
end;

class operator BigInt.>=(a: Int64; const b: BigInt): boolean;
begin
  result := BCmpI64(b, a) <= 0;
end;

function BigInt.toString: string;
begin
  result := if fNeg then '-' + LToBase(fLimbs, 10) else LToBase(fLimbs, 10);
end;

function BigInt.toString(base: integer): string;
begin
  if (base < 2) or (base > 36) then raise EBigIntError.Create($'invalid base {base}, expected 2..36');
  result := if fNeg then '-' + LToBase(fLimbs, base) else LToBase(fLimbs, base);
end;

function BigInt.toHex: string;
begin
  result := toString(16);
end;

function BigInt.toBin: string;
begin
  result := toString(2);
end;

function BigInt.toOct: string;
begin
  result := toString(8);
end;

function BigInt.toInt64: Int64;
begin
  if not fitsInInt64 then raise ERangeError.Create('BigInt value does not fit in Int64');
  var q := LToQWord(fLimbs);
  result := if fNeg then Int64((not q) + 1) else Int64(q);
end;

function BigInt.toQWord: QWord;
begin
  if not fitsInQWord then raise ERangeError.Create('BigInt value does not fit in QWord');
  result := LToQWord(fLimbs);
end;

function BigInt.toInteger: LongInt;
begin
  if not fitsInInteger then raise ERangeError.Create('BigInt value does not fit in Integer');
  result := LongInt(toInt64);
end;

function BigInt.toCardinal: LongWord;
begin
  if not fitsInCardinal then raise ERangeError.Create('BigInt value does not fit in Cardinal');
  result := LongWord(LToQWord(fLimbs));
end;

function BigInt.toDouble: Double;
begin
  result := magnitude.toDouble;
  if fNeg then result := -result;
end;

function BigInt.toUBigInt: UBigInt;
begin
  if fNeg then RaiseNegativeUnsigned;
  result.fLimbs := fLimbs;
end;

function BigInt.fitsInInt64: boolean;
begin
  if Length(fLimbs) > LIMBS_PER_QWORD then exit(false);
  var q := LToQWord(fLimbs);
  result := if fNeg then q <= QWord($8000000000000000) else q <= QWord(High(Int64));
end;

function BigInt.fitsInQWord: boolean;
begin
  result := (not fNeg) and (Length(fLimbs) <= LIMBS_PER_QWORD);
end;

function BigInt.fitsInInteger: boolean;
begin
  if Length(fLimbs) > 1 then exit(false);
  var q := LToQWord(fLimbs);
  result := if fNeg then q <= QWord($80000000) else q <= QWord(High(LongInt));
end;

function BigInt.fitsInCardinal: boolean;
begin
  result := (not fNeg) and (Length(fLimbs) <= 1) and (LToQWord(fLimbs) <= QWord(High(LongWord)));
end;

function BigInt.isZero: boolean;
begin
  result := Length(fLimbs) = 0;
end;

function BigInt.isOne: boolean;
begin
  result := (not fNeg) and (Length(fLimbs) = 1) and (fLimbs[0] = 1);
end;

function BigInt.isEven: boolean;
begin
  result := (Length(fLimbs) = 0) or (fLimbs[0] and 1 = 0);
end;

function BigInt.isOdd: boolean;
begin
  result := (Length(fLimbs) > 0) and (fLimbs[0] and 1 = 1);
end;

function BigInt.isNegative: boolean;
begin
  result := fNeg;
end;

function BigInt.isPositive: boolean;
begin
  result := (not fNeg) and (Length(fLimbs) > 0);
end;

function BigInt.isPowerOfTwo: boolean;
begin
  result := (not fNeg) and (LPopCount(fLimbs) = 1);
end;

function BigInt.sign: integer;
begin
  result := if Length(fLimbs) = 0 then 0 else if fNeg then -1 else 1;
end;

function BigInt.abs: BigInt;
begin
  result.fLimbs := fLimbs;
  result.fNeg := false;
end;

function BigInt.magnitude: UBigInt;
begin
  result.fLimbs := fLimbs;
end;

procedure BigInt.negate;
begin
  if Length(fLimbs) > 0 then fNeg := not fNeg;
end;

function BigInt.bitLength: LongWord;
begin
  result := LBitLen(fLimbs);
  // for negatives the minimal two's complement form of -2^k needs one bit less
  if fNeg and (LPopCount(fLimbs) = 1) then dec(result);
end;

function BigInt.popCount: LongWord;
begin
  // for negatives: bits that differ from the (one) sign bit, like Java bitCount
  result := if fNeg then LPopCount(LSub(fLimbs, LFromQWord(1))) else LPopCount(fLimbs);
end;

function BigInt.lowestSetBit: Int64;
begin
  // two's complement negation keeps the lowest set bit in place
  for var i := 0 to Length(fLimbs) - 1 do
    if fLimbs[i] <> 0 then exit(Int64(i) * LIMB_BITS + LimbBsf(fLimbs[i]));
  result := -1;
end;

function BigInt.testBit(i: LongWord): boolean;
begin
  if not fNeg then exit(LTestBit(fLimbs, i));
  var v := TCLimbAt(fLimbs, true, LLowestNZ(fLimbs), SizeInt(i shr LIMB_SHIFT));
  result := (v shr (i and LIMB_MASK)) and 1 <> 0;
end;

procedure BigInt.setBit(i: LongWord);
begin
  if not fNeg then begin
    var limb := SizeInt(i shr LIMB_SHIFT);
    SetLength(fLimbs, MaxS(Length(fLimbs), limb + 1)); // also un-shares the array
    fLimbs[limb] := fLimbs[limb] or (TLimb(1) shl (i and LIMB_MASK));
  end else self := self or (BigInt(1) shl i);
end;

procedure BigInt.clearBit(i: LongWord);
begin
  if not fNeg then begin
    var limb := SizeInt(i shr LIMB_SHIFT);
    if limb >= Length(fLimbs) then exit;
    SetLength(fLimbs, Length(fLimbs));
    fLimbs[limb] := fLimbs[limb] and not (TLimb(1) shl (i and LIMB_MASK));
    LNorm(fLimbs);
  end else self := self and not (BigInt(1) shl i);
end;

procedure BigInt.flipBit(i: LongWord);
begin
  if not fNeg then begin
    var limb := SizeInt(i shr LIMB_SHIFT);
    SetLength(fLimbs, MaxS(Length(fLimbs), limb + 1));
    fLimbs[limb] := fLimbs[limb] xor (TLimb(1) shl (i and LIMB_MASK));
    LNorm(fLimbs);
  end else self := self xor (BigInt(1) shl i);
end;

function BigInt.getBitProp(i: LongWord): boolean;
begin
  result := testBit(i);
end;

procedure BigInt.putBitProp(i: LongWord; v: boolean);
begin
  if v then setBit(i) else clearBit(i);
end;

function BigInt.compare(const other: BigInt): integer;
begin
  result := BCmp(self, other);
end;

function BigInt.equals(const other: BigInt): boolean;
begin
  result := BCmp(self, other) = 0;
end;

function BigInt.min(const other: BigInt): BigInt;
begin
  result := if BCmp(self, other) <= 0 then self else other;
end;

function BigInt.max(const other: BigInt): BigInt;
begin
  result := if BCmp(self, other) >= 0 then self else other;
end;

function BigInt.divMod(const d: BigInt): (q, r: BigInt);
var
  qq, rr: BigInt;
begin
  if Length(d.fLimbs) = 0 then RaiseDivByZero;
  SDivModPair(fLimbs, fNeg, d.fLimbs, d.fNeg, qq, rr);
  exit(qq, rr);
end;

function BigInt.floorDiv(const d: BigInt): BigInt;
begin
  var (q, r) := divMod(d);
  result := if r.isZero or (fNeg = d.fNeg) then q else q - 1;
end;

function BigInt.floorMod(const d: BigInt): BigInt;
begin
  var (q, r) := divMod(d);
  result := if r.isZero or (fNeg = d.fNeg) then r else r + d;
end;

function BigInt.ceilDiv(const d: BigInt): BigInt;
begin
  var (q, r) := divMod(d);
  result := if r.isZero or (fNeg <> d.fNeg) then q else q + 1;
end;

procedure BigInt.swap(var other: BigInt);
begin
  SwapValues(fLimbs, other.fLimbs);
  SwapValues(fNeg, other.fNeg);
end;

class function BigInt.parse(const s: string): BigInt;
begin
  if not tryParse(s, result) then RaiseParseError(s);
end;

class function BigInt.parse(const s: string; base: integer): BigInt;
begin
  if not tryParse(s, base, result) then RaiseParseError(s);
end;

class function BigInt.tryParse(const s: string; out v: BigInt): boolean;
var
  neg: boolean;
begin
  result := TryParseLimbs(s, 0, v.fLimbs, neg);
  v.fNeg := result and neg and (Length(v.fLimbs) <> 0);
end;

class function BigInt.tryParse(const s: string; base: integer; out v: BigInt): boolean;
var
  neg: boolean;
begin
  if (base < 2) or (base > 36) then raise EBigIntError.Create($'invalid base {base}, expected 2..36');
  result := TryParseLimbs(s, base, v.fLimbs, neg);
  v.fNeg := result and neg and (Length(v.fLimbs) <> 0);
end;

function TUBigIntBridge.toBigInt: BigInt;
begin
  result.fLimbs := fLimbs;
  result.fNeg := false;
end;

function BigInt.toBytesLE: TBytes;
var
  res: TBytes;
begin
  // minimal two's complement including the sign bit
  var n := SizeInt(bitLength div 8) + 1;
  SetLength(res, n);
  var low := LLowestNZ(fLimbs);
  for var i := 0 to n - 1 do res[i] := byte(TCLimbAt(fLimbs, fNeg, low, i shr BYTES_SHIFT) shr ((i and BYTES_MASK) * 8));
  result := res;
end;

function BigInt.toBytesBE: TBytes;
begin
  result := toBytesLE;
  for var i := 0 to (Length(result) shr 1) - 1 do SwapValues(result[i], result[High(result) - i]);
end;

class function BigInt.fromBytesLE(const bytes: TBytes): BigInt;
var
  res: TLimbs;
begin
  var n := Length(bytes);
  if n = 0 then exit(default(BigInt));
  var neg := bytes[n - 1] >= $80;
  var limbCount := (n + BYTES_MASK) shr BYTES_SHIFT;
  SetLength(res, limbCount);
  // sign-extend the incomplete top limb (a full top limb gets all its bytes)
  if neg and (n and BYTES_MASK <> 0) then res[limbCount - 1] := High(TLimb) shl ((n and BYTES_MASK) * 8);
  for var i := 0 to n - 1 do res[i shr BYTES_SHIFT] := res[i shr BYTES_SHIFT] or (TLimb(bytes[i]) shl ((i and BYTES_MASK) * 8));
  if neg then LTCNegateInPlace(res);
  LNorm(res);
  result.fLimbs := res;
  result.fNeg := neg and (Length(res) > 0);
end;

class function BigInt.fromBytesBE(const bytes: TBytes): BigInt;
var
  tmp: TBytes;
begin
  tmp := Copy(bytes);
  for var i := 0 to (Length(tmp) shr 1) - 1 do SwapValues(tmp[i], tmp[High(tmp) - i]);
  result := fromBytesLE(tmp);
end;

function BigInt.digitCount: LongWord;
begin
  result := LongWord(Length(LToBase(fLimbs, 10)));
end;

function BigInt.toStringGrouped(sep: char; groupSize: integer): string;
begin
  result := GroupDigits(toString, sep, groupSize);
end;

function BigInt.hashCode: DWord;
begin
  result := magnitude.hashCode;
  if fNeg then result := not result;
end;

class function BigInt.zero: BigInt;
begin
  result := default(BigInt);
end;

class function BigInt.one: BigInt;
begin
  result.fLimbs := LFromQWord(1);
  result.fNeg := false;
end;

class function BigInt.two: BigInt;
begin
  result.fLimbs := LFromQWord(2);
  result.fNeg := false;
end;

class function BigInt.ten: BigInt;
begin
  result.fLimbs := LFromQWord(10);
  result.fNeg := false;
end;

class function BigInt.minusOne: BigInt;
begin
  result.fLimbs := LFromQWord(1);
  result.fNeg := true;
end;

class function BigInt.pow2(n: LongWord): BigInt;
begin
  result.fLimbs := LShl(LFromQWord(1), n);
  result.fNeg := false;
end;

class function BigInt.random(bits: LongWord): BigInt;
begin
  result := UBigInt.random(bits).toBigInt;
end;

class function BigInt.randomBelow(const bound: BigInt): BigInt;
begin
  if bound.sign <= 0 then raise EBigIntError.Create('randomBelow needs a positive bound');
  result := UBigInt.randomBelow(bound.toUBigInt).toBigInt;
end;

class function BigInt.randomRange(const lo, hi: BigInt): BigInt;
begin
  if lo > hi then raise EBigIntError.Create('randomRange needs lo <= hi');
  result := lo + UBigInt.randomBelow((hi - lo + 1).toUBigInt).toBigInt;
end;

{$ifdef BIGINT_ASM}
initialization
  UseAdx := CpuHasAdx;
{$endif}
end.
