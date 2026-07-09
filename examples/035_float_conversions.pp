program float_conversions;

// two ways to read a float: the shortest decimal that round-trips, or the
// exact binary value

{$mode unleashed}

uses BigInts;

begin
  // what you see is what fromDouble gives
  writeln($'{BigDecimal.fromDouble(0.1)}');        // 0.1
  writeln($'{BigDecimal.fromDouble(1/3)}');        // 0.3333333333333333

  // what the machine really stores
  writeln($'{BigDecimal.fromDoubleExact(0.1)}');
  // 0.1000000000000000055511151231257827021181583404541015625

  // powers of two are exact either way
  writeln($'{BigDecimal.fromDoubleExact(0.375)}'); // 0.375

  // explicit casts use the shortest form
  writeln($'{BigDecimal(2.5)}');

  // and back: correctly rounded to the nearest float, ties to even
  writeln(BigDecimal('0.1').toDouble = 0.1);       // TRUE
  writeln(BigDecimal('1E400').toDouble);           // +Inf
  writeln(BigDecimal('1E-400').toDouble);          // 0

  // Single works the same
  writeln($'{BigDecimal.fromSingle(Single(0.1))}');   // 0.1
  writeln(BigDecimal('0.1').toSingle = Single(0.1));  // TRUE
  {$ifdef WINDOWS}readln;{$endif}
end.
