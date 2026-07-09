program trigonometry;

// sin, cos, tan in radians at any precision

{$mode unleashed}

uses BigInts;

begin
  writeln($'{BigDecimal(1).sin(40)}');
  writeln($'{BigDecimal(1).cos(40)}');
  writeln($'{BigDecimal(1).tan(40)}');

  // the identity holds to the working precision
  var x: BigDecimal := '0.7';
  var s := x.sin(45);
  var c := x.cos(45);
  writeln($'{(s * s + c * c).rounded(-40)}'); // 1

  // sin(pi) is zero to as many digits as pi was given
  writeln(BigDecimal.pi(60).sin(40).toString);

  // huge arguments reduce correctly: pi is carried at a matching precision
  writeln($'{BigDecimal('1000000000000.5').sin(30)}');

  // degrees are just a scaling away
  var deg30 := BigDecimal(30) * BigDecimal.pi(40) / 180;
  writeln($'sin 30 deg = {deg30.sin(30).rounded(-25)}'); // 0.5
  {$ifdef WINDOWS}readln;{$endif}
end.
