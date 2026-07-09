program approx_compare;

// comparing decimals: exact by default, with tolerance when you want it

{$mode unleashed}

uses BigInts;

begin
  // numeric equality across representations
  writeln(BigDecimal('0.5') = BigDecimal('5E-1'));      // TRUE
  writeln(BigDecimal('1.01') > BigDecimal('1.001'));    // TRUE
  writeln(BigDecimal('2') = 2);                         // mixed with integers

  // approxEquals for computed values
  var root := BigDecimal(2).sqrt(30);
  writeln(root.approxEquals(BigDecimal('1.41421356'), BigDecimal('1E-8')));   // TRUE
  writeln(root.approxEquals(BigDecimal('1.41421356'), BigDecimal('1E-12')));  // FALSE

  // compare, min, max
  writeln(BigDecimal('2.5').compare(BigDecimal('2.4'))); // 1
  writeln($'{BigDecimal('2.5').min(2)} {BigDecimal('2.5').max(3)}');

  // equal values share a hashCode (hash-map ready)
  writeln(BigDecimal('0.5').hashCode = BigDecimal('5E-1').hashCode); // TRUE
  {$ifdef WINDOWS}readln;{$endif}
end.
