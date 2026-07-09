program inverse_trig;

// arcsin, arccos, arctan and pi out of thin air

{$mode unleashed}

uses SysUtils, BigInts;

begin
  writeln($'{BigDecimal('0.5').arcsin(40)}');   // pi/6
  writeln($'{BigDecimal('0.5').arccos(40)}');   // pi/3
  writeln($'{BigDecimal(1).arctan(40)}');       // pi/4

  // the classic: 4 arctan 1 = pi
  writeln($'{(BigDecimal(1).arctan(45) * 4).rounded(-40)}');

  // arctan takes anything, arcsin insists on -1..1
  writeln($'{BigDecimal(1000000).arctan(30)}'); // close to pi/2
  try
    var bad := BigDecimal(2).arcsin;
  except
    on e: EBigIntError do writeln('domain: ', e.Message);
  end;

  // roundtrip
  var x: BigDecimal := '0.42';
  writeln($'{x.sin(50).arcsin(40)}'); // 0.42 again
  {$ifdef WINDOWS}readln;{$endif}
end.
