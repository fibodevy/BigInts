program continued_fractions;

// continued fractions: exact expansions and best rational approximations

{$mode unleashed}

uses BigInts;

begin
  // a rational unfolds and folds back
  var cf := BigInt.continuedFraction(BigInt(415), BigInt(93));
  write('415/93 = [');
  for var i := 0 to High(cf) do write(if i = 0 then $'{cf[i]}' else $'; {cf[i]}');
  writeln(']');
  var (n, d) := BigInt.fromContinuedFraction(cf);
  writeln($'rebuilt: {n}/{d}');

  // convergents of pi are the classic approximations
  var pcf := BigDecimal.pi(40).continuedFraction(8);
  writeln('pi convergents:');
  for var k := 1 to 5 do begin
    var (pn, pd) := BigInt.fromContinuedFraction(Copy(pcf, 0, k));
    writeln($'  {pn}/{pd}'); // 3, 22/7, 333/106, 355/113, ...
  end;
  {$ifdef WINDOWS}readln;{$endif}
end.
