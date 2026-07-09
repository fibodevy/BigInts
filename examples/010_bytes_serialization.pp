program bytes_serialization;

// raw magnitude bytes in both endiannesses, e.g. for crypto interop

{$mode unleashed}

uses SysUtils, BigInts;

begin
  var n: UBigInt := '0x0102030405';
  var le := n.toBytesLE;
  var be := n.toBytesBE;
  write('LE:');
  for var b in le do write(' ', IntToHex(b, 2));
  writeln;
  write('BE:');
  for var b in be do write(' ', IntToHex(b, 2));
  writeln;

  writeln(UBigInt.fromBytesLE(le) = n);   // TRUE
  writeln(UBigInt.fromBytesBE(be) = n);   // TRUE

  // a 256-bit key roundtrip
  BigIntRandomSeed(7);
  var key := UBigInt.random(256);
  writeln(UBigInt.fromBytesBE(key.toBytesBE) = key);
  writeln($'key bytes: {Length(key.toBytesBE)}');
  {$ifdef WINDOWS}readln;{$endif}
end.
