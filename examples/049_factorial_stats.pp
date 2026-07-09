program factorial_stats;

// exact integer worlds feeding the decimal analytics

{$mode unleashed}

uses BigInts;

begin
  var n := 1000;
  var f := UBigInt.factorial(LongWord(n));
  writeln($'1000! has {f.digitCount} digits');

  // log10 through BigDecimal tells the same story analytically
  var lg := BigDecimal(f).log10(10);
  writeln($'log10(1000!) = {lg}');

  // Stirling's approximation: ln n! ~ n ln n - n + ln(2 pi n)/2
  var nd := BigDecimal(n);
  var stirling := nd * nd.ln(30) - nd + (BigDecimal.pi(30) * 2 * nd).ln(30) / 2;
  var exact := BigDecimal(f).ln(30);
  writeln($'ln 1000!  exact    {exact.rounded(-10)}');
  writeln($'          stirling {stirling.rounded(-10)}');
  writeln($'          error    {(exact - stirling).toScientific}');
  {$ifdef WINDOWS}readln;{$endif}
end.
