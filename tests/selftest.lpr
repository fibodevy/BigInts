program selftest;

{$mode unleashed}

uses
  SysUtils, bigints;

type
  TTestProc = reference to procedure;

var
  passCount: integer = 0;
  failCount: integer = 0;

procedure check(cond: boolean; const name: string);
begin
  if cond then inc(passCount)
  else begin
    inc(failCount);
    writeln(#27'[31mFAIL: ', name, #27'[0m');
  end;
end;

procedure checkEq(const got, want: string; const name: string);
begin
  if got = want then inc(passCount)
  else begin
    inc(failCount);
    writeln(#27'[31mFAIL: ', name, ' got=', got, ' want=', want, #27'[0m');
  end;
end;

procedure checkRaises(p: TTestProc; ex: ExceptClass; const name: string);
begin
  try
    p();
    inc(failCount);
    writeln(#27'[31mFAIL: ', name, ' (no exception)'#27'[0m');
  except
    on e: Exception do
      if e is ex then inc(passCount)
      else begin
        inc(failCount);
        writeln(#27'[31mFAIL: ', name, ' (got ', e.ClassName, ': ', e.Message, ')'#27'[0m');
      end;
  end;
end;

function randQ: QWord;
begin
  result := (QWord(Random($100000000)) shl 32) or QWord(Random($100000000));
end;

// random UBigInt with roughly the given number of bits
function randU(bits: integer): UBigInt;
begin
  result := 0;
  for var i := 0 to (bits div 32) do result := (result shl 32) or QWord(Random($100000000));
  result := result shr (32 - (bits mod 32));
end;

procedure section(const name: string);
begin
  writeln('== ', name);
end;

procedure testUBasics;
begin
  section('UBigInt basics');
  var u: UBigInt;
  check(u.isZero, 'default init is zero');
  checkEq(u.toString, '0', 'zero toString');
  u := 0;
  check(u.isZero and u.isEven and not u.isOdd, 'zero properties');
  u := 42;
  check((u.sign = 1) and u.isEven, '42 basic');
  checkEq(u.toString, '42', '42 toString');
  u := 18446744073709551615; // max qword literal
  checkEq(u.toString, '18446744073709551615', 'max qword literal');
  u := QWord(18446744073709551615);
  checkEq(u.toHex, 'FFFFFFFFFFFFFFFF', 'max qword toHex');
  u := '123456789012345678901234567890';
  checkEq(u.toString, '123456789012345678901234567890', 'string literal roundtrip');
  check(UBigInt(1).isOne, 'isOne');

  // value semantics: mutating a copy must not touch the original
  var a: UBigInt := '340282366920938463463374607431768211455'; // 2^128-1
  var b := a;
  b.clearBit(0);
  checkEq(a.toString, '340282366920938463463374607431768211455', 'copy-on-write original intact');
  check(b = a - 1, 'copy-on-write mutated copy');
end;

procedure testUArithmeticSmall;
begin
  section('UBigInt small arithmetic vs QWord oracle');
  for var i := 1 to 2000 do begin
    var x := randQ shr (Random(64));
    var y := randQ shr (Random(64));
    var ux: UBigInt := x;
    var uy: UBigInt := y;
    if High(QWord) - x >= y then check((ux + uy).toUInt64 = x + y, $'add {x}+{y}');
    if x >= y then check((ux - uy).toUInt64 = x - y, $'sub {x}-{y}')
    else check((uy - ux).toUInt64 = y - x, $'sub {y}-{x}');
    if (y = 0) or (x <= High(QWord) div y) then check((ux * uy).toUInt64 = x * y, $'mul {x}*{y}');
    if y <> 0 then begin
      check((ux div uy).toUInt64 = x div y, $'div {x} div {y}');
      check((ux mod uy).toUInt64 = x mod y, $'mod {x} mod {y}');
    end;
    check((ux = uy) = (x = y), 'eq oracle');
    check((ux < uy) = (x < y), 'lt oracle');
    check((ux >= uy) = (x >= y), 'ge oracle');
    var sh := Random(64);
    check((ux shr sh).toUInt64 = x shr sh, $'shr {sh}');
    check((ux and uy).toUInt64 = x and y, 'and oracle');
    check((ux or uy).toUInt64 = x or y, 'or oracle');
    check((ux xor uy).toUInt64 = x xor y, 'xor oracle');
  end;
end;

procedure testUCarryChains;
begin
  section('UBigInt carry chains and known values');
  var u: UBigInt := QWord($FFFFFFFF);
  u := u + 1;
  checkEq(u.toHex, '100000000', 'carry 32-bit');
  u := QWord($FFFFFFFFFFFFFFFF);
  u := u + 1;
  checkEq(u.toHex, '10000000000000000', 'carry 64-bit');
  u := u - 1;
  checkEq(u.toHex, 'FFFFFFFFFFFFFFFF', 'borrow across limb');

  // 2^128 = 340282366920938463463374607431768211456
  var p128: UBigInt := 1;
  for var i := 1 to 128 do p128 := p128 + p128;
  checkEq(p128.toString, '340282366920938463463374607431768211456', '2^128 via additions');
  check(p128 = UBigInt(1) shl 128, '2^128 via shl');
  check(p128.isPowerOfTwo and (p128.bitLength = 129) and (p128.popCount = 1), '2^128 bit facts');
  check(p128.lowestSetBit = 128, '2^128 lowestSetBit');

  // 10^30 arithmetic
  var t: UBigInt := '1000000000000000000000000000000';
  check(t * t = UBigInt('1000000000000000000000000000000000000000000000000000000000000'), '10^30 squared');
  check((t * t) div t = t, 'big div roundtrip');
  check((t * t + 12345) mod t = 12345, 'big mod');
  check(t * 0 = 0, 'mul by zero');
  check((t * 1 = t) and (t div t = 1) and (t mod t = 0), 'identities');
end;

procedure testUMulDivRandom;
begin
  section('UBigInt randomized big mul/div roundtrips');
  for var i := 1 to 400 do begin
    var a := randU(50 + Random(900));
    var b := randU(20 + Random(500));
    if b.isZero then b := b + 1;
    var r := randU(16);
    r := r mod b;
    var n := a * b + r;
    var (q, rem) := n.divMod(b);
    check(q = a, 'divMod quotient roundtrip');
    check(rem = r, 'divMod remainder roundtrip');
    check(q * b + rem = n, 'reconstruction');
    check(rem < b, 'remainder < divisor');
    check((a + b) - b = a, 'add/sub roundtrip');
    var sh := Random(300);
    check((a shl sh) shr sh = a, 'shl/shr roundtrip');
    check((a shl sh).bitLength = a.bitLength + LongWord(sh), 'shl bitLength');
    check(a * b = b * a, 'mul commutativity');
  end;
end;

procedure testUDivisionEdge;
const
  pat: array[0..8] of QWord = (0, 1, 2, 3, $7FFFFFFF, $80000000, $80000001, $FFFFFFFE, $FFFFFFFF);
begin
  section('UBigInt division edge patterns (Knuth D corrections)');
  // 3-limb dividends / 2-limb divisors built from edge limbs
  for var i0 := 0 to High(pat) do
    for var i1 := 0 to High(pat) do
      for var i2 := 0 to High(pat) do begin
        var u := (UBigInt(pat[i2]) shl 64) or (UBigInt(pat[i1]) shl 32) or pat[i0];
        for var j0 := 0 to High(pat) do
          for var j1 := 1 to High(pat) do begin
            var v := (UBigInt(pat[j1]) shl 32) or pat[j0];
            var (q, r) := u.divMod(v);
            if not ((q * v + r = u) and (r < v)) then check(false, $'division invariant u={u.toHex} v={v.toHex}');
          end;
      end;
  check(true, 'division edge sweep done');
end;

procedure testUStringsAndParse;
begin
  section('UBigInt strings and parsing');
  checkEq(UBigInt.parse('0').toString, '0', 'parse 0');
  checkEq(UBigInt.parse('-0').toString, '0', 'parse -0');
  checkEq(UBigInt.parse('+123').toString, '123', 'parse +123');
  checkEq(UBigInt.parse('  42  ').toString, '42', 'parse trims spaces');
  checkEq(UBigInt.parse('1_000_000').toString, '1000000', 'parse underscores');
  checkEq(UBigInt.parse('$FF').toString, '255', 'parse $FF');
  checkEq(UBigInt.parse('0xff').toString, '255', 'parse 0xff');
  checkEq(UBigInt.parse('%1010').toString, '10', 'parse %1010');
  checkEq(UBigInt.parse('0b1010').toString, '10', 'parse 0b1010');
  checkEq(UBigInt.parse('&17').toString, '15', 'parse &17');
  checkEq(UBigInt.parse('0o17').toString, '15', 'parse 0o17');
  checkEq(UBigInt.parse('ZZ', 36).toString, '1295', 'parse base 36');
  checkEq(UBigInt.parse('zz', 36).toString, '1295', 'parse base 36 lowercase');

  var u: UBigInt := '123456789123456789123456789';
  checkEq(UBigInt.parse(u.toHex, 16).toString, u.toString, 'hex roundtrip');
  checkEq(UBigInt.parse(u.toBin, 2).toString, u.toString, 'bin roundtrip');
  checkEq(UBigInt.parse(u.toOct, 8).toString, u.toString, 'oct roundtrip');
  checkEq(string(u), u.toString, 'explicit string cast');

  for var base := 2 to 36 do begin
    var v := randU(200);
    check(UBigInt.parse(v.toString(base), base) = v, $'base {base} roundtrip');
  end;

  var dummy: UBigInt;
  check(not UBigInt.tryParse('', dummy), 'tryParse empty');
  check(not UBigInt.tryParse('xyz', dummy), 'tryParse garbage');
  check(not UBigInt.tryParse('-5', dummy), 'tryParse negative for unsigned');
  check(not UBigInt.tryParse('12a', dummy), 'tryParse trailing garbage');
  check(not UBigInt.tryParse('_', dummy), 'tryParse only separator');
  check(not UBigInt.tryParse('0x', dummy), 'tryParse bare prefix');
  check(UBigInt.tryParse('42', dummy) and (dummy = 42), 'tryParse ok');
end;

procedure testUConversions;
begin
  section('UBigInt conversions');
  var u: UBigInt := 12345;
  check(u.toInt64 = 12345, 'toInt64');
  check(u.toUInt64 = 12345, 'toQWord');
  check(u.toInt32 = 12345, 'toInteger');
  check(u.toUInt32 = 12345, 'toCardinal');
  check(Int64(u) = 12345, 'explicit Int64');
  check(QWord(u) = 12345, 'explicit QWord');
  u := QWord(High(QWord));
  check(u.fitsInUInt64 and not u.fitsInInt64, 'fitsIn edges');
  u := QWord(High(Int64));
  check(u.fitsInInt64 and (u.toInt64 = High(Int64)), 'High(Int64) fits');
  u := QWord(High(Int64)) + 1;
  check(not u.fitsInInt64 and u.fitsInUInt64, '2^63 does not fit Int64');
  u := QWord(High(LongWord));
  check(u.fitsInUInt32 and not u.fitsInInt32, 'dword edge');
  // the small-type predicates, upper edge and one over
  check(UBigInt(255).fitsInUInt8 and not UBigInt(256).fitsInUInt8, 'byte edge');
  check(UBigInt(127).fitsInInt8 and not UBigInt(128).fitsInInt8, 'shortint edge');
  check(UBigInt(65535).fitsInUInt16 and not UBigInt(65536).fitsInUInt16, 'word edge');
  check(UBigInt(32767).fitsInInt16 and not UBigInt(32768).fitsInInt16, 'smallint edge');
  check(UBigInt(High(LongWord)).fitsInUInt32 and not (UBigInt(High(LongWord)) + 1).fitsInUInt32, 'dword upper edge');
  // sized conversions roundtrip
  check(UBigInt(200).toUInt8 = 200, 'u toUInt8');
  check(UBigInt(100).toInt8 = 100, 'u toInt8');
  check(UBigInt(60000).toUInt16 = 60000, 'u toUInt16');
  check(UBigInt(3000000000).toUInt32 = 3000000000, 'u toUInt32');
  check(UBigInt(QWord(High(QWord))).toUInt64 = High(QWord), 'u toUInt64 max');
  checkRaises(procedure begin UBigInt(300).toUInt8; end, ERangeError, 'u toUInt8 overflow');
  checkRaises(procedure begin UBigInt(200).toInt8; end, ERangeError, 'u toInt8 overflow');

  // typecasts from full-width integers must stay exact (not round via Double)
  checkEq(UBigInt(QWord(High(QWord))).toString, '18446744073709551615', 'exact cast from QWord');
  checkEq(UBigInt(High(Int64)).toString, '9223372036854775807', 'exact cast from Int64');

  // double conversions
  u := '1208925819614629174706176'; // 2^80
  check(System.Abs(u.toDouble - 1.208925819614629174706176e24) < 1e10, 'toDouble 2^80');
  check(UBigInt(u.toDouble) = u, 'double roundtrip for exact power of two');
  check(UBigInt(3.99) = 3, 'double truncation');
  check(UBigInt(0.5).isZero, 'double below one');
end;

procedure testUBits;
begin
  section('UBigInt bit operations');
  var u: UBigInt := 0;
  u.setBit(100);
  check(u = UBigInt(1) shl 100, 'setBit 100');
  check(u.testBit(100) and not u.testBit(99), 'testBit');
  u.flipBit(0);
  check(u.isOdd, 'flipBit 0');
  u.clearBit(100);
  check(u = 1, 'clearBit 100');
  u.clearBit(5000);
  check(u = 1, 'clearBit beyond length is no-op');
  u.bits[77] := true;
  check(u.bits[77] and (u = (UBigInt(1) shl 77) or 1), 'bits[] write');
  u.bits[77] := false;
  check(u = 1, 'bits[] clear');

  u := '0b101101';
  check(u.popCount = 4, 'popCount');
  check(u.bitLength = 6, 'bitLength');
  check(u.lowestSetBit = 0, 'lowestSetBit');
  check((u shr 1).lowestSetBit = 1, 'lowestSetBit shifted');
  check(UBigInt(0).lowestSetBit = -1, 'lowestSetBit of zero');
  check(UBigInt(0).bitLength = 0, 'bitLength of zero');

  checkEq(UBigInt.parse('%1010').complement(4).toBin, '101', 'complement 4 bits');
  checkEq(UBigInt(0).complement(8).toString, '255', 'complement of zero');
  check(u.complement(6).complement(6) = u, 'complement involution');
end;

procedure testUOperatorsMixed;
begin
  section('UBigInt mixed Int64 operators');
  var u: UBigInt := 100;
  check(u + 1 = 101, 'u + literal');
  check(1 + u = 101, 'literal + u');
  check(u - 1 = 99, 'u - literal');
  check(200 - u = 100, 'literal - u');
  check(u + (-30) = 70, 'u plus negative literal');
  check(u - (-30) = 130, 'u minus negative literal');
  check(u * 3 = 300, 'u * literal');
  check(3 * u = 300, 'literal * u');
  check(UBigInt(0) * (-5) = 0, 'zero times negative ok');
  check(u div 7 = 14, 'u div literal');
  check(u mod 7 = 2, 'u mod literal');
  check(u mod (-7) = 2, 'u mod negative literal');
  check(u / 7 = 14, 'slash is integer division');
  check(u ** 2 = 10000, 'power literal');
  check(u ** 0 = 1, 'power zero');
  check(UBigInt(0) ** 0 = 1, '0^0 = 1');
  check(UBigInt(2) ** 100 = UBigInt(1) shl 100, '2^100');
  check(u <> 99, 'ne literal');
  check((u > 99) and (u >= 100) and (u < 101) and (u <= 100), 'cmp literals');
  check((u > -5) and (u >= -5) and not (u < -5) and not (u <= -5) and (u <> -5), 'cmp negative literals');
  check((-5 < u) and (-5 <= u) and not (-5 > u) and not (-5 >= u), 'negative left literals');
  check(not (u = -1), 'eq negative literal is false');

  inc(u);
  check(u = 101, 'inc');
  dec(u);
  check(u = 100, 'dec');
  u += 10;
  check(u = 110, '+=');
  u -= 10;
  check(u = 100, '-=');
  u *= 2;
  check(u = 200, '*=');

  var a: UBigInt := 17;
  var b: UBigInt := 5;
  check(a.min(b) = 5, 'min');
  check(a.max(b) = 17, 'max');
  check(a.compare(b) > 0, 'compare');
  check(a.equals(a) and not a.equals(b), 'equals');
  check(a.ceilDiv(b) = 4, 'ceilDiv');
  check(UBigInt(15).ceilDiv(b) = 3, 'ceilDiv exact');
  a.swap(b);
  check((a = 5) and (b = 17), 'swap');
end;

procedure testUAliasing;
begin
  section('UBigInt self-assignment aliasing');
  var u: UBigInt := '123456789123456789';
  u := u + u;
  checkEq(u.toString, '246913578246913578', 'u := u + u');
  u := u - u;
  check(u.isZero, 'u := u - u');
  u := '99999999999999999999';
  u := u * u;
  checkEq(u.toString, '9999999999999999999800000000000000000001', 'u := u * u');
  u := u div u;
  check(u = 1, 'u := u div u');
  u := '123456789';
  u := u mod u;
  check(u.isZero, 'u := u mod u');
  u := '987654321987654321';
  u := u shl 100;
  u := u shr 100;
  checkEq(u.toString, '987654321987654321', 'self shift roundtrip');
  u := u xor u;
  check(u.isZero, 'u := u xor u');
  u := '0xDEADBEEF';
  u := u and u;
  checkEq(u.toHex, 'DEADBEEF', 'u := u and u');
  u := u or u;
  checkEq(u.toHex, 'DEADBEEF', 'u := u or u');
  var a: UBigInt := '0xF0F0';
  var b: UBigInt := '0x0F0F';
  a := b or a;
  checkEq(a.toHex, 'FFFF', 'a := b or a');
  u := 3;
  u := u ** 7;
  check(u = 2187, 'u := u ** 7');
  // 2187 = 100010001011b, complement within 12 bits = 4095 - 2187
  u := u.complement(u.bitLength);
  check(u = 1908, 'u := u.complement(bitLength)');
end;

procedure testUErrors;
begin
  section('UBigInt error conditions');
  checkRaises(procedure begin var u: UBigInt := -1; u := u; end, ERangeError, 'assign negative');
  checkRaises(procedure begin var u: UBigInt := 5; u := u - 6; end, ERangeError, 'subtraction underflow');
  checkRaises(procedure begin var u: UBigInt := 5; u := u div 0; end, EDivByZero, 'div by zero');
  checkRaises(procedure begin var u: UBigInt := 5; u := u mod UBigInt(0); end, EDivByZero, 'mod by zero');
  checkRaises(procedure begin var u: UBigInt := 5; u := u div (-2); end, ERangeError, 'div negative');
  checkRaises(procedure begin var u: UBigInt := 0; dec(u); end, ERangeError, 'dec below zero');
  checkRaises(procedure begin UBigInt.parse('nope'); end, EConvertError, 'parse error raises');
  checkRaises(procedure begin var u: UBigInt := QWord(High(QWord)); u.toInt64; end, ERangeError, 'toInt64 overflow');
  checkRaises(procedure begin var u: UBigInt := '18446744073709551616'; u.toUInt64; end, ERangeError, 'toQWord overflow');
  checkRaises(procedure begin var u: UBigInt := 5; u := u shl (-1); end, ERangeError, 'negative shift');
  checkRaises(procedure begin var u: UBigInt := 5; u := u ** (-2); end, EBigIntError, 'negative exponent');
  checkRaises(procedure begin UBigInt(5).toString(37); end, EBigIntError, 'invalid base');
  checkRaises(procedure begin UBigInt(5).toString(1); end, EBigIntError, 'base 1');
end;

// random Int64 with at most `bits` magnitude bits, both signs
function randI(bits: integer): Int64;
begin
  result := Int64(randQ shr (64 - bits));
  if Random(2) = 0 then result := -result;
end;

// random BigInt with roughly the given number of bits, both signs
function randB(bits: integer): BigInt;
begin
  result := randU(bits).toBigInt;
  if Random(2) = 0 then result := -result;
end;

procedure testBBasics;
begin
  section('BigInt basics');
  var b := default(BigInt);
  check(b.isZero and (b.sign = 0), 'default init is zero');
  checkEq(b.toString, '0', 'zero toString');
  b := -42;
  check(b.isNegative and not b.isPositive and (b.sign = -1), '-42 sign');
  checkEq(b.toString, '-42', '-42 toString');
  check(b.abs = 42, 'abs');
  checkEq(b.magnitude.toString, '42', 'magnitude');
  b.negate;
  check(b = 42, 'negate in place');
  check((-b).toString = '-42', 'unary minus');
  check(+b = b, 'unary plus');
  b := 0;
  b.negate;
  check(b.isZero and (b.sign = 0), 'negate zero stays zero');
  check((-b).isZero, 'minus zero is zero');
  b := '-123456789012345678901234567890';
  checkEq(b.toString, '-123456789012345678901234567890', 'big negative literal');
  check(BigInt(Low(Int64)).toString = '-9223372036854775808', 'Low(Int64) literal');
  check(BigInt(QWord(High(QWord))).toString = '18446744073709551615', 'QWord literal');
end;

procedure testBArithmeticSmall;
const
  edge: array[0..11] of Int64 = (0, 1, -1, 2, -2, High(Int64), Low(Int64), Low(Int64) + 1, $7FFFFFFF, -$80000000, $100000000, -$100000000);
begin
  section('BigInt small arithmetic vs Int64 oracle');
  for var i := 1 to 2000 do begin
    var x := randI(60);
    var y := randI(60);
    var bx: BigInt := x;
    var by: BigInt := y;
    check((bx + by).toInt64 = x + y, $'add {x}+{y}');
    check((bx - by).toInt64 = x - y, $'sub {x}-{y}');
    var mx := randI(30);
    var my := randI(30);
    check((BigInt(mx) * my).toInt64 = mx * my, $'mul {mx}*{my}');
    if y <> 0 then begin
      check((bx div by).toInt64 = x div y, $'div {x} div {y}');
      check((bx mod by).toInt64 = x mod y, $'mod {x} mod {y}');
    end;
    check((bx and by).toInt64 = (x and y), 'and oracle');
    check((bx or by).toInt64 = (x or y), 'or oracle');
    check((bx xor by).toInt64 = (x xor y), 'xor oracle');
    check((not bx).toInt64 = (not x), 'not oracle');
    var sh := Random(64);
    check((bx shr sh).toInt64 = SarInt64(x, sh), $'arithmetic shr {sh}');
    check((bx = by) = (x = y), 'eq oracle');
    check((bx < by) = (x < y), 'lt oracle');
    check((bx >= by) = (x >= y), 'ge oracle');
    check((bx < y) = (x < y), 'lt mixed literal');
    check((x > by) = (x > y), 'gt mixed literal');
  end;
  // edge value pairs with representability guards
  for var i := 0 to High(edge) do
    for var j := 0 to High(edge) do begin
      var x := edge[i];
      var y := edge[j];
      var bx: BigInt := x;
      var by: BigInt := y;
      // compare addition only when the true sum is representable in Int64
      var sum := bx + by;
      if sum.fitsInInt64 then check(sum.toInt64 = x + y, 'edge add');
      check((bx and by).toInt64 = (x and y), 'edge and');
      check((bx or by).toInt64 = (x or y), 'edge or');
      check((bx xor by).toInt64 = (x xor y), 'edge xor');
      check((bx < by) = (x < y), 'edge lt');
      check((bx = by) = (x = y), 'edge eq');
      if (y <> 0) and not ((x = Low(Int64)) and (y = -1)) then begin
        check((bx div by).toInt64 = x div y, 'edge div');
        check((bx mod by).toInt64 = x mod y, 'edge mod');
      end;
    end;
  // the one division that overflows Int64
  check((BigInt(Low(Int64)) div -1).toString = '9223372036854775808', 'Low(Int64) div -1');
  var b: BigInt := High(Int64);
  inc(b);
  checkEq(b.toString, '9223372036854775808', 'inc beyond Int64');
  dec(b);
  check(b.toInt64 = High(Int64), 'dec back');
end;

procedure testBBigIdentities;
begin
  section('BigInt randomized big identities');
  for var i := 1 to 300 do begin
    var a := randB(100 + Random(800));
    var b := randB(50 + Random(400));
    if b.isZero then b := b + 1;
    check((a + b) - b = a, 'add/sub roundtrip');
    check(a + (-b) = a - b, 'negated add');
    check((a * b) div b = a, 'mul/div roundtrip');
    check(-(a * b) = (-a) * b, 'sign of product');
    var (q, r) := a.divMod(b);
    check(q * b + r = a, 'divMod reconstruction');
    check(r.abs < b.abs, 'remainder magnitude');
    check(r.isZero or (r.sign = a.sign), 'remainder sign follows dividend');
    var fq := a.floorDiv(b);
    var fr := a.floorMod(b);
    check(fq * b + fr = a, 'floor reconstruction');
    check(fr.isZero or (fr.sign = b.sign), 'floor remainder sign follows divisor');
    check(a.ceilDiv(b) >= a.floorDiv(b), 'ceil >= floor');
    check((a mod b).isZero = (a.ceilDiv(b) = a.floorDiv(b)), 'ceil = floor iff divisible');
    var sh := Random(200);
    check((a shl sh) shr sh = a, 'signed shl/shr roundtrip');
    check((a xor b) xor b = a, 'xor involution');
    check(not (not a) = a, 'not involution');
    check((a and b) or (a xor b) = (a or b), 'and/or/xor identity');
    check(a.min(b) <= a.max(b), 'min/max');
  end;
end;

procedure testBBitwiseTC;
begin
  section('BigInt two''s complement bitwise semantics');
  check((BigInt(-5) and 3) = 3, '(-5) and 3');
  check((BigInt(-5) or 3) = -5, '(-5) or 3');
  check((BigInt(-5) xor 3) = -8, '(-5) xor 3');
  check((not BigInt(5)) = -6, 'not 5');
  check((not BigInt(-6)) = 5, 'not -6');
  check((not BigInt(0)) = -1, 'not 0');
  check((BigInt(-1) and 12345) = 12345, '-1 is identity for and');
  check((BigInt(-1) or 12345) = -1, '-1 absorbs or');
  check((BigInt(-1) xor 12345) = not BigInt(12345), '-1 xor is not');
  check(BigInt(-6).testBit(0) = false, 'testBit -6 bit 0');
  check(BigInt(-6).testBit(1) = true, 'testBit -6 bit 1');
  check(BigInt(-1).testBit(0) and BigInt(-1).testBit(63) and BigInt(-1).testBit(1000), 'testBit -1 infinite ones');
  check(BigInt(-1).bitLength = 0, 'bitLength -1');
  check(BigInt(-8).bitLength = 3, 'bitLength -8');
  check(BigInt(8).bitLength = 4, 'bitLength 8');
  check(BigInt(-6).popCount = 2, 'popCount -6');
  check(BigInt(-1).popCount = 0, 'popCount -1');
  check(BigInt(-6).lowestSetBit = 1, 'lowestSetBit -6');
  check(BigInt(-1).lowestSetBit = 0, 'lowestSetBit -1');

  // big negative shifted: floor semantics
  check(BigInt(-5) shr 1 = -3, '-5 shr 1 = floor(-2.5)');
  check(BigInt(-4) shr 1 = -2, '-4 shr 1');
  check(BigInt(-1) shr 100 = -1, '-1 shr anything');
  check(BigInt(-1) shl 3 = -8, 'negative shl');
  var big: BigInt := '-123456789123456789123456789';
  check((big shr 64) shl 64 <= big, 'shr/shl floor bound');
  check(((big shr 64) shl 64) + (big and ((BigInt(1) shl 64) - 1)) = big, 'split via shr/and');

  // mutating bit ops on negatives (two's complement view)
  var b: BigInt := -6;
  b.setBit(0);
  check(b = -5, 'setBit on negative');
  b.clearBit(0);
  check(b = -6, 'clearBit on negative');
  b.flipBit(2);
  check(b = -2, 'flipBit on negative');
  b := 6;
  b.bits[0] := true;
  check(b = 7, 'bits[] on positive');
  check(BigInt(-6).bits[1], 'bits[] read negative');
end;

procedure testBStringsParse;
begin
  section('BigInt strings and parsing');
  checkEq(BigInt.parse('-255').toHex, '-FF', 'negative toHex');
  checkEq(BigInt.parse('-$FF').toString, '-255', 'parse -$FF');
  checkEq(BigInt.parse('-0xff').toString, '-255', 'parse -0xff');
  checkEq(BigInt.parse('-%101').toString, '-5', 'parse -%101');
  checkEq(BigInt.parse('+42').toString, '42', 'parse +42');
  checkEq(BigInt.parse('-1_000').toString, '-1000', 'parse -1_000');
  checkEq(BigInt.parse('-ZZ', 36).toString, '-1295', 'parse negative base 36');
  for var base := 2 to 36 do begin
    var v := randB(150);
    check(BigInt.parse(v.toString(base), base) = v, $'signed base {base} roundtrip');
  end;
  var dummy: BigInt;
  check(BigInt.tryParse('-5', dummy) and (dummy = -5), 'tryParse negative');
  check(not BigInt.tryParse('--5', dummy), 'tryParse double sign');
  check(not BigInt.tryParse('5-', dummy), 'tryParse trailing sign');
end;

procedure testBConversions;
begin
  section('BigInt conversions');
  check(BigInt(Low(Int64)).toInt64 = Low(Int64), 'Low(Int64) roundtrip');
  check(BigInt(High(Int64)).toInt64 = High(Int64), 'High(Int64) roundtrip');
  check(BigInt('-9223372036854775808').fitsInInt64, '-2^63 fits');
  check(not BigInt('-9223372036854775809').fitsInInt64, '-2^63-1 does not fit');
  check(not BigInt('9223372036854775808').fitsInInt64, '2^63 does not fit');
  check(BigInt(-1).toInt32 = -1, 'toInteger -1');
  check(BigInt(-$80000000).fitsInInt32, 'Low(LongInt) fits');
  check(not BigInt(-$80000001).fitsInInt32, 'below Low(LongInt)');
  check(not BigInt(-1).fitsInUInt64, 'negative does not fit QWord');
  check(not BigInt(-1).fitsInUInt32, 'negative does not fit DWord');
  // signed small types: both bounds, and unsigned targets reject negatives
  check(BigInt(127).fitsInInt8 and BigInt(-128).fitsInInt8, 'shortint both bounds');
  check(not BigInt(128).fitsInInt8 and not BigInt(-129).fitsInInt8, 'shortint over both');
  check(BigInt(-32768).fitsInInt16 and not BigInt(-32769).fitsInInt16, 'smallint low edge');
  check(BigInt(255).fitsInUInt8 and not BigInt(-1).fitsInUInt8, 'byte rejects negative');
  check(BigInt(65535).fitsInUInt16 and not BigInt(-1).fitsInUInt16, 'word rejects negative');
  check(BigInt('4294967295').fitsInUInt32 and not BigInt('4294967296').fitsInUInt32, 'dword upper edge');
  // sized conversions keep the sign
  check(BigInt(-100).toInt8 = -100, 'b toInt8 neg');
  check(BigInt(-30000).toInt16 = -30000, 'b toInt16 neg');
  check(BigInt(200).toUInt8 = 200, 'b toUInt8');
  check(BigInt(Low(Int64)).toInt64 = Low(Int64), 'b toInt64 min');
  checkRaises(procedure begin BigInt(-1).toUInt8; end, ERangeError, 'b toUInt8 negative raises');
  checkRaises(procedure begin BigInt(128).toInt8; end, ERangeError, 'b toInt8 overflow');
  check(BigInt(-12345).toDouble = -12345.0, 'toDouble negative');
  check(BigInt(-3.99) = -3, 'explicit negative double truncates');
  check(BigInt(3.99) = 3, 'explicit positive double truncates');
  checkEq(string(BigInt(-7)), '-7', 'explicit string');
end;

procedure testBMixedTypes;
begin
  section('BigInt/UBigInt mixed');
  var ux: UBigInt := '340282366920938463463374607431768211455';
  var bx: BigInt := ux;
  checkEq(bx.toString, ux.toString, 'implicit U -> B');
  check(bx = ux, 'mixed equality');
  check(bx + ux = ux + bx, 'mixed addition commutes');
  check((bx + ux).toString = (ux * 2).toString, 'mixed add value');
  check(ux.toBigInt = bx, 'toBigInt bridge');
  check(bx.toUBigInt = ux, 'toUBigInt');
  check(UBigInt(bx) = ux, 'explicit B -> U');
  bx := -bx;
  check(bx.magnitude = ux, 'magnitude of negative');
  check(-ux.toBigInt = bx, 'negated bridge');
  var neg: BigInt := -5;
  checkRaises(procedure begin neg.toUBigInt; end, ERangeError, 'toUBigInt negative raises');
  checkRaises(procedure begin var u := UBigInt(neg); u := u; end, ERangeError, 'explicit negative B -> U raises');
end;

procedure testBFloorCeil;
type
  TRow = record
    a, b, d, m, fd, fm, cd: Int64;
  end;
const
  rows: array[0..3] of TRow = (
    (a: 7; b: 2; d: 3; m: 1; fd: 3; fm: 1; cd: 4),
    (a: -7; b: 2; d: -3; m: -1; fd: -4; fm: 1; cd: -3),
    (a: 7; b: -2; d: -3; m: 1; fd: -4; fm: -1; cd: -3),
    (a: -7; b: -2; d: 3; m: -1; fd: 3; fm: -1; cd: 4));
begin
  section('BigInt trunc/floor/ceil division table');
  for var i := 0 to High(rows) do begin
    var a: BigInt := rows[i].a;
    var b: BigInt := rows[i].b;
    check(a div b = rows[i].d, $'div {rows[i].a}/{rows[i].b}');
    check(a mod b = rows[i].m, $'mod {rows[i].a}/{rows[i].b}');
    check(a.floorDiv(b) = rows[i].fd, $'floorDiv {rows[i].a}/{rows[i].b}');
    check(a.floorMod(b) = rows[i].fm, $'floorMod {rows[i].a}/{rows[i].b}');
    check(a.ceilDiv(b) = rows[i].cd, $'ceilDiv {rows[i].a}/{rows[i].b}');
  end;
end;

procedure testBAliasing;
begin
  section('BigInt self-assignment aliasing');
  var b: BigInt := '-123456789123456789';
  b := b + b;
  checkEq(b.toString, '-246913578246913578', 'b := b + b');
  b := b * b;
  checkEq(b.toString, '60966315122694714062490483000762084', 'b := b * b');
  b := -b;
  b := b - b;
  check(b.isZero, 'b := b - b');
  b := '-99999999999999999999';
  b := b div b;
  check(b = 1, 'b := b div b');
  b := '-987654321987654321';
  b := b shl 65;
  b := b shr 65;
  checkEq(b.toString, '-987654321987654321', 'signed self shift roundtrip');
  b := not b;
  checkEq(b.toString, '987654321987654320', 'b := not b');
  b := -12345;
  b := b xor b;
  check(b.isZero, 'b := b xor b');
  b := -12345;
  b := b and b;
  check(b = -12345, 'b := b and b');
  b := b or b;
  check(b = -12345, 'b := b or b');
  b := b ** 3;
  checkEq(b.toString, '-1881365963625', 'b := b ** 3');
  var c: BigInt := '424242424242424242';
  b := '-171717';
  b.swap(c);
  check((b = 424242424242424242) and (c = -171717), 'swap');
end;

procedure testBErrors;
begin
  section('BigInt error conditions');
  checkRaises(procedure begin var b: BigInt := 5; b := b div 0; end, EDivByZero, 'div by zero');
  checkRaises(procedure begin var b: BigInt := 5; b := b mod BigInt(0); end, EDivByZero, 'mod by zero');
  checkRaises(procedure begin BigInt(5).divMod(BigInt(0)); end, EDivByZero, 'divMod by zero');
  checkRaises(procedure begin var b: BigInt := -1; b.toUInt64; end, ERangeError, 'toQWord negative');
  checkRaises(procedure begin var b: BigInt := -1; b.toUInt32; end, ERangeError, 'toCardinal negative');
  checkRaises(procedure begin var b: BigInt := 2; b := b ** (-1); end, EBigIntError, 'negative exponent');
  checkRaises(procedure begin var b: BigInt := 2; b := b shl (-1); end, ERangeError, 'negative shift');
  checkRaises(procedure begin BigInt.parse('12x34'); end, EConvertError, 'parse garbage');
  checkRaises(procedure begin var b: BigInt := '99999999999999999999'; b.toInt64; end, ERangeError, 'toInt64 overflow');
end;

procedure testMathRoots;
begin
  section('sqr / sqrt / nthRoot / pow');
  check(UBigInt(0).sqrt.isZero, 'sqrt 0');
  check(UBigInt(1).sqrt = 1, 'sqrt 1');
  check(UBigInt(3).sqrt = 1, 'sqrt 3');
  check(UBigInt(4).sqrt = 2, 'sqrt 4');
  check((UBigInt(1) shl 128).sqrt = UBigInt(1) shl 64, 'sqrt 2^128');
  var t: UBigInt := '100000000000000000000';
  check(t.sqr.sqrt = t, 'sqrt of exact square');
  for var i := 1 to 200 do begin
    var x := randU(20 + Random(400));
    var s := x.sqrt;
    check((s.sqr <= x) and ((s + 1).sqr > x), 'sqrt bounds');
    check(x.sqr = x * x, 'sqr equals mul');
    var n := 2 + Random(9);
    var r := x.nthRoot(n);
    check((r.pow(n) <= x) and ((r + 1).pow(n) > x), $'nthRoot {n} bounds');
  end;
  check(UBigInt(27).nthRoot(3) = 3, 'cube root 27');
  check(UBigInt(26).nthRoot(3) = 2, 'cube root 26');
  check(UBigInt(32).nthRoot(5) = 2, '5th root 32');
  check(UBigInt(12345).nthRoot(1) = 12345, '1st root');
  check(UBigInt(3).pow(0) = 1, 'pow 0');
  check(UBigInt(2).pow(10) = 1024, 'pow 10');
  check(BigInt(-2).pow(3) = -8, 'negative pow odd');
  check(BigInt(-2).pow(2) = 4, 'negative pow even');
  check(BigInt(-27).nthRoot(3) = -3, 'negative cube root');
  check(BigInt(-8).sqr = 64, 'signed sqr');
  checkRaises(procedure begin BigInt(-16).nthRoot(2); end, EBigIntError, 'even root of negative');
  checkRaises(procedure begin BigInt(-16).sqrt; end, EBigIntError, 'sqrt of negative');
  checkRaises(procedure begin UBigInt(16).nthRoot(0); end, EBigIntError, 'zeroth root');
  for var i := 1 to 50 do begin
    var b := randB(80);
    var e := Random(20);
    check(b.pow(e) = b ** e, 'pow equals ** operator');
  end;
end;

procedure testMathGcdLcm;
begin
  section('gcd / lcm');
  check(UBigInt(12).gcd(18) = 6, 'gcd 12 18');
  check(UBigInt(0).gcd(7) = 7, 'gcd 0 x');
  check(UBigInt(7).gcd(0) = 7, 'gcd x 0');
  check(UBigInt(4).lcm(6) = 12, 'lcm 4 6');
  check(UBigInt(5).lcm(0).isZero, 'lcm x 0');
  check(BigInt(-12).gcd(18) = 6, 'signed gcd uses magnitudes');
  check(BigInt(-4).lcm(-6) = 12, 'signed lcm nonnegative');
  for var i := 1 to 150 do begin
    var a := randU(150) + 1;
    var b := randU(120) + 1;
    var g := randU(40) + 1;
    check((a * g).gcd(b * g) = a.gcd(b) * g, 'gcd scaling');
    check(a.gcd(b) * a.lcm(b) = a * b, 'gcd * lcm = product');
    check((a mod a.gcd(b)).isZero and (b mod a.gcd(b)).isZero, 'gcd divides both');
  end;
end;

procedure testMathModular;
const
  p: Int64 = 1000000007;
begin
  section('modPow / modInverse');
  check(UBigInt(4).modPow(UBigInt(13), UBigInt(497)) = 445, 'modPow classic');
  check(UBigInt(5).modPow(UBigInt(0), UBigInt(7)) = 1, 'modPow exp 0');
  check(UBigInt(5).modPow(UBigInt(100), UBigInt(1)).isZero, 'modPow mod 1');
  check(UBigInt(3).modInverse(11) = 4, 'modInverse 3 mod 11');
  for var i := 1 to 100 do begin
    var a := randU(200) mod (p - 1) + 1;
    check(a.modPow(UBigInt(p - 1), UBigInt(p)) = 1, 'Fermat little theorem');
    var inv := a.modInverse(p);
    check((a * inv) mod p = 1, 'modular inverse');
  end;
  // naive cross-check on small numbers
  for var i := 1 to 200 do begin
    var base := UBigInt(Random(1000));
    var e := Random(40);
    var m := UBigInt(Random(5000) + 2);
    check(base.modPow(UBigInt(e), m) = (base ** e) mod m, 'modPow vs naive');
  end;
  checkRaises(procedure begin UBigInt(6).modInverse(9); end, EBigIntError, 'no inverse when gcd > 1');
  checkRaises(procedure begin UBigInt(6).modPow(UBigInt(2), UBigInt(0)); end, EDivByZero, 'modPow mod 0');

  // signed variants
  check(BigInt(-4).modPow(BigInt(13), BigInt(497)) = 52, 'negative base modPow');
  check(BigInt(3).modPow(BigInt(-1), BigInt(11)) = 4, 'negative exponent = inverse');
  check(BigInt(3).modPow(BigInt(-2), BigInt(11)) = 5, 'exp -2');
  check(BigInt(-3).modInverse(BigInt(11)) = 7, 'inverse of negative');
  checkRaises(procedure begin BigInt(3).modPow(BigInt(2), BigInt(-5)); end, EBigIntError, 'negative modulus');
end;

procedure testMathFactFib;
begin
  section('factorial / fibonacci');
  check(UBigInt.factorial(0) = 1, '0! = 1');
  check(UBigInt.factorial(1) = 1, '1! = 1');
  check(UBigInt.factorial(20).toUInt64 = QWord(2432902008176640000), '20!');
  checkEq(UBigInt.factorial(50).toString, '30414093201713378043612608166064768844377641568960512000000000000', '50!');
  for var i := 1 to 20 do begin
    var n := 2 + LongWord(Random(300));
    check(UBigInt.factorial(n) = UBigInt.factorial(n - 1) * Int64(n), 'factorial recurrence');
  end;
  check(BigInt.factorial(10) = 3628800, 'signed factorial wrapper');

  check(UBigInt.fibonacci(0).isZero, 'F(0)');
  check(UBigInt.fibonacci(1) = 1, 'F(1)');
  check(UBigInt.fibonacci(10) = 55, 'F(10)');
  check(UBigInt.fibonacci(90).toUInt64 = QWord(2880067194370816120), 'F(90)');
  checkEq(UBigInt.fibonacci(100).toString, '354224848179261915075', 'F(100)');
  for var i := 1 to 30 do begin
    var n := 2 + LongWord(Random(500));
    check(UBigInt.fibonacci(n) = UBigInt.fibonacci(n - 1) + UBigInt.fibonacci(n - 2), 'fib recurrence');
    // Cassini: F(n-1)*F(n+1) - F(n)^2 = (-1)^n
    var cas := BigInt.fibonacci(n - 1) * BigInt.fibonacci(n + 1) - BigInt.fibonacci(n).sqr;
    check(cas = (if n and 1 = 0 then 1 else -1), 'Cassini identity');
  end;
end;

procedure testMathPrimes;
begin
  section('primality');
  check(UBigInt(2).isProbablePrime, '2 prime');
  check(UBigInt(3).isProbablePrime, '3 prime');
  check(UBigInt(97).isProbablePrime, '97 prime');
  check(UBigInt(999999937).isProbablePrime, '999999937 prime');
  check(not UBigInt(0).isProbablePrime, '0 not prime');
  check(not UBigInt(1).isProbablePrime, '1 not prime');
  check(not UBigInt(561).isProbablePrime, 'Carmichael 561 composite');
  check(not UBigInt(41041).isProbablePrime, 'Carmichael 41041 composite');
  check(UBigInt('2305843009213693951').isProbablePrime, '2^61-1 prime');
  check(UBigInt('170141183460469231731687303715884105727').isProbablePrime, '2^127-1 prime');
  check(not ((UBigInt(1) shl 67) - 1).isProbablePrime, '2^67-1 composite');
  check(not BigInt(-7).isProbablePrime, 'negative not prime');
  check(UBigInt(0).nextPrime = 2, 'nextPrime 0');
  check(UBigInt(2).nextPrime = 3, 'nextPrime 2');
  check(UBigInt(10).nextPrime = 11, 'nextPrime 10');
  check(UBigInt(13).nextPrime = 17, 'nextPrime 13');
  check(UBigInt(89).nextPrime = 97, 'nextPrime 89');
  check(BigInt(-100).nextPrime = 2, 'nextPrime negative');
  for var i := 1 to 10 do begin
    var x := randU(48);
    var np := x.nextPrime;
    check((np > x) and np.isProbablePrime, 'nextPrime is a bigger prime');
  end;
end;

procedure testBytesEtc;
begin
  section('bytes / hashCode / digitCount / grouping / constants');
  check(Length(UBigInt(0).toBytesLE) = 0, 'zero magnitude has no bytes');
  var b258 := UBigInt(258).toBytesLE;
  check((Length(b258) = 2) and (b258[0] = 2) and (b258[1] = 1), '258 bytes LE');
  var be := UBigInt(258).toBytesBE;
  check((be[0] = 1) and (be[1] = 2), '258 bytes BE');
  for var i := 1 to 100 do begin
    var x := randU(10 + Random(300));
    check(UBigInt.fromBytesLE(x.toBytesLE) = x, 'U bytes LE roundtrip');
    check(UBigInt.fromBytesBE(x.toBytesBE) = x, 'U bytes BE roundtrip');
  end;

  // two's complement bytes, Java toByteArray convention
  var tc := BigInt(0).toBytesLE;
  check((Length(tc) = 1) and (tc[0] = 0), 'tc bytes of 0');
  tc := BigInt(127).toBytesLE;
  check((Length(tc) = 1) and (tc[0] = 127), 'tc bytes of 127');
  tc := BigInt(128).toBytesLE;
  check((Length(tc) = 2) and (tc[0] = 128) and (tc[1] = 0), 'tc bytes of 128');
  tc := BigInt(-128).toBytesLE;
  check((Length(tc) = 1) and (tc[0] = $80), 'tc bytes of -128');
  tc := BigInt(-1).toBytesLE;
  check((Length(tc) = 1) and (tc[0] = $FF), 'tc bytes of -1');
  tc := BigInt(-255).toBytesLE;
  check((Length(tc) = 2) and (tc[0] = $01) and (tc[1] = $FF), 'tc bytes of -255');
  for var i := 1 to 100 do begin
    var x := randB(10 + Random(300));
    check(BigInt.fromBytesLE(x.toBytesLE) = x, 'B bytes LE roundtrip');
    check(BigInt.fromBytesBE(x.toBytesBE) = x, 'B bytes BE roundtrip');
  end;

  var h1 := UBigInt('123456789123456789').hashCode;
  var h2 := UBigInt('123456789123456789').hashCode;
  check(h1 = h2, 'hashCode deterministic');
  check(BigInt(1).hashCode <> BigInt(-1).hashCode, 'hashCode sign sensitive');

  check(UBigInt(0).digitCount = 1, 'digitCount 0');
  check(UBigInt(999).digitCount = 3, 'digitCount 999');
  check(UBigInt(1000).digitCount = 4, 'digitCount 1000');
  check(BigInt(-1234).digitCount = 4, 'digitCount ignores sign');

  checkEq(UBigInt(1234567).toStringGrouped, '1_234_567', 'grouped default');
  checkEq(BigInt(-1234567).toStringGrouped, '-1_234_567', 'grouped negative');
  checkEq(UBigInt(1234567).toStringGrouped(',', 2), '1,23,45,67', 'grouped custom');
  checkEq(UBigInt(123).toStringGrouped, '123', 'grouped short');
  checkEq(UBigInt(0).toStringGrouped, '0', 'grouped zero');

  check(UBigInt.zero.isZero and UBigInt.one.isOne and (UBigInt.two = 2) and (UBigInt.ten = 10), 'U constants');
  check(BigInt.zero.isZero and BigInt.one.isOne and (BigInt.two = 2) and (BigInt.ten = 10) and (BigInt.minusOne = -1), 'B constants');
  check(UBigInt.pow2(100) = UBigInt(1) shl 100, 'pow2');
  check(BigInt.pow2(31) = 2147483648, 'B pow2');

  check(UBigInt.random(0).isZero, 'random 0 bits');
  for var i := 1 to 200 do begin
    var bits := 1 + LongWord(Random(300));
    check(UBigInt.random(bits).bitLength <= bits, 'random bit bound');
  end;
  check(not BigInt.random(128).isNegative, 'B random nonnegative');
end;

procedure testKaratsuba;
begin
  section('Karatsuba vs schoolbook cross-check');
  var saved := BigIntKaratsubaThreshold;
  for var i := 1 to 60 do begin
    var a := randU(200 + Random(6000));
    var b := randU(200 + Random(6000));
    BigIntKaratsubaThreshold := 4;
    var pk := a * b;
    var sk := a.sqr;
    BigIntKaratsubaThreshold := 1000000;
    check(pk = a * b, 'kara mul = schoolbook mul');
    check(sk = a.sqr, 'kara sqr = schoolbook sqr');
    BigIntKaratsubaThreshold := saved;
    check((a * b) div b = a, 'big roundtrip at default threshold');
    check(a.sqr = a * a, 'sqr = mul at default threshold');
  end;
  // unbalanced operand shapes
  for var i := 1 to 25 do begin
    var a := randU(20000 + Random(20000));
    var b := randU(50 + Random(3000));
    BigIntKaratsubaThreshold := 4;
    var pk := a * b;
    BigIntKaratsubaThreshold := 1000000;
    check(pk = a * b, 'unbalanced kara mul');
    BigIntKaratsubaThreshold := saved;
  end;
  // factorial through both paths
  BigIntKaratsubaThreshold := 4;
  var f1 := UBigInt.factorial(1500);
  BigIntKaratsubaThreshold := 1000000;
  var f2 := UBigInt.factorial(1500);
  BigIntKaratsubaThreshold := saved;
  check(f1 = f2, 'factorial via both mul paths');
  check(f1 = UBigInt.factorial(1499) * 1500, 'factorial recurrence big');
end;

procedure testToom3;
begin
  section('Toom-3 vs Karatsuba/schoolbook cross-check');
  var savedK := BigIntKaratsubaThreshold;
  var savedT := BigIntToom3Threshold;
  for var i := 1 to 30 do begin
    var a := randU(3000 + Random(20000));
    var b := randU(3000 + Random(20000));
    BigIntKaratsubaThreshold := 4;
    BigIntToom3Threshold := 8;
    var pt := a * b;
    var st := a.sqr;
    BigIntToom3Threshold := 1000000;
    check(pt = a * b, 'toom3 mul = karatsuba mul');
    check(st = a.sqr, 'toom3 sqr = karatsuba sqr');
    BigIntKaratsubaThreshold := 1000000;
    check(pt = a * b, 'toom3 mul = schoolbook mul');
    BigIntKaratsubaThreshold := savedK;
    BigIntToom3Threshold := savedT;
    check((a * b) div b = a, 'roundtrip at default thresholds');
    check(a.sqr = a * a, 'sqr = mul at default thresholds');
  end;
  // all-ones operands push maximal carries through the interpolation
  var ones := UBigInt.pow2(40000) - 1;
  BigIntKaratsubaThreshold := 4;
  BigIntToom3Threshold := 8;
  var po := ones * ones;
  var so := ones.sqr;
  BigIntKaratsubaThreshold := 1000000;
  BigIntToom3Threshold := 1000000;
  check(po = ones * ones, 'all-ones toom3 mul');
  check(so = po, 'all-ones toom3 sqr');
  BigIntKaratsubaThreshold := savedK;
  BigIntToom3Threshold := savedT;
end;

procedure testStressChain;
begin
  section('stress: long random operator chains vs Int64 oracle');
  var b: BigInt := 0;
  var o: Int64 := 0;
  for var i := 1 to 20000 do begin
    if System.Abs(o) > High(Int64) div 8 then begin
      o := o div 65536;
      b := b div 65536;
    end;
    var v := randI(30);
    if v = 0 then v := 7;
    case Random(9) of
      0: begin o := o + v; b := b + v; end;
      1: begin o := o - v; b := b - v; end;
      2: begin o := (o mod 100000007) * (v mod 1000); b := (b mod 100000007) * (v mod 1000); end;
      3: begin o := o div v; b := b div v; end;
      4: begin o := o mod v; b := b mod v; end;
      5: begin o := o and v; b := b and v; end;
      6: begin o := o or v; b := b or v; end;
      7: begin o := o xor v; b := b xor v; end;
      8: begin o := SarInt64(o, 3); b := b shr 3; end;
    end;
    if b <> o then begin
      check(false, $'chain drift at step {i}: got {b} want {o}');
      exit;
    end;
  end;
  check(true, 'chain of 20000 mixed ops matches oracle');
end;

procedure testStressStrings;
begin
  section('stress: big parse/format roundtrips');
  for var i := 1 to 6 do begin
    var x := randU(20000 + Random(20000));
    check(UBigInt.parse(x.toString) = x, 'huge decimal roundtrip');
    check(UBigInt.parse(x.toHex, 16) = x, 'huge hex roundtrip');
    check(UBigInt.parse(x.toString(7), 7) = x, 'huge base 7 roundtrip');
    check(UBigInt.parse(x.toString(36), 36) = x, 'huge base 36 roundtrip');
  end;
end;

procedure testExtrasRandom;
begin
  section('extras: random suite');
  for var algo in [rngXoshiro256ss, rngPcg64, rngSplitMix64, rngSystem] do begin
    BigIntRngAlgo := algo;
    BigIntRandomSeed(12345);
    var a := UBigInt.random(256);
    BigIntRandomSeed(12345);
    var b := UBigInt.random(256);
    check(a = b, 'seeded stream reproduces');
    check(UBigInt.random(256) <> a, 'stream advances');
  end;
  BigIntRngAlgo := rngXoshiro256ss;
  BigIntRandomSeed(99);
  for var i := 1 to 200 do begin
    var n := UBigInt.random(80) + 1;
    check(UBigInt.randomBelow(n) < n, 'randomBelow bound');
  end;
  for var i := 1 to 200 do begin
    var lo := BigInt.random(60) - BigInt.pow2(59);
    var hi := lo + BigInt.random(50);
    var r := BigInt.randomRange(lo, hi);
    check((r >= lo) and (r <= hi), 'randomRange bounds');
  end;
  for var bits in [8, 16, 48, 128] do begin
    var p := UBigInt.randomPrime(bits);
    check(p.bitLength = LongWord(bits), 'randomPrime exact bits');
    check(p.isProbablePrime, 'randomPrime is prime');
  end;
  BigIntRngAlgo := rngOS;
  check(UBigInt.random(256) <> UBigInt.random(256), 'rngOS varies');
  BigIntRngAlgo := rngXoshiro256ss;
  checkRaises(procedure begin UBigInt.randomBelow(UBigInt.zero); end, EBigIntError, 'randomBelow zero bound');
end;

procedure testExtrasNumberTheory;
begin
  section('extras: gcdExt / jacobi / modSqrt / crt');
  for var i := 1 to 100 do begin
    var a := BigInt.random(1 + Random(300));
    var b := BigInt.random(1 + Random(300));
    if Random(2) = 1 then a.negate;
    if Random(2) = 1 then b.negate;
    var (g, x, y) := a.gcdExt(b);
    check(a * x + b * y = g, 'Bezout identity');
    check(g = a.gcd(b), 'gcdExt matches gcd');
  end;
  // unsigned gcdExt agrees with the signed one
  for var i := 1 to 50 do begin
    var ua := UBigInt.random(1 + Random(300));
    var ub := UBigInt.random(1 + Random(300));
    var (g, x, y) := ua.gcdExt(ub);
    check(ua.toBigInt * x + ub.toBigInt * y = g.toBigInt, 'unsigned Bezout identity');
    check(g = ua.gcd(ub), 'unsigned gcdExt matches gcd');
  end;
  var (g0, x0, y0) := UBigInt(0).gcdExt(UBigInt(0));
  check(g0.isZero and (x0*0 + y0*0 = 0), 'unsigned gcdExt(0,0)');
  // jacobi against the Euler criterion for a prime modulus
  var p: BigInt := 1000000007;
  for var i := 1 to 100 do begin
    var a := BigInt.random(120);
    var e := a.modPow((p - 1) div 2, p);
    var euler := if e = p - 1 then -1 else e.toInt32;
    check(a.jacobi(p) = euler, 'jacobi = Euler criterion');
  end;
  check(BigInt(1001).jacobi(BigInt(9907)) = -1, 'jacobi 1001/9907');
  check(BigInt(19).jacobi(BigInt(45)) = 1, 'jacobi 19/45');
  check(BigInt(8).jacobi(BigInt(21)) = -1, 'jacobi 8/21');
  check(BigInt(21).jacobi(BigInt(21)) = 0, 'jacobi shared factor');
  checkRaises(procedure begin BigInt(3).jacobi(BigInt(10)); end, EBigIntError, 'jacobi even modulus');
  // modSqrt roundtrips for primes of both residue classes mod 4
  var sprimes: array of Int64 := [1000000007, 998244353, 65537, 104729];
  for var pi := 0 to High(sprimes) do begin
    var pp := UBigInt(QWord(sprimes[pi]));
    for var i := 1 to 40 do begin
      var sq := (UBigInt.random(100) mod pp).sqr mod pp;
      var r := sq.modSqrt(pp);
      check(r.sqr mod pp = sq, $'modSqrt roundtrip p={sprimes[pi]}');
    end;
  end;
  var z: UBigInt := 2;
  while z.jacobi(UBigInt(1000000007)) <> -1 do z := z + 1;
  checkRaises(procedure begin z.modSqrt(UBigInt(1000000007)); end, EBigIntError, 'non-residue raises');
  // crt
  check(BigInt.crt([BigInt(2), BigInt(3), BigInt(2)], [BigInt(3), BigInt(5), BigInt(7)]) = 23, 'crt classic 23');
  var m1: BigInt := 97;
  var m2: BigInt := 1000000007;
  var m3: BigInt := 998244353;
  for var i := 1 to 50 do begin
    var x := BigInt.random(90);
    check(BigInt.crt([x mod m1, x mod m2, x mod m3], [m1, m2, m3]) = x mod (m1 * m2 * m3), 'crt roundtrip');
  end;
  // multiplicative order
  check(UBigInt(2).multiplicativeOrder(UBigInt(7)) = 3, 'ord(2 mod 7) = 3');
  check(UBigInt(3).multiplicativeOrder(UBigInt(7)) = 6, 'ord(3 mod 7) = 6');
  check(UBigInt(10).multiplicativeOrder(UBigInt(17)) = 16, 'ord(10 mod 17) = 16');
  check(UBigInt(3).multiplicativeOrder(UBigInt(100)) = 20, 'ord(3 mod 100) = 20');
  checkRaises(procedure begin UBigInt(6).multiplicativeOrder(UBigInt(15)); end, EBigIntError, 'ord needs coprime');
  var p17: UBigInt := 65537;
  for var i := 1 to 30 do begin
    var a := UBigInt.random(200) mod p17;
    if a.isZero then a := 3;
    var ord := a.multiplicativeOrder(p17);
    check(a.modPow(ord, p17).isOne, 'a^ord = 1');
    check((UBigInt(65536) mod ord).isZero, 'ord divides p-1');
    if ord.isEven then check(not a.modPow(ord shr 1, p17).isOne, 'ord is minimal');
  end;
  // primitive roots
  check(UBigInt(2).primitiveRoot = 1, 'primitiveRoot(2)');
  check(UBigInt(4).primitiveRoot = 3, 'primitiveRoot(4)');
  check(UBigInt(7).primitiveRoot = 3, 'primitiveRoot(7)');
  check(UBigInt(9).primitiveRoot = 2, 'primitiveRoot(9)');
  check(UBigInt(18).primitiveRoot = 5, 'primitiveRoot(18)');
  check(UBigInt(998244353).primitiveRoot = 3, 'primitiveRoot(998244353)');
  check(UBigInt(1000000007).primitiveRoot = 5, 'primitiveRoot(1000000007)');
  checkRaises(procedure begin UBigInt(8).primitiveRoot; end, EBigIntError, 'no primitive root mod 8');
  checkRaises(procedure begin UBigInt(15).primitiveRoot; end, EBigIntError, 'no primitive root mod 15');
  check(UBigInt(3).isPrimitiveRoot(UBigInt(998244353)), '3 generates mod 998244353');
  check(not UBigInt(2).isPrimitiveRoot(UBigInt(7)), '2 does not generate mod 7');
  check(not UBigInt(6).isPrimitiveRoot(UBigInt(15)), 'non-coprime is no generator');
  for var i := 0 to High(sprimes) do begin
    var pp := UBigInt(QWord(sprimes[i]));
    var g := pp.primitiveRoot;
    check(g.multiplicativeOrder(pp) = pp - 1, $'primitiveRoot order p={sprimes[i]}');
  end;
  // signed wrappers
  check(BigInt(-4).multiplicativeOrder(BigInt(7)) = 6, 'signed ord(-4 mod 7)');
  check(BigInt(7).primitiveRoot = 3, 'signed primitiveRoot');
  check(BigInt(-1).isPrimitiveRoot(BigInt(3)), 'signed isPrimitiveRoot(-1 mod 3)');
  // lucasSequence: P=1, Q=-1 gives Fibonacci and Lucas numbers
  var lm: BigInt := 1000000007;
  for var i := 1 to 20 do begin
    var n := LongWord(Random(500));
    var (u, v) := BigInt.lucasSequence(1, -1, BigInt(Int64(n)), lm);
    check(u = BigInt.fibonacci(n) mod lm, $'lucasSequence U = fib({n})');
    check(v = BigInt.lucas(n) mod lm, $'lucasSequence V = lucas({n})');
  end;
  // random parameters against the recurrence oracle
  for var i := 1 to 30 do begin
    var lp := BigInt(Int64(Random(19)) - 9);
    var lq := BigInt(Int64(Random(19)) - 9);
    var lmm := BigInt(Int64(3 + 2 * Random(500)));
    var n := Random(80);
    var u0 := BigInt.zero;
    var u1 := BigInt.one;
    var v0 := BigInt(2).floorMod(lmm);
    var v1 := lp.floorMod(lmm);
    for var j := 2 to n do begin
      (u0, u1) := (u1, (lp * u1 - lq * u0).floorMod(lmm));
      (v0, v1) := (v1, (lp * v1 - lq * v0).floorMod(lmm));
    end;
    var (u, v) := BigInt.lucasSequence(lp, lq, BigInt(Int64(n)), lmm);
    var wantU := u1;
    var wantV := v1;
    if n = 0 then begin
      wantU := u0;
      wantV := v0;
    end;
    check(u = wantU, $'lucasSequence U oracle n={n}');
    check(v = wantV, $'lucasSequence V oracle n={n}');
  end;
  // nthRootMod: roundtrip x^k -> root -> ^k over primes with rich p-1 torsion
  var rprimes: array of Int64 := [1000000007, 998244353, 65537, 104729, 786433]; // 786433 = 3*2^18+1, 998244353 = 119*2^23+1
  for var pi := 0 to High(rprimes) do begin
    var pp := UBigInt(QWord(rprimes[pi]));
    for var i := 1 to 25 do begin
      var k := LongWord(1 + Random(24));
      var x := UBigInt.random(80) mod pp;
      var a := x.modPow(UBigInt(QWord(k)), pp);
      var r := a.nthRootMod(k, pp);
      check(r.modPow(UBigInt(QWord(k)), pp) = a, $'nthRootMod roundtrip k={k} p={rprimes[pi]}');
    end;
  end;
  check(UBigInt(0).nthRootMod(5, UBigInt(97)).isZero, 'nthRootMod of 0');
  check(UBigInt(27).nthRootMod(3, UBigInt(2)).isOne, 'nthRootMod p=2');
  check(UBigInt(10).nthRootMod(1, UBigInt(97)) = 10, 'nthRootMod k=1');
  // 2 is not a cube mod 7 (cubes mod 7 are 1 and 6)
  checkRaises(procedure begin UBigInt(2).nthRootMod(3, UBigInt(7)); end, EBigIntError, 'no cube root of 2 mod 7');
  checkRaises(procedure begin UBigInt(5).nthRootMod(0, UBigInt(7)); end, EBigIntError, 'nthRootMod k=0');
  // k a multiple of p-1: only 1 has a root
  check(UBigInt(1).nthRootMod(6, UBigInt(7)).isOne, 'nthRootMod k=p-1 of 1');
  checkRaises(procedure begin UBigInt(2).nthRootMod(6, UBigInt(7)); end, EBigIntError, 'nthRootMod k=p-1 of 2');
  check(BigInt(-1).nthRootMod(3, BigInt(7)).modPow(BigInt(3), BigInt(7)) = 6, 'signed nthRootMod');
  var (lsU, lsV) := BigInt.lucasSequence(3, 2, BigInt.zero, BigInt(101));
  check(lsU.isZero and (lsV = 2), 'lucasSequence n=0');
  checkRaises(procedure begin BigInt.lucasSequence(1, -1, BigInt(5), BigInt(10)); end, EBigIntError, 'lucasSequence even modulus');
  checkRaises(procedure begin BigInt.lucasSequence(1, -1, BigInt(-1), BigInt(7)); end, EBigIntError, 'lucasSequence negative index');
end;

procedure testExtrasCombinatorics;
begin
  section('extras: binomial / catalan / lucas / primorial / squares / prevPrime');
  check(UBigInt.binomial(0, 0) = 1, 'C(0,0)');
  check(UBigInt.binomial(5, 2) = 10, 'C(5,2)');
  check(UBigInt.binomial(10, 11).isZero, 'C(10,11) = 0');
  checkEq(UBigInt.binomial(100, 50).toString, '100891344545564193334812497256', 'C(100,50)');
  for var i := 1 to 50 do begin
    var n := LongWord(2 + Random(300));
    var k := LongWord(1 + Random(integer(n) - 1));
    check(UBigInt.binomial(n, k) = UBigInt.binomial(n - 1, k - 1) + UBigInt.binomial(n - 1, k), 'Pascal rule');
  end;
  // binomialMod vs the exact binomial
  var bmprimes: array of Int64 := [2, 3, 7, 13, 65537, 1000000007];
  for var pi := 0 to High(bmprimes) do begin
    var pp := UBigInt(QWord(bmprimes[pi]));
    for var i := 1 to 30 do begin
      var n := LongWord(Random(300));
      var k := LongWord(Random(320));
      check(UBigInt.binomialMod(UBigInt(QWord(n)), UBigInt(QWord(k)), pp) = UBigInt.binomial(n, k) mod pp, $'binomialMod n={n} k={k} p={bmprimes[pi]}');
    end;
  end;
  // huge arguments, p=2: C(n,k) is odd iff k and (n-k) share no set bit
  for var i := 1 to 30 do begin
    var n := UBigInt.random(200);
    var k := UBigInt.randomBelow(n + 1);
    var wantOdd := ((k.toBigInt and (n - k).toBigInt) = 0);
    check(UBigInt.binomialMod(n, k, UBigInt.two).isOne = wantOdd, 'binomialMod p=2 Kummer');
  end;
  // Pascal rule mod p on huge arguments
  var bp: UBigInt := 1000003;
  for var i := 1 to 20 do begin
    var n := UBigInt.random(120) + 2;
    var k := UBigInt.randomBelow(n - 1) + 1;
    check(UBigInt.binomialMod(n, k, bp) = (UBigInt.binomialMod(n - 1, k - 1, bp) + UBigInt.binomialMod(n - 1, k, bp)) mod bp, 'binomialMod Pascal rule');
  end;
  check(UBigInt.binomialMod(UBigInt(10), UBigInt(11), UBigInt(7)).isZero, 'binomialMod k>n');
  check(UBigInt.binomialMod(UBigInt(10), UBigInt(0), UBigInt(7)).isOne, 'binomialMod k=0');
  check(BigInt.binomialMod(BigInt(100), BigInt(50), BigInt(13)) = BigInt.binomial(100, 50) mod 13, 'signed binomialMod');
  checkRaises(procedure begin BigInt.binomialMod(BigInt(-1), BigInt(2), BigInt(7)); end, EBigIntError, 'binomialMod negative n');
  check(UBigInt.catalan(0) = 1, 'catalan 0');
  check(UBigInt.catalan(10) = 16796, 'catalan 10');
  check(UBigInt.lucas(0) = 2, 'L(0)');
  check(UBigInt.lucas(1) = 1, 'L(1)');
  for var i := 1 to 30 do begin
    var n := LongWord(1 + Random(2000));
    check(UBigInt.lucas(n) = UBigInt.fibonacci(n - 1) + UBigInt.fibonacci(n + 1), 'lucas via fibonacci');
  end;
  check(UBigInt.primorial(1) = 1, 'primorial 1');
  check(UBigInt.primorial(2) = 2, 'primorial 2');
  check(UBigInt.primorial(10) = 210, 'primorial 10');
  check(UBigInt.primorial(30) = 6469693230, 'primorial 30');
  checkEq(UBigInt.primorial(100).toString, '2305567963945518424753102147331756070', 'primorial 100');
  for var i := 1 to 100 do begin
    var a := UBigInt.random(1 + Random(400));
    check(a.sqr.isPerfectSquare, 'square detected');
    var (rt, rm) := a.sqr.sqrtRem;
    check((rt = a) and rm.isZero, 'sqrtRem of a square');
    if not a.isZero then check(not (a.sqr + 1).isPerfectSquare, 'square plus one is not a square');
  end;
  check(not UBigInt(2).isPerfectSquare, '2 not a square');
  check(UBigInt(99980001).isPerfectSquare, '9999^2 detected');
  check(not BigInt(-4).isPerfectSquare, 'negative never a square');
  check(UBigInt(3).prevPrime = 2, 'prevPrime 3');
  check(UBigInt(100).prevPrime = 97, 'prevPrime 100');
  for var i := 1 to 20 do begin
    var p := UBigInt.randomPrime(40);
    check(p.nextPrime.prevPrime = p, 'prevPrime inverts nextPrime');
  end;
  checkRaises(procedure begin UBigInt(2).prevPrime; end, EBigIntError, 'prevPrime below 2');
end;

procedure testExtrasFactorize;
begin
  section('extras: factorize');
  var f := UBigInt(720).factorize;
  check(Length(f) = 3, '720 three primes');
  check((f[0].p = 2) and (f[0].e = 4) and (f[1].p = 3) and (f[1].e = 2) and (f[2].p = 5) and (f[2].e = 1), '720 = 2^4*3^2*5');
  check(Length(UBigInt(1).factorize) = 0, '1 factors to nothing');
  check(Length(UBigInt(0).factorize) = 0, '0 factors to nothing');
  var bigp: UBigInt := 1000000007;
  f := (bigp * bigp * 2).factorize;
  check((Length(f) = 2) and (f[0].p = 2) and (f[1].p = bigp) and (f[1].e = 2), 'factorize 2*p^2');
  for var i := 1 to 25 do begin
    var n := UBigInt.random(1 + Random(48)) + 2;
    var fac := n.factorize;
    var prod := UBigInt.one;
    for var j := 0 to High(fac) do prod := prod * fac[j].p.pow(fac[j].e);
    check(prod = n, 'factor product roundtrip');
    for var j := 0 to High(fac) do check(fac[j].p.isProbablePrime, 'every factor is prime');
    for var j := 1 to High(fac) do check(fac[j - 1].p < fac[j].p, 'factors ascending');
  end;
  var sf := BigInt(-360).factorize;
  check((Length(sf) = 3) and (sf[0].p = 2) and (sf[0].e = 3) and (sf[1].p = 3) and (sf[1].e = 2) and (sf[2].p = 5), 'factorize abs(-360)');
  var (sr, sm) := BigInt(-360).abs.sqrtRem;
  check((sr = 18) and (sm = 36), 'signed sqrtRem');
end;

function dblBits(d: Double): QWord;
begin
  Move(d, result, 8);
end;

function dblFromBits(q: QWord): Double;
begin
  Move(q, result, 8);
end;

function sngBits(s: Single): DWord;
begin
  Move(s, result, 4);
end;

function sngFromBits(q: DWord): Single;
begin
  Move(q, result, 4);
end;

// random BigDecimal: mantissa up to `bits` bits, decimal exponent -30..29
function randDec(bits: integer): BigDecimal;
begin
  var m := randU(bits).toBigInt;
  if Random(2) = 1 then m.negate;
  result := BigDecimal(m).shifted10(Random(60) - 30);
end;

procedure testDecBasics;
begin
  section('BigDecimal basics');
  var d := default(BigDecimal);
  check(d.isZero, 'dec default init is zero');
  checkEq(d.toString, '0', 'dec zero toString');
  checkEq(d.toScientific, '0', 'dec zero toScientific');
  check(d.isIntegral and d.isEven and not d.isOdd and (d.sign = 0), 'dec zero properties');
  d := 42;
  checkEq(d.toString, '42', 'dec int assign');
  check(d.isIntegral and d.isEven and (d.sign = 1) and d.isPositive, 'dec 42 properties');
  d := '-123.45';
  checkEq(d.toString, '-123.45', 'dec parse basic');
  checkEq(d.toScientific, '-1.2345E2', 'dec sci basic');
  check((d.sign = -1) and d.isNegative and not d.isIntegral, 'dec neg properties');
  check(not d.isEven and not d.isOdd, 'dec fraction has no parity');
  d := '1.500';
  checkEq(d.toString, '1.5', 'dec canonical strips zeros');
  check(d.precision = 2, 'dec precision after strip');
  check(d = BigDecimal('1.5'), 'dec 1.500 = 1.5');
  check(d.hashCode = BigDecimal('0.15E1').hashCode, 'dec equal values hash equal');
  checkEq(BigDecimal('00012.3400').toString, '12.34', 'dec leading and trailing zeros');
  checkEq(BigDecimal('.5').toString, '0.5', 'dec leading dot');
  checkEq(BigDecimal('5.').toString, '5', 'dec trailing dot');
  checkEq(BigDecimal('1_234.5_6').toString, '1234.56', 'dec separators');
  checkEq(BigDecimal(' 2.5 ').toString, '2.5', 'dec whitespace trim');
  checkEq(BigDecimal('1.5E3').toString, '1500', 'dec positive exponent');
  checkEq(BigDecimal('+25e-4').toString, '0.0025', 'dec negative exponent');
  checkEq(BigDecimal('-0').toString, '0', 'dec minus zero');
  checkEq(BigDecimal('-0.0E9').toString, '0', 'dec minus zero exp');
  checkEq(BigDecimal('1E10').toString, '10000000000', 'dec plain big');
  checkEq(BigDecimal('5').toScientific, '5.0E0', 'dec sci one digit');
  checkEq(BigDecimal('0.00123').toScientific, '1.23E-3', 'dec sci small');
  var ok: BigDecimal;
  check(not BigDecimal.tryParse('', ok), 'dec parse empty');
  check(not BigDecimal.tryParse('.', ok), 'dec parse lone dot');
  check(not BigDecimal.tryParse('1.2.3', ok), 'dec parse two dots');
  check(not BigDecimal.tryParse('1E', ok), 'dec parse dangling E');
  check(not BigDecimal.tryParse('abc', ok), 'dec parse junk');
  check(not BigDecimal.tryParse('--1', ok), 'dec parse double sign');
  check(not BigDecimal.tryParse('1E99999999999999', ok), 'dec parse exponent overflow');
  check(BigDecimal.tryParse('-.5e+2', ok) and (ok.toString = '-50'), 'dec parse compact form');
  check(BigDecimal.zero.isZero and BigDecimal.one.isOne, 'dec constants zero one');
  checkEq((BigDecimal.two + BigDecimal.ten).toString, '12', 'dec constants two ten');
  checkEq(BigDecimal(QWord(18446744073709551615)).toString, '18446744073709551615', 'dec qword cast exact');
  checkEq(BigDecimal(Int64(-9223372036854775807 - 1)).toString, '-9223372036854775808', 'dec int64 cast exact');
  var bi: BigInt := '123456789012345678901234567890';
  checkEq(BigDecimal(bi).toString, '123456789012345678901234567890', 'dec from BigInt');
  var u: UBigInt := '999999999999999999999999';
  checkEq(BigDecimal(u).toString, '999999999999999999999999', 'dec from UBigInt');
  checkEq(string(BigDecimal('2.5')), '2.5', 'dec string cast');
  var a: BigDecimal := '1.5';
  var b: BigDecimal := '-7';
  a.swap(b);
  check((a = -7) and (b = BigDecimal('1.5')), 'dec swap');
  a := '4.25';
  a.negate;
  checkEq(a.toString, '-4.25', 'dec negate');
  checkEq(a.abs.toString, '4.25', 'dec abs');
  checkRaises(procedure begin var z := BigDecimal('nope'); end, EConvertError, 'dec parse raises');
end;

procedure testDecArithmetic;
begin
  section('BigDecimal arithmetic');
  checkEq((BigDecimal('0.1') + BigDecimal('0.2')).toString, '0.3', 'dec 0.1+0.2');
  checkEq((BigDecimal('1.5') * BigDecimal('2.5')).toString, '3.75', 'dec mul');
  checkEq((BigDecimal('10') - BigDecimal('0.001')).toString, '9.999', 'dec sub align');
  checkEq((BigDecimal('-1.5') * BigDecimal('-2')).toString, '3', 'dec neg mul');
  checkEq((BigDecimal('2.5') - BigDecimal('2.5')).toString, '0', 'dec sub to zero');
  var x: BigDecimal := '5.5';
  inc(x);
  checkEq(x.toString, '6.5', 'dec inc');
  dec(x);
  dec(x);
  checkEq(x.toString, '4.5', 'dec dec');
  checkEq((+x).toString, '4.5', 'dec unary plus');
  checkEq((-x).toString, '-4.5', 'dec unary minus');
  // random cross-check against integers on a common scale
  for var i := 1 to 300 do begin
    var am := randU(96).toBigInt;
    var bm := randU(96).toBigInt;
    if Random(2) = 1 then am.negate;
    if Random(2) = 1 then bm.negate;
    var ea := Random(40) - 20;
    var eb := Random(40) - 20;
    var a := BigDecimal(am).shifted10(ea);
    var b := BigDecimal(bm).shifted10(eb);
    var e := if ea < eb then ea else eb;
    var aScaled := am * BigInt.ten.pow(LongWord(ea - e));
    var bScaled := bm * BigInt.ten.pow(LongWord(eb - e));
    check(a + b = BigDecimal(aScaled + bScaled).shifted10(e), 'dec random add');
    check(a - b = BigDecimal(aScaled - bScaled).shifted10(e), 'dec random sub');
    check(a * b = BigDecimal(am * bm).shifted10(ea + eb), 'dec random mul');
    check((a + b) - b = a, 'dec add sub roundtrip');
    check(a.compare(b) = -b.compare(a), 'dec compare antisymmetry');
    check((a - b).sign = a.compare(b), 'dec compare vs difference sign');
  end;
  // comparisons across representations and magnitudes
  check(BigDecimal('0.5') = BigDecimal('5E-1'), 'dec eq across representations');
  check(BigDecimal('1.01') > BigDecimal('1.001'), 'dec gt');
  check(BigDecimal('-2') < BigDecimal('0.001'), 'dec lt signs');
  check(BigDecimal('1E30') > BigDecimal('999999999999'), 'dec magnitude fast path');
  check(BigDecimal('-1E30') < BigDecimal('-999999999999'), 'dec magnitude fast path neg');
  check(BigDecimal('2') = 2, 'dec int mixed eq');
  check(BigDecimal('2.5') > 2, 'dec int mixed gt');
  check(3 > BigDecimal('2.5'), 'dec int mixed reversed');
  check(BigDecimal('2.5').min(BigDecimal('2.4')) = BigDecimal('2.4'), 'dec min');
  check(BigDecimal('2.5').max(2) = BigDecimal('2.5'), 'dec max');
end;

procedure testDecDivision;
begin
  section('BigDecimal division');
  var third := BigDecimal.one / 3;
  checkEq(third.toString, '0.333333333333333333', 'dec 1/3 default 18 digits');
  checkEq((third * 3).toString, '1', 'dec (1/3)*3 prints 1');
  checkEq((third + third + third).toString, '1', 'dec thirds sum prints 1');
  check(third * 3 < BigDecimal.one, 'dec guard digit is real value');
  checkEq((BigDecimal.one / 8).toString, '0.125', 'dec exact division');
  checkEq((BigDecimal(100) / 4).toString, '25', 'dec integer quotient');
  checkEq((BigDecimal('0.5') / BigDecimal('0.25')).toString, '2', 'dec fractional exact');
  checkEq((BigDecimal(-1) / 3).toString, '-0.333333333333333333', 'dec negative quotient');
  checkEq(BigDecimal(2).divide(3, 4).toString, '0.6667', 'dec divide precision 4');
  checkEq(BigDecimal(2).divide(3, 0).toString, '1', 'dec divide precision 0 rounds display');
  checkEq(BigDecimal(1).divide(3, 0).toString, '0', 'dec divide precision 0 down');
  checkEq((BigDecimal('1E-30') / 2).toScientific, '5.0E-31', 'dec tiny operand keeps precision');
  var tiny := BigDecimal('1E-100') / 3;
  checkEq(Copy(tiny.toScientific, 1, 5), '3.333', 'dec tiny quotient keeps significant digits');
  // divMod identity and sign conventions
  checkEq((BigDecimal('7.5') div BigDecimal(2)).toString, '3', 'dec div');
  checkEq((BigDecimal('7.5') mod BigDecimal(2)).toString, '1.5', 'dec mod');
  checkEq((BigDecimal('-7.5') div BigDecimal(2)).toString, '-3', 'dec div neg');
  checkEq((BigDecimal('-7.5') mod BigDecimal(2)).toString, '-1.5', 'dec mod takes dividend sign');
  for var i := 1 to 200 do begin
    var a := randDec(80);
    var b := randDec(60);
    if b.isZero then continue;
    var (q, r) := a.divMod(b);
    check(q.isIntegral, 'dec divMod quotient integral');
    check(q * b + r = a, 'dec divMod identity');
    check(r.abs < b.abs, 'dec divMod remainder below divisor');
    check(r.isZero or (r.sign = a.sign), 'dec divMod remainder sign');
    // truncated quotient at the guard position: within 10^-p of the target
    var qd := a.divide(b, 6);
    check((a - qd * b).abs < b.abs * BigDecimal('1E-6'), 'dec divide within precision');
  end;
  checkRaises(procedure begin var z := BigDecimal(1) / 0; end, EDivByZero, 'dec div by zero');
  checkRaises(procedure begin var z := BigDecimal(1) div BigDecimal(0); end, EDivByZero, 'dec int div by zero');
end;

procedure testDecRounding;

  procedure modes(const v, t, c, f, r, hu, he: string);
  begin
    var x: BigDecimal := v;
    checkEq(x.rounded(0, bdrTrunc).toString, t, 'dec trunc ' + v);
    checkEq(x.rounded(0, bdrCeil).toString, c, 'dec ceil ' + v);
    checkEq(x.rounded(0, bdrFloor).toString, f, 'dec floor ' + v);
    checkEq(x.rounded(0, bdrRound).toString, r, 'dec round ' + v);
    checkEq(x.rounded(0, bdrHalfUp).toString, hu, 'dec halfup ' + v);
    checkEq(x.rounded(0, bdrHalfEven).toString, he, 'dec halfeven ' + v);
  end;

begin
  section('BigDecimal rounding');
  //     value     trunc ceil floor round halfup halfeven
  modes('2.5',     '2',  '3', '2',  '3',  '3',   '2');
  modes('-2.5',    '-2', '-2', '-3', '-3', '-2',  '-2');
  modes('3.5',     '3',  '4', '3',  '4',  '4',   '4');
  modes('-3.5',    '-3', '-3', '-4', '-4', '-3',  '-4');
  modes('2.4',     '2',  '3', '2',  '2',  '2',   '2');
  modes('2.6',     '2',  '3', '2',  '3',  '3',   '3');
  modes('-2.4',    '-2', '-2', '-3', '-2', '-2',  '-2');
  modes('0.5',     '0',  '1', '0',  '1',  '1',   '0');
  modes('-0.5',    '0',  '0', '-1', '-1', '0',   '0');
  modes('2.5001',  '2',  '3', '2',  '3',  '3',   '3');
  modes('-2.5001', '-2', '-2', '-3', '-3', '-3',  '-3');
  checkEq(BigDecimal('123.456').rounded(-2).toString, '123.46', 'dec round to cents');
  checkEq(BigDecimal('123.456').rounded(2).toString, '100', 'dec round to hundreds');
  checkEq(BigDecimal('987.654').rounded(3, bdrCeil).toString, '1000', 'dec ceil to thousands');
  checkEq(BigDecimal('0.004').rounded(6, bdrCeil).toString, '1000000', 'dec ceil far above digits');
  checkEq(BigDecimal('0.004').rounded(6, bdrRound).toString, '0', 'dec round far above digits');
  checkEq(BigDecimal('9.99').rounded(-1).toString, '10', 'dec carry through');
  checkEq(BigDecimal('42').rounded(-5).toString, '42', 'dec finer position is identity');
  for var i := 1 to 200 do begin
    var a := randDec(64);
    var toDigit := Random(20) - 10;
    for var mode := Low(TBigDecimalRounding) to High(TBigDecimalRounding) do begin
      var rr := a.rounded(toDigit, mode);
      check((rr - a).abs < BigDecimal.one.shifted10(toDigit), 'dec rounded distance');
      check(rr.rounded(toDigit, mode) = rr, 'dec rounded idempotent');
    end;
    check(a.rounded(-40, bdrTrunc) = a, 'dec rounding below scale is identity');
  end;
  // integer parts
  checkEq(BigDecimal('3.75').trunc.toString, '3', 'dec trunc method');
  checkEq(BigDecimal('-3.75').trunc.toString, '-3', 'dec trunc neg');
  checkEq(BigDecimal('3.75').floor.toString, '3', 'dec floor method');
  checkEq(BigDecimal('-3.75').floor.toString, '-4', 'dec floor neg');
  checkEq(BigDecimal('3.75').ceil.toString, '4', 'dec ceil method');
  checkEq(BigDecimal('-3.75').ceil.toString, '-3', 'dec ceil neg');
  checkEq(BigDecimal('2.5').round.toString, '2', 'dec round ties to even down');
  checkEq(BigDecimal('3.5').round.toString, '4', 'dec round ties to even up');
  checkEq(BigDecimal('3.75').frac.toString, '0.75', 'dec frac');
  checkEq(BigDecimal('-3.75').frac.toString, '-0.75', 'dec frac neg');
  checkEq(BigDecimal('42').frac.toString, '0', 'dec frac integral');
  for var i := 1 to 100 do begin
    var a := randDec(64);
    check(BigDecimal(a.floor) <= a, 'dec floor below');
    check(BigDecimal(a.ceil) >= a, 'dec ceil above');
    check(BigDecimal(a.ceil) - BigDecimal(a.floor) <= BigDecimal.one, 'dec floor ceil gap');
    check(BigDecimal(a.trunc) + a.frac = a, 'dec trunc plus frac');
    check(a.frac.abs < BigDecimal.one, 'dec frac below one');
  end;
end;

procedure testDecFloats;
begin
  section('BigDecimal floats');
  checkEq(BigDecimal.fromDouble(0.1).toString, '0.1', 'dec fromDouble shortest 0.1');
  checkEq(BigDecimal.fromDouble(0.5).toString, '0.5', 'dec fromDouble 0.5');
  checkEq(BigDecimal.fromDouble(-2.75).toString, '-2.75', 'dec fromDouble -2.75');
  checkEq(BigDecimal.fromDouble(1e300).toScientific, '1.0E300', 'dec fromDouble 1e300');
  checkEq(BigDecimal.fromDouble(5e-324).toScientific, '5.0E-324', 'dec fromDouble min denormal');
  checkEq(BigDecimal.fromDoubleExact(0.5).toString, '0.5', 'dec exact 0.5');
  checkEq(BigDecimal.fromDoubleExact(0.1).toString, '0.1000000000000000055511151231257827021181583404541015625', 'dec exact 0.1');
  checkEq(BigDecimal.fromDoubleExact(3).toString, '3', 'dec exact integer');
  checkEq(BigDecimal.fromSingle(Single(0.1)).toString, '0.1', 'dec fromSingle 0.1');
  checkEq(BigDecimal.fromSingleExact(Single(0.5)).toString, '0.5', 'dec fromSingleExact');
  // compare bit patterns, not values: on i386 a bare `0.1` literal is 80-bit
  // Extended and never equals the 64-bit Double result even when it is correct
  check(dblBits(BigDecimal('0.1').toDouble) = dblBits(0.1), 'dec toDouble 0.1');
  check(BigDecimal('0.1').toSingle = Single(0.1), 'dec toSingle 0.1');
  check(dblBits(BigDecimal('12345678901234567890').toDouble) = dblBits(12345678901234567890.0), 'dec toDouble big');
  check(BigDecimal('1E400').toDouble > 1e300, 'dec toDouble overflow is infinite');
  check(BigDecimal('1E-400').toDouble = 0.0, 'dec toDouble underflow is zero');
  check(dblBits(BigDecimal('1e-320').toDouble) = dblBits(1e-320), 'dec toDouble subnormal');
  check(Double(BigDecimal('0.25')) = 0.25, 'dec double cast out');
  check(BigDecimal(0.1) = BigDecimal('0.1'), 'dec double cast in is shortest');
  checkRaises(procedure begin var z := BigDecimal.fromDouble(dblFromBits(QWord($7FF8000000000000))); end, EConvertError, 'dec fromDouble NaN');
  checkRaises(procedure begin var z := BigDecimal.fromDouble(dblFromBits(QWord($7FF0000000000000))); end, EConvertError, 'dec fromDouble Inf');
  // round-trip on random bit patterns; the shortest form is also verified
  // against exact arithmetic: it must sit closer to its double than to
  // either bit neighbor (FPC's Val is off by an ulp on hard cases, so the
  // oracle is built from the exact conversions instead)
  for var i := 1 to 1500 do begin
    var q := randQ;
    if (q shr 52) and $7FF = $7FF then continue;
    var dd := dblFromBits(q);
    var bd := BigDecimal.fromDouble(dd);
    check(dblBits(BigDecimal(bd.toString).toDouble) = q, 'dec double roundtrip plain');
    check(dblBits(BigDecimal(bd.toScientific).toDouble) = q, 'dec double roundtrip sci');
    check(dblBits(BigDecimal.fromDoubleExact(dd).toDouble) = q, 'dec exact roundtrip');
    if (q and QWord($7FFFFFFFFFFFFFFF)) = 0 then continue;
    var sv := BigDecimal(bd.toString);
    var dSelf := (sv - BigDecimal.fromDoubleExact(dd)).abs;
    if (((q - 1) shr 52) and $7FF <> $7FF) and (q and QWord($7FFFFFFFFFFFFFFF) <> 0) then check(dSelf <= (sv - BigDecimal.fromDoubleExact(dblFromBits(q - 1))).abs, 'dec shortest closer than below');
    if ((q + 1) shr 52) and $7FF <> $7FF then check(dSelf <= (sv - BigDecimal.fromDoubleExact(dblFromBits(q + 1))).abs, 'dec shortest closer than above');
  end;
  for var i := 1 to 800 do begin
    var w := DWord(Random($100000000));
    if (w shr 23) and $FF = $FF then continue;
    var ss := sngFromBits(w);
    var s := BigDecimal.fromSingle(ss).toString;
    check(sngBits(BigDecimal(s).toSingle) = sngBits(ss), 'dec single roundtrip self');
    check(sngBits(BigDecimal.fromSingleExact(ss).toSingle) = sngBits(ss), 'dec single exact roundtrip');
  end;
  // toDouble on random decimal strings: the chosen double must be at least
  // as close to the exact decimal as both of its bit neighbors
  for var i := 1 to 500 do begin
    var s := '';
    if Random(2) = 1 then s := '-';
    s := s + IntToStr(Random(1000000000)) + '.' + IntToStr(Random(1000000000)) + 'E' + IntToStr(Random(600) - 300);
    var sv := BigDecimal(s);
    var dd := sv.toDouble;
    var q := dblBits(dd);
    if (q and QWord($7FFFFFFFFFFFFFFF)) = 0 then continue;
    if (q shr 52) and $7FF = $7FF then continue;
    var dSelf := (sv - BigDecimal.fromDoubleExact(dd)).abs;
    if ((q - 1) shr 52) and $7FF <> $7FF then check(dSelf <= (sv - BigDecimal.fromDoubleExact(dblFromBits(q - 1))).abs, 'dec toDouble closer than below');
    if ((q + 1) shr 52) and $7FF <> $7FF then check(dSelf <= (sv - BigDecimal.fromDoubleExact(dblFromBits(q + 1))).abs, 'dec toDouble closer than above');
  end;
  {$ifdef FPC_HAS_TYPE_EXTENDED}
  checkEq(BigDecimal.fromExtended(Extended(0.5)).toString, '0.5', 'dec fromExtended 0.5');
  // computed at run time: a cross-compiler folds the 0.1 literal at double precision
  var eTen: Extended := 10.0;
  check(BigDecimal('0.1').toExtended = Extended(1.0) / eTen, 'dec toExtended 0.1');
  for var i := 1 to 400 do begin
    var q := randQ;
    var dd := dblFromBits(q);
    if (q shr 52) and $7FF = $7FF then continue;
    var x: Extended := dd;
    check(BigDecimal.fromExtended(x).toExtended = x, 'dec extended roundtrip');
    check(BigDecimal.fromExtendedExact(x).toExtended = x, 'dec extended exact roundtrip');
  end;
  {$endif}
end;

procedure testDecMath;
begin
  section('BigDecimal math');
  checkEq(BigDecimal(2).sqrt(5).toString, '1.41421', 'dec sqrt 2');
  checkEq(BigDecimal('0.25').sqrt.toString, '0.5', 'dec sqrt exact');
  checkEq(BigDecimal('152.2756').sqrt(4).toString, '12.34', 'dec sqrt exact fraction');
  checkEq(BigDecimal(0).sqrt.toString, '0', 'dec sqrt zero');
  checkEq(BigDecimal(2).sqrt(0).toString, '1', 'dec sqrt precision 0');
  for var i := 1 to 100 do begin
    var a := randDec(50).abs;
    var r := a * a;
    check(r.sqrt(40) = a.abs, 'dec sqrt of square');
    if a.isZero then continue;
    var s := a.sqrt(12);
    check(s * s <= a, 'dec sqrt below');
    check((s + BigDecimal('1E-12')) * (s + BigDecimal('1E-12')) > a, 'dec sqrt tight');
  end;
  checkRaises(procedure begin var z := BigDecimal(-4).sqrt; end, EBigIntError, 'dec sqrt negative');
  checkEq((BigDecimal(2) ** 10).toString, '1024', 'dec pow');
  checkEq((BigDecimal('1.5') ** 3).toString, '3.375', 'dec pow fraction');
  checkEq((BigDecimal('-1.5') ** 3).toString, '-3.375', 'dec pow negative base');
  checkEq((BigDecimal('0.5') ** (-2)).toString, '4', 'dec pow negative exponent');
  checkEq((BigDecimal(3) ** (-1)).toString, '0.333333333333333333', 'dec pow negative inexact');
  checkEq(BigDecimal(7).pow(0).toString, '1', 'dec pow zero');
  checkEq(BigDecimal(0).pow(5).toString, '0', 'dec zero pow');
  checkRaises(procedure begin var z := BigDecimal(0).pow(-1); end, EDivByZero, 'dec zero pow negative');
  for var i := 1 to 50 do begin
    var a := randDec(40);
    check(a.pow(3) = a * a * a, 'dec pow vs mul');
  end;
  checkEq(BigDecimal('0.25').gcd('0.15').toString, '0.05', 'dec gcd lattice');
  checkEq(BigDecimal('0.25').lcm('0.15').toString, '0.75', 'dec lcm lattice');
  checkEq(BigDecimal(12).gcd(BigDecimal(18)).toString, '6', 'dec gcd integers');
  checkEq(BigDecimal(4).lcm(BigDecimal(6)).toString, '12', 'dec lcm integers');
  checkEq(BigDecimal(0).gcd(BigDecimal('-2.5')).toString, '2.5', 'dec gcd with zero');
  for var i := 1 to 100 do begin
    var a := randDec(40);
    var b := randDec(40);
    if a.isZero or b.isZero then continue;
    var g := a.gcd(b);
    check(g.isPositive, 'dec gcd positive');
    var (q1, r1) := a.divMod(g);
    var (q2, r2) := b.divMod(g);
    check(r1.isZero and r2.isZero, 'dec gcd divides both');
    var l := a.lcm(b);
    var (q3, r3) := l.divMod(a);
    var (q4, r4) := l.divMod(b);
    check(r3.isZero and r4.isZero, 'dec lcm multiple of both');
    check(g * l = (a * b).abs, 'dec gcd lcm product');
  end;
end;

procedure testDecIntrospection;
begin
  section('BigDecimal introspection');
  var d: BigDecimal := '123.45';
  check(d.precision = 5, 'dec precision');
  check(d.mostSignificantExponent = 2, 'dec msExp');
  check((d.getDigit(2) = 1) and (d.getDigit(1) = 2) and (d.getDigit(0) = 3), 'dec getDigit integer part');
  check((d.getDigit(-1) = 4) and (d.getDigit(-2) = 5), 'dec getDigit fraction');
  check((d.getDigit(3) = 0) and (d.getDigit(-3) = 0), 'dec getDigit outside');
  check(BigDecimal('-123.45').getDigit(-2) = 5, 'dec getDigit ignores sign');
  check(BigDecimal('0.00123').precision = 3, 'dec precision fraction');
  check(BigDecimal('0.00123').mostSignificantExponent = -3, 'dec msExp fraction');
  check(BigDecimal('4E9').precision = 1, 'dec precision canonical');
  check(BigDecimal('4E9').mostSignificantExponent = 9, 'dec msExp big');
  check(BigDecimal(0).precision = 0, 'dec precision zero');
  checkEq(BigDecimal('12.5').shifted10(2).toString, '1250', 'dec shifted10 up');
  checkEq(BigDecimal('12.5').shifted10(-3).toString, '0.0125', 'dec shifted10 down');
  checkEq(BigDecimal(0).shifted10(5).toString, '0', 'dec shifted10 zero');
  var m: BigDecimal := '7.25';
  m.shift10(2);
  checkEq(m.toString, '725', 'dec shift10 in place');
  // digits reported by getDigit match the printed form
  for var i := 1 to 100 do begin
    var a := randDec(64).abs;
    var s := a.toString;
    var dot := Pos('.', s);
    var e := if dot = 0 then 0 else -(Length(s) - dot);
    if dot > 0 then Delete(s, dot, 1);
    for var j := 1 to Length(s) do check(a.getDigit(e + Length(s) - j) = Ord(s[j]) - Ord('0'), 'dec getDigit vs toString');
  end;
  // exact conversions
  check(BigDecimal('42').toInt64 = 42, 'dec toInt64');
  check(BigDecimal('-42').toInt32 = -42, 'dec toInteger');
  check(BigDecimal('42').toUInt64 = 42, 'dec toQWord');
  check(BigDecimal('42').toUInt32 = 42, 'dec toCardinal');
  check(BigDecimal('4.2E1').toInt64 = 42, 'dec toInt64 from exponent form');
  checkEq(BigDecimal('12345678901234567890123').toBigInt.toString, '12345678901234567890123', 'dec toBigInt');
  checkEq(BigDecimal('340282366920938463463374607431768211456').toUBigInt.toString, '340282366920938463463374607431768211456', 'dec toUBigInt');
  check(BigDecimal('42').toUBigInt = UBigInt(42), 'dec toUBigInt small');
  checkRaises(procedure begin var z := BigDecimal('1.5').toUBigInt; end, ERangeError, 'dec toUBigInt fraction raises');
  checkRaises(procedure begin var z := BigDecimal('-4').toUBigInt; end, ERangeError, 'dec toUBigInt negative raises');
  // integer types widen to BigDecimal via toDecimal
  check(UBigInt('123456789012345678901234567890').toDecimal = BigDecimal('123456789012345678901234567890'), 'dec UBigInt.toDecimal');
  check(BigInt('-999999999999999999999').toDecimal = BigDecimal('-999999999999999999999'), 'dec BigInt.toDecimal');
  check(UBigInt(720).toDecimal.divide(BigDecimal(2), 4).toString = '360', 'dec toDecimal in expression');
  check(BigInt(-7).toDecimal.toBigInt = BigInt(-7), 'dec toDecimal roundtrip');
  checkEq(BigInt(BigDecimal('-99')).toString, '-99', 'dec BigInt cast');
  check(BigDecimal('42').fitsInInt64 and BigDecimal('42').fitsInInt32, 'dec fits integral');
  check(not BigDecimal('42.5').fitsInInt64, 'dec fits rejects fraction');
  check(not BigDecimal('-1').fitsInUInt64, 'dec fits rejects negative qword');
  check(not BigDecimal('1E30').fitsInInt64, 'dec fits rejects big');
  // the small-type predicates delegate through trunc
  check(BigDecimal('255').fitsInUInt8 and not BigDecimal('256').fitsInUInt8, 'dec byte edge');
  check(not BigDecimal('255.5').fitsInUInt8, 'dec byte rejects fraction');
  check(BigDecimal('-128').fitsInInt8 and not BigDecimal('-129').fitsInInt8, 'dec shortint low edge');
  check(BigDecimal('65535').fitsInUInt16 and BigDecimal('32767').fitsInInt16, 'dec word smallint');
  check(BigDecimal('4294967295').fitsInUInt32 and not BigDecimal('-1').fitsInUInt32, 'dec dword edge');
  check(BigDecimal('-100').toInt8 = -100, 'dec toInt8');
  check(BigDecimal('60000').toUInt16 = 60000, 'dec toUInt16');
  checkRaises(procedure begin var z := BigDecimal('1.5').toInt64; end, ERangeError, 'dec toInt64 fraction raises');
  checkRaises(procedure begin var z := BigDecimal('1.5').toBigInt; end, ERangeError, 'dec toBigInt fraction raises');
  checkRaises(procedure begin var z := BigDecimal('1E2147483647') * BigDecimal('1E2147483647'); end, ERangeError, 'dec exponent overflow raises');
end;

const
  // reference digits generated independently (integer Machin arctans for pi,
  // the IBM decimal library for the rest)
  PI1000 =
    '3.14159265358979323846264338327950288419716939937510582097494459230781640628' +
    '6208998628034825342117067982148086513282306647093844609550582231725359408128' +
    '4811174502841027019385211055596446229489549303819644288109756659334461284756' +
    '4823378678316527120190914564856692346034861045432664821339360726024914127372' +
    '4587006606315588174881520920962829254091715364367892590360011330530548820466' +
    '5213841469519415116094330572703657595919530921861173819326117931051185480744' +
    '6237996274956735188575272489122793818301194912983367336244065664308602139494' +
    '6395224737190702179860943702770539217176293176752384674818467669405132000568' +
    '1271452635608277857713427577896091736371787214684409012249534301465495853710' +
    '5079227968925892354201995611212902196086403441815981362977477130996051870721' +
    '1349999998372978049951059731732816096318595024459455346908302642522308253344' +
    '6850352619311881710100031378387528865875332083814206171776691473035982534904' +
    '2875546873115956286388235378759375195778185778053217122680661300192787661119' +
    '590921642019893809525720';
  E1000 =
    '2.71828182845904523536028747135266249775724709369995957496696762772407663035' +
    '3547594571382178525166427427466391932003059921817413596629043572900334295260' +
    '5956307381323286279434907632338298807531952510190115738341879307021540891499' +
    '3488416750924476146066808226480016847741185374234544243710753907774499206955' +
    '1702761838606261331384583000752044933826560297606737113200709328709127443747' +
    '0472306969772093101416928368190255151086574637721112523897844250569536967707' +
    '8544996996794686445490598793163688923009879312773617821542499922957635148220' +
    '8269895193668033182528869398496465105820939239829488793320362509443117301238' +
    '1970684161403970198376793206832823764648042953118023287825098194558153017567' +
    '1736133206981125099618188159304169035159888851934580727386673858942287922849' +
    '9892086805825749279610484198444363463244968487560233624827041978623209002160' +
    '9902353043699418491463140934317381436405462531520961836908887070167683964243' +
    '7814059271456354906130310720851038375051011574770417189861068739696552126715' +
    '468895703503540212340784';
  LN2_100 = '0.6931471805599453094172321214581765680755001343602552541206800094933936219696947156058633269964186875';
  LN10_100 = '2.3025850929940456840179914546843642076011014886287729760333279009675726096773524802359972050895982983';
  LN3_100 = '1.0986122886681096913952452369225257046474905578227494517346943336374942932186089668736157548137320887';
  EXP05_100 = '1.6487212707001281468486507878141635716537761007101480115750793116406610211942156086327765200563666430';
  LOG107_100 = '0.8450980400142568307122162585926361934835723963239654065036349537182534399020791660661115278474885733';
  P2HALF_100 = '1.4142135623730950488016887242096980785696718753769480731766797379907324784621070388503875343276415727';
  CBRT2_100 = '1.2599210498948731647672106072782283505702514647015079800819751121552996765139594837293965624362550941';

// toString rounds the hidden guard digit half-up, so the oracle is the
// reference value rounded half-up at the same decimal position
procedure checkDigits(const v: BigDecimal; p: integer; const ref, name: string);
begin
  checkEq(v.toString, BigDecimal(ref).rounded(-p, bdrHalfUp).toString, name);
end;

procedure testDecTranscendental;
begin
  section('BigDecimal transcendentals');
  // known digits at several precisions
  checkDigits(BigDecimal.pi(50), 50, PI1000, 'dec pi 50');
  checkDigits(BigDecimal.pi(100), 100, PI1000, 'dec pi 100');
  checkDigits(BigDecimal.pi(999), 999, PI1000, 'dec pi 999');
  checkDigits(BigDecimal.pi(0), 0, PI1000, 'dec pi 0');
  checkDigits(BigDecimal.e(100), 100, E1000, 'dec e 100');
  checkDigits(BigDecimal.e(999), 999, E1000, 'dec e 999');
  checkDigits(BigDecimal.two.ln(95), 95, LN2_100, 'dec ln 2');
  checkDigits(BigDecimal.ten.ln(95), 95, LN10_100, 'dec ln 10');
  checkDigits(BigDecimal(3).ln(95), 95, LN3_100, 'dec ln 3');
  checkDigits(BigDecimal('0.5').exp(95), 95, EXP05_100, 'dec exp 0.5');
  checkDigits(BigDecimal(1).exp(95), 95, E1000, 'dec exp(1) = e');
  checkDigits(BigDecimal(7).log10(95), 95, LOG107_100, 'dec log10 7');
  checkDigits(BigDecimal(2).pow(BigDecimal('0.5'), 95), 95, P2HALF_100, 'dec 2^0.5');
  checkDigits(BigDecimal(2).nthRoot(3, 95), 95, CBRT2_100, 'dec cbrt 2');
  checkDigits(BigDecimal(2).sqrt(95), 95, P2HALF_100, 'dec sqrt agrees with pow');
  // the byte-narrowing regression: results with over 255 mantissa digits
  check(BigDecimal.pi(300).precision = 302, 'dec pi 300 precision');
  check(BigDecimal(700).exp(5).precision = 311, 'dec exp 700 precision');
  // exact shortcuts
  checkEq(BigDecimal('1000').log10.toString, '3', 'dec log10 power of ten');
  checkEq(BigDecimal('0.001').log10.toString, '-3', 'dec log10 negative power');
  checkEq(BigDecimal('1024').log2.toString, '10', 'dec log2 power of two');
  checkEq(BigDecimal('0.5').log2.toString, '-1', 'dec log2 half');
  checkEq(BigDecimal('0.0625').log2.toString, '-4', 'dec log2 sixteenth');
  checkEq(BigDecimal(1).ln.toString, '0', 'dec ln 1');
  checkEq(BigDecimal(0).exp.toString, '1', 'dec exp 0');
  checkEq(BigDecimal('0.25').nthRoot(2).toString, '0.5', 'dec nthRoot exact');
  checkEq(BigDecimal(27).nthRoot(3).toString, '3', 'dec cbrt exact');
  checkEq(BigDecimal(-27).nthRoot(3).toString, '-3', 'dec cbrt negative');
  checkEq(BigDecimal('2.5').nthRoot(1).toString, '2.5', 'dec first root');
  checkEq(BigDecimal(2).pow(BigDecimal(10)).toString, '1024', 'dec pow integral exact');
  checkEq(BigDecimal(1).pow(BigDecimal('0.37')).toString, '1', 'dec one to any power');
  // identities on random values
  for var i := 1 to 25 do begin
    var x := (randDec(40).abs + BigDecimal('0.001')).rounded(-12, bdrTrunc) + BigDecimal('0.001');
    // absolute errors of exp and pow scale with the value, so compare relative
    check((x.ln(45).exp(35) - x).abs < x * BigDecimal('1E-28'), 'dec exp(ln x) = x');
    var y := randDec(20).abs.rounded(-6, bdrTrunc) + BigDecimal('0.5');
    check((x.ln(45) + y.ln(45) - (x * y).ln(45)).abs < BigDecimal('1E-42'), 'dec ln(xy) = ln x + ln y');
    check(((x.nthRoot(5, 40) ** 5) - x).abs < x * BigDecimal('1E-28'), 'dec nthRoot pow roundtrip');
    check((x.log2(40) - x.logBase(BigDecimal.two, 40)).abs < BigDecimal('1E-38'), 'dec log2 vs logBase');
  end;
  for var i := 1 to 15 do begin
    var a := BigDecimal(Random(2000) - 1000).divide(BigDecimal(Random(100) + 7), 8);
    check((a.exp(40) * (-a).exp(40) - 1).abs < BigDecimal('1E-36'), 'dec exp(x)exp(-x) = 1');
  end;
  // errors
  checkRaises(procedure begin var z := BigDecimal(-1).ln; end, EBigIntError, 'dec ln negative');
  checkRaises(procedure begin var z := BigDecimal(0).ln; end, EBigIntError, 'dec ln zero');
  checkRaises(procedure begin var z := BigDecimal(5).logBase(BigDecimal(1)); end, EBigIntError, 'dec logBase one');
  checkRaises(procedure begin var z := BigDecimal(-2).pow(BigDecimal('0.5')); end, EBigIntError, 'dec fractional power of negative');
  checkRaises(procedure begin var z := BigDecimal(0).pow(BigDecimal('-0.5')); end, EDivByZero, 'dec zero to negative power');
  checkRaises(procedure begin var z := BigDecimal(-4).nthRoot(2); end, EBigIntError, 'dec even root of negative');
  checkRaises(procedure begin var z := BigDecimal(4).nthRoot(0); end, EBigIntError, 'dec zeroth root');
  checkRaises(procedure begin var z := BigDecimal('1E10').exp; end, ERangeError, 'dec exp out of range');
end;

procedure testDecTrig;
const
  SIN1 = '0.8414709848078965066525023216302989996225630607983710656727517099919104043912396689486397435430526958';
  COS1 = '0.5403023058681397174009366074429766037323104206179222276700972553811003947744717645179518560871830893';
  TAN1 = '1.5574077246549022305069748074583601730872507723815200383839466056988613971517272895550999652022429838';
  SIN100 = '-0.5063656411097587936565576104597854320650327212906573234433924735943579134194766964992366645129273922';
  COS100 = '0.8623188722876839341019385139508425355100840085355108292801621126927210880509266241030951056842772850';
  SINB = '-0.7034419212638210627013603336854093543526735571476958549629868974154429626514109671515089917819792352';
  ATAN05 = '0.4636476090008061162142562314612144020285370542861202638109330887201978641657417053006002839848878925';
  ASIN05 = '0.5235987755982988730771072305465838140328615665625176368291574320513027343810348331046724708903528446';
  ACOSM05 = '2.0943951023931954923084289221863352561314462662500705473166297282052109375241393324186898835614113786';
  SINH1 = '1.1752011936438014568823818505956008151557179813340958702295654130133075673043238956071174520896233918';
  COSH1 = '1.5430806348152437784779056207570616826015291123658637047374022147107690630492236989642647264355430355';
  TANH1 = '0.7615941559557648881194582826047935904127685972579365515968105001219532445766384834589475216736767144';
  TANH3 = '0.9950547536867304513318801852554884750978138547002824918238788151306647027825591767193959600223117579';
begin
  section('BigDecimal trigonometry');
  checkDigits(BigDecimal(1).sin(95), 95, SIN1, 'dec sin 1');
  checkDigits(BigDecimal(1).cos(95), 95, COS1, 'dec cos 1');
  checkDigits(BigDecimal(1).tan(95), 95, TAN1, 'dec tan 1');
  checkDigits(BigDecimal(100).sin(95), 95, SIN100, 'dec sin 100');
  checkDigits(BigDecimal(100).cos(95), 95, COS100, 'dec cos 100');
  checkDigits(BigDecimal('12345.6789').sin(95), 95, SINB, 'dec sin 12345.6789');
  checkDigits(BigDecimal('0.5').arctan(95), 95, ATAN05, 'dec arctan 0.5');
  checkDigits(BigDecimal('0.5').arcsin(95), 95, ASIN05, 'dec arcsin 0.5');
  checkDigits(BigDecimal('-0.5').arccos(95), 95, ACOSM05, 'dec arccos -0.5');
  checkDigits(BigDecimal(1).sinh(95), 95, SINH1, 'dec sinh 1');
  checkDigits(BigDecimal(1).cosh(95), 95, COSH1, 'dec cosh 1');
  checkDigits(BigDecimal(1).tanh(95), 95, TANH1, 'dec tanh 1');
  checkDigits(BigDecimal(3).tanh(95), 95, TANH3, 'dec tanh 3');
  // special values
  checkEq(BigDecimal(0).sin.toString, '0', 'dec sin 0');
  checkEq(BigDecimal(0).cos.toString, '1', 'dec cos 0');
  checkEq(BigDecimal(0).tan.toString, '0', 'dec tan 0');
  checkEq(BigDecimal(0).arctan.toString, '0', 'dec arctan 0');
  checkEq(BigDecimal(0).sinh.toString, '0', 'dec sinh 0');
  checkEq(BigDecimal(0).cosh.toString, '1', 'dec cosh 0');
  checkEq(BigDecimal(0).tanh.toString, '0', 'dec tanh 0');
  checkDigits(BigDecimal(1).arcsin(60), 60, BigDecimal.pi(70).divide(2, 65).toString, 'dec arcsin 1 = pi/2');
  checkDigits(BigDecimal(-1).arccos(60), 60, BigDecimal.pi(70).toString, 'dec arccos -1 = pi');
  check((BigDecimal(1).arctan(65) * 4 - BigDecimal.pi(70)).abs < BigDecimal('1E-60'), 'dec 4 arctan 1 = pi');
  check(BigDecimal.pi(80).sin(60).abs < BigDecimal('1E-58'), 'dec sin pi near zero');
  check((BigDecimal.pi(80).cos(60) + 1).abs < BigDecimal('1E-58'), 'dec cos pi near -1');
  check(BigDecimal(200).tanh(30) = BigDecimal(1), 'dec tanh saturates');
  // tiny arguments keep their significant digits
  check((BigDecimal('1E-50').sin(60) - BigDecimal('1E-50')).abs < BigDecimal('1E-58'), 'dec sin tiny');
  check((BigDecimal('1E-50').arctan(60) - BigDecimal('1E-50')).abs < BigDecimal('1E-58'), 'dec arctan tiny');
  check(BigDecimal('1E-50').cos(40) = BigDecimal(1), 'dec cos tiny');
  // identities on random arguments
  for var i := 1 to 20 do begin
    var x := BigDecimal(Random(2000000) - 1000000).divide(BigDecimal(Random(300) + 11), 10);
    var s := x.sin(45);
    var c := x.cos(45);
    check((s * s + c * c - 1).abs < BigDecimal('1E-42'), 'dec sin2 + cos2 = 1');
    if c.abs > BigDecimal('0.01') then check((x.tan(45) - s.divide(c, 45)).abs * c.abs < BigDecimal('1E-40'), 'dec tan = sin/cos');
    var hs := x.sinh(45);
    if hs.isZero then continue;
    var hc := x.cosh(45);
    check(((hc * hc - hs * hs - 1).abs.divide(hc * hc, 45)) < BigDecimal('1E-40'), 'dec cosh2 - sinh2 = 1');
  end;
  for var i := 1 to 15 do begin
    var u := BigDecimal(Random(1999) - 999).divide(BigDecimal(1000), 6);
    check((u.sin(50).arcsin(42) - u).abs < BigDecimal('1E-40'), 'dec arcsin sin roundtrip');
    check((u.tan(50).arctan(42) - u).abs < BigDecimal('1E-40'), 'dec arctan tan roundtrip');
    check((u.sinh(50) + (-u).sinh(50)).isZero, 'dec sinh odd');
    check((u.cosh(50) - (-u).cosh(50)).isZero, 'dec cosh even');
  end;
  // errors
  checkRaises(procedure begin var z := BigDecimal(2).arcsin; end, EBigIntError, 'dec arcsin out of domain');
  checkRaises(procedure begin var z := BigDecimal('-1.0001').arccos; end, EBigIntError, 'dec arccos out of domain');
end;

procedure testDecPractical;
begin
  section('BigDecimal practical extras');
  // toFraction
  var (n1, d1) := BigDecimal('0.375').toFraction;
  check((n1 = 3) and (d1 = 8), 'dec toFraction 0.375');
  var (n2, d2) := BigDecimal('-0.5').toFraction;
  check((n2 = -1) and (d2 = 2), 'dec toFraction -0.5');
  var (n3, d3) := BigDecimal('42').toFraction;
  check((n3 = 42) and (d3 = 1), 'dec toFraction integral');
  var (n4, d4) := BigDecimal('0').toFraction;
  check((n4 = 0) and (d4 = 1), 'dec toFraction zero');
  var (n5, d5) := BigDecimal('0.1').toFraction;
  check((n5 = 1) and (d5 = 10), 'dec toFraction 0.1');
  var (n6, d6) := BigDecimal('1.25E3').toFraction;
  check((n6 = 1250) and (d6 = 1), 'dec toFraction exponent form');
  for var i := 1 to 100 do begin
    var x := randDec(64);
    var (nn, dd) := x.toFraction;
    check(BigDecimal(nn).divide(BigDecimal(dd), 40) = x, 'dec toFraction roundtrip');
    check(nn.gcd(dd).isOne or nn.isZero, 'dec toFraction reduced');
  end;
  // quantize
  checkEq(BigDecimal('7.13').quantize(BigDecimal('0.05')).toString, '7.15', 'dec quantize nickels');
  checkEq(BigDecimal('7.12').quantize(BigDecimal('0.05')).toString, '7.1', 'dec quantize down');
  checkEq(BigDecimal('7.125').quantize(BigDecimal('0.05'), bdrTrunc).toString, '7.1', 'dec quantize trunc');
  checkEq(BigDecimal('7.11').quantize(BigDecimal('0.05'), bdrCeil).toString, '7.15', 'dec quantize ceil');
  checkEq(BigDecimal('-7.11').quantize(BigDecimal('0.05'), bdrCeil).toString, '-7.1', 'dec quantize ceil negative');
  checkEq(BigDecimal('-7.11').quantize(BigDecimal('0.05'), bdrFloor).toString, '-7.15', 'dec quantize floor negative');
  checkEq(BigDecimal('0.125').quantize(BigDecimal('0.25'), bdrHalfEven).toString, '0', 'dec quantize half even down');
  checkEq(BigDecimal('0.375').quantize(BigDecimal('0.25'), bdrHalfEven).toString, '0.5', 'dec quantize half even up');
  checkEq(BigDecimal('12.5').quantize(BigDecimal(5)).toString, '15', 'dec quantize integer step');
  checkEq(BigDecimal('1.7').quantize(BigDecimal('0.1')).toString, '1.7', 'dec quantize exact multiple');
  checkRaises(procedure begin var z := BigDecimal(1).quantize(BigDecimal(0)); end, EDivByZero, 'dec quantize zero step');
  for var i := 1 to 100 do begin
    var x := randDec(48);
    var st := randDec(16).abs;
    if st.isZero then continue;
    var qz := x.quantize(st);
    var (qq, rr) := qz.divMod(st);
    check(rr.isZero, 'dec quantize lands on a multiple');
    check((qz - x).abs * 2 <= st, 'dec quantize within half a step');
  end;
  // toEngineering
  checkEq(BigDecimal('123456.789').toEngineering, '123.456789E3', 'dec eng 123456.789');
  checkEq(BigDecimal('0.00123').toEngineering, '1.23E-3', 'dec eng 0.00123');
  checkEq(BigDecimal('0.000123').toEngineering, '123E-6', 'dec eng 0.000123');
  checkEq(BigDecimal('5').toEngineering, '5E0', 'dec eng 5');
  checkEq(BigDecimal('50').toEngineering, '50E0', 'dec eng 50');
  checkEq(BigDecimal('5000').toEngineering, '5E3', 'dec eng 5000');
  checkEq(BigDecimal('-2.5E7').toEngineering, '-25E6', 'dec eng negative');
  checkEq(BigDecimal('0').toEngineering, '0', 'dec eng zero');
  // approxEquals
  check(BigDecimal('1.0000001').approxEquals(BigDecimal(1), BigDecimal('1E-6')), 'dec approx within');
  check(not BigDecimal('1.0001').approxEquals(BigDecimal(1), BigDecimal('1E-6')), 'dec approx outside');
  check(BigDecimal(5).approxEquals(BigDecimal(5), BigDecimal(0)), 'dec approx exact zero eps');
  check(BigDecimal('0.3').approxEquals(BigDecimal('0.1') + BigDecimal('0.2'), BigDecimal(0)), 'dec approx exact decimals');
end;

procedure testDecSpecial;

  procedure near(const v, ref: BigDecimal; tol: integer; const name: string);
  begin
    check((v - ref).abs < BigDecimal.one.shifted10(-tol), name);
  end;

const
  SQRTPI = '1.7724538509055160272981674833411451827975494561224';
  SQRTPI_HALF = '0.88622692545275801364908374167057259139877472806119';
  ERF_1 = '0.84270079294971486934122063508260925929606699796630';
  ERFC_1 = '0.15729920705028513065877936491739074070393300203370';
  ERFC_3 = '0.0000220904969985854413727761295823203798477559552253';
  AGM_1_2 = '1.4567910310469068691864323832650819749738639432213';
begin
  section('BigDecimal special functions');
  // gamma against closed forms
  near(BigDecimal('0.5').gamma(45), BigDecimal(SQRTPI), 43, 'gamma(1/2) = sqrt(pi)');
  near(BigDecimal('1.5').gamma(45), BigDecimal(SQRTPI_HALF), 43, 'gamma(3/2)');
  near(BigDecimal('-0.5').gamma(40), BigDecimal(SQRTPI) * (-2), 37, 'gamma(-1/2)');
  check(BigDecimal(5).gamma(20) = BigDecimal(24), 'gamma(5) = 4!');
  check(BigDecimal(10).gamma(20) = BigDecimal(362880), 'gamma(10) = 9!');
  // gamma(x+1) = x gamma(x) on random arguments
  for var i := 1 to 20 do begin
    var x := BigDecimal(Random(1900) + 100).divide(BigDecimal(100), 12); // 1..20
    near(x.gamma(35) * x, (x + 1).gamma(35), 30, 'gamma recurrence');
  end;
  // lnGamma = ln(gamma) where gamma is positive
  near(BigDecimal(10).lnGamma(40), BigDecimal(362880).ln(45), 36, 'lnGamma(10)');
  near(BigDecimal('3.5').lnGamma(40), BigDecimal('3.5').gamma(45).ln(45), 35, 'lnGamma = ln gamma');
  near(BigDecimal(100).lnGamma(40), BigDecimal(UBigInt.factorial(99)).ln(45), 35, 'lnGamma(100)');
  // factorial on fractions and integers
  near(BigDecimal('0.5').factorial(40), BigDecimal(SQRTPI_HALF), 38, '0.5! = gamma(1.5)');
  check(BigDecimal(6).factorial(20) = BigDecimal(720), '6! = 720');
  check(BigDecimal(20).factorial(20) = BigDecimal(UBigInt.factorial(20)), '20! exact');
  // erf and erfc
  checkEq(BigDecimal(0).erf.toString, '0', 'erf(0) = 0');
  near(BigDecimal(1).erf(45), BigDecimal(ERF_1), 43, 'erf(1)');
  near(BigDecimal('-1').erf(45), -BigDecimal(ERF_1), 43, 'erf odd');
  near(BigDecimal(1).erfc(45), BigDecimal(ERFC_1), 43, 'erfc(1)');
  near(BigDecimal(3).erfc(45), BigDecimal(ERFC_3), 43, 'erfc(3)');
  // the 1 - erf path has to hand back every digit asked for, not a trimmed tail
  checkEq(BigDecimal(1).erfc(40).toString, BigDecimal(ERFC_1).rounded(-40).toString, 'erfc(1) full width');
  check(BigDecimal(30).erf(30) = BigDecimal.one, 'erf saturates');
  for var i := 1 to 15 do begin
    var x := BigDecimal(Random(500) - 250).divide(BigDecimal(100), 10);   // -2.5..2.5
    near(x.erf(40) + x.erfc(40), BigDecimal.one, 38, 'erf + erfc = 1');
  end;
  // agm
  near(BigDecimal.agm(BigDecimal(1), BigDecimal(2), 45), BigDecimal(AGM_1_2), 43, 'agm(1,2)');
  check(BigDecimal.agm(BigDecimal(7), BigDecimal(7), 20) = BigDecimal(7), 'agm(a,a) = a');
  // atan2 across all quadrants
  var pi := BigDecimal.pi(45);
  near(BigDecimal.atan2(BigDecimal(1), BigDecimal(1), 40), pi.divide(4, 42), 37, 'atan2 Q1');
  near(BigDecimal.atan2(BigDecimal(1), BigDecimal(-1), 40), pi * 3 / 4, 37, 'atan2 Q2');
  near(BigDecimal.atan2(BigDecimal(-1), BigDecimal(-1), 40), -pi * 3 / 4, 37, 'atan2 Q3');
  near(BigDecimal.atan2(BigDecimal(-1), BigDecimal(1), 40), -pi.divide(4, 42), 37, 'atan2 Q4');
  near(BigDecimal.atan2(BigDecimal(1), BigDecimal(0), 40), pi.divide(2, 42), 37, 'atan2 +y axis');
  near(BigDecimal.atan2(BigDecimal(-1), BigDecimal(0), 40), -pi.divide(2, 42), 37, 'atan2 -y axis');
  near(BigDecimal.atan2(BigDecimal(0), BigDecimal(-1), 40), pi, 37, 'atan2 -x axis');
  check(BigDecimal.atan2(BigDecimal(0), BigDecimal(0), 20).isZero, 'atan2(0,0) = 0');
  // atan2(sin, cos) recovers the angle
  for var i := 1 to 15 do begin
    var t := BigDecimal(Random(600) - 300).divide(BigDecimal(100), 10);   // -3..3
    near(BigDecimal.atan2(t.sin(40), t.cos(40), 35), t, 30, 'atan2 of sin,cos');
  end;
  // hypot
  check(BigDecimal.hypot(BigDecimal(3), BigDecimal(4), 20) = BigDecimal(5), 'hypot 3,4,5');
  check(BigDecimal.hypot(BigDecimal(8), BigDecimal(15), 20) = BigDecimal(17), 'hypot 8,15,17');
  near(BigDecimal.hypot(BigDecimal(1), BigDecimal(1), 40), BigDecimal(2).sqrt(42), 37, 'hypot(1,1) = sqrt2');
  // roundToSignificant
  checkEq(BigDecimal('123.456').roundToSignificant(2).toString, '120', 'sig 2');
  checkEq(BigDecimal('123.456').roundToSignificant(4).toString, '123.5', 'sig 4');
  checkEq(BigDecimal('0.00123456').roundToSignificant(3).toString, '0.00123', 'sig small');
  checkEq(BigDecimal('0.0996').roundToSignificant(2).toString, '0.1', 'sig carry');
  checkEq(BigDecimal('-98765').roundToSignificant(2, bdrTrunc).toString, '-98000', 'sig trunc negative');
  checkRaises(procedure begin var z := BigDecimal(5).roundToSignificant(0); end, EBigIntError, 'sig zero digits');
  // error paths
  checkRaises(procedure begin var z := BigDecimal(0).gamma; end, EBigIntError, 'gamma pole at 0');
  checkRaises(procedure begin var z := BigDecimal(-3).gamma; end, EBigIntError, 'gamma pole at -3');
  checkRaises(procedure begin var z := BigDecimal(-1).lnGamma; end, EBigIntError, 'lnGamma negative');
  checkRaises(procedure begin var z := BigDecimal.agm(BigDecimal(-1), BigDecimal(2)); end, EBigIntError, 'agm negative');
end;

procedure testExtrasMultiplicative;
begin
  section('extras: multiplicative functions');
  check(UBigInt(1).eulerPhi = 1, 'phi(1)');
  check(UBigInt(360).eulerPhi = 96, 'phi(360)');
  check(UBigInt(97).eulerPhi = 96, 'phi(prime)');
  // phi via the product formula matches a direct coprime count for small n
  for var n := 1 to 200 do begin
    var cnt := 0;
    for var k := 1 to n do if UBigInt(k).gcd(UBigInt(n)).isOne then inc(cnt);
    check(UBigInt(n).eulerPhi = cnt, 'phi count ' + IntToStr(n));
  end;
  check(UBigInt(12).sigma(1) = 28, 'sigma1(12)');
  check(UBigInt(6).sigma(1) = 12, 'sigma1(6)');
  check(UBigInt(10).sigma(2) = 130, 'sigma2(10)'); // 1+4+25+100
  check(UBigInt(12).tau = 6, 'tau(12)');
  check(UBigInt(360).sigma(0) = UBigInt(360).tau, 'sigma0 = tau');
  // sum of divisors matches sigma, count matches tau
  for var n := 1 to 100 do begin
    var d := UBigInt(n).divisors;
    var s := UBigInt.zero;
    for var x in d do s := s + x;
    check(UBigInt(Int64(Length(d))) = UBigInt(n).tau, 'divisor count ' + IntToStr(n));
    check(s = UBigInt(n).sigma(1), 'divisor sum ' + IntToStr(n));
    for var i := 0 to High(d) do check((UBigInt(n) mod d[i]).isZero, 'divides ' + IntToStr(n));
  end;
  check(UBigInt(30).moebius = -1, 'mu(30)');
  check(UBigInt(12).moebius = 0, 'mu(12)');
  check(UBigInt(1).moebius = 1, 'mu(1)');
  check(UBigInt(12).radical = 6, 'rad(12)');
  check(UBigInt(360).radical = 30, 'rad(360)');
  check(UBigInt(15).carmichaelLambda = 4, 'lambda(15)');
  check(UBigInt(561).carmichaelLambda = 80, 'lambda(561)');
  // a^lambda(n) = 1 (mod n) for a coprime to n
  for var n := 2 to 60 do begin
    var lam := UBigInt(n).carmichaelLambda;
    for var a := 1 to n - 1 do
      if UBigInt(a).gcd(UBigInt(n)).isOne then check(UBigInt(a).modPow(lam, UBigInt(n)).isOne, 'carmichael order ' + IntToStr(n));
  end;
  check(UBigInt(6).isPerfect and UBigInt(28).isPerfect and UBigInt(496).isPerfect and UBigInt(8128).isPerfect, 'perfect numbers');
  check(not UBigInt(12).isPerfect, 'not perfect');
  check(UBigInt(30).isSquarefree and not UBigInt(18).isSquarefree, 'squarefree');
  check(UBigInt(561).isCarmichael and UBigInt(1105).isCarmichael and UBigInt(1729).isCarmichael, 'carmichael numbers');
  check(not UBigInt(1728).isCarmichael, 'not carmichael');
  check(UBigInt(729).isKthPower(6) and UBigInt(1000000).isKthPower(6), 'is 6th power');
  check(not UBigInt(1000).isKthPower(6), 'not 6th power');
  var (rt, rm) := UBigInt(1030).nthRootRem(3);
  check((rt = 10) and (rm = 30), 'nthRootRem');
  check(BigInt(-8).isKthPower(3) and not BigInt(-8).isKthPower(2), 'signed kth power');
  check(BigInt(-360).eulerPhi = 96, 'signed phi on magnitude');
end;

procedure testExtrasCrypto;
begin
  section('extras: cryptographic helpers');
  // BPSW agrees with the deterministic small-range test, then beyond it
  for var n := 0 to 2000 do check(UBigInt(n).isPrime = UBigInt(n).isProbablePrime, 'isPrime small ' + IntToStr(n));
  var p1: UBigInt := '1000000000000000000000000000057';
  check(p1.isPrime, 'isPrime big prime');
  check(not (p1 + 3).isPrime, 'isPrime big composite');
  // large Carmichael and strong pseudoprimes must not fool BPSW
  check(not UBigInt('651693055693681').isPrime, 'BPSW big carmichael');
  check(not UBigInt('3215031751').isPrime, 'BPSW strong pseudoprime base 2,3,5,7');
  // prime counting
  check(UBigInt.primePi(10) = 4, 'pi(10)');
  check(UBigInt.primePi(100) = 25, 'pi(100)');
  check(UBigInt.primePi(1000000) = 78498, 'pi(1e6)');
  check(UBigInt.primeCount(1000000, 1100000) = 7216, 'primeCount interval');
  // kronecker extends jacobi and matches it on odd positive moduli
  for var a := -30 to 30 do
    for var m := 1 to 29 do
      if UBigInt(m).isOdd then check(BigInt(a).kronecker(BigInt(m)) = BigInt(a).floorMod(BigInt(m)).jacobi(BigInt(m)), 'kronecker vs jacobi');
  check(BigInt(5).kronecker(BigInt(2)) = -1, 'kronecker(5,2)');
  check(BigInt(7).kronecker(BigInt(2)) = 1, 'kronecker(7,2)');
  check(BigInt(-1).kronecker(BigInt(7)) = -1, 'kronecker(-1,7)');
  check(BigInt(6).kronecker(BigInt(10)) = 0, 'kronecker shares factor');
  // constant-time modPow agrees with the fast one on random inputs
  for var i := 1 to 200 do begin
    var b := randU(200);
    var e := randU(200);
    var m := randU(200) or UBigInt.one;
    if m.isOne then continue;
    check(b.modPowSec(e, m) = b.modPow(e, m), 'modPowSec matches modPow');
  end;
  // sqrtModN: every returned root squares back, and a residue is found
  for var i := 1 to 100 do begin
    var n := randU(40) or UBigInt.one;
    if n < 2 then continue;
    var a := UBigInt.randomBelow(n);
    if not a.gcd(n).isOne then continue;
    var roots := a.sqrtModN(n);
    for var r in roots do check(r.sqr mod n = a, 'sqrtModN valid');
    // if a is a residue, at least one root comes back (small n only)
    if n.toUInt64 <= 3000 then begin
      var isRes := false;
      for var x := 1 to integer(n.toUInt64) - 1 do
        if UBigInt(x).sqr mod n = a then begin
          isRes := true;
          break;
        end;
      check((Length(roots) > 0) = isRes, 'sqrtModN completeness');
    end;
  end;
  // discrete log round-trips: recover x from g^x
  var pm: UBigInt := 1000003;
  var g: UBigInt := 5;
  for var i := 1 to 20 do begin
    var x := UBigInt.randomBelow(UBigInt(500));
    var y := g.modPow(x, pm);
    var rec := g.discreteLog(y, pm);
    check((rec >= 0) and (g.modPow(UBigInt(QWord(rec)), pm) = y), 'discreteLog roundtrip');
  end;
  // safe and strong primes have the required structure
  BigIntRandomSeed(4242);
  var sp := UBigInt.randomSafePrime(96);
  check(sp.isPrime and ((sp - 1) shr 1).isPrime, 'safe prime structure');
  var stp := UBigInt.randomStrongPrime(160);
  check(stp.isPrime, 'strong prime is prime');
end;

procedure testExtrasComb2;
begin
  section('extras: combinatorics');
  // partitions against known values and the pentagonal identity is implicit
  check(UBigInt.partitions(0) = 1, 'p(0)');
  check(UBigInt.partitions(1) = 1, 'p(1)');
  check(UBigInt.partitions(10) = 42, 'p(10)');
  check(UBigInt.partitions(100) = UBigInt('190569292'), 'p(100)');
  check(UBigInt.partitions(500) = UBigInt('2300165032574323995027'), 'p(500)');
  // bell numbers, and bell = sum of stirling2 over k
  check(UBigInt.bell(0) = 1, 'bell(0)');
  check(UBigInt.bell(10) = 115975, 'bell(10)');
  for var n := 0 to 15 do begin
    var s := UBigInt.zero;
    for var k := 0 to n do s := s + UBigInt.stirling2(n, k);
    check(s = UBigInt.bell(n), 'bell = sum stirling2 ' + IntToStr(n));
  end;
  check(UBigInt.stirling2(5, 2) = 15, 'S2(5,2)');
  check(UBigInt.stirling2(10, 3) = 9330, 'S2(10,3)');
  // sum_k |s1(n,k)| = n!, and signs alternate to give the rising factorial
  for var n := 0 to 12 do begin
    var s := BigInt.zero;
    for var k := 0 to n do s := s + BigInt.stirling1(n, k).abs;
    check(s = BigInt.factorial(n), 'sum|s1| = n! ' + IntToStr(n));
  end;
  check(BigInt.stirling1(5, 2) = -50, 's1(5,2)');
  check(BigInt.stirling1(4, 2) = 11, 's1(4,2)');
  // subfactorial and the D(n) = n*D(n-1) + (-1)^n identity
  check(UBigInt.subfactorial(0) = 1, '!0');
  check(UBigInt.subfactorial(9) = 133496, '!9');
  for var n := 2 to 40 do begin
    var lhs := UBigInt.subfactorial(n);
    var rhs := Int64(n) * UBigInt.subfactorial(n - 1);
    if n and 1 = 0 then check(lhs = rhs + 1, 'derangement even ' + IntToStr(n))
    else check(lhs = rhs - 1, 'derangement odd ' + IntToStr(n));
  end;
  // multinomial equals the factorial ratio
  check(UBigInt.multinomial([2, 3, 4]) = UBigInt.factorial(9) div (UBigInt.factorial(2) * UBigInt.factorial(3) * UBigInt.factorial(4)), 'multinomial');
  check(UBigInt.multinomial([5]) = 1, 'multinomial single');
  // rising/falling factorials
  check(UBigInt.risingFactorial(UBigInt(5), 3) = 210, 'rising(5,3)');
  check(UBigInt.fallingFactorial(UBigInt(5), 3) = 60, 'falling(5,3)');
  check(UBigInt.fallingFactorial(UBigInt(3), 5).isZero, 'falling past zero');
  check(BigInt.fallingFactorial(BigInt(-2), 3) = -24, 'falling negative base');
  check(UBigInt.fallingFactorial(UBigInt(9), 9) = UBigInt.factorial(9), 'falling n n = n!');
  // Bernoulli numbers as exact fractions
  var (n1, d1) := BigInt.bernoulli(1);
  check((n1 = -1) and (d1 = 2), 'B1 = -1/2');
  var (n2, d2) := BigInt.bernoulli(2);
  check((n2 = 1) and (d2 = 6), 'B2 = 1/6');
  var (n4, d4) := BigInt.bernoulli(4);
  check((n4 = -1) and (d4 = 30), 'B4 = -1/30');
  var (n6, d6) := BigInt.bernoulli(6);
  check((n6 = 1) and (d6 = 42), 'B6 = 1/42');
  var (n12, d12) := BigInt.bernoulli(12);
  check((n12 = -691) and (d12 = 2730), 'B12 = -691/2730');
  var (n3, d3) := BigInt.bernoulli(3);
  check(n3.isZero and (d3 = 1), 'B3 = 0');
end;

procedure testExtrasFormat;
begin
  section('extras: roman, words, continued fractions');
  checkEq(BigInt(4).toRoman, 'IV', 'roman 4');
  checkEq(BigInt(49).toRoman, 'XLIX', 'roman 49');
  checkEq(BigInt(1994).toRoman, 'MCMXCIV', 'roman 1994');
  checkEq(BigInt(3999).toRoman, 'MMMCMXCIX', 'roman 3999');
  checkRaises(procedure begin var z := BigInt(4000).toRoman; end, EConvertError, 'roman out of range');
  checkRaises(procedure begin var z := BigInt(0).toRoman; end, EConvertError, 'roman zero');
  checkEq(BigInt(0).toWords, 'zero', 'words 0');
  checkEq(BigInt(19).toWords, 'nineteen', 'words 19');
  checkEq(BigInt(42).toWords, 'forty-two', 'words 42');
  checkEq(BigInt(305).toWords, 'three hundred five', 'words 305');
  checkEq(BigInt(1234567).toWords, 'one million two hundred thirty-four thousand five hundred sixty-seven', 'words big');
  checkEq(BigInt(-7).toWords, 'negative seven', 'words negative');
  checkEq(BigInt('1000000000000').toWords, 'one trillion', 'words trillion');
  // continued fractions: expand and rebuild
  var cf := BigInt.continuedFraction(BigInt(415), BigInt(93));
  check((Length(cf) = 4) and (cf[0] = 4) and (cf[3] = 7), 'CF 415/93');
  var (cn, cd) := BigInt.fromContinuedFraction(cf);
  check((cn = 415) and (cd = 93), 'CF rebuild');
  // random rationals round-trip through the CF
  for var i := 1 to 200 do begin
    var a := BigInt(Random(1000000) - 500000);
    var b := BigInt(Random(100000) + 1);
    var (rn, rd) := BigInt.fromContinuedFraction(BigInt.continuedFraction(a, b));
    var g := a.gcd(b);
    check((rn = a div g) and (rd = b div g), 'CF roundtrip');
  end;
  // pi convergents: 22/7 and 355/113 are the low-order best approximations
  var pcf := BigDecimal.pi(40).continuedFraction(6);
  var (pn, pd) := BigInt.fromContinuedFraction(Copy(pcf, 0, 4));
  check((pn = 355) and (pd = 113), 'pi convergent 355/113');
end;

{$if declared(UInt128)}
procedure testInt128;
begin
  section('Int128 / UInt128 conversions');
  // UBigInt -> native 128, checked against the compiler's own arithmetic
  var u := UBigInt.pow2(100) + 12345;
  check(u.toUInt128 = ((UInt128(1) shl 100) + 12345), 'u toUInt128 roundtrip');
  check(u.fitsInUInt128 and u.fitsInInt128, 'u 100-bit fits both');
  check((UBigInt.pow2(127) - 1).fitsInInt128 and not UBigInt.pow2(127).fitsInInt128, 'u Int128 edge');
  check(UBigInt.pow2(127).fitsInUInt128 and not UBigInt.pow2(128).fitsInUInt128, 'u UInt128 edge');
  check((UBigInt.pow2(127) - 1).toInt128 = High(Int128), 'u toInt128 = High(Int128)');
  check((UBigInt.pow2(128) - 1).toUInt128 = High(UInt128), 'u toUInt128 = High(UInt128)');
  checkRaises(procedure begin UBigInt.pow2(200).toUInt128; end, ERangeError, 'u toUInt128 overflow raises');
  // BigInt signed
  check((-(BigInt(1) shl 100)).toInt128 = -(Int128(1) shl 100), 'b toInt128 negative');
  check((-(BigInt(1) shl 127)).toInt128 = Low(Int128), 'b toInt128 = Low(Int128)');
  check((-(BigInt(1) shl 127)).fitsInInt128 and not (-(BigInt(1) shl 127) - 1).fitsInInt128, 'b Low(Int128) edge');
  check((BigInt(1) shl 127).fitsInUInt128 and not (BigInt(1) shl 127).fitsInInt128, 'b 2^127 unsigned only');
  check(BigInt(255).toUInt128 = 255, 'b small toUInt128');
  checkRaises(procedure begin BigInt(-1).toUInt128; end, ERangeError, 'b negative toUInt128 raises');
  // BigDecimal delegates through trunc
  check(BigDecimal('170141183460469231731687303715884105727').toInt128 = High(Int128), 'dec toInt128 max');
  check(BigDecimal('42').fitsInInt128 and not BigDecimal('42.5').fitsInInt128, 'dec fitsInInt128 integral');
end;
{$endif}

procedure testDecCalc;
begin
  section('BigDecimal calculator');
  // precedence and associativity
  checkEq(BigDecimal.calc('2+3*4').toString, '14', 'calc precedence');
  checkEq(BigDecimal.calc('(2+3)*4').toString, '20', 'calc parens');
  checkEq(BigDecimal.calc('2^3^2').toString, '512', 'calc power right assoc');
  checkEq(BigDecimal.calc('-2^2').toString, '-4', 'calc unary below power');
  checkEq(BigDecimal.calc('2^-3').toString, '0.125', 'calc negative exponent');
  checkEq(BigDecimal.calc('5!').toString, '120', 'calc factorial');
  checkEq(BigDecimal.calc('-5!').toString, '-120', 'calc minus factorial');
  checkEq(BigDecimal.calc('5!^2').toString, '14400', 'calc factorial before power');
  checkEq(BigDecimal.calc('(3!)!').toString, '720', 'calc chained factorial');
  checkEq(BigDecimal.calc('0!').toString, '1', 'calc zero factorial');
  checkEq(BigDecimal.calc('----1').toString, '1', 'calc stacked unary');
  checkEq(BigDecimal.calc('2--3').toString, '5', 'calc minus minus');
  // division family
  checkEq(BigDecimal.calc('10/4').toString, '2.5', 'calc true division');
  checkEq(BigDecimal.calc('1/3').toString, '0.333333333333333333', 'calc 1/3 default precision');
  checkEq(BigDecimal.calc('1/3*3').toString, '1', 'calc guard digit');
  checkEq((BigDecimal.calc('1/3') * 3).toString, '1', 'calc guard survives outside');
  checkEq(BigDecimal.calc('10 div 3').toString, '3', 'calc div');
  checkEq(BigDecimal.calc('10 mod 3').toString, '1', 'calc mod');
  checkEq(BigDecimal.calc('10 % 3').toString, '1', 'calc percent alias');
  checkEq(BigDecimal.calc('7.5 div 2').toString, '3', 'calc div fractional');
  checkEq(BigDecimal.calc('7.5 mod 2').toString, '1.5', 'calc mod fractional');
  // power aliases
  checkEq(BigDecimal.calc('2**10').toString, '1024', 'calc star star');
  checkEq(BigDecimal.calc('pow(2, 10)').toString, '1024', 'calc pow function');
  check(BigDecimal.calc('2^0.5', 40).toString = BigDecimal(2).sqrt(40).toString, 'calc fractional power');
  // numbers
  checkEq(BigDecimal.calc('1_000.5*2').toString, '2001', 'calc separators');
  checkEq(BigDecimal.calc('2.5E3').toString, '2500', 'calc exponent literal');
  checkEq(BigDecimal.calc('.5+.5').toString, '1', 'calc leading dot');
  checkEq(BigDecimal.calc('2e3').toString, '2000', 'calc lowercase exponent');
  checkEq(BigDecimal.calc('2 * e', 18).rounded(-6).toString, '5.436564', 'calc e constant after number');
  // functions match the methods digit for digit at the same precision
  checkEq(BigDecimal.calc('sqrt(2)', 40).toString, BigDecimal(2).sqrt(40).toString, 'calc sqrt');
  checkEq(BigDecimal.calc('cbrt(2)', 40).toString, BigDecimal(2).nthRoot(3, 40).toString, 'calc cbrt');
  checkEq(BigDecimal.calc('root(2, 5)', 40).toString, BigDecimal(2).nthRoot(5, 40).toString, 'calc root');
  checkEq(BigDecimal.calc('exp(1)', 40).toString, BigDecimal(1).exp(40).toString, 'calc exp');
  checkEq(BigDecimal.calc('ln(2)', 40).toString, BigDecimal(2).ln(40).toString, 'calc ln');
  checkEq(BigDecimal.calc('log(7)', 40).toString, BigDecimal(7).log10(40).toString, 'calc log excel');
  checkEq(BigDecimal.calc('log(8, 2)').toString, '3', 'calc log base');
  checkEq(BigDecimal.calc('log2(1024)').toString, '10', 'calc log2 exact');
  checkEq(BigDecimal.calc('log10(0.001)').toString, '-3', 'calc log10 exact');
  checkEq(BigDecimal.calc('logb(8, 2)').toString, '3', 'calc logb');
  checkEq(BigDecimal.calc('sin(1)', 40).toString, BigDecimal(1).sin(40).toString, 'calc sin');
  checkEq(BigDecimal.calc('cos(1)', 40).toString, BigDecimal(1).cos(40).toString, 'calc cos');
  checkEq(BigDecimal.calc('tan(1)', 40).toString, BigDecimal(1).tan(40).toString, 'calc tan');
  checkEq(BigDecimal.calc('asin(0.5)', 40).toString, BigDecimal('0.5').arcsin(40).toString, 'calc asin');
  checkEq(BigDecimal.calc('arcsin(0.5)', 40).toString, BigDecimal.calc('asin(0.5)', 40).toString, 'calc arcsin alias');
  checkEq(BigDecimal.calc('acos(0.5)', 40).toString, BigDecimal('0.5').arccos(40).toString, 'calc acos');
  checkEq(BigDecimal.calc('atan(2)', 40).toString, BigDecimal(2).arctan(40).toString, 'calc atan');
  checkEq(BigDecimal.calc('sinh(1)', 40).toString, BigDecimal(1).sinh(40).toString, 'calc sinh');
  checkEq(BigDecimal.calc('cosh(1)', 40).toString, BigDecimal(1).cosh(40).toString, 'calc cosh');
  checkEq(BigDecimal.calc('tanh(1)', 40).toString, BigDecimal(1).tanh(40).toString, 'calc tanh');
  checkEq(BigDecimal.calc('gamma(0.5)', 40).toString, BigDecimal('0.5').gamma(40).toString, 'calc gamma');
  checkEq(BigDecimal.calc('lngamma(3.5)', 40).toString, BigDecimal('3.5').lnGamma(40).toString, 'calc lngamma');
  checkEq(BigDecimal.calc('erf(1)', 40).toString, BigDecimal(1).erf(40).toString, 'calc erf');
  checkEq(BigDecimal.calc('erfc(1)', 40).toString, BigDecimal(1).erfc(40).toString, 'calc erfc');
  checkEq(BigDecimal.calc('factorial(5.5)', 30).toString, BigDecimal('5.5').factorial(30).toString, 'calc real factorial');
  checkEq(BigDecimal.calc('atan2(1, -1)', 40).toString, BigDecimal.atan2(1, -1, 40).toString, 'calc atan2');
  checkEq(BigDecimal.calc('hypot(3, 4)').toString, '5', 'calc hypot');
  checkEq(BigDecimal.calc('agm(1, 2)', 40).toString, BigDecimal.agm(1, 2, 40).toString, 'calc agm');
  checkEq(BigDecimal.calc('sqr(4)').toString, '16', 'calc sqr');
  checkEq(BigDecimal.calc('abs(-4.5)').toString, '4.5', 'calc abs');
  checkEq(BigDecimal.calc('floor(3.7)+ceil(3.2)+trunc(-3.7)+round(2.5)').toString, '6', 'calc roundings');
  checkEq(BigDecimal.calc('min(3, 2)+max(3, 2)').toString, '5', 'calc min max');
  checkEq(BigDecimal.calc('gcd(0.25, 0.15)').toString, '0.05', 'calc gcd lattice');
  checkEq(BigDecimal.calc('lcm(4, 6)').toString, '12', 'calc lcm');
  // constants
  checkEq(BigDecimal.calc('pi', 50).toString, BigDecimal.pi(50).toString, 'calc pi');
  checkEq(BigDecimal.calc('e', 50).toString, BigDecimal.e(50).toString, 'calc e');
  check((BigDecimal.calc('tau', 40) - BigDecimal.pi(48) * 2).abs < BigDecimal('1E-39'), 'calc tau');
  check((BigDecimal.calc('phi', 40) - BigDecimal.calc('(1+sqrt(5))/2', 40)).abs < BigDecimal('1E-39'), 'calc phi');
  check((BigDecimal.calc('phi^2 - phi - 1', 40)).abs < BigDecimal('1E-38'), 'calc phi property');
  // case-insensitive
  checkEq(BigDecimal.calc('SIN(0)+Cos(0)').toString, '1', 'calc case insensitive');
  checkEq(BigDecimal.calc('PI', 20).toString, BigDecimal.calc('pi', 20).toString, 'calc PI');
  // whitespace freedom
  checkEq(BigDecimal.calc('  2 +   3*4  ').toString, '14', 'calc whitespace');
  // precision parameter and trimming
  check(BigDecimal.calc('1/3', 50).precision = 51, 'calc precision 50 plus guard');
  checkEq(BigDecimal.calc('2+2', 50).toString, '4', 'calc exact stays exact');
  checkEq(BigDecimal.calc('0.5', 3).toString, '0.5', 'calc short exact untouched');
  // the original motivating expression, cross-checked by hand
  check(BigDecimal.calc('123456999999**123*4444/2/sqr(4)', 10).rounded(-5) = ((BigDecimal('123456999999') ** 123) * 4444).divide(2, 18).divide(16, 18).rounded(-5), 'calc user expression');
  // errors: syntax raises EConvertError with a position, math errors pass through
  checkRaises(procedure begin BigDecimal.calc(''); end, EConvertError, 'calc empty');
  checkRaises(procedure begin BigDecimal.calc('1+'); end, EConvertError, 'calc dangling operator');
  checkRaises(procedure begin BigDecimal.calc('(1'); end, EConvertError, 'calc open paren');
  checkRaises(procedure begin BigDecimal.calc('1)'); end, EConvertError, 'calc stray paren');
  checkRaises(procedure begin BigDecimal.calc('foo(1)'); end, EConvertError, 'calc unknown function');
  checkRaises(procedure begin BigDecimal.calc('bar'); end, EConvertError, 'calc unknown name');
  checkRaises(procedure begin BigDecimal.calc('sqrt(1,2)'); end, EConvertError, 'calc too many args');
  checkRaises(procedure begin BigDecimal.calc('sqrt()'); end, EConvertError, 'calc no args');
  checkRaises(procedure begin BigDecimal.calc('1 2'); end, EConvertError, 'calc juxtaposition');
  checkRaises(procedure begin BigDecimal.calc('@'); end, EConvertError, 'calc bad char');
  checkRaises(procedure begin BigDecimal.calc('2e'); end, EConvertError, 'calc dangling exponent');
  checkRaises(procedure begin BigDecimal.calc('e(5)'); end, EConvertError, 'calc constant is not a function');
  checkRaises(procedure begin BigDecimal.calc('1/0'); end, EDivByZero, 'calc division by zero');
  checkRaises(procedure begin BigDecimal.calc('ln(-1)'); end, EBigIntError, 'calc domain error passes');
  checkRaises(procedure begin BigDecimal.calc('root(2, 0.5)'); end, EBigIntError, 'calc root degree');
  var errMsg := '';
  try
    BigDecimal.calc('1 + bar(2)');
  except
    on ex: EConvertError do errMsg := ex.Message;
  end;
  check(Pos('position 5', errMsg) > 0, 'calc error carries position');
  // tryCalc never raises
  var v: BigDecimal;
  check(BigDecimal.tryCalc('2+2', v) and (v = 4), 'calc tryCalc ok');
  check(not BigDecimal.tryCalc('1/0', v), 'calc tryCalc math error');
  check(not BigDecimal.tryCalc('1+', v), 'calc tryCalc syntax error');
  // nesting guard
  var deep := '1';
  for var i := 1 to 100 do deep := '(' + deep + ')';
  checkEq(BigDecimal.calc(deep).toString, '1', 'calc 100 parens fine');
  for var i := 1 to 200 do deep := '(' + deep + ')';
  checkRaises(procedure begin BigDecimal.calc(deep); end, EConvertError, 'calc 300 parens rejected');
end;

begin
  RandSeed := 20260706;
  // the native RNG now auto-seeds from OS entropy per thread; seed it explicitly
  // so the whole run is reproducible
  BigIntRandomSeed(20260706);
  testUBasics;
  testUArithmeticSmall;
  testUCarryChains;
  testUMulDivRandom;
  testUDivisionEdge;
  testUStringsAndParse;
  testUConversions;
  testUBits;
  testUOperatorsMixed;
  testUAliasing;
  testUErrors;

  testBBasics;
  testBArithmeticSmall;
  testBBigIdentities;
  testBBitwiseTC;
  testBStringsParse;
  testBConversions;
  testBMixedTypes;
  testBFloorCeil;
  testBAliasing;
  testBErrors;

  testMathRoots;
  testMathGcdLcm;
  testMathModular;
  testMathFactFib;
  testMathPrimes;
  testBytesEtc;

  testKaratsuba;
  testToom3;
  testStressChain;
  testStressStrings;

  testExtrasRandom;
  testExtrasNumberTheory;
  testExtrasCombinatorics;
  testExtrasFactorize;
  testExtrasMultiplicative;
  testExtrasCrypto;
  testExtrasComb2;
  testExtrasFormat;

  testDecBasics;
  testDecArithmetic;
  testDecDivision;
  testDecRounding;
  testDecFloats;
  testDecMath;
  testDecIntrospection;
  testDecTranscendental;
  testDecTrig;
  testDecPractical;
  testDecSpecial;
  testDecCalc;
  {$if declared(UInt128)}
  testInt128;
  {$endif}

  writeln;
  if failCount = 0 then writeln(#27'[32mALL TESTS PASSED (', passCount, ' checks)'#27'[0m')
  else writeln(#27'[31m', failCount, ' FAILED / ', passCount, ' passed'#27'[0m');
  if failCount <> 0 then ExitCode := 1;
end.
