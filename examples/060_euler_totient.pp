program euler_totient;

// phi(n) from the factorization, and Euler's theorem in action

{$mode unleashed}

uses BigInts;

function totient(const n: UBigInt): UBigInt;
begin
  result := n;
  for var (p, e) in n.factorize do result := result div p * (p - 1);
end;

begin
  writeln($'phi(360) = {totient(UBigInt(360))}');       // 96
  writeln($'phi(97) = {totient(UBigInt(97))}');         // 96, primes give p-1

  var n: UBigInt := '123456789012345678';
  var phi := totient(n);
  writeln($'phi({n}) = {phi}');

  // Euler: a^phi(n) = 1 (mod n) for gcd(a, n) = 1
  var a: UBigInt := 5;
  writeln($'gcd = {a.gcd(n)}, a^phi mod n = {a.modPow(phi, n)}');
  {$ifdef WINDOWS}readln;{$endif}
end.
