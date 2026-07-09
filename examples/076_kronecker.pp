program kronecker_symbol;

// the Kronecker symbol extends Jacobi to every integer, including 2 and
// negatives

{$mode unleashed}

uses BigInts;

begin
  // (a/2) follows the a mod 8 rule
  writeln($'(7/2)  = {BigInt(7).kronecker(BigInt(2))}');   //  1
  writeln($'(5/2)  = {BigInt(5).kronecker(BigInt(2))}');   // -1
  // negative arguments
  writeln($'(-1/7) = {BigInt(-1).kronecker(BigInt(7))}');  // -1
  writeln($'(-1/5) = {BigInt(-1).kronecker(BigInt(5))}');  //  1

  // a quadratic residue table modulo 15 via the symbol
  write('residue flags mod 15:');
  for var a := 1 to 14 do
    if BigInt(a).gcd(BigInt(15)).isOne then write($' {a}:{BigInt(a).kronecker(BigInt(15))}');
  writeln;
  {$ifdef WINDOWS}readln;{$endif}
end.
