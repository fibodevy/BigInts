program jacobi_modsqrt;

// quadratic residues: the Jacobi symbol and Tonelli-Shanks square roots

{$mode unleashed}

uses SysUtils, BigInts;

begin
  var p: UBigInt := '1000000000000000003';

  // jacobi = 1 means "quadratic residue" for a prime modulus
  var a: UBigInt := 5;
  writeln($'jacobi(5/p) = {a.jacobi(p)}');

  // find a residue and take its root
  var x: UBigInt := 123456789;
  var sq := x.sqr mod p;
  var root := sq.modSqrt(p);
  writeln($'root = {root}');
  writeln(root.sqr mod p = sq);            // TRUE
  writeln((root = x) or (root = p - x));   // either root works

  // non-residues raise
  var nr: UBigInt := 2;
  while nr.jacobi(p) <> -1 do inc(nr);
  try
    var bad := nr.modSqrt(p);
  except
    on e: EBigIntError do writeln('non-residue: ', e.Message);
  end;
  {$ifdef WINDOWS}readln;{$endif}
end.
