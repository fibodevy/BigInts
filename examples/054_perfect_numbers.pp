program perfect_numbers;

// Euclid: 2^(p-1) * (2^p - 1) is perfect when 2^p - 1 is prime

{$mode unleashed}

uses BigInts;

// sum of proper divisors from the factorization
function sigmaProper(const n: UBigInt): UBigInt;
begin
  var s := UBigInt.one;
  for var (p, e) in n.factorize do s := s * ((p.pow(e + 1) - 1) div (p - 1));
  result := s - n;
end;

begin
  for var p in [2, 3, 5, 7, 13] do begin
    var m := UBigInt.pow2(LongWord(p)) - 1;
    if not m.isProbablePrime then continue;
    var perfect := UBigInt.pow2(LongWord(p - 1)) * m;
    writeln($'{perfect}  proper divisors sum to {sigmaProper(perfect)}');
  end;
  {$ifdef WINDOWS}readln;{$endif}
end.
