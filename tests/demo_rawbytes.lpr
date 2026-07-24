program demo_rawbytes;

{$mode unleashed}

uses {$ifdef WINDOWS}Windows,{$endif} BigInts;

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

var
  fails: integer = 0;

procedure check(const name: string; ok: boolean);
begin
  if ok then writeln(#27'[32mOK  '#27'[0m', name) else begin
    writeln(#27'[31mFAIL'#27'[0m ', name);
    inc(fails);
  end;
end;

// hex dump of a raw byte string
function dump(const s: string): string;
begin
  result := '';
  for var i := 1 to Length(s) do result += HexStr(ord(s[i]), 2);
end;

begin
  {$ifdef WINDOWS}enableVTColors;{$endif}

  // --- UBigInt: string container ---
  var u := UBigInt.parse('$DEADBEEFCAFE1234567890');
  var sLE := u.toByteStringLE;
  var sBE := u.toByteStringBE;
  writeln('u        = ', u.toHex);
  writeln('u LE str = ', dump(sLE));
  writeln('u BE str = ', dump(sBE));
  check('UBigInt byteString LE roundtrip', UBigInt.fromByteStringLE(sLE) = u);
  check('UBigInt byteString BE roundtrip', UBigInt.fromByteStringBE(sBE) = u);
  check('UBigInt BE string starts with $DE', ord(sBE[1]) = $DE);
  check('UBigInt LE string starts with $90', ord(sLE[1]) = $90);
  check('UBigInt string matches TBytes len', Length(sLE) = Length(u.toBytesLE));

  // --- UBigInt: pointer container ---
  var p: Pointer;
  var n := u.toBytesLE(p);
  check('UBigInt pointer LE roundtrip', UBigInt.fromBytesLE(p, n) = u);
  FreeMem(p);
  n := u.toBytesBE(p);
  check('UBigInt pointer BE roundtrip', UBigInt.fromBytesBE(p, n) = u);
  check('UBigInt pointer BE first byte $DE', PByte(p)^ = $DE);
  FreeMem(p);

  // --- UBigInt: zero ---
  check('UBigInt zero byteString empty', UBigInt.zero.toByteStringLE = '');
  check('UBigInt zero from empty string', UBigInt.fromByteStringLE('') = 0);
  n := UBigInt.zero.toBytesLE(p);
  check('UBigInt zero pointer len 0', n = 0);
  FreeMem(p);

  // --- BigInt: sign lives in the data (two's complement) ---
  for var v in [BigInt(0), BigInt(1), BigInt(-1), BigInt(127), BigInt(128), BigInt(-128), BigInt(-129), BigInt.parse('123456789012345678901234567890'), BigInt.parse('-123456789012345678901234567890')] do begin
    var raw := v.toByteStringLE;
    check('BigInt byteString LE roundtrip '+v.toString, BigInt.fromByteStringLE(raw) = v);
    raw := v.toByteStringBE;
    check('BigInt byteString BE roundtrip '+v.toString, BigInt.fromByteStringBE(raw) = v);
    var q: Pointer;
    var m := v.toBytesLE(q);
    check('BigInt pointer LE roundtrip '+v.toString, BigInt.fromBytesLE(q, m) = v);
    FreeMem(q);
    m := v.toBytesBE(q);
    check('BigInt pointer BE roundtrip '+v.toString, BigInt.fromBytesBE(q, m) = v);
    FreeMem(q);
  end;

  // -1 is a single $FF byte, sign read back from the data
  check('BigInt -1 byteString is $FF', BigInt(-1).toByteStringLE = #$FF);
  writeln('-300 LE  = ', dump(BigInt(-300).toByteStringLE));
  writeln('-300 BE  = ', dump(BigInt(-300).toByteStringBE));

  // string and TBytes forms carry identical bytes
  var big := BigInt.parse('-987654321987654321987654321');
  var tb := big.toBytesBE;
  var bs := big.toByteStringBE;
  var same := Length(tb) = Length(bs);
  if same then
    for var i := 0 to High(tb) do
      if tb[i] <> ord(bs[i+1]) then same := false;
  check('BigInt string bytes = TBytes bytes', same);

  // cross-check against 64-bit ints written to memory natively (LE)
  var i64: Int64 := -123456789012345;
  var vi := BigInt(i64);
  check('BigInt LE(8) matches raw Int64 memory', vi.toByteStringLE = BigInt.fromBytesLE(@i64, 8).toByteStringLE);
  check('BigInt from raw Int64 memory', BigInt.fromBytesLE(@i64, 8) = i64);

  writeln;
  if fails = 0 then writeln(#27'[32mALL OK'#27'[0m') else writeln(#27'[31m', fails, ' FAILED'#27'[0m');
  readln;
end.
