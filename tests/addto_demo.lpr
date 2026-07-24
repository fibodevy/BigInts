program addto_demo;

{$mode unleashed}

uses
  {$ifdef WINDOWS}Windows,{$endif} SysUtils, BigInts;

var
  fails: integer = 0;

{$ifdef WINDOWS}
// make ANSI color escapes render when the exe is launched outside a VT-capable shell
procedure enableVTColors;
const
  ENABLE_VT = $0004;
var
  h: THandle;
  mode: DWord;
begin
  h := GetStdHandle(STD_OUTPUT_HANDLE);
  if GetConsoleMode(h, mode) then SetConsoleMode(h, mode or ENABLE_VT);
end;
{$endif}

procedure check(const what: string; ok: boolean);
begin
  if ok then writeln(#27'[32mOK'#27'[0m  ', what)
  else begin
    writeln(#27'[31mFAIL'#27'[0m ', what);
    inc(fails);
  end;
end;

procedure checkEq(const what: string; const got, want: UBigInt);
begin
  if got = want then writeln(#27'[32mOK'#27'[0m  ', what)
  else begin
    writeln(#27'[31mFAIL'#27'[0m ', what, ': got ', got.toString, ' want ', want.toString);
    inc(fails);
  end;
end;

begin
  {$ifdef WINDOWS}enableVTColors;{$endif}
  BigIntRandomSeed(42);

  // random pairs across the inline/spill boundary and beyond
  for var bits in [1, 64, 250, 448, 512, 576, 1000, 4096, 65536] do begin
    var a := UBigInt.random(bits);
    var b := UBigInt.random(bits div 2 + 1);
    var r: UBigInt;
    addTo(r, a, b);
    checkEq($'addTo fresh {bits}b', r, a + b);
    subTo(r, a, b);
    checkEq($'subTo fresh {bits}b', r, a - b);
    // reuse: r already holds a buffer, second call must land in place
    addTo(r, a, b);
    checkEq($'addTo reuse {bits}b', r, a + b);
  end;

  // aliasing: dst is also an operand
  var x: UBigInt := UBigInt.random(1000);
  var y: UBigInt := UBigInt.random(700);
  var wantSum := x + y;
  addTo(x, x, y);
  checkEq('addTo(x, x, y)', x, wantSum);
  x := UBigInt.random(1000);
  wantSum := y + x;
  addTo(x, y, x);
  checkEq('addTo(x, y, x)', x, wantSum);
  x := UBigInt.random(1000);
  var wantDbl := x + x;
  addTo(x, x, x);
  checkEq('addTo(x, x, x)', x, wantDbl);
  x := UBigInt.random(1000);
  y := UBigInt.random(700);
  var wantDiff := x - y;
  subTo(x, x, y);
  checkEq('subTo(x, x, y)', x, wantDiff);

  // shared spill array: the copy seen through the second variable must survive
  x := UBigInt.random(1000);
  var shared := x;
  var snapshot := shared.toString;
  addTo(x, x, x);
  check('shared copy intact after addTo', shared.toString = snapshot);
  subTo(x, x, shared);
  checkEq('subTo back to shared value', x, shared);

  // shrink: a spilled difference small enough to return to inline storage
  x := UBigInt.random(2000);
  y := x - 5;
  subTo(x, x, y);
  checkEq('subTo shrink to inline', x, 5);
  // and reuse of the shrunken dst again
  addTo(x, y, y);
  checkEq('addTo after shrink', x, y + y);

  // zero operands and equality
  var z: UBigInt := 0;
  addTo(x, y, z);
  checkEq('addTo b = 0', x, y);
  addTo(x, z, y);
  checkEq('addTo a = 0', x, y);
  subTo(x, y, y);
  checkEq('subTo equal -> 0', x, z);
  var raised := false;
  try
    subTo(x, z, y);
  except
    on ERangeError do raised := true;
  end;
  check('subTo a < b raises', raised);

  // accumulator loop: repeated addTo into one dst, verified against operators
  var acc: UBigInt := 0;
  var accRef: UBigInt := 0;
  for var i := 1 to 300 do begin
    var step := UBigInt.random(64 + (i mod 512));
    addTo(acc, acc, step);
    accRef := accRef + step;
  end;
  checkEq('300-step accumulator', acc, accRef);

  writeln;
  if fails = 0 then writeln(#27'[32mSUCCESS'#27'[0m - all checks passed')
  else writeln(#27'[31mFAILURE'#27'[0m - ', fails, ' check(s) failed');
  {$ifdef WINDOWS}readln;{$endif}
end.
