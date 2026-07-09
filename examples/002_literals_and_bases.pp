program literals_and_bases;

// literal prefixes, digit separators and every base from 2 to 36

{$mode unleashed}

uses BigInts;

begin
  var a: UBigInt := '123_456_789_000_000_000_000_000';
  var b: UBigInt := '$FF_FF';        // hex, $ or 0x
  var c: UBigInt := '%1010_1010';    // binary, % or 0b
  var d: UBigInt := '&777';          // octal, & or 0o
  writeln(a.toStringGrouped);        // 123_456_789_000_000_000_000_000
  writeln($'{b} {c} {d}');           // 65535 170 511

  // parse and format in any base
  var z := UBigInt.parse('zz', 36);
  writeln(z.toString);               // 1295
  writeln(z.toString(36));           // ZZ
  writeln(z.toHex, ' ', z.toBin, ' ', z.toOct);

  // negative literals work on BigInt
  var n: BigInt := '-0b1111';
  writeln($'{n} = {n.toHex} in hex'); // -15 = -F in hex
  {$ifdef WINDOWS}readln;{$endif}
end.
