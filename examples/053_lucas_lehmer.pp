program lucas_lehmer;

// the Lucas-Lehmer test finds Mersenne primes 2^p - 1

{$mode unleashed}

uses BigInts;

function mersennePrime(p: LongWord): boolean;
begin
  // s := 4; s := s^2 - 2 (mod M) p-2 times; prime iff s = 0
  var m := UBigInt.pow2(p) - 1;
  var s: UBigInt := 4;
  for var i := 1 to p - 2 do s := (s.sqr - 2) mod m;
  result := s.isZero;
end;

begin
  write('Mersenne exponents up to 1300:');
  var p: UBigInt := 2;
  writeln;
  write('  ');
  while p <= 1300 do begin
    if mersennePrime(LongWord(p.toInt64)) or (p = 2) then write($'{p} ');
    p := p.nextPrime;
  end;
  writeln;
  // expected: 2 3 5 7 13 17 19 31 61 89 107 127 521 607 1279
  writeln($'2^1279 - 1 has {(UBigInt.pow2(1279) - 1).digitCount} digits');
  {$ifdef WINDOWS}readln;{$endif}
end.
