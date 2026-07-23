# BigInts

Arbitrary precision integers, decimals and rationals for Pascal in a single self-contained unit, `BigInts` ([bigints.pas](bigints.pas)). Four value types, every operator a plain number has, no size limits beyond available memory, no dependencies beyond the RTL.

> **Requires a compiler that understands `{$mode unleashed}`.** The unit and the examples below lean on inline variables, tuples, statement expressions and interpolated strings, so a stock compiler will not build them.

| type | what it is |
|---|---|
| `BigInt` | signed; bitwise operators use two's complement semantics with infinite sign extension, like Python ints |
| `UBigInt` | unsigned; anything that would drop below zero raises `ERangeError` |
| `BigDecimal` | decimal float: a `BigInt` mantissa times a power of ten; exact `+ - *`, division at a chosen precision |
| `BigRational` | exact fraction: a normalized `num`/`den` pair of `BigInt`s (`den > 0`, `gcd = 1`); `1/3` stays `1/3` and never rounds |

## Capabilities

- full operator coverage: `+ - * div mod / ** shl shr and or xor not`, all comparisons, `inc`/`dec`, compound assignments (`+=`, `*=`, ...), unary `+`/`-`
- mixed expressions with plain integers on either side, implicit conversions from `Int64`/`QWord`/string, explicit casts in both directions (`Double` included; integer casts never round through floating point)
- literals of any size with `_` separators and `$ 0x % 0b & 0o` prefixes; parsing and formatting in every base 2..36
- multiplication: schoolbook, Karatsuba, Toom-3, Toom-4 and an exact number-theoretic transform, picked by tunable thresholds, with dedicated squaring paths
- division: Knuth algorithm D, then recursive Burnikel-Ziegler at multiply speed for large operands, plus divide-and-conquer base conversion for long numbers
- modular arithmetic: Montgomery `modPow` (plus reusable `TModRing` / constant-time `TModRingSec` contexts), `modInverse`, `modSqrt` (Tonelli-Shanks), `sqrtModN`, `nthRootMod`, `crt`, `discreteLog`, `multiplicativeOrder`, `primitiveRoot`/`isPrimitiveRoot`, `binomialMod`, `lucasSequence`
- primes: Miller-Rabin `isProbablePrime` (deterministic below 3.3e24), Baillie-PSW `isPrime`, `nextPrime`/`prevPrime`, `randomPrime`/`randomSafePrime`/`randomStrongPrime`, exact `primePi`/`primeCount`
- factorization: trial division plus Pollard-Brent rho, exponents grouped into `(p, e)` tuples; the multiplicative functions `eulerPhi`, `carmichaelLambda`, `moebius`, `sigma`, `tau`, `divisors`, `radical` follow from it
- number theory and combinatorics: Lehmer `gcd`, `gcdExt`, `jacobi`, `kronecker`, `continuedFraction`, and `factorial`, `fibonacci`, `lucas`, `binomial`, `multinomial`, `catalan`, `bell`, `stirling1`/`stirling2`, `bernoulli`, `partitions`, `subfactorial`, `primorial`
- randomness: pluggable generators (xoshiro256**, PCG64, splitmix64, `System.Random`, OS entropy), deterministic seeding, uniform `randomBelow`/`randomRange`
- constant-time and secure: side-channel-resistant `equalsCT`/`compareCT`, `secureClear` to wipe a value, and `randomSecure`/`randomSecureBelow`/`randomSecureRange`/`randomSecurePrime` drawing straight from OS entropy with no seedable generator in between
- interop: byte serialization in both endiannesses, `hashCode`, digit-grouped output
- decimals: exact decimal arithmetic (`0.1 + 0.2 = 0.3`), division and roots at any precision, six rounding modes, shortest and exact float conversions in both directions, and the whole analytic toolbox - `pi`, `exp`, `ln`, `log2`/`log10`/`logBase`, fractional powers, trigonometry, hyperbolics, `gamma`, `erf`, `atan2`, `hypot`, `agm` at any precision (the BigDecimal chapter below)
- speed: measured 1.3-4.9x of GMP on x64 for the core operations (benchmarks below); assembler inner loops with a pure Pascal fallback behind a `USEASM` define

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
| `toInt8`, `toUInt8`, `toInt16`, `toUInt16`, `toInt32`, `toUInt32`, `toInt64`, `toUInt64`, `toDouble` | raise `ERangeError` when the value does not fit |
| `toInt128`, `toUInt128` | on targets whose compiler provides the native 128-bit type |
| `fitsInInt8`, `fitsInUInt8`, ... `fitsInInt64`, `fitsInUInt64` (and `fitsInInt128`/`fitsInUInt128` where available) | the matching checks for every native width |
| `toUBigInt` / `toBigInt` | cross the signedness bridge; a negative value raises `ERangeError` |
| `toDecimal` | widen to `BigDecimal` (exact, never rounds) |
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
| `sqr`, `sqrt`, `nthRoot(n)`, `nthRootRem(n)` | squaring and integer (floor) roots; `nthRootRem` also returns the remainder |
| `isKthPower(k)` | whether the value is an exact `k`-th power |
| `pow(e)`, `**` | plain powers |
| `modPow(e, m)` | Montgomery with a windowed exponent for odd `m`; on `BigInt` the modulus must be positive, the result lands in `0..m-1` and a negative exponent goes through the modular inverse |
| `modInverse(m)` | raises `EBigIntError` when no inverse exists |
| `gcd`, `lcm` | Lehmer gcd |
| `isProbablePrime(rounds = 24)` | Miller-Rabin; deterministic witnesses below 3.3e24, random rounds above |
| `isPrime` | Baillie-PSW (deterministic small-range test, then strong base-2 Miller-Rabin plus a strong Lucas test); no known counterexample |
| `nextPrime` | first prime above self |

