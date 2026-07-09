program powers_and_roots;

// squares, integer roots and the perfect-square test

{$mode unleashed}

uses BigInts;

begin
  var n: UBigInt := '123456789';
  writeln($'{n.sqr}');
  writeln($'{n.pow(5)}');
  writeln($'{UBigInt(3) ** 100}');

  // integer (floor) roots
  writeln($'{n.sqr.sqrt = n}');                 // TRUE
  writeln($'{UBigInt(1000).sqrt}');             // 31
  writeln($'{UBigInt(1000000).nthRoot(3)}');    // 100
  writeln($'{(UBigInt(7) ** 30).nthRoot(30)}'); // 7

  // sqrtRem gives the exact remainder: n = root^2 + rem
  var (root, rem) := UBigInt(1000).sqrtRem;
  writeln($'{root}^2 + {rem} = {root.sqr + rem}');

  writeln(n.sqr.isPerfectSquare, ' ', UBigInt(1000).isPerfectSquare); // TRUE FALSE
  writeln($'{UBigInt.pow2(10)}');                                     // 1024
  {$ifdef WINDOWS}readln;{$endif}
end.
