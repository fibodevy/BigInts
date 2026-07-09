program roman_words;

// numbers for humans: Roman numerals and English words

{$mode unleashed}

uses BigInts;

const
  romans: array[0..4] of integer = (4, 49, 1994, 2026, 3888);
  words: array[0..3] of integer = (0, 42, 305, 1000000);

begin
  for var n in romans do writeln($'{n} = {BigInt(n).toRoman}');
  writeln;
  for var n in words do writeln($'{n} = {BigInt(n).toWords}');
  writeln($'-7 = {BigInt(-7).toWords}');
  var big: BigInt := '1234567890123';
  writeln($'{big} =');
  writeln($'  {big.toWords}');
  {$ifdef WINDOWS}readln;{$endif}
end.
