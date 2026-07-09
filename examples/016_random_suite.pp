program random_suite;

// pluggable generators, deterministic seeding, uniform ranges

{$mode unleashed}

uses BigInts;

begin
  // reproducible: same seed, same stream
  BigIntRandomSeed(42);
  writeln(UBigInt.random(128).toHex);
  BigIntRandomSeed(42);
  writeln(UBigInt.random(128).toHex); // identical

  // pick the backend
  BigIntRngAlgo := rngPcg64;
  BigIntRandomSeed(42);
  writeln('pcg64:    ', UBigInt.random(64).toHex);
  BigIntRngAlgo := rngSplitMix64;
  BigIntRandomSeed(42);
  writeln('splitmix: ', UBigInt.random(64).toHex);
  BigIntRngAlgo := rngXoshiro256ss;

  // uniform below a bound and in a closed range (rejection sampling)
  BigIntRandomSeed(1);
  writeln($'{UBigInt.randomBelow(UBigInt.ten ** 20)}');
  writeln($'{BigInt.randomRange(-100, 100)}');
  var lo := -(BigInt.ten ** 30);
  writeln($'{BigInt.randomRange(lo, -lo)}');

  // rngOS reads fresh OS entropy every call: unseedable, for key material
  BigIntRngAlgo := rngOS;
  writeln($'os entropy bits: {UBigInt.random(256).bitLength}');
  BigIntRngAlgo := rngXoshiro256ss;
  {$ifdef WINDOWS}readln;{$endif}
end.
