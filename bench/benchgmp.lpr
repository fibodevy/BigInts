program benchgmp;

// head-to-head benchmark: bigints.pas vs GMP (libgmp-10.dll loaded dynamically)

{$mode unleashed}

uses
  Windows, SysUtils, Math, bigints;

// ---------------------------------------------------------------------------
// minimal GMP binding (only what the benchmark needs)
// ---------------------------------------------------------------------------

type
  mpz_t = record
    alloc: LongInt;
    size: LongInt;
    d: Pointer;
  end;

var
  gmpLib: HMODULE = 0;
  gmpVersion: PAnsiChar = nil;
  gmpBitsPerLimb: LongInt = 0;
  mpz_init: procedure(var x: mpz_t); cdecl;
  mpz_clear: procedure(var x: mpz_t); cdecl;
  mpz_add: procedure(var r: mpz_t; constref a, b: mpz_t); cdecl;
  mpz_sub: procedure(var r: mpz_t; constref a, b: mpz_t); cdecl;
  mpz_mul: procedure(var r: mpz_t; constref a, b: mpz_t); cdecl;
  mpz_tdiv_q: procedure(var q: mpz_t; constref n, d: mpz_t); cdecl;
  mpz_tdiv_qr: procedure(var q, r: mpz_t; constref n, d: mpz_t); cdecl;
  mpz_powm: procedure(var r: mpz_t; constref b, e, m: mpz_t); cdecl;
  mpz_gcd: procedure(var r: mpz_t; constref a, b: mpz_t); cdecl;
  mpz_set_str: function(var x: mpz_t; s: PAnsiChar; base: LongInt): LongInt; cdecl;
  mpz_get_str: function(buf: PAnsiChar; base: LongInt; constref x: mpz_t): PAnsiChar; cdecl;
  mpz_sizeinbase: function(constref x: mpz_t; base: LongInt): SizeUInt; cdecl;
  mpz_import: procedure(var r: mpz_t; count: SizeUInt; order: LongInt; size: SizeUInt; endian: LongInt; nails: SizeUInt; op: Pointer); cdecl;

function Bind(const name: string): Pointer;
begin
  result := GetProcAddress(gmpLib, PAnsiChar(AnsiString(name)));
  if result = nil then begin
    writeln('missing GMP export: ', name);
    halt(2);
  end;
end;

function LoadGmp: boolean;
const
  candidates: array[2] of string = ('libgmp-10.dll', 'C:\Program Files\Git\mingw64\bin\libgmp-10.dll');
begin
  for var c in candidates do begin
    gmpLib := LoadLibraryExW(PWideChar(UnicodeString(c)), 0, LOAD_WITH_ALTERED_SEARCH_PATH);
    if gmpLib <> 0 then break;
  end;
  if gmpLib = 0 then exit(false);
  gmpVersion := PPAnsiChar(Bind('__gmp_version'))^;
  gmpBitsPerLimb := PLongInt(Bind('__gmp_bits_per_limb'))^;
  Pointer(mpz_init) := Bind('__gmpz_init');
  Pointer(mpz_clear) := Bind('__gmpz_clear');
  Pointer(mpz_add) := Bind('__gmpz_add');
  Pointer(mpz_sub) := Bind('__gmpz_sub');
  Pointer(mpz_mul) := Bind('__gmpz_mul');
  Pointer(mpz_tdiv_q) := Bind('__gmpz_tdiv_q');
  Pointer(mpz_tdiv_qr) := Bind('__gmpz_tdiv_qr');
  Pointer(mpz_powm) := Bind('__gmpz_powm');
  Pointer(mpz_gcd) := Bind('__gmpz_gcd');
  Pointer(mpz_set_str) := Bind('__gmpz_set_str');
  Pointer(mpz_get_str) := Bind('__gmpz_get_str');
  Pointer(mpz_sizeinbase) := Bind('__gmpz_sizeinbase');
  Pointer(mpz_import) := Bind('__gmpz_import');
  result := true;
end;

// load a UBigInt value into an initialized mpz via byte import
procedure mpzFromU(var z: mpz_t; const u: UBigInt);
begin
  var bytes := u.toBytesLE;
  if Length(bytes) = 0 then mpz_set_str(z, '0', 10)
  else mpz_import(z, Length(bytes), -1, 1, 0, 0, @bytes[0]);
end;

function mpzToHex(constref z: mpz_t): string;
begin
  var buf: AnsiString;
  SetLength(buf, mpz_sizeinbase(z, 16) + 2);
  mpz_get_str(PAnsiChar(buf), 16, z);
  result := UpperCase(string(PAnsiChar(buf)));
