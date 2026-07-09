program bezout_gcdext;

// extended Euclid: g = a*x + b*y, the engine behind modular inverses

{$mode unleashed}

uses BigInts;

begin
  var a: BigInt := 240;
  var b: BigInt := 46;
  var (g, x, y) := a.gcdExt(b);
  writeln($'gcd = {g}, x = {x}, y = {y}');
  writeln(a * x + b * y = g); // TRUE

  // works at any size
  var p: BigInt := '1000000000000000000000000000057';
  var q: BigInt := '999999999999999999999999999943';
  var (g2, x2, y2) := p.gcdExt(q);
  writeln($'gcd = {g2}');
  writeln(p * x2 + q * y2 = g2); // TRUE

  // when gcd is 1, x is the modular inverse of a mod b
  var (g3, inv, dummy) := BigInt(17).gcdExt(BigInt(3120));
  writeln($'17^-1 mod 3120 = {inv.floorMod(BigInt(3120))}'); // 2753 (the RSA textbook example)
  {$ifdef WINDOWS}readln;{$endif}
end.
