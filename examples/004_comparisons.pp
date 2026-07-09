program comparisons;

// comparison operators and helpers, with plain integers on either side

{$mode unleashed}

uses BigInts;

begin
  var a: UBigInt := '340282366920938463463374607431768211456'; // 2^128
  var b := UBigInt.pow2(128);
  writeln(a = b);                    // TRUE
  writeln(a < b + 1);                // TRUE
  writeln(a >= 12345);               // mixed with plain integers
  writeln(1 < a);

  writeln(a.compare(b));             // 0
  writeln(a.equals(b));              // TRUE
  writeln($'{a.min(12345)} {a.max(b + 5)}');

  // three-way compare drives sorting
  var xs: array of UBigInt := [UBigInt(30), UBigInt(7), UBigInt(100), UBigInt(1)];
  for var i := 0 to High(xs) - 1 do
    for var j := 0 to High(xs) - 2 - i do
      if xs[j] > xs[j + 1] then xs[j].swap(xs[j + 1]);
  for var x in xs do write($'{x} '); // 1 7 30 100
  writeln;
  {$ifdef WINDOWS}readln;{$endif}
end.
