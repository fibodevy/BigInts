program fibonacci_milestones;

// hunting indices: the first Fibonacci numbers with 100, 500, 1000 digits

{$mode unleashed}

uses BigInts;

begin
  // digits of F(n) grow linearly (by log10 of the golden ratio), so a
  // linear prediction plus a local walk finds each milestone fast
  for var target in [100, 500, 1000] do begin
    var n := LongWord((Int64(target) - 1) * 100000 div 20899 + 1); // 1/log10(phi) = 4.78497
    while UBigInt.fibonacci(n).digitCount >= LongWord(target) do dec(n);
    while UBigInt.fibonacci(n).digitCount < LongWord(target) do inc(n);
    writeln($'F({n}) is the first with {target} digits');
  end;

  // fast doubling makes million-index terms routine
  writeln($'F(1000000) has {UBigInt.fibonacci(1000000).digitCount} digits');
  {$ifdef WINDOWS}readln;{$endif}
end.
