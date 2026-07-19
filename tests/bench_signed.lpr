program bench_signed;

// signed BigInt benchmark: a negative, b positive (the costliest sign mix for
// bitwise two's complement paths); same RESULT/SINK format as bench.lpr

{$mode unleashed}
{$q-}{$r-}

uses Windows, SysUtils, BigInts;

var
  qpc: Int64;
  sink: QWord = 0;

function clk: Double;
begin
  var t: Int64;
  QueryPerformanceCounter(t);
  result := t / qpc;
end;

// exact nbits magnitude, dense pseudo-random limbs, top bit set
function mkU(nbits: integer; seed: QWord): UBigInt;
begin
  result := 0;
  var need := (nbits + 63) div 64;
  for var i := 1 to need do begin
    seed := seed * 6364136223846793005 + 1442695040888963407;
    result := (result shl 64) or UBigInt(seed);
  end;
  result := result shr (need * 64 - nbits);
  result.setBit(nbits - 1);
end;

function mkB(nbits: integer; seed: QWord; neg: boolean): BigInt;
begin
  result := mkU(nbits, seed);
  if neg then result := -result;
end;

procedure emit(const tag: string; nbits: integer; iters: Int64; t0: Double);
begin
  writeln(Format('RESULT %-10s %5d %10.3f', [tag, nbits, (clk - t0) / iters * 1e9]));
end;

procedure bAdd(const a, b: BigInt; nbits: integer; it: Int64);
begin var t := clk; for var i := 1 to it do begin var c := a + b; sink += Ord(c.isEven); end; emit('add', nbits, it, t); end;

procedure bSub(const a, b: BigInt; nbits: integer; it: Int64);
begin var t := clk; for var i := 1 to it do begin var c := a - b; sink += Ord(c.isEven); end; emit('sub', nbits, it, t); end;

procedure bMul(const a, b: BigInt; nbits: integer; it: Int64);
begin var t := clk; for var i := 1 to it do begin var c := a * b; sink += Ord(c.isEven); end; emit('mul', nbits, it, t); end;

procedure bSqr(const a: BigInt; nbits: integer; it: Int64);
begin var t := clk; for var i := 1 to it do begin var c := a.sqr; sink += Ord(c.isEven); end; emit('sqr', nbits, it, t); end;

procedure bDiv(const a, b: BigInt; nbits: integer; it: Int64);
begin var t := clk; for var i := 1 to it do begin var c := a div b; sink += Ord(c.isEven); end; emit('div', nbits, it, t); end;

procedure bMod(const a, b: BigInt; nbits: integer; it: Int64);
begin var t := clk; for var i := 1 to it do begin var c := a mod b; sink += Ord(c.isEven); end; emit('mod', nbits, it, t); end;

procedure bAnd(const a, b: BigInt; nbits: integer; it: Int64);
begin var t := clk; for var i := 1 to it do begin var c := a and b; sink += Ord(c.isEven); end; emit('and', nbits, it, t); end;

procedure bOr(const a, b: BigInt; nbits: integer; it: Int64);
begin var t := clk; for var i := 1 to it do begin var c := a or b; sink += Ord(c.isEven); end; emit('or', nbits, it, t); end;

procedure bXor(const a, b: BigInt; nbits: integer; it: Int64);
begin var t := clk; for var i := 1 to it do begin var c := a xor b; sink += Ord(c.isEven); end; emit('xor', nbits, it, t); end;

procedure bShl(const a: BigInt; nbits: integer; it: Int64);
begin var t := clk; for var i := 1 to it do begin var c := a shl 17; sink += Ord(c.isEven); end; emit('shl', nbits, it, t); end;

procedure bShr(const a: BigInt; nbits: integer; it: Int64);
begin var t := clk; for var i := 1 to it do begin var c := a shr 17; sink += Ord(c.isEven); end; emit('shr', nbits, it, t); end;

procedure bCmp(const a, b: BigInt; nbits: integer; it: Int64);
begin var t := clk; for var i := 1 to it do sink += Ord(a < b); emit('cmp', nbits, it, t); end;

procedure bEq(const a, b: BigInt; nbits: integer; it: Int64);
begin var t := clk; for var i := 1 to it do sink += Ord(a = b); emit('eq', nbits, it, t); end;

procedure runB(nbits: integer; base: Int64);
begin
  var a := mkB(nbits, 1, true); // negative left operand
  var b := mkB(nbits, 2, false);
  var a2 := mkB(nbits * 2, 3, true); // 2N-bit negative dividend
  bAdd(a, b, nbits, base);
  bSub(a, b, nbits, base);
  bMul(a, b, nbits, if nbits >= 1024 then base div 8 else base);
  bSqr(a, nbits, if nbits >= 1024 then base div 8 else base);
  bDiv(a2, b, nbits, if nbits >= 1024 then base div 4 else base);
  bMod(a2, b, nbits, if nbits >= 1024 then base div 4 else base);
  bAnd(a, b, nbits, base);
  bOr(a, b, nbits, base);
  bXor(a, b, nbits, base);
  bShl(a, nbits, base);
  bShr(a, nbits, base);
  bCmp(a, b, nbits, base);
  bEq(a, b, nbits, base);
end;

begin
  QueryPerformanceFrequency(qpc);
  runB(64, 4000000);
  runB(128, 4000000);
  runB(256, 3000000);
  runB(512, 2000000);
  runB(1024, 800000);
  runB(4096, 120000);
  writeln;
  writeln($'(sink = {sink})');
end.