end;

// ---------------------------------------------------------------------------
// timing harness
// ---------------------------------------------------------------------------

type
  TOp = reference to procedure(n: Int64);

var
  qpcFreq: Int64;
  sink: LongWord = 0;

// run op with growing iteration counts until it takes long enough, return ns/iteration
function BenchNs(const op: TOp): Double;
begin
  var n: Int64 := 1;
  repeat
    var t0, t1: Int64;
    QueryPerformanceCounter(t0);
    op(n);
    QueryPerformanceCounter(t1);
    var secs := (t1 - t0) / qpcFreq;
    if (secs >= 0.10) or (n >= 100000000) then exit(secs / n * 1e9);
    n := if secs < 0.005 then n * 10 else Max(n + 1, Round(n * 0.14 / secs));
  until false;
end;

const
  W_TIME = 32;
  W_RATIO = 8;
  W_RAM = 10;

var
  W_NAME: integer = 24; // widest operation label; set at startup

function PadL(const s: string; w: integer): string;
begin
  result := s;
  while Length(result) < w do result := ' ' + result;
end;

function PadR(const s: string; w: integer): string;
begin
  result := s;
  while Length(result) < w do result := result + ' ';
end;

procedure Sep;
begin
  writeln('+', StringOfChar('-', W_NAME + 2), '+', StringOfChar('-', W_TIME + 2), '+',
          StringOfChar('-', W_TIME + 2), '+', StringOfChar('-', W_RATIO + 2), '+', StringOfChar('-', W_RAM + 2), '+');
end;

procedure Cells(const name, c1, c2, c3, c4: string);
begin
  writeln('| ', PadR(name, W_NAME), ' | ', PadL(c1, W_TIME), ' | ', PadL(c2, W_TIME), ' | ', PadL(c3, W_RATIO), ' | ', PadL(c4, W_RAM), ' |');
end;

// always microseconds so a column never mixes units (ns vs ms reads wrong at
// a glance); 3 decimals keep sub-microsecond ops legible. the seconds twin on
// the right (integer part space-padded to 3, fraction zero-padded to 3) makes
// the slow rows readable without unit juggling
function FmtNs(ns: Double): string;
begin
  result := Format('%.3f us / %7.3f s', [ns / 1e3, ns / 1e9]);
end;

// FPC heap in use right now (our side only; GMP allocates through its own C
// heap and is invisible here). sampled per row with the operands still live,
// so it reads as the operand footprint for that size
function RamStr: string;
begin
  var b := Double(GetFPCHeapStatus.CurrHeapUsed);
  if b >= 1024*1024*1024 then result := Format('%.2f GB', [b / (1024*1024*1024)])
  else if b >= 1024*1024 then result := Format('%.1f MB', [b / (1024*1024)])
  else result := Format('%.0f KB', [b / 1024]);
end;

procedure Row(const name: string; const ourOp, gmpOp: TOp);
begin
  var ours := BenchNs(ourOp);
  var g := BenchNs(gmpOp);
  Cells(name, FmtNs(ours), FmtNs(g), Format('%.1fx', [ours / g]), RamStr);
end;

// random value with exactly the requested bit length
function RandExact(bits: LongWord): UBigInt;
begin
  result := UBigInt.random(bits);
  result.setBit(bits - 1);
end;

// decimal-digit count needed to size an operand: bits = ceil(digits*log2(10))
function DigitsToBits(digits: LongWord): LongWord;
begin
  result := LongWord(Trunc(digits*3.3219280948873623)) + 1;
end;

// row tag for a digit count: fold whole thousands/millions/billions into
// K/M/B, raw number otherwise
function SizeTag(digits: LongWord): string;
begin
  if (digits >= 1000000000) and (digits mod 1000000000 = 0) then exit(IntToStr(digits div 1000000000)+'B');
  if (digits >= 1000000) and (digits mod 1000000 = 0) then exit(IntToStr(digits div 1000000)+'M');
  if (digits >= 1000) and (digits mod 1000 = 0) then exit(IntToStr(digits div 1000)+'K');
  result := IntToStr(digits);
end;

// ---------------------------------------------------------------------------
// benchmark sections
// ---------------------------------------------------------------------------

