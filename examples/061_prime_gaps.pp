program prime_gaps;

// record gaps between consecutive primes past 10^15

{$mode unleashed}

uses BigInts;

begin
  var p: UBigInt := '1000000000000000';
  p := p.nextPrime;
  var best := UBigInt.zero;
  var bestAt := p;
  for var i := 1 to 200 do begin
    var q := p.nextPrime;
    if q - p > best then begin
      best := q - p;
      bestAt := p;
    end;
    p := q;
  end;
  writeln($'largest gap among 200 primes past 10^15: {best}');
  writeln($'after {bestAt}');
  {$ifdef WINDOWS}readln;{$endif}
end.