### Modular rings: `TModRing` vs `TModRingSec`

`TModRing` is the fast, general-purpose Montgomery context: variable-time, windowed `modPow`, `mul`/`sqr`/`add`/`sub`/`pow`/`inv`/`reduce`. Use it for public data - primality, number theory, RSA verify with a public exponent, any modular math where the operands are not secret.

`TModRingSec` is the hardened counterpart and the unit's only constant-time *arithmetic* surface (the plain `UBigInt`/`BigInt` types add constant-time comparison through `equalsCT`/`compareCT` and wiping through `secureClear`, but their arithmetic stays variable-time). The modulus width is fixed at `create`: every value is padded to that width and no operation normalizes, branches on operand values, or exits early, so the running time and the memory-access pattern depend only on the ring width, not on the secret data. It offers `modPow` (Montgomery ladder with `cswap`), `mul`/`sqr`/`addMod`/`subMod`/`negMod`, and the constant-time primitives `select`/`cswap`/`equalCT`/`isZeroCT`. Reach for it only when a secret drives the computation (RSA sign/decrypt, a private DH exponent); it runs several times slower than `TModRing`, which is the price of the guarantee. Operands import through a fixed masked-copy loop, the exponent is scanned as `bitWidth` bits wide, and internal scratch buffers are wiped before release. Remaining boundary caveats: reducing an unreduced base on entry is variable-time, and results come back as normalized `UBigInt`s whose representation length is that of the value itself - keep secrets reduced and `secureClear` values you drop.

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
| `randomSafePrime(bits)` | a safe prime `p` where `(p-1)/2` is also prime |
| `randomStrongPrime(bits)` | Gordon's algorithm: `p-1` and `p+1` each carry a large prime factor |
| `randomSecure(bits)`, `randomSecureBelow(bound)`, `randomSecureRange(lo, hi)` | uniform draws taken straight from OS entropy, no seedable generator in between |
| `randomSecurePrime(bits, rounds = 24)` | like `randomPrime`, but from OS entropy |

The backend behind `random` and friends is selected with the `BigIntRngAlgo` variable:

| generator | notes |
|---|---|
| `rngXoshiro256ss` | default; xoshiro256** |
| `rngPcg64` | PCG XSL-RR 128/64 with the reference multiplier and stream |
| `rngSplitMix64` | tiny and fast; also used internally to expand seeds |
| `rngSystem` | the historical `RandSeed`-driven `System.Random` stream |
| `rngOS` | fresh OS entropy on every call (RtlGenRandom, /dev/urandom); pick this for key material |

The generator state is per-thread (`threadvar`): the first random draw in a thread seeds itself from OS entropy, so unseeded values differ every run and threads have independent streams - no shared state, no lock. `BigIntRandomSeed(seed)` makes the calling thread reproducible (it also sets `RandSeed`, so the `rngSystem` mode follows along); `BigIntRandomize` reseeds it from OS entropy. Seed each thread separately if you need reproducibility across threads. The `rngSystem` mode keeps the plain `System.Random` contract (driven by `RandSeed`, which the lazy auto-seed leaves untouched).

