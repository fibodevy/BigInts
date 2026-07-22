{ BigInts - arbitrary precision integers for Unleashed Pascal

 Three value types with full operator coverage and no size limit:
   UBigInt - unsigned big integer (raises ERangeError on negative results)
   BigInt  - signed big integer, two's complement semantics for bitwise ops
   BigDecimal - decimal float over the same core: BigInt mantissa * 10^exp }

{ Copyright (c) 2026 @fibodevy / https://github.com/fibodevy
  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/ }

unit BigInts;

{$mode unleashed}

// asm inner loops on x86_64; comment out to build the fully portable pure
// Pascal core (64-bit limbs when the compiler provides a native UInt128 on a
// 64-bit CPU, 32-bit limbs otherwise)
{$define USEASM}

{$if defined(CPUX86_64) and defined(USEASM)}{$define BIGINT_ASM}{$endif}
{$if defined(CPU386) and defined(USEASM)}{$define BIGINT_ASM32}{$endif}

// limb arithmetic relies on modular 32-bit/64-bit wraparound
{$q-}{$r-}

// dynamic array locals are nil-initialized by the compiler and tuple
// destructuring discards are intentional; these flow hints are noise here
{$warn 5089 off}{$warn 5091 off}{$warn 5092 off}{$warn 5093 off}{$warn 5094 off}{$warn 5027 off}

interface

// native UInt128 (compilers that provide it): double-limb products and
// the PCG64 state advance become single inline multiplies instead of calls
// (declared() only resolves system types from the interface part on)
// BIGINT_HAS_INT128 gates the public Int128/UInt128 conversions (they need
// only the type); BIGINT_INT128 additionally requires a 64-bit CPU and drives
// the inline double-limb product and PCG64 advance; BIGINT_PP128 marks the
// pure Pascal build that still gets 64-bit limbs, with UInt128 double-limb
// temps in the portable kernels
{$if declared(UInt128)}{$define BIGINT_HAS_INT128}{$if defined(CPU64)}{$define BIGINT_INT128}{$endif}{$endif}
{$if defined(BIGINT_INT128) and not defined(BIGINT_ASM)}{$define BIGINT_PP128}{$endif}
{$if defined(BIGINT_ASM) or defined(BIGINT_PP128)}{$define BIGINT_LIMB64}{$endif}

uses SysUtils;

type
  // raised for domain errors: negative exponent, no modular inverse, ...
  // (div by zero raises EDivByZero, overflows in conversions raise ERangeError,
  // parse errors raise EConvertError - same classes plain integers use)
  EBigIntError = class(Exception);

  // generator behind random/randomBelow/randomRange/randomPrime; rngSystem is
  // the RandSeed-driven System.Random stream, rngOS reads OS entropy per call
  TBigIntRngAlgo = (rngXoshiro256ss, rngPcg64, rngSplitMix64, rngSystem, rngOS);

  // internal storage: little-endian array of limbs (64-bit on 64-bit CPUs,
  // 32-bit elsewhere), highest limb nonzero, nil = 0
  {$ifdef BIGINT_LIMB64}
  TBigIntLimb = QWord;
  {$else}
  TBigIntLimb = DWord;
  {$endif}
  TBigIntLimbs = array of TBigIntLimb;
  PBigIntLimb = ^TBigIntLimb;

const
  // values up to this many limbs (256 bits) live inline in the record with no
  // heap allocation; larger ones spill into a refcounted block. tunable
  {$ifdef BIGINT_LIMB64}
  BIGINT_INLINE_LIMBS = 4;
  {$else}
  BIGINT_INLINE_LIMBS = 8;
  {$endif}

type
  { UBigInt - unsigned arbitrary precision integer }

  UBigInt = record
  private
    // small-value optimization: up to BIGINT_INLINE_LIMBS limbs sit inline
    // with no allocation, larger values spill into the fArr limb array (nil =
    // value lives inline); fLen is the significant limb count (0 = zero,
    // highest limb nonzero). fLimbs is a property view over either storage:
    // for spilled values it shares fArr with no copy, so large-value paths
    // cost the same as a plain limb-array field, while small values never
    // touch the heap. fArr is compiler-managed (refcounted dynarray)
    fInline: array[0..BIGINT_INLINE_LIMBS - 1] of TBigIntLimb;
    fArr: TBigIntLimbs;
    fLen: SizeInt;
    function dataPtr: PBigIntLimb; inline;
    function getLimbs: TBigIntLimbs;
    procedure setLimbs(const v: TBigIntLimbs);
    function getBitProp(i: LongWord): boolean; inline;
    procedure putBitProp(i: LongWord; v: boolean); inline;
    property fLimbs: TBigIntLimbs read getLimbs write setLimbs;
  public
    // fArr is a managed field, so copy/addref/finalize are compiler-default;
    // Initialize only zeroes the plain fields the compiler would leave alone
    class operator Initialize(var x: UBigInt);
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
    function toInt8: Int8;
    function toUInt8: UInt8;
    function toInt16: Int16;
    function toUInt16: UInt16;
    function toInt32: Int32;
    function toUInt32: UInt32;
    function toInt64: Int64;
    function toUInt64: UInt64;
    {$ifdef BIGINT_HAS_INT128}
    function toInt128: Int128;
    function toUInt128: UInt128;
    {$endif}
    function toDouble: Double;
    // does the value fit in each native integer width
    function fitsInInt8: boolean;
    function fitsInUInt8: boolean;
    function fitsInInt16: boolean;
    function fitsInUInt16: boolean;
    function fitsInInt32: boolean;
    function fitsInUInt32: boolean;
    function fitsInInt64: boolean;
    function fitsInUInt64: boolean;
    {$ifdef BIGINT_HAS_INT128}
    function fitsInInt128: boolean;
    function fitsInUInt128: boolean;
    {$endif}
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
    // constant-time variants: no data-dependent branches or early exits, the
    // running time depends only on the limb counts (for secret comparisons)
    function equalsCT(const other: UBigInt): boolean;
    function compareCT(const other: UBigInt): integer;
    // zero the limb storage before releasing it (skips buffers shared with
    // other values), then set the value to 0
    procedure secureClear;
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
    // math
    function sqr: UBigInt;
    function sqrt: UBigInt;
    function nthRoot(n: LongWord): UBigInt;
    function nthRootRem(n: LongWord): (root, rem: UBigInt);
    function isKthPower(k: LongWord): boolean;
    function pow(e: LongWord): UBigInt;
    function modPow(const e, m: UBigInt): UBigInt;
    // constant-time square-and-multiply: the running time does not depend on
    // the exponent bits (side-channel resistant), for secret exponents
    function modPowSec(const e, m: UBigInt): UBigInt;
    function modInverse(const m: UBigInt): UBigInt;
    function gcd(const other: UBigInt): UBigInt;
    function lcm(const other: UBigInt): UBigInt;
    // extras: number theory
    function jacobi(const n: UBigInt): integer;
    function kronecker(const n: UBigInt): integer;
    function modSqrt(const p: UBigInt): UBigInt;
    // one k-th root modulo an odd prime (Adleman-Manders-Miller); raises when
    // none exists
    function nthRootMod(k: LongWord; const p: UBigInt): UBigInt;
    // square roots modulo a composite: every solution, via factor+lift+CRT
    function sqrtModN(const n: UBigInt): array of UBigInt;
    // baby-step giant-step discrete log: least x with self^x = target (mod m),
    // or -1 when none exists below the modulus order
    function discreteLog(const target, m: UBigInt): Int64;
    // least k > 0 with self^k = 1 (mod m); self must be coprime to m
    function multiplicativeOrder(const m: UBigInt): UBigInt;
    function isPrimitiveRoot(const m: UBigInt): boolean;
    // smallest primitive root modulo self (exists for 1, 2, 4, p^k, 2*p^k)
    function primitiveRoot: UBigInt;
    function isPerfectSquare: boolean;
    function sqrtRem: (root, rem: UBigInt);
    function factorize: array of (p: UBigInt; e: LongWord);
    // multiplicative functions, all read off the factorization
    function eulerPhi: UBigInt;
    function carmichaelLambda: UBigInt;
    function moebius: integer;
    function sigma(k: LongWord = 1): UBigInt;
    function tau: UBigInt;
    function radical: UBigInt;
    function divisors: array of UBigInt;
    function isSquarefree: boolean;
    function isPerfect: boolean;
    function isCarmichael: boolean;
    // primes: isProbablePrime is Miller-Rabin (deterministic below 3.3e24, then
    // random rounds); isPrime is Baillie-PSW (no known counterexample)
    function isProbablePrime(rounds: integer = 24): boolean;
    function isPrime: boolean;
    function nextPrime: UBigInt;
    function prevPrime: UBigInt;
    // bytes, little/big endian magnitude; zero gives an empty array
    function toBytesLE: TBytes;
    function toBytesBE: TBytes;
    // fixed width: zero-padded to len bytes (ERangeError when the value does
    // not fit), for protocols with fixed-size fields
    function toBytesLE(len: SizeInt): TBytes;
    function toBytesBE(len: SizeInt): TBytes;
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
    class function randomPrime(bits: LongWord; rounds: integer = 24): UBigInt; static;
    // CSPRNG variants: bytes come straight from the OS entropy source with no
    // seedable generator in between (key material); raise EBigIntError when
    // the OS source is unavailable
    class function randomSecure(bits: LongWord): UBigInt; static;
    class function randomSecureBelow(const bound: UBigInt): UBigInt; static;
    class function randomSecureRange(const lo, hi: UBigInt): UBigInt; static;
    class function randomSecurePrime(bits: LongWord; rounds: integer = 24): UBigInt; static;
    // safe prime: p and (p-1)/2 both prime; strong prime: p-1 and p+1 each have
    // a large prime factor (RSA/DH key generation)
    class function randomSafePrime(bits: LongWord): UBigInt; static;
    class function randomStrongPrime(bits: LongWord): UBigInt; static;
    // exact prime counting by a segmented sieve (practical to ~1e10)
    class function primePi(n: QWord): QWord; static;
    class function primeCount(lo, hi: QWord): QWord; static;
    class function factorial(n: LongWord): UBigInt; static;
    class function fibonacci(n: LongWord): UBigInt; static;
    class function lucas(n: LongWord): UBigInt; static;
    class function binomial(n, k: LongWord): UBigInt; static;
    // C(n, k) mod prime p for arbitrarily large n, k via the Lucas theorem;
    // cost grows with min(k, n-k) taken per base-p digit
    class function binomialMod(const n, k, p: UBigInt): UBigInt; static;
    class function multinomial(const ks: array of LongWord): UBigInt; static;
    class function risingFactorial(const x: UBigInt; n: LongWord): UBigInt; static;
    class function fallingFactorial(const x: UBigInt; n: LongWord): UBigInt; static;
    class function catalan(n: LongWord): UBigInt; static;
    class function primorial(n: LongWord): UBigInt; static;
    class function subfactorial(n: LongWord): UBigInt; static;
    class function bell(n: LongWord): UBigInt; static;
    class function stirling2(n, k: LongWord): UBigInt; static;
    class function partitions(n: LongWord): UBigInt; static;
  end;

  { BigInt - signed arbitrary precision integer, sign-magnitude storage;
    bitwise operators and bit access use two's complement semantics with
    infinite sign extension (like Python ints), div/mod truncate like Pascal }

  BigInt = record
  private
    // same inline storage as UBigInt (see there), plus a sign flag
    fInline: array[0..BIGINT_INLINE_LIMBS - 1] of TBigIntLimb;
    fArr: TBigIntLimbs;
    fLen: SizeInt;
    fNeg: boolean;
    function dataPtr: PBigIntLimb; inline;
    function getLimbs: TBigIntLimbs;
    procedure setLimbs(const v: TBigIntLimbs);
    function getBitProp(i: LongWord): boolean; inline;
    procedure putBitProp(i: LongWord; v: boolean); inline;
    property fLimbs: TBigIntLimbs read getLimbs write setLimbs;
  public
    class operator Initialize(var x: BigInt);
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
    function toInt8: Int8;
    function toUInt8: UInt8;
    function toInt16: Int16;
    function toUInt16: UInt16;
    function toInt32: Int32;
    function toUInt32: UInt32;
    function toInt64: Int64;
    function toUInt64: UInt64;
    {$ifdef BIGINT_HAS_INT128}
    function toInt128: Int128;
    function toUInt128: UInt128;
    {$endif}
    function toDouble: Double;
    function toUBigInt: UBigInt;
    // does the value fit in each native integer width
    function fitsInInt8: boolean;
    function fitsInUInt8: boolean;
    function fitsInInt16: boolean;
    function fitsInUInt16: boolean;
    function fitsInInt32: boolean;
    function fitsInUInt32: boolean;
    function fitsInInt64: boolean;
    function fitsInUInt64: boolean;
    {$ifdef BIGINT_HAS_INT128}
    function fitsInInt128: boolean;
    function fitsInUInt128: boolean;
    {$endif}
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
    // constant-time variants, see UBigInt
    function equalsCT(const other: BigInt): boolean;
    function compareCT(const other: BigInt): integer;
    procedure secureClear;
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
    // math
    function sqr: BigInt;
    function sqrt: BigInt;
    function nthRoot(n: LongWord): BigInt;
    function pow(e: LongWord): BigInt;
    // modPow follows Java: modulus must be positive, result in [0, m),
    // a negative exponent goes through the modular inverse
    function modPow(const e, m: BigInt): BigInt;
    function modInverse(const m: BigInt): BigInt;
    function gcd(const other: BigInt): BigInt;
    function lcm(const other: BigInt): BigInt;
    // extras: number theory (these all work on the absolute value)
    function gcdExt(const other: BigInt): (g, x, y: BigInt);
    function jacobi(const n: BigInt): integer;
    function kronecker(const n: BigInt): integer;
    function modSqrt(const p: BigInt): BigInt;
    // one k-th root modulo an odd prime (Adleman-Manders-Miller); raises when
    // none exists
    function nthRootMod(k: LongWord; const p: BigInt): BigInt;
    // least k > 0 with self^k = 1 (mod m); self must be coprime to m
    function multiplicativeOrder(const m: BigInt): BigInt;
    function isPrimitiveRoot(const m: BigInt): boolean;
    // smallest primitive root modulo self (exists for 1, 2, 4, p^k, 2*p^k)
    function primitiveRoot: BigInt;
    function isPerfectSquare: boolean;
    function sqrtRem: (root, rem: BigInt);
    function factorize: array of (p: BigInt; e: LongWord);
    function eulerPhi: BigInt;
    function carmichaelLambda: BigInt;
    function moebius: integer;
    function sigma(k: LongWord = 1): BigInt;
    function tau: BigInt;
    function radical: BigInt;
    function divisors: array of BigInt;
    function isSquarefree: boolean;
    function isPerfect: boolean;
    function isCarmichael: boolean;
    function isKthPower(k: LongWord): boolean;
    // primes: negative values are never prime, nextPrime returns the first prime > self
    function isProbablePrime(rounds: integer = 24): boolean;
    function isPrime: boolean;
    function nextPrime: BigInt;
    function prevPrime: BigInt;
    // bytes: minimal two's complement with sign bit, like Java toByteArray
    function toBytesLE: TBytes;
    function toBytesBE: TBytes;
    // fixed width: sign-extended two's complement over len bytes (ERangeError
    // when the value does not fit)
    function toBytesLE(len: SizeInt): TBytes;
    function toBytesBE(len: SizeInt): TBytes;
    class function fromBytesLE(const bytes: TBytes): BigInt; static;
    class function fromBytesBE(const bytes: TBytes): BigInt; static;
    // misc
    function digitCount: LongWord;
    function toStringGrouped(sep: char = '_'; groupSize: integer = 3): string;
    // number in Roman numerals (1..3999); in words (English short scale)
    function toRoman: string;
    function toWords: string;
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
    class function randomPrime(bits: LongWord; rounds: integer = 24): BigInt; static;
    // CSPRNG variants, see UBigInt
    class function randomSecure(bits: LongWord): BigInt; static;
    class function randomSecureBelow(const bound: BigInt): BigInt; static;
    class function randomSecureRange(const lo, hi: BigInt): BigInt; static;
    class function randomSecurePrime(bits: LongWord; rounds: integer = 24): BigInt; static;
    // Chinese remainder theorem for pairwise coprime positive moduli
    class function crt(const remainders, moduli: array of BigInt): BigInt; static;
    // Lucas sequences U_n(P,Q), V_n(P,Q) modulo an odd m, by index doubling
    class function lucasSequence(const p, q, n, m: BigInt): (u, v: BigInt); static;
    class function factorial(n: LongWord): BigInt; static;
    class function fibonacci(n: LongWord): BigInt; static;
    class function lucas(n: LongWord): BigInt; static;
    class function binomial(n, k: LongWord): BigInt; static;
    // C(n, k) mod prime p for arbitrarily large n, k via the Lucas theorem
    class function binomialMod(const n, k, p: BigInt): BigInt; static;
    class function multinomial(const ks: array of LongWord): BigInt; static;
    class function risingFactorial(const x: BigInt; n: LongWord): BigInt; static;
    class function fallingFactorial(const x: BigInt; n: LongWord): BigInt; static;
    class function catalan(n: LongWord): BigInt; static;
    class function primorial(n: LongWord): BigInt; static;
    class function subfactorial(n: LongWord): BigInt; static;
    class function bell(n: LongWord): BigInt; static;
    // signed Stirling numbers of the first kind, Stirling of the second kind
    class function stirling1(n, k: LongWord): BigInt; static;
    class function stirling2(n, k: LongWord): BigInt; static;
    class function partitions(n: LongWord): BigInt; static;
    // Bernoulli number as an exact reduced fraction (num/den)
    class function bernoulli(n: LongWord): (num, den: BigInt); static;
    // continued fractions: coefficients of num/den, and the rebuild to a
    // reduced fraction
    class function continuedFraction(const num, den: BigInt): array of BigInt; static;
    class function fromContinuedFraction(const cf: array of BigInt): (num, den: BigInt); static;
  end;


  // rounding modes for BigDecimal.rounded: bdrRound rounds halves away from
  // zero, bdrHalfUp rounds halves toward +infinity, bdrHalfEven to the even
  // neighbor (banker's rounding)
  TBigDecimalRounding = (bdrTrunc, bdrCeil, bdrFloor, bdrRound, bdrHalfUp, bdrHalfEven);

  { BigDecimal - arbitrary precision decimal float: value = mantissa * 10^exp
    with a BigInt mantissa, kept canonical (no trailing zero digits).
    + - * are exact; / rounds to a chosen number of fractional digits and
    keeps one hidden guard digit, so (1/3)*3 still prints as 1 }

  BigDecimal = record
  private
    fMan: BigInt;     // decimal mantissa
    fExp: integer;    // value = fMan * 10^fExp
    fHidden: boolean; // last mantissa digit is a division guard, hidden by toString
  public
    // conversions in
    class operator :=(x: Int64): BigDecimal;
    class operator :=(x: QWord): BigDecimal;
    class operator :=(const s: string): BigDecimal;
    class operator :=(const a: BigInt): BigDecimal;
    class operator :=(const a: UBigInt): BigDecimal;
    // float casts take the shortest decimal that reads back to the same
    // float (0.1 gives 0.1); fromDoubleExact gives the exact binary value
    class operator explicit(d: Double): BigDecimal;
    class operator explicit(s: Single): BigDecimal;
    // exact integer paths for typecasts, so BigDecimal(q) never rounds via Double
    class operator explicit(x: Int64): BigDecimal;
    class operator explicit(x: QWord): BigDecimal;
    // conversions out (the BigInt cast raises ERangeError unless integral)
    class operator explicit(const a: BigDecimal): Double;
    class operator explicit(const a: BigDecimal): Single;
    class operator explicit(const a: BigDecimal): string;
    class operator explicit(const a: BigDecimal): BigInt;
    // arithmetic: + - * are exact, / rounds to 18 fractional digits (see
    // divide), div/mod are the integer quotient and the exact remainder
    class operator +(const a, b: BigDecimal): BigDecimal;
    class operator -(const a, b: BigDecimal): BigDecimal;
    class operator *(const a, b: BigDecimal): BigDecimal;
    class operator /(const a, b: BigDecimal): BigDecimal;
    class operator div(const a, b: BigDecimal): BigDecimal;
    class operator mod(const a, b: BigDecimal): BigDecimal;
    class operator **(const a: BigDecimal; e: Int64): BigDecimal;
    class operator **(const a, b: BigDecimal): BigDecimal;
    class operator inc(const a: BigDecimal): BigDecimal;
    class operator dec(const a: BigDecimal): BigDecimal;
    // unary
    class operator -(const a: BigDecimal): BigDecimal;
    class operator +(const a: BigDecimal): BigDecimal;
    // comparisons (numeric: 0.5 = 5E-1 whatever the representation)
    class operator =(const a, b: BigDecimal): boolean;
    class operator <>(const a, b: BigDecimal): boolean;
    class operator <(const a, b: BigDecimal): boolean;
    class operator <=(const a, b: BigDecimal): boolean;
    class operator >(const a, b: BigDecimal): boolean;
    class operator >=(const a, b: BigDecimal): boolean;

    // formatting: toString is plain decimal (-123.45), toScientific keeps
    // one leading digit (-1.2345E2), toEngineering an exponent that is a
    // multiple of three (-123.45E0, 12.5E3)
    function toString: string;
    function toScientific: string;
    function toEngineering: string;
    // exact conversions (raise ERangeError unless integral and in range;
    // use trunc/floor/ceil/round for the lossy ones)
    function toInt8: Int8;
    function toUInt8: UInt8;
    function toInt16: Int16;
    function toUInt16: UInt16;
    function toInt32: Int32;
    function toUInt32: UInt32;
    function toInt64: Int64;
    function toUInt64: UInt64;
    {$ifdef BIGINT_HAS_INT128}
    function toInt128: Int128;
    function toUInt128: UInt128;
    {$endif}
    function toBigInt: BigInt;
    function toUBigInt: UBigInt;
    // integral and inside each native integer width
    function fitsInInt8: boolean;
    function fitsInUInt8: boolean;
    function fitsInInt16: boolean;
    function fitsInUInt16: boolean;
    function fitsInInt32: boolean;
    function fitsInUInt32: boolean;
    function fitsInInt64: boolean;
    function fitsInUInt64: boolean;
    {$ifdef BIGINT_HAS_INT128}
    function fitsInInt128: boolean;
    function fitsInUInt128: boolean;
    {$endif}
    // correctly rounded to the nearest float (ties to even); overflow gives
    // infinity, underflow gives zero
    function toDouble: Double;
    function toSingle: Single;
    {$ifdef FPC_HAS_TYPE_EXTENDED}
    function toExtended: Extended;
    {$endif}
    // predicates
    function isZero: boolean;
    function isOne: boolean;
    function isIntegral: boolean;
    // parity of integral values; a fractional value is neither even nor odd
    function isEven: boolean;
    function isOdd: boolean;
    function isNegative: boolean;
    function isPositive: boolean;
    function sign: integer;
    // sign helpers
    function abs: BigDecimal;
    procedure negate;
    // integer parts: trunc cuts toward zero, floor toward -infinity, ceil
    // toward +infinity, round takes halves to even (like Pascal round);
    // frac is what trunc drops, so self = trunc + frac
    function trunc: BigInt;
    function floor: BigInt;
    function ceil: BigInt;
    function round: BigInt;
    function frac: BigDecimal;
    // exact rational view: self = num / den with a reduced power-of-ten
    // denominator, so 0.375 gives (3, 8)
    function toFraction: (num, den: BigInt);
    // continued fraction coefficients of the exact value (maxTerms <= 0 for
    // all of them); great for best rational approximations
    function continuedFraction(maxTerms: integer = 0): array of BigInt;
    // decimal introspection: precision counts significant digits, getDigit
    // returns the digit at 10^i of the absolute value (0 outside)
    function precision: integer;
    function mostSignificantExponent: integer;
    function getDigit(i: integer): integer;
    // multiply by a power of ten
    procedure shift10(n: integer);
    function shifted10(n: integer): BigDecimal;
    // round to a decimal position: toDigit 0 = integer, -2 = cents, 3 = thousands
    function rounded(toDigit: integer = 0; mode: TBigDecimalRounding = bdrRound): BigDecimal;
    // round to the nearest multiple of an arbitrary step, e.g. 0.05
    function quantize(const step: BigDecimal; mode: TBigDecimalRounding = bdrRound): BigDecimal;
    // comparison helpers
    function compare(const other: BigDecimal): integer;
    function equals(const other: BigDecimal): boolean;
    function approxEquals(const other, epsilon: BigDecimal): boolean;
    function min(const other: BigDecimal): BigDecimal;
    function max(const other: BigDecimal): BigDecimal;
    // division: the quotient carries `precision` fractional digits (more when
    // the operands are finer, always the full integer part) plus a hidden
    // guard digit; exact quotients stay exact. divMod gives the integer
    // quotient and the exact remainder
    function divide(const other: BigDecimal; precision: integer = 18): BigDecimal;
    function divMod(const d: BigDecimal): (q, r: BigDecimal);
    // parsing: [sign]digits[.digits][E[sign]digits], "_" separators allowed
    class function parse(const s: string): BigDecimal; static;
    class function tryParse(const s: string; out v: BigDecimal): boolean; static;
    // calculator: evaluate a textual expression at the given precision, e.g.
    // calc('2^100 / sqrt(2)'). Operators + - * / div mod(%) ^(**) !, the
    // usual precedence with a right-associative power; functions sqrt cbrt
    // root pow sqr abs exp ln log log2 log10 logb sin cos tan asin acos atan
    // sinh cosh tanh floor ceil round trunc gamma lngamma erf erfc factorial
    // min max gcd lcm atan2 hypot agm; constants pi e tau phi. Stateless:
    // no variables, syntax errors raise EConvertError with the position
    class function calc(const s: string; precision: integer = 18): BigDecimal; static;
    class function tryCalc(const s: string; out v: BigDecimal; precision: integer = 18): boolean; static;
    // math: sqrt keeps `precision` fractional digits plus the same hidden
    // guard digit as divide; pow with a negative exponent divides at the
    // default precision; gcd/lcm work on the decimal lattice, so
    // gcd(0.25, 0.15) = 0.05
    function sqrt(precision: integer = 18): BigDecimal;
    function pow(e: Int64): BigDecimal;
    function pow(const y: BigDecimal; precision: integer = 18): BigDecimal;
    function nthRoot(n: LongWord; precision: integer = 18): BigDecimal;
    function gcd(const other: BigDecimal): BigDecimal;
    function lcm(const other: BigDecimal): BigDecimal;
    // transcendentals: `precision` fractional digits (and at least that many
    // significant digits for tiny results) behind the same hidden guard
    // digit as divide; computed over scaled integers with extra working
    // digits. log10 is exact for powers of ten, log2 for powers of two,
    // a fractional pow goes through exp(y * ln x)
    function exp(precision: integer = 18): BigDecimal;
    function ln(precision: integer = 18): BigDecimal;
    function log2(precision: integer = 18): BigDecimal;
    function log10(precision: integer = 18): BigDecimal;
    function logBase(const b: BigDecimal; precision: integer = 18): BigDecimal;
    // trigonometry in radians; large arguments are reduced modulo pi/2 with
    // pi carried at a matching precision, arcsin/arccos raise EBigIntError
    // outside -1..1
    function sin(precision: integer = 18): BigDecimal;
    function cos(precision: integer = 18): BigDecimal;
    function tan(precision: integer = 18): BigDecimal;
    function arcsin(precision: integer = 18): BigDecimal;
    function arccos(precision: integer = 18): BigDecimal;
    function arctan(precision: integer = 18): BigDecimal;
    // hyperbolics
    function sinh(precision: integer = 18): BigDecimal;
    function cosh(precision: integer = 18): BigDecimal;
    function tanh(precision: integer = 18): BigDecimal;
    // special functions: the gamma function and its logarithm (positive
    // argument for lnGamma, reflection covers negatives for gamma), the real
    // factorial x! = gamma(x+1), the error function and its complement
    function lnGamma(precision: integer = 18): BigDecimal;
    function gamma(precision: integer = 18): BigDecimal;
    function factorial(precision: integer = 18): BigDecimal;
    function erf(precision: integer = 18): BigDecimal;
    function erfc(precision: integer = 18): BigDecimal;
    // round to a count of significant digits rather than a decimal position
    function roundToSignificant(digits: integer; mode: TBigDecimalRounding = bdrRound): BigDecimal;
    // float builders: plain takes the shortest round-tripping decimal,
    // exact the full binary expansion
    class function fromDouble(d: Double): BigDecimal; static;
    class function fromDoubleExact(d: Double): BigDecimal; static;
    class function fromSingle(s: Single): BigDecimal; static;
    class function fromSingleExact(s: Single): BigDecimal; static;
    {$ifdef FPC_HAS_TYPE_EXTENDED}
    class function fromExtended(e: Extended): BigDecimal; static;
    class function fromExtendedExact(e: Extended): BigDecimal; static;
    {$endif}
    // misc
    function hashCode: DWord;
    procedure swap(var other: BigDecimal);
    // constants
    class function zero: BigDecimal; static;
    class function one: BigDecimal; static;
    class function two: BigDecimal; static;
    class function ten: BigDecimal; static;
    // famous constants at any precision (pi is cached, Chudnovsky splitting)
    class function pi(precision: integer = 18): BigDecimal; static;
    class function e(precision: integer = 18): BigDecimal; static;
    // two-argument arctangent (quadrant-aware), Euclidean length, and the
    // arithmetic-geometric mean
    class function atan2(const y, x: BigDecimal; precision: integer = 18): BigDecimal; static;
    class function hypot(const x, y: BigDecimal; precision: integer = 18): BigDecimal; static;
    class function agm(const a, b: BigDecimal; precision: integer = 18): BigDecimal; static;
  end;

  // bridges declared after BigDecimal so the integer types can return the
  // wider types (BigInt for UBigInt, BigDecimal for both)
  TUBigIntBridge = record helper for UBigInt
    function toBigInt: BigInt;
    function toDecimal: BigDecimal;
    // extended Euclid: g = self*x + other*y (the coefficients can be negative)
    function gcdExt(const other: UBigInt): (g: UBigInt; x, y: BigInt);
  end;

  TBigIntBridge = record helper for BigInt
    function toDecimal: BigDecimal;
  end;

var
  // limb count above which multiplication and squaring switch from schoolbook
  // to Karatsuba; exposed for tuning and testing
  BigIntKaratsubaThreshold: integer = {$ifdef BIGINT_ASM} 80 {$else} 48 {$endif};

  // limb count above which balanced multiplication and squaring switch from
  // Karatsuba to Toom-3; exposed for tuning and testing. with the 64-bit asm
  // kernels Karatsuba stays ahead of Toom-3 well past 500 limbs, so the switch
  // sits high there; below ~520 limbs Toom-3 is a net loss on the asm build
  BigIntToom3Threshold: integer = {$ifdef BIGINT_ASM} 700 {$else} 200 {$endif};

  // generator used by random/randomBelow/randomRange/randomPrime
  BigIntRngAlgo: TBigIntRngAlgo = rngXoshiro256ss;

  // spare limbs allocated past the needed size when addTo/subTo must grow the
  // destination, so repeated accumulation into one value reallocates rarely
  BigIntGrowLimbs: integer = 32;

// deterministic seeding of every generator (also sets RandSeed for rngSystem)
procedure BigIntRandomSeed(seed: QWord);
// seed all generators from OS entropy
procedure BigIntRandomize;

// in-place arithmetic: dst := a + b / a - b writing into dst's existing
// buffer when it is exclusively owned and big enough (mpz_add-style, no
// allocation per call); dst may alias a or b
procedure addTo(var dst: UBigInt; const a, b: UBigInt);
// dst := a - b, raises ERangeError when a < b
procedure subTo(var dst: UBigInt; const a, b: UBigInt);

implementation

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
{$if defined(BIGINT_ASM) or defined(BIGINT_ASM32)}{$asmmode intel}{$endif}

const
{$ifdef BIGINT_LIMB64}
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
{$ifdef BIGINT_INT128}
// inlines to one mul at the call site, no call and no memory round-trip
procedure UMulLimb(a, b: TLimb; out hi, lo: TLimb); inline;
begin
  var p := UInt128(a) * b;
  lo := TLimb(p);
  hi := TLimb(p shr 64);
end;
{$else}
procedure UMulLimb(a, b: TLimb; out hi, lo: TLimb); assembler; nostackframe;
asm
  mov rax, rcx
  mul rdx       // rdx:rax = a * b
  mov [r8], rdx
  mov [r9], rax
end;
{$endif}

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

// 64-byte entry alignment pins the inner-loop labels to fixed cache-line
// offsets, so kernel timing does not drift with the binary's code layout
{$codealign proc=64}

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
  align 32                 // pin the loop to a fixed cache-line offset
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
function MpnSubMul1Gen(rp, ap: PLimb; n: SizeInt; b: TLimb): TLimb; assembler; nostackframe;
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

// two-chain variant: the product row rides the OF chain (adox), the borrow
// rides the CF chain through the memory subtract, so the serial part is one
// sbb per limb instead of four flag-coupled ops
function MpnSubMul1Adx(rp, ap: PLimb; n: SizeInt; b: TLimb): TLimb; assembler; nostackframe;
asm
  mov r10, rdx        // ap
  mov rdx, r9         // b, implicit mulx operand
  xor r11d, r11d      // row carry = 0, CF = 0, OF = 0
  test r8, r8
  jz @done
@loop:
  mulx r9, rax, [r10]
  adox rax, r11       // lo += row carry, OF = overflow
  mov r11d, 0
  adox r11, r9        // row carry = hi + overflow (cannot wrap), OF = 0
  sbb [rcx], rax      // borrow chain lives in CF across iterations
  lea r10, [r10 + 8]
  lea rcx, [rcx + 8]
  dec r8              // dec leaves CF alone
  jnz @loop
@done:
  mov rax, r11
  adc rax, 0          // fold the final borrow into the carry limb
end;

function MpnSubMul1(rp, ap: PLimb; n: SizeInt; b: TLimb): TLimb; inline;
begin
  result := if UseAdx then MpnSubMul1Adx(rp, ap, n, b) else MpnSubMul1Gen(rp, ap, n, b);
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

{$codealign proc=16}

{$else}

// portable primitives: carries ride in the top half of double-width temps
// (UInt128 with 64-bit limbs, QWord with 32-bit)

type
  {$ifdef BIGINT_PP128}
  TWide = UInt128;
  {$else}
  TWide = QWord;
  {$endif}

function LimbBsr(x: TLimb): LongWord; inline;
begin
  {$ifdef BIGINT_PP128}
  result := BsrQWord(x);
  {$else}
  result := BsrDWord(x);
  {$endif}
end;

function LimbBsf(x: TLimb): LongWord; inline;
begin
  {$ifdef BIGINT_PP128}
  result := BsfQWord(x);
  {$else}
  result := BsfDWord(x);
  {$endif}
end;

// 2-limb product of a * b
procedure UMulLimb(a, b: TLimb; out hi, lo: TLimb); inline;
begin
  var p := TWide(a) * b;
  lo := TLimb(p);
  hi := TLimb(p shr LIMB_BITS);
end;

// (hi:lo) div d and its remainder, caller guarantees hi < d
{$ifdef BIGINT_ASM32}
function UDivLimb(hi, lo, d: TLimb; out rem: TLimb): TLimb; assembler;
asm
  // eax = hi, edx = lo, ecx = d, rem pointer on the stack; hi < d makes the
  // single div safe, skipping the RTL 64/32 helper
  push ebx
  mov ebx, rem
  xchg eax, edx
  div ecx
  mov [ebx], edx
  pop ebx
end;
{$else}
function UDivLimb(hi, lo, d: TLimb; out rem: TLimb): TLimb; inline;
begin
  var cur := (TWide(hi) shl LIMB_BITS) or lo;
  result := TLimb(cur div d);
  // remainder fits a limb, so mul-back in limb width beats a second wide mod
  rem := TLimb(cur) - result * d;
end;
{$endif}

// mpn-style row primitives: fixed-length limb runs behind raw pointers with
// the carry/borrow returned to the caller; rp may alias ap (and bp)

// rp := ap + bp over n limbs, returns carry
{$ifdef BIGINT_ASM32}
function MpnAddN(rp, ap, bp: PLimb; n: SizeInt): TLimb; assembler;
asm
  // register convention: eax = rp, edx = ap, ecx = bp, n on the stack
  push ebx
  push esi
  push edi
  mov edi, eax
  mov esi, edx
  mov ebx, ecx
  mov ecx, n
  xor eax, eax       // result 0, CF cleared for the adc chain
  test ecx, ecx
  jz @done
@loop:
  mov eax, [esi]
  adc eax, [ebx]
  mov [edi], eax
  lea esi, [esi + 4] // lea/dec keep CF alive across the iteration
  lea ebx, [ebx + 4]
  lea edi, [edi + 4]
  dec ecx
  jnz @loop
  mov eax, 0
  adc eax, 0
@done:
  pop edi
  pop esi
  pop ebx
end;
{$else}
function MpnAddN(rp, ap, bp: PLimb; n: SizeInt): TLimb;
begin
  var carry: TWide := 0;
  for var i := 0 to n - 1 do begin
    carry := carry + ap[i] + bp[i];
    rp[i] := TLimb(carry);
    carry := carry shr LIMB_BITS;
  end;
  result := TLimb(carry);
end;
{$endif}

// rp := ap - bp over n limbs, returns borrow
{$ifdef BIGINT_ASM32}
function MpnSubN(rp, ap, bp: PLimb; n: SizeInt): TLimb; assembler;
asm
  push ebx
  push esi
  push edi
  mov edi, eax
  mov esi, edx
  mov ebx, ecx
  mov ecx, n
  xor eax, eax
  test ecx, ecx
  jz @done
@loop:
  mov eax, [esi]
  sbb eax, [ebx]
  mov [edi], eax
  lea esi, [esi + 4]
  lea ebx, [ebx + 4]
  lea edi, [edi + 4]
  dec ecx
  jnz @loop
  mov eax, 0
  adc eax, 0
@done:
  pop edi
  pop esi
  pop ebx
end;
{$else}
function MpnSubN(rp, ap, bp: PLimb; n: SizeInt): TLimb;
begin
  var borrow: TWide := 0;
  for var i := 0 to n - 1 do begin
    var t := TWide(ap[i]) - bp[i] - borrow;
    rp[i] := TLimb(t);
    borrow := (t shr LIMB_BITS) and 1;
  end;
  result := TLimb(borrow);
end;
{$endif}

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
{$ifdef BIGINT_ASM32}
function MpnMul1(rp, ap: PLimb; n: SizeInt; b: TLimb): TLimb; assembler;
asm
  // eax = rp, edx = ap, ecx = n, b on the stack; ebx carries between limbs
  push ebx
  push esi
  push edi
  mov edi, eax
  mov esi, edx
  xor ebx, ebx
  test ecx, ecx
  jz @done
@loop:
  mov eax, [esi]
  mul b          // edx:eax = ap[i] * b
  add eax, ebx
  adc edx, 0
  mov [edi], eax
  mov ebx, edx
  add esi, 4
  add edi, 4
  dec ecx
  jnz @loop
@done:
  mov eax, ebx
  pop edi
  pop esi
  pop ebx
end;
{$else}
function MpnMul1(rp, ap: PLimb; n: SizeInt; b: TLimb): TLimb;
begin
  var carry: TWide := 0;
  for var i := 0 to n - 1 do begin
    carry := TWide(ap[i]) * b + carry;
    rp[i] := TLimb(carry);
    carry := carry shr LIMB_BITS;
  end;
  result := TLimb(carry);
end;
{$endif}

// rp += ap * b, returns the carry limb
{$ifdef BIGINT_ASM32}
function MpnAddMul1(rp, ap: PLimb; n: SizeInt; b: TLimb): TLimb; assembler;
asm
  push ebx
  push esi
  push edi
  mov edi, eax
  mov esi, edx
  xor ebx, ebx
  test ecx, ecx
  jz @done
@loop:
  mov eax, [esi]
  mul b
  add eax, ebx
  adc edx, 0
  add [edi], eax // rp[i] += low, CF folds into the high half
  adc edx, 0
  mov ebx, edx
  add esi, 4
  add edi, 4
  dec ecx
  jnz @loop
@done:
  mov eax, ebx
  pop edi
  pop esi
  pop ebx
end;
{$else}
function MpnAddMul1(rp, ap: PLimb; n: SizeInt; b: TLimb): TLimb;
begin
  var carry: TWide := 0;
  for var i := 0 to n - 1 do begin
    carry := TWide(rp[i]) + TWide(ap[i]) * b + carry;
    rp[i] := TLimb(carry);
    carry := carry shr LIMB_BITS;
  end;
  result := TLimb(carry);
end;
{$endif}

// rp -= ap * b, returns the borrow limb
{$ifdef BIGINT_ASM32}
function MpnSubMul1(rp, ap: PLimb; n: SizeInt; b: TLimb): TLimb; assembler;
asm
  push ebx
  push esi
  push edi
  mov edi, eax
  mov esi, edx
  xor ebx, ebx
  test ecx, ecx
  jz @done
@loop:
  mov eax, [esi]
  mul b
  add eax, ebx
  adc edx, 0
  sub [edi], eax // rp[i] -= low, CF = borrow into the high half
  adc edx, 0
  mov ebx, edx
  add esi, 4
  add edi, 4
  dec ecx
  jnz @loop
@done:
  mov eax, ebx
  pop edi
  pop esi
  pop ebx
end;
{$else}
function MpnSubMul1(rp, ap: PLimb; n: SizeInt; b: TLimb): TLimb;
begin
  var carry: TWide := 0;
  for var i := 0 to n - 1 do begin
    var p := TWide(ap[i]) * b + carry;
    var t := TWide(rp[i]) - TLimb(p);
    rp[i] := TLimb(t);
    carry := (p shr LIMB_BITS) + ((t shr LIMB_BITS) and 1);
  end;
  result := TLimb(carry);
end;
{$endif}

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

// ---------------------------------------------------------------------------
// small-value optimization storage (inline limbs + spill limb array)
// ---------------------------------------------------------------------------

// all storage helpers take typed PLimb rather than untyped var params: an
// untyped var passed to an inline routine and dereferenced via @ miscompiles
// on this toolchain

function MakeLimbs(p: PLimb; len: SizeInt): TLimbs; inline;
begin
  result := nil;
  if len = 0 then exit;
  result := LNew(len);
  Move(p^, result[0], len * SizeOf(TLimb));
end;

// true when the spill array is exclusively owned (dynarray refcount 1), so
// bit mutators may edit it in place with no copy; reads the FPC dynarray
// header (refcount, high) that sits right before the data
function ArrUnshared(const a: TLimbs): boolean; inline;
begin
  result := PPtrInt(Pointer(a))[-2] = 1;
end;

// store a limb array into inline-or-spill storage, normalizing the length.
// dst is the record's inline array. normalized arrays are adopted by
// reference (no copy); an unnormalized tail forces a trimming copy so the
// invariant fLen = Length(fArr) holds for spilled values
procedure StoreLimbs(const v: TLimbs; dst: PLimb; var arr: TLimbs; var len: SizeInt);
begin
  var n := Length(v);
  while (n > 0) and (v[n - 1] = 0) do dec(n);
  len := n;
  if n <= BIGINT_INLINE_LIMBS then begin
    // inline invariant: limbs above len are zero, so fast paths read branchlessly
    FillChar(dst^, BIGINT_INLINE_LIMBS * SizeOf(TLimb), 0);
    if n > 0 then Move(v[0], dst^, n * SizeOf(TLimb));
    arr := nil;
  end else if n = Length(v) then arr := v
  else arr := Copy(v, 0, n);
end;

function UBigInt.dataPtr: PBigIntLimb; inline;
begin
  result := PBigIntLimb(Pointer(fArr));
  if result = nil then result := @fInline[0];
end;

function UBigInt.getLimbs: TBigIntLimbs;
begin
  // spilled values share the array by reference: reading fLimbs on a large
  // value costs one refcount bump, same as a plain limb-array field
  if fArr <> nil then begin
    if fLen = Length(fArr) then exit(fArr);
    exit(Copy(fArr, 0, fLen));
  end;
  result := MakeLimbs(@fInline[0], fLen);
end;

procedure UBigInt.setLimbs(const v: TBigIntLimbs);
begin
  StoreLimbs(v, @fInline[0], fArr, fLen);
end;

class operator UBigInt.Initialize(var x: UBigInt);
begin
  // fArr is nil-initialized by the compiler before this runs
  x.fLen := 0;
  FillChar(x.fInline, SizeOf(x.fInline), 0);
end;

function BigInt.dataPtr: PBigIntLimb; inline;
begin
  result := PBigIntLimb(Pointer(fArr));
  if result = nil then result := @fInline[0];
end;

function BigInt.getLimbs: TBigIntLimbs;
begin
  if fArr <> nil then begin
    if fLen = Length(fArr) then exit(fArr);
    exit(Copy(fArr, 0, fLen));
  end;
  result := MakeLimbs(@fInline[0], fLen);
end;

procedure BigInt.setLimbs(const v: TBigIntLimbs);
begin
  StoreLimbs(v, @fInline[0], fArr, fLen);
end;

class operator BigInt.Initialize(var x: BigInt);
begin
  // fArr is nil-initialized by the compiler before this runs
  x.fLen := 0;
  x.fNeg := false;
  FillChar(x.fInline, SizeOf(x.fInline), 0);
end;
// strict a < b magnitude test: cheaper than the three-way compare for the
// ordering operators
function ULessU(const a, b: UBigInt): boolean; inline;
begin
  if a.fLen <> b.fLen then exit(a.fLen < b.fLen);
  var pa := a.dataPtr;
  var pb := b.dataPtr;
  for var i := a.fLen - 1 downto 0 do
    if pa[i] <> pb[i] then exit(pa[i] < pb[i]);
  result := false;
end;

// signed counterparts for BigInt (zero always carries fNeg = false)
function BLess(const a, b: BigInt): boolean; inline;
begin
  if a.fNeg <> b.fNeg then exit(a.fNeg);
  if a.fLen <> b.fLen then exit((a.fLen < b.fLen) xor a.fNeg);
  var pa := a.dataPtr;
  var pb := b.dataPtr;
  for var i := a.fLen - 1 downto 0 do
    if pa[i] <> pb[i] then exit((pa[i] < pb[i]) xor a.fNeg);
  result := false;
end;

function BEqB(const a, b: BigInt): boolean; inline;
begin
  if (a.fNeg <> b.fNeg) or (a.fLen <> b.fLen) then exit(false);
  var pa := a.dataPtr;
  var pb := b.dataPtr;
  for var i := 0 to a.fLen - 1 do
    if pa[i] <> pb[i] then exit(false);
  result := true;
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

// pointer-based reads over (ptr, len): used by the small-value fast paths so
// they never materialize a limb array
function LToQWordP(p: PLimb; len: SizeInt): QWord; inline;
begin
  {$if LIMB_BITS = 64}
  result := if len > 0 then p[0] else 0;
  {$else}
  result := 0;
  if len > 0 then result := p[0];
  if len > 1 then result := result or (QWord(p[1]) shl 32);
  {$endif}
end;

function LCmpP(pa: PLimb; la: SizeInt; pb: PLimb; lb: SizeInt): integer; inline;
begin
  if la <> lb then exit(if la < lb then -1 else 1);
  for var i := la - 1 downto 0 do
    if pa[i] <> pb[i] then exit(if pa[i] < pb[i] then -1 else 1);
  result := 0;
end;

function LCmpQP(p: PLimb; len: SizeInt; q: QWord): integer; inline;
begin
  if len > LIMBS_PER_QWORD then exit(1);
  var av := LToQWordP(p, len);
  if av < q then exit(-1);
  if av > q then exit(1);
  result := 0;
end;

// ---------------------------------------------------------------------------
// inline small-value fast paths (no allocation, no property materialization);
// operands and results live in the zero-padded inline array. r is a fresh
// operator result (fArr = nil, inline zeroed)
// ---------------------------------------------------------------------------

// all fast paths take typed PLimb pointers (never untyped var params - those
// miscompile when inlined and dereferenced via @ on this toolchain). dst is
// the destination record's inline array; the destination may be a reused
// operator temp still holding a live spill array, so every finish drops it

// build a magnitude from a QWord straight into inline storage
procedure USetQWord(dst: PLimb; var arr: TLimbs; var len: SizeInt; q: QWord); inline;
begin
  {$if LIMB_BITS = 64}
  dst[0] := q;
  var m: SizeInt := if q <> 0 then 1 else 0;
  {$else}
  dst[0] := TLimb(q);
  dst[1] := TLimb(q shr 32);
  var m: SizeInt := if q > High(TLimb) then 2 else if q <> 0 then 1 else 0;
  {$endif}
  for var i := m to BIGINT_INLINE_LIMBS - 1 do dst[i] := 0;
  arr := nil;
  len := m;
end;

// finish a fast-path result as zero
procedure PutZero(dst: PLimb; var rarr: TLimbs; var rlen: SizeInt); inline;
begin
  for var i := 0 to BIGINT_INLINE_LIMBS - 1 do dst[i] := 0;
  rarr := nil;
  rlen := 0;
end;

// share a source magnitude into a destination record's storage fields with no
// materialization: the spill array is shared by refcount instead of copying
// limbs. safe when source and destination alias (dynarray assignment is)
procedure ShareMag(srcInline: PLimb; const sarr: TLimbs; slen: SizeInt; dstInline: PLimb; var darr: TLimbs; var dlen: SizeInt);
begin
  if dstInline <> srcInline then
    for var i := 0 to BIGINT_INLINE_LIMBS - 1 do dstInline[i] := srcInline[i];
  darr := sarr;
  dlen := slen;
end;

// spread a QWord into a zero-padded stack operand for the inline fast paths;
// returns its significant length
function QToInline(q: QWord; p: PLimb): SizeInt; inline;
begin
  for var i := 0 to BIGINT_INLINE_LIMBS - 1 do p[i] := 0;
  {$if LIMB_BITS = 64}
  p[0] := q;
  result := if q <> 0 then 1 else 0;
  {$else}
  p[0] := TLimb(q);
  p[1] := TLimb(q shr 32);
  result := if p[1] <> 0 then 2 else if q <> 0 then 1 else 0;
  {$endif}
end;

// copy a computed buffer of significance m into the destination and finish it.
// the fast paths compute into a local buffer first, so the result may safely
// alias an operand (the compiler reuses operand temps as the result slot)
procedure PutInline(buf: PLimb; m: SizeInt; dst: PLimb; var rarr: TLimbs; var rlen: SizeInt);
begin
  for var i := 0 to m - 1 do dst[i] := buf[i];
  for var i := m to BIGINT_INLINE_LIMBS - 1 do dst[i] := 0;
  rarr := nil;
  rlen := m;
end;

// move a freshly built normalized array into a record's storage fields,
// transferring ownership with no refcount traffic (the caller's local is
// nil-ed out); small results land inline, keeping the zero-pad invariant
procedure MoveArr(var v: TLimbs; dst: PLimb; var arr: TLimbs; var len: SizeInt);
begin
  len := Length(v);
  if len <= BIGINT_INLINE_LIMBS then begin
    FillChar(dst^, BIGINT_INLINE_LIMBS * SizeOf(TLimb), 0);
    if len > 0 then Move(Pointer(v)^, dst^, len * SizeOf(TLimb));
    arr := nil; // drops any reused-temp spill
    exit;
  end;
  arr := nil; // no-op for a fresh result temp, releases a reused one
  Pointer(arr) := Pointer(v);
  Pointer(v) := nil;
end;

// spill finisher for fast-path results just past the inline capacity; copies
// into a fresh array before dropping the old one (result may be a reused temp)
procedure PutSpill(buf: PLimb; m: SizeInt; var rarr: TLimbs; var rlen: SizeInt);
begin
  var nb := LNew(m);
  Move(buf^, nb[0], m * SizeOf(TLimb));
  rarr := nb;
  rlen := m;
end;

// r := a + b for two inline operands; spills to an array only when the carry
// actually runs past the inline capacity
procedure AddInline(pa: PLimb; alen: SizeInt; pb: PLimb; blen: SizeInt; dst: PLimb; var rarr: TLimbs; var rlen: SizeInt);
begin
  var n := if alen > blen then alen else blen;
  var buf: array[0..BIGINT_INLINE_LIMBS] of TLimb;
  var carry: TLimb := 0;
  for var i := 0 to n - 1 do begin
    var av := pa[i];
    var s := av + pb[i];
    var c1 := TLimb(Ord(s < av));
    s := s + carry;
    carry := c1 or TLimb(Ord(s < carry));
    buf[i] := s;
  end;
  buf[n] := carry;
  var m: SizeInt;
  if carry <> 0 then m := n + 1
  else begin
    m := n;
    while (m > 0) and (buf[m - 1] = 0) do dec(m);
  end;
  if m <= BIGINT_INLINE_LIMBS then PutInline(@buf[0], m, dst, rarr, rlen)
  else PutSpill(@buf[0], m, rarr, rlen);
end;

// magnitude subtract a - b for a >= b, both inline
procedure SubInline(pa: PLimb; alen: SizeInt; pb: PLimb; dst: PLimb; var rarr: TLimbs; var rlen: SizeInt);
begin
  var buf: array[0..BIGINT_INLINE_LIMBS] of TLimb;
  var borrow: TLimb := 0;
  for var i := 0 to alen - 1 do begin
    var av := pa[i];
    var bv := pb[i];
    var s := av - bv;
    var b1 := TLimb(Ord(av < bv));
    var s2 := s - borrow;
    borrow := b1 or TLimb(Ord(s < borrow));
    buf[i] := s2;
  end;
  var m := alen;
  while (m > 0) and (buf[m - 1] = 0) do dec(m);
  PutInline(@buf[0], m, dst, rarr, rlen);
end;

// r := a * b for two inline operands; the product (at most twice the inline
// capacity) is computed on the stack and spills to an array only when it has to
procedure MulInline(pa: PLimb; alen: SizeInt; pb: PLimb; blen: SizeInt; dst: PLimb; var rarr: TLimbs; var rlen: SizeInt);
begin
  if (alen = 0) or (blen = 0) then begin
    PutZero(dst, rarr, rlen);
    exit;
  end;
  var buf: array[0..2 * BIGINT_INLINE_LIMBS - 1] of TLimb;
  for var i := 0 to alen + blen - 1 do buf[i] := 0;
  for var i := 0 to alen - 1 do buf[i + blen] := MpnAddMul1(@buf[i], pb, blen, pa[i]);
  var m := alen + blen;
  while (m > 0) and (buf[m - 1] = 0) do dec(m);
  if m <= BIGINT_INLINE_LIMBS then PutInline(@buf[0], m, dst, rarr, rlen)
  else PutSpill(@buf[0], m, rarr, rlen);
end;

// r := a and b; fits inline whenever either operand does (the result is never
// longer than the shorter operand), so pa/pb may point into a spill array
procedure AndInline(pa: PLimb; alen: SizeInt; pb: PLimb; blen: SizeInt; dst: PLimb; var rarr: TLimbs; var rlen: SizeInt);
begin
  var n := if alen < blen then alen else blen;
  while (n > 0) and ((pa[n - 1] and pb[n - 1]) = 0) do dec(n);
  var buf: array[0..BIGINT_INLINE_LIMBS - 1] of TLimb;
  for var i := 0 to n - 1 do buf[i] := pa[i] and pb[i];
  PutInline(@buf[0], n, dst, rarr, rlen);
end;

// r := a or b for two inline operands; n is max(alen, blen). the top limb of
// the longer operand survives, so no trim is needed
procedure OrInline(pa, pb: PLimb; n: SizeInt; dst: PLimb; var rarr: TLimbs; var rlen: SizeInt);
begin
  var buf: array[0..BIGINT_INLINE_LIMBS - 1] of TLimb;
  for var i := 0 to n - 1 do buf[i] := pa[i] or pb[i];
  PutInline(@buf[0], n, dst, rarr, rlen);
end;

// r := a xor b for two inline operands; n is max(alen, blen), equal-length
// operands may cancel top limbs so the trim runs before the copy
procedure XorInline(pa, pb: PLimb; n: SizeInt; dst: PLimb; var rarr: TLimbs; var rlen: SizeInt);
begin
  while (n > 0) and ((pa[n - 1] xor pb[n - 1]) = 0) do dec(n);
  var buf: array[0..BIGINT_INLINE_LIMBS - 1] of TLimb;
  for var i := 0 to n - 1 do buf[i] := pa[i] xor pb[i];
  PutInline(@buf[0], n, dst, rarr, rlen);
end;

// r := a shl n for an inline operand, alen >= 1; caller guarantees
// alen + (n div LIMB_BITS) <= BIGINT_INLINE_LIMBS, so at most one limb spills
procedure ShlInline(pa: PLimb; alen: SizeInt; n: LongWord; dst: PLimb; var rarr: TLimbs; var rlen: SizeInt);
begin
  var ls := SizeInt(n shr LIMB_SHIFT);
  var bs := integer(n and LIMB_MASK);
  var buf: array[0..BIGINT_INLINE_LIMBS] of TLimb;
  for var i := 0 to ls - 1 do buf[i] := 0;
  var top: TLimb := 0;
  if bs = 0 then
    for var i := 0 to alen - 1 do buf[ls + i] := pa[i]
  else top := MpnLshift(@buf[ls], pa, alen, bs);
  buf[ls + alen] := top;
  var m := ls + alen + SizeInt(ord(top <> 0));
  if m <= BIGINT_INLINE_LIMBS then PutInline(@buf[0], m, dst, rarr, rlen)
  else PutSpill(@buf[0], m, rarr, rlen);
end;

// r := a shr n for an inline operand; the result always fits inline
procedure ShrInline(pa: PLimb; alen: SizeInt; n: LongWord; dst: PLimb; var rarr: TLimbs; var rlen: SizeInt);
begin
  var ls := SizeInt(n shr LIMB_SHIFT);
  var rl := alen - ls;
  if rl <= 0 then begin
    PutZero(dst, rarr, rlen);
    exit;
  end;
  var bs := integer(n and LIMB_MASK);
  var buf: array[0..BIGINT_INLINE_LIMBS - 1] of TLimb;
  if bs = 0 then for var i := 0 to rl - 1 do buf[i] := pa[ls + i]
  else MpnRshift(@buf[0], @pa[ls], rl, bs);
  // only the top limb can shift to zero on a normalized operand
  if buf[rl - 1] = 0 then dec(rl);
  PutInline(@buf[0], rl, dst, rarr, rlen);
end;

// signed add of two small magnitudes given as zero-padded (ptr, len, neg)
// operands; dst/rarr/rlen/rneg are the destination record's storage fields
procedure SAddInlineP(pa: PLimb; alen: SizeInt; aneg: boolean; pb: PLimb; blen: SizeInt; bneg: boolean; dst: PLimb; var rarr: TLimbs; var rlen: SizeInt; out rneg: boolean);
begin
  if aneg = bneg then begin
    AddInline(pa, alen, pb, blen, dst, rarr, rlen);
    rneg := aneg and (rlen > 0);
    exit;
  end;
  var c := LCmpP(pa, alen, pb, blen);
  if c = 0 then begin
    PutZero(dst, rarr, rlen);
    rneg := false;
  end else if c > 0 then begin
    SubInline(pa, alen, pb, dst, rarr, rlen);
    rneg := aneg and (rlen > 0);
  end else begin
    SubInline(pb, blen, pa, dst, rarr, rlen);
    rneg := bneg and (rlen > 0);
  end;
end;

// (pa, alen) divMod (pb, blen) for alen up to twice the inline capacity and
// an inline divisor (blen in 1..BIGINT_INLINE_LIMBS): covers the common
// double-width-dividend division with no heap allocation. qb must hold alen
// limbs, rb MaxS(alen, blen) limbs (a < b leaves the whole dividend in rb).
// computes into caller stack buffers qb/rb, so results may alias the operands
procedure DivModInline(pa: PLimb; alen: SizeInt; pb: PLimb; blen: SizeInt; qb: PLimb; out qlen: SizeInt; rb: PLimb; out rlen: SizeInt);
var
  un: array[0..2 * BIGINT_INLINE_LIMBS] of TLimb;
  vn: array[0..BIGINT_INLINE_LIMBS - 1] of TLimb;
begin
  if LCmpP(pa, alen, pb, blen) < 0 then begin
    qlen := 0;
    for var i := 0 to alen - 1 do rb[i] := pa[i];
    rlen := alen;
    exit;
  end;
  if blen = 1 then begin
    var d := pb[0];
    var r: TLimb := 0;
    for var i := alen - 1 downto 0 do qb[i] := UDivLimb(r, pa[i], d, r);
    var mq := alen;
    while (mq > 0) and (qb[mq - 1] = 0) do dec(mq);
    qlen := mq;
    rb[0] := r;
    rlen := if r <> 0 then 1 else 0;
    exit;
  end;
  // Knuth algorithm D on stack buffers, same steps as LDivMod (alen >= blen >= 2)
  var n := blen;
  var m := alen;
  var s := LIMB_MASK - integer(LimbBsr(pb[n - 1]));
  if s = 0 then begin
    for var i := 0 to n - 1 do vn[i] := pb[i];
    for var i := 0 to m - 1 do un[i] := pa[i];
    un[m] := 0;
  end else begin
    MpnLshift(@vn[0], pb, n, s);
    un[m] := MpnLshift(@un[0], pa, m, s);
  end;
  var vTop := vn[n - 1];
  var vNext := vn[n - 2];
  for var j := m - n downto 0 do begin
    var qhat, rhat: TLimb;
    var doneAdjust := false;
    if un[j + n] = vTop then begin
      qhat := High(TLimb);
      rhat := un[j + n - 1] + vTop;
      doneAdjust := rhat < vTop;
    end else qhat := UDivLimb(un[j + n], un[j + n - 1], vTop, rhat);
    while not doneAdjust do begin
      var phi, plo: TLimb;
      UMulLimb(qhat, vNext, phi, plo);
      if (phi < rhat) or ((phi = rhat) and (plo <= un[j + n - 2])) then break;
      dec(qhat);
      rhat := rhat + vTop;
      doneAdjust := rhat < vTop;
    end;
    var borrow := MpnSubMul1(@un[j], @vn[0], n, qhat);
    var top := un[j + n];
    un[j + n] := top - borrow;
    if top < borrow then begin
      dec(qhat);
      un[j + n] := un[j + n] + MpnAddN(@un[j], @un[j], @vn[0], n);
    end;
    qb[j] := qhat;
  end;
  var ql := m - n + 1;
  while (ql > 0) and (qb[ql - 1] = 0) do dec(ql);
  qlen := ql;
  if s = 0 then for var i := 0 to n - 1 do rb[i] := un[i]
  else MpnRshift(rb, @un[0], n, s);
  var rl := n;
  while (rl > 0) and (rb[rl - 1] = 0) do dec(rl);
  rlen := rl;
end;


// all TLimbs-returning routines build into a fresh local and assign the result
// at the very end: the hidden result may alias an input (x := LAdd(x, y))
// pointer-based cores build the result array directly from (ptr, len) views,
// so operators never materialize an operand; the TLimbs entry points below
// are thin wrappers over them for array-based callers
function LAddP(pa: PLimb; la: SizeInt; pb: PLimb; lb: SizeInt): TLimbs;
var
  res: TLimbs;
begin
  if (la <= 2) and (lb <= 2) then begin
    // two-limb fast path: exact-size allocation, no trim
    var a0: TLimb := if la > 0 then pa[0] else 0;
    var a1: TLimb := if la > 1 then pa[1] else 0;
    var b1: TLimb := if lb > 1 then pb[1] else 0;
    var s0: TLimb := a0 + (if lb > 0 then pb[0] else 0);
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
  if la < lb then exit(LAddP(pb, lb, pa, la));
  if lb = 0 then exit(MakeLimbs(pa, la));
  res := LNew(la + 1);
  var carry := MpnAddN(@res[0], pa, pb, lb);
  res[la] := MpnAdd1(@res[lb], @pa[lb], la - lb, carry);
  LNorm(res);
  result := res;
end;

function LAdd(const a, b: TLimbs): TLimbs;
begin
  result := LAddP(PLimb(Pointer(a)), Length(a), PLimb(Pointer(b)), Length(b));
end;

// a - b, caller guarantees a >= b
function LSubP(pa: PLimb; la: SizeInt; pb: PLimb; lb: SizeInt): TLimbs;
var
  res: TLimbs;
begin
  if la <= 2 then begin
    // b is no longer than a here
    var a1: TLimb := if la > 1 then pa[1] else 0;
    var d0: TLimb := if la > 0 then pa[0] else 0;
    var b0: TLimb := if lb > 0 then pb[0] else 0;
    var brw: TLimb := TLimb(ord(d0 < b0));
    d0 := d0 - b0;
    var d1: TLimb := a1 - (if lb > 1 then pb[1] else 0) - brw;
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
  if lb = 0 then exit(MakeLimbs(pa, la));
  res := LNew(la);
  var borrow := MpnSubN(@res[0], pa, pb, lb);
  MpnSub1(@res[lb], @pa[lb], la - lb, borrow);
  LNorm(res);
  result := res;
end;

function LSub(const a, b: TLimbs): TLimbs;
begin
  result := LSubP(PLimb(Pointer(a)), Length(a), PLimb(Pointer(b)), Length(b));
end;

// a - b with underflow check
function LSubChecked(const a, b: TLimbs): TLimbs;
begin
  if LCmp(a, b) < 0 then RaiseNegativeUnsigned;
  result := LSub(a, b);
end;

function LMulBasicP(pa: PLimb; la: SizeInt; pb: PLimb; lb: SizeInt): TLimbs;
var
  res: TLimbs;
begin
  if (la = 0) or (lb = 0) then exit(nil);
  if (la = 1) and (lb = 1) then begin
    var hi, lo: TLimb;
    UMulLimb(pa[0], pb[0], hi, lo);
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
  if la < lb then exit(LMulBasicP(pb, lb, pa, la));
  if la = 2 then begin
    // 2x1 and 2x2 by hand: exact-size result, no trim
    var h0, l0, h1, l1: TLimb;
    UMulLimb(pa[0], pb[0], h0, l0);
    UMulLimb(pa[1], pb[0], h1, l1);
    var r1: TLimb := h0 + l1;
    var c: TLimb := TLimb(ord(r1 < h0));
    var r2: TLimb := h1 + c;
    var r3: TLimb := 0;
    if lb = 2 then begin
      var hx, lx: TLimb;
      UMulLimb(pa[0], pb[1], hx, lx);
      r1 := r1 + lx;
      c := TLimb(ord(r1 < lx));
      r2 := r2 + c;
      c := TLimb(ord(r2 < c));
      var t: TLimb := r2 + hx;
      c := c + TLimb(ord(t < hx));
      r2 := t;
      UMulLimb(pa[1], pb[1], hx, lx);
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
  res[la] := MpnMul1(@res[0], pa, la, pb[0]);
  {$ifdef BIGINT_ASM}
  // hoist the adx dispatch out of the row loop
  if UseAdx then begin
    for var j := 1 to lb - 1 do res[la + j] := MpnAddMul1Adx(@res[j], pa, la, pb[j]);
    LNorm(res);
    exit(res);
  end;
  {$endif}
  for var j := 1 to lb - 1 do res[la + j] := MpnAddMul1(@res[j], pa, la, pb[j]);
  LNorm(res);
  result := res;
end;

// schoolbook squaring: cross products once, doubled, plus the diagonal
function LSqrBasicP(pa: PLimb; la: SizeInt): TLimbs;
var
  res: TLimbs;
begin
  if la = 0 then exit(nil);
  if la = 1 then begin
    var hi, lo: TLimb;
    UMulLimb(pa[0], pa[0], hi, lo);
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
    res[la] := MpnMul1(@res[1], @pa[1], la - 1, pa[0]);
    for var i := 1 to la - 2 do res[la + i] := MpnAddMul1(@res[2 * i + 1], @pa[i + 1], la - 1 - i, pa[i]);
    // double the cross part
    MpnLshift(@res[0], @res[0], 2 * la, 1);
  end;
  // add the diagonal squares, tracking a single-bit carry between pairs
  var cy: TLimb := 0;
  for var i := 0 to la - 1 do begin
    var hi, lo: TLimb;
    UMulLimb(pa[i], pa[i], hi, lo);
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

// normalized copy of a[start..start+count-1] out of a (ptr, len) view
function LSliceP(pa: PLimb; la, start, count: SizeInt): TLimbs;
begin
  if start >= la then exit(nil);
  result := MakeLimbs(@pa[start], MinS(count, la - start));
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
function LMulKaraP(pa: PLimb; la: SizeInt; pb: PLimb; lb: SizeInt): TLimbs;
var
  res: TLimbs;
begin
  var m := (MaxS(la, lb) + 1) shr 1;
  var a0 := LSliceP(pa, la, 0, m);
  var a1 := LSliceP(pa, la, m, la);
  var b0 := LSliceP(pb, lb, 0, m);
  var b1 := LSliceP(pb, lb, m, lb);
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

function LSqrKaraP(pa: PLimb; la: SizeInt): TLimbs;
var
  res: TLimbs;
begin
  var m := (la + 1) shr 1;
  var a0 := LSliceP(pa, la, 0, m);
  var a1 := LSliceP(pa, la, m, la);
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
begin
  result := LDivModW(x, 3, _);
end;

// Toom-3: split into three k-limb parts, evaluate at 0, 1, -1, 2 and
// infinity, recombine five recursive products instead of nine
function LMulToom3P(pa: PLimb; la: SizeInt; pb: PLimb; lb: SizeInt): TLimbs;
var
  res: TLimbs;
begin
  var k := (MaxS(la, lb) + 2) div 3;
  var a0 := LSliceP(pa, la, 0, k);
  var a1 := LSliceP(pa, la, k, k);
  var a2 := LSliceP(pa, la, 2 * k, la);
  var b0 := LSliceP(pb, lb, 0, k);
  var b1 := LSliceP(pb, lb, k, k);
  var b2 := LSliceP(pb, lb, 2 * k, lb);
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

function LSqrToom3P(pa: PLimb; la: SizeInt): TLimbs;
var
  res: TLimbs;
begin
  var k := (la + 2) div 3;
  var a0 := LSliceP(pa, la, 0, k);
  var a1 := LSliceP(pa, la, k, k);
  var a2 := LSliceP(pa, la, 2 * k, la);
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

function LMulP(pa: PLimb; la: SizeInt; pb: PLimb; lb: SizeInt): TLimbs;
begin
  var mn := MinS(la, lb);
  if mn < BigIntKaratsubaThreshold then exit(LMulBasicP(pa, la, pb, lb));
  if (mn >= BigIntToom3Threshold) and (MaxS(la, lb) < 2 * mn) then exit(LMulToom3P(pa, la, pb, lb));
  result := LMulKaraP(pa, la, pb, lb);
end;

function LMul(const a, b: TLimbs): TLimbs;
begin
  result := LMulP(PLimb(Pointer(a)), Length(a), PLimb(Pointer(b)), Length(b));
end;

function LSqrP(pa: PLimb; la: SizeInt): TLimbs;
begin
  if la < BigIntKaratsubaThreshold then exit(LSqrBasicP(pa, la));
  if la >= BigIntToom3Threshold then exit(LSqrToom3P(pa, la));
  result := LSqrKaraP(pa, la);
end;

function LSqr(const a: TLimbs): TLimbs;
begin
  result := LSqrP(PLimb(Pointer(a)), Length(a));
end;

// a * w for a single-limb factor
function LMulWP(pa: PLimb; la: SizeInt; w: TLimb): TLimbs;
var
  res: TLimbs;
begin
  if (la = 0) or (w = 0) then exit(nil);
  res := LNew(la + 1);
  res[la] := MpnMul1(@res[0], pa, la, w);
  LNorm(res);
  result := res;
end;

function LMulW(const a: TLimbs; w: TLimb): TLimbs;
begin
  result := LMulWP(PLimb(Pointer(a)), Length(a), w);
end;

function LMulQP(pa: PLimb; la: SizeInt; q: QWord): TLimbs;
begin
  {$if LIMB_BITS = 64}
  result := LMulWP(pa, la, q);
  {$else}
  if q <= High(TLimb) then exit(LMulWP(pa, la, TLimb(q)));
  var qq := LFromQWord(q);
  result := LMulP(pa, la, PLimb(Pointer(qq)), Length(qq));
  {$endif}
end;

function LMulQ(const a: TLimbs; q: QWord): TLimbs;
begin
  result := LMulQP(PLimb(Pointer(a)), Length(a), q);
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

function LDivModWP(pa: PLimb; la: SizeInt; w: TLimb; out rem: TLimb): TLimbs;
var
  res: TLimbs;
begin
  res := LNew(la);
  var r: TLimb := 0;
  for var i := la - 1 downto 0 do res[i] := UDivLimb(r, pa[i], w, r);
  rem := r;
  LNorm(res);
  result := res;
end;

function LDivModW(const a: TLimbs; w: TLimb; out rem: TLimb): TLimbs;
begin
  result := LDivModWP(PLimb(Pointer(a)), Length(a), w, rem);
end;

// full division, Knuth algorithm D; v <> 0 guaranteed by callers
// q and r are out params, so callers must pass fresh locals, never anything
// that may alias u or v (managed out params are finalized on entry)
const
  // stack scratch for the normalized dividend+divisor in LDivModP: covers
  // divisions with up to a 4KB working set (32k-bit dividends on 64-bit
  // limbs) with no heap traffic and layout-independent addresses
  DIVMOD_STACK_LIMBS = 512;

procedure LDivModP(pu: PLimb; m: SizeInt; pv: PLimb; n: SizeInt; out q, r: TLimbs);
var
  scratch: TLimbs;
  stackBuf: array[0..DIVMOD_STACK_LIMBS - 1] of TLimb;
  rw: TLimb;
begin
  if LCmpP(pu, m, pv, n) < 0 then begin
    q := nil;
    r := MakeLimbs(pu, m);
    exit;
  end;
  if n = 1 then begin
    q := LDivModWP(pu, m, pv[0], rw);
    r := LFromQWord(rw);
    exit;
  end;
  // normalize so the top bit of vn[n-1] is set; un and vn share one scratch
  // block (un at 0, vn right after), on the stack whenever it fits
  var s := LIMB_MASK - integer(LimbBsr(pv[n - 1]));
  var un: PLimb := @stackBuf[0];
  if m + 1 + n > DIVMOD_STACK_LIMBS then begin
    scratch := LNew(m + 1 + n);
    un := @scratch[0];
  end;
  var vn: PLimb := @un[m + 1];
  if s = 0 then begin
    Move(pv^, vn[0], n * SizeOf(TLimb));
    Move(pu^, un[0], m * SizeOf(TLimb));
    un[m] := 0;
  end else begin
    MpnLshift(@vn[0], pv, n, s);
    un[m] := MpnLshift(@un[0], pu, m, s);
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

procedure LDivMod(const u, v: TLimbs; out q, r: TLimbs);
begin
  LDivModP(PLimb(Pointer(u)), Length(u), PLimb(Pointer(v)), Length(v), q, r);
end;

// barrett reciprocal mu = floor(B^(2n) / d), n = limb count of d; precomputed
// once per fixed divisor so repeated divisions become multiplications
function LReciprocal(const d: TLimbs): TLimbs;
var
  q, r: TLimbs;
begin
  var n := Length(d);
  var bpow := LNewZ(2 * n + 1);
  bpow[2 * n] := 1;
  LDivMod(bpow, d, q, r);
  result := q;
end;

// floor/mod of x by the fixed d whose barrett reciprocal mu is precomputed;
// requires x < d^2 (the toString split keeps nd <= 2*D, so a < 10^(2D) = d^2).
// HAC 14.42: the estimate underestimates the quotient by at most 2, fixed below
procedure LBarrettDivMod(const x, d, mu: TLimbs; out q, r: TLimbs);
var
  qh, rr: TLimbs;
begin
  var n := Length(d);
  if LCmp(x, d) < 0 then begin
    q := nil;
    r := Copy(x);
    exit;
  end;
  var lx := Length(x);
  // q1 = x div B^(n-1), then q3 = (q1 * mu) div B^(n+1) estimates the quotient
  var q1 := Copy(x, n - 1, lx - (n - 1));
  var q2 := LMul(q1, mu);
  var lq2 := Length(q2);
  if lq2 > n + 1 then qh := Copy(q2, n + 1, lq2 - (n + 1)) else qh := nil;
  rr := LSub(x, LMul(qh, d));
  while LCmp(rr, d) >= 0 do begin
    rr := LSub(rr, d);
    qh := LAdd(qh, LFromQWord(1));
  end;
  LNorm(qh);
  LNorm(rr);
  q := qh;
  r := rr;
end;

function LShlP(pa: PLimb; la: SizeInt; n: LongWord): TLimbs;
var
  res: TLimbs;
begin
  if la = 0 then exit(nil);
  if n = 0 then exit(MakeLimbs(pa, la));
  var limbShift := SizeInt(n shr LIMB_SHIFT);
  var bitShift := integer(n and LIMB_MASK);
  res := LNew(la + limbShift + 1);
  if limbShift > 0 then FillChar(res[0], limbShift * SizeOf(TLimb), 0);
  if bitShift = 0 then begin
    Move(pa^, res[limbShift], la * SizeOf(TLimb));
    res[la + limbShift] := 0;
  end else res[la + limbShift] := MpnLshift(@res[limbShift], pa, la, bitShift);
  LNorm(res);
  result := res;
end;

function LShl(const a: TLimbs; n: LongWord): TLimbs;
begin
  result := LShlP(PLimb(Pointer(a)), Length(a), n);
end;

function LShrP(pa: PLimb; la: SizeInt; n: LongWord): TLimbs;
var
  res: TLimbs;
begin
  if la = 0 then exit(nil);
  if n = 0 then exit(MakeLimbs(pa, la));
  var limbShift := SizeInt(n shr LIMB_SHIFT);
  if limbShift >= la then exit(nil);
  var bitShift := integer(n and LIMB_MASK);
  var rl := la - limbShift;
  res := LNew(rl);
  if bitShift = 0 then Move(pa[limbShift], res[0], rl * SizeOf(TLimb))
  else MpnRshift(@res[0], @pa[limbShift], rl, bitShift);
  LNorm(res);
  result := res;
end;

function LShr(const a: TLimbs; n: LongWord): TLimbs;
begin
  result := LShrP(PLimb(Pointer(a)), Length(a), n);
end;

function LAndP(pa: PLimb; la: SizeInt; pb: PLimb; lb: SizeInt): TLimbs;
var
  res: TLimbs;
begin
  var n := MinS(la, lb);
  while (n > 0) and ((pa[n - 1] and pb[n - 1]) = 0) do dec(n);
  if n = 0 then exit(nil);
  res := LNew(n);
  for var i := 0 to n - 1 do res[i] := pa[i] and pb[i];
  result := res;
end;

function LAnd(const a, b: TLimbs): TLimbs;
begin
  result := LAndP(PLimb(Pointer(a)), Length(a), PLimb(Pointer(b)), Length(b));
end;

function LOrP(pa: PLimb; la: SizeInt; pb: PLimb; lb: SizeInt): TLimbs;
var
  res: TLimbs;
begin
  if la < lb then exit(LOrP(pb, lb, pa, la));
  if la = 0 then exit(nil);
  res := LNew(la);
  for var i := 0 to lb - 1 do res[i] := pa[i] or pb[i];
  if la > lb then Move(pa[lb], res[lb], (la - lb) * SizeOf(TLimb));
  result := res;
end;

function LOr(const a, b: TLimbs): TLimbs;
begin
  result := LOrP(PLimb(Pointer(a)), Length(a), PLimb(Pointer(b)), Length(b));
end;

function LXorP(pa: PLimb; la: SizeInt; pb: PLimb; lb: SizeInt): TLimbs;
var
  res: TLimbs;
begin
  if la < lb then exit(LXorP(pb, lb, pa, la));
  // equal lengths: top limbs may cancel, trim before allocating
  var n := la;
  if la = lb then begin
    while (n > 0) and ((pa[n - 1] xor pb[n - 1]) = 0) do dec(n);
    if n = 0 then exit(nil);
  end;
  res := LNew(n);
  var m := MinS(n, lb);
  for var i := 0 to m - 1 do res[i] := pa[i] xor pb[i];
  if n > lb then Move(pa[lb], res[lb], (n - lb) * SizeOf(TLimb));
  result := res;
end;

function LXor(const a, b: TLimbs): TLimbs;
begin
  result := LXorP(PLimb(Pointer(a)), Length(a), PLimb(Pointer(b)), Length(b));
end;

function LBitLenP(p: PLimb; len: SizeInt): LongWord; inline;
begin
  if len = 0 then exit(0);
  result := LongWord(len - 1) * LIMB_BITS + LimbBsr(p[len - 1]) + 1;
end;

function LBitLen(const a: TLimbs): LongWord;
begin
  result := LBitLenP(PLimb(Pointer(a)), Length(a));
end;

function LTestBitP(p: PLimb; len: SizeInt; i: LongWord): boolean; inline;
begin
  var limb := SizeInt(i shr LIMB_SHIFT);
  if limb >= len then exit(false);
  result := (p[limb] shr (i and LIMB_MASK)) and 1 <> 0;
end;

function LTestBit(const a: TLimbs; i: LongWord): boolean;
begin
  result := LTestBitP(PLimb(Pointer(a)), Length(a), i);
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
  PARSE_DC_DIGITS = 900; // wide linear parse stays ahead of D&C further out
  // below this divisor limb count Knuth division still beats the two barrett
  // multiplies, so only large split powers take the reciprocal path
  BARRETT_MIN_LIMBS = 160;

var
  // shared base-10 split powers, DecDCPows[i] = chunkBase^(2^i), grown on
  // demand and reused across every base-10 parse/toString (single-threaded)
  DecDCPows: array of TLimbs;
  // barrett reciprocals aligned with DecDCPows, so toString divides by each
  // fixed split power via multiply instead of Knuth long division
  DecDCRecip: array of TLimbs;

// grow the shared base-10 split-power cache to cover levels 0..maxLevel
procedure EnsureDecDCPows(maxLevel: integer; chunkBase: TLimb);
begin
  var old := Length(DecDCPows);
  if maxLevel < old then exit;
  SetLength(DecDCPows, maxLevel + 1);
  SetLength(DecDCRecip, maxLevel + 1);
  if old = 0 then begin
    DecDCPows[0] := LFromQWord(chunkBase);
    DecDCRecip[0] := LReciprocal(DecDCPows[0]);
    old := 1;
  end;
  for var i := old to maxLevel do begin
    DecDCPows[i] := LSqr(DecDCPows[i - 1]);
    DecDCRecip[i] := LReciprocal(DecDCPows[i]);
  end;
end;

// linear conversion core: right-align the digits of a into buf[0..nd-1] and
// left-pad with zeros; a is a scratch copy this routine destroys. on 64-bit
// limbs two chunkBase divisions run per loop so the loop and pad bookkeeping
// amortize over 2*chunkLen digits
procedure LToBaseLinear(a: TLimbs; base: integer; chunkBase: TLimb; chunkLen: integer; buf: PAnsiChar; nd: SizeInt);
{$if LIMB_BITS = 64}
begin
  var p := nd - 1;
  var alen := Length(a);
  var b := TLimb(base);
  while alen > 0 do begin
    var r0 := LDivWInPlaceLen(a, alen, chunkBase);
    if alen > 0 then begin
      var r1 := LDivWInPlaceLen(a, alen, chunkBase);
      for var i := 1 to chunkLen do begin buf[p] := DIGIT_CHARS[r0 mod b + 1]; r0 := r0 div b; dec(p); end;
      if alen > 0 then
        for var i := 1 to chunkLen do begin buf[p] := DIGIT_CHARS[r1 mod b + 1]; r1 := r1 div b; dec(p); end
      else
        repeat buf[p] := DIGIT_CHARS[r1 mod b + 1]; r1 := r1 div b; dec(p); until r1 = 0;
    end else
      repeat buf[p] := DIGIT_CHARS[r0 mod b + 1]; r0 := r0 div b; dec(p); until r0 = 0;
  end;
  while p >= 0 do begin buf[p] := '0'; dec(p); end;
end;
{$else}
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
{$endif}

// divide-and-conquer digits writer: split off the low base^k digits with one
// division against a precomputed power, recurse into both halves. for base 10
// the divisor is a fixed cached power, so barrett reciprocal division (two
// multiplies) replaces the Knuth long division once the divisor is large
procedure LToBaseRec(const a: TLimbs; base: integer; chunkBase: TLimb; chunkLen: integer; buf: PAnsiChar; nd: SizeInt; const pows, recips: array of TLimbs; level: integer);
var
  q, r: TLimbs;
begin
  if (level < 0) or (nd <= TOSTR_DC_DIGITS) then begin
    LToBaseLinear(Copy(a), base, chunkBase, chunkLen, buf, nd);
    exit;
  end;
  var k := chunkLen shl level;
  if k >= nd then begin
    LToBaseRec(a, base, chunkBase, chunkLen, buf, nd, pows, recips, level - 1);
    exit;
  end;
  // the split invariant nd <= 2*k keeps a < pows[level]^2, so barrett is valid
  if (Length(recips) > 0) and (Length(pows[level]) >= BARRETT_MIN_LIMBS) then LBarrettDivMod(a, pows[level], recips[level], q, r)
  else LDivMod(a, pows[level], q, r);
  LToBaseRec(q, base, chunkBase, chunkLen, buf, nd - k, pows, recips, level - 1);
  LToBaseRec(r, base, chunkBase, chunkLen, buf + (nd - k), k, pows, recips, level - 1);
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
  var cap := SizeInt(Trunc(LBitLen(a) / (Ln(base) / Ln(2)))) + 2;
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
    if base = 10 then begin
      EnsureDecDCPows(maxLevel, chunkBase);
      LToBaseRec(a, base, chunkBase, chunkLen, PAnsiChar(buf), cap, DecDCPows, DecDCRecip, maxLevel);
    end else begin
      SetLength(pows, maxLevel + 1);
      pows[0] := LFromQWord(chunkBase);
      for var i := 1 to maxLevel do pows[i] := LSqr(pows[i - 1]);
      LToBaseRec(a, base, chunkBase, chunkLen, PAnsiChar(buf), cap, pows, [], maxLevel);
    end;
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

// a := a * (mHi:mLo) + (addHi:addLo); a must not be shared, scratch supplies a
// live copy of the multiplicand and must hold at least Length(a) limbs
{$if LIMB_BITS = 64}
procedure LMulAdd2WInPlace(var a, scratch: TLimbs; mHi, mLo, addHi, addLo: TLimb);
begin
  var la := Length(a);
  if la = 0 then begin
    if addHi <> 0 then begin
      SetLength(a, 2);
      a[0] := addLo;
      a[1] := addHi;
    end else if addLo <> 0 then begin
      SetLength(a, 1);
      a[0] := addLo;
    end;
    exit;
  end;
  Move(a[0], scratch[0], la * SizeOf(TLimb));
  SetLength(a, la + 2);
  a[la] := MpnMul1(@a[0], @scratch[0], la, mLo);
  a[la + 1] := MpnAddMul1(@a[1], @scratch[0], la, mHi);
  // fold the 2-limb addend into the low limbs, propagate the carry upward
  var lo := a[0] + addLo;
  var carry: TLimb := ord(lo < addLo);
  a[0] := lo;
  var s := a[1] + addHi;
  var c2: TLimb := ord(s < addHi);
  s := s + carry;
  inc(c2, ord(s < carry));
  a[1] := s;
  var i := 2;
  while (c2 <> 0) and (i < Length(a)) do begin
    var t := a[i] + c2;
    c2 := ord(t < c2);
    a[i] := t;
    inc(i);
  end;
  LNorm(a);
end;
{$endif}

// linear parse core: chunked multiply-add over count digit values; on 64-bit
// limbs two limb-chunks (2*chunkLen digits) fold in per multiply-add, halving
// the number of big-integer passes
function LFromDigitsLinear(digits: PByte; count: SizeInt; base: integer; chunkBase: TLimb; chunkLen: integer): TLimbs;
{$if LIMB_BITS = 64}
begin
  result := nil;
  var b := TLimb(base);
  var cbHi, cbLo: TLimb;
  UMulLimb(chunkBase, chunkBase, cbHi, cbLo); // wide chunk base = chunkBase^2
  var wideLen := chunkLen * 2;
  var scratch: TLimbs := nil;
  if count > wideLen then SetLength(scratch, count div chunkLen + 4);
  var pos: SizeInt := 0;
  var firstLen := count mod wideLen;
  if firstLen > 0 then begin
    var hiPart: TLimb := 0;
    var loPart: TLimb := 0;
    if firstLen > chunkLen then begin
      for var i := 1 to firstLen - chunkLen do begin hiPart := hiPart * b + digits[pos]; inc(pos); end;
      for var i := 1 to chunkLen do begin loPart := loPart * b + digits[pos]; inc(pos); end;
      var wHi, wLo: TLimb;
      UMulLimb(hiPart, chunkBase, wHi, wLo);
      wLo := wLo + loPart;
      inc(wHi, ord(wLo < loPart));
      if wHi <> 0 then begin SetLength(result, 2); result[0] := wLo; result[1] := wHi; end
      else if wLo <> 0 then begin SetLength(result, 1); result[0] := wLo; end;
    end else begin
      for var i := 1 to firstLen do begin loPart := loPart * b + digits[pos]; inc(pos); end;
      if loPart <> 0 then begin SetLength(result, 1); result[0] := loPart; end;
    end;
  end;
  while pos < count do begin
    var hiPart: TLimb := 0;
    var loPart: TLimb := 0;
    for var i := 1 to chunkLen do begin hiPart := hiPart * b + digits[pos]; inc(pos); end;
    for var i := 1 to chunkLen do begin loPart := loPart * b + digits[pos]; inc(pos); end;
    var wHi, wLo: TLimb;
    UMulLimb(hiPart, chunkBase, wHi, wLo);
    wLo := wLo + loPart;
    inc(wHi, ord(wLo < loPart));
    LMulAdd2WInPlace(result, scratch, cbHi, cbLo, wHi, wLo);
  end;
end;
{$else}
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
{$endif}

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
  if base = 10 then begin
    EnsureDecDCPows(maxLevel, chunkBase);
    result := LFromDigitsRec(@digits[0], count, base, chunkBase, chunkLen, DecDCPows, maxLevel);
  end else begin
    SetLength(pows, maxLevel + 1);
    pows[0] := LFromQWord(chunkBase);
    for var i := 1 to maxLevel do pows[i] := LSqr(pows[i - 1]);
    result := LFromDigitsRec(@digits[0], count, base, chunkBase, chunkLen, pows, maxLevel);
  end;
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
  USetQWord(@result.fInline[0], result.fArr, result.fLen, QWord(x));
end;

class operator UBigInt.:=(x: QWord): UBigInt;
begin
  USetQWord(@result.fInline[0], result.fArr, result.fLen, x);
end;

class operator UBigInt.:=(const s: string): UBigInt;
begin
  result := UBigInt.parse(s);
end;

// double bit test: a biased exponent of all ones marks NaN or infinity
function DblIsNanOrInf(d: Double): boolean;
begin
  var bits: QWord;
  Move(d, bits, 8);
  result := (bits shr 52) and $7FF = $7FF;
end;

// integer mantissa and base-2 exponent of a finite |d| >= 1: |d| = m * 2^e
procedure DblIntParts(d: Double; out m: QWord; out e: integer);
begin
  var bits: QWord;
  Move(d, bits, 8);
  m := (bits and ((QWord(1) shl 52) - 1)) or (QWord(1) shl 52);
  e := integer((bits shr 52) and $7FF) - 1075;
end;

// positive infinity of the native float type
function FltPosInf: Extended;
begin
{$ifdef FPC_HAS_TYPE_EXTENDED}
  var m: QWord := QWord($8000000000000000);
  var xe: Word := $7FFF;
  Move(m, PByte(@result)[0], 8);
  Move(xe, PByte(@result)[8], 2);
{$else}
  var bits: QWord := QWord($7FF0000000000000);
  Move(bits, result, 8);
{$endif}
end;

// x * 2^n for the native float type, correctly rounded including subnormals;
// steps through in-range powers so an out-of-range 2^n is never formed on its own
function FltLdexp(x: Extended; n: integer): Extended;
{$ifdef FPC_HAS_TYPE_EXTENDED}
  function pow2(k: integer): Extended; // 2^k, k in [-16382, 16383]
  begin
    var m: QWord := QWord(1) shl 63;
    var xe: Word := Word(k + 16383);
    Move(m, PByte(@result)[0], 8);
    Move(xe, PByte(@result)[8], 2);
  end;
begin
  result := x;
  if n > 16383 then begin
    result := result * pow2(16383);
    dec(n, 16383);
    if n > 16383 then begin
      result := result * pow2(16383);
      dec(n, 16383);
      if n > 16383 then n := 16383;
    end;
  end else if n < -16382 then begin
    result := result * pow2(-16318);
    inc(n, 16318);
    if n < -16382 then begin
      result := result * pow2(-16318);
      inc(n, 16318);
      if n < -16382 then n := -16382;
    end;
  end;
  result := result * pow2(n);
end;
{$else}
  function pow2(k: integer): Double; // 2^k, k in [-1022, 1023]
  begin
    var bits: QWord := QWord(k + 1023) shl 52;
    Move(bits, result, 8);
  end;
begin
  var y: Double := x;
  if n > 1023 then begin
    y := y * pow2(1023);
    dec(n, 1023);
    if n > 1023 then begin
      y := y * pow2(1023);
      dec(n, 1023);
      if n > 1023 then n := 1023;
    end;
  end else if n < -1022 then begin
    y := y * pow2(-969);
    inc(n, 969);
    if n < -1022 then begin
      y := y * pow2(-969);
      inc(n, 969);
      if n < -1022 then n := -1022;
    end;
  end;
  result := y * pow2(n);
end;
{$endif}

class operator UBigInt.explicit(d: Double): UBigInt;
begin
  if DblIsNanOrInf(d) then raise EConvertError.Create('cannot convert NaN or Inf to UBigInt');
  if d <= -1.0 then RaiseNegativeUnsigned;
  if System.Abs(d) < 1.0 then exit(default(UBigInt));
  // 53-bit integer mantissa scaled by its base-2 exponent
  DblIntParts(d, var q, var e);
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
  result := a.toUInt64;
end;

class operator UBigInt.explicit(const a: UBigInt): LongInt;
begin
  result := a.toInt32;
end;

class operator UBigInt.explicit(const a: UBigInt): LongWord;
begin
  result := a.toUInt32;
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
  if (a.fArr = nil) and (b.fArr = nil) then begin
    AddInline(@a.fInline[0], a.fLen, @b.fInline[0], b.fLen, @result.fInline[0], result.fArr, result.fLen);
    exit;
  end;
  var t := LAddP(a.dataPtr, a.fLen, b.dataPtr, b.fLen);
  MoveArr(t, @result.fInline[0], result.fArr, result.fLen);
end;

class operator UBigInt.+(const a: UBigInt; b: Int64): UBigInt;
begin
  if a.fArr = nil then begin
    var bb: array[0..BIGINT_INLINE_LIMBS - 1] of TLimb;
    var bl := QToInline(if b >= 0 then QWord(b) else NegAbs64(b), @bb[0]);
    if b >= 0 then AddInline(@a.fInline[0], a.fLen, @bb[0], bl, @result.fInline[0], result.fArr, result.fLen)
    else begin
      var c := LCmpP(@a.fInline[0], a.fLen, @bb[0], bl);
      if c < 0 then RaiseNegativeUnsigned;
      if c = 0 then PutZero(@result.fInline[0], result.fArr, result.fLen)
      else SubInline(@a.fInline[0], a.fLen, @bb[0], @result.fInline[0], result.fArr, result.fLen);
    end;
    exit;
  end;
  // spilled a is at least BIGINT_INLINE_LIMBS + 1 limbs, so |a| > |b| always
  var bq: array[0..BIGINT_INLINE_LIMBS - 1] of TLimb;
  var bql := QToInline(if b >= 0 then QWord(b) else NegAbs64(b), @bq[0]);
  var t := if b >= 0 then LAddP(a.dataPtr, a.fLen, @bq[0], bql) else LSubP(a.dataPtr, a.fLen, @bq[0], bql);
  MoveArr(t, @result.fInline[0], result.fArr, result.fLen);
end;

class operator UBigInt.+(a: Int64; const b: UBigInt): UBigInt;
begin
  result := b + a;
end;

class operator UBigInt.-(const a, b: UBigInt): UBigInt;
begin
  if (a.fArr = nil) and (b.fArr = nil) then begin
    var c := LCmpP(@a.fInline[0], a.fLen, @b.fInline[0], b.fLen);
    if c < 0 then RaiseNegativeUnsigned;
    if c = 0 then PutZero(@result.fInline[0], result.fArr, result.fLen)
    else SubInline(@a.fInline[0], a.fLen, @b.fInline[0], @result.fInline[0], result.fArr, result.fLen);
    exit;
  end;
  if LCmpP(a.dataPtr, a.fLen, b.dataPtr, b.fLen) < 0 then RaiseNegativeUnsigned;
  var t := LSubP(a.dataPtr, a.fLen, b.dataPtr, b.fLen);
  MoveArr(t, @result.fInline[0], result.fArr, result.fLen);
end;

class operator UBigInt.-(const a: UBigInt; b: Int64): UBigInt;
begin
  if a.fArr = nil then begin
    var bb: array[0..BIGINT_INLINE_LIMBS - 1] of TLimb;
    var bl := QToInline(if b >= 0 then QWord(b) else NegAbs64(b), @bb[0]);
    if b < 0 then AddInline(@a.fInline[0], a.fLen, @bb[0], bl, @result.fInline[0], result.fArr, result.fLen)
    else begin
      var c := LCmpP(@a.fInline[0], a.fLen, @bb[0], bl);
      if c < 0 then RaiseNegativeUnsigned;
      if c = 0 then PutZero(@result.fInline[0], result.fArr, result.fLen)
      else SubInline(@a.fInline[0], a.fLen, @bb[0], @result.fInline[0], result.fArr, result.fLen);
    end;
    exit;
  end;
  // spilled a is at least BIGINT_INLINE_LIMBS + 1 limbs, so |a| > |b| always
  var bq: array[0..BIGINT_INLINE_LIMBS - 1] of TLimb;
  var bql := QToInline(if b >= 0 then QWord(b) else NegAbs64(b), @bq[0]);
  var t := if b >= 0 then LSubP(a.dataPtr, a.fLen, @bq[0], bql) else LAddP(a.dataPtr, a.fLen, @bq[0], bql);
  MoveArr(t, @result.fInline[0], result.fArr, result.fLen);
end;

class operator UBigInt.-(a: Int64; const b: UBigInt): UBigInt;
begin
  if a < 0 then RaiseNegativeUnsigned;
  result.fLimbs := LSubChecked(LFromQWord(QWord(a)), b.fLimbs);
end;

// dst := a + b in place: the row kernels tolerate rp = ap/bp overlap, so the
// sum lands straight in dst's buffer; a shared or too-small buffer is replaced
// by a fresh one carrying BigIntGrowLimbs limbs of headroom
procedure addTo(var dst: UBigInt; const a, b: UBigInt);
begin
  var pa := a.dataPtr;
  var la := a.fLen;
  var pb := b.dataPtr;
  var lb := b.fLen;
  if lb = 0 then begin
    if @dst <> @a then dst := a;
    exit;
  end;
  if la = 0 then begin
    if @dst <> @b then dst := b;
    exit;
  end;
  if la < lb then begin var tp := pa; pa := pb; pb := tp; var tl := la; la := lb; lb := tl; end;
  if la < BIGINT_INLINE_LIMBS then begin
    // both operands live inline (zero-padded), the stack-buffered helper is alias-safe
    AddInline(pa, la, pb, lb, @dst.fInline[0], dst.fArr, dst.fLen);
    exit;
  end;
  var need := la + 1;
  var fresh: TLimbs := nil;
  var rp: PLimb;
  if (dst.fArr <> nil) and (Length(dst.fArr) >= need) and ArrUnshared(dst.fArr) then rp := PLimb(Pointer(dst.fArr))
  else begin
    fresh := LNew(need + BigIntGrowLimbs);
    rp := PLimb(Pointer(fresh));
  end;
  var carry := MpnAddN(rp, pa, pb, lb);
  var top := MpnAdd1(@rp[lb], @pa[lb], la - lb, carry);
  if top <> 0 then begin
    rp[la] := top;
    inc(la);
  end;
  if fresh <> nil then dst.fArr := fresh;
  dst.fLen := la;
end;

// dst := a - b in place; a >= b is required, equality zeroes dst
procedure subTo(var dst: UBigInt; const a, b: UBigInt);
begin
  var pa := a.dataPtr;
  var la := a.fLen;
  var pb := b.dataPtr;
  var lb := b.fLen;
  var c := LCmpP(pa, la, pb, lb);
  if c < 0 then RaiseNegativeUnsigned;
  if c = 0 then begin
    PutZero(@dst.fInline[0], dst.fArr, dst.fLen);
    exit;
  end;
  if lb = 0 then begin
    if @dst <> @a then dst := a;
    exit;
  end;
  if la <= BIGINT_INLINE_LIMBS then begin
    SubInline(pa, la, pb, @dst.fInline[0], dst.fArr, dst.fLen);
    exit;
  end;
  var fresh: TLimbs := nil;
  var rp: PLimb;
  if (dst.fArr <> nil) and (Length(dst.fArr) >= la) and ArrUnshared(dst.fArr) then rp := PLimb(Pointer(dst.fArr))
  else begin
    fresh := LNew(la + BigIntGrowLimbs);
    rp := PLimb(Pointer(fresh));
  end;
  var borrow := MpnSubN(rp, pa, pb, lb);
  MpnSub1(@rp[lb], @pa[lb], la - lb, borrow);
  var rl := la;
  while rp[rl - 1] = 0 do dec(rl);
  if rl <= BIGINT_INLINE_LIMBS then begin
    // spilled storage keeps fLen above the inline capacity, shrink back inline
    PutInline(rp, rl, @dst.fInline[0], dst.fArr, dst.fLen);
    exit;
  end;
  if fresh <> nil then dst.fArr := fresh;
  dst.fLen := rl;
end;

class operator UBigInt.*(const a, b: UBigInt): UBigInt;
begin
  if (a.fArr = nil) and (b.fArr = nil) then begin
    MulInline(@a.fInline[0], a.fLen, @b.fInline[0], b.fLen, @result.fInline[0], result.fArr, result.fLen);
    exit;
  end;
  var t := LMulP(a.dataPtr, a.fLen, b.dataPtr, b.fLen);
  MoveArr(t, @result.fInline[0], result.fArr, result.fLen);
end;

class operator UBigInt.*(const a: UBigInt; b: Int64): UBigInt;
begin
  if b < 0 then begin
    if a.fLen <> 0 then RaiseNegativeUnsigned;
    exit(default(UBigInt));
  end;
  if a.fArr = nil then begin
    var bb: array[0..BIGINT_INLINE_LIMBS - 1] of TLimb;
    var bl := QToInline(QWord(b), @bb[0]);
    MulInline(@a.fInline[0], a.fLen, @bb[0], bl, @result.fInline[0], result.fArr, result.fLen);
    exit;
  end;
  var t := LMulQP(a.dataPtr, a.fLen, QWord(b));
  MoveArr(t, @result.fInline[0], result.fArr, result.fLen);
end;

class operator UBigInt.*(a: Int64; const b: UBigInt): UBigInt;
begin
  result := b * a;
end;

class operator UBigInt.div(const a, b: UBigInt): UBigInt;
var
  q, r: TLimbs;
begin
  if b.fLen = 0 then RaiseDivByZero;
  if (b.fArr = nil) and (a.fLen <= 2 * BIGINT_INLINE_LIMBS) then begin
    var qb, rb: array[0..2 * BIGINT_INLINE_LIMBS - 1] of TLimb;
    DivModInline(a.dataPtr, a.fLen, @b.fInline[0], b.fLen, @qb[0], var ql, @rb[0], _);
    if ql <= BIGINT_INLINE_LIMBS then PutInline(@qb[0], ql, @result.fInline[0], result.fArr, result.fLen)
    else PutSpill(@qb[0], ql, result.fArr, result.fLen);
    exit;
  end;
  LDivModP(a.dataPtr, a.fLen, b.dataPtr, b.fLen, q, r);
  MoveArr(q, @result.fInline[0], result.fArr, result.fLen);
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
    if a.fLen <> 0 then RaiseNegativeUnsigned;
    exit(default(UBigInt));
  end;
  if a.fLen <= 2 * BIGINT_INLINE_LIMBS then begin
    var db: array[0..1] of TLimb;
    db[0] := TLimb(b);
    {$if LIMB_BITS = 64}
    var dl: SizeInt := 1;
    {$else}
    db[1] := TLimb(QWord(b) shr 32);
    var dl: SizeInt := if db[1] <> 0 then 2 else 1;
    {$endif}
    var qb, rb: array[0..2 * BIGINT_INLINE_LIMBS - 1] of TLimb;
    DivModInline(a.dataPtr, a.fLen, @db[0], dl, @qb[0], var ql, @rb[0], _);
    if ql <= BIGINT_INLINE_LIMBS then PutInline(@qb[0], ql, @result.fInline[0], result.fArr, result.fLen)
    else PutSpill(@qb[0], ql, result.fArr, result.fLen);
    exit;
  end;
  {$if LIMB_BITS = 64}
  var t := LDivModWP(a.dataPtr, a.fLen, TLimb(b), rw);
  MoveArr(t, @result.fInline[0], result.fArr, result.fLen);
  {$else}
  if QWord(b) <= High(TLimb) then begin
    var t := LDivModWP(a.dataPtr, a.fLen, TLimb(b), rw);
    MoveArr(t, @result.fInline[0], result.fArr, result.fLen);
  end else begin
    LDivMod(a.fLimbs, LFromQWord(QWord(b)), q, r);
    result.fLimbs := q;
  end;
  {$endif}
end;

class operator UBigInt.mod(const a, b: UBigInt): UBigInt;
var
  q, r: TLimbs;
begin
  if b.fLen = 0 then RaiseDivByZero;
  if (b.fArr = nil) and (a.fLen <= 2 * BIGINT_INLINE_LIMBS) then begin
    var qb, rb: array[0..2 * BIGINT_INLINE_LIMBS - 1] of TLimb;
    DivModInline(a.dataPtr, a.fLen, @b.fInline[0], b.fLen, @qb[0], _, @rb[0], var rl);
    // a < b leaves the whole dividend as the remainder, which can spill
    if rl <= BIGINT_INLINE_LIMBS then PutInline(@rb[0], rl, @result.fInline[0], result.fArr, result.fLen)
    else PutSpill(@rb[0], rl, result.fArr, result.fLen);
    exit;
  end;
  LDivModP(a.dataPtr, a.fLen, b.dataPtr, b.fLen, q, r);
  MoveArr(r, @result.fInline[0], result.fArr, result.fLen);
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
  if a.fLen <= 2 * BIGINT_INLINE_LIMBS then begin
    var db: array[0..1] of TLimb;
    db[0] := TLimb(m);
    {$if LIMB_BITS = 64}
    var dl: SizeInt := 1;
    {$else}
    db[1] := TLimb(m shr 32);
    var dl: SizeInt := if db[1] <> 0 then 2 else 1;
    {$endif}
    var qb, rb: array[0..2 * BIGINT_INLINE_LIMBS - 1] of TLimb;
    DivModInline(a.dataPtr, a.fLen, @db[0], dl, @qb[0], _, @rb[0], var rl);
    if rl <= BIGINT_INLINE_LIMBS then PutInline(@rb[0], rl, @result.fInline[0], result.fArr, result.fLen)
    else PutSpill(@rb[0], rl, result.fArr, result.fLen);
    exit;
  end;
  {$if LIMB_BITS = 64}
  LDivModWP(a.dataPtr, a.fLen, TLimb(m), rw);
  USetQWord(@result.fInline[0], result.fArr, result.fLen, rw);
  {$else}
  if m <= High(TLimb) then begin
    LDivModWP(a.dataPtr, a.fLen, TLimb(m), rw);
    USetQWord(@result.fInline[0], result.fArr, result.fLen, rw);
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
  if b.fLen = 0 then begin
    // x^0 = 1, including 0^0
    result.fLimbs := [1];
    exit;
  end;
  if a.fLen = 0 then exit(default(UBigInt));
  if a.isOne then exit(a);
  result.fLimbs := UPowQ(a.fLimbs, b.toUInt64);
end;

class operator UBigInt.**(const a: UBigInt; e: Int64): UBigInt;
begin
  if e < 0 then raise EBigIntError.Create('negative exponent for integer power');
  if e = 0 then begin
    result.fLimbs := [1];
    exit;
  end;
  if a.fLen = 0 then exit(default(UBigInt));
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
  if a.fLen = 0 then exit(default(UBigInt));
  if n > High(LongWord) then raise EBigIntError.Create('shift count out of range');
  if (a.fArr = nil) and (a.fLen + SizeInt(QWord(n) shr LIMB_SHIFT) <= BIGINT_INLINE_LIMBS) then begin
    ShlInline(@a.fInline[0], a.fLen, LongWord(n), @result.fInline[0], result.fArr, result.fLen);
    exit;
  end;
  var t := LShlP(a.dataPtr, a.fLen, LongWord(n));
  MoveArr(t, @result.fInline[0], result.fArr, result.fLen);
end;

class operator UBigInt.shr(const a: UBigInt; n: Int64): UBigInt;
begin
  if n < 0 then raise ERangeError.Create('negative shift count');
  if n > High(LongWord) then exit(default(UBigInt));
  if a.fArr = nil then begin
    ShrInline(@a.fInline[0], a.fLen, LongWord(n), @result.fInline[0], result.fArr, result.fLen);
    exit;
  end;
  var t := LShrP(a.dataPtr, a.fLen, LongWord(n));
  MoveArr(t, @result.fInline[0], result.fArr, result.fLen);
end;

class operator UBigInt.and(const a, b: UBigInt): UBigInt;
begin
  if (a.fArr = nil) or (b.fArr = nil) then begin
    AndInline(a.dataPtr, a.fLen, b.dataPtr, b.fLen, @result.fInline[0], result.fArr, result.fLen);
    exit;
  end;
  var t := LAndP(a.dataPtr, a.fLen, b.dataPtr, b.fLen);
  MoveArr(t, @result.fInline[0], result.fArr, result.fLen);
end;

class operator UBigInt.or(const a, b: UBigInt): UBigInt;
begin
  if (a.fArr = nil) and (b.fArr = nil) then begin
    OrInline(@a.fInline[0], @b.fInline[0], MaxS(a.fLen, b.fLen), @result.fInline[0], result.fArr, result.fLen);
    exit;
  end;
  var t := LOrP(a.dataPtr, a.fLen, b.dataPtr, b.fLen);
  MoveArr(t, @result.fInline[0], result.fArr, result.fLen);
end;

class operator UBigInt.xor(const a, b: UBigInt): UBigInt;
begin
  if (a.fArr = nil) and (b.fArr = nil) then begin
    XorInline(@a.fInline[0], @b.fInline[0], MaxS(a.fLen, b.fLen), @result.fInline[0], result.fArr, result.fLen);
    exit;
  end;
  var t := LXorP(a.dataPtr, a.fLen, b.dataPtr, b.fLen);
  MoveArr(t, @result.fInline[0], result.fArr, result.fLen);
end;

class operator UBigInt.=(const a, b: UBigInt): boolean;
begin
  result := a.equals(b);
end;

class operator UBigInt.=(const a: UBigInt; b: Int64): boolean;
begin
  result := (b >= 0) and (LCmpQP(a.dataPtr, a.fLen, QWord(b)) = 0);
end;

class operator UBigInt.=(a: Int64; const b: UBigInt): boolean;
begin
  result := b = a;
end;

class operator UBigInt.<>(const a, b: UBigInt): boolean;
begin
  result := not a.equals(b);
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
  result := ULessU(a, b);
end;

class operator UBigInt.<(const a: UBigInt; b: Int64): boolean;
begin
  result := (b > 0) and (LCmpQP(a.dataPtr, a.fLen, QWord(b)) < 0);
end;

class operator UBigInt.<(a: Int64; const b: UBigInt): boolean;
begin
  result := (a < 0) or (LCmpQP(b.dataPtr, b.fLen, QWord(a)) > 0);
end;

class operator UBigInt.<=(const a, b: UBigInt): boolean;
begin
  result := not ULessU(b, a);
end;

class operator UBigInt.<=(const a: UBigInt; b: Int64): boolean;
begin
  result := (b >= 0) and (LCmpQP(a.dataPtr, a.fLen, QWord(b)) <= 0);
end;

class operator UBigInt.<=(a: Int64; const b: UBigInt): boolean;
begin
  result := (a < 0) or (LCmpQP(b.dataPtr, b.fLen, QWord(a)) >= 0);
end;

class operator UBigInt.>(const a, b: UBigInt): boolean;
begin
  result := ULessU(b, a);
end;

class operator UBigInt.>(const a: UBigInt; b: Int64): boolean;
begin
  result := (b < 0) or (LCmpQP(a.dataPtr, a.fLen, QWord(b)) > 0);
end;

class operator UBigInt.>(a: Int64; const b: UBigInt): boolean;
begin
  result := (a > 0) and (LCmpQP(b.dataPtr, b.fLen, QWord(a)) < 0);
end;

class operator UBigInt.>=(const a, b: UBigInt): boolean;
begin
  result := not ULessU(a, b);
end;

class operator UBigInt.>=(const a: UBigInt; b: Int64): boolean;
begin
  result := (b < 0) or (LCmpQP(a.dataPtr, a.fLen, QWord(b)) >= 0);
end;

class operator UBigInt.>=(a: Int64; const b: UBigInt): boolean;
begin
  result := (a >= 0) and (LCmpQP(b.dataPtr, b.fLen, QWord(a)) <= 0);
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

function UBigInt.toInt8: Int8;
begin
  if not fitsInInt8 then raise ERangeError.Create('UBigInt value does not fit in Int8');
  result := Int8(LToQWordP(dataPtr, fLen));
end;

function UBigInt.toUInt8: UInt8;
begin
  if not fitsInUInt8 then raise ERangeError.Create('UBigInt value does not fit in UInt8');
  result := UInt8(LToQWordP(dataPtr, fLen));
end;

function UBigInt.toInt16: Int16;
begin
  if not fitsInInt16 then raise ERangeError.Create('UBigInt value does not fit in Int16');
  result := Int16(LToQWordP(dataPtr, fLen));
end;

function UBigInt.toUInt16: UInt16;
begin
  if not fitsInUInt16 then raise ERangeError.Create('UBigInt value does not fit in UInt16');
  result := UInt16(LToQWordP(dataPtr, fLen));
end;

function UBigInt.toInt32: Int32;
begin
  if not fitsInInt32 then raise ERangeError.Create('UBigInt value does not fit in Int32');
  result := Int32(LToQWordP(dataPtr, fLen));
end;

function UBigInt.toUInt32: UInt32;
begin
  if not fitsInUInt32 then raise ERangeError.Create('UBigInt value does not fit in UInt32');
  result := UInt32(LToQWordP(dataPtr, fLen));
end;

function UBigInt.toInt64: Int64;
begin
  if not fitsInInt64 then raise ERangeError.Create('UBigInt value does not fit in Int64');
  result := Int64(LToQWordP(dataPtr, fLen));
end;

function UBigInt.toUInt64: UInt64;
begin
  if not fitsInUInt64 then raise ERangeError.Create('UBigInt value does not fit in UInt64');
  result := LToQWordP(dataPtr, fLen);
end;

{$ifdef BIGINT_HAS_INT128}
function UBigInt.toInt128: Int128;
begin
  if not fitsInInt128 then raise ERangeError.Create('UBigInt value does not fit in Int128');
  result := Int128((UInt128(LExtract64(fLimbs, 64)) shl 64) or UInt128(LExtract64(fLimbs, 0)));
end;

function UBigInt.toUInt128: UInt128;
begin
  if not fitsInUInt128 then raise ERangeError.Create('UBigInt value does not fit in UInt128');
  result := (UInt128(LExtract64(fLimbs, 64)) shl 64) or UInt128(LExtract64(fLimbs, 0));
end;
{$endif}

function UBigInt.toDouble: Double;
begin
  var bits := bitLength;
  if bits = 0 then exit(0.0);
  if bits <= 64 then exit(LToQWordP(dataPtr, fLen));
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
  result := Double(FltLdexp(Extended(q), e));
end;

function UBigInt.fitsInInt8: boolean;
begin
  result := bitLength <= 7;
end;

function UBigInt.fitsInUInt8: boolean;
begin
  result := bitLength <= 8;
end;

function UBigInt.fitsInInt16: boolean;
begin
  result := bitLength <= 15;
end;

function UBigInt.fitsInUInt16: boolean;
begin
  result := bitLength <= 16;
end;

function UBigInt.fitsInInt32: boolean;
begin
  result := bitLength <= 31;
end;

function UBigInt.fitsInUInt32: boolean;
begin
  result := bitLength <= 32;
end;

function UBigInt.fitsInInt64: boolean;
begin
  result := bitLength <= 63;
end;

function UBigInt.fitsInUInt64: boolean;
begin
  result := bitLength <= 64;
end;

{$ifdef BIGINT_HAS_INT128}
function UBigInt.fitsInInt128: boolean;
begin
  result := bitLength <= 127;
end;

function UBigInt.fitsInUInt128: boolean;
begin
  result := bitLength <= 128;
end;
{$endif}

function UBigInt.isZero: boolean;
begin
  result := fLen = 0;
end;

function UBigInt.isOne: boolean;
begin
  result := (fLen = 1) and (dataPtr[0] = 1);
end;

function UBigInt.isEven: boolean;
begin
  result := (fLen = 0) or (dataPtr[0] and 1 = 0);
end;

function UBigInt.isOdd: boolean;
begin
  result := (fLen > 0) and (dataPtr[0] and 1 = 1);
end;

function UBigInt.isPowerOfTwo: boolean;
begin
  result := popCount = 1;
end;

function UBigInt.sign: integer;
begin
  result := if fLen = 0 then 0 else 1;
end;

function UBigInt.bitLength: LongWord;
begin
  if fLen = 0 then exit(0);
  var p := dataPtr;
  result := LongWord(fLen) * LIMB_BITS - (LIMB_BITS - 1 - LimbBsr(p[fLen - 1]));
end;

function UBigInt.popCount: LongWord;
begin
  result := 0;
  var p := dataPtr;
  for var i := 0 to fLen - 1 do result := result + PopCnt(p[i]);
end;

function UBigInt.lowestSetBit: Int64;
begin
  var p := dataPtr;
  for var i := 0 to fLen - 1 do
    if p[i] <> 0 then exit(Int64(i) * LIMB_BITS + LimbBsf(p[i]));
  result := -1;
end;

function UBigInt.testBit(i: LongWord): boolean;
begin
  result := LTestBitP(dataPtr, fLen, i);
end;

procedure UBigInt.setBit(i: LongWord);
begin
  var limb := SizeInt(i shr LIMB_SHIFT);
  var mask := TLimb(1) shl (i and LIMB_MASK);
  if limb < fLen then begin
    // within the significant limbs: edit in place when the storage is ours
    if fArr = nil then begin
      fInline[limb] := fInline[limb] or mask;
      exit;
    end;
    if ArrUnshared(fArr) then begin
      fArr[limb] := fArr[limb] or mask;
      exit;
    end;
  end else if (fArr = nil) and (limb < BIGINT_INLINE_LIMBS) then begin
    // grows within the inline capacity: limbs above fLen are already zero
    fInline[limb] := mask;
    fLen := limb + 1;
    exit;
  end;
  var l := fLimbs;
  SetLength(l, MaxS(Length(l), limb + 1));
  l[limb] := l[limb] or mask;
  fLimbs := l;
end;

procedure UBigInt.clearBit(i: LongWord);
begin
  var limb := SizeInt(i shr LIMB_SHIFT);
  if limb >= fLen then exit;
  var mask := not (TLimb(1) shl (i and LIMB_MASK));
  if fArr = nil then begin
    fInline[limb] := fInline[limb] and mask;
    while (fLen > 0) and (fInline[fLen - 1] = 0) do dec(fLen);
    exit;
  end;
  if ArrUnshared(fArr) then begin
    // in place; a shortened value keeps its (now oversized) array
    fArr[limb] := fArr[limb] and mask;
    while (fLen > 0) and (fArr[fLen - 1] = 0) do dec(fLen);
    exit;
  end;
  var l := fLimbs;
  SetLength(l, Length(l)); // un-share: the getter may hand out fArr itself
  l[limb] := l[limb] and mask;
  fLimbs := l; // the setter normalizes
end;

procedure UBigInt.flipBit(i: LongWord);
begin
  var limb := SizeInt(i shr LIMB_SHIFT);
  var mask := TLimb(1) shl (i and LIMB_MASK);
  if limb < fLen then begin
    if fArr = nil then begin
      fInline[limb] := fInline[limb] xor mask;
      while (fLen > 0) and (fInline[fLen - 1] = 0) do dec(fLen);
      exit;
    end;
    if ArrUnshared(fArr) then begin
      fArr[limb] := fArr[limb] xor mask;
      while (fLen > 0) and (fArr[fLen - 1] = 0) do dec(fLen);
      exit;
    end;
  end else if (fArr = nil) and (limb < BIGINT_INLINE_LIMBS) then begin
    fInline[limb] := mask;
    fLen := limb + 1;
    exit;
  end;
  var l := fLimbs;
  SetLength(l, MaxS(Length(l), limb + 1));
  l[limb] := l[limb] xor mask;
  fLimbs := l;
end;

function UBigInt.complement(width: LongWord): UBigInt;
var
  res: TLimbs;
begin
  if width = 0 then exit(default(UBigInt));
  var n := SizeInt((QWord(width) + LIMB_MASK) shr LIMB_SHIFT);
  SetLength(res, n);
  for var i := 0 to n - 1 do res[i] := if i < fLen then not fLimbs[i] else High(TLimb);
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

function UBigInt.compare(const other: UBigInt): integer; inline;
begin
  result := LCmpP(dataPtr, fLen, other.dataPtr, other.fLen);
end;


function UBigInt.equals(const other: UBigInt): boolean; inline;
begin
  if fLen <> other.fLen then exit(false);
  var pa := dataPtr;
  var pb := other.dataPtr;
  for var i := 0 to fLen - 1 do
    if pa[i] <> pb[i] then exit(false);
  result := true;
end;

function UBigInt.equalsCT(const other: UBigInt): boolean;
begin
  var pa := dataPtr;
  var pb := other.dataPtr;
  var la := fLen;
  var lb := other.fLen;
  // every limb folds into one accumulator; the index tests branch on limb
  // counts only, never on limb contents
  var diff := TLimb(la) xor TLimb(lb);
  for var i := 0 to MaxS(la, lb) - 1 do begin
    var a := if i < la then pa[i] else 0;
    var b := if i < lb then pb[i] else 0;
    diff := diff or (a xor b);
  end;
  result := diff = 0;
end;

function UBigInt.compareCT(const other: UBigInt): integer;
begin
  var pa := dataPtr;
  var pb := other.dataPtr;
  var la := fLen;
  var lb := other.fLen;
  // top-down scan keeping the first decided direction, no early exit
  var gt: LongWord := 0;
  var lt: LongWord := 0;
  for var i := MaxS(la, lb) - 1 downto 0 do begin
    var a := if i < la then pa[i] else 0;
    var b := if i < lb then pb[i] else 0;
    var undecided := LongWord(1) - (gt or lt);
    gt := gt or (LongWord(ord(a > b)) and undecided);
    lt := lt or (LongWord(ord(a < b)) and undecided);
  end;
  result := integer(gt) - integer(lt);
end;

procedure UBigInt.secureClear;
begin
  FillChar(fInline, SizeOf(fInline), 0);
  if (fArr <> nil) and ArrUnshared(fArr) then FillChar(fArr[0], Length(fArr) * SizeOf(TLimb), 0);
  fArr := nil;
  fLen := 0;
end;

function UBigInt.min(const other: UBigInt): UBigInt;
begin
  result := if LCmpP(dataPtr, fLen, other.dataPtr, other.fLen) <= 0 then self else other;
end;

function UBigInt.max(const other: UBigInt): UBigInt;
begin
  result := if LCmpP(dataPtr, fLen, other.dataPtr, other.fLen) >= 0 then self else other;
end;

function UBigInt.divMod(const d: UBigInt): (q, r: UBigInt);
var
  qq, rr: UBigInt;
begin
  if d.fLen = 0 then RaiseDivByZero;
  if (d.fArr = nil) and (fLen <= 2 * BIGINT_INLINE_LIMBS) then begin
    var qb, rb: array[0..2 * BIGINT_INLINE_LIMBS - 1] of TLimb;
    DivModInline(dataPtr, fLen, @d.fInline[0], d.fLen, @qb[0], var ql, @rb[0], var rl);
    if ql <= BIGINT_INLINE_LIMBS then PutInline(@qb[0], ql, @qq.fInline[0], qq.fArr, qq.fLen)
    else PutSpill(@qb[0], ql, qq.fArr, qq.fLen);
    if rl <= BIGINT_INLINE_LIMBS then PutInline(@rb[0], rl, @rr.fInline[0], rr.fArr, rr.fLen)
    else PutSpill(@rb[0], rl, rr.fArr, rr.fLen);
    exit(qq, rr);
  end;
  var qm, rm: TLimbs;
  LDivModP(dataPtr, fLen, d.dataPtr, d.fLen, qm, rm);
  MoveArr(qm, @qq.fInline[0], qq.fArr, qq.fLen);
  MoveArr(rm, @rr.fInline[0], rr.fArr, rr.fLen);
  exit(qq, rr);
end;

function UBigInt.ceilDiv(const d: UBigInt): UBigInt;
begin
  var (q, r) := divMod(d);
  result := if r.isZero then q else q + 1;
end;

procedure UBigInt.swap(var other: UBigInt);
begin
  var t := self;
  self := other;
  other := t;
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
  lm: TLimbs;
begin
  result := TryParseLimbs(s, 0, lm, neg);
  if result and neg and (Length(lm) <> 0) then result := false
  else v.fLimbs := lm;
end;

class function UBigInt.tryParse(const s: string; base: integer; out v: UBigInt): boolean;
var
  neg: boolean;
  lm: TLimbs;
begin
  if (base < 2) or (base > 36) then raise EBigIntError.Create($'invalid base {base}, expected 2..36');
  result := TryParseLimbs(s, base, lm, neg);
  if result and neg and (Length(lm) <> 0) then result := false
  else v.fLimbs := lm;
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

function UBigInt.sqr: UBigInt;
begin
  if fArr = nil then begin
    MulInline(@fInline[0], fLen, @fInline[0], fLen, @result.fInline[0], result.fArr, result.fLen);
    exit;
  end;
  var t := LSqrP(dataPtr, fLen);
  MoveArr(t, @result.fInline[0], result.fArr, result.fLen);
end;

function UBigInt.sqrt: UBigInt;
begin
  if fLen = 0 then exit(default(UBigInt));
  // Newton iteration seeded above the root converges downward to floor(sqrt)
  var x := UBigInt.pow2((bitLength + 1) div 2);
  repeat
    var y := (x + self div x) shr 1;
    if y >= x then break;
    x := y;
  until false;
  result := x;
end;

function UBigInt.nthRoot(n: LongWord): UBigInt;
begin
  if n = 0 then raise EBigIntError.Create('zeroth root is undefined');
  if (n = 1) or (fLen = 0) or isOne then exit(self);
  var x := UBigInt.pow2((bitLength + n - 1) div n);
  repeat
    var y := ((n - 1) * x + self div x.pow(n - 1)) div n;
    if y >= x then break;
    x := y;
  until false;
  // Newton for higher roots can land one off, correct exactly
  while x.pow(n) > self do x := x - 1;
  while (x + 1).pow(n) <= self do x := x + 1;
  result := x;
end;

function UBigInt.pow(e: LongWord): UBigInt;
begin
  result.fLimbs := UPowQ(fLimbs, e);
end;

// negated inverse of m0 modulo the limb base (Montgomery m'), m0 odd
function MontInv(m0: TLimb): TLimb;
begin
  var inv := m0; // 3 correct bits to seed (x = x^-1 mod 8 for odd x), Newton doubles per step
  for var i := 1 to 5 do inv := inv * (TLimb(2) - m0 * inv);
  result := TLimb(0) - inv;
end;

// Montgomery product rp := ap * bp / B^n mod m; every run is n limbs, t is a
// caller-provided 2n+1 limb workspace; rp may alias ap and bp
procedure MontMul(rp, ap, bp: PLimb; const m: TLimbs; mInv: TLimb; n: SizeInt; var t: TLimbs);
begin
  t[2 * n] := 0;
  t[n] := MpnMul1(@t[0], ap, n, bp[0]);
  for var j := 1 to n - 1 do t[n + j] := MpnAddMul1(@t[j], ap, n, bp[j]);
  // interleaved REDC: kill one low limb per round with a multiple of m
  for var i := 0 to n - 1 do begin
    var u: TLimb := t[i] * mInv;
    var c := MpnAddMul1(@t[i], @m[0], n, u);
    MpnAdd1(@t[i + n], @t[i + n], n + 1 - i, c);
  end;
  // t[n..2n] holds a value below 2m: one conditional subtract finishes
  if (t[2 * n] <> 0) or (MpnCmp(@t[n], @m[0], n) >= 0) then MpnSubN(rp, @t[n], @m[0], n)
  else Move(t[n], rp^, n * SizeOf(TLimb));
end;

// modular exponentiation for odd m: Montgomery form with a fixed k-bit window
function UMontModPow(const base, e, m: UBigInt): UBigInt;
var
  q, rr, bred, baseM, acc, t, oneVec: TLimbs;
  table: array of TLimbs;
begin
  var n := m.fLen;
  // materialize the modulus and exponent limbs once; MontMul/LGetBits run in a
  // loop and would otherwise rebuild these arrays on every step
  var mLimbs := m.fLimbs;
  var eLimbs := e.fLimbs;
  var mInv := MontInv(mLimbs[0]);
  // base*R mod m, costs one shift and two divisions
  LDivMod(base.fLimbs, mLimbs, q, rr);
  bred := LShl(rr, LongWord(n) * LIMB_BITS);
  LDivMod(bred, mLimbs, q, baseM);
  SetLength(baseM, n);
  var ebits := e.bitLength;
  var k := if ebits >= 1024 then 6 else if ebits >= 256 then 5 else if ebits >= 64 then 4 else if ebits >= 16 then 3 else if ebits >= 4 then 2 else 1;
  SetLength(t, 2 * n + 1);
  SetLength(table, 1 shl k);
  table[1] := baseM;
  for var j := 2 to (1 shl k) - 1 do begin
    SetLength(table[j], n);
    MontMul(@table[j][0], @table[j - 1][0], @baseM[0], mLimbs, mInv, n, t);
  end;
  // scan the exponent top-down in k-bit digits: k squarings then one table mul
  var chunks := (SizeInt(ebits) + k - 1) div k;
  acc := Copy(table[LGetBits(eLimbs, LongWord((chunks - 1) * k), k)]);
  for var c := chunks - 2 downto 0 do begin
    for var s := 1 to k do MontMul(@acc[0], @acc[0], @acc[0], mLimbs, mInv, n, t);
    var d := LGetBits(eLimbs, LongWord(c * k), k);
    if d <> 0 then MontMul(@acc[0], @acc[0], @table[d][0], mLimbs, mInv, n, t);
  end;
  // back out of Montgomery form via a multiply by plain 1
  SetLength(oneVec, n);
  oneVec[0] := 1;
  MontMul(@acc[0], @acc[0], @oneVec[0], mLimbs, mInv, n, t);
  LNorm(acc);
  result.fLimbs := acc;
end;

function UBigInt.modPow(const e, m: UBigInt): UBigInt;
begin
  if m.isZero then RaiseDivByZero;
  if m.isOne then exit(default(UBigInt));
  // Montgomery needs an odd modulus; tiny exponents skip the setup cost
  if m.isOdd and (e.bitLength > 8) then exit(UMontModPow(self, e, m));
  var base := self mod m;
  var acc: UBigInt := 1;
  var bits := e.bitLength;
  for var i := 0 to Int64(bits) - 1 do begin
    if e.testBit(i) then acc := (acc * base) mod m;
    if i < Int64(bits) - 1 then base := base.sqr mod m;
  end;
  result := acc;
end;

function UBigInt.modInverse(const m: UBigInt): UBigInt;
begin
  if m.isZero then RaiseDivByZero;
  // extended Euclid on signed values
  var oldR: BigInt := self mod m;
  var r: BigInt := m;
  var oldS: BigInt := 1;
  var s: BigInt := 0;
  while not r.isZero do begin
    var q := oldR div r;
    (oldR, r) := (r, oldR - q * r);
    (oldS, s) := (s, oldS - q * s);
  end;
  if not oldR.isOne then raise EBigIntError.Create('value has no modular inverse for this modulus');
  result := oldS.floorMod(m).toUBigInt;
end;

// remainder of a modulo a single limb
function LModW(const a: TLimbs; w: TLimb): TLimb;
begin
  result := 0;
  for var i := Length(a) - 1 downto 0 do UDivLimb(result, a[i], w, result);
end;

// remainder modulo a single limb over (ptr, len), no array materialization
function LModWP(p: PLimb; len: SizeInt; w: TLimb): TLimb; inline;
begin
  result := 0;
  for var i := len - 1 downto 0 do UDivLimb(result, p[i], w, result);
end;

function GcdQWord(a, b: QWord): QWord;
begin
  while b <> 0 do begin
    var t := a mod b;
    a := b;
    b := t;
  end;
  result := a;
end;

// p*a + q*b for small cofactors of opposite sign, result known nonnegative
function LSignedComb(p: Int64; const a: TLimbs; q: Int64; const b: TLimbs): TLimbs;
var
  res: TLimbs;
begin
  // orient so the nonnegative coefficient comes first
  if (p < 0) or ((p = 0) and (q > 0)) then exit(LSignedComb(q, b, p, a));
  var la := Length(a);
  var lb := Length(b);
  SetLength(res, MaxS(la, lb) + 1);
  if (p <> 0) and (la > 0) then res[la] := MpnMul1(@res[0], @a[0], la, TLimb(p));
  if (q <> 0) and (lb > 0) then begin
    var borrow := MpnSubMul1(@res[0], @b[0], lb, TLimb(-q));
    MpnSub1(@res[lb], @res[lb], Length(res) - lb, borrow);
  end;
  LNorm(res);
  result := res;
end;

function UBigInt.gcd(const other: UBigInt): UBigInt;
begin
  var aL := Copy(fLimbs);
  var bL := Copy(other.fLimbs);
  if LCmp(aL, bL) < 0 then SwapValues(aL, bL);
  // Lehmer: run Euclid on the top 63 bits, apply the resulting 2x2 matrix to
  // the full numbers with single-limb rows, fall back to one big division
  // whenever the word view cannot certify a quotient
  while Length(bL) > 1 do begin
    var shs := SizeInt(LBitLen(aL)) - 63;
    if shs < 0 then shs := 0;
    var x := Int64(LExtract64(aL, LongWord(shs)));
    var y := Int64(LExtract64(bL, LongWord(shs)));
    var mA: Int64 := 1;
    var mB: Int64 := 0;
    var mC: Int64 := 0;
    var mD: Int64 := 1;
    while (y + mC > 0) and (y + mD > 0) do begin
      var q := (x + mA) div (y + mC);
      if (q <> (x + mB) div (y + mD)) or (q > $7FFFFFFF) then break;
      var t1 := mA - q * mC;
      var t2 := mB - q * mD;
      mA := mC;
      mB := mD;
      mC := t1;
      mD := t2;
      var t := x - q * y;
      x := y;
      y := t;
      if (System.Abs(mC) > $40000000) or (System.Abs(mD) > $40000000) then break;
    end;
    if mB = 0 then begin
      // no certified quotient in the top words: one full division step
      var q, r: TLimbs;
      LDivMod(aL, bL, q, r);
      aL := bL;
      bL := r;
    end else begin
      var na := LSignedComb(mA, aL, mB, bL);
      var nb := LSignedComb(mC, aL, mD, bL);
      aL := na;
      bL := nb;
      if LCmp(aL, bL) < 0 then SwapValues(aL, bL);
    end;
  end;
  if Length(bL) = 0 then begin
    result.fLimbs := aL;
    exit;
  end;
  var w := bL[0];
  result.fLimbs := LFromQWord(GcdQWord(w, LModW(aL, w)));
end;

function UBigInt.lcm(const other: UBigInt): UBigInt;
begin
  if isZero or other.isZero then exit(default(UBigInt));
  result := (self div gcd(other)) * other;
end;

function UBigInt.isProbablePrime(rounds: integer): boolean;
const
  // enough trial primes that every composite below 47*47 gets caught,
  // and the first 12 double as deterministic Miller-Rabin witnesses to 3.3e24
  smallPrimes: array[0..14] of byte = (2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47);
begin
  if self < 2 then exit(false);
  for var i := 0 to High(smallPrimes) do begin
    if self = smallPrimes[i] then exit(true);
    if (self mod smallPrimes[i]).isZero then exit(false);
  end;
  if self < 47 * 47 then exit(true);
  // n-1 = d * 2^s with d odd
  var nm1 := self - 1;
  var s := nm1.lowestSetBit;
  var d := nm1 shr s;
  var witnesses := if rounds > 12 then rounds else 12;
  for var w := 0 to witnesses - 1 do begin
    var a: UBigInt;
    if w <= 11 then a := smallPrimes[w]
    else begin
      // random witness in [2, n-2]
      a := UBigInt.random(bitLength + 8) mod (self - 3) + 2;
    end;
    var x := a.modPow(d, self);
    if x.isOne or (x = nm1) then continue;
    var composite := true;
    for var j := 1 to s - 1 do begin
      x := x.sqr mod self;
      if x = nm1 then begin
        composite := false;
        break;
      end;
    end;
    if composite then exit(false);
  end;
  result := true;
end;

function UBigInt.nextPrime: UBigInt;
begin
  if self < 2 then exit(UBigInt(2));
  var c := self + 1;
  if c.isEven then c := c + 1;
  while not c.isProbablePrime do c := c + 2;
  result := c;
end;

function UBigInt.prevPrime: UBigInt;
begin
  if self <= 2 then raise EBigIntError.Create('no prime below 2');
  if self = 3 then exit(UBigInt(2));
  var c := self - 1;
  if c.isEven then c := c - 1;
  while not c.isProbablePrime do c := c - 2;
  result := c;
end;

// Jacobi symbol (a/m) for odd positive m
function UJacobi(a, m: UBigInt): integer;
begin
  a := a mod m;
  result := 1;
  while not a.isZero do begin
    var z := a.lowestSetBit;
    if z and 1 = 1 then begin
      // (2/m) = -1 exactly for m = 3, 5 (mod 8)
      var m8 := m.fLimbs[0] and 7;
      if (m8 = 3) or (m8 = 5) then result := -result;
    end;
    a := a shr z;
    // both odd here: quadratic reciprocity
    if (a.fLimbs[0] and 3 = 3) and (m.fLimbs[0] and 3 = 3) then result := -result;
    a.swap(m);
    a := a mod m;
  end;
  if not m.isOne then result := 0;
end;

function UBigInt.jacobi(const n: UBigInt): integer;
begin
  if not n.isOdd then raise EBigIntError.Create('jacobi symbol needs an odd positive modulus');
  result := UJacobi(self, n);
end;

function UBigInt.modSqrt(const p: UBigInt): UBigInt;
begin
  if p.isZero then RaiseDivByZero;
  if p = 2 then exit(if isOdd then UBigInt.one else default(UBigInt));
  if not p.isOdd then raise EBigIntError.Create('modSqrt needs an odd prime modulus');
  var a := self mod p;
  if a.isZero then exit(default(UBigInt));
  if UJacobi(a, p) <> 1 then raise EBigIntError.Create('value has no square root for this modulus');
  // p = 3 (mod 4): a^((p+1)/4) is a root directly
  if p.fLimbs[0] and 3 = 3 then exit(a.modPow((p + 1) shr 2, p));
  // Tonelli-Shanks for p = 1 (mod 4)
  var q := p - 1;
  var s := q.lowestSetBit;
  q := q shr s;
  var z := UBigInt.two;
  while UJacobi(z, p) <> -1 do z := z + 1;
  var m := s;
  var c := z.modPow(q, p);
  var t := a.modPow(q, p);
  result := a.modPow((q + 1) shr 1, p);
  while not t.isOne do begin
    // least i with t^(2^i) = 1
    var i: Int64 := 0;
    var t2 := t;
    while not t2.isOne do begin
      t2 := t2.sqr mod p;
      inc(i);
      if i = m then raise EBigIntError.Create('modSqrt needs a prime modulus');
    end;
    var b := c;
    for var j := 1 to m - i - 1 do b := b.sqr mod p;
    m := i;
    c := b.sqr mod p;
    t := (t * c) mod p;
    result := (result * b) mod p;
  end;
end;

// q-th root of c modulo an odd prime p, for prime q dividing p-1 and c a
// nonzero q-th power: peel the exponent onto c, then fix the q^t-torsion part
// via Pohlig-Hellman with brute-force digits (O(q) per digit, so cheap for
// the small prime factors nthRootMod feeds in)
function UAMMRoot(const c: UBigInt; q: QWord; const p: UBigInt): UBigInt;
begin
  var n1 := p - 1;
  var qq := UBigInt(q);
  var s := n1;
  var t := 0;
  while (s mod qq).isZero do begin
    s := s div qq;
    inc(t);
  end;
  // x := c^(q^-1 mod s) is the root up to torsion; err lands in the q^t group
  var x := c.modPow(qq.modInverse(s), p);
  var err := (x.modPow(qq, p) * c.modInverse(p)) mod p;
  if err.isOne then exit(x);
  // any q-nonresidue gives a generator of the torsion subgroup
  var z := UBigInt.two;
  var tries := 0;
  while z.modPow(n1 div qq, p).isOne do begin
    z := z + 1;
    inc(tries);
    if tries = 256 then raise EBigIntError.Create('nthRootMod needs a prime modulus');
  end;
  var b := z.modPow(s, p);
  var omega := b.modPow(qq.pow(LongWord(t - 1)), p);
  // discrete log of err base b, base-q digit by digit
  var dl := UBigInt.zero;
  var qi := UBigInt.one;
  for var i := 0 to t - 1 do begin
    var g := ((err * b.modPow(dl, p).modInverse(p)) mod p).modPow(qq.pow(LongWord(t - 1 - i)), p);
    var cur := UBigInt.one;
    var digit: QWord := 0;
    while cur <> g do begin
      cur := (cur * omega) mod p;
      inc(digit);
      if digit = q then raise EBigIntError.Create('nthRootMod needs a prime modulus');
    end;
    dl := dl + UBigInt(digit) * qi;
    qi := qi * qq;
  end;
  // err = b^dl with q | dl, so b^(-dl/q) cancels the torsion in x
  if not (dl mod qq).isZero then raise EBigIntError.Create('nthRootMod needs a prime modulus');
  result := (x * b.modPow(dl div qq, p).modInverse(p)) mod p;
end;

function UBigInt.nthRootMod(k: LongWord; const p: UBigInt): UBigInt;
begin
  if k = 0 then raise EBigIntError.Create('nthRootMod needs k >= 1');
  if p.isZero then RaiseDivByZero;
  if p = 2 then exit(self mod p);
  if not p.isOdd then raise EBigIntError.Create('nthRootMod needs an odd prime modulus');
  var a := self mod p;
  if a.isZero then exit(default(UBigInt));
  var n1 := p - 1;
  var r := UBigInt(QWord(k)) mod n1;
  if r.isZero then begin
    // x^k = 1 for every unit, so only a = 1 has roots
    if a.isOne then exit(UBigInt.one);
    raise EBigIntError.Create('value has no k-th root for this modulus');
  end;
  var d := r.gcd(n1);
  if not a.modPow(n1 div d, p).isOne then raise EBigIntError.Create('value has no k-th root for this modulus');
  // shift the invertible exponent part onto a: x^d = a^e solves x^r = a, and
  // d | p-1 keeps every AMM peel below solvable regardless of root choice
  var c := a.modPow((r div d).modInverse(n1 div d), p);
  var dd := d.toUInt64;
  var q: QWord := 2;
  while dd > 1 do begin
    if q * q > dd then q := dd;
    while dd mod q = 0 do begin
      c := UAMMRoot(c, q, p);
      dd := dd div q;
    end;
    q := q + (if q = 2 then 1 else 2);
  end;
  result := c;
end;

function UBigInt.sqrtRem: (root, rem: UBigInt);
begin
  var r := sqrt;
  exit(r, self - r.sqr);
end;

function UBigInt.isPerfectSquare: boolean;
begin
  if isZero then exit(true);
  // squares are 0, 1, 4 or 9 mod 16
  if not (byte(fLimbs[0] and 15) in [0, 1, 4, 9]) then exit(false);
  var (_, rem) := sqrtRem;
  result := rem.isZero;
end;

// Brent's cycle variant of Pollard rho: a nontrivial factor of an odd
// composite n; expected runtime grows with the square root of the smallest
// prime factor, so hard semiprimes take long
function UPollardBrent(const n: UBigInt): UBigInt;
begin
  repeat
    var y := UBigInt.randomBelow(n - 3) + 2;
    var c := UBigInt.randomBelow(n - 3) + 1;
    var g := UBigInt.one;
    var q := UBigInt.one;
    var x := y;
    var ys := y;
    var r: Int64 := 1;
    while g.isOne do begin
      x := y;
      for var i := 1 to r do y := (y.sqr + c) mod n;
      var k: Int64 := 0;
      while (k < r) and g.isOne do begin
        ys := y;
        for var i := 1 to MinS(128, SizeInt(r - k)) do begin
          y := (y.sqr + c) mod n;
          q := (q * (if x > y then x - y else y - x)) mod n;
        end;
        g := q.gcd(n);
        k := k + 128;
      end;
      r := r * 2;
    end;
    if g = n then begin
      // the batch overshot: replay one step at a time
      repeat
        ys := (ys.sqr + c) mod n;
        var d := if x > ys then x - ys else ys - x;
        g := d.gcd(n);
      until not g.isOne;
    end;
    if g <> n then exit(g);
  until false;
end;

function UBigInt.factorize: array of (p: UBigInt; e: LongWord);
var
  factors: array of UBigInt;
  res: array of (p: UBigInt; e: LongWord);

  procedure push(const f: UBigInt);
  begin
    SetLength(factors, Length(factors) + 1);
    factors[High(factors)] := f;
  end;

  procedure split(const v: UBigInt);
  begin
    if v.isOne then exit;
    if v.isProbablePrime then begin
      push(v);
      exit;
    end;
    var f := UPollardBrent(v);
    split(f);
    split(v div f);
  end;

begin
  var n := self;
  if n <= 1 then exit(nil);
  // powers of two straight from the bit count
  var z := n.lowestSetBit;
  if z > 0 then begin
    SetLength(res, 1);
    res[0] := (UBigInt.two, LongWord(z));
    n := n shr z;
  end;
  // small trial division
  var d: Int64 := 3;
  while (d <= 9999) and (n > 1) do begin
    if n < d * d then break;
    var cnt: LongWord := 0;
    while (n mod d).isZero do begin
      n := n div d;
      inc(cnt);
    end;
    if cnt > 0 then begin
      SetLength(res, Length(res) + 1);
      res[High(res)] := (UBigInt(d), cnt);
    end;
    inc(d, 2);
  end;
  if n > 1 then begin
    if n < d * d then push(n) // a cofactor below the trial bound squared is prime
    else split(n);
    // sort the collected factors, then merge equal ones
    for var i := 1 to High(factors) do begin
      var f := factors[i];
      var j := i - 1;
      while (j >= 0) and (factors[j] > f) do begin
        factors[j + 1] := factors[j];
        dec(j);
      end;
      factors[j + 1] := f;
    end;
    var i := 0;
    while i <= High(factors) do begin
      var cnt: LongWord := 1;
      while (i + SizeInt(cnt) <= High(factors)) and (factors[i + SizeInt(cnt)] = factors[i]) do inc(cnt);
      SetLength(res, Length(res) + 1);
      res[High(res)] := (factors[i], cnt);
      i := i + SizeInt(cnt);
    end;
  end;
  result := res;
end;

function UBigInt.eulerPhi: UBigInt;
begin
  if isZero then exit(default(UBigInt));
  result := self;
  for var (p, e) in factorize do result := result div p * (p - 1);
end;

function UBigInt.carmichaelLambda: UBigInt;
begin
  if isZero then raise EBigIntError.Create('carmichaelLambda needs a positive value');
  result := UBigInt.one;
  for var (p, e) in factorize do begin
    // lambda(2^e) drops to 2^(e-2) from e = 3 up; odd prime powers keep phi
    var lam := if (p = 2) and (e >= 3) then UBigInt.pow2(e - 2) else p.pow(e - 1) * (p - 1);
    result := result.lcm(lam);
  end;
end;

function UBigInt.multiplicativeOrder(const m: UBigInt): UBigInt;
begin
  if m.isZero then RaiseDivByZero;
  if m.isOne then exit(UBigInt.one);
  var a := self mod m;
  if not a.gcd(m).isOne then raise EBigIntError.Create('multiplicativeOrder needs gcd(value, modulus) = 1');
  // start from lambda(m) (every order divides it), then strip primes while the
  // power still fixes 1
  result := m.carmichaelLambda;
  for var (p, e) in result.factorize do
    while (result mod p).isZero and a.modPow(result div p, m).isOne do result := result div p;
end;

function UBigInt.isPrimitiveRoot(const m: UBigInt): boolean;
begin
  if m.isZero then RaiseDivByZero;
  if m.isOne then exit(true);
  var a := self mod m;
  if not a.gcd(m).isOne then exit(false);
  result := multiplicativeOrder(m) = m.eulerPhi;
end;

function UBigInt.primitiveRoot: UBigInt;
begin
  if isZero then RaiseDivByZero;
  if self <= 4 then exit(if isOne then default(UBigInt) else self - 1); // 1 -> 0, 2 -> 1, 3 -> 2, 4 -> 3
  // a primitive root exists only for p^k and 2*p^k with p an odd prime
  var fac := factorize;
  var ok := ((Length(fac) = 1) and (fac[0].p.isOdd)) or ((Length(fac) = 2) and (fac[0].p = 2) and (fac[0].e = 1));
  if not ok then raise EBigIntError.Create('modulus has no primitive root');
  var phi := eulerPhi;
  var phiFac := phi.factorize;
  var g := UBigInt.two;
  repeat
    if g.gcd(self).isOne then begin
      var isGen := true;
      for var (q, e) in phiFac do
        if g.modPow(phi div q, self).isOne then begin
          isGen := false;
          break;
        end;
      if isGen then exit(g);
    end;
    g := g + 1;
  until g = self;
  raise EBigIntError.Create('modulus has no primitive root'); // unreachable for valid moduli
end;

function UBigInt.moebius: integer;
begin
  if isZero then exit(0);
  result := 1;
  for var (p, e) in factorize do begin
    if e > 1 then exit(0);
    result := -result;
  end;
end;

function UBigInt.sigma(k: LongWord): UBigInt;
begin
  if isZero then exit(default(UBigInt));
  if k = 0 then exit(tau);
  result := UBigInt.one;
  for var (p, e) in factorize do begin
    // sum of the geometric series 1 + p^k + ... + p^(k*e)
    var pk := p.pow(k);
    result := result * ((pk.pow(e + 1) - 1) div (pk - 1));
  end;
end;

function UBigInt.tau: UBigInt;
begin
  if isZero then exit(default(UBigInt));
  result := UBigInt.one;
  for var (p, e) in factorize do result := result * Int64(e + 1);
end;

function UBigInt.radical: UBigInt;
begin
  if isZero then exit(default(UBigInt));
  result := UBigInt.one;
  for var (p, e) in factorize do result := result * p;
end;

function UBigInt.divisors: array of UBigInt;
var
  res: array of UBigInt;
begin
  if isZero then exit(nil);
  res := [UBigInt.one];
  for var (p, e) in factorize do begin
    var base := Length(res);
    var pe := UBigInt.one;
    for var j := 1 to e do begin
      pe := pe * p;
      for var i := 0 to base - 1 do begin
        SetLength(res, Length(res) + 1);
        res[High(res)] := res[i] * pe;
      end;
    end;
  end;
  // insertion sort ascending
  for var i := 1 to High(res) do begin
    var v := res[i];
    var j := i - 1;
    while (j >= 0) and (res[j] > v) do begin
      res[j + 1] := res[j];
      dec(j);
    end;
    res[j + 1] := v;
  end;
  result := res;
end;

function UBigInt.isSquarefree: boolean;
begin
  if isZero then exit(false);
  for var (p, e) in factorize do
    if e > 1 then exit(false);
  result := true;
end;

function UBigInt.isPerfect: boolean;
begin
  if self < 2 then exit(false);
  // proper divisors sum to self exactly when sigma(1) = 2*self
  result := sigma(1) = (self shl 1);
end;

function UBigInt.isCarmichael: boolean;
begin
  // Korselt: composite, squarefree, and p-1 | n-1 for every prime p | n
  if (self < 561) or isEven then exit(false);
  var f := factorize;
  if Length(f) < 3 then exit(false);
  var nm1 := self - 1;
  for var i := 0 to High(f) do begin
    if f[i].e > 1 then exit(false);
    if not (nm1 mod (f[i].p - 1)).isZero then exit(false);
  end;
  result := true;
end;

function UBigInt.nthRootRem(n: LongWord): (root, rem: UBigInt);
begin
  var r := nthRoot(n);
  exit(r, self - r.pow(n));
end;

function UBigInt.isKthPower(k: LongWord): boolean;
begin
  if k = 0 then raise EBigIntError.Create('zeroth power test is undefined');
  if (k = 1) or isZero or isOne then exit(true);
  var r := nthRoot(k);
  result := r.pow(k) = self;
end;

// ---------------------------------------------------------------------------
// UBigInt cryptographic helpers
// ---------------------------------------------------------------------------

// modular helpers for values already reduced into [0, n)
function AddMod(const a, b, n: UBigInt): UBigInt; inline;
begin
  result := a + b;
  if result >= n then result := result - n;
end;

function SubMod(const a, b, n: UBigInt): UBigInt; inline;
begin
  result := if a >= b then a - b else a + n - b;
end;

// x / 2 mod an odd n
function HalfMod(const x, n: UBigInt): UBigInt; inline;
begin
  result := if x.isEven then x shr 1 else (x + n) shr 1;
end;

// Miller-Rabin to base 2, the first half of Baillie-PSW
function MillerRabin2(const n: UBigInt): boolean;
begin
  var nm1 := n - 1;
  var s := nm1.lowestSetBit;
  var d := nm1 shr s;
  var x := UBigInt.two.modPow(d, n);
  if x.isOne or (x = nm1) then exit(true);
  for var j := 1 to s - 1 do begin
    x := x.sqr mod n;
    if x = nm1 then exit(true);
  end;
  result := false;
end;

// strong Lucas test with Selfridge parameters, the second half of Baillie-PSW;
// n is odd, > 1 and not a perfect square
function LucasStrongPRP(const n: UBigInt): boolean;
begin
  // first D in 5, -7, 9, -11, ... with the Jacobi symbol (D/n) = -1
  var dabs: Int64 := 5;
  var sgn: Int64 := 1;
  var dm := default(UBigInt);
  while true do begin
    var dmod := UBigInt(QWord(dabs)) mod n;
    if sgn < 0 then dmod := n - dmod;
    var j := UJacobi(dmod, n);
    if j = 0 then exit(UBigInt(QWord(dabs)) = n); // a shared factor means composite
    if j = -1 then begin
      dm := dmod;
      break;
    end;
    sgn := -sgn;
    dabs := dabs + 2;
  end;
  // Q = (1 - D)/4 mod n, with P = 1 (D is 1 mod 4, so the division is exact)
  var qsig := (1 - sgn * dabs) div 4;
  var qm := if qsig >= 0 then UBigInt(QWord(qsig)) mod n else n - (UBigInt(QWord(-qsig)) mod n);
  // n + 1 = d * 2^s
  var np1 := n + 1;
  var s := np1.lowestSetBit;
  var d := np1 shr s;
  // Lucas sequence U_d, V_d and Q^d mod n, scanning d from the second bit down
  var u := UBigInt.one;
  var v := UBigInt.one;
  var qk := qm;
  for var i := integer(d.bitLength) - 2 downto 0 do begin
    u := (u * v) mod n;
    v := SubMod(v.sqr mod n, (qk shl 1) mod n, n);
    qk := qk.sqr mod n;
    if d.testBit(i) then begin
      var nu := HalfMod(AddMod(u, v, n), n);
      var nv := HalfMod(AddMod(v, (dm * u) mod n, n), n);
      u := nu;
      v := nv;
      qk := (qk * qm) mod n;
    end;
  end;
  if u.isZero or v.isZero then exit(true);
  for var r := 1 to s - 1 do begin
    v := SubMod(v.sqr mod n, (qk shl 1) mod n, n);
    if v.isZero then exit(true);
    qk := qk.sqr mod n;
  end;
  result := false;
end;

function UBigInt.isPrime: boolean;
begin
  if self < 2 then exit(false);
  if isEven then exit(self = 2);
  // deterministic Miller-Rabin already settles everything below 3.3e24
  if bitLength <= 81 then exit(isProbablePrime);
  // Baillie-PSW above: strong base-2 Miller-Rabin plus a strong Lucas test
  if not MillerRabin2(self) then exit(false);
  if isPerfectSquare then exit(false);
  result := LucasStrongPRP(self);
end;

function UBigInt.modPowSec(const e, m: UBigInt): UBigInt;
begin
  if m.isZero then RaiseDivByZero;
  if m.isOne then exit(default(UBigInt));
  // Montgomery ladder: every bit runs one multiply and one square, and the two
  // registers swap roles without branching on the operation performed, so the
  // sequence of big-integer operations does not depend on the exponent bits
  var x0 := UBigInt.one;
  var x1 := self mod m;
  var bits := e.bitLength;
  if bits = 0 then bits := 1;
  for var i := integer(bits) - 1 downto 0 do
    if e.testBit(i) then begin
      x0 := (x0 * x1) mod m;
      x1 := (x1 * x1) mod m;
    end else begin
      x1 := (x0 * x1) mod m;
      x0 := (x0 * x0) mod m;
    end;
  result := x0;
end;

// Kronecker symbol (a/n), the full extension of Jacobi to any integers
function KroneckerSym(a, n: BigInt): integer;
begin
  if n.isZero then exit(if (a = 1) or (a = -1) then 1 else 0);
  result := 1;
  if n.isNegative then begin
    n.negate;
    if a.isNegative then result := -result;
  end;
  // pull the twos out of n, using (a/2) = 0, 1 or -1 by a mod 8
  if n.isEven then begin
    if a.isEven then exit(0);
    var v: Int64 := 0;
    while n.isEven do begin
      n := n shr 1;
      inc(v);
    end;
    if (v and 1) = 1 then begin
      var m8 := a.floorMod(BigInt(8)).toInt32;
      if (m8 = 3) or (m8 = 5) then result := -result;
    end;
  end;
  // n is odd positive now; Jacobi depends only on a mod n
  var au := a.floorMod(n).toUBigInt;
  var nu := n.toUBigInt;
  var j := UJacobi(au, nu);
  if j = 0 then exit(0);
  result := result * j;
end;

function UBigInt.kronecker(const n: UBigInt): integer;
begin
  result := KroneckerSym(self.toBigInt, n.toBigInt);
end;

// solve y = r1 (mod m1), y = r2 (mod m2) for coprime moduli
function CrtPair(const r1, m1, r2, m2: UBigInt): UBigInt;
begin
  var t := (SubMod(r2 mod m2, r1 mod m2, m2) * m1.modInverse(m2)) mod m2;
  result := r1 + m1 * t;
end;

// every square root of a coprime to p, modulo p^e; empty when a is a non-residue
function RootsModPP(const a, p: UBigInt; e: LongWord): array of UBigInt;
begin
  var pe := p.pow(e);
  var am := a mod pe;
  if p = 2 then begin
    if e = 1 then exit([am mod 2]);
    if e = 2 then exit(if (am mod 4) = 1 then [UBigInt.one, UBigInt(3)] else nil);
    if (am mod 8) <> 1 then exit(nil);
    // lift a root through the 2-adic squares: add 2^(k-1) when the square is off
    var r := UBigInt.one;
    var pk := UBigInt(8);
    var k := 3;
    while k < integer(e) do begin
      var pk1 := pk shl 1;
      if (r.sqr mod pk1) <> (am mod pk1) then r := r + (pk shr 1);
      pk := pk1;
      inc(k);
    end;
    r := r mod pe;
    var s := (r + UBigInt.pow2(e - 1)) mod pe;
    exit([r, pe - r, s, pe - s]);
  end;
  // odd prime: Tonelli-Shanks mod p, then Hensel lift to p^e
  if UJacobi(am, p) <> 1 then exit(nil);
  var r := am.modSqrt(p);
  var pk := p;
  for var k := 2 to integer(e) do begin
    var pk1 := pk * p;
    // Newton step r := r - (r^2 - a) / (2r), all mod p^k
    var num := SubMod(r.sqr mod pk1, am mod pk1, pk1);
    var inv := ((r shl 1) mod pk1).modInverse(pk1);
    r := SubMod(r, (num * inv) mod pk1, pk1);
    pk := pk1;
  end;
  result := [r, pe - r];
end;

function UBigInt.sqrtModN(const n: UBigInt): array of UBigInt;
begin
  if n.isZero then RaiseDivByZero;
  if n.isOne then exit([default(UBigInt)]);
  var a := self mod n;
  if not a.gcd(n).isOne then raise EBigIntError.Create('sqrtModN needs gcd(self, n) = 1');
  // roots modulo each prime power, glued together with the CRT
  var sols: array of UBigInt := [default(UBigInt)];
  var modAcc := UBigInt.one;
  for var (p, e) in n.factorize do begin
    var pe := p.pow(e);
    var rs := RootsModPP(a, p, e);
    if Length(rs) = 0 then exit(nil);
    // fresh accumulator each round (an inline var keeps its value across
    // loop iterations, so the reset is explicit)
    var next: array of UBigInt := nil;
    for var x in sols do
      for var r in rs do begin
        SetLength(next, Length(next) + 1);
        next[High(next)] := CrtPair(x, modAcc, r, pe);
      end;
    sols := next;
    modAcc := modAcc * pe;
  end;
  // sort ascending, drop duplicates
  for var i := 1 to High(sols) do begin
    var v := sols[i];
    var j := i - 1;
    while (j >= 0) and (sols[j] > v) do begin
      sols[j + 1] := sols[j];
      dec(j);
    end;
    sols[j + 1] := v;
  end;
  var res: array of UBigInt;
  for var i := 0 to High(sols) do
    if (i = 0) or (sols[i] <> sols[i - 1]) then begin
      SetLength(res, Length(res) + 1);
      res[High(res)] := sols[i];
    end;
  result := res;
end;

function UBigInt.discreteLog(const target, m: UBigInt): Int64;
begin
  if m.isZero then RaiseDivByZero;
  if m.isOne then exit(0);
  var g := self mod m;
  var h := target mod m;
  if h.isOne then exit(0);
  if not g.gcd(m).isOne then raise EBigIntError.Create('discreteLog needs gcd(base, modulus) = 1');
  // baby-step giant-step over ceil(sqrt(m)) steps
  var nb := m.sqrt + 1;
  if nb > UBigInt(QWord(1) shl 20) then raise EBigIntError.Create('discreteLog search space too large');
  var steps := SizeInt(nb.toUInt64);
  // open-addressed table of the baby steps (g^j, keeping the least j)
  var cap: SizeInt := 1;
  while cap < steps * 2 do cap := cap shl 1;
  var mask := DWord(cap - 1);
  var htKey: array of UBigInt;
  var htVal: array of Int64;
  var htUsed: array of boolean;
  SetLength(htKey, cap);
  SetLength(htVal, cap);
  SetLength(htUsed, cap);
  var cur := UBigInt.one;
  for var j := 0 to steps - 1 do begin
    var slot := cur.hashCode and mask;
    var dup := false;
    while htUsed[slot] do begin
      if htKey[slot] = cur then begin
        dup := true;
        break;
      end;
      slot := (slot + 1) and mask;
    end;
    if not dup then begin
      htUsed[slot] := true;
      htKey[slot] := cur;
      htVal[slot] := j;
    end;
    cur := (cur * g) mod m;
  end;
  // giant steps: multiply by g^(-nb) and look each result up
  var factor := g.modPow(nb, m).modInverse(m);
  var nbq := Int64(nb.toUInt64);
  var gamma := h;
  for var i := 0 to steps do begin
    var slot := gamma.hashCode and mask;
    while htUsed[slot] do begin
      if htKey[slot] = gamma then exit(Int64(i) * nbq + htVal[slot]);
      slot := (slot + 1) and mask;
    end;
    gamma := (gamma * factor) mod m;
  end;
  result := -1;
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

function UBigInt.toBytesLE(len: SizeInt): TBytes;
begin
  if SizeInt((QWord(bitLength) + 7) shr 3) > len then raise ERangeError.Create($'UBigInt value does not fit in {len} bytes');
  result := toBytesLE();
  SetLength(result, len); // the grown tail is zero-filled
end;

function UBigInt.toBytesBE(len: SizeInt): TBytes;
begin
  result := toBytesLE(len);
  for var i := 0 to (len shr 1) - 1 do SwapValues(result[i], result[len - 1 - i]);
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
  for var i := 0 to fLen - 1 do begin
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

threadvar
  // per-thread generator state (zero-initialized per thread); the first random
  // draw in a thread lazily seeds from OS entropy (see LazySeed), so unseeded
  // values differ every run and across threads. BigIntRandomSeed makes the
  // calling thread reproducible
  xoshiroState: array[4] of QWord;
  pcgHi: QWord;
  pcgLo: QWord;
  splitmixState: QWord;

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

{$ifndef BIGINT_INT128}
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
{$endif}

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
  {$ifdef BIGINT_INT128}
  var state := ((UInt128(oldHi) shl 64) or oldLo) * ((UInt128(mHi) shl 64) or mLo) + ((UInt128(aHi) shl 64) or aLo);
  pcgHi := QWord(state shr 64);
  pcgLo := QWord(state);
  {$else}
  Mul64x64(oldLo, mLo, var hi, var lo);
  hi := hi + oldHi * mLo + oldLo * mHi;
  var newLo := lo + aLo;
  if newLo < lo then inc(hi);
  pcgHi := hi + aHi;
  pcgLo := newLo;
  {$endif}
  // output from the pre-advance state
  var rot := integer(oldHi shr 58);
  var x := oldHi xor oldLo;
  result := (x shr rot) or (x shl ((64 - rot) and 63));
end;

{$ifdef windows}
// RtlGenRandom, the loader-light OS entropy source
function SystemFunction036(buffer: Pointer; len: LongWord): ByteBool; stdcall; external 'advapi32' name 'SystemFunction036';
{$endif}

function TryOsEntropy(buf: PByte; len: SizeInt): boolean;
begin
  {$ifdef windows}
  result := SystemFunction036(buf, LongWord(len));
  {$else}
  result := false;
  var h := FileOpen('/dev/urandom', fmOpenRead);
  if h <> THandle(-1) then begin
    var got := FileRead(h, buf^, len);
    FileClose(h);
    result := got = len;
  end;
  {$endif}
end;

procedure OsEntropy(buf: PByte; len: SizeInt);
begin
  if TryOsEntropy(buf, len) then exit;
  // last-resort fallback: time-mixed splitmix stream
  var s := QWord(GetTickCount64) xor (QWord(PtrUInt(buf)) shl 24);
  for var i := 0 to len - 1 do buf[i] := byte(SplitMix64(s) shr 13);
end;

function OsEntropy64: QWord;
begin
  OsEntropy(@result, SizeOf(result));
end;

// seed the native generators (leaves RandSeed alone) from a 64-bit value
procedure SeedGenerators(seed: QWord);
begin
  splitmixState := seed;
  var s := seed;
  for var i := 0 to 3 do xoshiroState[i] := SplitMix64(s);
  // xoshiro must never sit in the all-zero state
  if (xoshiroState[0] or xoshiroState[1] or xoshiroState[2] or xoshiroState[3]) = 0 then xoshiroState[0] := QWord($9E3779B97F4A7C15);
  pcgLo := SplitMix64(s);
  pcgHi := SplitMix64(s);
end;

procedure BigIntRandomSeed(seed: QWord);
begin
  SeedGenerators(seed);
  RandSeed := LongInt(seed xor (seed shr 32));
end;

procedure BigIntRandomize;
begin
  BigIntRandomSeed(OsEntropy64);
end;

// pull OS entropy for this thread on its first draw, unless BigIntRandomSeed
// already primed the state (SeedGenerators never leaves xoshiro all-zero, so an
// all-zero state means "untouched"). RandSeed is left alone, keeping the
// rngSystem mode on the plain System.Random contract. Driven once per thread by
// the threadstatic guard in RandomLimb
function LazySeed: boolean;
begin
  if (xoshiroState[0] or xoshiroState[1] or xoshiroState[2] or xoshiroState[3]) = 0 then SeedGenerators(OsEntropy64);
  result := true;
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
  // the compiler's per-thread guard runs LazySeed once per thread
  threadstatic primed := LazySeed;
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

class function UBigInt.randomPrime(bits: LongWord; rounds: integer): UBigInt;
begin
  if bits < 2 then raise EBigIntError.Create('randomPrime needs at least 2 bits');
  if bits = 2 then exit(UBigInt(2) + randomBelow(UBigInt(2)));
  repeat
    // exact bit count: top bit set, odd
    result := random(bits);
    result.setBit(bits - 1);
    result.setBit(0);
  until result.isProbablePrime(rounds);
end;

class function UBigInt.randomSecure(bits: LongWord): UBigInt;
var
  res: TLimbs;
begin
  if bits = 0 then exit(default(UBigInt));
  var n := SizeInt((QWord(bits) + LIMB_MASK) shr LIMB_SHIFT);
  SetLength(res, n);
  if not TryOsEntropy(PByte(@res[0]), n * SizeOf(TLimb)) then raise EBigIntError.Create('no OS entropy source available');
  var top := bits and LIMB_MASK;
  if top <> 0 then res[n - 1] := res[n - 1] and (High(TLimb) shr (LIMB_BITS - top));
  LNorm(res);
  result.fLimbs := res;
end;

class function UBigInt.randomSecureBelow(const bound: UBigInt): UBigInt;
begin
  if bound.isZero then raise EBigIntError.Create('randomSecureBelow needs a positive bound');
  var bits := bound.bitLength;
  repeat
    result := randomSecure(bits);
  until result < bound;
end;

class function UBigInt.randomSecureRange(const lo, hi: UBigInt): UBigInt;
begin
  if lo > hi then raise EBigIntError.Create('randomSecureRange needs lo <= hi');
  result := lo + randomSecureBelow(hi - lo + 1);
end;

class function UBigInt.randomSecurePrime(bits: LongWord; rounds: integer): UBigInt;
begin
  if bits < 2 then raise EBigIntError.Create('randomSecurePrime needs at least 2 bits');
  if bits = 2 then exit(UBigInt(2) + randomSecureBelow(UBigInt(2)));
  repeat
    result := randomSecure(bits);
    result.setBit(bits - 1);
    result.setBit(0);
  until result.isProbablePrime(rounds);
end;

// balanced product of lo..hi, far fewer big*big multiplications than a plain loop
function UProdRange(lo, hi: LongWord): UBigInt;
begin
  if hi - lo < 8 then begin
    result := lo;
    for var i := lo + 1 to hi do result := result * Int64(i);
    exit;
  end;
  var mid := lo + (hi - lo) shr 1;
  result := UProdRange(lo, mid) * UProdRange(mid + 1, hi);
end;

class function UBigInt.factorial(n: LongWord): UBigInt;
begin
  if n < 2 then exit(UBigInt.one);
  result := UProdRange(2, n);
end;

// fast doubling: F(2k) = F(k)*(2F(k+1)-F(k)), F(2k+1) = F(k)^2+F(k+1)^2
procedure UFibPair(n: LongWord; out fn, fn1: UBigInt);
begin
  var a := UBigInt.zero;
  var b := UBigInt.one;
  if n > 0 then
    for var i := integer(BsrDWord(n)) downto 0 do begin
      var c := a * ((b shl 1) - a);
      var d := a.sqr + b.sqr;
      if (n shr i) and 1 = 1 then begin
        a := d;
        b := c + d;
      end else begin
        a := c;
        b := d;
      end;
    end;
  fn := a;
  fn1 := b;
end;

class function UBigInt.fibonacci(n: LongWord): UBigInt;
begin
  UFibPair(n, result, _);
end;

class function UBigInt.lucas(n: LongWord): UBigInt;
begin
  // L(n) = 2F(n+1) - F(n)
  UFibPair(n, var fn, var fn1);
  result := (fn1 shl 1) - fn;
end;

class function UBigInt.binomial(n, k: LongWord): UBigInt;
begin
  if k > n then exit(default(UBigInt));
  if k > n - k then k := n - k;
  // multiplicative form; every intermediate division is exact
  result := UBigInt.one;
  for var i := 1 to k do begin
    result := result * Int64(n - k + i);
    result := result div Int64(i);
  end;
end;

// C(nd, kd) mod prime p for digits nd, kd < p: multiplicative form with one
// batched inverse at the end
function ULucasDigit(const nd, kd, p: UBigInt): UBigInt;
begin
  if kd > nd then exit(default(UBigInt));
  var k2 := kd.min(nd - kd);
  var num := UBigInt.one;
  var den := UBigInt.one;
  var i := UBigInt.one;
  while i <= k2 do begin
    num := (num * ((nd - k2 + i) mod p)) mod p;
    den := (den * i) mod p;
    i := i + 1;
  end;
  result := (num * den.modInverse(p)) mod p;
end;

class function UBigInt.binomialMod(const n, k, p: UBigInt): UBigInt;
begin
  if p.isZero then RaiseDivByZero;
  if p.isOne then exit(default(UBigInt));
  if k > n then exit(default(UBigInt));
  // Lucas: multiply the digit binomials in base p
  result := UBigInt.one;
  var nn := n;
  var kk := k;
  while not kk.isZero do begin
    var (nq, nd) := nn.divMod(p);
    var (kq, kd) := kk.divMod(p);
    result := (result * ULucasDigit(nd, kd, p)) mod p;
    if result.isZero then exit;
    nn := nq;
    kk := kq;
  end;
end;

class function UBigInt.catalan(n: LongWord): UBigInt;
begin
  if n > High(LongWord) div 2 then raise EBigIntError.Create('catalan argument out of range');
  result := binomial(2 * n, n) div Int64(n + 1);
end;

// balanced product of a prime list slice
function UProdPrimes(const primes: array of LongWord; lo, hi: SizeInt): UBigInt;
begin
  if hi - lo < 8 then begin
    result := QWord(primes[lo]);
    for var i := lo + 1 to hi do result := result * Int64(primes[i]);
    exit;
  end;
  var mid := lo + (hi - lo) shr 1;
  result := UProdPrimes(primes, lo, mid) * UProdPrimes(primes, mid + 1, hi);
end;

class function UBigInt.primorial(n: LongWord): UBigInt;
var
  comp: array of boolean;
  primes: array of LongWord;
begin
  if n < 2 then exit(UBigInt.one);
  // sieve over odd numbers: index i stands for 2i+1
  var half := SizeInt((n - 1) div 2);
  SetLength(comp, half + 1);
  var i: SizeInt := 1;
  repeat
    var p := QWord(2 * i + 1);
    if p * p > n then break;
    if not comp[i] then begin
      var j := SizeInt((p * p - 1) div 2);
      while j <= half do begin
        comp[j] := true;
        inc(j, SizeInt(p));
      end;
    end;
    inc(i);
  until false;
  var cnt: SizeInt := 1; // the prime 2
  for var k := 1 to half do
    if not comp[k] then inc(cnt);
  SetLength(primes, cnt);
  primes[0] := 2;
  var idx: SizeInt := 1;
  for var k := 1 to half do
    if not comp[k] then begin
      primes[idx] := LongWord(2 * k + 1);
      inc(idx);
    end;
  result := UProdPrimes(primes, 0, cnt - 1);
end;

class function UBigInt.multinomial(const ks: array of LongWord): UBigInt;
begin
  result := UBigInt.one;
  var total: LongWord := 0;
  // product of binomials keeps every intermediate exact and small
  for var k in ks do begin
    total := total + k;
    result := result * binomial(total, k);
  end;
end;

class function UBigInt.risingFactorial(const x: UBigInt; n: LongWord): UBigInt;
begin
  result := UBigInt.one;
  for var i := 0 to Int64(n) - 1 do result := result * (x + i);
end;

class function UBigInt.fallingFactorial(const x: UBigInt; n: LongWord): UBigInt;
begin
  result := UBigInt.one;
  for var i := 0 to Int64(n) - 1 do begin
    if x < i then exit(default(UBigInt));
    result := result * (x - i);
  end;
end;

class function UBigInt.subfactorial(n: LongWord): UBigInt;
begin
  if n = 0 then exit(UBigInt.one);
  if n = 1 then exit(default(UBigInt));
  // D(k) = (k-1) * (D(k-1) + D(k-2))
  var a := UBigInt.one;
  var b := default(UBigInt);
  for var i := 2 to n do begin
    var c := Int64(i - 1) * (a + b);
    a := b;
    b := c;
  end;
  result := b;
end;

class function UBigInt.bell(n: LongWord): UBigInt;
var
  row: array of UBigInt;
begin
  // Bell triangle: each row starts with the previous row's last value
  row := [UBigInt.one];
  for var i := 1 to n do begin
    var next: array of UBigInt;
    SetLength(next, i + 1);
    next[0] := row[i - 1];
    for var j := 1 to i do next[j] := next[j - 1] + row[j - 1];
    row := next;
  end;
  result := row[0];
end;

class function UBigInt.stirling2(n, k: LongWord): UBigInt;
var
  dp: array of UBigInt;
begin
  if k > n then exit(default(UBigInt));
  if k = 0 then exit(if n = 0 then UBigInt.one else default(UBigInt));
  // S(i, j) = j*S(i-1, j) + S(i-1, j-1), rolled over j descending
  SetLength(dp, k + 1);
  dp[0] := UBigInt.one;
  for var i := 1 to n do begin
    var top := if i < k then i else k;
    for var j := top downto 1 do dp[j] := Int64(j) * dp[j] + dp[j - 1];
    dp[0] := default(UBigInt);
  end;
  result := dp[k];
end;

class function UBigInt.partitions(n: LongWord): UBigInt;
var
  p: array of BigInt;
begin
  SetLength(p, n + 1);
  p[0] := BigInt.one;
  for var m := 1 to Int64(n) do begin
    var sum := BigInt.zero;
    var k: Int64 := 1;
    while true do begin
      // generalized pentagonal numbers k(3k-1)/2 and k(3k+1)/2
      var g1 := k * (3 * k - 1) div 2;
      if g1 > m then break;
      var term := p[SizeInt(m - g1)];
      var g2 := k * (3 * k + 1) div 2;
      if g2 <= m then term := term + p[SizeInt(m - g2)];
      if (k and 1) = 1 then sum := sum + term else sum := sum - term;
      inc(k);
    end;
    p[SizeInt(m)] := sum;
  end;
  result := p[n].toUBigInt;
end;

class function UBigInt.randomSafePrime(bits: LongWord): UBigInt;
begin
  if bits < 3 then raise EBigIntError.Create('safe prime needs at least 3 bits');
  // p = 2q + 1 with q also prime (q is a Sophie Germain prime)
  while true do begin
    var q := UBigInt.randomPrime(bits - 1);
    var p := (q shl 1) + 1;
    if (p.bitLength = bits) and p.isProbablePrime then exit(p);
  end;
end;

class function UBigInt.randomStrongPrime(bits: LongWord): UBigInt;
begin
  if bits < 16 then raise EBigIntError.Create('strong prime needs at least 16 bits');
  // Gordon's algorithm: p-1 has the large factor s, p+1 the large factor r,
  // and r-1 the large factor t
  var half := bits div 2;
  var s := UBigInt.randomPrime(half);
  var t := UBigInt.randomPrime(half - 4);
  var r := (t shl 1) + 1;
  while not r.isProbablePrime do r := r + (t shl 1);
  var p0 := ((s.modPow(r - 2, r) * s) shl 1) - 1;
  var rs2 := (r * s) shl 1;
  var p := p0;
  while not p.isProbablePrime do p := p + rs2;
  result := p;
end;

class function UBigInt.primeCount(lo, hi: QWord): QWord;
var
  comp, seg: array of boolean;
  base: array of QWord;
begin
  if hi < 2 then exit(0);
  if lo < 2 then lo := 2;
  if lo > hi then exit(0);
  // sieve the base primes up to floor(sqrt(hi))
  var lim: QWord := 0;
  while (lim + 1) * (lim + 1) <= hi do inc(lim);
  SetLength(comp, SizeInt(lim) + 1);
  SetLength(base, SizeInt(lim div 2) + 8);
  var bcount: SizeInt := 0;
  var i: QWord := 2;
  while i <= lim do begin
    if not comp[i] then begin
      base[bcount] := i;
      inc(bcount);
      var j := i * i;
      while j <= lim do begin
        comp[j] := true;
        j := j + i;
      end;
    end;
    inc(i);
  end;
  // sweep [lo, hi] in cache-sized windows
  var total: QWord := 0;
  var segLen: SizeInt := 1 shl 15;
  SetLength(seg, segLen);
  var low := lo;
  while low <= hi do begin
    var high := low + QWord(segLen) - 1;
    if high > hi then high := hi;
    var span := SizeInt(high - low) + 1;
    for var s := 0 to span - 1 do seg[s] := false;
    for var bi := 0 to bcount - 1 do begin
      var p := base[bi];
      if p * p > high then break;
      var start := ((low + p - 1) div p) * p;
      if start < p * p then start := p * p;
      var j := start;
      while j <= high do begin
        seg[SizeInt(j - low)] := true;
        j := j + p;
      end;
    end;
    for var s := 0 to span - 1 do
      if not seg[s] then inc(total);
    if high = hi then break;
    low := high + 1;
  end;
  result := total;
end;

class function UBigInt.primePi(n: QWord): QWord;
begin
  result := primeCount(2, n);
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
    USetQWord(@result.fInline[0], result.fArr, result.fLen, QWord(x));
    result.fNeg := false;
  end else begin
    USetQWord(@result.fInline[0], result.fArr, result.fLen, NegAbs64(x));
    result.fNeg := true;
  end;
end;

// signed add of two sign/magnitude (ptr, len, neg) views straight into a
// destination record's storage fields
procedure SAddP(pa: PLimb; alen: SizeInt; aneg: boolean; pb: PLimb; blen: SizeInt; bneg: boolean; dst: PLimb; var rarr: TLimbs; var rlen: SizeInt; out rneg: boolean);
var
  m: TLimbs;
begin
  if aneg = bneg then begin
    m := LAddP(pa, alen, pb, blen);
    rneg := aneg and (Length(m) > 0);
    MoveArr(m, dst, rarr, rlen);
    exit;
  end;
  var c := LCmpP(pa, alen, pb, blen);
  if c = 0 then begin
    PutZero(dst, rarr, rlen);
    rneg := false;
  end else if c > 0 then begin
    m := LSubP(pa, alen, pb, blen);
    rneg := aneg;
    MoveArr(m, dst, rarr, rlen);
  end else begin
    m := LSubP(pb, blen, pa, alen);
    rneg := bneg;
    MoveArr(m, dst, rarr, rlen);
  end;
end;

procedure SMulP(pa: PLimb; alen: SizeInt; aneg: boolean; pb: PLimb; blen: SizeInt; bneg: boolean; dst: PLimb; var rarr: TLimbs; var rlen: SizeInt; out rneg: boolean);
var
  m: TLimbs;
begin
  m := LMulP(pa, alen, pb, blen);
  rneg := (aneg xor bneg) and (Length(m) > 0);
  MoveArr(m, dst, rarr, rlen);
end;

// truncated division: quotient toward zero, remainder takes the dividend sign
procedure SDivModP(pa: PLimb; alen: SizeInt; aneg: boolean; pb: PLimb; blen: SizeInt; bneg: boolean; out q, r: BigInt);
var
  qm, rm: TLimbs;
begin
  LDivModP(pa, alen, pb, blen, qm, rm);
  q.fNeg := (aneg xor bneg) and (Length(qm) > 0);
  MoveArr(qm, @q.fInline[0], q.fArr, q.fLen);
  r.fNeg := aneg and (Length(rm) > 0);
  MoveArr(rm, @r.fInline[0], r.fArr, r.fLen);
end;

// array-based entry points for the cold callers
function SAddPair(const am: TLimbs; an: boolean; const bm: TLimbs; bn: boolean): BigInt;
begin
  SAddP(PLimb(Pointer(am)), Length(am), an, PLimb(Pointer(bm)), Length(bm), bn, @result.fInline[0], result.fArr, result.fLen, result.fNeg);
end;

function SMulPair(const am: TLimbs; an: boolean; const bm: TLimbs; bn: boolean): BigInt;
begin
  SMulP(PLimb(Pointer(am)), Length(am), an, PLimb(Pointer(bm)), Length(bm), bn, @result.fInline[0], result.fArr, result.fLen, result.fNeg);
end;

procedure SDivModPair(const am: TLimbs; an: boolean; const bm: TLimbs; bn: boolean; out q, r: BigInt);
begin
  SDivModP(PLimb(Pointer(am)), Length(am), an, PLimb(Pointer(bm)), Length(bm), bn, q, r);
end;

function BCmp(const a, b: BigInt): integer;
begin
  if a.fNeg <> b.fNeg then exit(if a.fNeg then -1 else 1);
  var c := LCmpP(a.dataPtr, a.fLen, b.dataPtr, b.fLen);
  result := if a.fNeg then -c else c;
end;

function BCmpI64(const a: BigInt; v: Int64): integer;
begin
  var sa := if a.fLen = 0 then 0 else if a.fNeg then -1 else 1;
  var sv := if v > 0 then 1 else if v < 0 then -1 else 0;
  if sa <> sv then exit(if sa < sv then -1 else 1);
  if sa = 0 then exit(0);
  var c := LCmpQP(a.dataPtr, a.fLen, if v > 0 then QWord(v) else NegAbs64(v));
  result := if sa < 0 then -c else c;
end;

// lowest nonzero limb index, -1 for zero
function LLowestNZP(p: PLimb; len: SizeInt): SizeInt;
begin
  for var i := 0 to len - 1 do
    if p[i] <> 0 then exit(i);
  result := -1;
end;

// i-th limb of the infinite two's complement form of (p, len, neg)
function TCLimbAtP(p: PLimb; len: SizeInt; neg: boolean; lowNZ, i: SizeInt): TLimb; inline;
begin
  if not neg then result := if i < len then p[i] else 0
  else if i < lowNZ then result := 0
  else if i = lowNZ then result := (not p[i]) + 1
  else if i < len then result := not p[i]
  else result := High(TLimb);
end;

// negate a two's complement limb run in place (not + 1): limbs below the
// lowest nonzero one stay zero, that one negates, everything above inverts
procedure LTCNegateInPlaceP(p: PLimb; len: SizeInt);
begin
  var i := 0;
  while (i < len) and (p[i] = 0) do inc(i);
  if i >= len then exit;
  p[i] := TLimb(0) - p[i];
  for var j := i + 1 to len - 1 do p[j] := not p[j];
end;

type
  TBitOp = (boAnd, boOr, boXor);

function BBitOp(const a, b: BigInt; op: TBitOp): BigInt;
var
  res: TLimbs;
  buf: array[0..BIGINT_INLINE_LIMBS] of TLimb;
begin
  var la := a.fLen;
  var lb := b.fLen;
  var pa := a.dataPtr;
  var pb := b.dataPtr;
  // one limb above both operands captures the sign extension; small operands
  // compute on the stack with no allocation
  var n := MaxS(la, lb) + 1;
  var lowA := LLowestNZP(pa, la);
  var lowB := LLowestNZP(pb, lb);
  var pd: PLimb := @buf[0];
  if n > BIGINT_INLINE_LIMBS + 1 then begin
    res := LNew(n);
    pd := PLimb(Pointer(res));
  end;
  for var i := 0 to n - 1 do begin
    var x := TCLimbAtP(pa, la, a.fNeg, lowA, i);
    var y := TCLimbAtP(pb, lb, b.fNeg, lowB, i);
    pd[i] := case op of
      boAnd: x and y;
      boOr: x or y;
      boXor: x xor y;
    end;
  end;
  // the top limb came out either all zeros or all ones
  var neg := pd[n - 1] <> 0;
  if neg then LTCNegateInPlaceP(pd, n);
  var m := n;
  while (m > 0) and (pd[m - 1] = 0) do dec(m);
  result.fNeg := neg and (m > 0);
  if res = nil then begin
    if m <= BIGINT_INLINE_LIMBS then PutInline(@buf[0], m, @result.fInline[0], result.fArr, result.fLen)
    else PutSpill(@buf[0], m, result.fArr, result.fLen);
  end else begin
    SetLength(res, m);
    MoveArr(res, @result.fInline[0], result.fArr, result.fLen);
  end;
end;

// any nonzero bit among the n lowest bits (the bits a shr n drops)
function LAnyDroppedBitsP(p: PLimb; len: SizeInt; n: LongWord): boolean;
begin
  var limbShift := SizeInt(n shr LIMB_SHIFT);
  var bitShift := n and LIMB_MASK;
  for var i := 0 to MinS(limbShift, len) - 1 do
    if p[i] <> 0 then exit(true);
  if (bitShift > 0) and (limbShift < len) then exit(p[limbShift] and ((TLimb(1) shl bitShift) - 1) <> 0);
  result := false;
end;

class operator BigInt.:=(x: Int64): BigInt;
begin
  if x >= 0 then begin
    USetQWord(@result.fInline[0], result.fArr, result.fLen, QWord(x));
    result.fNeg := false;
  end else begin
    USetQWord(@result.fInline[0], result.fArr, result.fLen, NegAbs64(x));
    result.fNeg := true;
  end;
end;

class operator BigInt.:=(x: QWord): BigInt;
begin
  USetQWord(@result.fInline[0], result.fArr, result.fLen, x);
  result.fNeg := false;
end;

class operator BigInt.:=(const s: string): BigInt;
begin
  result := BigInt.parse(s);
end;

class operator BigInt.:=(const u: UBigInt): BigInt;
begin
  ShareMag(@u.fInline[0], u.fArr, u.fLen, @result.fInline[0], result.fArr, result.fLen);
  result.fNeg := false;
end;

class operator BigInt.explicit(d: Double): BigInt;
var
  u: UBigInt;
begin
  if DblIsNanOrInf(d) then raise EConvertError.Create('cannot convert NaN or Inf to BigInt');
  if d < 0 then begin
    u := UBigInt(-d);
    result.fLimbs := u.fLimbs;
    result.fNeg := u.fLen > 0;
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
  result := a.toUInt64;
end;

class operator BigInt.explicit(const a: BigInt): LongInt;
begin
  result := a.toInt32;
end;

class operator BigInt.explicit(const a: BigInt): LongWord;
begin
  result := a.toUInt32;
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

// signed add/sub of two small BigInts into typed destination fields; bNeg is
// b's effective sign (flipped for subtraction). false = not both inline
function BSignedInline(const a, b: BigInt; bNeg: boolean; dst: PLimb; var rarr: TLimbs; var rlen: SizeInt; out rneg: boolean): boolean;
begin
  if (a.fArr <> nil) or (b.fArr <> nil) then exit(false);
  SAddInlineP(@a.fInline[0], a.fLen, a.fNeg, @b.fInline[0], b.fLen, bNeg, dst, rarr, rlen, rneg);
  result := true;
end;

class operator BigInt.+(const a, b: BigInt): BigInt;
begin
  if BSignedInline(a, b, b.fNeg, @result.fInline[0], result.fArr, result.fLen, result.fNeg) then exit;
  SAddP(a.dataPtr, a.fLen, a.fNeg, b.dataPtr, b.fLen, b.fNeg, @result.fInline[0], result.fArr, result.fLen, result.fNeg);
end;

class operator BigInt.+(const a: BigInt; b: Int64): BigInt;
begin
  if a.fArr = nil then begin
    var bb: array[0..BIGINT_INLINE_LIMBS - 1] of TLimb;
    var bl := QToInline(if b >= 0 then QWord(b) else NegAbs64(b), @bb[0]);
    SAddInlineP(@a.fInline[0], a.fLen, a.fNeg, @bb[0], bl, b < 0, @result.fInline[0], result.fArr, result.fLen, result.fNeg);
    exit;
  end;
  var bq: array[0..BIGINT_INLINE_LIMBS - 1] of TLimb;
  var bql := QToInline(if b >= 0 then QWord(b) else NegAbs64(b), @bq[0]);
  SAddP(a.dataPtr, a.fLen, a.fNeg, @bq[0], bql, b < 0, @result.fInline[0], result.fArr, result.fLen, result.fNeg);
end;

class operator BigInt.+(a: Int64; const b: BigInt): BigInt;
begin
  result := b + a;
end;

class operator BigInt.-(const a, b: BigInt): BigInt;
begin
  if BSignedInline(a, b, not b.fNeg, @result.fInline[0], result.fArr, result.fLen, result.fNeg) then exit;
  SAddP(a.dataPtr, a.fLen, a.fNeg, b.dataPtr, b.fLen, not b.fNeg, @result.fInline[0], result.fArr, result.fLen, result.fNeg);
end;

class operator BigInt.-(const a: BigInt; b: Int64): BigInt;
begin
  if a.fArr = nil then begin
    var bb: array[0..BIGINT_INLINE_LIMBS - 1] of TLimb;
    var bl := QToInline(if b >= 0 then QWord(b) else NegAbs64(b), @bb[0]);
    SAddInlineP(@a.fInline[0], a.fLen, a.fNeg, @bb[0], bl, b >= 0, @result.fInline[0], result.fArr, result.fLen, result.fNeg);
    exit;
  end;
  var bq: array[0..BIGINT_INLINE_LIMBS - 1] of TLimb;
  var bql := QToInline(if b >= 0 then QWord(b) else NegAbs64(b), @bq[0]);
  SAddP(a.dataPtr, a.fLen, a.fNeg, @bq[0], bql, b >= 0, @result.fInline[0], result.fArr, result.fLen, result.fNeg);
end;

class operator BigInt.-(a: Int64; const b: BigInt): BigInt;
begin
  if b.fArr = nil then begin
    var ab: array[0..BIGINT_INLINE_LIMBS - 1] of TLimb;
    var al := QToInline(if a >= 0 then QWord(a) else NegAbs64(a), @ab[0]);
    SAddInlineP(@ab[0], al, a < 0, @b.fInline[0], b.fLen, not b.fNeg, @result.fInline[0], result.fArr, result.fLen, result.fNeg);
    exit;
  end;
  var aq: array[0..BIGINT_INLINE_LIMBS - 1] of TLimb;
  var aql := QToInline(if a >= 0 then QWord(a) else NegAbs64(a), @aq[0]);
  SAddP(@aq[0], aql, a < 0, b.dataPtr, b.fLen, not b.fNeg, @result.fInline[0], result.fArr, result.fLen, result.fNeg);
end;

class operator BigInt.*(const a, b: BigInt): BigInt;
begin
  if (a.fArr = nil) and (b.fArr = nil) then begin
    MulInline(@a.fInline[0], a.fLen, @b.fInline[0], b.fLen, @result.fInline[0], result.fArr, result.fLen);
    result.fNeg := (a.fNeg xor b.fNeg) and (result.fLen > 0);
    exit;
  end;
  SMulP(a.dataPtr, a.fLen, a.fNeg, b.dataPtr, b.fLen, b.fNeg, @result.fInline[0], result.fArr, result.fLen, result.fNeg);
end;

class operator BigInt.*(const a: BigInt; b: Int64): BigInt;
begin
  if a.fArr = nil then begin
    var bb: array[0..BIGINT_INLINE_LIMBS - 1] of TLimb;
    var bl := QToInline(if b >= 0 then QWord(b) else NegAbs64(b), @bb[0]);
    MulInline(@a.fInline[0], a.fLen, @bb[0], bl, @result.fInline[0], result.fArr, result.fLen);
    result.fNeg := (a.fNeg xor (b < 0)) and (result.fLen > 0);
    exit;
  end;
  var bq: array[0..BIGINT_INLINE_LIMBS - 1] of TLimb;
  var bql := QToInline(if b >= 0 then QWord(b) else NegAbs64(b), @bq[0]);
  SMulP(a.dataPtr, a.fLen, a.fNeg, @bq[0], bql, b < 0, @result.fInline[0], result.fArr, result.fLen, result.fNeg);
end;

class operator BigInt.*(a: Int64; const b: BigInt): BigInt;
begin
  result := b * a;
end;

class operator BigInt.div(const a, b: BigInt): BigInt;
var
  q, r: BigInt;
begin
  if b.fLen = 0 then RaiseDivByZero;
  if (b.fArr = nil) and (a.fLen <= 2 * BIGINT_INLINE_LIMBS) then begin
    var qb, rb: array[0..2 * BIGINT_INLINE_LIMBS - 1] of TLimb;
    DivModInline(a.dataPtr, a.fLen, @b.fInline[0], b.fLen, @qb[0], var ql, @rb[0], _);
    if ql <= BIGINT_INLINE_LIMBS then PutInline(@qb[0], ql, @result.fInline[0], result.fArr, result.fLen)
    else PutSpill(@qb[0], ql, result.fArr, result.fLen);
    result.fNeg := (a.fNeg xor b.fNeg) and (result.fLen > 0);
    exit;
  end;
  SDivModP(a.dataPtr, a.fLen, a.fNeg, b.dataPtr, b.fLen, b.fNeg, q, r);
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
  if b.fLen = 0 then RaiseDivByZero;
  if (b.fArr = nil) and (a.fLen <= 2 * BIGINT_INLINE_LIMBS) then begin
    var qb, rb: array[0..2 * BIGINT_INLINE_LIMBS - 1] of TLimb;
    DivModInline(a.dataPtr, a.fLen, @b.fInline[0], b.fLen, @qb[0], _, @rb[0], var rl);
    if rl <= BIGINT_INLINE_LIMBS then PutInline(@rb[0], rl, @result.fInline[0], result.fArr, result.fLen)
    else PutSpill(@rb[0], rl, result.fArr, result.fLen);
    result.fNeg := a.fNeg and (result.fLen > 0);
    exit;
  end;
  SDivModP(a.dataPtr, a.fLen, a.fNeg, b.dataPtr, b.fLen, b.fNeg, q, r);
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
  if b.fLen = 0 then begin
    result.fLimbs := LFromQWord(1);
    result.fNeg := false;
    exit;
  end;
  if a.fLen = 0 then exit(default(BigInt));
  m := UPowQ(a.fLimbs, b.toUInt64);
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
  if a.fLen = 0 then exit(default(BigInt));
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
  var neg := (not a.fNeg) and (a.fLen > 0);
  ShareMag(@a.fInline[0], a.fArr, a.fLen, @result.fInline[0], result.fArr, result.fLen);
  result.fNeg := neg;
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
  if a.fLen = 0 then exit(default(BigInt));
  if n > High(LongWord) then raise EBigIntError.Create('shift count out of range');
  if (a.fArr = nil) and (a.fLen + SizeInt(QWord(n) shr LIMB_SHIFT) <= BIGINT_INLINE_LIMBS) then begin
    ShlInline(@a.fInline[0], a.fLen, LongWord(n), @result.fInline[0], result.fArr, result.fLen);
    result.fNeg := a.fNeg;
    exit;
  end;
  m := LShlP(a.dataPtr, a.fLen, LongWord(n));
  result.fNeg := a.fNeg;
  MoveArr(m, @result.fInline[0], result.fArr, result.fLen);
end;

class operator BigInt.shr(const a: BigInt; n: Int64): BigInt;
var
  m: TLimbs;
begin
  if n < 0 then raise ERangeError.Create('negative shift count');
  if a.fLen = 0 then exit(default(BigInt));
  if not a.fNeg then begin
    if n > High(LongWord) then exit(default(BigInt));
    if a.fArr = nil then begin
      ShrInline(@a.fInline[0], a.fLen, LongWord(n), @result.fInline[0], result.fArr, result.fLen);
      result.fNeg := false;
      exit;
    end;
    m := LShrP(a.dataPtr, a.fLen, LongWord(n));
    result.fNeg := false;
    MoveArr(m, @result.fInline[0], result.fArr, result.fLen);
    exit;
  end;
  // negative: arithmetic shift rounds toward -infinity
  if n > High(LongWord) then begin
    result.fLimbs := LFromQWord(1);
    result.fNeg := true;
    exit;
  end;
  var dropped := LAnyDroppedBitsP(a.dataPtr, a.fLen, LongWord(n));
  if a.fArr = nil then begin
    ShrInline(@a.fInline[0], a.fLen, LongWord(n), @result.fInline[0], result.fArr, result.fLen);
    if dropped then begin
      var ob: array[0..BIGINT_INLINE_LIMBS - 1] of TLimb;
      var ol := QToInline(1, @ob[0]);
      AddInline(@result.fInline[0], result.fLen, @ob[0], ol, @result.fInline[0], result.fArr, result.fLen);
    end;
    result.fNeg := result.fLen > 0;
    exit;
  end;
  m := LShrP(a.dataPtr, a.fLen, LongWord(n));
  if dropped then begin
    // m is freshly built: increment in place, growing only on a full carry
    if Length(m) = 0 then m := LFromQWord(1)
    else if MpnAdd1(PLimb(Pointer(m)), PLimb(Pointer(m)), Length(m), 1) <> 0 then begin
      SetLength(m, Length(m) + 1);
      m[High(m)] := 1;
    end;
  end;
  result.fNeg := Length(m) > 0;
  MoveArr(m, @result.fInline[0], result.fArr, result.fLen);
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
  ob: array[0..BIGINT_INLINE_LIMBS - 1] of TLimb;
begin
  var ol := QToInline(1, @ob[0]);
  if a.fNeg then begin
    // not(-m) = m - 1, m >= 1 here
    if a.fArr = nil then begin
      SubInline(@a.fInline[0], a.fLen, @ob[0], @result.fInline[0], result.fArr, result.fLen);
      result.fNeg := false;
      exit;
    end;
    m := LSubP(a.dataPtr, a.fLen, @ob[0], ol);
    result.fNeg := false;
  end else begin
    // not(m) = -(m + 1)
    if a.fArr = nil then begin
      AddInline(@a.fInline[0], a.fLen, @ob[0], ol, @result.fInline[0], result.fArr, result.fLen);
      result.fNeg := true;
      exit;
    end;
    m := LAddP(a.dataPtr, a.fLen, @ob[0], ol);
    result.fNeg := true;
  end;
  MoveArr(m, @result.fInline[0], result.fArr, result.fLen);
end;

class operator BigInt.=(const a, b: BigInt): boolean;
begin
  result := BEqB(a, b);
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
  result := not BEqB(a, b);
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
  result := BLess(a, b);
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
  result := not BLess(b, a);
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
  result := BLess(b, a);
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
  result := not BLess(a, b);
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

function BigInt.toInt8: Int8;
begin
  if not fitsInInt8 then raise ERangeError.Create('BigInt value does not fit in Int8');
  result := Int8(toInt64);
end;

function BigInt.toUInt8: UInt8;
begin
  if not fitsInUInt8 then raise ERangeError.Create('BigInt value does not fit in UInt8');
  result := UInt8(LToQWordP(dataPtr, fLen));
end;

function BigInt.toInt16: Int16;
begin
  if not fitsInInt16 then raise ERangeError.Create('BigInt value does not fit in Int16');
  result := Int16(toInt64);
end;

function BigInt.toUInt16: UInt16;
begin
  if not fitsInUInt16 then raise ERangeError.Create('BigInt value does not fit in UInt16');
  result := UInt16(LToQWordP(dataPtr, fLen));
end;

function BigInt.toInt32: Int32;
begin
  if not fitsInInt32 then raise ERangeError.Create('BigInt value does not fit in Int32');
  result := Int32(toInt64);
end;

function BigInt.toUInt32: UInt32;
begin
  if not fitsInUInt32 then raise ERangeError.Create('BigInt value does not fit in UInt32');
  result := UInt32(LToQWordP(dataPtr, fLen));
end;

function BigInt.toInt64: Int64;
begin
  if not fitsInInt64 then raise ERangeError.Create('BigInt value does not fit in Int64');
  var q := LToQWordP(dataPtr, fLen);
  result := if fNeg then Int64((not q) + 1) else Int64(q);
end;

function BigInt.toUInt64: UInt64;
begin
  if not fitsInUInt64 then raise ERangeError.Create('BigInt value does not fit in UInt64');
  result := LToQWordP(dataPtr, fLen);
end;

{$ifdef BIGINT_HAS_INT128}
function BigInt.toInt128: Int128;
begin
  if not fitsInInt128 then raise ERangeError.Create('BigInt value does not fit in Int128');
  var m := (UInt128(LExtract64(fLimbs, 64)) shl 64) or UInt128(LExtract64(fLimbs, 0));
  result := if fNeg then -Int128(m) else Int128(m);
end;

function BigInt.toUInt128: UInt128;
begin
  if not fitsInUInt128 then raise ERangeError.Create('BigInt value does not fit in UInt128');
  result := (UInt128(LExtract64(fLimbs, 64)) shl 64) or UInt128(LExtract64(fLimbs, 0));
end;
{$endif}

function BigInt.toDouble: Double;
begin
  result := magnitude.toDouble;
  if fNeg then result := -result;
end;

function BigInt.toUBigInt: UBigInt;
begin
  if fNeg then RaiseNegativeUnsigned;
  ShareMag(@fInline[0], fArr, fLen, @result.fInline[0], result.fArr, result.fLen);
end;

// bitLength is the minimal two's complement width minus the sign bit, so a
// signed N-bit target holds every value shorter than N bits
function BigInt.fitsInInt8: boolean;
begin
  result := bitLength < 8;
end;

function BigInt.fitsInUInt8: boolean;
begin
  result := (not fNeg) and (bitLength <= 8);
end;

function BigInt.fitsInInt16: boolean;
begin
  result := bitLength < 16;
end;

function BigInt.fitsInUInt16: boolean;
begin
  result := (not fNeg) and (bitLength <= 16);
end;

function BigInt.fitsInInt32: boolean;
begin
  result := bitLength < 32;
end;

function BigInt.fitsInUInt32: boolean;
begin
  result := (not fNeg) and (bitLength <= 32);
end;

function BigInt.fitsInInt64: boolean;
begin
  result := bitLength < 64;
end;

function BigInt.fitsInUInt64: boolean;
begin
  result := (not fNeg) and (bitLength <= 64);
end;

{$ifdef BIGINT_HAS_INT128}
function BigInt.fitsInInt128: boolean;
begin
  result := bitLength < 128;
end;

function BigInt.fitsInUInt128: boolean;
begin
  result := (not fNeg) and (bitLength <= 128);
end;
{$endif}

function BigInt.isZero: boolean;
begin
  result := fLen = 0;
end;

function BigInt.isOne: boolean;
begin
  result := (not fNeg) and (fLen = 1) and (dataPtr[0] = 1);
end;

function BigInt.isEven: boolean;
begin
  result := (fLen = 0) or (dataPtr[0] and 1 = 0);
end;

function BigInt.isOdd: boolean;
begin
  result := (fLen > 0) and (dataPtr[0] and 1 = 1);
end;

function BigInt.isNegative: boolean;
begin
  result := fNeg;
end;

function BigInt.isPositive: boolean;
begin
  result := (not fNeg) and (fLen > 0);
end;

function BigInt.isPowerOfTwo: boolean;
begin
  result := (not fNeg) and (LPopCount(fLimbs) = 1);
end;

function BigInt.sign: integer;
begin
  result := if fLen = 0 then 0 else if fNeg then -1 else 1;
end;

function BigInt.abs: BigInt;
begin
  ShareMag(@fInline[0], fArr, fLen, @result.fInline[0], result.fArr, result.fLen);
  result.fNeg := false;
end;

function BigInt.magnitude: UBigInt;
begin
  ShareMag(@fInline[0], fArr, fLen, @result.fInline[0], result.fArr, result.fLen);
end;

procedure BigInt.negate;
begin
  if fLen > 0 then fNeg := not fNeg;
end;

function BigInt.bitLength: LongWord;
begin
  if fLen = 0 then exit(0);
  var p := dataPtr;
  var top := p[fLen - 1];
  result := LongWord(fLen) * LIMB_BITS - (LIMB_BITS - 1 - LimbBsr(top));
  // for negatives the minimal two's complement form of -2^k needs one bit less
  if fNeg and (top and (top - 1) = 0) then begin
    var isPow2 := true;
    for var i := 0 to fLen - 2 do if p[i] <> 0 then begin isPow2 := false; break; end;
    if isPow2 then dec(result);
  end;
end;

function BigInt.popCount: LongWord;
begin
  // for negatives: bits that differ from the (one) sign bit, like Java bitCount
  result := if fNeg then LPopCount(LSub(fLimbs, LFromQWord(1))) else LPopCount(fLimbs);
end;

function BigInt.lowestSetBit: Int64;
begin
  // two's complement negation keeps the lowest set bit in place
  var p := dataPtr;
  for var i := 0 to fLen - 1 do
    if p[i] <> 0 then exit(Int64(i) * LIMB_BITS + LimbBsf(p[i]));
  result := -1;
end;

function BigInt.testBit(i: LongWord): boolean;
begin
  if not fNeg then exit(LTestBitP(dataPtr, fLen, i));
  var v := TCLimbAtP(dataPtr, fLen, true, LLowestNZP(dataPtr, fLen), SizeInt(i shr LIMB_SHIFT));
  result := (v shr (i and LIMB_MASK)) and 1 <> 0;
end;

procedure BigInt.setBit(i: LongWord);
begin
  if not fNeg then begin
    var limb := SizeInt(i shr LIMB_SHIFT);
    var mask := TLimb(1) shl (i and LIMB_MASK);
    if limb < fLen then begin
      if fArr = nil then begin
        fInline[limb] := fInline[limb] or mask;
        exit;
      end;
      if ArrUnshared(fArr) then begin
        fArr[limb] := fArr[limb] or mask;
        exit;
      end;
    end else if (fArr = nil) and (limb < BIGINT_INLINE_LIMBS) then begin
      fInline[limb] := mask;
      fLen := limb + 1;
      exit;
    end;
    var l := fLimbs;
    SetLength(l, MaxS(Length(l), limb + 1));
    l[limb] := l[limb] or mask;
    fLimbs := l;
  end else self := self or (BigInt(1) shl i);
end;

procedure BigInt.clearBit(i: LongWord);
begin
  if not fNeg then begin
    var limb := SizeInt(i shr LIMB_SHIFT);
    if limb >= fLen then exit;
    var mask := not (TLimb(1) shl (i and LIMB_MASK));
    if fArr = nil then begin
      fInline[limb] := fInline[limb] and mask;
      while (fLen > 0) and (fInline[fLen - 1] = 0) do dec(fLen);
      exit;
    end;
    if ArrUnshared(fArr) then begin
      fArr[limb] := fArr[limb] and mask;
      while (fLen > 0) and (fArr[fLen - 1] = 0) do dec(fLen);
      exit;
    end;
    var l := fLimbs;
    SetLength(l, Length(l)); // un-share: the getter may hand out fArr itself
    l[limb] := l[limb] and mask;
    fLimbs := l; // the setter normalizes
  end else self := self and not (BigInt(1) shl i);
end;

procedure BigInt.flipBit(i: LongWord);
begin
  if not fNeg then begin
    var limb := SizeInt(i shr LIMB_SHIFT);
    var mask := TLimb(1) shl (i and LIMB_MASK);
    if limb < fLen then begin
      if fArr = nil then begin
        fInline[limb] := fInline[limb] xor mask;
        while (fLen > 0) and (fInline[fLen - 1] = 0) do dec(fLen);
        exit;
      end;
      if ArrUnshared(fArr) then begin
        fArr[limb] := fArr[limb] xor mask;
        while (fLen > 0) and (fArr[fLen - 1] = 0) do dec(fLen);
        exit;
      end;
    end else if (fArr = nil) and (limb < BIGINT_INLINE_LIMBS) then begin
      fInline[limb] := mask;
      fLen := limb + 1;
      exit;
    end;
    var l := fLimbs;
    SetLength(l, MaxS(Length(l), limb + 1));
    l[limb] := l[limb] xor mask;
    fLimbs := l;
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

function BigInt.equalsCT(const other: BigInt): boolean;
begin
  // both operands evaluate before the combine, so the sign check cannot
  // short-circuit past the magnitude scan
  var eqMag := magnitude.equalsCT(other.magnitude);
  result := eqMag and (fNeg = other.fNeg);
end;

function BigInt.compareCT(const other: BigInt): integer;
begin
  var c := magnitude.compareCT(other.magnitude);
  // equal signs use the magnitude order (flipped when both negative), mixed
  // signs decide on the sign alone; branch-free select
  var same := integer(ord(fNeg = other.fNeg));
  result := same * c * (1 - 2 * ord(fNeg)) + (1 - same) * (ord(other.fNeg) - ord(fNeg));
end;

procedure BigInt.secureClear;
begin
  FillChar(fInline, SizeOf(fInline), 0);
  if (fArr <> nil) and ArrUnshared(fArr) then FillChar(fArr[0], Length(fArr) * SizeOf(TLimb), 0);
  fArr := nil;
  fLen := 0;
  fNeg := false;
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
  if d.fLen = 0 then RaiseDivByZero;
  if (d.fArr = nil) and (fLen <= 2 * BIGINT_INLINE_LIMBS) then begin
    var qb, rb: array[0..2 * BIGINT_INLINE_LIMBS - 1] of TLimb;
    DivModInline(dataPtr, fLen, @d.fInline[0], d.fLen, @qb[0], var ql, @rb[0], var rl);
    if ql <= BIGINT_INLINE_LIMBS then PutInline(@qb[0], ql, @qq.fInline[0], qq.fArr, qq.fLen)
    else PutSpill(@qb[0], ql, qq.fArr, qq.fLen);
    qq.fNeg := (fNeg xor d.fNeg) and (qq.fLen > 0);
    if rl <= BIGINT_INLINE_LIMBS then PutInline(@rb[0], rl, @rr.fInline[0], rr.fArr, rr.fLen)
    else PutSpill(@rb[0], rl, rr.fArr, rr.fLen);
    rr.fNeg := fNeg and (rr.fLen > 0);
    exit(qq, rr);
  end;
  SDivModP(dataPtr, fLen, fNeg, d.dataPtr, d.fLen, d.fNeg, qq, rr);
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
  var t := self;
  self := other;
  other := t;
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
  lm: TLimbs;
begin
  result := TryParseLimbs(s, 0, lm, neg);
  v.fLimbs := lm;
  v.fNeg := result and neg and (Length(lm) <> 0);
end;

class function BigInt.tryParse(const s: string; base: integer; out v: BigInt): boolean;
var
  neg: boolean;
  lm: TLimbs;
begin
  if (base < 2) or (base > 36) then raise EBigIntError.Create($'invalid base {base}, expected 2..36');
  result := TryParseLimbs(s, base, lm, neg);
  v.fLimbs := lm;
  v.fNeg := result and neg and (Length(lm) <> 0);
end;

function TUBigIntBridge.toBigInt: BigInt;
begin
  ShareMag(@fInline[0], fArr, fLen, @result.fInline[0], result.fArr, result.fLen);
  result.fNeg := false;
end;

function TUBigIntBridge.toDecimal: BigDecimal;
begin
  result := self;
end;

function TUBigIntBridge.gcdExt(const other: UBigInt): (g: UBigInt; x, y: BigInt);
begin
  var (g, x, y) := toBigInt.gcdExt(other.toBigInt);
  exit(g.toUBigInt, x, y);
end;

function TBigIntBridge.toDecimal: BigDecimal;
begin
  result := self;
end;

function BigInt.sqr: BigInt;
begin
  result.fNeg := false;
  if fArr = nil then begin
    MulInline(@fInline[0], fLen, @fInline[0], fLen, @result.fInline[0], result.fArr, result.fLen);
    exit;
  end;
  var t := LSqrP(dataPtr, fLen);
  MoveArr(t, @result.fInline[0], result.fArr, result.fLen);
  result.fNeg := false;
end;

function BigInt.sqrt: BigInt;
begin
  if fNeg then raise EBigIntError.Create('square root of a negative value');
  result := magnitude.sqrt.toBigInt;
end;

function BigInt.nthRoot(n: LongWord): BigInt;
begin
  if not fNeg then exit(magnitude.nthRoot(n).toBigInt);
  if n and 1 = 0 then raise EBigIntError.Create('even root of a negative value');
  result := -magnitude.nthRoot(n).toBigInt;
end;

function BigInt.pow(e: LongWord): BigInt;
begin
  result.fLimbs := UPowQ(fLimbs, e);
  result.fNeg := fNeg and (e and 1 = 1) and (result.fLen > 0);
end;

function BigInt.modPow(const e, m: BigInt): BigInt;
begin
  if m.sign <= 0 then raise EBigIntError.Create('modulus must be positive');
  var mm := m.toUBigInt;
  var base := floorMod(m).toUBigInt;
  if e.isNegative then base := base.modInverse(mm);
  result := base.modPow(e.magnitude, mm).toBigInt;
end;

function BigInt.modInverse(const m: BigInt): BigInt;
begin
  if m.sign <= 0 then raise EBigIntError.Create('modulus must be positive');
  result := floorMod(m).toUBigInt.modInverse(m.toUBigInt).toBigInt;
end;

function BigInt.gcd(const other: BigInt): BigInt;
begin
  result := magnitude.gcd(other.magnitude).toBigInt;
end;

function BigInt.lcm(const other: BigInt): BigInt;
begin
  result := magnitude.lcm(other.magnitude).toBigInt;
end;

function BigInt.isProbablePrime(rounds: integer): boolean;
begin
  result := (not fNeg) and magnitude.isProbablePrime(rounds);
end;

function BigInt.isPrime: boolean;
begin
  result := (not fNeg) and magnitude.isPrime;
end;

function BigInt.nextPrime: BigInt;
begin
  if fNeg or (fLen = 0) then exit(BigInt(2));
  result := magnitude.nextPrime.toBigInt;
end;

function BigInt.prevPrime: BigInt;
begin
  if self <= 2 then raise EBigIntError.Create('no prime below 2');
  result := magnitude.prevPrime.toBigInt;
end;

function BigInt.gcdExt(const other: BigInt): (g, x, y: BigInt);
begin
  // extended Euclid: g = self*x + other*y with g >= 0
  var oldR := self;
  var r := other;
  var oldS := BigInt.one;
  var s := BigInt.zero;
  var oldT := BigInt.zero;
  var t := BigInt.one;
  while not r.isZero do begin
    var (q, rem) := oldR.divMod(r);
    oldR := r;
    r := rem;
    (oldS, s) := (s, oldS - q * s);
    (oldT, t) := (t, oldT - q * t);
  end;
  if oldR.isNegative then begin
    oldR.negate;
    oldS.negate;
    oldT.negate;
  end;
  exit(oldR, oldS, oldT);
end;

function BigInt.jacobi(const n: BigInt): integer;
begin
  if n.fNeg or not n.isOdd then raise EBigIntError.Create('jacobi symbol needs an odd positive modulus');
  result := UJacobi(floorMod(n).toUBigInt, n.magnitude);
end;

function BigInt.kronecker(const n: BigInt): integer;
begin
  result := KroneckerSym(self, n);
end;

function BigInt.modSqrt(const p: BigInt): BigInt;
begin
  if p.sign <= 0 then raise EBigIntError.Create('modulus must be positive');
  result := floorMod(p).toUBigInt.modSqrt(p.toUBigInt).toBigInt;
end;

function BigInt.nthRootMod(k: LongWord; const p: BigInt): BigInt;
begin
  if p.sign <= 0 then raise EBigIntError.Create('modulus must be positive');
  result := floorMod(p).toUBigInt.nthRootMod(k, p.toUBigInt).toBigInt;
end;

function BigInt.multiplicativeOrder(const m: BigInt): BigInt;
begin
  if m.sign <= 0 then raise EBigIntError.Create('modulus must be positive');
  result := floorMod(m).toUBigInt.multiplicativeOrder(m.toUBigInt).toBigInt;
end;

function BigInt.isPrimitiveRoot(const m: BigInt): boolean;
begin
  if m.sign <= 0 then raise EBigIntError.Create('modulus must be positive');
  result := floorMod(m).toUBigInt.isPrimitiveRoot(m.toUBigInt);
end;

function BigInt.primitiveRoot: BigInt;
begin
  if sign <= 0 then raise EBigIntError.Create('modulus must be positive');
  result := toUBigInt.primitiveRoot.toBigInt;
end;

function BigInt.sqrtRem: (root, rem: BigInt);
begin
  if fNeg then raise EBigIntError.Create('square root of a negative value');
  var (r, m) := magnitude.sqrtRem;
  exit(r.toBigInt, m.toBigInt);
end;

function BigInt.isPerfectSquare: boolean;
begin
  result := (not fNeg) and magnitude.isPerfectSquare;
end;

function BigInt.factorize: array of (p: BigInt; e: LongWord);
var
  res: array of (p: BigInt; e: LongWord);
begin
  var uf := magnitude.factorize;
  SetLength(res, Length(uf));
  for var i := 0 to High(uf) do res[i] := (uf[i].p.toBigInt, uf[i].e);
  result := res;
end;

// number-theoretic functions all read the magnitude
function BigInt.eulerPhi: BigInt;
begin
  result := magnitude.eulerPhi.toBigInt;
end;

function BigInt.carmichaelLambda: BigInt;
begin
  result := magnitude.carmichaelLambda.toBigInt;
end;

function BigInt.moebius: integer;
begin
  result := magnitude.moebius;
end;

function BigInt.sigma(k: LongWord): BigInt;
begin
  result := magnitude.sigma(k).toBigInt;
end;

function BigInt.tau: BigInt;
begin
  result := magnitude.tau.toBigInt;
end;

function BigInt.radical: BigInt;
begin
  result := magnitude.radical.toBigInt;
end;

function BigInt.divisors: array of BigInt;
var
  res: array of BigInt;
begin
  var ud := magnitude.divisors;
  SetLength(res, Length(ud));
  for var i := 0 to High(ud) do res[i] := ud[i].toBigInt;
  result := res;
end;

function BigInt.isSquarefree: boolean;
begin
  result := magnitude.isSquarefree;
end;

function BigInt.isPerfect: boolean;
begin
  result := (not fNeg) and magnitude.isPerfect;
end;

function BigInt.isCarmichael: boolean;
begin
  result := (not fNeg) and magnitude.isCarmichael;
end;

function BigInt.isKthPower(k: LongWord): boolean;
begin
  // an even root of a negative value cannot be a perfect power
  if fNeg and (k and 1 = 0) then exit(false);
  result := magnitude.isKthPower(k);
end;

function BigInt.toBytesLE: TBytes;
var
  res: TBytes;
begin
  // minimal two's complement including the sign bit
  var n := SizeInt(bitLength div 8) + 1;
  SetLength(res, n);
  var p := dataPtr;
  var low := LLowestNZP(p, fLen);
  for var i := 0 to n - 1 do res[i] := byte(TCLimbAtP(p, fLen, fNeg, low, i shr BYTES_SHIFT) shr ((i and BYTES_MASK) * 8));
  result := res;
end;

function BigInt.toBytesBE: TBytes;
begin
  result := toBytesLE;
  for var i := 0 to (Length(result) shr 1) - 1 do SwapValues(result[i], result[High(result) - i]);
end;

function BigInt.toBytesLE(len: SizeInt): TBytes;
begin
  // bitLength is already minimal-two's-complement aware, so the sign bit fits
  // exactly when it is below 8*len
  if Int64(bitLength) > Int64(len) * 8 - 1 then raise ERangeError.Create($'BigInt value does not fit in {len} bytes');
  result := toBytesLE();
  var n := Length(result);
  SetLength(result, len);
  if fNeg then
    for var i := n to len - 1 do result[i] := $FF;
end;

function BigInt.toBytesBE(len: SizeInt): TBytes;
begin
  result := toBytesLE(len);
  for var i := 0 to (len shr 1) - 1 do SwapValues(result[i], result[len - 1 - i]);
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
  if neg then LTCNegateInPlaceP(PLimb(Pointer(res)), Length(res));
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

function BigInt.toRoman: string;
const
  vals: array[0..12] of integer = (1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1);
  syms: array[0..12] of string = ('M', 'CM', 'D', 'CD', 'C', 'XC', 'L', 'XL', 'X', 'IX', 'V', 'IV', 'I');
begin
  if (sign <= 0) or (self > 3999) then raise EConvertError.Create('toRoman needs a value in 1..3999');
  var n := toInt32;
  result := '';
  for var i := 0 to High(vals) do
    while n >= vals[i] do begin
      result := result + syms[i];
      n := n - vals[i];
    end;
end;

function BigInt.toWords: string;
const
  ones: array[0..19] of string = ('zero', 'one', 'two', 'three', 'four', 'five',
    'six', 'seven', 'eight', 'nine', 'ten', 'eleven', 'twelve', 'thirteen',
    'fourteen', 'fifteen', 'sixteen', 'seventeen', 'eighteen', 'nineteen');
  tens: array[2..9] of string = ('twenty', 'thirty', 'forty', 'fifty', 'sixty',
    'seventy', 'eighty', 'ninety');
  // short-scale group names, up to 10^66 (limit of this table)
  scales: array[0..22] of string = ('', ' thousand', ' million', ' billion',
    ' trillion', ' quadrillion', ' quintillion', ' sextillion', ' septillion',
    ' octillion', ' nonillion', ' decillion', ' undecillion', ' duodecillion',
    ' tredecillion', ' quattuordecillion', ' quindecillion', ' sexdecillion',
    ' septendecillion', ' octodecillion', ' novemdecillion', ' vigintillion',
    ' unvigintillion');

  // words for a value 0..999 (no leading/trailing spaces)
  function under1000(v: integer): string;
  begin
    result := '';
    if v >= 100 then begin
      result := ones[v div 100] + ' hundred';
      v := v mod 100;
      if v > 0 then result := result + ' ';
    end;
    if v >= 20 then begin
      result := result + tens[v div 10];
      if v mod 10 > 0 then result := result + '-' + ones[v mod 10];
    end else if v > 0 then result := result + ones[v];
  end;

begin
  if isZero then exit('zero');
  // split into base-1000 groups, low to high
  var groups: array of integer;
  var m := magnitude;
  var thousand := UBigInt(1000);
  while not m.isZero do begin
    var (q, r) := m.divMod(thousand);
    SetLength(groups, Length(groups) + 1);
    groups[High(groups)] := r.toInt32;
    m := q;
  end;
  if High(groups) > High(scales) then raise EConvertError.Create('toWords value exceeds the scale table (10^66)');
  result := '';
  for var i := High(groups) downto 0 do
    if groups[i] > 0 then begin
      if result <> '' then result := result + ' ';
      result := result + under1000(groups[i]) + scales[i];
    end;
  if fNeg then result := 'negative ' + result;
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

class function BigInt.randomPrime(bits: LongWord; rounds: integer): BigInt;
begin
  result := UBigInt.randomPrime(bits, rounds).toBigInt;
end;

class function BigInt.randomSecure(bits: LongWord): BigInt;
begin
  result := UBigInt.randomSecure(bits).toBigInt;
end;

class function BigInt.randomSecureBelow(const bound: BigInt): BigInt;
begin
  if bound.sign <= 0 then raise EBigIntError.Create('randomSecureBelow needs a positive bound');
  result := UBigInt.randomSecureBelow(bound.toUBigInt).toBigInt;
end;

class function BigInt.randomSecureRange(const lo, hi: BigInt): BigInt;
begin
  if lo > hi then raise EBigIntError.Create('randomSecureRange needs lo <= hi');
  result := lo + UBigInt.randomSecureBelow((hi - lo + 1).toUBigInt).toBigInt;
end;

class function BigInt.randomSecurePrime(bits: LongWord; rounds: integer): BigInt;
begin
  result := UBigInt.randomSecurePrime(bits, rounds).toBigInt;
end;

class function BigInt.crt(const remainders, moduli: array of BigInt): BigInt;
begin
  if Length(remainders) <> Length(moduli) then raise EBigIntError.Create('crt needs one remainder per modulus');
  if Length(moduli) = 0 then exit(default(BigInt));
  var m := moduli[0];
  if m.sign <= 0 then raise EBigIntError.Create('crt moduli must be positive');
  var x := remainders[0].floorMod(m);
  for var i := 1 to High(moduli) do begin
    if moduli[i].sign <= 0 then raise EBigIntError.Create('crt moduli must be positive');
    // solve x + m*k = r_i (mod m_i); non-coprime moduli fail in modInverse
    var k := ((remainders[i] - x) * m.modInverse(moduli[i])).floorMod(moduli[i]);
    x := x + m * k;
    m := m * moduli[i];
  end;
  result := x;
end;

class function BigInt.lucasSequence(const p, q, n, m: BigInt): (u, v: BigInt);
begin
  if m.sign <= 0 then raise EBigIntError.Create('modulus must be positive');
  if not m.isOdd then raise EBigIntError.Create('lucasSequence needs an odd modulus');
  if n.isNegative then raise EBigIntError.Create('lucasSequence needs a nonnegative index');
  if m.isOne then exit(BigInt.zero, BigInt.zero);
  var pm := p.floorMod(m);
  var qm := q.floorMod(m);
  var d := (p * p - 4 * q).floorMod(m);
  // (U_k, V_k, Q^k) from the top exponent bit down: square the index each
  // step, add one when the bit is set; halving mod odd m bumps odd values by m
  var u := BigInt.zero;
  var v := BigInt(2).floorMod(m);
  var qk := BigInt.one;
  for var i := Int64(n.bitLength) - 1 downto 0 do begin
    u := (u * v).floorMod(m);
    v := (v * v - 2 * qk).floorMod(m);
    qk := (qk * qk).floorMod(m);
    if n.testBit(LongWord(i)) then begin
      var t1 := (pm * u + v).floorMod(m);
      if t1.isOdd then t1 := t1 + m;
      var t2 := (d * u + pm * v).floorMod(m);
      if t2.isOdd then t2 := t2 + m;
      u := t1 shr 1;
      v := t2 shr 1;
      qk := (qk * qm).floorMod(m);
    end;
  end;
  exit(u, v);
end;

class function BigInt.factorial(n: LongWord): BigInt;
begin
  result := UBigInt.factorial(n).toBigInt;
end;

class function BigInt.fibonacci(n: LongWord): BigInt;
begin
  result := UBigInt.fibonacci(n).toBigInt;
end;

class function BigInt.lucas(n: LongWord): BigInt;
begin
  result := UBigInt.lucas(n).toBigInt;
end;

class function BigInt.binomial(n, k: LongWord): BigInt;
begin
  result := UBigInt.binomial(n, k).toBigInt;
end;

class function BigInt.binomialMod(const n, k, p: BigInt): BigInt;
begin
  if p.sign <= 0 then raise EBigIntError.Create('modulus must be positive');
  if n.isNegative or k.isNegative then raise EBigIntError.Create('binomialMod needs nonnegative n and k');
  result := UBigInt.binomialMod(n.toUBigInt, k.toUBigInt, p.toUBigInt).toBigInt;
end;

class function BigInt.catalan(n: LongWord): BigInt;
begin
  result := UBigInt.catalan(n).toBigInt;
end;

class function BigInt.primorial(n: LongWord): BigInt;
begin
  result := UBigInt.primorial(n).toBigInt;
end;

class function BigInt.multinomial(const ks: array of LongWord): BigInt;
begin
  result := UBigInt.multinomial(ks).toBigInt;
end;

class function BigInt.risingFactorial(const x: BigInt; n: LongWord): BigInt;
begin
  // signed base, so this cannot go through the unsigned version
  result := BigInt.one;
  for var i := 0 to Int64(n) - 1 do result := result * (x + i);
end;

class function BigInt.fallingFactorial(const x: BigInt; n: LongWord): BigInt;
begin
  result := BigInt.one;
  for var i := 0 to Int64(n) - 1 do result := result * (x - i);
end;

class function BigInt.subfactorial(n: LongWord): BigInt;
begin
  result := UBigInt.subfactorial(n).toBigInt;
end;

class function BigInt.bell(n: LongWord): BigInt;
begin
  result := UBigInt.bell(n).toBigInt;
end;

class function BigInt.stirling1(n, k: LongWord): BigInt;
var
  dp: array of BigInt;
begin
  if k > n then exit(BigInt.zero);
  if k = 0 then exit(if n = 0 then BigInt.one else BigInt.zero);
  // s(i, j) = s(i-1, j-1) - (i-1)*s(i-1, j), rolled over j descending
  SetLength(dp, k + 1);
  dp[0] := BigInt.one;
  for var i := 1 to n do begin
    var top := if i < k then i else k;
    for var j := top downto 1 do dp[j] := dp[j - 1] - Int64(i - 1) * dp[j];
    dp[0] := BigInt.zero;
  end;
  result := dp[k];
end;

class function BigInt.stirling2(n, k: LongWord): BigInt;
begin
  result := UBigInt.stirling2(n, k).toBigInt;
end;

class function BigInt.partitions(n: LongWord): BigInt;
begin
  result := UBigInt.partitions(n).toBigInt;
end;

class function BigInt.bernoulli(n: LongWord): (num, den: BigInt);
var
  bn, bd: array of BigInt;
begin
  // recurrence sum_{k=0}^{m} C(m+1,k) B_k = 0, with exact rational B_k
  SetLength(bn, n + 1);
  SetLength(bd, n + 1);
  bn[0] := BigInt.one;
  bd[0] := BigInt.one;
  for var m := 1 to Int64(n) do begin
    var sn := BigInt.zero;
    var sd := BigInt.one;
    for var k := 0 to m - 1 do begin
      if (k > 1) and (k and 1 = 1) then continue; // odd B_k above 1 vanish
      var tn := BigInt.binomial(LongWord(m + 1), LongWord(k)) * bn[k];
      // sn/sd + tn/bd[k]
      sn := sn * bd[k] + tn * sd;
      sd := sd * bd[k];
      var g := sn.gcd(sd);
      if not g.isZero then begin
        sn := sn div g;
        sd := sd div g;
      end;
    end;
    // B[m] = -(sn/sd)/(m+1)
    var rn := -sn;
    var rd := sd * BigInt(m + 1);
    if rd.isNegative then begin
      rn.negate;
      rd.negate;
    end;
    var g := rn.gcd(rd);
    if not g.isZero then begin
      rn := rn div g;
      rd := rd div g;
    end;
    bn[m] := rn;
    bd[m] := rd;
  end;
  exit(bn[n], bd[n]);
end;

class function BigInt.continuedFraction(const num, den: BigInt): array of BigInt;
var
  res: array of BigInt;
begin
  if den.isZero then RaiseDivByZero;
  var a := num;
  var b := den;
  while not b.isZero do begin
    SetLength(res, Length(res) + 1);
    res[High(res)] := a.floorDiv(b);
    var r := a.floorMod(b);
    a := b;
    b := r;
  end;
  result := res;
end;

class function BigInt.fromContinuedFraction(const cf: array of BigInt): (num, den: BigInt);
begin
  if Length(cf) = 0 then exit(BigInt.zero, BigInt.one);
  var num := cf[High(cf)];
  var den := BigInt.one;
  for var i := High(cf) - 1 downto 0 do begin
    var nn := cf[i] * num + den;
    den := num;
    num := nn;
  end;
  var g := num.gcd(den);
  if not g.isZero then begin
    num := num div g;
    den := den div g;
  end;
  if den.isNegative then begin
    num.negate;
    den.negate;
  end;
  exit(num, den);
end;

// ---------------------------------------------------------------------------
// BigDecimal
// ---------------------------------------------------------------------------

const
  // powers of ten up to the largest fitting a QWord
  POW10Q: array[0..19] of QWord = (1, 10, 100, 1000, 10000, 100000, 1000000,
    10000000, 100000000, 1000000000, 10000000000, 100000000000, 1000000000000,
    10000000000000, 100000000000000, 1000000000000000, 10000000000000000,
    100000000000000000, 1000000000000000000, 10000000000000000000);
  // largest power of ten in one limb, the chunk size for base-10 scaling
  {$if LIMB_BITS = 64}
  DEC_CHUNK = TLimb(10000000000000000000);
  DEC_CHUNK_POW = 19;
  {$else}
  DEC_CHUNK = TLimb(1000000000);
  DEC_CHUNK_POW = 9;
  {$endif}
  // stack budget (limbs) for the medium scale-and-add path in DecAddSub;
  // same byte budget on both limb widths
  DEC_MED_LIMBS = 6144 div LIMB_BITS;

procedure RaiseDecParseError(const s: string);
begin
  raise EConvertError.Create($'"{s}" is not a valid decimal value');
end;

procedure RaiseDecExpRange;
begin
  raise ERangeError.Create('BigDecimal exponent out of range');
end;

var
  // 10^(2^k) as limb magnitudes, grown on demand (single-threaded)
  Pow10Sq: array of TLimbs;

// cached 10^(2^k); grows the table by squaring the previous entry
function Pow10Bit(k: integer): TLimbs;
begin
  var old := Length(Pow10Sq);
  if k >= old then begin
    SetLength(Pow10Sq, k + 1);
    if old = 0 then begin
      Pow10Sq[0] := LFromQWord(10);
      old := 1;
    end;
    for var i := old to k do Pow10Sq[i] := LSqr(Pow10Sq[i - 1]);
  end;
  result := Pow10Sq[k];
end;

var
  // one-slot memo of the last composed 10^n; decimal alignment hits the same n
  // over and over (matching exponent gaps), so rebuilding it each call is waste
  Pow10MemoN: Int64 = -1;
  Pow10Memo: TLimbs;

function UPow10(n: LongWord): UBigInt;
begin
  if n <= 19 then begin
    result.fLimbs := LFromQWord(POW10Q[n]);
    exit;
  end;
  if Int64(n) = Pow10MemoN then begin
    result.fLimbs := Pow10Memo;
    exit;
  end;
  var n0 := n;
  // compose 10^n from cached 10^(2^k) for each set bit of n
  var acc: TLimbs := [1];
  var k := 0;
  while n > 0 do begin
    if n and 1 <> 0 then acc := LMul(acc, Pow10Bit(k));
    n := n shr 1;
    inc(k);
  end;
  Pow10MemoN := n0;
  Pow10Memo := acc;
  result.fLimbs := acc;
end;

// borrowed (ptr, len) view of 10^k with no refcount traffic; small k reads the
// POW10Q table in place (little-endian limb layout), larger k pins the memo
function Pow10ViewP(k: LongWord; out len: SizeInt): PLimb;
begin
  if k <= 19 then begin
    result := PLimb(@POW10Q[k]);
    {$if LIMB_BITS = 64}
    len := 1;
    {$else}
    len := if POW10Q[k] <= High(TLimb) then 1 else 2;
    {$endif}
    exit;
  end;
  if Int64(k) <> Pow10MemoN then UPow10(k);
  result := PLimb(Pointer(Pow10Memo));
  len := Length(Pow10Memo);
end;

var
  // 5^(2^i) squaring blocks, grown on demand; plus a one-slot memo of the last 5^k
  Pow5Blocks: array of TLimbs;
  Pow5MemoK: Int64 = -1;
  Pow5Memo: TLimbs;

function UPow5(k: LongWord): TLimbs; forward;

// borrowed (ptr, len) view of 5^k pinned in the memo, no refcount traffic
function Pow5ViewP(k: LongWord; out len: SizeInt): PLimb;
begin
  if Int64(k) <> Pow5MemoK then UPow5(k);
  result := PLimb(Pointer(Pow5Memo));
  len := Length(Pow5Memo);
end;

// 5^k built from cached 5^(2^i) blocks, memoized for repeated k
function UPow5(k: LongWord): TLimbs;
begin
  if Int64(k) = Pow5MemoK then exit(Pow5Memo);
  result := [1];
  var i := 0;
  var kk := k;
  while kk > 0 do begin
    if i > High(Pow5Blocks) then begin
      SetLength(Pow5Blocks, i + 1);
      Pow5Blocks[i] := if i = 0 then LFromQWord(5) else LSqr(Pow5Blocks[i - 1]);
    end;
    if kk and 1 <> 0 then result := LMul(result, Pow5Blocks[i]);
    kk := kk shr 1;
    inc(i);
  end;
  Pow5MemoK := k;
  Pow5Memo := result;
end;

// m div/mod 10^k using 10^k = 2^k*5^k: shift off the 2^k factor, divide by the
// smaller 5^k, then rebuild the true remainder mod 10^k. pow5 returns 5^k so the
// caller can form 10^k with one shift instead of a second power build. k >= 1.
procedure LDivPow10(const m: TLimbs; k: LongWord; out q, r, pow5: TLimbs);
begin
  pow5 := UPow5(k);
  var m1 := LShr(m, k);
  var r2: TLimbs;
  LDivMod(m1, pow5, q, r2);
  // remainder mod 10^k = (m1 mod 5^k)*2^k + (m mod 2^k)
  r := LAdd(LShl(r2, k), LSub(m, LShl(m1, k)));
end;

// multiply a (ptr, len) magnitude view by 10^k; k <= 0 hands back a copy
function LScale10P(p: PLimb; len: SizeInt; k: Int64): TLimbs;
begin
  if (k <= 0) or (len = 0) then exit(MakeLimbs(p, len));
  if k <= 2 * DEC_CHUNK_POW then begin
    var r: TLimbs;
    if k >= DEC_CHUNK_POW then begin
      r := LMulWP(p, len, DEC_CHUNK);
      k := k - DEC_CHUNK_POW;
      if k >= DEC_CHUNK_POW then begin
        r := LMulW(r, DEC_CHUNK);
        k := k - DEC_CHUNK_POW;
      end;
      if k > 0 then r := LMulW(r, TLimb(POW10Q[k]));
    end else r := LMulWP(p, len, TLimb(POW10Q[k]));
    result := r;
  end else if k <= 128 then begin
    var f := UPow10(LongWord(k)).fLimbs;
    result := LMulP(p, len, PLimb(Pointer(f)), Length(f));
  end else begin
    // large gap: 10^k = 5^k shl k; 5^k has ~30% fewer bits than 10^k, so both
    // building it and the multiply are cheaper and the binary shift is linear
    var f := UPow5(LongWord(k));
    result := LShl(LMulP(p, len, PLimb(Pointer(f)), Length(f)), LongWord(k));
  end;
end;

function LScale10(const a: TLimbs; k: Int64): TLimbs;
begin
  if (k <= 0) or (Length(a) = 0) then exit(a);
  result := LScale10P(PLimb(Pointer(a)), Length(a), k);
end;

// divisibility by 5: 2^LIMB_BITS mod 5 = 1, so m mod 5 = (limb sum + carry
// count) mod 5 - one wraparound pass, no per-limb division
function LDivisibleBy5P(p: PLimb; len: SizeInt): boolean;
begin
  var s: TLimb := 0;
  var cnt: TLimb := 0;
  for var i := 0 to len - 1 do begin
    s := s + p[i];
    cnt := cnt + TLimb(Ord(s < p[i]));
  end;
  result := (s mod 5 + cnt mod 5) mod 5 = 0;
end;

// strip trailing decimal zeros of a magnitude, bumping the exponent
procedure LStrip10(var m: TLimbs; var e: Int64);
begin
  var lm := Length(m);
  if (lm = 0) or (m[0] and 1 = 1) then exit;
  // cheap gate: an even mantissa still needs a factor of 5 to end in a zero
  if not LDivisibleBy5P(PLimb(Pointer(m)), lm) then exit;
  // a trailing decimal zero needs a factor of 2 and 5, so their count cannot
  // exceed the 2-adic valuation; the trailing binary zeros bound the work
  var t: Int64 := 0;
  var i := 0;
  while (i < lm) and (m[i] = 0) do begin
    inc(t, LIMB_BITS);
    inc(i);
  end;
  if i < lm then inc(t, LimbBsf(m[i]));
  while t > 0 do begin
    var w := if t < DEC_CHUNK_POW then integer(t) else DEC_CHUNK_POW;
    var r := LModW(m, TLimb(POW10Q[w]));
    var z: integer;
    if r = 0 then z := w
    else begin
      z := 0;
      while r mod 10 = 0 do begin
        r := r div 10;
        inc(z);
      end;
      if z = 0 then exit;
    end;
    var rem: TLimb;
    m := LDivModW(m, TLimb(POW10Q[z]), rem);
    e := e + z;
    if z < w then exit;
    t := t - z;
  end;
end;

// range-checked decimal exponent
function DecExp(e: Int64): integer;
begin
  if (e > High(integer)) or (e < Low(integer)) then RaiseDecExpRange;
  result := integer(e);
end;

// canonicalize a value whose mantissa is already in place: range-check the
// exponent and strip trailing decimal zeros unless a guard digit keeps them
procedure DecFinish(var d: BigDecimal; e: Int64; hidden: boolean);
begin
  d.fHidden := hidden and (d.fMan.fLen > 0);
  if d.fMan.fLen = 0 then begin
    d.fExp := 0;
    exit;
  end;
  // an odd mantissa cannot end in a decimal zero, so most results skip the
  // strip without touching more than the low limb; LStrip10 bounds its own
  // work by the 2-adic valuation for the rest
  if not d.fHidden and (d.fMan.dataPtr[0] and 1 = 0) then begin
    var e0 := e;
    var sm := d.fMan.fLimbs;
    LStrip10(sm, e);
    if e <> e0 then d.fMan.fLimbs := sm;
  end;
  d.fExp := DecExp(e);
end;

// assemble a value: canonical (no trailing zeros) unless it keeps a guard digit
function DecMake(const m: BigInt; e: Int64; hidden: boolean): BigDecimal;
begin
  result.fMan := m;
  DecFinish(result, e, hidden);
end;

// stored value as a canonical mantissa/exponent pair (guard digit kept,
// trailing zeros stripped)
procedure DecCanon(const a: BigDecimal; out m: TLimbs; out e: Int64);
begin
  m := a.fMan.fLimbs;
  e := a.fExp;
  if a.fHidden then LStrip10(m, e);
end;

// value as shown: the guard digit is dropped and rounds the magnitude up when
// it is 5 or more - this is what makes (1/3)*3 print as 1
procedure DecDisplay(const a: BigDecimal; out m: TLimbs; out e: Int64);
begin
  m := a.fMan.fLimbs;
  e := a.fExp;
  if a.fHidden then begin
    var r: TLimb;
    m := LDivModW(m, 10, r);
    e := e + 1;
    if r >= 5 then m := LAdd(m, LFromQWord(1));
  end;
  LStrip10(m, e);
end;

// bounds for the exponent of the leading decimal digit (1233/4096 < log10 2)
procedure DecMagBoundsP(p: PLimb; len: SizeInt; e: Int64; out lo, hi: Int64);
begin
  var bl := Int64(LBitLenP(p, len));
  lo := (bl - 1) * 1233 div 4096 + e;
  hi := bl * 1233 div 4096 + 1 + e;
end;

function DecCmp(const a, b: BigDecimal): integer;
begin
  var sa := a.fMan.sign;
  var sb := b.fMan.sign;
  if sa <> sb then exit(if sa < sb then -1 else 1);
  if sa = 0 then exit(0);
  // same scale: the mantissas compare directly, whatever their storage
  if a.fExp = b.fExp then begin
    var c := LCmpP(a.fMan.dataPtr, a.fMan.fLen, b.fMan.dataPtr, b.fMan.fLen);
    exit(if sa < 0 then -c else c);
  end;
  // disjoint leading-digit positions decide without aligning
  var loA, hiA, loB, hiB: Int64;
  DecMagBoundsP(a.fMan.dataPtr, a.fMan.fLen, a.fExp, loA, hiA);
  DecMagBoundsP(b.fMan.dataPtr, b.fMan.fLen, b.fExp, loB, hiB);
  var c: integer;
  if hiA < loB then c := -1
  else if hiB < loA then c := 1
  else begin
    var d := Int64(a.fExp) - b.fExp;
    if d > 0 then begin
      var t := LScale10P(a.fMan.dataPtr, a.fMan.fLen, d);
      c := LCmpP(PLimb(Pointer(t)), Length(t), b.fMan.dataPtr, b.fMan.fLen);
    end else begin
      var t := LScale10P(b.fMan.dataPtr, b.fMan.fLen, -d);
      c := -LCmpP(PLimb(Pointer(t)), Length(t), a.fMan.dataPtr, a.fMan.fLen);
    end;
  end;
  result := if sa < 0 then -c else c;
end;

function DecAddSub(const a, b: BigDecimal; negateB: boolean): BigDecimal;
begin
  if b.fMan.fLen = 0 then exit(a);
  if a.fMan.fLen = 0 then begin
    result := b;
    if negateB then result.fMan := -result.fMan;
    exit;
  end;
  // equal scale: no alignment multiply, add the mantissas as they are
  if a.fExp = b.fExp then begin
    // small mantissas: signed add straight into the result record
    if (a.fMan.fArr = nil) and (b.fMan.fArr = nil) then begin
      SAddInlineP(@a.fMan.fInline[0], a.fMan.fLen, a.fMan.fNeg, @b.fMan.fInline[0], b.fMan.fLen, b.fMan.fNeg xor negateB, @result.fMan.fInline[0], result.fMan.fArr, result.fMan.fLen, result.fMan.fNeg);
      DecFinish(result, Int64(a.fExp), a.fHidden or b.fHidden);
      exit;
    end;
    SAddP(a.fMan.dataPtr, a.fMan.fLen, a.fMan.fNeg, b.fMan.dataPtr, b.fMan.fLen, b.fMan.fNeg xor negateB, @result.fMan.fInline[0], result.fMan.fArr, result.fMan.fLen, result.fMan.fNeg);
    DecFinish(result, Int64(a.fExp), a.fHidden or b.fHidden);
    exit;
  end;
  // small mantissas over a modest gap: scale the higher-exponent one by a
  // single-limb power of ten on the stack, then add inline with no allocation
  if (a.fMan.fArr = nil) and (b.fMan.fArr = nil) then begin
    var d := Int64(a.fExp) - b.fExp;
    var k := if d > 0 then d else -d;
    if k <= DEC_CHUNK_POW then begin
      var hp: PLimb;
      var hlen: SizeInt;
      if d > 0 then begin
        hp := @a.fMan.fInline[0];
        hlen := a.fMan.fLen;
      end else begin
        hp := @b.fMan.fInline[0];
        hlen := b.fMan.fLen;
      end;
      var sb: array[0..BIGINT_INLINE_LIMBS] of TLimb;
      for var i := 0 to BIGINT_INLINE_LIMBS do sb[i] := 0;
      sb[hlen] := MpnMul1(@sb[0], hp, hlen, TLimb(POW10Q[k]));
      var slen: SizeInt := hlen + 1;
      while (slen > 0) and (sb[slen - 1] = 0) do dec(slen);
      if slen <= BIGINT_INLINE_LIMBS then begin
        var ee := if d > 0 then Int64(b.fExp) else Int64(a.fExp);
        if d > 0 then SAddInlineP(@sb[0], slen, a.fMan.fNeg, @b.fMan.fInline[0], b.fMan.fLen, b.fMan.fNeg xor negateB, @result.fMan.fInline[0], result.fMan.fArr, result.fMan.fLen, result.fMan.fNeg)
        else SAddInlineP(@a.fMan.fInline[0], a.fMan.fLen, a.fMan.fNeg, @sb[0], slen, b.fMan.fNeg xor negateB, @result.fMan.fInline[0], result.fMan.fArr, result.fMan.fLen, result.fMan.fNeg);
        DecFinish(result, ee, a.fHidden or b.fHidden);
        exit;
      end;
    end;
  end;
  // medium operands over a gap up to 128: scale the higher-exponent side into
  // a stack buffer with one schoolbook pass over the memoized power limbs, so
  // the only allocation left is the result itself
  var dm := Int64(a.fExp) - b.fExp;
  var km := if dm > 0 then dm else -dm;
  if km <= 4 * DEC_MED_LIMBS * DEC_CHUNK_POW div 5 then begin
    var hp, lp: PLimb;
    var hlen, llen: SizeInt;
    var hneg, lneg: boolean;
    if dm > 0 then begin
      hp := a.fMan.dataPtr; hlen := a.fMan.fLen; hneg := a.fMan.fNeg;
      lp := b.fMan.dataPtr; llen := b.fMan.fLen; lneg := b.fMan.fNeg xor negateB;
    end else begin
      hp := b.fMan.dataPtr; hlen := b.fMan.fLen; hneg := b.fMan.fNeg xor negateB;
      lp := a.fMan.dataPtr; llen := a.fMan.fLen; lneg := a.fMan.fNeg;
    end;
    var s: array[0..DEC_MED_LIMBS] of TLimb;
    var slen: SizeInt := -1;
    if km <= 64 then begin
      var f := Pow10ViewP(LongWord(km), var fl);
      if hlen + fl <= DEC_MED_LIMBS then begin
        // mul_1 first row then addmul_1 rows: every limb is written before read
        s[hlen] := MpnMul1(@s[0], hp, hlen, f[0]);
        for var j := 1 to fl - 1 do s[hlen + j] := MpnAddMul1(@s[j], hp, hlen, f[j]);
        slen := hlen + fl;
      end;
    end else begin
      // wide gap: multiply by the ~30% narrower 5^km, then shift the 2^km
      // factor in while placing the product into the add buffer
      var f := Pow5ViewP(LongWord(km), var fl);
      var ls := SizeInt(km shr LIMB_SHIFT);
      var tlen := hlen + fl;
      if ls + tlen + 1 <= DEC_MED_LIMBS then begin
        var t: array[0..DEC_MED_LIMBS - 1] of TLimb;
        t[hlen] := MpnMul1(@t[0], hp, hlen, f[0]);
        for var j := 1 to fl - 1 do t[hlen + j] := MpnAddMul1(@t[j], hp, hlen, f[j]);
        while (tlen > 0) and (t[tlen - 1] = 0) do dec(tlen);
        var bs := integer(km and LIMB_MASK);
        for var i := 0 to ls - 1 do s[i] := 0;
        if bs = 0 then begin
          for var i := 0 to tlen - 1 do s[ls + i] := t[i];
          slen := ls + tlen;
        end else begin
          s[ls + tlen] := MpnLshift(@s[ls], @t[0], tlen, bs);
          slen := ls + tlen + 1;
        end;
      end;
    end;
    if slen >= 0 then begin
      while (slen > 0) and (s[slen - 1] = 0) do dec(slen);
      if dm > 0 then SAddP(@s[0], slen, hneg, lp, llen, lneg, @result.fMan.fInline[0], result.fMan.fArr, result.fMan.fLen, result.fMan.fNeg)
      else SAddP(lp, llen, lneg, @s[0], slen, hneg, @result.fMan.fInline[0], result.fMan.fArr, result.fMan.fLen, result.fMan.fNeg);
      DecFinish(result, if dm > 0 then Int64(b.fExp) else Int64(a.fExp), a.fHidden or b.fHidden);
      exit;
    end;
  end;

  // align to the smaller exponent: only the higher-exponent side is scaled,
  // the other one is read in place
  var d2 := Int64(a.fExp) - b.fExp;
  var sm: TLimbs;
  if d2 > 0 then begin
    sm := LScale10P(a.fMan.dataPtr, a.fMan.fLen, d2);
    SAddP(PLimb(Pointer(sm)), Length(sm), a.fMan.fNeg, b.fMan.dataPtr, b.fMan.fLen, b.fMan.fNeg xor negateB, @result.fMan.fInline[0], result.fMan.fArr, result.fMan.fLen, result.fMan.fNeg);
    DecFinish(result, Int64(b.fExp), a.fHidden or b.fHidden);
  end else begin
    sm := LScale10P(b.fMan.dataPtr, b.fMan.fLen, -d2);
    SAddP(a.fMan.dataPtr, a.fMan.fLen, a.fMan.fNeg, PLimb(Pointer(sm)), Length(sm), b.fMan.fNeg xor negateB, @result.fMan.fInline[0], result.fMan.fArr, result.fMan.fLen, result.fMan.fNeg);
    DecFinish(result, Int64(a.fExp), a.fHidden or b.fHidden);
  end;
end;

class operator BigDecimal.:=(x: Int64): BigDecimal;
begin
  result := DecMake(BFromI64(x), 0, false);
end;

class operator BigDecimal.:=(x: QWord): BigDecimal;
begin
  var m: BigInt;
  m.fLimbs := LFromQWord(x);
  m.fNeg := false;
  result := DecMake(m, 0, false);
end;

class operator BigDecimal.:=(const s: string): BigDecimal;
begin
  if not tryParse(s, result) then RaiseDecParseError(s);
end;

class operator BigDecimal.:=(const a: BigInt): BigDecimal;
begin
  result := DecMake(a, 0, false);
end;

class operator BigDecimal.:=(const a: UBigInt): BigDecimal;
begin
  var m: BigInt;
  m.fLimbs := a.fLimbs;
  m.fNeg := false;
  result := DecMake(m, 0, false);
end;

class operator BigDecimal.explicit(d: Double): BigDecimal;
begin
  result := fromDouble(d);
end;

class operator BigDecimal.explicit(s: Single): BigDecimal;
begin
  result := fromSingle(s);
end;

class operator BigDecimal.explicit(x: Int64): BigDecimal;
begin
  result := DecMake(BFromI64(x), 0, false);
end;

class operator BigDecimal.explicit(x: QWord): BigDecimal;
begin
  var m: BigInt;
  m.fLimbs := LFromQWord(x);
  m.fNeg := false;
  result := DecMake(m, 0, false);
end;

class operator BigDecimal.explicit(const a: BigDecimal): Double;
begin
  result := a.toDouble;
end;

class operator BigDecimal.explicit(const a: BigDecimal): Single;
begin
  result := a.toSingle;
end;

class operator BigDecimal.explicit(const a: BigDecimal): string;
begin
  result := a.toString;
end;

class operator BigDecimal.explicit(const a: BigDecimal): BigInt;
begin
  result := a.toBigInt;
end;

class operator BigDecimal.+(const a, b: BigDecimal): BigDecimal;
begin
  result := DecAddSub(a, b, false);
end;

class operator BigDecimal.-(const a, b: BigDecimal): BigDecimal;
begin
  result := DecAddSub(a, b, true);
end;

class operator BigDecimal.*(const a, b: BigDecimal): BigDecimal;
begin
  // small mantissas: multiply straight into the result record
  if (a.fMan.fArr = nil) and (b.fMan.fArr = nil) then begin
    MulInline(@a.fMan.fInline[0], a.fMan.fLen, @b.fMan.fInline[0], b.fMan.fLen, @result.fMan.fInline[0], result.fMan.fArr, result.fMan.fLen);
    result.fMan.fNeg := (a.fMan.fNeg xor b.fMan.fNeg) and (result.fMan.fLen > 0);
    DecFinish(result, Int64(a.fExp) + b.fExp, a.fHidden or b.fHidden);
    exit;
  end;
  SMulP(a.fMan.dataPtr, a.fMan.fLen, a.fMan.fNeg, b.fMan.dataPtr, b.fMan.fLen, b.fMan.fNeg, @result.fMan.fInline[0], result.fMan.fArr, result.fMan.fLen, result.fMan.fNeg);
  DecFinish(result, Int64(a.fExp) + b.fExp, a.fHidden or b.fHidden);
end;

class operator BigDecimal./(const a, b: BigDecimal): BigDecimal;
begin
  result := a.divide(b);
end;

class operator BigDecimal.div(const a, b: BigDecimal): BigDecimal;
begin
  var (q, r) := a.divMod(b);
  result := q;
end;

class operator BigDecimal.mod(const a, b: BigDecimal): BigDecimal;
begin
  var (q, r) := a.divMod(b);
  result := r;
end;

class operator BigDecimal.**(const a: BigDecimal; e: Int64): BigDecimal;
begin
  result := a.pow(e);
end;

class operator BigDecimal.inc(const a: BigDecimal): BigDecimal;
begin
  result := DecAddSub(a, BigDecimal.one, false);
end;

class operator BigDecimal.dec(const a: BigDecimal): BigDecimal;
begin
  result := DecAddSub(a, BigDecimal.one, true);
end;

class operator BigDecimal.-(const a: BigDecimal): BigDecimal;
begin
  result := a;
  result.fMan := -result.fMan;
end;

class operator BigDecimal.+(const a: BigDecimal): BigDecimal;
begin
  result := a;
end;

class operator BigDecimal.=(const a, b: BigDecimal): boolean;
begin
  result := DecCmp(a, b) = 0;
end;

class operator BigDecimal.<>(const a, b: BigDecimal): boolean;
begin
  result := DecCmp(a, b) <> 0;
end;

class operator BigDecimal.<(const a, b: BigDecimal): boolean;
begin
  result := DecCmp(a, b) < 0;
end;

class operator BigDecimal.<=(const a, b: BigDecimal): boolean;
begin
  result := DecCmp(a, b) <= 0;
end;

class operator BigDecimal.>(const a, b: BigDecimal): boolean;
begin
  result := DecCmp(a, b) > 0;
end;

class operator BigDecimal.>=(const a, b: BigDecimal): boolean;
begin
  result := DecCmp(a, b) >= 0;
end;

// fast decimal render of a single-limb magnitude, no leading zeros
function QWordToDecimal(q: QWord): string;
begin
  if q = 0 then exit('0');
  var buf: array[0..19] of AnsiChar;
  var p := 20;
  while q > 0 do begin
    dec(p);
    buf[p] := AnsiChar(Ord('0') + q mod 10);
    q := q div 10;
  end;
  SetString(result, PAnsiChar(@buf[p]), 20 - p);
end;

function BigDecimal.toString: string;
var
  m: TLimbs;
  e: Int64;
begin
  DecDisplay(self, m, e);
  if Length(m) = 0 then exit('0');
  var digits := if Length(m) = 1 then QWordToDecimal(m[0]) else LToBase(m, 10);
  var l := Length(digits);
  if e >= 0 then result := digits + StringOfChar('0', e)
  else begin
    var f := -e;
    if l > f then result := Copy(digits, 1, l - f) + '.' + Copy(digits, l - f + 1, f)
    else result := '0.' + StringOfChar('0', f - l) + digits;
  end;
  if fMan.fNeg then result := '-' + result;
end;

function BigDecimal.toScientific: string;
var
  m: TLimbs;
  e: Int64;
begin
  DecDisplay(self, m, e);
  if Length(m) = 0 then exit('0');
  var digits := if Length(m) = 1 then QWordToDecimal(m[0]) else LToBase(m, 10);
  var l := Length(digits);
  var rest := if l > 1 then Copy(digits, 2, l - 1) else '0';
  result := digits[1] + '.' + rest + 'E' + IntToStr(e + l - 1);
  if fMan.fNeg then result := '-' + result;
end;

function BigDecimal.toInt8: Int8;
begin
  result := toBigInt.toInt8;
end;

function BigDecimal.toUInt8: UInt8;
begin
  result := toBigInt.toUInt8;
end;

function BigDecimal.toInt16: Int16;
begin
  result := toBigInt.toInt16;
end;

function BigDecimal.toUInt16: UInt16;
begin
  result := toBigInt.toUInt16;
end;

function BigDecimal.toInt32: Int32;
begin
  result := toBigInt.toInt32;
end;

function BigDecimal.toUInt32: UInt32;
begin
  result := toBigInt.toUInt32;
end;

function BigDecimal.toInt64: Int64;
begin
  result := toBigInt.toInt64;
end;

function BigDecimal.toUInt64: UInt64;
begin
  result := toBigInt.toUInt64;
end;

{$ifdef BIGINT_HAS_INT128}
function BigDecimal.toInt128: Int128;
begin
  result := toBigInt.toInt128;
end;

function BigDecimal.toUInt128: UInt128;
begin
  result := toBigInt.toUInt128;
end;
{$endif}

function BigDecimal.toBigInt: BigInt;
begin
  if not isIntegral then raise ERangeError.Create('BigDecimal value is not integral');
  result := trunc;
end;

function BigDecimal.toUBigInt: UBigInt;
begin
  result := toBigInt.toUBigInt;
end;

function BigDecimal.fitsInInt8: boolean;
begin
  result := isIntegral and trunc.fitsInInt8;
end;

function BigDecimal.fitsInUInt8: boolean;
begin
  result := isIntegral and trunc.fitsInUInt8;
end;

function BigDecimal.fitsInInt16: boolean;
begin
  result := isIntegral and trunc.fitsInInt16;
end;

function BigDecimal.fitsInUInt16: boolean;
begin
  result := isIntegral and trunc.fitsInUInt16;
end;

function BigDecimal.fitsInInt32: boolean;
begin
  result := isIntegral and trunc.fitsInInt32;
end;

function BigDecimal.fitsInUInt32: boolean;
begin
  result := isIntegral and trunc.fitsInUInt32;
end;

function BigDecimal.fitsInInt64: boolean;
begin
  result := isIntegral and trunc.fitsInInt64;
end;

function BigDecimal.fitsInUInt64: boolean;
begin
  result := isIntegral and trunc.fitsInUInt64;
end;

{$ifdef BIGINT_HAS_INT128}
function BigDecimal.fitsInInt128: boolean;
begin
  result := isIntegral and trunc.fitsInInt128;
end;

function BigDecimal.fitsInUInt128: boolean;
begin
  result := isIntegral and trunc.fitsInUInt128;
end;
{$endif}

function BigDecimal.isZero: boolean;
begin
  result := fMan.fLen = 0;
end;

function BigDecimal.isOne: boolean;
begin
  if fMan.fNeg then exit(false);
  DecCanon(self, var m, var e);
  result := (e = 0) and (Length(m) = 1) and (m[0] = 1);
end;

function BigDecimal.isIntegral: boolean;
begin
  if fExp >= 0 then exit(true);
  DecCanon(self, var m, var e);
  result := (Length(m) = 0) or (e >= 0);
end;

function BigDecimal.isEven: boolean;
begin
  DecCanon(self, var m, var e);
  if e > 0 then exit(true);
  if e < 0 then exit(false);
  result := (Length(m) = 0) or (m[0] and 1 = 0);
end;

function BigDecimal.isOdd: boolean;
begin
  DecCanon(self, var m, var e);
  result := (e = 0) and (Length(m) > 0) and (m[0] and 1 = 1);
end;

function BigDecimal.isNegative: boolean;
begin
  result := fMan.isNegative;
end;

function BigDecimal.isPositive: boolean;
begin
  result := fMan.isPositive;
end;

function BigDecimal.sign: integer;
begin
  result := fMan.sign;
end;

function BigDecimal.abs: BigDecimal;
begin
  result := self;
  result.fMan := result.fMan.abs;
end;

procedure BigDecimal.negate;
begin
  fMan.negate;
end;

function BigDecimal.trunc: BigInt;
begin
  if fExp >= 0 then begin
    result.fLimbs := LScale10(fMan.fLimbs, fExp);
    result.fNeg := fMan.fNeg;
  end else begin
    LDivPow10(fMan.fLimbs, LongWord(-Int64(fExp)), var q, _, _);
    result.fLimbs := q;
    result.fNeg := fMan.fNeg and (Length(q) > 0);
  end;
end;

function BigDecimal.floor: BigInt;
begin
  result := trunc;
  if fMan.fNeg and not isIntegral then result := result - 1;
end;

function BigDecimal.ceil: BigInt;
begin
  result := trunc;
  if not fMan.fNeg and not isIntegral then result := result + 1;
end;

function BigDecimal.round: BigInt;
begin
  result := rounded(0, bdrHalfEven).trunc;
end;

function BigDecimal.frac: BigDecimal;
begin
  if fExp >= 0 then exit(default(BigDecimal));
  LDivPow10(fMan.fLimbs, LongWord(-Int64(fExp)), _, var r, _);
  var m: BigInt;
  m.fLimbs := r;
  m.fNeg := fMan.fNeg and (Length(r) > 0);
  result := DecMake(m, fExp, false);
end;

function BigDecimal.precision: integer;
begin
  DecCanon(self, var m, var e);
  if Length(m) = 0 then exit(0);
  result := integer(Length(LToBase(m, 10)));
end;

function BigDecimal.mostSignificantExponent: integer;
begin
  DecCanon(self, var m, var e);
  if Length(m) = 0 then exit(0);
  result := DecExp(e + Length(LToBase(m, 10)) - 1);
end;

function BigDecimal.getDigit(i: integer): integer;
begin
  var pos := Int64(i) - fExp;
  if (pos < 0) or fMan.isZero then exit(0);
  // cheap digit-count bound skips the division for positions above the top
  if pos > Int64(LBitLen(fMan.fLimbs)) * 1233 div 4096 + 1 then exit(0);
  var q, r: TLimbs;
  if pos = 0 then q := fMan.fLimbs
  else LDivMod(fMan.fLimbs, UPow10(LongWord(pos)).fLimbs, q, r);
  result := integer(LModW(q, 10));
end;

procedure BigDecimal.shift10(n: integer);
begin
  if not fMan.isZero then fExp := DecExp(Int64(fExp) + n);
end;

function BigDecimal.shifted10(n: integer): BigDecimal;
begin
  result := self;
  result.shift10(n);
end;

function BigDecimal.rounded(toDigit: integer; mode: TBigDecimalRounding): BigDecimal;
begin
  if fMan.isZero then exit(default(BigDecimal));
  if fExp >= toDigit then exit(self);
  var delta := Int64(toDigit) - fExp;
  var neg := fMan.fNeg;
  var dcMax := Int64(LBitLen(fMan.fLimbs)) * 1233 div 4096 + 1;
  var qm, rm, p10: TLimbs;
  if delta > dcMax then begin
    // every digit is dropped: quotient 0, remainder is the whole mantissa,
    // and the remainder is always far below half of 10^delta
    qm := nil;
    rm := fMan.fLimbs;
  end else begin
    LDivPow10(fMan.fLimbs, LongWord(delta), qm, rm, var p5);
    p10 := LShl(p5, LongWord(delta));
  end;
  var up := false;
  if Length(rm) > 0 then begin
    if mode = bdrCeil then up := not neg
    else if mode = bdrFloor then up := neg
    else if mode <> bdrTrunc then begin
      // half modes compare twice the remainder against 10^delta
      var c := if delta > dcMax then -1 else LCmp(LShl(rm, 1), p10);
      if c > 0 then up := true
      else if c = 0 then begin
        if mode = bdrRound then up := true
        else if mode = bdrHalfUp then up := not neg
        else up := (Length(qm) > 0) and (qm[0] and 1 = 1);
      end;
    end;
  end;
  var m: BigInt;
  m.fLimbs := if up then LAdd(qm, LFromQWord(1)) else qm;
  m.fNeg := neg and (m.fLen > 0);
  result := DecMake(m, toDigit, false);
end;

function BigDecimal.compare(const other: BigDecimal): integer;
begin
  result := DecCmp(self, other);
end;

function BigDecimal.equals(const other: BigDecimal): boolean;
begin
  result := DecCmp(self, other) = 0;
end;

function BigDecimal.min(const other: BigDecimal): BigDecimal;
begin
  result := if DecCmp(self, other) <= 0 then self else other;
end;

function BigDecimal.max(const other: BigDecimal): BigDecimal;
begin
  result := if DecCmp(self, other) >= 0 then self else other;
end;

function BigDecimal.divide(const other: BigDecimal; precision: integer): BigDecimal;
begin
  if other.fMan.isZero then RaiseDivByZero;
  if fMan.isZero then exit(default(BigDecimal));
  if precision < 0 then precision := 0;
  // guard position: below the requested fractional digits, both operands'
  // last digits, and `precision` significant digits of a small quotient
  var ms := (Int64(LBitLenP(fMan.dataPtr, fMan.fLen)) - LBitLenP(other.fMan.dataPtr, other.fMan.fLen) - 1) * 1233;
  ms := (if ms >= 0 then ms div 4096 else -((-ms + 4095) div 4096)) + fExp - other.fExp;
  var er := -Int64(precision);
  if fExp < er then er := fExp;
  if other.fExp < er then er := other.fExp;
  if ms - precision + 1 < er then er := ms - precision + 1;
  er := er - 1;
  var t := Int64(fExp) - other.fExp - er;
  var s: TLimbs;
  var q, r: TLimbs;
  if t > 0 then begin
    s := LScale10P(fMan.dataPtr, fMan.fLen, t);
    LDivModP(PLimb(Pointer(s)), Length(s), other.fMan.dataPtr, other.fMan.fLen, q, r);
  end else if t < 0 then begin
    s := LScale10P(other.fMan.dataPtr, other.fMan.fLen, -t);
    LDivModP(fMan.dataPtr, fMan.fLen, PLimb(Pointer(s)), Length(s), q, r);
  end else LDivModP(fMan.dataPtr, fMan.fLen, other.fMan.dataPtr, other.fMan.fLen, q, r);
  result.fMan.fNeg := (fMan.fNeg xor other.fMan.fNeg) and (Length(q) > 0);
  MoveArr(q, @result.fMan.fInline[0], result.fMan.fArr, result.fMan.fLen);
  DecFinish(result, er, Length(r) > 0);
end;

function BigDecimal.divMod(const d: BigDecimal): (q, r: BigDecimal);
var
  qq, rr: BigDecimal;
begin
  if d.fMan.isZero then RaiseDivByZero;
  var t := Int64(fExp) - d.fExp;
  var n, dm: TLimbs;
  if t >= 0 then begin
    n := LScale10(fMan.fLimbs, t);
    dm := d.fMan.fLimbs;
  end else begin
    n := fMan.fLimbs;
    dm := LScale10(d.fMan.fLimbs, -t);
  end;
  var qm, rm: TLimbs;
  LDivMod(n, dm, qm, rm);
  var bq, br: BigInt;
  bq.fLimbs := qm;
  bq.fNeg := (fMan.fNeg xor d.fMan.fNeg) and (Length(qm) > 0);
  br.fLimbs := rm;
  br.fNeg := fMan.fNeg and (Length(rm) > 0);
  qq := DecMake(bq, 0, false);
  rr := DecMake(br, if t >= 0 then Int64(d.fExp) else Int64(fExp), false);
  exit(qq, rr);
end;

class function BigDecimal.parse(const s: string): BigDecimal;
begin
  if not tryParse(s, result) then RaiseDecParseError(s);
end;

class function BigDecimal.tryParse(const s: string; out v: BigDecimal): boolean;
begin
  v := default(BigDecimal);
  result := false;
  var i: SizeInt := 1;
  var len := Length(s);
  while (i <= len) and (s[i] in [' ', #9]) do inc(i);
  while (len >= i) and (s[len] in [' ', #9]) do dec(len);
  if i > len then exit;
  var neg := false;
  if s[i] in ['+', '-'] then begin
    neg := s[i] = '-';
    inc(i);
  end;
  var digits: TBytes;
  SetLength(digits, len - i + 1);
  var count: SizeInt := 0;
  var acc: QWord := 0;
  var fracDigits: Int64 := 0;
  var seenDot := false;
  while i <= len do begin
    var c: char := s[i];
    if c = '_' then begin
      inc(i);
      continue;
    end;
    if (c = '.') and not seenDot then begin
      seenDot := true;
      inc(i);
      continue;
    end;
    if not (c in ['0'..'9']) then break;
    digits[count] := byte(Ord(c) - Ord('0'));
    if count < 18 then acc := acc * 10 + digits[count];
    inc(count);
    if seenDot then inc(fracDigits);
    inc(i);
  end;
  if count = 0 then exit;
  var expPart: Int64 := 0;
  if (i <= len) and (s[i] in ['e', 'E']) then begin
    inc(i);
    var eneg := false;
    if (i <= len) and (s[i] in ['+', '-']) then begin
      eneg := s[i] = '-';
      inc(i);
    end;
    var any := false;
    while (i <= len) and ((s[i] = '_') or (s[i] in ['0'..'9'])) do begin
      if s[i] <> '_' then begin
        any := true;
        // clamp far past the exponent range, the final check rejects it
        if expPart < 1000000000000 then expPart := expPart * 10 + (Ord(s[i]) - Ord('0'));
      end;
      inc(i);
    end;
    if not any then exit;
    if eneg then expPart := -expPart;
  end;
  if i <= len then exit;
  var m: BigInt;
  // money-sized mantissas (<= 18 digits) fit one 64-bit word: build directly,
  // skipping the TBytes chunked parse
  if count <= 18 then m.fLimbs := LFromQWord(acc)
  else begin
    SetLength(digits, count);
    m.fLimbs := LFromDigits(digits, 10);
  end;
  m.fNeg := neg and (m.fLen > 0);
  var e := expPart - fracDigits;
  var sm := m.fLimbs;
  LStrip10(sm, e);
  m.fLimbs := sm;
  if m.fLen = 0 then e := 0;
  if (e > High(integer)) or (e < Low(integer)) then exit;
  v.fMan := m;
  v.fExp := integer(e);
  result := true;
end;

function BigDecimal.sqrt(precision: integer): BigDecimal;
begin
  if fMan.fNeg then raise EBigIntError.Create('square root of a negative value');
  if fMan.isZero then exit(default(BigDecimal));
  if precision < 0 then precision := 0;
  // scale to an integer carrying 2*(precision+1) fractional digits and take
  // the integer root: the extra digit is a truncated guard, hidden like
  // divide's, so toString shows `precision` rounded digits
  var p1 := Int64(precision) + 1;
  var k := Int64(fExp) + 2 * p1;
  var n: UBigInt;
  var exact := true;
  if k >= 0 then n.fLimbs := LScale10(fMan.fLimbs, k)
  else begin
    var q, r: TLimbs;
    LDivMod(fMan.fLimbs, UPow10(LongWord(-k)).fLimbs, q, r);
    n.fLimbs := q;
    exact := Length(r) = 0;
  end;
  var (root, rem) := n.sqrtRem;
  var m: BigInt;
  m.fLimbs := root.fLimbs;
  m.fNeg := false;
  result := DecMake(m, -p1, not (exact and rem.isZero));
end;

function BigDecimal.pow(e: Int64): BigDecimal;
begin
  if e = 0 then exit(BigDecimal.one);
  if fMan.isZero then begin
    if e < 0 then RaiseDivByZero;
    exit(default(BigDecimal));
  end;
  var mag: QWord := if e > 0 then QWord(e) else NegAbs64(e);
  var m: BigInt;
  m.fLimbs := UPowQ(fMan.fLimbs, mag);
  m.fNeg := fMan.fNeg and (mag and 1 = 1);
  var pe: Int64 := 0;
  if fExp <> 0 then begin
    var ae: QWord := if fExp < 0 then QWord(-Int64(fExp)) else QWord(fExp);
    if mag > QWord(High(Int64)) div ae then RaiseDecExpRange;
    pe := Int64(fExp) * Int64(mag);
  end;
  result := DecMake(m, pe, fHidden);
  if e < 0 then result := BigDecimal.one.divide(result);
end;

function BigDecimal.gcd(const other: BigDecimal): BigDecimal;
begin
  if fMan.isZero then exit(other.abs);
  if other.fMan.isZero then exit(abs);
  // align to the common scale and reduce the integer pair
  var e := if Int64(fExp) < other.fExp then Int64(fExp) else Int64(other.fExp);
  var ua, ub: UBigInt;
  ua.fLimbs := LScale10(fMan.fLimbs, Int64(fExp) - e);
  ub.fLimbs := LScale10(other.fMan.fLimbs, Int64(other.fExp) - e);
  var m: BigInt;
  m.fLimbs := ua.gcd(ub).fLimbs;
  m.fNeg := false;
  result := DecMake(m, e, false);
end;

function BigDecimal.lcm(const other: BigDecimal): BigDecimal;
begin
  if fMan.isZero or other.fMan.isZero then exit(default(BigDecimal));
  var e := if Int64(fExp) < other.fExp then Int64(fExp) else Int64(other.fExp);
  var am := LScale10(fMan.fLimbs, Int64(fExp) - e);
  var bm := LScale10(other.fMan.fLimbs, Int64(other.fExp) - e);
  var ua, ub: UBigInt;
  ua.fLimbs := am;
  ub.fLimbs := bm;
  var q, r: TLimbs;
  LDivMod(am, ua.gcd(ub).fLimbs, q, r);
  var m: BigInt;
  m.fLimbs := LMul(q, bm);
  m.fNeg := false;
  result := DecMake(m, e, false);
end;

// float bit split: value = (-1)^neg * m * 2^e2, raises on NaN and infinity
procedure SplitDouble(d: Double; out neg: boolean; out m: QWord; out e2: integer);
begin
  var bits: QWord;
  Move(d, bits, 8);
  neg := bits shr 63 = 1;
  var be := integer((bits shr 52) and $7FF);
  m := bits and ((QWord(1) shl 52) - 1);
  if be = $7FF then raise EConvertError.Create('cannot convert NaN or infinity to BigDecimal');
  if be = 0 then e2 := -1074
  else begin
    m := m or (QWord(1) shl 52);
    e2 := be - 1075;
  end;
end;

procedure SplitSingle(s: Single; out neg: boolean; out m: QWord; out e2: integer);
begin
  var bits: DWord;
  Move(s, bits, 4);
  neg := bits shr 31 = 1;
  var be := integer((bits shr 23) and $FF);
  m := bits and ((1 shl 23) - 1);
  if be = $FF then raise EConvertError.Create('cannot convert NaN or infinity to BigDecimal');
  if be = 0 then e2 := -149
  else begin
    m := m or (1 shl 23);
    e2 := be - 150;
  end;
end;

{$ifdef FPC_HAS_TYPE_EXTENDED}
procedure SplitExtended(x: Extended; out neg: boolean; out m: QWord; out e2: integer);
begin
  // 80-bit layout: 64-bit mantissa with an explicit integer bit + 15-bit exponent
  var hi: Word;
  Move(x, m, 8);
  Move(PByte(@x)[8], hi, 2);
  neg := hi shr 15 = 1;
  var be := integer(hi and $7FFF);
  if be = $7FFF then raise EConvertError.Create('cannot convert NaN or infinity to BigDecimal');
  if be = 0 then e2 := -16445
  else e2 := be - 16446;
end;
{$endif}

// exact decimal expansion of m * 2^e2 (m * 5^-e2 * 10^e2 for negative e2)
function DecFromFloatExact(neg: boolean; m: QWord; e2: integer): BigDecimal;
begin
  if m = 0 then exit(default(BigDecimal));
  var b: BigInt;
  var e10: Int64 := 0;
  if e2 >= 0 then b.fLimbs := LShl(LFromQWord(m), LongWord(e2))
  else begin
    b.fLimbs := LMul(LFromQWord(m), UPowQ(LFromQWord(5), LongWord(-e2)));
    e10 := e2;
  end;
  b.fNeg := neg;
  result := DecMake(b, e10, false);
end;

// shortest decimal digits that read back to exactly m * 2^e2 under round to
// nearest, ties to even: value = 0.d1..dn * 10^k. The classic long-division
// loop over exact integers with the half-gap boundaries (Steele & White)
function ShortestDigits(m: QWord; e2: integer; lowHalf: boolean; out k: Int64): TBytes;
begin
  var even := m and 1 = 0;
  var r, s, mp: UBigInt;
  if e2 >= 0 then begin
    mp := UBigInt.pow2(LongWord(e2));
    r := UBigInt(m) * mp * 2;
    s := 2;
  end else begin
    r := UBigInt(m) * 2;
    s := UBigInt.pow2(LongWord(1 - e2));
    mp := 1;
  end;
  var mm := mp;
  if lowHalf then begin
    // the gap below a power-of-two mantissa is half the gap above it
    r := r * 2;
    s := s * 2;
    mp := mp * 2;
  end;
  // scale so the value sits in [1/10, 1): digits then come out one per step
  // (an even mantissa owns its boundaries, so ties count as inside)
  var hiIncl := if even then 0 else 1;
  k := 0;
  while (r + mp).compare(s) >= hiIncl do begin
    s := s * 10;
    inc(k);
  end;
  while ((r + mp) * 10).compare(s) < hiIncl do begin
    r := r * 10;
    mp := mp * 10;
    mm := mm * 10;
    dec(k);
  end;
  var digs: TBytes;
  SetLength(digs, 24);
  var count: SizeInt := 0;
  repeat
    r := r * 10;
    mp := mp * 10;
    mm := mm * 10;
    var (d, rr) := r.divMod(s);
    r := rr;
    var dv := byte(d.toUInt64);
    var low := if even then r.compare(mm) <= 0 else r.compare(mm) < 0;
    var high := if even then (r + mp).compare(s) >= 0 else (r + mp).compare(s) > 0;
    if count = Length(digs) then SetLength(digs, count * 2);
    if low or high then begin
      // terminal digit: pick the closer side, ties round up
      if (high and not low) or (high and low and ((r * 2).compare(s) >= 0)) then inc(dv);
      digs[count] := dv;
      inc(count);
      break;
    end;
    digs[count] := dv;
    inc(count);
  until false;
  // a rounded-up 10 carries into the digits above
  var i := count - 1;
  while (i >= 0) and (digs[i] = 10) do begin
    digs[i] := 0;
    dec(i);
    if i >= 0 then inc(digs[i]);
  end;
  if i < 0 then begin
    // all nines rolled over: a single 1, one power of ten higher
    digs[0] := 1;
    count := 1;
    inc(k);
  end;
  while (count > 1) and (digs[count - 1] = 0) do dec(count);
  var start: SizeInt := 0;
  while (start < count - 1) and (digs[start] = 0) do begin
    inc(start);
    dec(k);
  end;
  result := Copy(digs, start, count - start);
end;

function DecFromShortest(neg: boolean; m: QWord; e2: integer; lowHalf: boolean): BigDecimal;
begin
  if m = 0 then exit(default(BigDecimal));
  var k: Int64;
  var digs := ShortestDigits(m, e2, lowHalf, k);
  var b: BigInt;
  b.fLimbs := LFromDigits(digs, 10);
  b.fNeg := neg;
  result := DecMake(b, k - Length(digs), false);
end;

// correctly rounded binary conversion: p mantissa bits, [emin, emax] the
// exponent range; ties to even, overflow gives infinity, underflow zero
function DecToFloat(const a: BigDecimal; p, emin, emax: integer): Extended;
begin
  if a.fMan.fLen = 0 then exit(0.0);
  var sgn: Extended := if a.fMan.fNeg then -1.0 else 1.0;
  var lo, hi: Int64;
  DecMagBoundsP(a.fMan.dataPtr, a.fMan.fLen, a.fExp, lo, hi);
  // decimal guards keep absurd exponents from materializing huge powers
  if lo > 4940 then exit(sgn * FltPosInf);
  if hi < -4970 then exit(sgn * 0.0);
  var n, dm: TLimbs;
  if a.fExp >= 0 then begin
    n := LScale10(a.fMan.fLimbs, a.fExp);
    dm := LFromQWord(1);
  end else begin
    n := a.fMan.fLimbs;
    dm := UPow10(LongWord(-Int64(a.fExp))).fLimbs;
  end;
  // scale so the quotient carries p+1..p+3 bits, then round with the remainder
  var s := Int64(p) + 2 - (Int64(LBitLen(n)) - Int64(LBitLen(dm)));
  if s >= 0 then n := LShl(n, LongWord(s))
  else dm := LShl(dm, LongWord(-s));
  var q, r: TLimbs;
  LDivMod(n, dm, q, r);
  var qb := Int64(LBitLen(q));
  var vexp := qb - 1 - s;
  if vexp < Int64(emin) - p then exit(sgn * 0.0);
  // subnormals keep fewer bits: positions vexp down to emin - p + 1
  var targetP := vexp - Int64(emin) + p;
  if targetP > p then targetP := p;
  var excess := qb - targetP;
  var keep := LToQWord(LShr(q, LongWord(excess)));
  var roundBit := LTestBit(q, LongWord(excess - 1));
  var rest := Length(r) > 0;
  if not rest then begin
    var uq: UBigInt;
    uq.fLimbs := q;
    var lsb := uq.lowestSetBit;
    rest := (lsb >= 0) and (lsb < excess - 1);
  end;
  if roundBit and (rest or (keep and 1 = 1)) then begin
    if keep = High(QWord) then begin
      // 64-bit mantissa rolled over to 2^64
      if vexp + 1 > emax then exit(sgn * FltPosInf);
      exit(sgn * FltLdexp(2.0, integer(vexp)));
    end;
    inc(keep);
  end;
  if keep = 0 then exit(sgn * 0.0);
  var fe := vexp - targetP + 1;
  if Int64(BsrQWord(keep)) + fe > emax then exit(sgn * FltPosInf);
  result := sgn * FltLdexp(Extended(keep), integer(fe));
end;

function BigDecimal.toDouble: Double;
begin
  result := Double(DecToFloat(self, 53, -1022, 1023));
end;

function BigDecimal.toSingle: Single;
begin
  result := Single(DecToFloat(self, 24, -126, 127));
end;

{$ifdef FPC_HAS_TYPE_EXTENDED}
function BigDecimal.toExtended: Extended;
begin
  result := DecToFloat(self, 64, -16382, 16383);
end;
{$endif}

class function BigDecimal.fromDouble(d: Double): BigDecimal;
begin
  var neg: boolean;
  var m: QWord;
  var e2: integer;
  SplitDouble(d, neg, m, e2);
  result := DecFromShortest(neg, m, e2, (m = QWord(1) shl 52) and (e2 > -1074));
end;

class function BigDecimal.fromDoubleExact(d: Double): BigDecimal;
begin
  var neg: boolean;
  var m: QWord;
  var e2: integer;
  SplitDouble(d, neg, m, e2);
  result := DecFromFloatExact(neg, m, e2);
end;

class function BigDecimal.fromSingle(s: Single): BigDecimal;
begin
  var neg: boolean;
  var m: QWord;
  var e2: integer;
  SplitSingle(s, neg, m, e2);
  result := DecFromShortest(neg, m, e2, (m = 1 shl 23) and (e2 > -149));
end;

class function BigDecimal.fromSingleExact(s: Single): BigDecimal;
begin
  var neg: boolean;
  var m: QWord;
  var e2: integer;
  SplitSingle(s, neg, m, e2);
  result := DecFromFloatExact(neg, m, e2);
end;

{$ifdef FPC_HAS_TYPE_EXTENDED}
class function BigDecimal.fromExtended(e: Extended): BigDecimal;
begin
  var neg: boolean;
  var m: QWord;
  var e2: integer;
  SplitExtended(e, neg, m, e2);
  result := DecFromShortest(neg, m, e2, (m = QWord(1) shl 63) and (e2 > -16445));
end;

class function BigDecimal.fromExtendedExact(e: Extended): BigDecimal;
begin
  var neg: boolean;
  var m: QWord;
  var e2: integer;
  SplitExtended(e, neg, m, e2);
  result := DecFromFloatExact(neg, m, e2);
end;
{$endif}

function BigDecimal.hashCode: DWord;
begin
  DecCanon(self, var m, var e);
  var b: BigInt;
  b.fLimbs := m;
  b.fNeg := fMan.fNeg and (Length(m) > 0);
  result := b.hashCode xor (DWord(e) * 16777619);
end;

procedure BigDecimal.swap(var other: BigDecimal);
begin
  fMan.swap(other.fMan);
  SwapValues(fExp, other.fExp);
  SwapValues(fHidden, other.fHidden);
end;

class function BigDecimal.zero: BigDecimal;
begin
  result := default(BigDecimal);
end;

class function BigDecimal.one: BigDecimal;
begin
  result := default(BigDecimal);
  result.fMan := 1;
end;

class function BigDecimal.two: BigDecimal;
begin
  result := default(BigDecimal);
  result.fMan := 2;
end;

class function BigDecimal.ten: BigDecimal;
begin
  result := default(BigDecimal);
  result.fMan := 1;
  result.fExp := 1;
end;

// ---------------------------------------------------------------------------
// BigDecimal transcendentals
// ---------------------------------------------------------------------------

// the transcendental functions run on plain integers scaled by 10^w, with w
// a couple dozen digits above the requested precision; series terms and
// divisions truncate, the surplus digits absorb the accumulated error

var
  // pi, ln 2 and ln 10 caches (scaled integers, grown on demand)
  PiCache: UBigInt;
  PiCacheW: Int64 = -1;
  Ln2Cache: UBigInt;
  Ln2CacheW: Int64 = -1;
  Ln10Cache: UBigInt;
  Ln10CacheW: Int64 = -1;

function UScaleDown(const v: UBigInt; k: Int64): UBigInt;
begin
  if k <= 0 then exit(v);
  var q, r: TLimbs;
  LDivMod(v.fLimbs, UPow10(LongWord(k)).fLimbs, q, r);
  result.fLimbs := q;
end;

// value * 10^w, truncated toward zero
function DecToScaled(const a: BigDecimal; w: Int64): BigInt;
begin
  var t := Int64(a.fExp) + w;
  if t >= 0 then result.fLimbs := LScale10(a.fMan.fLimbs, t)
  else begin
    var q, r: TLimbs;
    LDivMod(a.fMan.fLimbs, UPow10(LongWord(-t)).fLimbs, q, r);
    result.fLimbs := q;
  end;
  result.fNeg := a.fMan.fNeg and (result.fLen > 0);
end;

// wrap a scaled result: v * 10^-w cut to p fractional digits (or p
// significant digits for small values) plus the hidden guard digit
function DecFromScaled(const v: BigInt; w: Int64; p: integer): BigDecimal;
begin
  if v.fLen = 0 then exit(default(BigDecimal));
  // exponent of the leading digit, bounded from below
  var msdLo := (Int64(LBitLen(v.fLimbs)) - 1) * 1233 div 4096 - w;
  var er := -Int64(p) - 1;
  if msdLo - p < er then er := msdLo - p;
  if er < -(w - 8) then er := -(w - 8);
  var m: BigInt;
  if w + er > 0 then begin
    var q, r: TLimbs;
    LDivMod(v.fLimbs, UPow10(LongWord(w + er)).fLimbs, q, r);
    m.fLimbs := q;
  end else m.fLimbs := v.fLimbs;
  m.fNeg := v.fNeg and (m.fLen > 0);
  result := DecMake(m, er, true);
end;

// cut an already computed value down to `p` fractional digits the same way
function DecGuardCut(const a: BigDecimal; p: integer): BigDecimal;
begin
  if (a.fMan.fLen = 0) or (a.fExp >= 0) then exit(a);
  result := DecFromScaled(a.fMan, -Int64(a.fExp), p);
end;

// Chudnovsky binary splitting for pi
procedure ChudPQT(a, b: LongWord; out p, q, t: BigInt);
begin
  if b - a = 1 then begin
    if a = 0 then begin
      p := 1;
      q := 1;
    end else begin
      p := BigInt(Int64(6) * a - 5) * (Int64(2) * a - 1) * (Int64(6) * a - 1);
      q := BigInt(Int64(a)) * Int64(a) * Int64(a) * Int64(10939058860032000);
    end;
    t := p * (Int64(13591409) + Int64(545140134) * a);
    if a and 1 = 1 then t.negate;
  end else begin
    var m := (a + b) div 2;
    var p1, q1, t1, p2, q2, t2: BigInt;
    ChudPQT(a, m, p1, q1, t1);
    ChudPQT(m, b, p2, q2, t2);
    p := p1 * p2;
    q := q1 * q2;
    t := t1 * q2 + p1 * t2;
  end;
end;

// pi * 10^w (each Chudnovsky term is worth 14.18 digits)
function PiScaled(w: Int64): UBigInt;
begin
  if PiCacheW < w then begin
    var wc := w + 32;
    var p, q, t: BigInt;
    ChudPQT(0, LongWord(wc div 14) + 2, p, q, t);
    var sq := (UBigInt(10005) * UPow10(LongWord(2 * wc))).sqrt;
    PiCache := UBigInt(426880) * sq * q.magnitude div t.magnitude;
    PiCacheW := wc;
  end;
  result := UScaleDown(PiCache, PiCacheW - w);
end;

// artanh(1/q) * 10^w by the direct series, two cheap passes per term
function UArtanhInv(q, w: Int64): UBigInt;
begin
  var wc := w + 24;
  var t := UPow10(LongWord(wc)) div q;
  var s := t;
  var q2 := q * q;
  var j: Int64 := 1;
  repeat
    t := t div q2;
    if t.isZero then break;
    j := j + 2;
    s := s + t div j;
  until false;
  result := UScaleDown(s, wc - w);
end;

// ln 2 = 2 artanh(1/3) and ln 10 = 3 ln 2 + 2 artanh(1/9), both scaled
function Ln2Scaled(w: Int64): UBigInt;
begin
  if Ln2CacheW < w then begin
    Ln2Cache := UArtanhInv(3, w + 32) * 2;
    Ln2CacheW := w + 32;
  end;
  result := UScaleDown(Ln2Cache, Ln2CacheW - w);
end;

function Ln10Scaled(w: Int64): UBigInt;
begin
  if Ln10CacheW < w then begin
    var wc := w + 32;
    Ln10Cache := Ln2Scaled(wc) * 3 + UArtanhInv(9, wc) * 2;
    Ln10CacheW := wc;
  end;
  result := UScaleDown(Ln10Cache, Ln10CacheW - w);
end;

// e^(X / 10^w) * 10^w: the argument is halved into (-1/2, 1/2), the Taylor
// sum runs on scaled integers and the halvings are squared back
function ExpScaled(const X: BigInt; w: Int64): UBigInt;
begin
  var p10 := UPow10(LongWord(w));
  if X.fLen = 0 then exit(p10);
  var xu: UBigInt;
  xu.fLimbs := X.fLimbs;
  var k := Int64(LBitLen(X.fLimbs)) + 2 - LBitLen(p10.fLimbs);
  if k < 0 then k := 0;
  if k > 0 then xu := xu shr k;
  var t := p10;
  var s := p10;
  var i: Int64 := 1;
  repeat
    t := t * xu div p10 div i;
    if t.isZero then break;
    s := s + t;
    inc(i);
  until false;
  for var j := 1 to k do s := s.sqr div p10;
  if X.fNeg then s := UPow10(LongWord(2 * w)) div s;
  result := s;
end;

class function BigDecimal.pi(precision: integer): BigDecimal;
begin
  var p := precision;
  if p < 0 then p := 0;
  var w := Int64(p) + 10;
  var v: BigInt;
  v.fLimbs := PiScaled(w).fLimbs;
  v.fNeg := false;
  result := DecFromScaled(v, w, p);
end;

class function BigDecimal.e(precision: integer): BigDecimal;
begin
  var p := precision;
  if p < 0 then p := 0;
  var w := Int64(p) + 16;
  var t := UPow10(LongWord(w));
  var s := t;
  var i: Int64 := 1;
  repeat
    t := t div i;
    if t.isZero then break;
    s := s + t;
    inc(i);
  until false;
  var v: BigInt;
  v.fLimbs := s.fLimbs;
  v.fNeg := false;
  result := DecFromScaled(v, w, p);
end;

function BigDecimal.exp(precision: integer): BigDecimal;
begin
  var p := precision;
  if p < 0 then p := 0;
  if fMan.isZero then exit(BigDecimal.one);
  var lo, hi: Int64;
  DecMagBoundsP(fMan.dataPtr, fMan.fLen, fExp, lo, hi);
  // e^(10^10) does not fit a 32-bit decimal exponent anymore
  if hi >= 10 then RaiseDecExpRange;
  var ax := toDouble;
  if ax < 0 then ax := -ax;
  // integer digits of the result (leading zeros for a negative argument)
  var d := System.Trunc(ax * 0.4342944819032518) + 2;
  var w := Int64(p) + d + 24;
  var s: BigInt;
  s.fLimbs := ExpScaled(DecToScaled(self, w), w).fLimbs;
  s.fNeg := false;
  result := DecFromScaled(s, w, p);
end;

function BigDecimal.ln(precision: integer): BigDecimal;
begin
  var p := precision;
  if p < 0 then p := 0;
  if fMan.fNeg or fMan.isZero then raise EBigIntError.Create('logarithm of a non-positive value');
  if isOne then exit(default(BigDecimal));
  var w := Int64(p) + 28;
  var p10 := UPow10(LongWord(w));
  // mantissa scaled into [1, 10) at w digits; f is the leading-digit exponent
  DecCanon(self, var m, var e);
  var dc := Int64(Length(LToBase(m, 10)));
  var f := e + dc - 1;
  var t := w - (dc - 1);
  var mu: UBigInt;
  if t >= 0 then mu.fLimbs := LScale10(m, t)
  else begin
    var q, r: TLimbs;
    LDivMod(m, UPow10(LongWord(-t)).fLimbs, q, r);
    mu.fLimbs := q;
  end;
  // halve into (0.707, 1.415], then six square roots pull it against 1,
  // so the artanh series below gains five digits per term
  var j2 := 0;
  var s2 := (UBigInt(2) * UPow10(LongWord(2 * w))).sqrt;
  while mu > s2 do begin
    mu := mu shr 1;
    inc(j2);
  end;
  for var i := 1 to 6 do mu := (mu * p10).sqrt;
  // z = (y - 1) / (y + 1), ln y = 2^7 artanh(z) after the six roots
  var zneg := mu < p10;
  var zu := (if zneg then p10 - mu else mu - p10) * p10 div (mu + p10);
  var s := zu;
  var tt := zu;
  var z2 := zu.sqr div p10;
  var j: Int64 := 1;
  repeat
    tt := tt * z2 div p10;
    if tt.isZero then break;
    j := j + 2;
    s := s + tt div j;
  until false;
  var r: BigInt;
  r.fLimbs := (s shl 7).fLimbs;
  r.fNeg := zneg and (r.fLen > 0);
  if j2 <> 0 then r := r + BigInt(Int64(j2)) * Ln2Scaled(w).toBigInt;
  if f <> 0 then r := r + BigInt(f) * Ln10Scaled(w).toBigInt;
  result := DecFromScaled(r, w, p);
end;

function BigDecimal.log2(precision: integer): BigDecimal;
begin
  var p := precision;
  if p < 0 then p := 0;
  if fMan.fNeg or fMan.isZero then raise EBigIntError.Create('logarithm of a non-positive value');
  DecCanon(self, var m, var e);
  // exact powers of two: man * 10^e = 2^k needs man = 2^(k-e) * 5^(-e)
  if (e <= 0) and ((-e) * 699 div 1000 + 1 <= Int64(LBitLen(m)) * 1233 div 4096 + 1) then begin
    var u: UBigInt;
    u.fLimbs := m;
    if e < 0 then begin
      var (q5, r5) := u.divMod(UBigInt(5).pow(LongWord(-e)));
      if r5.isZero then u := q5 else u := UBigInt.zero;
    end;
    if u.isPowerOfTwo then begin
      result := BFromI64(u.lowestSetBit + e);
      exit;
    end;
  end;
  var w := Int64(p) + 20;
  var lnr := DecToScaled(ln(p + 12), w);
  var q: BigInt;
  q.fLimbs := (lnr.magnitude * UPow10(LongWord(w)) div Ln2Scaled(w)).fLimbs;
  q.fNeg := lnr.fNeg and (q.fLen > 0);
  result := DecFromScaled(q, w, p);
end;

function BigDecimal.log10(precision: integer): BigDecimal;
begin
  var p := precision;
  if p < 0 then p := 0;
  if fMan.fNeg or fMan.isZero then raise EBigIntError.Create('logarithm of a non-positive value');
  DecCanon(self, var m, var e);
  // exact powers of ten
  if (Length(m) = 1) and (m[0] = 1) then begin
    result := BFromI64(e);
    exit;
  end;
  var w := Int64(p) + 20;
  var lnr := DecToScaled(ln(p + 12), w);
  var q: BigInt;
  q.fLimbs := (lnr.magnitude * UPow10(LongWord(w)) div Ln10Scaled(w)).fLimbs;
  q.fNeg := lnr.fNeg and (q.fLen > 0);
  result := DecFromScaled(q, w, p);
end;

function BigDecimal.logBase(const b: BigDecimal; precision: integer): BigDecimal;
begin
  var p := precision;
  if p < 0 then p := 0;
  if b.isOne then raise EBigIntError.Create('logarithm base one');
  result := DecGuardCut(ln(p + 12).divide(b.ln(p + 12), p + 4), p);
end;

function BigDecimal.pow(const y: BigDecimal; precision: integer): BigDecimal;
begin
  var p := precision;
  if p < 0 then p := 0;
  if y.isIntegral and y.fitsInInt64 then exit(pow(y.toInt64));
  if fMan.isZero then begin
    if y.isNegative then RaiseDivByZero;
    exit(default(BigDecimal));
  end;
  if fMan.fNeg then raise EBigIntError.Create('fractional power of a negative value');
  if isOne then exit(BigDecimal.one);
  // magnitude of y*ln(x) drives the extra working digits
  var yd := y.toDouble;
  if yd < 0 then yd := -yd;
  var zd := yd * (System.Abs(Double(mostSignificantExponent)) + 1.0) * 2.302585092994046;
  if DblIsNanOrInf(zd) or (zd > 4.6E9) then RaiseDecExpRange;
  var d := System.Trunc(zd * 0.4342944819032518) + 2;
  var dy := y.mostSignificantExponent + 1;
  if dy < 0 then dy := 0;
  result := (y * ln(p + d + dy + 12)).exp(p);
end;

function BigDecimal.nthRoot(n: LongWord; precision: integer): BigDecimal;
begin
  if n = 0 then raise EBigIntError.Create('zeroth root is undefined');
  var p := precision;
  if p < 0 then p := 0;
  if fMan.isZero then exit(default(BigDecimal));
  if fMan.fNeg and (n and 1 = 0) then raise EBigIntError.Create('even root of a negative value');
  if n = 1 then exit(self);
  var p1 := Int64(p) + 1;
  var k := Int64(fExp) + Int64(n) * p1;
  if (k > High(integer)) or (k < -Int64(High(integer))) then RaiseDecExpRange;
  var nu: UBigInt;
  var exact := true;
  if k >= 0 then nu.fLimbs := LScale10(fMan.fLimbs, k)
  else begin
    var q, r: TLimbs;
    LDivMod(fMan.fLimbs, UPow10(LongWord(-k)).fLimbs, q, r);
    nu.fLimbs := q;
    exact := Length(r) = 0;
  end;
  var root := nu.nthRoot(n);
  if exact then exact := root.pow(n) = nu;
  var m: BigInt;
  m.fLimbs := root.fLimbs;
  m.fNeg := fMan.fNeg and (root.fLen > 0);
  result := DecMake(m, -p1, not exact);
end;

class operator BigDecimal.**(const a, b: BigDecimal): BigDecimal;
begin
  result := a.pow(b);
end;

// reduce |a| modulo pi/2 at a precision matching the argument size: r is the
// signed remainder scaled by 10^w with |r| a touch above pi/4, quad the
// quadrant of |a|
procedure TrigReduce(const a: BigDecimal; w: Int64; out r: BigInt; out quad: integer);
begin
  var lo, hi: Int64;
  DecMagBoundsP(a.fMan.dataPtr, a.fMan.fLen, a.fExp, lo, hi);
  var wred := w + 8;
  if hi > 0 then wred := wred + hi;
  var xu: UBigInt;
  xu.fLimbs := DecToScaled(a, wred).fLimbs;
  var ph := PiScaled(wred) div 2;
  var q := (xu * 2 + ph) div (ph * 2);
  var rb := xu.toBigInt - (q * ph).toBigInt;
  quad := integer(LModW(q.fLimbs, 4));
  r.fLimbs := UScaleDown(rb.magnitude, wred - w).fLimbs;
  r.fNeg := rb.fNeg and (r.fLen > 0);
end;

// sine and cosine of r = R/10^w for |r| below 0.8, both scaled by 10^w
procedure SinCosScaled(const r: BigInt; w: Int64; out sinS: BigInt; out cosS: UBigInt);
begin
  var p10 := UPow10(LongWord(w));
  var ru: UBigInt;
  ru.fLimbs := r.fLimbs;
  var r2 := ru.sqr div p10;
  var s := ru;
  var t := ru;
  var j: Int64 := 1;
  var sub := true;
  repeat
    t := t * r2 div p10 div ((j + 1) * (j + 2));
    if t.isZero then break;
    j := j + 2;
    if sub then s := s - t else s := s + t;
    sub := not sub;
  until false;
  sinS.fLimbs := s.fLimbs;
  sinS.fNeg := r.fNeg and (s.fLen > 0);
  var c := p10;
  t := p10;
  j := 0;
  sub := true;
  repeat
    t := t * r2 div p10 div ((j + 1) * (j + 2));
    if t.isZero then break;
    j := j + 2;
    if sub then c := c - t else c := c + t;
    sub := not sub;
  until false;
  cosS := c;
end;

// arctan of x = XU/10^w, XU >= 0, scaled by 10^w: arguments above one fold
// through pi/2 - arctan(1/x), the rest is halved under 1e-3 and summed
function ATanScaledU(XU: UBigInt; w: Int64): UBigInt;
begin
  var p10 := UPow10(LongWord(w));
  if XU = p10 then exit(PiScaled(w) div 4);
  var fold := XU > p10;
  if fold then XU := p10 * p10 div XU;
  var cnt := 0;
  var thresh := p10 div 1000;
  while XU > thresh do begin
    // x := x / (1 + sqrt(1 + x^2)) halves the angle
    var h := (p10 * p10 + XU * XU).sqrt;
    XU := XU * p10 div (p10 + h);
    inc(cnt);
  end;
  var s := XU;
  var t := XU;
  var x2 := XU.sqr div p10;
  var j: Int64 := 1;
  var sub := true;
  repeat
    t := t * x2 div p10;
    if t.isZero then break;
    j := j + 2;
    var d := t div j;
    if d.isZero then break;
    if sub then s := s - d else s := s + d;
    sub := not sub;
  until false;
  s := s shl cnt;
  if fold then s := PiScaled(w) div 2 - s;
  result := s;
end;

function BigDecimal.sin(precision: integer): BigDecimal;
begin
  var p := precision;
  if p < 0 then p := 0;
  if fMan.isZero then exit(default(BigDecimal));
  var w := Int64(p) + 20;
  var msd := mostSignificantExponent;
  if msd < 0 then w := w - msd;
  var r: BigInt;
  var quad: integer;
  TrigReduce(abs, w, r, quad);
  var ss, v: BigInt;
  var cc: UBigInt;
  SinCosScaled(r, w, ss, cc);
  case quad of
    0: v := ss;
    1: begin
      v.fLimbs := cc.fLimbs;
      v.fNeg := false;
    end;
    2: v := -ss;
    else begin
      v.fLimbs := cc.fLimbs;
      v.fNeg := cc.fLen > 0;
    end;
  end;
  if fMan.fNeg then v := -v;
  result := DecFromScaled(v, w, p);
end;

function BigDecimal.cos(precision: integer): BigDecimal;
begin
  var p := precision;
  if p < 0 then p := 0;
  if fMan.isZero then exit(BigDecimal.one);
  var w := Int64(p) + 20;
  var r: BigInt;
  var quad: integer;
  TrigReduce(abs, w, r, quad);
  var ss, v: BigInt;
  var cc: UBigInt;
  SinCosScaled(r, w, ss, cc);
  case quad of
    0: begin
      v.fLimbs := cc.fLimbs;
      v.fNeg := false;
    end;
    1: v := -ss;
    2: begin
      v.fLimbs := cc.fLimbs;
      v.fNeg := cc.fLen > 0;
    end;
    else v := ss;
  end;
  result := DecFromScaled(v, w, p);
end;

function BigDecimal.tan(precision: integer): BigDecimal;
begin
  var p := precision;
  if p < 0 then p := 0;
  if fMan.isZero then exit(default(BigDecimal));
  var w := Int64(p) + 24;
  var msd := mostSignificantExponent;
  if msd < 0 then w := w - msd;
  var r: BigInt;
  var quad: integer;
  TrigReduce(abs, w, r, quad);
  var ss: BigInt;
  var cc: UBigInt;
  SinCosScaled(r, w, ss, cc);
  var p10 := UPow10(LongWord(w));
  var v: BigInt;
  if quad and 1 = 0 then begin
    // tan r: the cosine of a reduced argument never vanishes
    v.fLimbs := (ss.magnitude * p10 div cc).fLimbs;
    v.fNeg := ss.fNeg and (v.fLen > 0);
  end else begin
    // tan(pi/2 + r) = -cos r / sin r
    if ss.isZero then raise EBigIntError.Create('tangent pole');
    v.fLimbs := (cc * p10 div ss.magnitude).fLimbs;
    v.fNeg := not ss.fNeg and (v.fLen > 0);
  end;
  if fMan.fNeg then v := -v;
  result := DecFromScaled(v, w, p);
end;

function BigDecimal.arctan(precision: integer): BigDecimal;
begin
  var p := precision;
  if p < 0 then p := 0;
  if fMan.isZero then exit(default(BigDecimal));
  var w := Int64(p) + 20;
  var msd := mostSignificantExponent;
  if msd < 0 then w := w - msd;
  var xu: UBigInt;
  xu.fLimbs := DecToScaled(self, w).fLimbs;
  var v: BigInt;
  v.fLimbs := ATanScaledU(xu, w).fLimbs;
  v.fNeg := fMan.fNeg;
  result := DecFromScaled(v, w, p);
end;

function BigDecimal.arcsin(precision: integer): BigDecimal;
begin
  var p := precision;
  if p < 0 then p := 0;
  if fMan.isZero then exit(default(BigDecimal));
  var c := abs.compare(BigDecimal.one);
  if c > 0 then raise EBigIntError.Create('arcsine argument outside -1..1');
  var w := Int64(p) + 20;
  var msd := mostSignificantExponent;
  if msd < 0 then w := w - msd;
  var v: BigInt;
  if c = 0 then v.fLimbs := (PiScaled(w) div 2).fLimbs
  else begin
    // arcsin(x) = arctan(x / sqrt(1 - x^2))
    var xu: UBigInt;
    xu.fLimbs := DecToScaled(self, w).fLimbs;
    var p10 := UPow10(LongWord(w));
    var den := (p10 * p10 - xu * xu).sqrt;
    v.fLimbs := ATanScaledU(xu * p10 div den, w).fLimbs;
  end;
  v.fNeg := fMan.fNeg;
  result := DecFromScaled(v, w, p);
end;

function BigDecimal.arccos(precision: integer): BigDecimal;
begin
  var p := precision;
  if p < 0 then p := 0;
  if abs.compare(BigDecimal.one) > 0 then raise EBigIntError.Create('arccosine argument outside -1..1');
  var w := Int64(p) + 20;
  var v: BigInt;
  v.fNeg := false;
  if fMan.isZero then v.fLimbs := (PiScaled(w) div 2).fLimbs
  else begin
    // arccos(x) = arctan(sqrt(1 - x^2) / x), plus pi below zero - the
    // cancellation-free form
    var xu: UBigInt;
    xu.fLimbs := DecToScaled(self, w).fLimbs;
    var p10 := UPow10(LongWord(w));
    var den := (p10 * p10 - xu * xu).sqrt;
    var at := ATanScaledU(den * p10 div xu, w);
    if fMan.fNeg then v.fLimbs := (PiScaled(w) - at).fLimbs
    else v.fLimbs := at.fLimbs;
  end;
  result := DecFromScaled(v, w, p);
end;

function BigDecimal.sinh(precision: integer): BigDecimal;
begin
  var p := precision;
  if p < 0 then p := 0;
  if fMan.isZero then exit(default(BigDecimal));
  if abs.compare(BigDecimal.one) <= 0 then begin
    // the plus-only sine series keeps tiny arguments significant
    var w := Int64(p) + 20;
    var msd := mostSignificantExponent;
    if msd < 0 then w := w - msd;
    var p10 := UPow10(LongWord(w));
    var xu: UBigInt;
    xu.fLimbs := DecToScaled(self, w).fLimbs;
    var r2 := xu.sqr div p10;
    var s := xu;
    var t := xu;
    var j: Int64 := 1;
    repeat
      t := t * r2 div p10 div ((j + 1) * (j + 2));
      if t.isZero then break;
      j := j + 2;
      s := s + t;
    until false;
    var v: BigInt;
    v.fLimbs := s.fLimbs;
    v.fNeg := fMan.fNeg and (s.fLen > 0);
    exit(DecFromScaled(v, w, p));
  end;
  // (e^x - e^-x) / 2
  var lo, hi: Int64;
  DecMagBoundsP(fMan.dataPtr, fMan.fLen, fExp, lo, hi);
  if hi >= 10 then RaiseDecExpRange;
  var ax := toDouble;
  if ax < 0 then ax := -ax;
  var d := System.Trunc(ax * 0.4342944819032518) + 2;
  var w := Int64(p) + d + 24;
  var eu := ExpScaled(DecToScaled(abs, w), w);
  var p10 := UPow10(LongWord(w));
  var v: BigInt;
  v.fLimbs := ((eu - p10 * p10 div eu) div 2).fLimbs;
  v.fNeg := fMan.fNeg;
  result := DecFromScaled(v, w, p);
end;

function BigDecimal.cosh(precision: integer): BigDecimal;
begin
  var p := precision;
  if p < 0 then p := 0;
  if fMan.isZero then exit(BigDecimal.one);
  var lo, hi: Int64;
  DecMagBoundsP(fMan.dataPtr, fMan.fLen, fExp, lo, hi);
  if hi >= 10 then RaiseDecExpRange;
  var ax := toDouble;
  if ax < 0 then ax := -ax;
  var d := System.Trunc(ax * 0.4342944819032518) + 2;
  var w := Int64(p) + d + 24;
  var eu := ExpScaled(DecToScaled(abs, w), w);
  var p10 := UPow10(LongWord(w));
  var v: BigInt;
  v.fLimbs := ((eu + p10 * p10 div eu) div 2).fLimbs;
  v.fNeg := false;
  result := DecFromScaled(v, w, p);
end;

function BigDecimal.tanh(precision: integer): BigDecimal;
begin
  var p := precision;
  if p < 0 then p := 0;
  if fMan.isZero then exit(default(BigDecimal));
  var v: BigInt;
  if abs.compare(BigDecimal.one) <= 0 then begin
    // sinh / cosh with cosh = sqrt(1 + sinh^2), all in one scale
    var w := Int64(p) + 20;
    var msd := mostSignificantExponent;
    if msd < 0 then w := w - msd;
    var p10 := UPow10(LongWord(w));
    var xu: UBigInt;
    xu.fLimbs := DecToScaled(self, w).fLimbs;
    var r2 := xu.sqr div p10;
    var s := xu;
    var t := xu;
    var j: Int64 := 1;
    repeat
      t := t * r2 div p10 div ((j + 1) * (j + 2));
      if t.isZero then break;
      j := j + 2;
      s := s + t;
    until false;
    v.fLimbs := (s * p10 div (p10 * p10 + s.sqr).sqrt).fLimbs;
    v.fNeg := fMan.fNeg and (v.fLen > 0);
    exit(DecFromScaled(v, w, p));
  end;
  // (1 - u) / (1 + u) with u = e^(-2|x|); past the working scale u is zero
  var w := Int64(p) + 24;
  var p10 := UPow10(LongWord(w));
  var ax := toDouble;
  if ax < 0 then ax := -ax;
  var u := UBigInt.zero;
  if 0.8685889638065036 * ax <= w + 2 then begin
    var x2 := DecToScaled(abs, w);
    x2 := x2 + x2;
    x2.fNeg := true;
    u := ExpScaled(x2, w);
  end;
  v.fLimbs := ((p10 - u) * p10 div (p10 + u)).fLimbs;
  v.fNeg := fMan.fNeg;
  result := DecFromScaled(v, w, p);
end;

function BigDecimal.toEngineering: string;
var
  m: TLimbs;
  e: Int64;
begin
  DecDisplay(self, m, e);
  if Length(m) = 0 then exit('0');
  var digits := LToBase(m, 10);
  var l := Length(digits);
  var realExp := e + l - 1;
  var fm := realExp mod 3;
  if fm < 0 then fm := fm + 3;
  var before := integer(fm) + 1;
  if l <= before then result := digits + StringOfChar('0', before - l)
  else result := Copy(digits, 1, before) + '.' + Copy(digits, before + 1, l - before);
  result := result + 'E' + IntToStr(realExp - fm);
  if fMan.fNeg then result := '-' + result;
end;

function BigDecimal.toFraction: (num, den: BigInt);
var
  nn, dd: BigInt;
begin
  DecCanon(self, var m, var e);
  if e >= 0 then begin
    nn.fLimbs := LScale10(m, e);
    nn.fNeg := fMan.fNeg and (nn.fLen > 0);
    dd := 1;
  end else begin
    // the canonical mantissa shares only twos and fives with 10^-e
    var u: UBigInt;
    u.fLimbs := m;
    var dv := UPow10(LongWord(-e));
    var g := u.gcd(dv);
    nn.fLimbs := (u div g).fLimbs;
    nn.fNeg := fMan.fNeg;
    dd.fLimbs := (dv div g).fLimbs;
    dd.fNeg := false;
  end;
  exit(nn, dd);
end;

function BigDecimal.continuedFraction(maxTerms: integer): array of BigInt;
begin
  // a decimal is rational, so its expansion is finite and exact
  var (num, den) := toFraction;
  result := BigInt.continuedFraction(num, den);
  if (maxTerms > 0) and (Length(result) > maxTerms) then SetLength(result, maxTerms);
end;

function BigDecimal.quantize(const step: BigDecimal; mode: TBigDecimalRounding): BigDecimal;
begin
  var (q, r) := divMod(step);
  if r.isZero then exit(q * step);
  // the mode acts on the exact ratio self/step; "up" grows its magnitude
  var rhoNeg := fMan.fNeg <> step.fMan.fNeg;
  var up := false;
  if mode = bdrCeil then up := not rhoNeg
  else if mode = bdrFloor then up := rhoNeg
  else if mode <> bdrTrunc then begin
    var c := (r.abs + r.abs).compare(step.abs);
    if c > 0 then up := true
    else if c = 0 then begin
      if mode = bdrRound then up := true
      else if mode = bdrHalfUp then up := not rhoNeg
      else up := q.isOdd;
    end;
  end;
  if up then begin
    if rhoNeg then q := q - 1 else q := q + 1;
  end;
  result := q * step;
end;

function BigDecimal.approxEquals(const other, epsilon: BigDecimal): boolean;
begin
  result := (self - other).abs.compare(epsilon.abs) <= 0;
end;

function BigDecimal.roundToSignificant(digits: integer; mode: TBigDecimalRounding): BigDecimal;
begin
  if digits < 1 then raise EBigIntError.Create('roundToSignificant needs at least one digit');
  if isZero then exit(default(BigDecimal));
  result := rounded(mostSignificantExponent - digits + 1, mode);
end;

class function BigDecimal.atan2(const y, x: BigDecimal; precision: integer): BigDecimal;
begin
  var p := precision;
  if p < 0 then p := 0;
  var wp := p + 10;
  if x.isZero then begin
    if y.isZero then exit(default(BigDecimal));
    var h := BigDecimal.pi(wp).divide(2, wp);
    exit(DecGuardCut(if y.isNegative then -h else h, p));
  end;
  var at := y.divide(x, wp).arctan(wp);
  if x.isPositive then exit(DecGuardCut(at, p));
  // x < 0: swing by pi into the correct quadrant, keeping the sign of y
  var pv := BigDecimal.pi(wp);
  result := DecGuardCut(if y.isNegative then at - pv else at + pv, p);
end;

class function BigDecimal.hypot(const x, y: BigDecimal; precision: integer): BigDecimal;
begin
  var p := precision;
  if p < 0 then p := 0;
  result := (x * x + y * y).sqrt(p);
end;

class function BigDecimal.agm(const a, b: BigDecimal; precision: integer): BigDecimal;
begin
  var p := precision;
  if p < 0 then p := 0;
  if a.isNegative or b.isNegative then raise EBigIntError.Create('agm needs non-negative arguments');
  var wp := p + 12;
  var pa := a;
  var pb := b;
  var tol := BigDecimal.one.shifted10(-(p + 4));
  // quadratic convergence: a handful of steps reach any practical precision
  for var i := 1 to 200 do begin
    var na := (pa + pb).divide(2, wp);
    var nb := (pa * pb).sqrt(wp);
    pa := na;
    if (na - nb).abs < tol then break;
    pb := nb;
  end;
  result := DecGuardCut(pa, p);
end;

// ln Gamma(z) for z > 0: Stirling's series with a Bernoulli tail, the argument
// shifted up so the series converges fast, then the shift undone
function LnGammaPos(const z: BigDecimal; p: integer): BigDecimal;
begin
  var wp := p + 14;
  var need := p + 4;
  var shift := 0;
  if z < need then shift := need - z.trunc.toInt32;
  var w := z + shift;
  var lnw := w.ln(wp);
  // (w - 1/2) ln w - w + ln(2 pi)/2
  var res := (w - BigDecimal('0.5')) * lnw - w + (BigDecimal.pi(wp) * 2).ln(wp).divide(2, wp);
  var w2 := w * w;
  var wpow := w; // w^(2k-1)
  var tol := BigDecimal.one.shifted10(-(p + 8));
  var k := 1;
  while k <= p + 2 do begin
    var (bnum, bden) := BigInt.bernoulli(LongWord(2 * k));
    // B_{2k} / ((2k)(2k-1) * w^{2k-1})
    var denom := BigDecimal(bden) * Int64((2 * k) * (2 * k - 1)) * wpow;
    var term := BigDecimal(bnum).divide(denom, wp);
    res := res + term;
    if term.abs < tol then break;
    wpow := wpow * w2;
    inc(k);
  end;
  for var i := 0 to shift - 1 do res := res - (z + i).ln(wp);
  result := res;
end;

// erf via its Taylor series; wp already carries the guard for the cancellation
function ErfSeries(const x: BigDecimal; wp: integer): BigDecimal;
begin
  var x2 := x * x;
  var termNum := x; // x^(2n+1) / n!
  var sum := x;
  var tol := BigDecimal.one.shifted10(-(wp - 2));
  var n := 1;
  while true do begin
    termNum := (termNum * x2).divide(n, wp);
    var t := termNum.divide(2 * n + 1, wp);
    if (n and 1) = 1 then sum := sum - t else sum := sum + t;
    if t.abs < tol then break;
    inc(n);
    if n > 40 * wp + 200 then break;
  end;
  result := sum * BigDecimal(2).divide(BigDecimal.pi(wp).sqrt(wp), wp);
end;

// erfc for x > 0 by the Lentz continued fraction, no 1 - (nearly 1) loss
function ErfcCF(const x: BigDecimal; wp: integer): BigDecimal;
begin
  var tiny := BigDecimal.one.shifted10(-(wp + 20));
  var tol := BigDecimal.one.shifted10(-wp);
  var f := x;
  if f.isZero then f := tiny;
  var c := f;
  var d := BigDecimal.zero;
  var k := 1;
  while true do begin
    var a := BigDecimal(k).divide(2, wp);
    d := x + a * d;
    if d.isZero then d := tiny;
    c := x + a.divide(c, wp);
    if c.isZero then c := tiny;
    d := BigDecimal.one.divide(d, wp);
    var delta := c * d;
    f := f * delta;
    if (delta - 1).abs < tol then break;
    inc(k);
    if k > 40 * wp + 200 then break;
  end;
  // erfc(x) = exp(-x^2) / (sqrt(pi) * D)
  result := (-(x * x)).exp(wp).divide(BigDecimal.pi(wp).sqrt(wp) * f, wp);
end;

function BigDecimal.lnGamma(precision: integer): BigDecimal;
begin
  var p := precision;
  if p < 0 then p := 0;
  if fMan.fNeg or isZero then raise EBigIntError.Create('lnGamma needs a positive argument');
  result := DecGuardCut(LnGammaPos(self, p + 4), p);
end;

function BigDecimal.gamma(precision: integer): BigDecimal;
begin
  var p := precision;
  if p < 0 then p := 0;
  if isZero or (isIntegral and fMan.fNeg) then raise EBigIntError.Create('gamma has a pole at zero and the negative integers');
  // exact for a small positive integer: Gamma(n) = (n-1)!
  if isIntegral and isPositive and fitsInUInt32 then begin
    var k := toUInt32;
    if k <= 1000 then begin
      var d: BigDecimal := UBigInt.factorial(k - 1);
      exit(d);
    end;
  end;
  if self < BigDecimal('0.5') then begin
    // reflection: Gamma(z) = pi / (sin(pi z) * Gamma(1 - z))
    var wp := p + 14;
    var pv := BigDecimal.pi(wp);
    var s := (pv * self).sin(wp);
    var g1 := (BigDecimal.one - self).gamma(wp);
    // the final divide already rounds to p digits, a second cut would drop some
    exit(pv.divide(s * g1, p));
  end;
  result := LnGammaPos(self, p + 8).exp(p);
end;

function BigDecimal.factorial(precision: integer): BigDecimal;
begin
  var p := precision;
  if p < 0 then p := 0;
  // exact when the argument is a small non-negative integer
  if isIntegral and not fMan.fNeg and fitsInUInt32 then begin
    var k := toUInt32;
    if k <= 1000 then begin
      var d: BigDecimal := UBigInt.factorial(k);
      exit(d);
    end;
  end;
  result := (self + 1).gamma(p);
end;

function BigDecimal.erf(precision: integer): BigDecimal;
begin
  var p := precision;
  if p < 0 then p := 0;
  if isZero then exit(default(BigDecimal));
  var neg := fMan.fNeg;
  var t := abs;
  var td := t.toDouble;
  // once erfc drops below the rounding threshold, erf is +-1
  if td * td > (p + 3) * 2.302585 + 5 then exit(if neg then -BigDecimal.one else BigDecimal.one);
  // the series cancels for large t; widen the working precision to compensate
  var guard := System.Trunc(0.44 * td * td) + 12;
  var r := ErfSeries(t, p + guard);
  if neg then r := -r;
  result := DecGuardCut(r, p);
end;

function BigDecimal.erfc(precision: integer): BigDecimal;
begin
  var p := precision;
  if p < 0 then p := 0;
  // for large positive x, 1 - erf loses all digits: use the continued fraction
  if self.toDouble > 1.5 then exit(DecGuardCut(ErfcCF(self, p + 12), p));
  // erf has to clear the guard band the cut drops, or it trims real digits
  result := DecGuardCut(BigDecimal.one - erf(p + 12), p);
end;

// ---------------------------------------------------------------------------
// BigDecimal calculator
// ---------------------------------------------------------------------------

// a stateless expression evaluator: one lexer pass, recursive descent with
// evaluation on the fly, everything computed on BigDecimal at a working
// precision a few digits above the requested one

type
  TCalcToken = (ckNumber, ckName, ckPlus, ckMinus, ckMul, ckDiv, ckIntDiv, ckMod, ckPow, ckFact, ckLParen, ckRParen, ckComma, ckEnd);

  TCalcState = record
    s: string;
    len: SizeInt;
    pos: SizeInt;       // next character to scan (1-based)
    kind: TCalcToken;
    tokPos: SizeInt;    // where the current token started
    num: BigDecimal;    // ckNumber payload
    name: string;       // ckName payload, lowercased
    wp: integer;        // working precision
    depth: integer;     // recursion guard (parens, calls, power chains)
  end;

procedure CalcError(const st: TCalcState; const msg: string);
begin
  raise EConvertError.Create($'calc: {msg} at position {st.tokPos}');
end;

// advance to the next token
procedure CalcNext(var st: TCalcState);
begin
  while (st.pos <= st.len) and (st.s[st.pos] in [' ', #9, #10, #13]) do inc(st.pos);
  st.tokPos := st.pos;
  if st.pos > st.len then begin
    st.kind := ckEnd;
    exit;
  end;
  var c: char := st.s[st.pos];
  // numbers: digits or a leading dot, separators, optional E exponent
  if (c in ['0'..'9']) or ((c = '.') and (st.pos < st.len) and (st.s[st.pos + 1] in ['0'..'9'])) then begin
    var start := st.pos;
    var dotSeen := false;
    while st.pos <= st.len do begin
      c := st.s[st.pos];
      if (c in ['0'..'9']) or (c = '_') then inc(st.pos)
      else if (c = '.') and not dotSeen then begin
        dotSeen := true;
        inc(st.pos);
      end else break;
    end;
    // exponent only when digits (or a signed digit) follow the E
    if (st.pos <= st.len) and (st.s[st.pos] in ['e', 'E']) then begin
      var q := st.pos + 1;
      if (q <= st.len) and (st.s[q] in ['+', '-']) then inc(q);
      if (q <= st.len) and (st.s[q] in ['0'..'9']) then begin
        st.pos := q;
        while (st.pos <= st.len) and (st.s[st.pos] in ['0'..'9', '_']) do inc(st.pos);
      end;
    end;
    if not BigDecimal.tryParse(Copy(st.s, start, st.pos - start), st.num) then CalcError(st, 'invalid number');
    st.kind := ckNumber;
    exit;
  end;
  if c in ['a'..'z', 'A'..'Z'] then begin
    var start := st.pos;
    while (st.pos <= st.len) and (st.s[st.pos] in ['a'..'z', 'A'..'Z', '0'..'9']) do inc(st.pos);
    st.name := LowerCase(Copy(st.s, start, st.pos - start));
    if st.name = 'div' then st.kind := ckIntDiv
    else if st.name = 'mod' then st.kind := ckMod
    else st.kind := ckName;
    exit;
  end;
  inc(st.pos);
  case c of
    '+': st.kind := ckPlus;
    '-': st.kind := ckMinus;
    '*': if (st.pos <= st.len) and (st.s[st.pos] = '*') then begin
      st.kind := ckPow;
      inc(st.pos);
    end else st.kind := ckMul;
    '/': st.kind := ckDiv;
    '%': st.kind := ckMod;
    '^': st.kind := ckPow;
    '!': st.kind := ckFact;
    '(': st.kind := ckLParen;
    ')': st.kind := ckRParen;
    ',': st.kind := ckComma;
    else CalcError(st, $'unexpected "{c}"');
  end;
end;

procedure CalcEnter(var st: TCalcState);
begin
  inc(st.depth);
  if st.depth > 256 then raise EConvertError.Create('calc: expression too deeply nested');
end;

function CalcExpr(var st: TCalcState): BigDecimal; forward;

// constants and function dispatch by lowercased name and argument count
function CalcName(var st: TCalcState; const fn: string; fnPos: SizeInt; const a: array of BigDecimal): BigDecimal;

  procedure needArgs(n: integer);
  begin
    if Length(a) <> n then begin
      st.tokPos := fnPos;
      CalcError(st, $'wrong number of arguments for "{fn}"');
    end;
  end;

begin
  match fn of
    'pi': begin
      needArgs(0);
      result := BigDecimal.pi(st.wp);
    end;
    'e': begin
      needArgs(0);
      result := BigDecimal.e(st.wp);
    end;
    'tau': begin
      needArgs(0);
      result := BigDecimal.pi(st.wp) * 2;
    end;
    'phi': begin
      needArgs(0);
      result := (BigDecimal(5).sqrt(st.wp) + 1) * BigDecimal('0.5');
    end;
    'sqrt': begin
      needArgs(1);
      result := a[0].sqrt(st.wp);
    end;
    'cbrt': begin
      needArgs(1);
      result := a[0].nthRoot(3, st.wp);
    end;
    'sqr': begin
      needArgs(1);
      result := a[0] * a[0];
    end;
    'abs': begin
      needArgs(1);
      result := a[0].abs;
    end;
    'exp': begin
      needArgs(1);
      result := a[0].exp(st.wp);
    end;
    'ln': begin
      needArgs(1);
      result := a[0].ln(st.wp);
    end;
    'log': begin
      // Excel convention: log(x) is base 10, log(x, b) any base
      if Length(a) = 1 then result := a[0].log10(st.wp)
      else begin
        needArgs(2);
        result := a[0].logBase(a[1], st.wp);
      end;
    end;
    'log2': begin
      needArgs(1);
      result := a[0].log2(st.wp);
    end;
    'log10': begin
      needArgs(1);
      result := a[0].log10(st.wp);
    end;
    'logb': begin
      needArgs(2);
      result := a[0].logBase(a[1], st.wp);
    end;
    'sin': begin
      needArgs(1);
      result := a[0].sin(st.wp);
    end;
    'cos': begin
      needArgs(1);
      result := a[0].cos(st.wp);
    end;
    'tan': begin
      needArgs(1);
      result := a[0].tan(st.wp);
    end;
    'asin', 'arcsin': begin
      needArgs(1);
      result := a[0].arcsin(st.wp);
    end;
    'acos', 'arccos': begin
      needArgs(1);
      result := a[0].arccos(st.wp);
    end;
    'atan', 'arctan': begin
      needArgs(1);
      result := a[0].arctan(st.wp);
    end;
    'sinh': begin
      needArgs(1);
      result := a[0].sinh(st.wp);
    end;
    'cosh': begin
      needArgs(1);
      result := a[0].cosh(st.wp);
    end;
    'tanh': begin
      needArgs(1);
      result := a[0].tanh(st.wp);
    end;
    'floor': begin
      needArgs(1);
      result := a[0].floor;
    end;
    'ceil': begin
      needArgs(1);
      result := a[0].ceil;
    end;
    'round': begin
      needArgs(1);
      result := a[0].round;
    end;
    'trunc': begin
      needArgs(1);
      result := a[0].trunc;
    end;
    'gamma': begin
      needArgs(1);
      result := a[0].gamma(st.wp);
    end;
    'lngamma': begin
      needArgs(1);
      result := a[0].lnGamma(st.wp);
    end;
    'erf': begin
      needArgs(1);
      result := a[0].erf(st.wp);
    end;
    'erfc': begin
      needArgs(1);
      result := a[0].erfc(st.wp);
    end;
    'factorial': begin
      needArgs(1);
      result := a[0].factorial(st.wp);
    end;
    'root': begin
      needArgs(2);
      if not (a[1].isIntegral and a[1].fitsInUInt32 and a[1].isPositive) then raise EBigIntError.Create('root degree must be a positive integer');
      result := a[0].nthRoot(a[1].toUInt32, st.wp);
    end;
    'pow': begin
      needArgs(2);
      result := a[0].pow(a[1], st.wp);
    end;
    'min': begin
      needArgs(2);
      result := a[0].min(a[1]);
    end;
    'max': begin
      needArgs(2);
      result := a[0].max(a[1]);
    end;
    'gcd': begin
      needArgs(2);
      result := a[0].gcd(a[1]);
    end;
    'lcm': begin
      needArgs(2);
      result := a[0].lcm(a[1]);
    end;
    'atan2': begin
      needArgs(2);
      result := BigDecimal.atan2(a[0], a[1], st.wp);
    end;
    'hypot': begin
      needArgs(2);
      result := BigDecimal.hypot(a[0], a[1], st.wp);
    end;
    'agm': begin
      needArgs(2);
      result := BigDecimal.agm(a[0], a[1], st.wp);
    end;
    else begin
      st.tokPos := fnPos;
      if Length(a) = 0 then CalcError(st, $'unknown name "{fn}"')
      else CalcError(st, $'unknown function "{fn}"');
    end;
  end;
end;

// atom: number | constant | function(args) | (expression), plus postfix "!"
function CalcAtom(var st: TCalcState): BigDecimal;
var
  v: BigDecimal;
begin
  case st.kind of
    ckNumber: begin
      v := st.num;
      CalcNext(st);
    end;
    ckLParen: begin
      CalcEnter(st);
      CalcNext(st);
      v := CalcExpr(st);
      if st.kind <> ckRParen then CalcError(st, 'expected ")"');
      dec(st.depth);
      CalcNext(st);
    end;
    ckName: begin
      var fn := st.name;
      var fnPos := st.tokPos;
      CalcNext(st);
      if st.kind = ckLParen then begin
        CalcEnter(st);
        CalcNext(st);
        var args: array of BigDecimal;
        if st.kind <> ckRParen then begin
          SetLength(args, 1);
          args[0] := CalcExpr(st);
          while st.kind = ckComma do begin
            CalcNext(st);
            SetLength(args, Length(args) + 1);
            args[High(args)] := CalcExpr(st);
          end;
        end;
        if st.kind <> ckRParen then CalcError(st, 'expected ")"');
        dec(st.depth);
        CalcNext(st);
        v := CalcName(st, fn, fnPos, args);
      end else v := CalcName(st, fn, fnPos, []);
    end;
    ckEnd: begin
      CalcError(st, 'unexpected end of expression');
      v := default(BigDecimal);
    end;
    else begin
      CalcError(st, 'unexpected token');
      v := default(BigDecimal);
    end;
  end;
  while st.kind = ckFact do begin
    v := v.factorial(st.wp);
    CalcNext(st);
  end;
  result := v;
end;

// power: right-associative, binds tighter than unary minus, so -2^2 = -4
// and 2^-3 works; the right side re-enters at the unary level
function CalcUnary(var st: TCalcState): BigDecimal; forward;

function CalcPower(var st: TCalcState): BigDecimal;
begin
  var base := CalcAtom(st);
  if st.kind = ckPow then begin
    CalcEnter(st);
    CalcNext(st);
    base := base.pow(CalcUnary(st), st.wp);
    dec(st.depth);
  end;
  result := base;
end;

// unary sign, iterative so "----1" cannot blow the stack
function CalcUnary(var st: TCalcState): BigDecimal;
begin
  var neg := false;
  while st.kind in [ckPlus, ckMinus] do begin
    if st.kind = ckMinus then neg := not neg;
    CalcNext(st);
  end;
  result := CalcPower(st);
  if neg then result := -result;
end;

function CalcTerm(var st: TCalcState): BigDecimal;
begin
  var v := CalcUnary(st);
  while st.kind in [ckMul, ckDiv, ckIntDiv, ckMod] do begin
    var op := st.kind;
    CalcNext(st);
    var rhs := CalcUnary(st);
    case op of
      ckMul: v := v * rhs;
      ckDiv: v := v.divide(rhs, st.wp);
      ckIntDiv: v := v div rhs;
      else v := v mod rhs;
    end;
  end;
  result := v;
end;

function CalcExpr(var st: TCalcState): BigDecimal;
begin
  var v := CalcTerm(st);
  while st.kind in [ckPlus, ckMinus] do begin
    var plus := st.kind = ckPlus;
    CalcNext(st);
    var rhs := CalcTerm(st);
    if plus then v := v + rhs else v := v - rhs;
  end;
  result := v;
end;

class function BigDecimal.calc(const s: string; precision: integer): BigDecimal;
var
  st: TCalcState;
begin
  var p := precision;
  if p < 0 then p := 0;
  st.s := s;
  st.len := Length(s);
  st.pos := 1;
  st.wp := p + 8;
  st.depth := 0;
  CalcNext(st);
  result := CalcExpr(st);
  if st.kind <> ckEnd then CalcError(st, 'unexpected token');
  // trim the working digits back to `precision` plus the usual hidden guard
  if Int64(result.fExp) < -(Int64(p) + 1) then begin
    result := result.rounded(-(p + 1), bdrTrunc);
    result.fHidden := (result.fExp = -(p + 1)) and (result.fMan.fLen > 0);
  end;
end;

class function BigDecimal.tryCalc(const s: string; out v: BigDecimal; precision: integer): boolean;
begin
  try
    v := calc(s, precision);
    result := true;
  except
    v := default(BigDecimal);
    result := false;
  end;
end;

{$ifdef BIGINT_ASM}
initialization
  UseAdx := CpuHasAdx;
{$endif}
end.
