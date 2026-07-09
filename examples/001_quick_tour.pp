program quick_tour;

// the three BigInts value types in one minute

{$mode unleashed}

uses BigInts;

begin
  // UBigInt: unsigned, unlimited
  var u: UBigInt := '123456789012345678901234567890';
  writeln($'{u * u}');

  // BigInt: signed, two's complement bitwise
  var i: BigInt := '-0xDEAD_BEEF';
  writeln($'{i} and 0xFF = {i and BigInt($FF)}');

  // BigDecimal: exact decimal floats
  var d: BigDecimal := '0.1';
  writeln($'{d + BigDecimal('0.2')}');           // 0.3, exactly
  writeln($'{BigDecimal(1) / 3}');               // 0.333333333333333333
  writeln($'{BigDecimal.pi(40)}');               // 3.1415926535897932384626433832795028841972

  // they mix freely
  writeln($'{BigDecimal(u) / i}');
  {$ifdef WINDOWS}readln;{$endif}
end.
