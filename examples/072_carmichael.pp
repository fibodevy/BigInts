program carmichael;

// Carmichael numbers: composite yet Fermat-liar for every coprime base

{$mode unleashed}

uses BigInts;

begin
  // Korselt: squarefree, and p-1 divides n-1 for every prime factor p
  write('Carmichael numbers below 10000:');
  var n: UBigInt := 3;
  while n < 10000 do begin
    if n.isCarmichael then write($' {n}');
    n := n + 2;
  end;
  writeln;
  // 561 = 3*11*17 is the smallest; every coprime base passes Fermat
  var c: UBigInt := 561;
  writeln($'{c} composite but 2^(c-1) mod c = {UBigInt(2).modPow(c - 1, c)}');
  writeln($'lambda(561) = {c.carmichaelLambda}'); // 80: a^80 = 1 for all coprime a
  // a real primality test is not fooled
  writeln($'isPrime(561) = {c.isPrime}'); // FALSE
  {$ifdef WINDOWS}readln;{$endif}
end.
