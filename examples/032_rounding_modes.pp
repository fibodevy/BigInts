program rounding_modes;

// six rounding modes at any decimal position

{$mode unleashed}

uses BigInts;

procedure row(const s: string);
begin
  var x: BigDecimal := s;
  writeln(s:7, ':', string(x.rounded(0, bdrTrunc)):7, string(x.rounded(0, bdrCeil)):7, string(x.rounded(0, bdrFloor)):7, string(x.rounded(0, bdrRound)):7, string(x.rounded(0, bdrHalfUp)):7, string(x.rounded(0, bdrHalfEven)):7);
end;

begin
  writeln('value':7, ':', 'trunc':7, 'ceil':7, 'floor':7, 'round':7, 'h-up':7, 'h-even':7);
  row('2.5');
  row('-2.5');
  row('3.5');
  row('2.4');
  row('-2.6');

  // positions: negative digits go right of the point, positive left
  var pi: BigDecimal := '3.14159265';
  writeln($'{pi.rounded(-4)}');                   // 3.1416
  writeln($'{pi.rounded(-2)}');                   // 3.14
  writeln($'{BigDecimal('987.654').rounded(2)}'); // 1000
  {$ifdef WINDOWS}readln;{$endif}
end.
