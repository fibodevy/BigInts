program bench_dec;

// BigDecimal benchmark by significant digit count; operands share the digit
// count but differ in exponent (fractional values), so add/sub exercise the
// alignment path and cmp the magnitude-bounds path

{$mode unleashed}
{$q-}{$r-}

uses Windows, SysUtils, BigInts;

var
  qpc: Int64;
  sink: QWord = 0;
  rngState: QWord = $9E3779B97F4A7C15;

function clk: Double;
begin
  var t: Int64;
  QueryPerformanceCounter(t);
  result := t / qpc;
end;

function rnd64: QWord;
begin
  rngState := rngState xor (rngState shl 13);
  rngState := rngState xor (rngState shr 7);
  rngState := rngState xor (rngState shl 17);
  result := rngState;
end;

// N significant digits, decimal point after the third digit, nonzero last
// digit so nothing strips
function mkD(digits: integer): BigDecimal;
begin
  var s: string;
  SetLength(s, digits);
  s[1] := char(Ord('1') + integer(rnd64 mod 9));
  for var i := 2 to digits - 1 do s[i] := char(Ord('0') + integer(rnd64 mod 10));
  s[digits] := char(Ord('1') + integer(rnd64 mod 9));
  var cut := if digits > 3 then 3 else 1;
  result := BigDecimal(Copy(s, 1, cut) + '.' + Copy(s, cut + 1, digits - cut));
end;

procedure emit(const tag: string; digits: integer; iters: Int64; t0: Double);
begin
  writeln(Format('RESULT %-10s %5d %10.3f', [tag, digits, (clk - t0) / iters * 1e9]));
end;

procedure runD(digits: integer; it: Int64);
begin
  var a := mkD(digits);
  var b := mkD(digits);
  var t := clk; for var i := 1 to it do begin var c := a + b; sink += Ord(c.isNegative); end; emit('add', digits, it, t);
  t := clk; for var i := 1 to it do begin var c := a - b; sink += Ord(c.isNegative); end; emit('sub', digits, it, t);
  t := clk; for var i := 1 to it do begin var c := a * b; sink += Ord(c.isNegative); end; emit('mul', digits, it, t);
  var itd := if digits >= 200 then it div 4 else it;
  t := clk; for var i := 1 to itd do begin var c := a / b; sink += Ord(c.isNegative); end; emit('div', digits, itd, t);
  t := clk; for var i := 1 to it do sink += Ord(a < b); emit('cmp', digits, it, t);
end;

begin
  QueryPerformanceFrequency(qpc);
  runD(16, 2000000);
  runD(50, 1500000);
  runD(200, 500000);
  runD(1000, 120000);
  writeln;
  writeln($'(sink = {sink})');
end.
