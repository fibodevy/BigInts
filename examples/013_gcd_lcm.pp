program gcd_lcm;

// greatest common divisor (Lehmer) and least common multiple

{$mode unleashed}

uses BigInts;

begin
  var a := UBigInt.factorial(30);
  var b := UBigInt.pow2(100);
  writeln($'gcd = {a.gcd(b)}');                         // the power of two inside 30!
  writeln($'lcm(4, 6) = {UBigInt(4).lcm(UBigInt(6))}'); // 12

  // gcd * lcm = a * b
  var x: UBigInt := 987654321;
  var y: UBigInt := 123456789;
  writeln(x.gcd(y) * x.lcm(y) = x * y); // TRUE

  // coprime check
  writeln($'gcd(35, 64) = {UBigInt(35).gcd(UBigInt(64))}'); // 1, coprime

  // consecutive fibonacci numbers are always coprime
  writeln(UBigInt.fibonacci(1000).gcd(UBigInt.fibonacci(1001)).isOne);
  {$ifdef WINDOWS}readln;{$endif}
end.
