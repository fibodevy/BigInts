program primes;

// Miller-Rabin testing and prime navigation

{$mode unleashed}

uses BigInts;

begin
  writeln(UBigInt(97).isProbablePrime);            // TRUE
  writeln(UBigInt(91).isProbablePrime);            // FALSE (7*13)

  // deterministic below 3.3e24, so small results are exact facts
  var p: UBigInt := '1000000000000000003';
  writeln($'{p} prime? {p.isProbablePrime}');

  // walk primes in both directions
  writeln($'next after 10^18: {UBigInt('1000000000000000000').nextPrime}');
  writeln($'previous: {UBigInt('1000000000000000000').prevPrime}');

  // a fresh 128-bit prime (top bit set, so exactly 128 bits)
  BigIntRandomSeed(2026);
  var q := UBigInt.randomPrime(128);
  writeln($'{q}  ({q.bitLength} bits)');

  // twin prime hunt
  var t: UBigInt := 1000000;
  repeat
    t := t.nextPrime;
  until (t + 2).isProbablePrime;
  writeln($'twins: {t} and {t + 2}');
  {$ifdef WINDOWS}readln;{$endif}
end.
