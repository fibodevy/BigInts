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
    // math
    function sqr: UBigInt;
    function sqrt: UBigInt;
    function nthRoot(n: LongWord): UBigInt;
    function pow(e: LongWord): UBigInt;
    function modPow(const e, m: UBigInt): UBigInt;
    function modInverse(const m: UBigInt): UBigInt;
    function gcd(const other: UBigInt): UBigInt;
    function lcm(const other: UBigInt): UBigInt;
    // extras: number theory
    function jacobi(const n: UBigInt): integer;
    function modSqrt(const p: UBigInt): UBigInt;
    function isPerfectSquare: boolean;
    function sqrtRem: (root, rem: UBigInt);
    function factorize: array of (p: UBigInt; e: LongWord);
    // primes (Miller-Rabin; deterministic witnesses below 3.3e24, then random rounds)
    function isProbablePrime(rounds: integer = 24): boolean;
    function nextPrime: UBigInt;
    function prevPrime: UBigInt;
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
    class function randomPrime(bits: LongWord; rounds: integer = 24): UBigInt; static;
    class function factorial(n: LongWord): UBigInt; static;
    class function fibonacci(n: LongWord): UBigInt; static;
    class function lucas(n: LongWord): UBigInt; static;
    class function binomial(n, k: LongWord): UBigInt; static;
    class function catalan(n: LongWord): UBigInt; static;
    class function primorial(n: LongWord): UBigInt; static;
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
    // extras: number theory (factorize works on the absolute value)
    function gcdExt(const other: BigInt): (g, x, y: BigInt);
    function jacobi(const n: BigInt): integer;
    function modSqrt(const p: BigInt): BigInt;
    function isPerfectSquare: boolean;
    function sqrtRem: (root, rem: BigInt);
    function factorize: array of (p: BigInt; e: LongWord);
    // primes: negative values are never prime, nextPrime returns the first prime > self
    function isProbablePrime(rounds: integer = 24): boolean;
    function nextPrime: BigInt;
    function prevPrime: BigInt;
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
    class function randomPrime(bits: LongWord; rounds: integer = 24): BigInt; static;
    // Chinese remainder theorem for pairwise coprime positive moduli
    class function crt(const remainders, moduli: array of BigInt): BigInt; static;
    class function factorial(n: LongWord): BigInt; static;
    class function fibonacci(n: LongWord): BigInt; static;
    class function lucas(n: LongWord): BigInt; static;
    class function binomial(n, k: LongWord): BigInt; static;
    class function catalan(n: LongWord): BigInt; static;
    class function primorial(n: LongWord): BigInt; static;
  end;

  // declared after both records so UBigInt can offer a BigInt-returning method
  TUBigIntBridge = record helper for UBigInt
    function toBigInt: BigInt;
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
    // one leading digit (-1.2345E2)
    function toString: string;
    function toScientific: string;
    // exact conversions (raise ERangeError unless integral and in range;
    // use trunc/floor/ceil/round for the lossy ones)
    function toInt64: Int64;
    function toQWord: QWord;
    function toInteger: LongInt;
    function toCardinal: LongWord;
    function toBigInt: BigInt;
    function fitsInInt64: boolean;
    function fitsInQWord: boolean;
    function fitsInInteger: boolean;
    function fitsInCardinal: boolean;
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
    // comparison helpers
    function compare(const other: BigDecimal): integer;
    function equals(const other: BigDecimal): boolean;
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

function UBigInt.sqr: UBigInt;
begin
  result.fLimbs := LSqr(fLimbs);
end;

