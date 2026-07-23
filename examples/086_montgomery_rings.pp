program montgomery_rings;

// TModRing binds one fixed modulus and reuses its Montgomery setup across many
// operations - faster than a fresh modPow/modInverse per call when the modulus
// stays put. TModRingSec is the constant-time twin for secret exponents.

{$mode unleashed}

uses BigInts;

begin
  var m: UBigInt := '1000000007';
  var ring := TModRing.create(m);

  // pow and inv are self-contained: plain values in, plain result out
  writeln($'2^1000 mod m = {ring.pow(UBigInt(2), UBigInt(1000))}');
  var inv := ring.inv(UBigInt(123456));
  writeln($'123456 * inv mod m = {(UBigInt(123456) * inv) mod m}'); // 1

  // mul/sqr run in the Montgomery domain: convert in, compute, convert out.
  // worth it when the same values feed a chain of products
  var a := ring.toMont(UBigInt(123456));
  var b := ring.toMont(UBigInt(789012));
  var prod := ring.fromMont(ring.mul(a, b));
  writeln($'123456 * 789012 mod m = {prod}');

  // add/sub take reduced operands and skip the domain round-trip
  writeln($'sum mod m = {ring.add(UBigInt(900000000), UBigInt(200000000))}');

  // TModRingSec: same modular exponentiation, constant-time for a secret exponent
  var sec := TModRingSec.create(m);
  var secret: UBigInt := 987654321;
  writeln($'sec matches fast: {sec.modPow(UBigInt(2), secret) = ring.pow(UBigInt(2), secret)}');
  {$ifdef WINDOWS}readln;{$endif}
end.
