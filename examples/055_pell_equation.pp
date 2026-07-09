program pell_equation;

// x^2 - 61 y^2 = 1: tiny equation, enormous fundamental solution

{$mode unleashed}

uses BigInts;

const
  D = 61;

begin
  // continued fraction of sqrt(61) generates the convergents
  var a0 := UBigInt(D).sqrt;
  var m := UBigInt.zero;
  var den := UBigInt.one;
  var a := a0;
  var pPrev := UBigInt.one;
  var p := a0;
  var qPrev := UBigInt.zero;
  var q := UBigInt.one;
  repeat
    m := den * a - m;
    den := (UBigInt(D) - m * m) div den;
    a := (a0 + m) div den;
    var pNext := a * p + pPrev;
    var qNext := a * q + qPrev;
    pPrev := p; p := pNext;
    qPrev := q; q := qNext;
  until p.sqr = UBigInt(D) * q.sqr + 1;
  writeln($'x = {p}');
  writeln($'y = {q}');
  writeln($'check x^2 - 61 y^2 = {p.sqr.toBigInt - (UBigInt(D) * q.sqr).toBigInt}');
  {$ifdef WINDOWS}readln;{$endif}
end.
