program birthday_paradox;

// exact probability that among n people two share a birthday

{$mode unleashed}

uses BigInts;

begin
  // p(no collision) = 365!/(365-n)! / 365^n, computed exactly then displayed
  for var n in [10, 23, 50, 70] do begin
    var num := UBigInt.one;
    for var k := 0 to n - 1 do num := num * UBigInt(365 - k);
    var den := UBigInt(365).pow(LongWord(n));
    var collide := BigDecimal(1) - BigDecimal(num).divide(BigDecimal(den), 10);
    writeln($'n = {n}: {(collide * 100).rounded(-2)}%');
  end;
  // the famous threshold: 23 people already pass 50 percent
  {$ifdef WINDOWS}readln;{$endif}
end.
