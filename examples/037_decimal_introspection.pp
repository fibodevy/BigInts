program decimal_introspection;

// looking inside a decimal: digits, positions, scaling

{$mode unleashed}

uses BigInts;

begin
  var x: BigDecimal := '123.45';
  writeln($'precision {x.precision}');                         // 5 significant digits
  writeln($'leading digit at 10^{x.mostSignificantExponent}'); // 2

  // getDigit(i) is the digit at 10^i of the absolute value
  for var i := 2 downto -2 do write(x.getDigit(i)); // 12345
  writeln;

  // shift10 moves the point without touching the mantissa
  writeln($'{x.shifted10(3)}');        // 123450
  writeln($'{x.shifted10(-4)}');       // 0.012345
  var y: BigDecimal := '7.25';
  y.shift10(2);
  writeln($'{y}');                     // 725

  // parity and integrality
  writeln(BigDecimal('4.0').isEven, ' ', BigDecimal('3').isOdd, ' ', BigDecimal('3.5').isOdd);
  writeln(BigDecimal('42').isIntegral, ' ', BigDecimal('42.5').isIntegral);
  {$ifdef WINDOWS}readln;{$endif}
end.
