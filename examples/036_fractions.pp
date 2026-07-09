program fractions;

// every finite decimal is a rational: toFraction hands you the reduced pair

{$mode unleashed}

uses BigInts;

begin
  var (n1, d1) := BigDecimal('0.375').toFraction;
  writeln($'{n1}/{d1}');               // 3/8
  var (n2, d2) := BigDecimal('-2.5').toFraction;
  writeln($'{n2}/{d2}');               // -5/2
  var (n3, d3) := BigDecimal('0.1').toFraction;
  writeln($'{n3}/{d3}');               // 1/10
  var (n4, d4) := BigDecimal(42).toFraction;
  writeln($'{n4}/{d4}');               // 42/1

  // and back again, exactly
  var x: BigDecimal := '3.14159265358979323846';
  var (p, q) := x.toFraction;
  writeln(BigDecimal(p).divide(BigDecimal(q), 30) = x); // TRUE

  // the machine value of 0.1 as a fraction (denominator is 2^52-something)
  var (fp, fq) := BigDecimal.fromDoubleExact(0.1).toFraction;
  writeln($'0.1 as stored = {fp} / {fq}');
  {$ifdef WINDOWS}readln;{$endif}
end.
