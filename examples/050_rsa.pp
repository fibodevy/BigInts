program rsa;

// RSA with a 2048-bit key: the public operations (encrypt, verify) run on the
// fast variable-time modPow, while the secret-exponent operations (decrypt,
// sign) go through the constant-time TModRingSec so their timing does not leak
// the private key. padding-free textbook RSA - a real system also wraps the
// message in OAEP and the signature in PSS, which live above this layer.

{$mode unleashed}

uses BigInts;

begin
  BigIntRandomSeed(20260709);

  // keygen: two 1024-bit primes give a 2048-bit modulus
  var p := UBigInt.randomPrime(1024);
  var q := UBigInt.randomPrime(1024);
  var n := p * q;
  var e: UBigInt := 65537;
  // private exponent over the Carmichael totient lcm(p-1, q-1)
  var d := e.modInverse((p - 1).lcm(q - 1));
  writeln($'modulus bits: {n.bitLength}');

  // one constant-time ring on n handles every private-key operation
  var priv := TModRingSec.create(n);

  // encrypt with the public exponent, decrypt with the secret one
  var msg: UBigInt := '0x48656C6C6F2C20556E6C656173686564'; // "Hello, Unleashed"
  var cipher := msg.modPow(e, n);
  var plain := priv.modPow(cipher, d);
  writeln($'decrypt roundtrip ok: {plain = msg}');

  // sign with the secret exponent, verify with the public one
  var signature := priv.modPow(msg, d);
  writeln($'signature verifies: {signature.modPow(e, n) = msg}');
  {$ifdef WINDOWS}readln;{$endif}
end.
