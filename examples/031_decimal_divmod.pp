program decimal_divmod;

// integer quotient and exact remainder on decimals

{$mode unleashed}

uses BigInts;

begin
  writeln($'{BigDecimal('7.5') div BigDecimal(2)}');   // 3
  writeln($'{BigDecimal('7.5') mod BigDecimal(2)}');   // 1.5

  var (q, r) := BigDecimal('10.5').divMod(BigDecimal('3'));
  writeln($'q = {q}, r = {r}');            // 3, 1.5
  writeln(q * 3 + r = BigDecimal('10.5')); // TRUE

  // remainder takes the dividend sign, like the integer types
  writeln($'{BigDecimal('-7.5') mod BigDecimal(2)}'); // -1.5

  // how many 0.75 l bottles fit a 10 l canister
  var (bottles, left) := BigDecimal(10).divMod(BigDecimal('0.75'));
  writeln($'{bottles} bottles, {left} l left');
  {$ifdef WINDOWS}readln;{$endif}
end.
