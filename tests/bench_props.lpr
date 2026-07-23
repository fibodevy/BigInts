program bench_props;

{$mode unleashed}

uses {$ifdef WINDOWS}Windows,{$endif} SysUtils, bigints;

const
  N = 2000000;

var
  freq: Int64;

function now64: Int64;
begin
  QueryPerformanceCounter(result);
end;

procedure report(const name: string; t0, t1: Int64; iters: Int64);
begin
  var ns := (t1-t0)*1e9/freq/iters;
  writeln(Format('%-28s %8.1f ns/op', [name, ns]));
end;

var
  sink: QWord = 0;

begin
  QueryPerformanceFrequency(freq);

  // inline-sized value (4 limbs, 256 bits)
  var a := UBigInt.parse('123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF', 16);
  // spilled value (16 limbs)
  var b := UBigInt.pow2(1000)+12345;

  var t0 := now64;
  for var i := 1 to N do sink := sink+a.hashCode;
  var t1 := now64;
  report('hashCode inline', t0, t1, N);

  t0 := now64;
  for var i := 1 to N do sink := sink+b.hashCode;
  t1 := now64;
  report('hashCode spilled', t0, t1, N);

  t0 := now64;
  for var i := 1 to N div 4 do sink := sink+Length(a.toBytesLE);
  t1 := now64;
  report('toBytesLE inline', t0, t1, N div 4);

  t0 := now64;
  for var i := 1 to N div 4 do sink := sink+Length(b.toBytesLE);
  t1 := now64;
  report('toBytesLE spilled', t0, t1, N div 4);

  t0 := now64;
  for var i := 1 to N div 4 do sink := sink+Length(a.toBytesBE);
  t1 := now64;
  report('toBytesBE inline', t0, t1, N div 4);

  t0 := now64;
  for var i := 1 to N div 4 do sink := sink+a.complement(256).bitLength;
  t1 := now64;
  report('complement inline', t0, t1, N div 4);

  var small := UBigInt(12345);
  var p := UBigInt.parse('FFFFFFFFFFFFFFFFC90FDAA22168C234C4C6628B80DC1CD129024E088A67CC74020BBEA63B139B22514A08798E3404DD', 16);
  t0 := now64;
  for var i := 1 to 20000 do sink := sink+QWord(integer(small.jacobi(p))+1);
  t1 := now64;
  report('jacobi small/big', t0, t1, 20000);

  writeln('sink=', sink);
  readln;
end.
