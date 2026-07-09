# BigInts

Arbitrary precision integers and decimals for Pascal in a single self-contained unit, `BigInts` ([bigints.pas](bigints.pas)). Three value types, every operator a plain number has, no size limits beyond available memory, no dependencies beyond the RTL.

> **Requires a compiler that understands `{$mode unleashed}`.** The unit and the examples below lean on inline variables, tuples, statement expressions and interpolated strings, so a stock compiler will not build them.

| type | what it is |
|---|---|
| `BigInt` | signed; bitwise operators use two's complement semantics with infinite sign extension, like Python ints |
| `UBigInt` | unsigned; anything that would drop below zero raises `ERangeError` |
| `BigDecimal` | decimal float: a `BigInt` mantissa times a power of ten; exact `+ - *`, division at a chosen precision |

## Capabilities

- full operator coverage: `+ - * div mod / ** shl shr and or xor not`, all comparisons, `inc`/`dec`, compound assignments (`+=`, `*=`, ...), unary `+`/`-`
- mixed expressions with plain integers on either side, implicit conversions from `Int64`/`QWord`/string, explicit casts in both directions (`Double` included; integer casts never round through floating point)
- literals of any size with `_` separators and `$ 0x % 0b & 0o` prefixes; parsing and formatting in every base 2..36
- multiplication: schoolbook, Karatsuba and Toom-3, picked by tunable thresholds, with dedicated squaring paths
- division: Knuth algorithm D, plus divide-and-conquer base conversion for long numbers
- modular arithmetic: Montgomery `modPow` with a windowed exponent, `modInverse`, `modSqrt` (Tonelli-Shanks), `crt`
- primes: Miller-Rabin `isProbablePrime` (deterministic below 3.3e24), `nextPrime`/`prevPrime`, `randomPrime` with an exact bit length
- factorization: trial division plus Pollard-Brent rho, exponents grouped into `(p, e)` tuples
- number theory and combinatorics: Lehmer `gcd`, `gcdExt` (Bezout coefficients), `lcm`, `jacobi`, `factorial`, `fibonacci`, `lucas`, `binomial`, `catalan`, `primorial`
- randomness: pluggable generators (xoshiro256**, PCG64, splitmix64, `System.Random`, OS entropy), deterministic seeding, uniform `randomBelow`/`randomRange`
- interop: byte serialization in both endiannesses, `hashCode`, digit-grouped output
- decimals: exact decimal arithmetic (`0.1 + 0.2 = 0.3`), division and roots at any precision, six rounding modes, shortest and exact float conversions in both directions, and the whole analytic toolbox - `pi`, `exp`, `ln`, `log`, fractional powers, trigonometry and hyperbolics at any precision (the BigDecimal chapter below)
- speed: measured 1.4-4x of GMP on x64 for the core operations (benchmarks below); assembler inner loops with a pure Pascal fallback behind a `USEASM` define

## Quick start

```pascal
program quickstart;

{$mode unleashed}

uses BigInts;

begin
  var a: BigInt := '123456789012345678901234567890';
  var b: BigInt := '-0xDEAD_BEEF';
  writeln($'{a * b}');
  writeln((BigInt(2) ** 4096).digitCount);           // 1234
  var (q, r) := a.divMod(b);
  writeln($'{q}  rem {r}');
  var p := UBigInt.randomPrime(256);
  writeln(p.isProbablePrime);                         // TRUE
  for var (f, e) in UBigInt(720).factorize do
    write($'{f}^{e} ');                               // 2^4 3^2 5^1
  writeln;
  {$ifdef WINDOWS}readln;{$endif}
end.
```

## Methods

Everything is camelCase and discoverable through code completion. Methods live on both types unless a note says otherwise.

### Converting in and out

