program signed_bytes;

// BigInt bytes are minimal two's complement with a sign bit, like Java's
// toByteArray

{$mode unleashed}

uses SysUtils, BigInts;

procedure show(v: Int64);
begin
  var b := BigInt(v).toBytesBE;
  write(v:5, ':');
  for var x in b do write(' ', IntToHex(x, 2));
  writeln;
end;

begin
  show(127);        // 7F
  show(128);        // 00 80 - the extra zero keeps it non-negative
  show(-128);       // 80
  show(-129);       // FF 7F
  show(255);        // 00 FF

  // roundtrips keep the sign
  var n: BigInt := '-123456789012345678901234567890';
  writeln(BigInt.fromBytesBE(n.toBytesBE) = n);   // TRUE
  writeln(BigInt.fromBytesLE(n.toBytesLE) = n);   // TRUE
  {$ifdef WINDOWS}readln;{$endif}
end.
