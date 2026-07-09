program twos_complement;

// bitwise operators on negatives behave like Python ints: two's complement
// with infinite sign extension

{$mode unleashed}

uses BigInts;

begin
  writeln($'{BigInt(-1) and BigInt($FF)}');   // 255: -1 is all ones
  writeln($'{not BigInt(0)}');                // -1
  writeln($'{not BigInt(41)}');               // -42, not x = -x-1
  writeln($'{BigInt(-16) or BigInt(1)}');     // -15
  writeln($'{BigInt(-2) xor BigInt(-3)}');    // 3

  // testBit on a negative sees the infinite one-run
  var n: BigInt := -1;
  writeln(n.testBit(0), ' ', n.testBit(1000));   // TRUE TRUE
  writeln($'{BigInt(-2).lowestSetBit}');         // 1

  // setBit and clearBit edit the two's complement image
  var x: BigInt := -256;
  x.setBit(0);
  writeln($'{x}');                            // -255
  x.clearBit(0);
  writeln($'{x}');                            // -256

  // for negatives popCount counts bits differing from the sign bit (Java style)
  writeln($'{BigInt(-1).popCount} {BigInt(255).popCount}'); // 0 8
  {$ifdef WINDOWS}readln;{$endif}
end.
