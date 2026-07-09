program decimal_gcd_lattice;

// gcd and lcm extend naturally to decimals: the largest common step and
// the smallest common multiple

{$mode unleashed}

uses BigInts;

begin
  writeln($'{BigDecimal('0.25').gcd('0.15')}');     // 0.05
  writeln($'{BigDecimal('0.25').lcm('0.15')}');     // 0.75

  // integers behave as usual
  writeln($'{BigDecimal(12).gcd(BigDecimal(18))}'); // 6
  writeln($'{BigDecimal(4).lcm(BigDecimal(6))}');   // 12

  // what tick fits both 0.2 s and 0.3 s events
  writeln($'common tick: {BigDecimal('0.2').gcd('0.3')}');       // 0.1
  writeln($'meet again after: {BigDecimal('0.2').lcm('0.3')}');  // 0.6

  // gcd * lcm = |a * b| on the lattice too
  var a: BigDecimal := '0.36';
  var b: BigDecimal := '0.084';
  writeln(a.gcd(b) * a.lcm(b) = a * b); // TRUE
  {$ifdef WINDOWS}readln;{$endif}
end.
