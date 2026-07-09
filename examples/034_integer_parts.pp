program integer_parts;

// trunc, floor, ceil, round land in BigInt; frac keeps the rest

{$mode unleashed}

uses BigInts;

begin
  var x: BigDecimal := '3.75';
  writeln($'{x.trunc} {x.floor} {x.ceil} {x.round}');       // 3 3 4 4
  var y: BigDecimal := '-3.75';
  writeln($'{y.trunc} {y.floor} {y.ceil} {y.round}');       // -3 -4 -3 -4

  // round takes halves to even, like Pascal round
  writeln($'{BigDecimal('2.5').round} {BigDecimal('3.5').round}'); // 2 4

  // self = trunc + frac, always
  writeln($'{x.frac} {y.frac}');             // 0.75 -0.75
  writeln(BigDecimal(x.trunc) + x.frac = x); // TRUE

  // the pieces are real BigInt values
  var n := BigDecimal('123456789.999').trunc;
  writeln($'{n * 2}');
  {$ifdef WINDOWS}readln;{$endif}
end.
