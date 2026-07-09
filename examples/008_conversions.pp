program conversions;

// converting to and from machine types, safely

{$mode unleashed}

uses SysUtils, BigInts;

begin
  var small: UBigInt := 42;
  writeln(small.toInt64 + 1); // 43
  writeln(small.toInteger, ' ', small.toCardinal, ' ', small.toQWord);

  var big := UBigInt.pow2(100);
  writeln(big.fitsInInt64, ' ', big.fitsInQWord); // FALSE FALSE
  try
    var x := big.toInt64;
  except
    on e: ERangeError do writeln('too big: ', e.Message);
  end;

  // exact integer casts never round through Double
  var q := UBigInt(QWord(18446744073709551615));
  writeln($'{q}'); // 18446744073709551615

  // toDouble rounds correctly to the nearest float
  writeln(big.toDouble); // 1.2676506002282294E30

  // Double -> UBigInt truncates (explicit cast required)
  writeln($'{UBigInt(3.99)}'); // 3
  {$ifdef WINDOWS}readln;{$endif}
end.
