program decimal_basics;

// BigDecimal: exact decimal floats in canonical form

{$mode unleashed}

uses BigInts;

begin
  var d: BigDecimal := '-123.45';
  writeln(d.toString);                 // -123.45
  writeln(d.toScientific);             // -1.2345E2
  writeln(d.toEngineering);            // -123.45E0

  // trailing zeros vanish, value stays
  writeln(BigDecimal('1.500').toString);               // 1.5
  writeln(BigDecimal('1.500') = BigDecimal('0.15E1')); // TRUE

  // scientific input, separators, whitespace
  writeln(BigDecimal('2.5E-3').toString); // 0.0025
  writeln(BigDecimal('1_000_000.25').toString);
  writeln(BigDecimal(' 42 ').toString);

  // no size limit in either direction
  writeln(BigDecimal('1E50').toString);
  writeln(BigDecimal('1E-30').toScientific);
  {$ifdef WINDOWS}readln;{$endif}
end.
