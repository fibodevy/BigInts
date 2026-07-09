program decimal_conversions;

// decimals to machine integers: exact or not at all

{$mode unleashed}

uses SysUtils, BigInts;

begin
  writeln(BigDecimal('42').toInt64 + 1);       // 43
  writeln(BigDecimal('4.2E1').toInteger);      // 42
  writeln($'{BigDecimal('12345678901234567890123').toBigInt}');

  writeln(BigDecimal('42').fitsInInt64);       // TRUE
  writeln(BigDecimal('42.5').fitsInInt64);     // FALSE, not integral

  // fractional values refuse the exact conversions...
  try
    var x := BigDecimal('1.5').toInt64;
  except
    on e: ERangeError do writeln('not integral: ', e.Message);
  end;

  // ...use the explicit roundings instead
  writeln($'{BigDecimal('1.5').trunc.toInt64}');   // 1
  writeln($'{BigDecimal('1.5').round.toInt64}');   // 2

  // BigInt cast is the exact path too
  writeln($'{BigInt(BigDecimal('-99'))}');
  {$ifdef WINDOWS}readln;{$endif}
end.
