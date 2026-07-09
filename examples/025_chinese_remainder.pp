program chinese_remainder;

// crt solves simultaneous congruences with pairwise coprime moduli

{$mode unleashed}

uses BigInts;

begin
  // x = 2 (mod 3), x = 3 (mod 5), x = 2 (mod 7)
  var x := BigInt.crt([BigInt(2), BigInt(3), BigInt(2)], [BigInt(3), BigInt(5), BigInt(7)]);
  writeln($'{x}'); // 23

  // verify
  writeln($'{x mod 3} {x mod 5} {x mod 7}');

  // big moduli: reconstruct a secret from residues
  var m1: BigInt := '1000000000000000003';
  var m2: BigInt := '1000000000000000009';
  var secret: BigInt := '123456789012345678901234567890';
  var r1 := secret mod m1;
  var r2 := secret mod m2;
  var back := BigInt.crt([r1, r2], [m1, m2]);
  writeln(back = secret); // TRUE
  {$ifdef WINDOWS}readln;{$endif}
end.
