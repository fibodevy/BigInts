program hyperbolics;

// sinh, cosh, tanh over the same exponential core

{$mode unleashed}

uses BigInts;

begin
  writeln($'{BigDecimal(1).sinh(40)}');
  writeln($'{BigDecimal(1).cosh(40)}');
  writeln($'{BigDecimal(1).tanh(40)}');

  // cosh^2 - sinh^2 = 1
  var x: BigDecimal := '2.5';
  var sh := x.sinh(45);
  var ch := x.cosh(45);
  writeln($'{(ch * ch - sh * sh).rounded(-40)}'); // 1

  // tanh saturates gracefully, no huge intermediates
  writeln($'{BigDecimal(200).tanh(30)}');       // 1
  writeln($'{BigDecimal(-200).tanh(30)}');      // -1

  // a hanging cable: catenary height y = a cosh(x/a)
  var a: BigDecimal := 20;
  var y := a * (BigDecimal(15) / a).cosh(20);
  writeln($'catenary at x=15, a=20: {y.rounded(-6)}');
  {$ifdef WINDOWS}readln;{$endif}
end.
