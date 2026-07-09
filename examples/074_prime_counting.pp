program prime_counting;

// exact prime counting by a segmented sieve

{$mode unleashed}

uses BigInts;

begin
  writeln($'pi(10)       = {UBigInt.primePi(10)}');        // 4
  writeln($'pi(100)      = {UBigInt.primePi(100)}');       // 25
  writeln($'pi(1000)     = {UBigInt.primePi(1000)}');      // 168
  writeln($'pi(1000000)  = {UBigInt.primePi(1000000)}');   // 78498
  writeln($'pi(10^8)     = {UBigInt.primePi(100000000)}'); // 5761455

  // primes in a window, straight out of the sieve
  writeln($'primes in [10^9, 10^9+10^6] = {UBigInt.primeCount(1000000000, 1001000000)}');

  // the density thins out: primes per 1000 near 10^6 vs near 10^9
  writeln($'near 10^6: {UBigInt.primeCount(1000000, 1001000)} per 1000');
  writeln($'near 10^9: {UBigInt.primeCount(1000000000, 1000001000)} per 1000');
  {$ifdef WINDOWS}readln;{$endif}
end.
