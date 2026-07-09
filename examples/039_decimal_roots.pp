program decimal_roots;

// square roots and nth roots at any precision

{$mode unleashed}

uses BigInts;

begin
  writeln($'{BigDecimal(2).sqrt}');            // 18 digits by default
  writeln($'{BigDecimal(2).sqrt(50)}');
  writeln($'{BigDecimal('0.25').sqrt}');        // 0.5, exact roots stay exact
  writeln($'{BigDecimal('152.2756').sqrt(4)}'); // 12.34

  writeln($'{BigDecimal(2).nthRoot(3, 40)}');     // cube root of 2
  writeln($'{BigDecimal('27').nthRoot(3)}');      // 3
  writeln($'{BigDecimal('-27').nthRoot(3)}');     // -3, odd roots keep the sign
  writeln($'{BigDecimal('0.00032').nthRoot(5)}'); // 0.2

  // high precision is routine
  var r := BigDecimal(5).sqrt(100);
  writeln($'{(r * r).rounded(-98)}'); // 5
  {$ifdef WINDOWS}readln;{$endif}
end.