function UBigInt.sqrt: UBigInt;
begin
  if Length(fLimbs) = 0 then exit(default(UBigInt));
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
  if (n = 1) or (Length(fLimbs) = 0) or isOne then exit(self);
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
  var n := Length(m.fLimbs);
  var mInv := MontInv(m.fLimbs[0]);
  // base*R mod m, costs one shift and two divisions
  LDivMod(base.fLimbs, m.fLimbs, q, rr);
  bred := LShl(rr, LongWord(n) * LIMB_BITS);
  LDivMod(bred, m.fLimbs, q, baseM);
  SetLength(baseM, n);
  var ebits := e.bitLength;
  var k := if ebits >= 1024 then 6 else if ebits >= 256 then 5 else if ebits >= 64 then 4 else if ebits >= 16 then 3 else if ebits >= 4 then 2 else 1;
  SetLength(t, 2 * n + 1);
  SetLength(table, 1 shl k);
  table[1] := baseM;
  for var j := 2 to (1 shl k) - 1 do begin
    SetLength(table[j], n);
    MontMul(@table[j][0], @table[j - 1][0], @baseM[0], m.fLimbs, mInv, n, t);
  end;
  // scan the exponent top-down in k-bit digits: k squarings then one table mul
  var chunks := (SizeInt(ebits) + k - 1) div k;
  acc := Copy(table[LGetBits(e.fLimbs, LongWord((chunks - 1) * k), k)]);
  for var c := chunks - 2 downto 0 do begin
    for var s := 1 to k do MontMul(@acc[0], @acc[0], @acc[0], m.fLimbs, mInv, n, t);
    var d := LGetBits(e.fLimbs, LongWord(c * k), k);
    if d <> 0 then MontMul(@acc[0], @acc[0], @table[d][0], m.fLimbs, mInv, n, t);
  end;
  // back out of Montgomery form via a multiply by plain 1
  SetLength(oneVec, n);
  oneVec[0] := 1;
  MontMul(@acc[0], @acc[0], @oneVec[0], m.fLimbs, mInv, n, t);
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
var
  f1: UBigInt;
begin
  UFibPair(n, result, f1);
end;

class function UBigInt.lucas(n: LongWord): UBigInt;
var
  fn, fn1: UBigInt;
begin
  // L(n) = 2F(n+1) - F(n)
  UFibPair(n, fn, fn1);
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

function BigInt.sqr: BigInt;
begin
  result.fLimbs := LSqr(fLimbs);
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
  result.fNeg := fNeg and (e and 1 = 1) and (Length(result.fLimbs) > 0);
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

function BigInt.nextPrime: BigInt;
begin
  if fNeg or (Length(fLimbs) = 0) then exit(BigInt(2));
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

function BigInt.modSqrt(const p: BigInt): BigInt;
begin
  if p.sign <= 0 then raise EBigIntError.Create('modulus must be positive');
  result := floorMod(p).toUBigInt.modSqrt(p.toUBigInt).toBigInt;
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

class function BigInt.randomPrime(bits: LongWord; rounds: integer): BigInt;
begin
  result := UBigInt.randomPrime(bits, rounds).toBigInt;
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

class function BigInt.catalan(n: LongWord): BigInt;
begin
  result := UBigInt.catalan(n).toBigInt;
end;

class function BigInt.primorial(n: LongWord): BigInt;
begin
  result := UBigInt.primorial(n).toBigInt;
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

procedure RaiseDecParseError(const s: string);
begin
  raise EConvertError.Create($'"{s}" is not a valid decimal value');
end;

procedure RaiseDecExpRange;
begin
  raise ERangeError.Create('BigDecimal exponent out of range');
end;

function UPow10(n: LongWord): UBigInt;
begin
  if n <= 19 then result.fLimbs := LFromQWord(POW10Q[n])
  else result.fLimbs := UPowQ(LFromQWord(10), n);
end;

// multiply a magnitude by 10^k
function LScale10(const a: TLimbs; k: Int64): TLimbs;
begin
  result := a;
  if (k <= 0) or (Length(a) = 0) then exit;
  if k <= 2 * DEC_CHUNK_POW then begin
    var r := a;
    while k >= DEC_CHUNK_POW do begin
      r := LMulW(r, DEC_CHUNK);
      k := k - DEC_CHUNK_POW;
    end;
    if k > 0 then r := LMulW(r, TLimb(POW10Q[k]));
    result := r;
  end else result := LMul(a, UPow10(LongWord(k)).fLimbs);
end;

// strip trailing decimal zeros of a magnitude, bumping the exponent
procedure LStrip10(var m: TLimbs; var e: Int64);
begin
  while (Length(m) > 0) and (m[0] and 1 = 0) do begin
    var r := LModW(m, DEC_CHUNK);
    var z: integer;
    if r = 0 then z := DEC_CHUNK_POW
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
    if z < DEC_CHUNK_POW then exit;
  end;
end;

// range-checked decimal exponent
function DecExp(e: Int64): integer;
begin
  if (e > High(integer)) or (e < Low(integer)) then RaiseDecExpRange;
  result := integer(e);
end;

