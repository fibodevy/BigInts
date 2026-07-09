program bit_operations;

// bit access and bitwise operators on the unsigned type

{$mode unleashed}

uses BigInts;

begin
  var x := UBigInt.pow2(100) - 1; // a hundred ones
  writeln($'bitLength {x.bitLength}  popCount {x.popCount}');
  writeln($'lowest set bit: {x.lowestSetBit}');

  x.clearBit(0);
  writeln($'after clearBit(0): lowest {x.lowestSetBit}');
  x.setBit(200);
  writeln($'after setBit(200): bitLength {x.bitLength}');
  x.flipBit(200);
  writeln($'after flipBit(200): bitLength {x.bitLength}');
  writeln(x.testBit(50), ' ', x.bits[0]); // TRUE FALSE

  // shifts and masks
  var m: UBigInt := '0xFF00FF00FF00FF00';
  writeln((m shr 8).toHex);
  writeln((m shl 4).toHex);
  writeln((m and UBigInt($FFFF)).toHex);
  writeln((m or UBigInt(255)).toHex);
  writeln((m xor m).toString); // 0

  // finite-width complement: UBigInt has no "not" (the infinite complement
  // of an unsigned value does not exist), complement(width) does the job
  writeln(UBigInt($F0).complement(8).toHex); // F
  writeln(x.isPowerOfTwo, ' ', UBigInt.pow2(77).isPowerOfTwo);
  {$ifdef WINDOWS}readln;{$endif}
end.