| method | notes |
|---|---|
| `parse(s)`, `parse(s, base)` | static; auto-detects `$ 0x % 0b & 0o` prefixes, allows `_` separators and a sign |
| `tryParse(s, out v)`, `tryParse(s, base, out v)` | static; no exception on bad input |
| `toString`, `toString(base)` | base 2..36; negatives format as sign plus magnitude in every base |
| `toHex`, `toBin`, `toOct` | shorthands for bases 16, 2, 8 |
| `toStringGrouped(sep = '_', groupSize = 3)` | `1_234_567` style output |
| `toInt64`, `toQWord`, `toInteger`, `toCardinal`, `toDouble` | raise `ERangeError` when the value does not fit |
| `fitsInInt64`, `fitsInQWord`, `fitsInInteger`, `fitsInCardinal` | the matching checks |
| `toUBigInt` / `toBigInt` | cross the signedness bridge; a negative value raises `ERangeError` |
| `toBytesLE`, `toBytesBE`, `fromBytesLE`, `fromBytesBE` | `UBigInt`: raw magnitude; `BigInt`: minimal two's complement with the sign bit, like Java `toByteArray` |

### Predicates and sign

| method | notes |
|---|---|
| `isZero`, `isOne`, `isEven`, `isOdd`, `isPowerOfTwo` | |
| `sign` | -1, 0 or 1 |
| `isNegative`, `isPositive` | `BigInt` only |
| `abs`, `magnitude`, `negate` | `BigInt` only; `magnitude` is the absolute value as `UBigInt` |

### Bits

| method | notes |
|---|---|
| `bitLength`, `popCount`, `lowestSetBit` | |
| `testBit(i)`, `setBit(i)`, `clearBit(i)`, `flipBit(i)`, `bits[i]` | on `BigInt` these see the infinite two's complement expansion |
| `complement(width)` | `UBigInt` only: bitwise not of the low `width` bits; the infinite complement of an unsigned value does not exist, so `UBigInt` has no `not` operator |

### Comparing and dividing

| method | notes |
|---|---|
| `compare`, `equals`, `min`, `max` | plus the full set of comparison operators |
| `divMod(d)` | one division, returns the `(q, r)` tuple |
| `floorDiv(d)`, `floorMod(d)` | `BigInt` only; round toward minus infinity like Python |
| `ceilDiv(d)` | rounds toward plus infinity |
| `swap(other)`, `hashCode`, `digitCount` | |

### Math

| method | notes |
|---|---|
| `sqr`, `sqrt`, `nthRoot(n)` | squaring and integer (floor) roots |
| `pow(e)`, `**` | plain powers |
| `modPow(e, m)` | Montgomery with a windowed exponent for odd `m`; on `BigInt` the modulus must be positive, the result lands in `0..m-1` and a negative exponent goes through the modular inverse |
| `modInverse(m)` | raises `EBigIntError` when no inverse exists |
| `gcd`, `lcm` | Lehmer gcd |
| `isProbablePrime(rounds = 24)` | Miller-Rabin; deterministic witnesses below 3.3e24, random rounds above |
| `nextPrime` | first prime above self |

### Constants and generators (class functions)

| method | notes |
|---|---|
| `zero`, `one`, `two`, `ten`, `minusOne` | `minusOne` on `BigInt` only |
| `pow2(n)` | |
| `random(bits)` | uniform below `2^bits`; the generator is pluggable, see the extras chapter |
| `factorial(n)` | binary split |
| `fibonacci(n)` | fast doubling |

## Extras

The optional math layer on top of the core arithmetic.

### Random

| method | notes |
|---|---|
| `randomBelow(bound)` | uniform in `0..bound-1`, rejection sampling |
| `randomRange(lo, hi)` | uniform in `lo..hi`, both ends included; negative bounds work on `BigInt` |
| `randomPrime(bits, rounds = 24)` | exact bit length: top bit set, odd, Miller-Rabin tested |

The backend behind `random` and friends is selected with the `BigIntRngAlgo` variable:

| generator | notes |
|---|---|
| `rngXoshiro256ss` | default; xoshiro256** |
| `rngPcg64` | PCG XSL-RR 128/64 with the reference multiplier and stream |
| `rngSplitMix64` | tiny and fast; also used internally to expand seeds |
| `rngSystem` | the historical `RandSeed`-driven `System.Random` stream |
| `rngOS` | fresh OS entropy on every call (RtlGenRandom, /dev/urandom); pick this for key material |

