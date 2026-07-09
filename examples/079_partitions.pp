program partitions_demo;

// p(n): the number of ways to write n as a sum of positive integers

{$mode unleashed}

uses BigInts;

begin
  for var n in [5, 10, 50, 100] do writeln($'p({n}) = {UBigInt.partitions(LongWord(n))}');
  // p(5) = 7:  5, 4+1, 3+2, 3+1+1, 2+2+1, 2+1+1+1, 1+1+1+1+1

  // Ramanujan's congruence: p(5k+4) is divisible by 5
  write('p(5k+4) mod 5:');
  for var k := 0 to 6 do write($' {UBigInt.partitions(LongWord(5 * k + 4)) mod 5}');
  writeln;

  // they grow fast
  writeln($'p(1000) has {UBigInt.partitions(1000).digitCount} digits');
  {$ifdef WINDOWS}readln;{$endif}
end.
