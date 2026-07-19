program bench_small;

{$mode unleashed}

// small-value benchmark harness for BigInts: fixed operands, tight
// loops, QueryPerformanceCounter, global sink against dead code elimination

uses Windows, SysUtils, BigInts;

const
  N = 20000000;  // fast integer ops
  ND = 5000000;  // BigDecimal ops

var
  freq: Int64;
  sink: QWord;

procedure report(const name: string; t0, t1, n: Int64);
begin
  writeln(Format('%-14s %7.1f ns/op', [name, (t1 - t0) / freq * 1e9 / n]));
end;

procedure BenchUAdd;
var
  a, b, x: UBigInt;
  t0, t1: Int64;
begin
  a := UBigInt.pow2(100) + 12345;
  b := UBigInt.pow2(99) + 6789;
  QueryPerformanceCounter(t0);
  for var i := 1 to N do begin
    x := a + b;
    if x.isOdd then inc(sink);
  end;
  QueryPerformanceCounter(t1);
  report('u_add2', t0, t1, N);
end;

procedure BenchUSub;
var
  a, b, x: UBigInt;
  t0, t1: Int64;
begin
  a := UBigInt.pow2(100) + 12345;
  b := UBigInt.pow2(99) + 6789;
  QueryPerformanceCounter(t0);
  for var i := 1 to N do begin
    x := a - b;
    if x.isOdd then inc(sink);
  end;
  QueryPerformanceCounter(t1);
  report('u_sub2', t0, t1, N);
end;

procedure BenchUMul;
var
  a, b, x: UBigInt;
  t0, t1: Int64;
begin
  a := UBigInt.pow2(100) + 12345;
  b := UBigInt.pow2(99) + 6789;
  QueryPerformanceCounter(t0);
  for var i := 1 to N do begin
    x := a * b;
    if x.isOdd then inc(sink);
  end;
  QueryPerformanceCounter(t1);
  report('u_mul2', t0, t1, N);
end;

procedure BenchUAdd4;
var
  a, b, x: UBigInt;
  t0, t1: Int64;
begin
  a := UBigInt.pow2(250) + 12345;
  b := UBigInt.pow2(249) + 6789;
  QueryPerformanceCounter(t0);
  for var i := 1 to N do begin
    x := a + b;
    if x.isOdd then inc(sink);
  end;
  QueryPerformanceCounter(t1);
  report('u_add4', t0, t1, N);
end;

procedure BenchUAdd4Spill;
var
  a, b, x: UBigInt;
  t0, t1: Int64;
begin
  a := UBigInt.pow2(255) + 12345;
  b := UBigInt.pow2(255) + 6789;
  QueryPerformanceCounter(t0);
  for var i := 1 to N do begin
    x := a + b;
    if x.isOdd then inc(sink);
  end;
  QueryPerformanceCounter(t1);
  report('u_add4spill', t0, t1, N);
end;

procedure BenchUMul23;
var
  a, b, x: UBigInt;
  t0, t1: Int64;
begin
  a := UBigInt.pow2(100) + 12345;
  b := UBigInt.pow2(150) + 6789;
  QueryPerformanceCounter(t0);
  for var i := 1 to N do begin
    x := a * b;
    if x.isOdd then inc(sink);
  end;
  QueryPerformanceCounter(t1);
  report('u_mul23', t0, t1, N);
end;

procedure BenchUCmp;
var
  a, b: UBigInt;
  t0, t1: Int64;
begin
  a := UBigInt.pow2(100) + 12345;
  b := UBigInt.pow2(100) + 6789;
  QueryPerformanceCounter(t0);
  for var i := 1 to N do
    if a > b then inc(sink);
  QueryPerformanceCounter(t1);
  report('u_cmp2', t0, t1, N);
end;

procedure BenchUDiv21;
var
  a, b, x: UBigInt;
  t0, t1: Int64;
begin
  a := UBigInt.pow2(100) + 12345;
  b := 987654321;
  QueryPerformanceCounter(t0);
  for var i := 1 to N do begin
    x := a div b;
    if x.isOdd then inc(sink);
  end;
  QueryPerformanceCounter(t1);
  report('u_div21', t0, t1, N);
end;

procedure BenchUDiv42;
var
  a, b, x: UBigInt;
  t0, t1: Int64;
begin
  a := UBigInt.pow2(250) + 12345;
  b := UBigInt.pow2(100) + 6789;
  QueryPerformanceCounter(t0);
  for var i := 1 to N do begin
    x := a div b;
    if x.isOdd then inc(sink);
  end;
  QueryPerformanceCounter(t1);
  report('u_div42', t0, t1, N);
end;

procedure BenchUMod21;
var
  a, b, x: UBigInt;
  t0, t1: Int64;
begin
  a := UBigInt.pow2(100) + 12345;
  b := 987654321;
  QueryPerformanceCounter(t0);
  for var i := 1 to N do begin
    x := a mod b;
    if x.isOdd then inc(sink);
  end;
  QueryPerformanceCounter(t1);
  report('u_mod21', t0, t1, N);
end;

procedure BenchUDivI64;
var
  a, x: UBigInt;
  t0, t1: Int64;
begin
  a := UBigInt.pow2(100) + 12345;
  QueryPerformanceCounter(t0);
  for var i := 1 to N do begin
    x := a div Int64(987654321);
    if x.isOdd then inc(sink);
  end;
  QueryPerformanceCounter(t1);
  report('u_divI64', t0, t1, N);
