program formatting;

// output shapes: bases, grouping, digit counts

{$mode unleashed}

uses BigInts;

begin
  var n := UBigInt.factorial(30);
  writeln(n.toString);
  writeln(n.toStringGrouped);              // underscores every 3 digits
  writeln(n.toStringGrouped(' ', 5));      // custom separator and group
  writeln($'{n.digitCount} decimal digits, {n.bitLength} bits');
  writeln(n.toHex);
  writeln(n.toString(36));
  writeln(UBigInt(1000000).toBin);

  // interpolation calls toString for you
  writeln($'2^64 = {UBigInt.pow2(64)}');

  // string cast does the same
  var s := string(n);
  writeln(Length(s), ' characters');
  {$ifdef WINDOWS}readln;{$endif}
end.