### Number theory

| method | notes |
|---|---|
| `gcdExt(other)` | `BigInt` only; extended Euclid returning the `(g, x, y)` tuple with `a*x + b*y = g` |
| `jacobi(n)` | Jacobi symbol for an odd positive `n`, returns -1, 0 or 1 |
| `kronecker(n)` | Kronecker symbol, the full extension of Jacobi to any integers (handles the factor 2 and negative arguments) |
| `modSqrt(p)` | square root modulo a prime (Tonelli-Shanks); raises `EBigIntError` for a non-residue |
| `sqrtModN(n)` | every square root modulo a composite `n` (factor, lift, CRT); needs `gcd(self, n) = 1`, empty array for a non-residue |
| `discreteLog(target, m)` | baby-step giant-step: least `x` with `self^x = target (mod m)`, or -1; `Int64`, for small instances |
| `nthRootMod(k, p)` | a `k`-th root modulo an odd prime `p` (Adleman-Manders-Miller) |
| `multiplicativeOrder(m)` | least `k > 0` with `self^k = 1 (mod m)`; needs `gcd(self, m) = 1` |
| `primitiveRoot`, `isPrimitiveRoot(m)` | a generator of the group modulo self / whether `self` generates modulo `m` |
| `binomialMod(n, k, p)` | class function; `C(n, k) mod p` for prime `p` via the Lucas theorem |
| `lucasSequence(p, q, n, m)` | class function; Lucas sequences `U_n`, `V_n` mod `m` by index doubling, returns a `(u, v)` tuple |
| `crt(remainders, moduli)` | `BigInt` class function; Chinese remainder theorem for pairwise coprime positive moduli |
| `isPerfectSquare` | quick mod-16 filter, then an exact root check |
| `sqrtRem` | returns the `(root, rem)` tuple with `self = root^2 + rem` |
| `prevPrime` | largest prime below self; raises for `self <= 2` |
| `factorize` | array of `(p, e)` tuples in ascending prime order; trial division below 10^4, Pollard-Brent rho above; `BigInt.factorize` factors the absolute value |

`factorize` runtime grows with the square root of the second-largest prime factor, so a product of two large random primes will grind for a very long time - that is the nature of factoring, not a bug.

These read straight off the factorization (so they cost what `factorize` costs):

| method | notes |
|---|---|
| `eulerPhi` | Euler totient, the count of integers up to `n` coprime to it |
| `carmichaelLambda` | the group exponent: the least `k` with `a^k = 1 (mod n)` for every coprime `a` |
| `moebius` | Moebius function, returns -1, 0 or 1 |
| `sigma(k = 1)` | sum of the `k`-th powers of the divisors; `sigma(0)` is `tau` |
| `tau` | number of divisors |
| `radical` | product of the distinct prime factors |
| `divisors` | every divisor in ascending order |
| `isSquarefree`, `isPerfect`, `isCarmichael` | the matching predicates |

Prime counting and rational approximation (`BigInt`/`UBigInt` class functions):

| method | notes |
|---|---|
| `primePi(n)` | exact number of primes `<= n` by a segmented sieve (`QWord`, practical to ~1e10) |
| `primeCount(lo, hi)` | exact number of primes in `lo..hi` |
| `continuedFraction(num, den)` | the coefficients of the continued fraction of `num/den` |
| `fromContinuedFraction(cf)` | evaluate coefficients back to a reduced `(num, den)`; slice `cf` for convergents |

### Combinatorics

All class functions.

| method | notes |
|---|---|
| `lucas(n)` | companion sequence to Fibonacci, one fast-doubling run |
| `binomial(n, k)` | multiplicative form, every intermediate division exact |
| `multinomial(ks)` | `(sum ks)! / prod(ks[i]!)`, as a product of binomials |
| `catalan(n)` | `binomial(2n, n) div (n + 1)` |
| `primorial(n)` | product of all primes up to `n`, odd sieve plus balanced multiplication |
| `risingFactorial(x, n)`, `fallingFactorial(x, n)` | Pochhammer symbols; `BigInt` accepts a negative base |
| `subfactorial(n)` | derangement count `!n` |
| `bell(n)` | Bell number, via the Bell triangle |
| `stirling1(n, k)` | signed Stirling number of the first kind (`BigInt`) |
| `stirling2(n, k)` | Stirling number of the second kind |
| `partitions(n)` | integer partition count `p(n)`, Euler pentagonal recurrence |
| `bernoulli(n)` | `BigInt` class function; the Bernoulli number as an exact reduced `(num, den)` fraction |

