program exact_money;

// the reason decimal types exist: money that never drifts

{$mode unleashed}

uses BigInts;

begin
  writeln($'{BigDecimal('0.1') + BigDecimal('0.2')}'); // 0.3, not 0.30000000000000004

  // sum a million transactions of 0.01 - binary floats drift, decimals do not
  var cent: BigDecimal := '0.01';
  var total := BigDecimal.zero;
  for var i := 1 to 1000000 do total += cent;
  writeln($'{total}'); // 10000

  // an invoice with vat
  var net: BigDecimal := '1234.56';
  var vat := (net * BigDecimal('0.23')).rounded(-2);
  writeln($'net {net}  vat {vat}  gross {net + vat}');

  // split 100.00 into 3 equal shares, the remainder goes on top of one
  var s := BigDecimal(100).divide(3, 2).rounded(-2, bdrFloor);
  writeln($'3 x {s} + {100 - s * 3} = 100');
  {$ifdef WINDOWS}readln;{$endif}
end.
