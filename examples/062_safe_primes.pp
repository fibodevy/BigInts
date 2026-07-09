program safe_primes;

// a safe prime p has (p-1)/2 prime too - the favourite of key exchanges

{$mode unleashed}

uses BigInts;

begin
  BigIntRandomSeed(99);
  var tries := 0;
  var p: UBigInt;
  repeat
    p := UBigInt.randomPrime(128);
    inc(tries);
  until ((p - 1) shr 1).isProbablePrime;
  writeln($'found after {tries} candidates:');
  writeln($'p       = {p}');
  writeln($'(p-1)/2 = {(p - 1) shr 1}');
  {$ifdef WINDOWS}readln;{$endif}
end.
