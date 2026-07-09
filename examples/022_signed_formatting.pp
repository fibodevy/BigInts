program signed_formatting;

// negatives format as sign plus magnitude in every base

{$mode unleashed}

uses BigInts;

begin
  var n: BigInt := -255;
  writeln(n.toString);                // -255
  writeln(n.toHex);                   // -FF
  writeln(n.toBin);                   // -11111111
  writeln(n.toOct);                   // -377
  writeln(n.toString(36));            // -73

  writeln(BigInt.parse('-FF', 16).toString);      // -255
  writeln(BigInt.parse('-0b1010').toString);      // -10
  writeln(BigInt('-123456789').toStringGrouped);  // -123_456_789
  writeln($'{BigInt('-123456789').digitCount} digits');
  {$ifdef WINDOWS}readln;{$endif}
end.