const
  // sizes are decimal-digit counts on a shared axis: 128, 1024, 16384,
  // 262144, then 1/10/100 million and a billion. the sub-million rungs sit in
  // every op; the large ones only reach as far as the op already did, never
  // extended past its range (GMP's 32-bit mp_size_t caps mul/div at 100
  // million and sqr at 10 million, modPow/gcd stay small)
  addSizes: array[8] of LongWord = (128, 1024, 16384, 262144, 1000000, 10000000, 100000000, 1000000000);
  mulSizes: array[7] of LongWord = (128, 1024, 16384, 262144, 1000000, 10000000, 100000000);
  sqrSizes: array[6] of LongWord = (128, 1024, 16384, 262144, 1000000, 10000000);
  divSizes: array[7] of LongWord = (128, 1024, 16384, 262144, 1000000, 10000000, 100000000);
  strSizes: array[4] of LongWord = (128, 1024, 16384, 262144);
  powSizes: array[3] of LongWord = (128, 1024, 16384);
  gcdSizes: array[5] of LongWord = (128, 1024, 16384, 262144, 1000000);

var
  gr, gq, gm: mpz_t; // shared gmp result slots

// widest operation label across every row, so the name column never overflows;
// the div/divmod pair rows at the top sizes are the longest
function LabelWidth: integer;
  procedure bump(const s: string);
  begin
    if Length(s) > result then result := Length(s);
  end;
begin
  result := Length('operation');
  for var d in addSizes do begin
    bump($'add ({SizeTag(d)} digits)'); bump($'addTo ({SizeTag(d)} digits)');
    bump($'sub ({SizeTag(d)} digits)'); bump($'subTo ({SizeTag(d)} digits)');
  end;
  for var d in mulSizes do bump($'mul ({SizeTag(d)} digits)');
  bump($'mul ({SizeTag(100000)}x{SizeTag(1000)} digits)');
  for var d in sqrSizes do bump($'sqr ({SizeTag(d)} digits)');
  for var d in divSizes do begin
    bump($'div ({SizeTag(d)} / {SizeTag(d div 2)} digits)');
    bump($'divmod ({SizeTag(d)} / {SizeTag(d div 2)} digits)');
  end;
  for var d in strSizes do begin bump($'toString ({SizeTag(d)} digits)'); bump($'parse ({SizeTag(d)} digits)'); end;
  for var d in powSizes do bump(if d >= 16384 then $'modPow ({SizeTag(d)} digits, 4k-bit e)' else $'modPow ({SizeTag(d)} digits)');
  for var d in gcdSizes do bump($'gcd ({SizeTag(d)} digits)');
end;

procedure BenchAdd(digits: LongWord);
var
  za, zb: mpz_t;
begin
  var a := RandExact(DigitsToBits(digits));
  var b := RandExact(DigitsToBits(digits));
  mpz_init(za); mpz_init(zb);
  mpzFromU(za, a); mpzFromU(zb, b);
  Row($'add ({SizeTag(digits)} digits)',
    procedure(n: Int64) begin for var i: Int64 := 1 to n do sink := sink xor (a + b).bitLength; end,
    procedure(n: Int64) begin for var i: Int64 := 1 to n do mpz_add(gr, za, zb); end);
  mpz_clear(za); mpz_clear(zb);
end;

procedure BenchSub(digits: LongWord);
var
  za, zb: mpz_t;
begin
  var a := RandExact(DigitsToBits(digits));
  var b := RandExact(DigitsToBits(digits));
  if a < b then begin var t := a; a := b; b := t; end;
  mpz_init(za); mpz_init(zb);
  mpzFromU(za, a); mpzFromU(zb, b);
  Row($'sub ({SizeTag(digits)} digits)',
    procedure(n: Int64) begin for var i: Int64 := 1 to n do sink := sink xor (a - b).bitLength; end,
    procedure(n: Int64) begin for var i: Int64 := 1 to n do mpz_sub(gr, za, zb); end);
  mpz_clear(za); mpz_clear(zb);
end;

// in-place addTo/subTo against the same mpz calls, which are in-place on the
// GMP side already; r persists across iterations so its buffer gets reused
procedure BenchAddTo(digits: LongWord);
var
  za, zb: mpz_t;
  r: UBigInt;
begin
  var a := RandExact(DigitsToBits(digits));
  var b := RandExact(DigitsToBits(digits));
  mpz_init(za); mpz_init(zb);
  mpzFromU(za, a); mpzFromU(zb, b);
  Row($'addTo ({SizeTag(digits)} digits)',
    procedure(n: Int64) begin for var i: Int64 := 1 to n do begin addTo(r, a, b); sink := sink xor r.bitLength; end; end,
    procedure(n: Int64) begin for var i: Int64 := 1 to n do mpz_add(gr, za, zb); end);
  mpz_clear(za); mpz_clear(zb);
