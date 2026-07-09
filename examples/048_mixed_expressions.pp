program mixed_expressions;

// the three types and the built-in ones cooperate in one expression

{$mode unleashed}

uses BigInts;

begin
  var u: UBigInt := '999999999999999999999999999999';
  var s: BigInt := -42;
  var d: BigDecimal := '0.5';

  // integers and literals slide into big expressions
  writeln($'{u + 1}');
  writeln($'{5 - s}');                     // 47
  writeln($'{d * 2 + 1}');                 // 2

  // strings parse in place
  writeln($'{u + UBigInt('1000000000000000000000000000001')}');
  writeln($'{d + BigDecimal('0.25')}'); // 0.75

  // UBigInt and BigInt widen into BigDecimal implicitly
  writeln($'{BigDecimal(u) * d}');
  writeln($'{s * BigDecimal('0.1')}'); // -4.2
  writeln($'{(BigDecimal(u) / s).rounded(-6)}');

  // and the whole ladder in one line
  writeln($'{(BigDecimal(u.toBigInt * s) / 1000).rounded(0)}');
  {$ifdef WINDOWS}readln;{$endif}
end.
