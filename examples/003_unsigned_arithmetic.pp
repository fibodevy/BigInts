program unsigned_arithmetic;

// UBigInt arithmetic: every operator a plain unsigned integer has

{$mode unleashed}

uses SysUtils, BigInts;

begin
  var a: UBigInt := '10000000000000000000000000000000000';
  var b: UBigInt := 12345;
  writeln($'{a + b}');
  writeln($'{a - b}');
  writeln($'{a * b}');
  writeln($'{a div b}  rem {a mod b}');
  writeln($'{UBigInt(2) ** 200}');
  inc(b);
  writeln($'{b}'); // 12346

  // compound assignments work too
  var acc: UBigInt := 1;
  for var i := 1 to 10 do acc *= i;
  writeln($'10! = {acc}'); // 3628800

  // dropping below zero raises ERangeError instead of wrapping
  try
    var oops := b - a;
  except
    on e: ERangeError do writeln('underflow: ', e.Message);
  end;
  {$ifdef WINDOWS}readln;{$endif}
end.
