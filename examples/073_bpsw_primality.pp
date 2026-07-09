program bpsw_primality;

// isPrime is Baillie-PSW: no known counterexample, unlike a few Miller-Rabin
// bases that strong pseudoprimes can fool

{$mode unleashed}

uses BigInts;

begin
  // 3215031751 is a strong pseudoprime to bases 2, 3, 5 and 7 at once
  var liar: UBigInt := 3215031751;
  writeln($'{liar}: isPrime = {liar.isPrime}'); // FALSE, BPSW is not fooled

  // large genuine primes
  var p: UBigInt := '1000000000000000000000000000057';
  writeln($'{p}: isPrime = {p.isPrime}'); // TRUE

  // a big Carmichael number stays composite
  writeln($'651693055693681 isPrime = {UBigInt('651693055693681').isPrime}');

  // build a 400-bit prime and confirm it
  BigIntRandomize;
  var q := UBigInt.randomPrime(400);
  writeln($'{q.bitLength}-bit random prime, isPrime = {q.isPrime}');
  {$ifdef WINDOWS}readln;{$endif}
end.
