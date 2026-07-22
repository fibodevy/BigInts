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
  W_NAME = 20;
  W_TIME = 13;
  W_RATIO = 8;

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
          StringOfChar('-', W_TIME + 2), '+', StringOfChar('-', W_RATIO + 2), '+');
end;

procedure Cells(const name, c1, c2, c3: string);
begin
  writeln('| ', PadR(name, W_NAME), ' | ', PadL(c1, W_TIME), ' | ', PadL(c2, W_TIME), ' | ', PadL(c3, W_RATIO), ' |');
end;

// always microseconds so a column never mixes units (ns vs ms reads wrong at
// a glance); 3 decimals keep sub-microsecond ops legible
function FmtNs(ns: Double): string;
begin
  result := Format('%.3f us', [ns / 1e3]);
end;

procedure Row(const name: string; const ourOp, gmpOp: TOp);
begin
  var ours := BenchNs(ourOp);
  var g := BenchNs(gmpOp);
  Cells(name, FmtNs(ours), FmtNs(g), Format('%.1fx', [ours / g]));
end;

// random value with exactly the requested bit length
function RandExact(bits: LongWord): UBigInt;
begin
  result := UBigInt.random(bits);
  result.setBit(bits - 1);
end;

// ---------------------------------------------------------------------------
// benchmark sections
// ---------------------------------------------------------------------------

const
  addSizes: array[4] of LongWord = (128, 1024, 16384, 262144);
  mulSizes: array[5] of LongWord = (128, 1024, 8192, 65536, 262144);
  sqrSizes: array[2] of LongWord = (8192, 65536);
  strSizes: array[2] of LongWord = (4096, 65536);
  powSizes: array[3] of LongWord = (512, 1024, 2048);
  gcdSizes: array[2] of LongWord = (1024, 16384);

var
  gr, gq, gm: mpz_t; // shared gmp result slots

procedure BenchAdd(bits: LongWord);
var
  za, zb: mpz_t;
begin
  var a := RandExact(bits);
  var b := RandExact(bits);
  mpz_init(za); mpz_init(zb);
  mpzFromU(za, a); mpzFromU(zb, b);
  Row($'add {bits}b',
    procedure(n: Int64) begin for var i: Int64 := 1 to n do sink := sink xor (a + b).bitLength; end,
    procedure(n: Int64) begin for var i: Int64 := 1 to n do mpz_add(gr, za, zb); end);
  mpz_clear(za); mpz_clear(zb);
end;

procedure BenchMul(abits, bbits: LongWord);
var
  za, zb: mpz_t;
begin
  var a := RandExact(abits);
  var b := RandExact(bbits);
  mpz_init(za); mpz_init(zb);
  mpzFromU(za, a); mpzFromU(zb, b);
  Row(if abits = bbits then $'mul {abits}b' else $'mul {abits}x{bbits}b',
    procedure(n: Int64) begin for var i: Int64 := 1 to n do sink := sink xor (a * b).bitLength; end,
    procedure(n: Int64) begin for var i: Int64 := 1 to n do mpz_mul(gr, za, zb); end);
  mpz_clear(za); mpz_clear(zb);
end;

procedure BenchSqr(bits: LongWord);
var
  za: mpz_t;
begin
  var a := RandExact(bits);
  mpz_init(za);
  mpzFromU(za, a);
  Row($'sqr {bits}b',
    procedure(n: Int64) begin for var i: Int64 := 1 to n do sink := sink xor a.sqr.bitLength; end,
    procedure(n: Int64) begin for var i: Int64 := 1 to n do mpz_mul(gr, za, za); end);
  mpz_clear(za);
end;

procedure BenchDiv(nbits, dbits: LongWord);
var
  zn, zd: mpz_t;
begin
  var nv := RandExact(nbits);
  var dv := RandExact(dbits);
  mpz_init(zn); mpz_init(zd);
  mpzFromU(zn, nv); mpzFromU(zd, dv);
  Row($'divmod {nbits}/{dbits}b',
    procedure(n: Int64) begin for var i: Int64 := 1 to n do begin var (q, r) := nv.divMod(dv); sink := sink xor q.bitLength xor r.bitLength; end; end,
    procedure(n: Int64) begin for var i: Int64 := 1 to n do mpz_tdiv_qr(gq, gr, zn, zd); end);
  mpz_clear(zn); mpz_clear(zd);
end;

procedure BenchToString(bits: LongWord);
var
  za: mpz_t;
begin
  var a := RandExact(bits);
  mpz_init(za);
  mpzFromU(za, a);
  var buf: AnsiString;
  SetLength(buf, mpz_sizeinbase(za, 10) + 2);
  Row($'toString {bits}b',
    procedure(n: Int64) begin for var i: Int64 := 1 to n do sink := sink xor LongWord(Length(a.toString)); end,
    procedure(n: Int64) begin for var i: Int64 := 1 to n do mpz_get_str(PAnsiChar(buf), 10, za); end);
  mpz_clear(za);
end;

procedure BenchParse(bits: LongWord);
begin
  var s := RandExact(bits).toString;
  Row($'parse {bits}b',
    procedure(n: Int64) begin for var i: Int64 := 1 to n do sink := sink xor UBigInt.parse(s).bitLength; end,
    procedure(n: Int64) begin for var i: Int64 := 1 to n do mpz_set_str(gr, PAnsiChar(s), 10); end);
end;

procedure BenchModPow(bits: LongWord);
var
  zb, ze, zm: mpz_t;
begin
  var base := RandExact(bits);
  var e := RandExact(bits);
  var m := RandExact(bits);
  m.setBit(0); // odd modulus
  mpz_init(zb); mpz_init(ze); mpz_init(zm);
  mpzFromU(zb, base); mpzFromU(ze, e); mpzFromU(zm, m);
  Row($'modPow {bits}b',
    procedure(n: Int64) begin for var i: Int64 := 1 to n do sink := sink xor base.modPow(e, m).bitLength; end,
    procedure(n: Int64) begin for var i: Int64 := 1 to n do mpz_powm(gr, zb, ze, zm); end);
  mpz_clear(zb); mpz_clear(ze); mpz_clear(zm);
end;

procedure BenchGcd(bits: LongWord);
var
  za, zb: mpz_t;
begin
  var a := RandExact(bits);
  var b := RandExact(bits);
  mpz_init(za); mpz_init(zb);
  mpzFromU(za, a); mpzFromU(zb, b);
  Row($'gcd {bits}b',
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
  Sep;
  Cells('operation', 'BigInts', 'GMP', 'ratio');
  Sep;
  RandSeed := 42;
  for var bits in addSizes do BenchAdd(bits);
  for var bits in mulSizes do BenchMul(bits, bits);
  BenchMul(65536, 1024);
  for var bits in sqrSizes do BenchSqr(bits);
  BenchDiv(2048, 1024);
  BenchDiv(8192, 4096);
  BenchDiv(131072, 65536);
  for var bits in strSizes do BenchToString(bits);
  for var bits in strSizes do BenchParse(bits);
  for var bits in powSizes do BenchModPow(bits);
  for var bits in gcdSizes do BenchGcd(bits);
  Sep;

  writeln;
  writeln($'(sink = {sink})');
end.
