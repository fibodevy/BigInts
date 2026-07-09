program division_flavours;

// one division, both results: divMod returns a (q, r) tuple

{$mode unleashed}

uses BigInts;

begin
  var a: UBigInt := '1000000000000000000000000000';
  var (q, r) := a.divMod(UBigInt(7));
  writeln($'{q} rem {r}');

  // ceilDiv rounds the quotient up
  writeln($'{UBigInt(7).ceilDiv(UBigInt(2))}');  // 4
  writeln($'{UBigInt(6).ceilDiv(UBigInt(2))}');  // 3

  // "/" on the integer types is just div (C-family convention)
  writeln($'{a / 7 = a div 7}'); // TRUE

  // exactness check with the tuple
  var (q2, r2) := (a * 7).divMod(UBigInt(7));
  writeln($'{r2.isZero} {q2 = a}'); // TRUE TRUE
  {$ifdef WINDOWS}readln;{$endif}
end.
