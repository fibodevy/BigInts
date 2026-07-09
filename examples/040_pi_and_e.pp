program pi_and_e;

// famous constants at whatever precision you ask for

{$mode unleashed}

uses BigInts;

begin
  writeln($'{BigDecimal.pi(60)}');
  writeln($'{BigDecimal.e(60)}');

  // a couple hundred digits cost nothing (Chudnovsky + the fast core)
  writeln($'{BigDecimal.pi(200)}');

  // pi is cached: the second call at lower precision reuses the digits
  writeln($'{BigDecimal.pi(50)}');

  // e is also exp(1)
  writeln(BigDecimal(1).exp(40) = BigDecimal.e(40));

  // and the classics hold
  writeln($'pi * r^2 for r = 2.5: {(BigDecimal.pi(30) * BigDecimal('6.25')).rounded(-10)}');
  {$ifdef WINDOWS}readln;{$endif}
end.
