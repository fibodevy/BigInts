program type_bridges;

// moving between UBigInt and BigInt

{$mode unleashed}

uses SysUtils, BigInts;

begin
  // UBigInt -> BigInt always works
  var u: UBigInt := '340282366920938463463374607431768211456';
  var s := u.toBigInt;
  writeln($'{-s}');

  // BigInt -> UBigInt only for non-negatives
  var back := (-(-s)).toUBigInt;
  writeln(back = u); // TRUE
  try
    var oops := BigInt(-1).toUBigInt;
  except
    on e: ERangeError do writeln('negative: ', e.Message);
  end;

  // implicit widening in expressions: UBigInt slots into BigInt arithmetic
  var mixed := BigInt(-5) * u;
  writeln($'{mixed.sign}'); // -1

  // explicit casts both ways
  writeln($'{UBigInt(s)}');
  writeln($'{BigInt(u)}');
  {$ifdef WINDOWS}readln;{$endif}
end.
