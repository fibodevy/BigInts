program bench_prime;

{$mode unleashed}

uses {$ifdef WINDOWS}Windows,{$endif} SysUtils, bigints;

var
  freq: Int64;

function now64: Int64;
begin
  QueryPerformanceCounter(result);
end;

procedure report(const name: string; t0, t1: Int64; iters: Int64);
begin
  writeln(Format('%-30s %10.2f us/op', [name, (t1-t0)*1e6/freq/iters]));
end;

begin
  QueryPerformanceFrequency(freq);
  BigIntRandomSeed(42);

  // isProbablePrime sweep over consecutive odd 1024-bit numbers (mostly composites)
  var base1024 := UBigInt.random(1024);
  base1024.setBit(1023);
  base1024.setBit(0);
  var t0 := now64;
  var primes := 0;
  for var k := 0 to 999 do
    if (base1024+2*k).isProbablePrime then inc(primes);
  var t1 := now64;
  report('isProbablePrime 1024b sweep', t0, t1, 1000);
  writeln('  primes found: ', primes);

  // isPrime (BPSW) sweep over odd 256-bit numbers
  var base256 := UBigInt.random(256);
  base256.setBit(255);
  base256.setBit(0);
  t0 := now64;
  primes := 0;
  for var k := 0 to 1999 do
    if (base256+2*k).isPrime then inc(primes);
  t1 := now64;
  report('isPrime 256b sweep', t0, t1, 2000);
  writeln('  primes found: ', primes);

  // nextPrime from a 512-bit start
  var b512 := UBigInt.random(512);
  b512.setBit(511);
  t0 := now64;
  var acc: LongWord := 0;
  for var k := 1 to 10 do begin
    b512 := b512.nextPrime;
    acc := acc+b512.bitLength;
  end;
  t1 := now64;
  report('nextPrime 512b', t0, t1, 10);
  writeln('  acc=', acc);
  readln;
end.
