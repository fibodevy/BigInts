program machin_pi;

// Machin 1706: pi = 16 arctan(1/5) - 4 arctan(1/239), by hand with
// BigDecimal, checked against the built-in Chudnovsky pi

{$mode unleashed}

uses BigInts;

const
  DIGITS = 100;

begin
  var pi := BigDecimal(16) * BigDecimal(1).divide(5, DIGITS + 10).arctan(DIGITS + 8)
          - BigDecimal(4) * BigDecimal(1).divide(239, DIGITS + 10).arctan(DIGITS + 8);
  writeln($'machin: {pi.rounded(-DIGITS)}');
  writeln($'exact:  {BigDecimal.pi(DIGITS)}');
  writeln($'agree:  {(pi - BigDecimal.pi(DIGITS + 5)).abs < BigDecimal('1E-100')}');
  {$ifdef WINDOWS}readln;{$endif}
end.
