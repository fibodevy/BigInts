program fractional_powers;

// x ** y for any decimal exponent

{$mode unleashed}

uses BigInts;

begin
  writeln($'{BigDecimal(2) ** BigDecimal('0.5')}'); // sqrt 2
  writeln($'{BigDecimal(3) ** BigDecimal('3.25')}');
  writeln($'{BigDecimal(10) ** BigDecimal('-1.5')}');
  writeln($'{BigDecimal('2.25') ** BigDecimal('0.5')}'); // 1.5

  // integer exponents stay on the exact path
  writeln($'{BigDecimal('1.5') ** 10}');            // 57.6650390625, exact
  writeln($'{BigDecimal(2).pow(BigDecimal(100))}'); // exact 2^100

  // pick the precision for the inexact ones
  writeln($'{BigDecimal(2).pow(BigDecimal(1) / 3, 50)}');

  // compound interest, fractional years
  var value := BigDecimal(1000) * (BigDecimal('1.05') ** BigDecimal('2.5'));
  writeln($'1000 at 5% for 2.5 years: {value.rounded(-2)}');
  {$ifdef WINDOWS}readln;{$endif}
end.
