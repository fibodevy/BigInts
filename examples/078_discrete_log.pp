program discrete_log;

// baby-step giant-step for the discrete logarithm

{$mode unleashed}

uses BigInts;

begin
  var p: UBigInt := 1000003;
  var g: UBigInt := 5;

  // pick a secret exponent, publish g^x, then recover x
  var secret: UBigInt := 31337;
  var y := g.modPow(secret, p);
  var x := g.discreteLog(y, p);
  writeln($'g^x = {y} mod {p}');
  writeln($'recovered x = {x}');
  writeln($'check: 5^{x} mod {p} = {g.modPow(UBigInt(QWord(x)), p)}');

  // no solution returns -1
  writeln($'log of a non-power: {g.discreteLog(UBigInt(0), p)}');
  {$ifdef WINDOWS}readln;{$endif}
end.