`BigIntRandomSeed(seed)` seeds every generator deterministically (it also sets `RandSeed`, so `rngSystem` follows along); `BigIntRandomize` seeds them from OS entropy. Unseeded runs are deterministic, the same way `System.Random` behaves with `RandSeed = 0`.

### Number theory

| method | notes |
|---|---|
| `gcdExt(other)` | `BigInt` only; extended Euclid returning the `(g, x, y)` tuple with `a*x + b*y = g` |
| `jacobi(n)` | Jacobi symbol for an odd positive `n`, returns -1, 0 or 1 |
| `modSqrt(p)` | square root modulo a prime (Tonelli-Shanks); raises `EBigIntError` for a non-residue |
| `crt(remainders, moduli)` | `BigInt` class function; Chinese remainder theorem for pairwise coprime positive moduli |
| `isPerfectSquare` | quick mod-16 filter, then an exact root check |
| `sqrtRem` | returns the `(root, rem)` tuple with `self = root^2 + rem` |
| `prevPrime` | largest prime below self; raises for `self <= 2` |
| `factorize` | array of `(p, e)` tuples in ascending prime order; trial division below 10^4, Pollard-Brent rho above; `BigInt.factorize` factors the absolute value |

`factorize` runtime grows with the square root of the second-largest prime factor, so a product of two large random primes will grind for a very long time - that is the nature of factoring, not a bug.

### Combinatorics

| method | notes |
|---|---|
| `lucas(n)` | companion sequence to Fibonacci, one fast-doubling run |
| `binomial(n, k)` | multiplicative form, every intermediate division exact |
| `catalan(n)` | `binomial(2n, n) div (n + 1)` |
| `primorial(n)` | product of all primes up to `n`, odd sieve plus balanced multiplication |

## BigDecimal

Arbitrary precision decimal floats on the same integer core: a value is a `BigInt` mantissa times a power of ten, kept canonical (no trailing zero digits). `0.1` is exactly `0.1`, money maths never drifts, and the mantissa gets the full speed of the integer engine.

- `+ - *` are always exact, and so are `div`/`mod` (integer quotient, exact remainder).
- `/` rounds to 18 fractional digits by default; `divide(b, precision)` chooses. The quotient always keeps the full integer part and at least `precision` significant digits, and carries one hidden guard digit that `toString` rounds away, so `(1/3) * 3` prints as `1`. Exact quotients stay exact: `1 / 8` is `0.125`.
- Comparisons are numeric (`0.5 = 5E-1`) and see the stored guard digit, so `(1/3) * 3 < 1` holds even though it prints as `1`.
- Mixed expressions with integers, strings, `BigInt` and `UBigInt` convert implicitly; floats convert only through explicit casts or the `from*` builders, so no binary rounding error sneaks in unannounced.

```pascal
program decimals;

{$mode unleashed}

uses BigInts;

begin
  var price: BigDecimal := '19.99';
  writeln($'{price * 3}');                       // 59.97
  writeln($'{BigDecimal(1) / 3}');               // 0.333333333333333333
  writeln($'{BigDecimal(1) / 3 * 3}');           // 1
  writeln($'{BigDecimal(2).sqrt(30)}');          // 1.41421356237309504880168872421
  writeln($'{BigDecimal.fromDouble(0.1)}');      // 0.1
  writeln($'{BigDecimal.fromDoubleExact(0.1)}'); // 0.1000000000000000055511151231257827021181583404541015625
  var pi: BigDecimal := '3.14159265';
  writeln($'{pi.rounded(-2)}  {pi.rounded(-2, bdrCeil)}  {pi.trunc}'); // 3.14  3.15  3
  writeln($'{BigDecimal('123456.789').toScientific}');                // 1.23456789E5
  {$ifdef WINDOWS}readln;{$endif}
end.
```

The analytic layer runs on the same scaled-integer core: every function takes a `precision` argument (fractional digits, default 18) and rounds its last shown digit through the hidden guard, like divide does. `pi` comes from Chudnovsky binary splitting and is cached, huge trigonometric arguments are reduced with pi carried at a matching precision.

