program digit_statistics;

// how uniform are the digits of 2^10000 and 1000 digits of pi

{$mode unleashed}

uses BigInts;

procedure histogram(const s: string; const title: string);
begin
  var counts: array[0..9] of integer;
  for var i := 0 to 9 do counts[i] := 0;
  var total := 0;
  for var i := 1 to Length(s) do
    if (s[i] >= '0') and (s[i] <= '9') then begin
      inc(counts[Ord(s[i]) - Ord('0')]);
      inc(total);
    end;
  writeln(title, ' (', total, ' digits)');
  for var d := 0 to 9 do writeln($'  {d}: {counts[d]}');
end;

begin
  histogram(UBigInt.pow2(10000).toString, '2^10000');
  histogram(BigDecimal.pi(1000).toString, 'pi');
  {$ifdef WINDOWS}readln;{$endif}
end.
