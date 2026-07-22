program calculator;

// calc evaluates a whole expression from a string, at any precision

{$mode unleashed}

uses SysUtils, BigInts;

begin
  // arithmetic with the usual precedence and a right-associative power
  writeln($'{BigDecimal.calc('2 + 3 * 4')}');           // 14
  writeln($'{BigDecimal.calc('2^3^2')}');               // 512
  writeln($'{BigDecimal.calc('-2^2')}');                // -4

  // "/" is real division, "div" and "mod" are the integer pair
  writeln($'{BigDecimal.calc('10 / 4')}');              // 2.5
  writeln($'{BigDecimal.calc('10 div 3')}');            // 3
  writeln($'{BigDecimal.calc('10 mod 3')}');            // 1

  // functions and constants, precision picked per call
  writeln($'{BigDecimal.calc('sqrt(2)', 40)}');
  writeln($'{BigDecimal.calc('sin(pi/6)', 30)}');       // 0.5
  writeln($'{BigDecimal.calc('log(1000)')}');           // 3 (log is base 10, like a spreadsheet)
  writeln($'{BigDecimal.calc('5!')}');                  // 120
  writeln($'{BigDecimal.calc('gcd(0.25, 0.15)')}');     // 0.05
  writeln($'{BigDecimal.calc('asinh(1)', 30)}');        // 0.881373587...
  writeln($'{BigDecimal.calc('atanh(0.5)', 30)}');      // 0.549306144...
  writeln($'{BigDecimal.calc('sign(-7)')}');            // -1
  writeln($'{BigDecimal.calc('frac(3.25)')}');          // 0.25

  // the whole thing at 50 digits
  writeln($'{BigDecimal.calc('(1 + sqrt(5)) / 2', 50)}'); // the golden ratio

  // several spellings for power all work
  writeln(BigDecimal.calc('2^10') = BigDecimal.calc('2**10'));
  writeln(BigDecimal.calc('pow(2, 10)').toString); // 1024

  // tryCalc never raises: it returns false on a bad expression
  var v: BigDecimal;
  if BigDecimal.tryCalc('2 + )', v) then writeln(v.toString)
  else writeln('rejected');

  // a syntax error from calc carries the character position
  try
    BigDecimal.calc('1 + sqrt(2, 3)');
  except
    on e: EConvertError do writeln(e.Message);
  end;
  {$ifdef WINDOWS}readln;{$endif}
end.