```pascal
program analytic;

{$mode unleashed}

uses BigInts;

begin
  writeln($'{BigDecimal.pi(50)}');    // 3.14159265358979323846264338327950288419716939937511
  writeln($'{BigDecimal(2).ln(40)}'); // 0.6931471805599453094172321214581765680755
  writeln($'{BigDecimal(2) ** BigDecimal('0.5')}');  // 1.414213562373095049
  writeln($'{BigDecimal(1).sin(40)}');               // 0.8414709848078965066525023216302989996226
  writeln($'{BigDecimal('1E6').logBase(BigDecimal(10))}');           // 6
  writeln($'{BigDecimal('19.99').quantize(BigDecimal('0.05'))}');    // 20
  var (num, den) := BigDecimal('0.375').toFraction;
  writeln($'{num}/{den}');                           // 3/8
  writeln(BigDecimal('0.000123').toEngineering);     // 123E-6
  {$ifdef WINDOWS}readln;{$endif}
end.
```

| method | notes |
|---|---|
| `parse(s)`, `tryParse(s, out v)`, `:=` from string | `[sign]digits[.digits][E[sign]digits]`, `_` separators allowed |
| `toString`, `toScientific`, `toEngineering` | plain `-123.45` / normalized `-1.2345E2` / exponent a multiple of three, `123E-6` |
| `toInt64`, `toQWord`, `toInteger`, `toCardinal`, `toBigInt`, `fitsIn*` | exact conversions: raise `ERangeError` unless integral and in range |
| `trunc`, `floor`, `ceil`, `round` | to `BigInt`: toward zero, toward -inf, toward +inf, halves to even (like Pascal `round`) |
| `frac` | what `trunc` drops, so `self = trunc + frac` |
| `toFraction` | exact rational view as a `(num, den)` tuple: `0.375` gives `(3, 8)` |
| `rounded(toDigit = 0, mode = bdrRound)` | rounding at any decimal position: `0` = integer, `-2` = cents, `3` = thousands; modes `bdrTrunc bdrCeil bdrFloor bdrRound bdrHalfUp bdrHalfEven` |
| `quantize(step, mode = bdrRound)` | round to the nearest multiple of any step, e.g. `0.05` |
| `divide(b, precision = 18)`, `divMod(d)` | division at a chosen precision / integer quotient with the exact remainder |
| `fromDouble`, `fromSingle`, explicit float casts | the shortest decimal that reads back to the same float: `0.1` gives `0.1` |
| `fromDoubleExact`, `fromSingleExact` | the exact binary value: `0.1` gives all 55 digits of it |
| `toDouble`, `toSingle` | correctly rounded to the nearest float, ties to even; overflow gives infinity, underflow zero |
| `toExtended`, `fromExtended`, `fromExtendedExact` | on targets with the 80-bit type |
| `sqrt(precision = 18)`, `nthRoot(n, precision = 18)` | `precision` fractional digits with the same hidden guard digit as divide |
| `pow(e)` | exact for an integer `e >= 0`; a negative exponent divides at the default precision |
| `pow(y, precision = 18)`, `**` | fractional exponents through `exp(y * ln x)` |
| `exp`, `ln`, `log2`, `log10`, `logBase(b)` | all take `(precision = 18)`; `log10` is exact for powers of ten, `log2` for powers of two |
| `sin`, `cos`, `tan`, `arcsin`, `arccos`, `arctan` | radians; big arguments reduce modulo pi/2 at a matching precision |
| `sinh`, `cosh`, `tanh` | hyperbolics over the same exponential core |
| `pi(precision)`, `e(precision)` | class functions; pi is cached between calls |
| `gcd`, `lcm` | on the decimal lattice: `gcd(0.25, 0.15) = 0.05` |
| `precision`, `mostSignificantExponent`, `getDigit(i)` | significant digit count, exponent of the leading digit, digit at `10^i` |
| `shift10(n)`, `shifted10(n)` | multiply by a power of ten without touching the mantissa |
| `isZero`, `isOne`, `isIntegral`, `isEven`, `isOdd`, `isNegative`, `isPositive`, `sign`, `abs`, `negate` | predicates and sign helpers; a fractional value is neither even nor odd |
| `compare`, `equals`, `approxEquals(other, eps)`, `min`, `max`, `hashCode`, `swap` | plus the full operator and comparison set |
| `zero`, `one`, `two`, `ten` | class constants |

