program signed_basics;

// BigInt: signs, magnitudes and the helpers around them

{$mode unleashed}

uses BigInts;

begin
  var a: BigInt := '-123456789012345678901234567890';
  writeln($'{a.sign} {a.isNegative} {a.isPositive}'); // -1 TRUE FALSE
  writeln($'{a.abs}');
  writeln($'{a.magnitude}');               // absolute value as UBigInt
  a.negate;
  writeln($'{a.sign}');                    // 1

  writeln($'{BigInt(-7) + 3}');            // -4
  writeln($'{BigInt(-7) * -3}');           // 21
  writeln($'{-BigInt.ten ** 20}');
  writeln($'{BigInt(0).sign} {BigInt.minusOne.sign}'); // 0 -1

  var b: BigInt := 5;
  b -= 8;
  writeln($'{b}');                         // -3
  writeln($'{b.min(2)} {b.max(2)}');       // -3 2
  {$ifdef WINDOWS}readln;{$endif}
end.
