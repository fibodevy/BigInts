program bell_stirling;

// set partitions: Bell and Stirling numbers

{$mode unleashed}

uses BigInts;

begin
  // Stirling2(n, k): partitions of an n-set into k blocks
  writeln('Stirling numbers of the second kind, S(5, k):');
  for var k := 0 to 5 do write($' {UBigInt.stirling2(5, LongWord(k))}');
  writeln;

  // Bell(n) = sum over k of S(n, k): all partitions of an n-set
  write('Bell numbers:');
  for var n := 0 to 10 do write($' {UBigInt.bell(LongWord(n))}');
  writeln;

  // check Bell = sum of Stirling2
  var s := UBigInt.zero;
  for var k := 0 to 6 do s := s + UBigInt.stirling2(6, LongWord(k));
  writeln($'sum S(6, k) = {s} = Bell(6) = {UBigInt.bell(6)}');

  // signed Stirling1: sum of |s(n, k)| = n!
  var t := BigInt.zero;
  for var k := 0 to 5 do t := t + BigInt.stirling1(5, LongWord(k)).abs;
  writeln($'sum |s(5, k)| = {t} = 5! = {BigInt.factorial(5)}');
  {$ifdef WINDOWS}readln;{$endif}
end.