### Roman numerals and words

`BigInt` and `UBigInt` also format themselves for humans:

| method | notes |
|---|---|
| `toRoman` | Roman numerals for a value in `1..3999` |
| `toWords` | English short-scale words (`one million two hundred thirty-four thousand ...`), up to `10^66` |

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
| `calc(s, precision = 18)`, `tryCalc(s, out v, precision = 18)` | evaluate a whole expression string, see the calculator section below |
| `toString`, `toScientific`, `toEngineering` | plain `-123.45` / normalized `-1.2345E2` / exponent a multiple of three, `123E-6` |
| `toInt8`..`toInt64`, `toUInt8`..`toUInt64`, `toBigInt`, `toUBigInt`, `fitsInInt8`..`fitsInUInt64` | exact conversions: raise `ERangeError` unless integral and in range (`toUInt*`/`toUBigInt` also on a negative value) |
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
| `sinh`, `cosh`, `tanh`, `arcsinh`, `arccosh`, `arctanh` | hyperbolics over the same exponential core; the inverses compose `ln` and `sqrt` (`arccosh` needs `x >= 1`, `arctanh` needs `-1 < x < 1`) |
| `gamma`, `lnGamma` | the gamma function (reflection covers negatives) and its logarithm (positive argument) |
| `factorial` | the real factorial `x! = gamma(x+1)`, exact for small non-negative integers |
| `erf`, `erfc` | the error function and its complement; `erfc` uses a continued fraction for large arguments |
| `continuedFraction(maxTerms = 0)` | the (finite, exact) continued fraction of the value; great for best rational approximations |
| `roundToSignificant(digits, mode = bdrRound)` | round to a count of significant digits rather than a decimal position |
| `pi(precision)`, `e(precision)` | class functions; pi is cached between calls |
| `atan2(y, x, precision)`, `hypot(x, y, precision)`, `agm(a, b, precision)` | class functions: quadrant-aware arctangent, Euclidean length, arithmetic-geometric mean |
| `gcd`, `lcm` | on the decimal lattice: `gcd(0.25, 0.15) = 0.05` |
| `precision`, `mostSignificantExponent`, `getDigit(i)` | significant digit count, exponent of the leading digit, digit at `10^i` |
| `shift10(n)`, `shifted10(n)` | multiply by a power of ten without touching the mantissa |
| `isZero`, `isOne`, `isIntegral`, `isEven`, `isOdd`, `isNegative`, `isPositive`, `sign`, `abs`, `negate` | predicates and sign helpers; a fractional value is neither even nor odd |
| `compare`, `equals`, `approxEquals(other, eps)`, `min`, `max`, `hashCode`, `swap` | plus the full operator and comparison set |
| `zero`, `one`, `two`, `ten` | class constants |

### The calculator

`calc` evaluates a whole expression from a string, at whatever precision you pass, and returns a `BigDecimal`. It is a pure, stateless evaluator: no variables, no assignment, the same string always gives the same result. `tryCalc` returns `false` on a bad expression instead of raising; `calc` raises `EConvertError` with the character position on a syntax error, and lets math errors (`EDivByZero`, `ERangeError`, `EBigIntError`) through unchanged.

```pascal
writeln(BigDecimal.calc('2^100 / 3').toScientific);   // 4.2...E29
writeln(BigDecimal.calc('sin(pi/6)', 30));            // 0.5
writeln(BigDecimal.calc('(1 + sqrt(5)) / 2', 50));    // the golden ratio, 50 digits
```

Operators, from lowest precedence to highest:

| operator | meaning | notes |
|---|---|---|
| `+` `-` | add, subtract | left associative |
| `*` `/` `div` `mod` `%` | multiply, real division, integer division, remainder | `/` gives `2.5` for `10/4`; `div` gives `2`; `%` is `mod` |
| `-` `+` (unary) | sign | binds below power, so `-2^2 = -4` |
| `^` `**` | power | right associative, `2^3^2 = 512`; `2^-3 = 0.125` |
| `!` (postfix) | factorial | on a non-negative integer |

Functions (names are case-insensitive):