end;

procedure BenchSubTo(digits: LongWord);
var
  za, zb: mpz_t;
  r: UBigInt;
begin
  var a := RandExact(DigitsToBits(digits));
  var b := RandExact(DigitsToBits(digits));
  if a < b then begin var t := a; a := b; b := t; end;
  mpz_init(za); mpz_init(zb);
  mpzFromU(za, a); mpzFromU(zb, b);
  Row($'subTo ({SizeTag(digits)} digits)',
    procedure(n: Int64) begin for var i: Int64 := 1 to n do begin subTo(r, a, b); sink := sink xor r.bitLength; end; end,
    procedure(n: Int64) begin for var i: Int64 := 1 to n do mpz_sub(gr, za, zb); end);
  mpz_clear(za); mpz_clear(zb);
end;

procedure BenchMul(adigits, bdigits: LongWord);
var
  za, zb: mpz_t;
begin
  var a := RandExact(DigitsToBits(adigits));
  var b := RandExact(DigitsToBits(bdigits));
  mpz_init(za); mpz_init(zb);
  mpzFromU(za, a); mpzFromU(zb, b);
  Row(if adigits = bdigits then $'mul ({SizeTag(adigits)} digits)' else $'mul ({SizeTag(adigits)}x{SizeTag(bdigits)} digits)',
    procedure(n: Int64) begin for var i: Int64 := 1 to n do sink := sink xor (a * b).bitLength; end,
    procedure(n: Int64) begin for var i: Int64 := 1 to n do mpz_mul(gr, za, zb); end);
  mpz_clear(za); mpz_clear(zb);
end;

procedure BenchSqr(digits: LongWord);
var
  za: mpz_t;
begin
  var a := RandExact(DigitsToBits(digits));
  mpz_init(za);
  mpzFromU(za, a);
  Row($'sqr ({SizeTag(digits)} digits)',
    procedure(n: Int64) begin for var i: Int64 := 1 to n do sink := sink xor a.sqr.bitLength; end,
    procedure(n: Int64) begin for var i: Int64 := 1 to n do mpz_mul(gr, za, za); end);
  mpz_clear(za);
end;

procedure BenchDivQ(ndigits, ddigits: LongWord);
var
  zn, zd: mpz_t;
begin
  var nv := RandExact(DigitsToBits(ndigits));
  var dv := RandExact(DigitsToBits(ddigits));
  mpz_init(zn); mpz_init(zd);
  mpzFromU(zn, nv); mpzFromU(zd, dv);
  Row($'div ({SizeTag(ndigits)} / {SizeTag(ddigits)} digits)',
    procedure(n: Int64) begin for var i: Int64 := 1 to n do sink := sink xor (nv div dv).bitLength; end,
    procedure(n: Int64) begin for var i: Int64 := 1 to n do mpz_tdiv_q(gq, zn, zd); end);
  mpz_clear(zn); mpz_clear(zd);
end;

procedure BenchDiv(ndigits, ddigits: LongWord);
var
  zn, zd: mpz_t;
begin
  var nv := RandExact(DigitsToBits(ndigits));
  var dv := RandExact(DigitsToBits(ddigits));
  mpz_init(zn); mpz_init(zd);
  mpzFromU(zn, nv); mpzFromU(zd, dv);
  Row($'divmod ({SizeTag(ndigits)} / {SizeTag(ddigits)} digits)',
    procedure(n: Int64) begin for var i: Int64 := 1 to n do begin var (q, r) := nv.divMod(dv); sink := sink xor q.bitLength xor r.bitLength; end; end,
    procedure(n: Int64) begin for var i: Int64 := 1 to n do mpz_tdiv_qr(gq, gr, zn, zd); end);
  mpz_clear(zn); mpz_clear(zd);
end;

procedure BenchToString(digits: LongWord);
var
  za: mpz_t;
begin
  var a := RandExact(DigitsToBits(digits));
  mpz_init(za);
  mpzFromU(za, a);
  var buf: AnsiString;
  SetLength(buf, mpz_sizeinbase(za, 10) + 2);
  Row($'toString ({SizeTag(digits)} digits)',
    procedure(n: Int64) begin for var i: Int64 := 1 to n do sink := sink xor LongWord(Length(a.toString)); end,
    procedure(n: Int64) begin for var i: Int64 := 1 to n do mpz_get_str(PAnsiChar(buf), 10, za); end);
  mpz_clear(za);
