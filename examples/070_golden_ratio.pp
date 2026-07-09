program golden_ratio;

// two roads to phi: (1 + sqrt 5)/2 and the Fibonacci quotient limit

{$mode unleashed}

uses BigInts;

begin
  var phi := (BigDecimal(1) + BigDecimal(5).sqrt(60)) / 2;
  writeln($'phi = {phi.rounded(-50)}');

  // F(n+1)/F(n) closes in on phi
  for var n in [10, 30, 90] do begin
    var ratio := BigDecimal(UBigInt.fibonacci(LongWord(n + 1))).divide(BigDecimal(UBigInt.fibonacci(LongWord(n))), 55);
    writeln($'F({n + 1})/F({n}) off by {(ratio - phi).abs.toScientific}');
  end;

  // and the defining property: phi^2 = phi + 1
  writeln($'phi^2 - phi - 1 = {(phi * phi - phi - 1).toScientific}');
  {$ifdef WINDOWS}readln;{$endif}
end.
