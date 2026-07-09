program division_precision;

// decimal division: exact when it can be, rounded where you say

{$mode unleashed}

uses BigInts;

begin
  writeln($'{BigDecimal(1) / 8}');     // 0.125, exact quotients stay exact
  writeln($'{BigDecimal(100) / 4}');   // 25

  // "/" carries 18 fractional digits plus a hidden guard digit
  var third := BigDecimal(1) / 3;
  writeln($'{third}');                 // 0.333333333333333333
  writeln($'{third * 3}');             // 1 - the guard digit rounds the display
  writeln(third * 3 < 1);              // TRUE: the value still knows the truth

  // pick your own precision
  writeln($'{BigDecimal(2).divide(3, 50)}');
  writeln($'{BigDecimal(2).divide(3, 4)}');

  // tiny quotients keep significant digits instead of collapsing to zero
  writeln((BigDecimal('1E-30') / 7).toScientific);
  {$ifdef WINDOWS}readln;{$endif}
end.
