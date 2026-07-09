program bernoulli_demo;

// Bernoulli numbers as exact fractions, and the sum of k-th powers

{$mode unleashed}

uses BigInts;

begin
  writeln('Bernoulli numbers B(n):');
  for var n := 0 to 12 do begin
    var (num, den) := BigInt.bernoulli(LongWord(n));
    if not num.isZero then writeln($'  B({n}) = {num}/{den}');
  end;

  // Faulhaber: sum_{i=1}^{N} i^2 = N(N+1)(2N+1)/6, checked against B numbers
  var big: BigInt := 1000000;
  var direct := big * (big + 1) * (2 * big + 1) div 6;
  writeln($'sum of squares 1..10^6 = {direct}');

  // B(12) has the famous numerator -691
  var (n12, d12) := BigInt.bernoulli(12);
  writeln($'B(12) = {n12}/{d12}');
  {$ifdef WINDOWS}readln;{$endif}
end.