// assemble a value: canonical (no trailing zeros) unless it keeps a guard digit
function DecMake(const m: BigInt; e: Int64; hidden: boolean): BigDecimal;
begin
  result.fMan := m;
  result.fHidden := hidden and (Length(m.fLimbs) > 0);
  if Length(m.fLimbs) = 0 then begin
    result.fExp := 0;
    exit;
  end;
  if not result.fHidden then LStrip10(result.fMan.fLimbs, e);
  result.fExp := DecExp(e);
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
procedure DecMagBounds(const m: TLimbs; e: Int64; out lo, hi: Int64);
begin
  var bl := Int64(LBitLen(m));
  lo := (bl - 1) * 1233 div 4096 + e;
  hi := bl * 1233 div 4096 + 1 + e;
end;

function DecCmp(const a, b: BigDecimal): integer;
begin
  var sa := a.fMan.sign;
  var sb := b.fMan.sign;
  if sa <> sb then exit(if sa < sb then -1 else 1);
  if sa = 0 then exit(0);
  // disjoint leading-digit positions decide without aligning
  var loA, hiA, loB, hiB: Int64;
  DecMagBounds(a.fMan.fLimbs, a.fExp, loA, hiA);
  DecMagBounds(b.fMan.fLimbs, b.fExp, loB, hiB);
  var c: integer;
  if hiA < loB then c := -1
  else if hiB < loA then c := 1
  else begin
    var d := Int64(a.fExp) - b.fExp;
    if d >= 0 then c := LCmp(LScale10(a.fMan.fLimbs, d), b.fMan.fLimbs)
    else c := LCmp(a.fMan.fLimbs, LScale10(b.fMan.fLimbs, -d));
  end;
  result := if sa < 0 then -c else c;
end;

function DecAddSub(const a, b: BigDecimal; negateB: boolean): BigDecimal;
begin
  if Length(b.fMan.fLimbs) = 0 then exit(a);
  if Length(a.fMan.fLimbs) = 0 then begin
    result := b;
    if negateB then result.fMan := -result.fMan;
    exit;
  end;
  // align both mantissas to the smaller exponent
  var e := if Int64(a.fExp) < b.fExp then Int64(a.fExp) else Int64(b.fExp);
  var am := LScale10(a.fMan.fLimbs, Int64(a.fExp) - e);
  var bm := LScale10(b.fMan.fLimbs, Int64(b.fExp) - e);
  result := DecMake(SAddPair(am, a.fMan.fNeg, bm, b.fMan.fNeg xor negateB), e, a.fHidden or b.fHidden);
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
  result := DecMake(SMulPair(a.fMan.fLimbs, a.fMan.fNeg, b.fMan.fLimbs, b.fMan.fNeg), Int64(a.fExp) + b.fExp, a.fHidden or b.fHidden);
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

function BigDecimal.toString: string;
var
  m: TLimbs;
  e: Int64;
begin
  DecDisplay(self, m, e);
  if Length(m) = 0 then exit('0');
  var digits := LToBase(m, 10);
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
  var digits := LToBase(m, 10);
  var l := Length(digits);
  var rest := if l > 1 then Copy(digits, 2, l - 1) else '0';
  result := digits[1] + '.' + rest + 'E' + IntToStr(e + l - 1);
  if fMan.fNeg then result := '-' + result;
end;

function BigDecimal.toInt64: Int64;
begin
  result := toBigInt.toInt64;
end;

function BigDecimal.toQWord: QWord;
begin
  result := toBigInt.toQWord;
end;

function BigDecimal.toInteger: LongInt;
begin
  result := toBigInt.toInteger;
end;

function BigDecimal.toCardinal: LongWord;
begin
  result := toBigInt.toCardinal;
end;

function BigDecimal.toBigInt: BigInt;
begin
  if not isIntegral then raise ERangeError.Create('BigDecimal value is not integral');
  result := trunc;
end;

function BigDecimal.fitsInInt64: boolean;
begin
  result := isIntegral and trunc.fitsInInt64;
end;

function BigDecimal.fitsInQWord: boolean;
begin
  result := isIntegral and trunc.fitsInQWord;
end;

function BigDecimal.fitsInInteger: boolean;
begin
  result := isIntegral and trunc.fitsInInteger;
end;

function BigDecimal.fitsInCardinal: boolean;
begin
  result := isIntegral and trunc.fitsInCardinal;
end;

function BigDecimal.isZero: boolean;
begin
  result := Length(fMan.fLimbs) = 0;
end;

function BigDecimal.isOne: boolean;
var
  m: TLimbs;
  e: Int64;
begin
  if fMan.fNeg then exit(false);
  DecCanon(self, m, e);
  result := (e = 0) and (Length(m) = 1) and (m[0] = 1);
end;

