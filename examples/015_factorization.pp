program factorization;

// factorize returns (prime, exponent) tuples in ascending order

{$mode unleashed}

uses BigInts;

begin
  for var (p, e) in UBigInt(720).factorize do write($'{p}^{e} '); // 2^4 3^2 5^1
  writeln;

  // Pollard-Brent rho cracks bigger composites
  var n: UBigInt := '123456789012345678';
  var check := UBigInt.one;
  for var (p, e) in n.factorize do begin
    write($'{p}^{e} ');
    check := check * p.pow(e);
  end;
  writeln;
  writeln($'product check: {check = n}'); // TRUE

  // BigInt factors the absolute value
  for var (p, e) in BigInt(-360).factorize do write($'{p}^{e} ');
  writeln;

  // primes come back as themselves
  var f := UBigInt('1000000007').factorize;
  writeln($'{Length(f)} factor, exponent {f[0].e}');
  {$ifdef WINDOWS}readln;{$endif}
end.
