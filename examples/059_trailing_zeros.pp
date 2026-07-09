program trailing_zeros;

// trailing zeros of n!: count them directly, then check Legendre's formula

{$mode unleashed}

uses BigInts;

const
  N = 1000;

begin
  var f := UBigInt.factorial(N);

  // count directly by dividing tens away
  var direct := 0;
  var t := f;
  while (t mod 10).isZero do begin
    t := t div 10;
    inc(direct);
  end;

  // Legendre: zeros = sum of n div 5^k
  var legendre := 0;
  var p5 := 5;
  while p5 <= N do begin
    legendre := legendre + N div p5;
    p5 := p5 * 5;
  end;

  writeln($'1000! ends with {direct} zeros, Legendre says {legendre}');
  writeln($'match: {direct = legendre}');
  {$ifdef WINDOWS}readln;{$endif}
end.