function BigDecimal.isIntegral: boolean;
var
  m: TLimbs;
  e: Int64;
begin
  if fExp >= 0 then exit(true);
  DecCanon(self, m, e);
  result := (Length(m) = 0) or (e >= 0);
end;

function BigDecimal.isEven: boolean;
var
  m: TLimbs;
  e: Int64;
begin
  DecCanon(self, m, e);
  if e > 0 then exit(true);
  if e < 0 then exit(false);
  result := (Length(m) = 0) or (m[0] and 1 = 0);
end;

function BigDecimal.isOdd: boolean;
var
  m: TLimbs;
  e: Int64;
begin
  DecCanon(self, m, e);
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
    var q, r: TLimbs;
    LDivMod(fMan.fLimbs, UPow10(LongWord(-Int64(fExp))).fLimbs, q, r);
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
  var q, r: TLimbs;
  LDivMod(fMan.fLimbs, UPow10(LongWord(-Int64(fExp))).fLimbs, q, r);
  var m: BigInt;
  m.fLimbs := r;
  m.fNeg := fMan.fNeg and (Length(r) > 0);
  result := DecMake(m, fExp, false);
end;

function BigDecimal.precision: integer;
var
  m: TLimbs;
  e: Int64;
begin
  DecCanon(self, m, e);
  if Length(m) = 0 then exit(0);
  result := integer(Length(LToBase(m, 10)));
end;

function BigDecimal.mostSignificantExponent: integer;
var
  m: TLimbs;
  e: Int64;
begin
  DecCanon(self, m, e);
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
    p10 := UPow10(LongWord(delta)).fLimbs;
    LDivMod(fMan.fLimbs, p10, qm, rm);
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
  m.fNeg := neg and (Length(m.fLimbs) > 0);
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
  var ms := (Int64(LBitLen(fMan.fLimbs)) - LBitLen(other.fMan.fLimbs) - 1) * 1233;
  ms := (if ms >= 0 then ms div 4096 else -((-ms + 4095) div 4096)) + fExp - other.fExp;
  var er := -Int64(precision);
  if fExp < er then er := fExp;
  if other.fExp < er then er := other.fExp;
  if ms - precision + 1 < er then er := ms - precision + 1;
  er := er - 1;
  var t := Int64(fExp) - other.fExp - er;
  var n, dm: TLimbs;
  if t >= 0 then begin
    n := LScale10(fMan.fLimbs, t);
    dm := other.fMan.fLimbs;
  end else begin
    n := fMan.fLimbs;
    dm := LScale10(other.fMan.fLimbs, -t);
  end;
  var q, r: TLimbs;
  LDivMod(n, dm, q, r);
  var m: BigInt;
  m.fLimbs := q;
  m.fNeg := (fMan.fNeg xor other.fMan.fNeg) and (Length(q) > 0);
  result := DecMake(m, er, Length(r) > 0);
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
  SetLength(digits, count);
  var m: BigInt;
  m.fLimbs := LFromDigits(digits, 10);
  m.fNeg := neg and (Length(m.fLimbs) > 0);
  var e := expPart - fracDigits;
  LStrip10(m.fLimbs, e);
  if Length(m.fLimbs) = 0 then e := 0;
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
    var dv := byte(d.toQWord);
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
  if Length(a.fMan.fLimbs) = 0 then exit(0.0);
  var sgn: Extended := if a.fMan.fNeg then -1.0 else 1.0;
  var lo, hi: Int64;
  DecMagBounds(a.fMan.fLimbs, a.fExp, lo, hi);
  // decimal guards keep absurd exponents from materializing huge powers
  if lo > 4940 then exit(sgn * Infinity);
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
      if vexp + 1 > emax then exit(sgn * Infinity);
      exit(sgn * ldexp(2.0, integer(vexp)));
    end;
    inc(keep);
  end;
  if keep = 0 then exit(sgn * 0.0);
  var fe := vexp - targetP + 1;
  if Int64(BsrQWord(keep)) + fe > emax then exit(sgn * Infinity);
  result := sgn * ldexp(Extended(keep), integer(fe));
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
var
  m: TLimbs;
  e: Int64;
begin
  DecCanon(self, m, e);
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
  result.fNeg := a.fMan.fNeg and (Length(result.fLimbs) > 0);
end;

