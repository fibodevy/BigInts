program exp_ln_log;

// exponentials and logarithms on exact decimals

{$mode unleashed}

uses BigInts;

begin
  writeln($'{BigDecimal(1).exp(40)}');         // e
  writeln($'{BigDecimal(2).ln(40)}');          // ln 2
  writeln($'{BigDecimal(10).ln(40)}');         // ln 10

  // exp and ln are inverses
  var x: BigDecimal := '3.7';
  writeln($'{x.ln(45).exp(40)}'); // 3.7 back again (40 digits)

  // logs in any base; powers of the base come out exact
  writeln($'{BigDecimal(7).log10(40)}');
  writeln($'{BigDecimal('1000').log10}');                 // 3, exact
  writeln($'{BigDecimal('0.5').log2}');                   // -1, exact
  writeln($'{BigDecimal(8).logBase(BigDecimal(2), 30)}'); // 3

  // growth questions: how long to double at 3 percent
  var years := BigDecimal(2).ln(30).divide(BigDecimal('1.03').ln(30), 10);
  writeln($'doubling at 3%: {years.rounded(-2)} years');

  // exp of big and tiny arguments
  writeln($'{BigDecimal(100).exp(5).toScientific}');
  writeln($'{BigDecimal(-100).exp(50).toScientific}');
  {$ifdef WINDOWS}readln;{$endif}
end.
