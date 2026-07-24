program stress_small;

{$mode unleashed}

// correctness stress test for the BigInts small-value fast paths.
// run with -gh (heaptrc): 0 unfreed blocks required

uses SysUtils, BigInts;

var
  fails: integer;
  rngState: QWord;

procedure check(cond: boolean; const msg: string);
begin
  if cond then exit;
  inc(fails);
  writeln('FAIL: ', msg);
end;

function rnd64: QWord;
begin
  rngState := rngState xor (rngState shl 13);
  rngState := rngState xor (rngState shr 7);
  rngState := rngState xor (rngState shl 17);
  result := rngState;
end;

// random magnitude of 0..maxLimbs 64-bit limbs (crosses the inline boundary)
function rndU(maxLimbs: integer): UBigInt;
begin
  result := 0;
  var n := integer(rnd64 mod QWord(maxLimbs + 1));
  for var i := 1 to n do result := (result shl 64) + UBigInt(rnd64);
end;

function rndB(maxLimbs: integer): BigInt;
begin
  result := rndU(maxLimbs);
  if rnd64 and 1 = 1 then result := -result;
end;

procedure TestAliasing;
var
  x, y: UBigInt;
  s, d: BigInt;
begin
  x := UBigInt.pow2(100) + 777;
  y := x;
  x := x + x;
  check(x = y * 2, 'alias x := x + x');
  x := x * x;
  check(x = (y * 2) * (y * 2), 'alias x := x * x');
  x := x - x;
  check(x.isZero, 'alias x := x - x');
  x := y;
  x := x div x;
  check(x.isOne, 'alias x := x div x');
  x := y;
  x := x mod x;
  check(x.isZero, 'alias x := x mod x');
  s := BigInt('-123456789012345678901234567890');
  d := s;
  s := s + s;
  check(s = d * 2, 'alias signed s := s + s');
  s := s - s;
  check(s.isZero, 'alias signed s := s - s');
end;

procedure TestTransitions;
var
  x: UBigInt;
begin
  // grow from 1 limb across the 4-limb inline boundary and back down
  x := 3;
  for var i := 1 to 6 do x := x * (UBigInt.pow2(64) - 1);
  check(x.toString = (UBigInt(3) * ((UBigInt.pow2(64) - 1) ** 6)).toString, 'grow to block');
  for var i := 1 to 6 do x := x div (UBigInt.pow2(64) - 1);
  check(x = 3, 'shrink back to inline');
  // shl/shr round trip across the boundary
  x := 12345;
  x := x shl 300;
  x := x shr 300;
  check(x = 12345, 'shl/shr round trip');
end;

procedure TestBitBoundary;
begin
  for var bits := 254 to 258 do begin
    var p := UBigInt.pow2(LongWord(bits));
    check(p.bitLength = LongWord(bits) + 1, Format('pow2(%d) bitLength', [bits]));
    check((p - 1).bitLength = LongWord(bits), Format('pow2(%d)-1 bitLength', [bits]));
    check((p + 1) - 1 = p, Format('pow2(%d) +1-1', [bits]));
    check(p * 2 div 2 = p, Format('pow2(%d) *2div2', [bits]));
    check((p - 1) + 1 = p, Format('pow2(%d) carry chain', [bits]));
  end;
end;

procedure TestCopyOnWrite;
var
  x, y: UBigInt;
begin
  // inline value
  x := UBigInt.pow2(100);
  y := x;
  y.setBit(5);
  check(not x.testBit(5), 'COW inline: original untouched');
  check(y.testBit(5), 'COW inline: copy modified');
  // block value
  x := UBigInt.pow2(500);
  y := x;
  y.setBit(7);
  check(not x.testBit(7), 'COW block: original untouched');
  check(y.testBit(7), 'COW block: copy modified');
end;

function SumByValue(a: UBigInt; b: UBigInt): UBigInt;
begin
  a := a + b;
  result := a;
end;

procedure TestArraysAndParams;
var
  arr, arr2: array of UBigInt;
begin
  SetLength(arr, 4);
  arr[0] := UBigInt.pow2(60);
  arr[1] := UBigInt.pow2(200);
  arr[2] := UBigInt.pow2(400);
  arr[3] := 42;
  arr2 := Copy(arr);
  arr2[1] := arr2[1] + 1;
  check(arr[1] = UBigInt.pow2(200), 'array copy is independent');
  var s := SumByValue(arr[0], arr[3]);
  check(arr[0] = UBigInt.pow2(60), 'by-value param untouched');
  check(s = UBigInt.pow2(60) + 42, 'by-value sum');
end;

