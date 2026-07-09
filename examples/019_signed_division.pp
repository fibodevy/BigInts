program signed_division;

// three rounding conventions for signed division, side by side

{$mode unleashed}

uses SysUtils, BigInts;

procedure row(a, b: Int64);
begin
  var x := BigInt(a);
  var y := BigInt(b);
  var (q, r) := x.divMod(y);
  writeln($'{a:4} / {b:2}:  div {q}  mod {r}   floorDiv {x.floorDiv(y)}  floorMod {x.floorMod(y)}   ceilDiv {x.ceilDiv(y)}');
end;

begin
  // div/mod truncate toward zero (Pascal), floor* round toward minus
  // infinity (Python), ceilDiv rounds up
  row(7, 2);
  row(-7, 2);
  row(7, -2);
  row(-7, -2);

  // the invariants that always hold
  var a: BigInt := -1234567;
  var b: BigInt := 789;
  var (q, r) := a.divMod(b);
  writeln(q * b + r = a);                          // TRUE
  writeln(a.floorDiv(b) * b + a.floorMod(b) = a);  // TRUE
  {$ifdef WINDOWS}readln;{$endif}
end.
