program sequences;

// combinatorial generators: factorial, fibonacci, lucas, binomial, catalan,
// primorial

{$mode unleashed}

uses BigInts;

begin
  writeln($'20!  = {UBigInt.factorial(20)}');
  writeln($'F(100) = {UBigInt.fibonacci(100)}');
  writeln($'L(100) = {UBigInt.lucas(100)}');
  writeln($'C(50, 25) = {UBigInt.binomial(50, 25)}');
  writeln($'catalan(20) = {UBigInt.catalan(20)}');
  writeln($'29# = {UBigInt.primorial(29)}'); // product of primes up to 29

  // identity: L(n) = F(n-1) + F(n+1)
  writeln(UBigInt.lucas(500) = UBigInt.fibonacci(499) + UBigInt.fibonacci(501));

  // catalan(n) = binomial(2n, n) div (n+1)
  writeln(UBigInt.catalan(30) = UBigInt.binomial(60, 30) div 31);

  // how big do they get
  writeln($'digits of 10000!: {UBigInt.factorial(10000).digitCount}');
  writeln($'digits of F(10000): {UBigInt.fibonacci(10000).digitCount}');
  {$ifdef WINDOWS}readln;{$endif}
end.
