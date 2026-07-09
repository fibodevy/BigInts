program continued_fraction;

// convergents of sqrt(2) = [1; 2, 2, 2, ...] close in like clockwork

{$mode unleashed}

uses BigInts;

begin
  var root2 := BigDecimal(2).sqrt(60);
  var pPrev := UBigInt.one;    // p(-1)
  var p := UBigInt.one;        // p0 = a0 = 1
  var qPrev := UBigInt.zero;
  var q := UBigInt.one;
  for var i := 1 to 30 do begin
    // every partial quotient of sqrt(2) after the first is 2
    var pNext := 2 * p + pPrev;
    var qNext := 2 * q + qPrev;
    pPrev := p; p := pNext;
    qPrev := q; q := qNext;
    if i mod 6 = 0 then begin
      var approx := BigDecimal(p).divide(BigDecimal(q), 40);
      writeln($'{p}/{q} off by {(approx - root2).abs.toScientific}');
    end;
  end;
  {$ifdef WINDOWS}readln;{$endif}
end.
