program newton_solver;

// Newton's method on exact decimals: solve x^3 = 2 to 80 digits

{$mode unleashed}

uses BigInts;

const
  P = 80;

begin
  var x: BigDecimal := '1.26'; // rough start
  for var i := 1 to 8 do begin
    // x := x - (x^3 - 2) / (3 x^2), doubling digits every round
    var fx := x * x * x - 2;
    var dfx := 3 * x * x;
    x := (x - fx.divide(dfx, P + 5)).rounded(-(P + 2), bdrTrunc);
  end;
  writeln($'newton:  {x.rounded(-P)}');
  writeln($'nthRoot: {BigDecimal(2).nthRoot(3, P)}');
  writeln($'cube check: {(x * x * x).rounded(-70)}');
  {$ifdef WINDOWS}readln;{$endif}
end.