// wrap a scaled result: v * 10^-w cut to p fractional digits (or p
// significant digits for small values) plus the hidden guard digit
function DecFromScaled(const v: BigInt; w: Int64; p: integer): BigDecimal;
begin
  if Length(v.fLimbs) = 0 then exit(default(BigDecimal));
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
  m.fNeg := v.fNeg and (Length(m.fLimbs) > 0);
  result := DecMake(m, er, true);
end;

// cut an already computed value down to `p` fractional digits the same way
function DecGuardCut(const a: BigDecimal; p: integer): BigDecimal;
begin
  if (Length(a.fMan.fLimbs) = 0) or (a.fExp >= 0) then exit(a);
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
  if Length(X.fLimbs) = 0 then exit(p10);
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
  DecMagBounds(fMan.fLimbs, fExp, lo, hi);
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
  var m: TLimbs;
  var e: Int64;
  DecCanon(self, m, e);
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
  r.fNeg := zneg and (Length(r.fLimbs) > 0);
  if j2 <> 0 then r := r + BigInt(Int64(j2)) * Ln2Scaled(w).toBigInt;
  if f <> 0 then r := r + BigInt(f) * Ln10Scaled(w).toBigInt;
  result := DecFromScaled(r, w, p);
end;

function BigDecimal.log2(precision: integer): BigDecimal;
begin
  var p := precision;
  if p < 0 then p := 0;
  if fMan.fNeg or fMan.isZero then raise EBigIntError.Create('logarithm of a non-positive value');
  var m: TLimbs;
  var e: Int64;
  DecCanon(self, m, e);
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
  q.fNeg := lnr.fNeg and (Length(q.fLimbs) > 0);
  result := DecFromScaled(q, w, p);
end;

function BigDecimal.log10(precision: integer): BigDecimal;
begin
  var p := precision;
  if p < 0 then p := 0;
  if fMan.fNeg or fMan.isZero then raise EBigIntError.Create('logarithm of a non-positive value');
  var m: TLimbs;
  var e: Int64;
  DecCanon(self, m, e);
  // exact powers of ten
  if (Length(m) = 1) and (m[0] = 1) then begin
    result := BFromI64(e);
    exit;
  end;
  var w := Int64(p) + 20;
  var lnr := DecToScaled(ln(p + 12), w);
  var q: BigInt;
  q.fLimbs := (lnr.magnitude * UPow10(LongWord(w)) div Ln10Scaled(w)).fLimbs;
  q.fNeg := lnr.fNeg and (Length(q.fLimbs) > 0);
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
  if IsNan(zd) or (zd > 4.6E9) then RaiseDecExpRange;
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
  m.fNeg := fMan.fNeg and (Length(root.fLimbs) > 0);
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
  DecMagBounds(a.fMan.fLimbs, a.fExp, lo, hi);
  var wred := w + 8;
  if hi > 0 then wred := wred + hi;
  var xu: UBigInt;
  xu.fLimbs := DecToScaled(a, wred).fLimbs;
  var ph := PiScaled(wred) div 2;
  var q := (xu * 2 + ph) div (ph * 2);
  var rb := xu.toBigInt - (q * ph).toBigInt;
  quad := integer(LModW(q.fLimbs, 4));
  r.fLimbs := UScaleDown(rb.magnitude, wred - w).fLimbs;
  r.fNeg := rb.fNeg and (Length(r.fLimbs) > 0);
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
  sinS.fNeg := r.fNeg and (Length(s.fLimbs) > 0);
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
    v.fNeg := Length(cc.fLimbs) > 0;
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
      v.fNeg := Length(cc.fLimbs) > 0;
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
    v.fNeg := ss.fNeg and (Length(v.fLimbs) > 0);
  end else begin
    // tan(pi/2 + r) = -cos r / sin r
    if ss.isZero then raise EBigIntError.Create('tangent pole');
    v.fLimbs := (cc * p10 div ss.magnitude).fLimbs;
    v.fNeg := not ss.fNeg and (Length(v.fLimbs) > 0);
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
    v.fNeg := fMan.fNeg and (Length(s.fLimbs) > 0);
    exit(DecFromScaled(v, w, p));
  end;
  // (e^x - e^-x) / 2
  var lo, hi: Int64;
  DecMagBounds(fMan.fLimbs, fExp, lo, hi);
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
  DecMagBounds(fMan.fLimbs, fExp, lo, hi);
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
    v.fNeg := fMan.fNeg and (Length(v.fLimbs) > 0);
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

{$ifdef BIGINT_ASM}
initialization
  UseAdx := CpuHasAdx;
{$endif}
end.
  UseAdx := CpuHasAdx;
{$endif}
end.
