program signed_shifts;

// shl keeps the sign, shr is an arithmetic shift toward minus infinity

{$mode unleashed}

uses BigInts;

begin
  writeln($'{BigInt(-3) shl 4}');     // -48
  writeln($'{BigInt(-8) shr 1}');     // -4
  writeln($'{BigInt(-7) shr 1}');     // -4, rounds toward minus infinity
  writeln($'{BigInt(7) shr 1}');      // 3
  writeln($'{BigInt(-1) shr 100}');   // -1 forever, like an infinite sign

  // shifting by big counts is fine
  var x := BigInt(1) shl 1000;
  writeln($'{x.bitLength}');          // 1001
  writeln($'{x shr 999}');            // 2
  {$ifdef WINDOWS}readln;{$endif}
end.