end;

procedure BenchUAddI64;
var
  a, x: UBigInt;
  t0, t1: Int64;
begin
  a := UBigInt.pow2(100) + 12345;
  QueryPerformanceCounter(t0);
  for var i := 1 to N do begin
    x := a + Int64(987654321);
    if x.isOdd then inc(sink);
  end;
  QueryPerformanceCounter(t1);
  report('u_addI64', t0, t1, N);
end;

procedure BenchSAddI64;
var
  a, x: BigInt;
  t0, t1: Int64;
begin
  a := BigInt('-1267650600228229401496703217701');
  QueryPerformanceCounter(t0);
  for var i := 1 to N do begin
    x := a + Int64(987654321);
    if x.isOdd then inc(sink);
  end;
  QueryPerformanceCounter(t1);
  report('s_addI64', t0, t1, N);
end;

procedure BenchSCmp;
var
  a, b: BigInt;
  t0, t1: Int64;
begin
  a := BigInt('-1267650600228229401496715325229');
  b := BigInt('-1267650600228229401496703217701');
  QueryPerformanceCounter(t0);
  for var i := 1 to N do
    if a < b then inc(sink);
  QueryPerformanceCounter(t1);
  report('s_cmp2', t0, t1, N);
end;

procedure BenchSNeg;
var
  a, x: BigInt;
  t0, t1: Int64;
begin
  a := BigInt('-1267650600228229401496703217701');
  QueryPerformanceCounter(t0);
  for var i := 1 to N do begin
    x := -a;
    if x.isOdd then inc(sink);
  end;
  QueryPerformanceCounter(t1);
  report('s_neg', t0, t1, N);
end;

procedure BenchDCmp;
var
  a, b: BigDecimal;
  t0, t1: Int64;
begin
  a := BigDecimal('123.45');
  b := BigDecimal('123.46');
  QueryPerformanceCounter(t0);
  for var i := 1 to N do
    if a < b then inc(sink);
  QueryPerformanceCounter(t1);
  report('d_cmp', t0, t1, N);
end;

procedure BenchSAdd;
var
  a, b, x: BigInt;
  t0, t1: Int64;
begin
  a := BigInt('1267650600228229401496703217701');
  b := BigInt('-633825300114114700748351610181');
  QueryPerformanceCounter(t0);
  for var i := 1 to N do begin
    x := a + b;
    if x.isOdd then inc(sink);
  end;
  QueryPerformanceCounter(t1);
  report('s_add2', t0, t1, N);
end;

procedure BenchSMul;
var
  a, b, x: BigInt;
  t0, t1: Int64;
begin
  a := BigInt('1267650600228229401496703217701');
  b := BigInt('-633825300114114700748351610181');
  QueryPerformanceCounter(t0);
  for var i := 1 to N do begin
    x := a * b;
    if x.isOdd then inc(sink);
  end;
  QueryPerformanceCounter(t1);
  report('s_mul2', t0, t1, N);
end;

procedure BenchSDiv;
var
  a, b, x: BigInt;
  t0, t1: Int64;
begin
  a := BigInt('-1267650600228229401496703217701');
  b := BigInt('633825300114114700748');
  QueryPerformanceCounter(t0);
  for var i := 1 to N do begin
    x := a div b;
    if x.isOdd then inc(sink);
  end;
  QueryPerformanceCounter(t1);
  report('s_div2', t0, t1, N);
end;

procedure BenchDAdd;
var
  a, b, x: BigDecimal;
  t0, t1: Int64;
begin
  a := BigDecimal('1.23');
  b := BigDecimal('0.01');
  QueryPerformanceCounter(t0);
  for var i := 1 to ND do begin
    x := a + b;
    if x.isNegative then inc(sink);
  end;
  QueryPerformanceCounter(t1);
  report('d_add', t0, t1, ND);
end;

procedure BenchDMul;
var
  a, b, x: BigDecimal;
  t0, t1: Int64;
begin
  a := BigDecimal('1.23');
  b := BigDecimal('4.56');
  QueryPerformanceCounter(t0);
  for var i := 1 to ND do begin
    x := a * b;
    if x.isNegative then inc(sink);
  end;
  QueryPerformanceCounter(t1);
  report('d_mul', t0, t1, ND);
end;

procedure BenchDSubAlign;
var
  a, b, x: BigDecimal;
  t0, t1: Int64;
begin
  a := BigDecimal('123.456789');
  b := BigDecimal('0.01');
  QueryPerformanceCounter(t0);
  for var i := 1 to ND do begin
    x := a - b;
    if x.isNegative then inc(sink);
  end;
  QueryPerformanceCounter(t1);
  report('d_sub_align', t0, t1, ND);
end;

begin
  QueryPerformanceFrequency(freq);
  sink := 0;
  BenchUAdd;
  BenchUSub;
  BenchUMul;
  BenchUAdd4;
  BenchUAdd4Spill;
  BenchUMul23;
  BenchUCmp;
  BenchUDiv21;
  BenchUDiv42;
  BenchUMod21;
  BenchUDivI64;
  BenchUAddI64;
  BenchSAdd;
  BenchSMul;
  BenchSDiv;
  BenchSAddI64;
  BenchSCmp;
  BenchSNeg;
  BenchDCmp;
  BenchDAdd;
  BenchDMul;
  BenchDSubAlign;
  writeln;
  writeln($'(sink = {sink})');
  if ParamStr(1) = 'wait' then readln;
end.
