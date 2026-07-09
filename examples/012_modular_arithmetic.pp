program modular_arithmetic;

// modPow and modInverse, the building blocks of most number-theoretic code

{$mode unleashed}

uses SysUtils, BigInts;

begin
  var m: UBigInt := '1000000007'; // a popular prime modulus
  var base: UBigInt := 2;
  writeln($'2^1000 mod p = {base.modPow(1000, m)}');

  // Fermat: a^(p-1) = 1 (mod p) for prime p
  writeln($'{UBigInt(12345).modPow(m - 1, m)}'); // 1

  // modular inverse: a * a^-1 = 1 (mod m)
  var a: UBigInt := 123456;
  var inv := a.modInverse(m);
  writeln($'{a} * {inv} mod {m} = {a * inv mod m}');

  // no inverse when gcd(a, m) <> 1
  try
    var x := UBigInt(6).modInverse(UBigInt(9));
  except
    on e: EBigIntError do writeln('no inverse: ', e.Message);
  end;

  // huge exponents are fine: Montgomery keeps it fast
  var big := UBigInt.pow2(4096) - 1;
  writeln($'bits of 3^(2^4096-1) mod p: {UBigInt(3).modPow(big, m).bitLength}');
  {$ifdef WINDOWS}readln;{$endif}
end.
