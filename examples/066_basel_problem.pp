program basel_problem;

// sum of 1/k^2 crawls toward pi^2/6 - watch the gap shrink like 1/n

{$mode unleashed}

uses BigInts;

begin
  var target := (BigDecimal.pi(40) ** 2) / 6;
  writeln($'pi^2/6 = {target.rounded(-30)}');
  var sum := BigDecimal.zero;
  var k := 0;
  for var stop in [10, 100, 1000, 10000] do begin
    while k < stop do begin
      inc(k);
      sum += BigDecimal(1).divide(BigDecimal(k) * k, 40);
    end;
    writeln($'n = {stop}: {sum.rounded(-12)}  gap {(target - sum).toScientific}');
  end;
  {$ifdef WINDOWS}readln;{$endif}
end.
