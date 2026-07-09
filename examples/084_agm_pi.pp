program agm_pi;

// the arithmetic-geometric mean, and pi via Gauss-Legendre

{$mode unleashed}

uses BigInts;

const
  P = 50;

begin
  writeln($'agm(1, 2)    = {BigDecimal.agm(BigDecimal(1), BigDecimal(2), 40)}');

  // Gauss-Legendre doubles the correct digits every iteration
  var a := BigDecimal(1);
  var b := BigDecimal(1).divide(BigDecimal(2).sqrt(P + 10), P + 10);
  var t := BigDecimal('0.25');
  var weight := BigDecimal(1);
  for var i := 1 to 6 do begin
    var an := (a + b).divide(2, P + 10);
    var bn := (a * b).sqrt(P + 10);
    var diff := a - an;
    t := t - weight * diff * diff;
    a := an;
    b := bn;
    weight := weight * 2;
  end;
  var mypi := (a + b) * (a + b) / (t * 4);
  writeln($'Gauss-Legendre pi = {mypi.rounded(-P)}');
  writeln($'built-in pi       = {BigDecimal.pi(P)}');
  {$ifdef WINDOWS}readln;{$endif}
end.
