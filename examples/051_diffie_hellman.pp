program diffie_hellman;

// two parties agree on a secret over a public channel

{$mode unleashed}

uses BigInts;

begin
  BigIntRandomSeed(7);

  // a public safe prime group (RFC 3526, 1536-bit MODP truncated demo:
  // here a fresh 512-bit prime for speed) and generator
  var p := UBigInt.randomPrime(512);
  var g: UBigInt := 2;

  // each side keeps a private exponent
  var alice := UBigInt.random(256);
  var bob := UBigInt.random(256);

  // and publishes g^x mod p
  var pubA := g.modPow(alice, p);
  var pubB := g.modPow(bob, p);

  // both arrive at the same shared key
  var keyA := pubB.modPow(alice, p);
  var keyB := pubA.modPow(bob, p);
  writeln($'shared secrets match: {keyA = keyB}');
  writeln($'key bits: {keyA.bitLength}');
  {$ifdef WINDOWS}readln;{$endif}
end.
