program compound_interest;

// an exact savings schedule: no cent ever appears or vanishes

{$mode unleashed}

uses BigInts;

begin
  var balance: BigDecimal := '10000.00';
  var rate: BigDecimal := '0.0525'; // 5.25% yearly
  var monthly := rate / 12;
  writeln('month   interest    balance');
  var totalInterest := BigDecimal.zero;
  for var m := 1 to 12 do begin
    // banks round each posting to cents; with decimals that is exact policy,
    // not accumulated noise
    var interest := (balance * monthly).rounded(-2, bdrHalfEven);
    balance += interest;
    totalInterest += interest;
    if m mod 3 = 0 then writeln($'{m}: {interest}  {balance}');
  end;
  writeln($'total interest: {totalInterest}');
  writeln($'effective rate: {(totalInterest.divide(BigDecimal(10000), 6) * 100).rounded(-4)}%');
  {$ifdef WINDOWS}readln;{$endif}
end.
