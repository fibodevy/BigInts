program gamma_erf;

// the gamma and error functions at arbitrary precision

{$mode unleashed}

uses BigInts;

begin
  // gamma generalizes the factorial: gamma(n) = (n-1)!
  writeln($'gamma(5)   = {BigDecimal(5).gamma(20)}');       // 24
  writeln($'gamma(1/2) = {BigDecimal('0.5').gamma(40)}');   // sqrt(pi)
  writeln($'0.5!       = {BigDecimal('0.5').factorial(40)}');
  writeln($'4.5!       = {BigDecimal('4.5').factorial(30)}');

  // the error function underlies the normal distribution
  writeln($'erf(1)     = {BigDecimal(1).erf(40)}');
  writeln($'erfc(3)    = {BigDecimal(3).erfc(30).toScientific}');

  // P(|Z| < 1 sigma) = erf(1/sqrt2) for a standard normal
  var oneOverSqrt2 := BigDecimal(1).divide(BigDecimal(2).sqrt(40), 40);
  writeln($'P(within 1 sigma) = {(oneOverSqrt2.erf(30) * 100).rounded(-4)}%'); // 68.27%
  {$ifdef WINDOWS}readln;{$endif}
end.