end;

procedure BenchParse(digits: LongWord);
begin
  var s := RandExact(DigitsToBits(digits)).toString;
  Row($'parse ({SizeTag(digits)} digits)',
    procedure(n: Int64) begin for var i: Int64 := 1 to n do sink := sink xor UBigInt.parse(s).bitLength; end,
    procedure(n: Int64) begin for var i: Int64 := 1 to n do mpz_set_str(gr, PAnsiChar(s), 10); end);
end;

procedure BenchModPow(digits: LongWord);
var
  zb, ze, zm: mpz_t;
begin
  var base := RandExact(DigitsToBits(digits));
  // a full-size exponent makes the ladder length quadratic in the size; the
  // big rows cap it at 4096 bits so they measure the modular products
  var e := RandExact(if digits >= 16384 then 4096 else DigitsToBits(digits));
  var m := RandExact(DigitsToBits(digits));
  m.setBit(0); // odd modulus
  mpz_init(zb); mpz_init(ze); mpz_init(zm);
  mpzFromU(zb, base); mpzFromU(ze, e); mpzFromU(zm, m);
  Row(if digits >= 16384 then $'modPow ({SizeTag(digits)} digits, 4k-bit e)' else $'modPow ({SizeTag(digits)} digits)',
    procedure(n: Int64) begin for var i: Int64 := 1 to n do sink := sink xor base.modPow(e, m).bitLength; end,
    procedure(n: Int64) begin for var i: Int64 := 1 to n do mpz_powm(gr, zb, ze, zm); end);
  mpz_clear(zb); mpz_clear(ze); mpz_clear(zm);
end;

procedure BenchGcd(digits: LongWord);
var
  za, zb: mpz_t;
begin
  var a := RandExact(DigitsToBits(digits));
  var b := RandExact(DigitsToBits(digits));
  mpz_init(za); mpz_init(zb);
  mpzFromU(za, a); mpzFromU(zb, b);
  Row($'gcd ({SizeTag(digits)} digits)',
    procedure(n: Int64) begin for var i: Int64 := 1 to n do sink := sink xor a.gcd(b).bitLength; end,
    procedure(n: Int64) begin for var i: Int64 := 1 to n do mpz_gcd(gr, za, zb); end);
  mpz_clear(za); mpz_clear(zb);
end;

begin
  QueryPerformanceFrequency(qpcFreq);
  if not LoadGmp then begin
    writeln('libgmp-10.dll not found - install Git for Windows or put the DLL on PATH');
    halt(2);
  end;
  writeln($'bigints.pas vs GMP {gmpVersion} ({gmpBitsPerLimb}-bit limbs)');

  // sanity: same product on both sides before trusting any numbers
  RandSeed := 12345;
  var sa := RandExact(1000);
  var sb := RandExact(900);
  var zsa, zsb: mpz_t;
  mpz_init(zsa); mpz_init(zsb); mpz_init(gr); mpz_init(gq); mpz_init(gm);
  mpzFromU(zsa, sa); mpzFromU(zsb, sb);
  mpz_mul(gr, zsa, zsb);
  if (sa * sb).toHex <> mpzToHex(gr) then begin
    writeln('SANITY CHECK FAILED: products differ, binding is broken');
    halt(3);
  end;
  mpz_clear(zsa); mpz_clear(zsb);
  writeln('sanity check ok (1000x900-bit product matches)');
  writeln;

  writeln('(ratio = BigInts / GMP; >1 slower, <1 faster)');
  W_NAME := LabelWidth;
  Sep;
  Cells('operation', 'BigInts', 'GMP', 'ratio', 'RAM used');
  Sep;
  RandSeed := 42;
  for var d in addSizes do BenchAdd(d);
  for var d in addSizes do BenchAddTo(d);
  for var d in addSizes do BenchSub(d);
  for var d in addSizes do BenchSubTo(d);
  for var d in mulSizes do BenchMul(d, d);
  BenchMul(100000, 1000);
  // dividend / half-size divisor; the fast divide keeps the big ones near
  // multiply speed, so they stay in range
  for var d in divSizes do BenchDivQ(d, d div 2);
  for var d in sqrSizes do BenchSqr(d);
  for var d in divSizes do BenchDiv(d, d div 2);
  for var d in strSizes do BenchToString(d);
  for var d in strSizes do BenchParse(d);
  for var d in powSizes do BenchModPow(d);
  for var d in gcdSizes do BenchGcd(d);
  Sep;

  writeln;
  writeln($'(sink = {sink})');
end.
