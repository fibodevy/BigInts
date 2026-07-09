program sqrt_mod_n;

// square roots modulo a composite: factor, lift, recombine with the CRT

{$mode unleashed}

uses BigInts;

begin
  // x^2 = 4 (mod 15) has four roots
  write('sqrt(4) mod 15:');
  for var r in UBigInt(4).sqrtModN(UBigInt(15)) do write($' {r}');
  writeln;

  // the Rabin cryptosystem lives on roots mod p*q
  var n: UBigInt := 3233;                  // 61 * 53
  var m: UBigInt := 1234;
  var c := m.sqr mod n;                    // "encrypt"
  write($'roots of {c} mod {n}:');
  var roots := c.sqrtModN(n);
  for var r in roots do write($' {r}');    // one of them is the message 1234
  writeln;

  // a non-residue yields no roots
  writeln($'sqrt(2) mod 3233 has {Length(UBigInt(2).sqrtModN(n))} roots');
  {$ifdef WINDOWS}readln;{$endif}
end.