## Semantics worth knowing

- `div`/`mod` truncate like Pascal; `floorDiv`/`floorMod` round like Python; `ceilDiv` rounds up.
- `/` is integer division, same as `div` (C-family convention for integer types).
- `shr` on a negative `BigInt` is an arithmetic shift (rounds toward minus infinity); `shl` keeps the sign.
- Bitwise ops on negative `BigInt` values use two's complement with infinite sign extension; `not x = -x-1`.
- Formatting of negatives is sign-magnitude in every base: `-255` prints as `-FF` in hex.
- Values are copy-on-write: assignment shares storage and is cheap, mutating methods un-share first, so no variable ever changes behind another one's back.
- `0 ** 0 = 1`, division by zero raises `EDivByZero`, conversions that do not fit raise `ERangeError`, parse errors raise `EConvertError`, domain errors (negative exponent, no inverse, non-residue) raise `EBigIntError`.

## Performance

64-bit limbs with assembler inner loops on x86_64 (mul/adc row primitives, plus a mulx/adcx/adox `addmul_1` picked at runtime when the CPU has ADX); portable 32-bit Pascal limbs everywhere else. The assembler sits behind a `USEASM` define at the top of the unit - comment it out for a fully portable pure Pascal build (roughly 4-8x slower on x64 in the core operations). Knuth algorithm D division, Karatsuba then Toom-3 multiplication and squaring above tunable thresholds (`BigIntKaratsubaThreshold`, `BigIntToom3Threshold`), Montgomery modPow with a windowed exponent, divide-and-conquer base conversion, Lehmer gcd, exact-size result buffers built directly on the heap in the hot paths. On a desktop x64: `factorial(50000)` in ~16 ms, `fibonacci(1000000)` in ~16 ms.

### Benchmarks vs GMP

Measured against GMP 6.2.1 (the 64-bit-limb `libgmp-10.dll` that ships with Git for Windows) on one x64 desktop, both sides `-O3`, time per operation. The GMP side reuses its mpz targets, which is how GMP code is normally written; the BigInts side allocates a fresh value per operation, which is what value semantics cost.

| operation | BigInts | GMP | ratio |
|---|---|---|---|
| add 128b | 32 ns | 5 ns | 6.2x |
| add 1024b | 46 ns | 9 ns | 5.3x |
| add 16384b | 176 ns | 65 ns | 2.7x |
| add 262144b | 1.91 us | 1.28 us | 1.5x |
| mul 128b | 39 ns | 6 ns | 6.4x |
| mul 1024b | 189 ns | 129 ns | 1.5x |
| mul 8192b | 6.3 us | 4.2 us | 1.5x |
| mul 65536b | 196 us | 82 us | 2.4x |
| mul 262144b | 1.57 ms | 547 us | 2.9x |
| mul 65536x1024b | 7.1 us | 8.5 us | 0.8x |
| sqr 8192b | 5.4 us | 2.6 us | 2.1x |
| sqr 65536b | 159 us | 56 us | 2.9x |
| divmod 2048/1024b | 521 ns | 265 ns | 2.0x |
| divmod 8192/4096b | 4.4 us | 2.5 us | 1.7x |
| divmod 131072/65536b | 929 us | 202 us | 4.6x |
| toString 4096b | 11.0 us | 3.9 us | 2.8x |
| toString 65536b | 683 us | 211 us | 3.2x |
| parse 4096b | 9.2 us | 3.7 us | 2.5x |
| parse 65536b | 344 us | 129 us | 2.7x |
| modPow 512b | 82 us | 40 us | 2.0x |
| modPow 1024b | 472 us | 264 us | 1.8x |
| modPow 2048b | 2.7 ms | 2.0 ms | 1.4x |
| gcd 1024b | 11.3 us | 2.7 us | 4.1x |
| gcd 16384b | 435 us | 119 us | 3.7x |

