program quantize_steps;

// rounding to a step that is not a power of ten

{$mode unleashed}

uses BigInts;

begin
  // cash rounding to 5 groszy
  writeln($'{BigDecimal('7.13').quantize(BigDecimal('0.05'))}');   // 7.15
  writeln($'{BigDecimal('7.12').quantize(BigDecimal('0.05'))}');   // 7.1

  // modes work here too
  writeln($'{BigDecimal('7.11').quantize(BigDecimal('0.05'), bdrCeil)}');   // 7.15
  writeln($'{BigDecimal('7.14').quantize(BigDecimal('0.05'), bdrTrunc)}');  // 7.1

  // quarter steps, banker's ties
  writeln($'{BigDecimal('0.125').quantize(BigDecimal('0.25'), bdrHalfEven)}');  // 0
  writeln($'{BigDecimal('0.375').quantize(BigDecimal('0.25'), bdrHalfEven)}');  // 0.5

  // schedule times to 15 minutes (as fractions of an hour)
  writeln($'{BigDecimal('9.37').quantize(BigDecimal('0.25'))}'); // 9.25
  {$ifdef WINDOWS}readln;{$endif}
end.