procedure TestRandomIdentities;
begin
  for var iter := 1 to 20000 do begin
    var a := rndU(6);
    var b := rndU(6);
    check((a + b) - b = a, 'u (a+b)-b = a');
    check(a * b = b * a, 'u ab = ba');
    if not b.isZero then begin
      check((a * b) div b = a, 'u (ab) div b = a');
      var (q, r) := a.divMod(b);
      check(q * b + r = a, 'u a = qb + r');
      check(r < b, 'u r < b');
      check(a div b = q, 'u div matches divMod');
      check(a mod b = r, 'u mod matches divMod');
    end;
    // cmp trichotomy
    var gt := a > b;
    var lt := a < b;
    var eq := a = b;
    check(Ord(gt) + Ord(lt) + Ord(eq) = 1, 'u cmp trichotomy');
    check((a >= b) = (gt or eq), 'u >=');
    check((a <= b) = (lt or eq), 'u <=');
  end;
end;

procedure TestRandomSigned;
begin
  for var iter := 1 to 20000 do begin
    var a := rndB(6);
    var b := rndB(6);
    check((a + b) - b = a, 's (a+b)-b = a');
    check(a * b = b * a, 's ab = ba');
    check(a + b = b + a, 's a+b = b+a');
    if not b.isZero then begin
      check((a * b) div b = a, 's (ab) div b = a');
      var q := a div b;
      var r := a mod b;
      check(q * b + r = a, 's a = qb + r');
      check(r.abs < b.abs, 's |r| < |b|');
      if not r.isZero then check(r.isNegative = a.isNegative, 's rem sign = dividend sign');
    end;
  end;
end;

procedure TestMixedInt64;
begin
  for var iter := 1 to 20000 do begin
    var a := rndU(5);
    var k := Int64(rnd64 and $7FFFFFFFFFFFFFFF);
    if k = 0 then k := 1;
    check(a + k = a + UBigInt(k), 'u a + k');
    check(a * k = a * UBigInt(k), 'u a * k');
    check(a div k = a div UBigInt(k), 'u a div k');
    check(a mod k = a mod UBigInt(k), 'u a mod k');
    if a >= UBigInt(k) then check(a - k = a - UBigInt(k), 'u a - k');
    check((a > k) = (a > UBigInt(k)), 'u a > k');
    check((a < k) = (a < UBigInt(k)), 'u a < k');
    check((a = k) = (a = UBigInt(k)), 'u a = k');
    check((a >= k) = (a >= UBigInt(k)), 'u a >= k');
    check((a <= k) = (a <= UBigInt(k)), 'u a <= k');
    var s := rndB(5);
    check(s + k = s + BigInt(k), 's a + k');
    check(s - k = s - BigInt(k), 's a - k');
    check(s * k = s * BigInt(k), 's a * k');
    check(s div k = s div BigInt(k), 's a div k');
    check(s mod k = s mod BigInt(k), 's a mod k');
  end;
end;

procedure TestDecimalAccum;
var
  acc, step: BigDecimal;
begin
  acc := 0;
  step := BigDecimal('0.01');
  for var i := 1 to 100000 do acc := acc + step;
  check(acc.toString = '1000', '100k x 0.01 = 1000, got ' + acc.toString);
end;

procedure TestDecimalOps;
begin
  check((BigDecimal('1.5') - BigDecimal('0.25')).toString = '1.25', 'd 1.5 - 0.25');
  check((BigDecimal('123.456789') - BigDecimal('0.01')).toString = '123.446789', 'd sub align');
  check((BigDecimal('1.23') * BigDecimal('4.56')).toString = '5.6088', 'd mul');
  check((BigDecimal('-1.23') * BigDecimal('4.56')).toString = '-5.6088', 'd mul neg');
  check((BigDecimal('0.1') + BigDecimal('0.2')).toString = '0.3', 'd 0.1 + 0.2');
  check((BigDecimal('1000000') * BigDecimal('0.000001')).toString = '1', 'd strip zeros');
  for var iter := 1 to 5000 do begin
    var a := BigDecimal(rndB(3));
    a.shift10(-integer(rnd64 mod 10));
    var b := BigDecimal(rndB(3));
    b.shift10(-integer(rnd64 mod 10));
    check((a + b) - b = a, 'd (a+b)-b = a');
    check(a * b = b * a, 'd ab = ba');
    check(a + b = b + a, 'd a+b = b+a');
  end;
end;

begin
  fails := 0;
  rngState := QWord($DEADBEEFCAFEF00D);
  TestAliasing;
  TestTransitions;
  TestBitBoundary;
  TestCopyOnWrite;
  TestArraysAndParams;
  TestRandomIdentities;
  TestRandomSigned;
  TestMixedInt64;
  TestDecimalAccum;
  TestDecimalOps;
  if fails = 0 then writeln('ALL OK')
  else writeln(fails, ' FAILURES');
  {$ifdef WINDOWS}readln;{$endif}
  if fails <> 0 then Halt(1);
end.
