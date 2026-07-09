program strong_safe_primes;

// key-generation primes with extra structure

{$mode unleashed}

uses BigInts;

begin
  BigIntRandomSeed(2026);

  // safe prime: p and (p-1)/2 are both prime (Diffie-Hellman groups)
  var sp := UBigInt.randomSafePrime(256);
  writeln($'safe prime p   = {sp}');
  writeln($'  (p-1)/2 prime? {((sp - 1) shr 1).isPrime}'); // TRUE

  // strong prime (Gordon): p-1 and p+1 each have a large prime factor
  var stp := UBigInt.randomStrongPrime(256);
  writeln($'strong prime   = {stp}');
  writeln($'  bits          = {stp.bitLength}');
  writeln($'  isPrime       = {stp.isPrime}');
  {$ifdef WINDOWS}readln;{$endif}
end.
