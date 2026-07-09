program parsing_input;

// parse raises on junk, tryParse returns false instead

{$mode unleashed}

uses SysUtils, BigInts;

begin
  writeln($'{UBigInt.parse('  1_000_000  ')}'); // whitespace and separators ok
  writeln($'{UBigInt.parse('DEADBEEF', 16)}');
  writeln($'{BigInt.parse('-42')}');

  var v: UBigInt;
  if UBigInt.tryParse('123x', v) then writeln('parsed') else writeln('junk rejected');
  if UBigInt.tryParse('777', 8, v) then writeln($'octal 777 = {v}');

  try
    var bad := UBigInt.parse('twelve');
  except
    on e: EConvertError do writeln('EConvertError: ', e.Message);
  end;

  // a negative string cannot land in an unsigned value
  var s: BigInt;
  writeln(BigInt.tryParse('-5', s), ' ', UBigInt.tryParse('-5', v)); // TRUE FALSE
  {$ifdef WINDOWS}readln;{$endif}
end.
