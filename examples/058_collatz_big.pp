program collatz_big;

// the 3n+1 walk from a 30-digit start

{$mode unleashed}

uses BigInts;

begin
  var n: UBigInt := '931386509544713451315421953851';
  var steps := 0;
  var peak := n;
  while not n.isOne do begin
    if n.isEven then n := n shr 1
    else n := 3 * n + 1;
    if n > peak then peak := n;
    inc(steps);
  end;
  writeln($'reached 1 in {steps} steps');
  writeln($'peak value: {peak}');
  writeln($'peak digits: {peak.digitCount}');
  {$ifdef WINDOWS}readln;{$endif}
end.