| group | functions |
|---|---|
| roots and powers | `sqrt(x)` `cbrt(x)` `root(x, n)` `pow(x, y)` `sqr(x)` |
| exp and logs | `exp(x)` `ln(x)` `log(x)`=log10, `log(x, b)`=base b, `log2(x)` `log10(x)` `logb(x, b)` |
| trigonometry | `sin cos tan (x)`, `asin acos atan (x)` (also `arcsin`/`arccos`/`arctan`), `sinh cosh tanh (x)`, `asinh acosh atanh (x)` (also `arcsinh`/`arccosh`/`arctanh`) |
| rounding and parts | `floor(x)` `ceil(x)` `round(x)` `trunc(x)` `frac(x)` `abs(x)` `sign(x)` |
| special | `gamma(x)` `lngamma(x)` `erf(x)` `erfc(x)` `factorial(x)` |
| two-argument | `min max gcd lcm atan2 hypot agm (a, b)` |
| constants | `pi` `e` `tau` `phi` |

Every function maps to the method of the same name at the working precision, so `calc('sin(1)', 40)` equals `BigDecimal(1).sin(40)`. Only functions that take numbers and return one number are exposed; the integer number-theory and the tuple-returning methods stay on the API.

## BigRational

Exact fractions on the same integer core: a `BigInt` numerator over a `BigInt` denominator, always normalized (`den > 0`, `gcd(num, den) = 1`). Nothing ever rounds - `1/3 + 1/3 + 1/3` is exactly `1`.

```pascal
program rationals;

{$mode unleashed}

uses BigInts;

begin
  var a: BigRational := '1/3';
  var b := BigRational.create(1, 6);
  writeln($'{a + b}');                          // 1/2
  writeln($'{a} + {a} + {a} = {a + a + a}');    // 1/3 + 1/3 + 1/3 = 1
  writeln($'{a.reciprocal}');                   // 3
  var pi := BigRational.parse('3.14159265');
  writeln($'{pi.limitDenominator(113)}');       // 355/113 - best fraction with denominator <= 113
  {$ifdef WINDOWS}readln;{$endif}
end.
```

| method | notes |
|---|---|
| `create(num, den)`, `parse(s)`, `tryParse(s, out v)`, `:=` from `Int64`/string/`BigInt`/`UBigInt` | `parse` accepts `'a/b'`, integers, decimals and exponents (`'1.25'`, `'2e10'`) |
| `num`, `den` | the two components; `den` is always positive |
| `+ - * / **`, all comparisons, unary `-` | full operator set; `**` takes an `Int64` exponent |
| `abs`, `negate`, `reciprocal`, `sign`, `frac` | `frac` is the fractional part, so `self = trunc + frac` |
| `trunc`, `floor`, `ceil`, `round` | to `BigInt`: toward zero / down / up / nearest |
| `isZero`, `isOne`, `isInteger`, `isNegative`, `isPositive` | predicates |
| `toString`, `toDouble`, `toDecimal(precision = 18)` | `'num/den'` (or just `num` when integral); exact widen to `BigDecimal` |
| `compare`, `equals`, `min`, `max`, `hashCode`, `swap` | |
| `continuedFraction`, `fromContinuedFraction(cf)`, `limitDenominator(maxDen)` | continued-fraction view and the tightest fraction within a denominator bound (best rational approximation via convergents) |
| `zero`, `one` | class constants |

## Semantics worth knowing

- `div`/`mod` truncate like Pascal; `floorDiv`/`floorMod` round like Python; `ceilDiv` rounds up.
- `/` is integer division, same as `div` (C-family convention for integer types).
- `shr` on a negative `BigInt` is an arithmetic shift (rounds toward minus infinity); `shl` keeps the sign.
- Bitwise ops on negative `BigInt` values use two's complement with infinite sign extension; `not x = -x-1`.
- Formatting of negatives is sign-magnitude in every base: `-255` prints as `-FF` in hex.
- Values are cheap to copy: small values (up to 256 bits) sit inline in the value, larger ones share a refcounted block that mutating methods un-share first, so no variable ever changes behind another one's back.
- `0 ** 0 = 1`, division by zero raises `EDivByZero`, conversions that do not fit raise `ERangeError`, parse errors raise `EConvertError`, domain errors (negative exponent, no inverse, non-residue) raise `EBigIntError`.

## Performance

