program e_limit;

// (1 + 1/n)^n converges to e painfully slowly - exact decimals show how

{$mode unleashed}

uses BigInts;

begin
  var e := BigDecimal.e(40);
  writeln($'e = {e.rounded(-30)}');
  for var n in [10, 1000, 100000] do begin
    // exact rational (1 + 1/n)^n evaluated to 40 digits
    var base := BigDecimal(1) + BigDecimal(1).divide(BigDecimal(n), 40);
    var approx := base.pow(BigDecimal(n), 40);
    writeln($'n = {n}: {approx.rounded(-15)}  gap {(e - approx).toScientific}');
  end;
  {$ifdef WINDOWS}readln;{$endif}
end.
