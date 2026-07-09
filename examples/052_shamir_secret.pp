program shamir_secret;

// Shamir secret sharing: split a secret into 5 shares, any 3 rebuild it

{$mode unleashed}

uses BigInts;

const
  SHARES = 5;
  NEED = 3;

begin
  BigIntRandomSeed(123);
  var p := UBigInt.randomPrime(256); // field modulus
  var secret := UBigInt.randomBelow(p);

  // random polynomial f(x) = secret + a1 x + a2 x^2 (degree NEED-1)
  var a1 := UBigInt.randomBelow(p);
  var a2 := UBigInt.randomBelow(p);
  var xs: array of UBigInt;
  var ys: array of UBigInt;
  SetLength(xs, SHARES);
  SetLength(ys, SHARES);
  for var i := 0 to SHARES - 1 do begin
    xs[i] := UBigInt(i + 1);
    ys[i] := (secret + a1 * xs[i] + a2 * xs[i] * xs[i]) mod p;
  end;

  // rebuild from shares 0, 2, 4 with Lagrange interpolation at x = 0
  var pick: array of integer := [0, 2, 4];
  var acc := UBigInt.zero;
  for var i in pick do begin
    var num := UBigInt.one;
    var den := UBigInt.one;
    for var j in pick do
      if j <> i then begin
        num := num * xs[j] mod p;                       // (0 - xj) up to sign
        den := den * ((p + xs[j] - xs[i]) mod p) mod p; // (xi - xj) mod p
      end;
    // the pair of negations cancels, so plain products work
    acc := (acc + ys[i] * num mod p * den.modInverse(p)) mod p;
  end;
  writeln($'recovered: {acc = secret}');
  {$ifdef WINDOWS}readln;{$endif}
end.