Bulk arithmetic lands at 1.4-4x of GMP. The remaining gap is GMP's hand-scheduled assembly, its higher Toom orders and FFT on huge operands, and sub-quadratic gcd and division that this unit does not implement. Tiny one/two-limb values compare at ~6x because a 30-40 ns operation is mostly allocation on the BigInts side; in absolute terms it is still tens of nanoseconds.

## Examples

Each block below is a complete program: copy it into a `.lpr`, drop `bigints.pas` next to it, and it compiles and runs as is.

### Literals and formatting

```pascal
program literals;

{$mode unleashed}

uses BigInts;

begin
  var a: UBigInt := '123_456_789_000_000_000_000_000';
  var b: BigInt := '-0xDEAD_BEEF';
  var c: UBigInt := '%1010_1010';
  writeln(a.toStringGrouped);                // 123_456_789_000_000_000_000_000
  writeln(b.toString);                       // -3735928559
  writeln(c.toString(36));                   // 4Q
  writeln(UBigInt.parse('zz', 36).toString); // 1295
  {$ifdef WINDOWS}readln;{$endif}
end.
```

### Division flavours

```pascal
program division;

{$mode unleashed}

uses BigInts;

begin
  var (q, r) := BigInt(-7).divMod(BigInt(2));
  writeln($'{q} {r}');                              // -3 -1 (truncated, like Pascal div/mod)
  writeln(BigInt(-7).floorDiv(2).toString);         // -4 (like Python)
  writeln(BigInt(-7).floorMod(2).toString);         // 1
  writeln(UBigInt(7).ceilDiv(UBigInt(2)).toString); // 4
  {$ifdef WINDOWS}readln;{$endif}
end.
```

### Two's complement bitwise

```pascal
program bitwise;

{$mode unleashed}

uses BigInts;

begin
  writeln((BigInt(-1) and BigInt($FF)).toString); // 255: -1 is an infinite run of ones
  writeln((not BigInt(0)).toString);              // -1
  writeln((BigInt(-5) shr 1).toString);           // -3: arithmetic shift
  writeln(BigInt(-255).toHex);                    // -FF: sign plus magnitude in every base
  {$ifdef WINDOWS}readln;{$endif}
end.
```

### Primes and a toy RSA

```pascal
program rsa;

{$mode unleashed}

uses BigInts;

begin
  BigIntRandomize;
  var p := UBigInt.randomPrime(512);
  var q := UBigInt.randomPrime(512);
  var n := p * q;
  var e: UBigInt := 65537;
  var d := e.modInverse((p - 1) * (q - 1));
  var msg: UBigInt := '0x48656C6C6F21';    // "Hello!"
  var cipher := msg.modPow(e, n);
  writeln(cipher.modPow(d, n) = msg);      // TRUE
  {$ifdef WINDOWS}readln;{$endif}
end.
```

### The random suite

```pascal
program random_suite;

{$mode unleashed}

uses BigInts;

begin
  BigIntRngAlgo := rngPcg64;
  BigIntRandomSeed(42);                    // reproducible from here on
  writeln(UBigInt.random(128).toHex);      // F6A4492CA8314B92F0D3403191F1E9AF
  writeln(UBigInt.randomBelow(UBigInt.ten ** 20).toString);
  writeln(BigInt.randomRange(-50, 50).toString);
  {$ifdef WINDOWS}readln;{$endif}
end.
```

### Factorization

```pascal
program factor;

{$mode unleashed}

uses BigInts;

begin
  var n: UBigInt := '123456789012345678';
  for var (p, e) in n.factorize do
    write($'{p}^{e} ');                    // 2^1 3^3 21491747^1 106377431^1
  writeln;
  {$ifdef WINDOWS}readln;{$endif}
end.
```

### Chinese remainder theorem

```pascal
program crt_demo;

{$mode unleashed}

uses BigInts;

begin
  // x = 2 (mod 3), x = 3 (mod 5), x = 2 (mod 7)
  var x := BigInt.crt([BigInt(2), BigInt(3), BigInt(2)], [BigInt(3), BigInt(5), BigInt(7)]);
  writeln(x.toString);                     // 23
  {$ifdef WINDOWS}readln;{$endif}
end.
```

## License

This project is licensed under the Mozilla Public License 2.0 (MPL-2.0). See the LICENSE file for details.
