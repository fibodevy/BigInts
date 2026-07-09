program number_theory;

// the classic multiplicative functions, all read off one factorization

{$mode unleashed}

uses BigInts;

begin
  var n: UBigInt := 360;
  writeln($'n            = {n}');
  writeln($'phi(n)       = {n.eulerPhi}');         // 96
  writeln($'lambda(n)    = {n.carmichaelLambda}'); // 12
  writeln($'mu(n)        = {n.moebius}');          // 0 (360 has a square factor)
  writeln($'tau(n)       = {n.tau}');              // 24 divisors
  writeln($'sigma(n)     = {n.sigma}');            // sum of divisors
  writeln($'sigma2(n)    = {n.sigma(2)}');         // sum of squares of divisors
  writeln($'radical(n)   = {n.radical}');          // 30 = 2*3*5

  write('divisors:');
  for var d in n.divisors do write($' {d}');
  writeln;

  // mu is nonzero exactly on squarefree numbers
  writeln($'30 squarefree? {UBigInt(30).isSquarefree}  (mu = {UBigInt(30).moebius})');
  writeln($'28 perfect?    {UBigInt(28).isPerfect}');
  {$ifdef WINDOWS}readln;{$endif}
end.