64-bit limbs with assembler inner loops on x86_64 (mul/adc row primitives, plus a mulx/adcx/adox `addmul_1` picked at runtime when the CPU has ADX); 32-bit limbs with their own assembler row primitives on i386; portable Pascal limbs everywhere else. The assembler sits behind a `USEASM` define at the top of the unit - comment it out for a fully portable pure Pascal build (roughly 4-8x slower on x64 in the core operations). Knuth algorithm D division, Karatsuba then Toom-3 multiplication and squaring above tunable thresholds (`BigIntKaratsubaThreshold`, `BigIntToom3Threshold`), Montgomery modPow with a windowed exponent, divide-and-conquer base conversion, Lehmer gcd. Values up to 256 bits (`BIGINT_INLINE_LIMBS` limbs) live inline in the value with no heap allocation; larger results build exact-size heap buffers directly in the hot paths. On a desktop x64: `factorial(50000)` in ~12 ms, `fibonacci(1000000)` in ~10 ms.

### Benchmarks vs GMP

Measured against GMP 6.3.0 (64-bit limbs) on one x64 desktop, both sides `-O3`, time per operation. The GMP side reuses its mpz targets, which is how GMP code is normally written; the BigInts side allocates a fresh value per operation, which is what value semantics cost.

| operation | BigInts | GMP | ratio |
|---|---|---|---|
| add 128b | 0.016 us | 0.005 us | 2.9x |
| add 1024b | 0.037 us | 0.008 us | 4.9x |
| add 16384b | 0.153 us | 0.067 us | 2.3x |
| add 262144b | 1.72 us | 1.26 us | 1.4x |
| sub 128b | 0.018 us | 0.006 us | 3.0x |
| sub 1024b | 0.038 us | 0.008 us | 4.5x |
| sub 16384b | 0.151 us | 0.062 us | 2.4x |
| sub 262144b | 1.65 us | 1.30 us | 1.3x |
| mul 128b | 0.020 us | 0.006 us | 3.2x |
| mul 1024b | 0.187 us | 0.132 us | 1.4x |
| mul 8192b | 6.28 us | 4.18 us | 1.5x |
| mul 65536b | 184 us | 84.2 us | 2.2x |
| mul 65536x1024b | 7.06 us | 8.66 us | 0.8x |
| div 2048/1024b | 0.370 us | 0.207 us | 1.8x |
| div 8192/4096b | 3.49 us | 1.69 us | 2.1x |
| div 131072/65536b | 717 us | 176 us | 4.1x |
| sqr 8192b | 5.52 us | 2.59 us | 2.1x |
| sqr 65536b | 169 us | 56.1 us | 3.0x |
| divmod 2048/1024b | 0.492 us | 0.298 us | 1.7x |
| divmod 8192/4096b | 3.57 us | 2.74 us | 1.3x |
| divmod 131072/65536b | 715 us | 207 us | 3.5x |
| toString 4096b | 9.11 us | 4.26 us | 2.1x |
| toString 65536b | 423 us | 225 us | 1.9x |
| parse 4096b | 5.91 us | 3.63 us | 1.6x |
| parse 65536b | 245 us | 138 us | 1.8x |
| modPow 512b | 80.8 us | 38.4 us | 2.1x |
| modPow 1024b | 435 us | 258 us | 1.7x |
| modPow 2048b | 2784 us | 1969 us | 1.4x |
| gcd 1024b | 11.0 us | 2.69 us | 4.1x |
| gcd 16384b | 421 us | 115 us | 3.7x |

`div` is quotient-only; `divmod` returns quotient and remainder. Bulk arithmetic lands at 1.3-4.9x of GMP. The remaining gap is GMP's hand-scheduled assembly, its higher Toom orders and FFT on huge operands, and sub-quadratic gcd and division that this unit does not implement. Small values up to 256 bits live inline with no allocation, so a one/two-limb add or multiply runs in ~15-20 ns and stays within ~3x of GMP even at that size, where a fresh-value-per-op library would otherwise be dominated by allocation.

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

### Primes and RSA

The public exponent runs on the fast `modPow`; the secret one goes through the constant-time `TModRingSec` so decrypt/sign timing does not leak the key.

```pascal
program rsa;

{$mode unleashed}

uses BigInts;

begin
  BigIntRandomize;
  var p := UBigInt.randomPrime(1024);
  var q := UBigInt.randomPrime(1024);
  var n := p * q;
  var e: UBigInt := 65537;
  var d := e.modInverse((p - 1).lcm(q - 1));
  var priv := TModRingSec.create(n);
  var msg: UBigInt := '0x48656C6C6F21';    // "Hello!"
  var cipher := msg.modPow(e, n);
  writeln(priv.modPow(cipher, d) = msg);   // TRUE
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

The example programs under `examples/` are free to use without restriction; copy from them into your own projects freely, with no MPL obligations.
