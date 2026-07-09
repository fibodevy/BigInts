program rsa_toy;

// the RSA textbook flow: keygen, encrypt, decrypt, sign

{$mode unleashed}

uses BigInts;

begin
  BigIntRandomSeed(20260709);

  // two primes and the usual arithmetic
  var p := UBigInt.randomPrime(512);
  var q := UBigInt.randomPrime(512);
  var n := p * q;
  var phi := (p - 1) * (q - 1);
  var e: UBigInt := 65537;
  var d := e.modInverse(phi);
  writeln($'modulus bits: {n.bitLength}');

  // encrypt / decrypt
  var msg: UBigInt := '0x48656C6C6F2C20756E6C65617368656421'; // "Hello, unleashed!"
  var cipher := msg.modPow(e, n);
  var plain := cipher.modPow(d, n);
  writeln($'roundtrip ok: {plain = msg}');

  // sign / verify is the same trick backwards
  var signature := msg.modPow(d, n);
  writeln($'signature ok: {signature.modPow(e, n) = msg}');
  {$ifdef WINDOWS}readln;{$endif}
end.
