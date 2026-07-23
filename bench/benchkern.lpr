program benchkern;

{$mode unleashed}
{$asmmode intel}
{$codealign proc=64}

// standalone micro-bench of x64 limb-kernel variants: each candidate is a
// self-contained copy, correctness-checked against a plain reference before
// timing; results drive which variant lands in bigints.pas

uses Windows, SysUtils;

type
  TLimb = QWord;
  PLimb = ^TLimb;

// -- current bigints.pas kernels (copies) ----------------------

function MpnAddN1(rp, ap, bp: PLimb; n: SizeInt): TLimb; assembler; nostackframe;
asm
  xor eax, eax
  test r9, r9
  jz @done
@loop:
  mov r10, [rdx]
  adc r10, [r8]
  mov [rcx], r10
  lea rdx, [rdx + 8]
  lea r8, [r8 + 8]
  lea rcx, [rcx + 8]
  dec r9
  jnz @loop
  setc al
@done:
end;

function MpnAddMul1Gen(rp, ap: PLimb; n: SizeInt; b: TLimb): TLimb; assembler; nostackframe;
asm
  mov r10, rdx
  xor r11d, r11d
  test r8, r8
  jz @done
@loop:
  mov rax, [r10]
  mul r9
  add rax, r11
  adc rdx, 0
  add [rcx], rax
  adc rdx, 0
  mov r11, rdx
  lea r10, [r10 + 8]
  lea rcx, [rcx + 8]
  dec r8
  jnz @loop
@done:
  mov rax, r11
end;

function MpnAddMul1Adx2(rp, ap: PLimb; n: SizeInt; b: TLimb): TLimb; assembler; nostackframe;
asm
  mov r10, rdx
  mov rdx, r9
  mov r9, rcx
  mov rcx, r8
  mov r8, r9
  xor r11d, r11d
  shr rcx, 1
  jnc @even
  mulx r11, rax, [r10]
  add rax, [r8]
  adc r11, 0
  mov [r8], rax
  lea r10, [r10 + 8]
  lea r8, [r8 + 8]
@even:
  test al, al
  jrcxz @fold
  align 32
@loop:
  mulx r9, rax, [r10]
  adcx rax, r11
  adox rax, [r8]
  mov [r8], rax
  mulx r11, rax, [r10 + 8]
  adcx rax, r9
  adox rax, [r8 + 8]
  mov [r8 + 8], rax
  lea r10, [r10 + 16]
  lea r8, [r8 + 16]
  lea rcx, [rcx - 1]
  jrcxz @fold
  jmp @loop
@fold:
  mov rax, r11
  mov r9d, 0
  adcx rax, r9
  adox rax, r9
end;

// -- candidates ----------------------

// 4x unrolled adc chain; tail peeled after the quads with the carry live
function MpnAddN4(rp, ap, bp: PLimb; n: SizeInt): TLimb; assembler; nostackframe;
asm
  mov r10, r9
  shr r9, 2
  and r10d, 3
  xor eax, eax       // rax = 0, CF = 0
  test r9, r9
  jz @tail
  align 32
@q:
  mov r11, [rdx]
  adc r11, [r8]
  mov [rcx], r11
  mov r11, [rdx + 8]
  adc r11, [r8 + 8]
  mov [rcx + 8], r11
  mov r11, [rdx + 16]
  adc r11, [r8 + 16]
  mov [rcx + 16], r11
  mov r11, [rdx + 24]
  adc r11, [r8 + 24]
  mov [rcx + 24], r11
  lea rdx, [rdx + 32]
  lea r8, [r8 + 32]
  lea rcx, [rcx + 32]
  dec r9             // dec leaves CF alone
  jnz @q
@tail:
  dec r10
  js @fin
@t:
  mov r11, [rdx]
  adc r11, [r8]
  mov [rcx], r11
  lea rdx, [rdx + 8]
  lea r8, [r8 + 8]
  lea rcx, [rcx + 8]
  dec r10
  jns @t
@fin:
  setc al
end;

// 4x unrolled mulx/adcx/adox; low limbs peeled first so the carry limb seeds
// the chains
function MpnAddMul1Adx4(rp, ap: PLimb; n: SizeInt; b: TLimb): TLimb; assembler; nostackframe;
asm
  push rbx
  mov r10, rdx             // ap
  mov rdx, r9              // b, implicit mulx operand
  mov r9, rcx              // rp
  xor r11d, r11d           // carry limb
  mov rcx, r8
  and ecx, 3               // peel count
  shr r8, 2                // quad count
  jrcxz @main
@peel:
  mulx rbx, rax, [r10]
  add rax, r11
  adc rbx, 0
  add [r9], rax
  adc rbx, 0
  mov r11, rbx
  lea r10, [r10 + 8]
  lea r9, [r9 + 8]
  dec ecx
  jnz @peel
@main:
  mov rcx, r8
  test rcx, rcx            // ZF for the branch, CF = 0, OF = 0
  jz @fold
  align 32
@loop:
  mulx r8, rax, [r10]
  adcx rax, r11
  adox rax, [r9]
  mov [r9], rax
  mulx r11, rax, [r10 + 8]
  adcx rax, r8
  adox rax, [r9 + 8]
  mov [r9 + 8], rax
  mulx r8, rax, [r10 + 16]
  adcx rax, r11
  adox rax, [r9 + 16]
  mov [r9 + 16], rax
  mulx r11, rax, [r10 + 24]
  adcx rax, r8
  adox rax, [r9 + 24]
  mov [r9 + 24], rax
  lea r10, [r10 + 32]
  lea r9, [r9 + 32]
  lea rcx, [rcx - 1]
  jrcxz @fold
  jmp @loop
@fold:
  mov rax, r11
  mov ebx, 0
  adcx rax, rbx
  adox rax, rbx
  pop rbx
end;

// rp[0..n] += ap[0..n-1] * (pv[0] + B*pv[1]); rp[n] must be valid on entry,
// returns the limb for rp[n+1]. rdx holds ap[i] so both multipliers come from
// registers (mulx trick)
function MpnAddMul2(rp, ap: PLimb; n: SizeInt; pv: PLimb): TLimb; assembler; nostackframe;
asm
  push rbx
  push rsi
  push rdi
  mov r10, rdx        // ap
  mov r11, [r9]       // b0
  mov rsi, [r9 + 8]   // b1
  mov r9, rcx         // rp
  mov rcx, r8         // n
  xor edi, edi        // a0 (column i accumulator)
  xor r8d, r8d        // a1 (column i+1 accumulator)
  align 32
@loop:
  mov rdx, [r10]
  mulx rbx, rax, r11  // rbx:rax = ap[i] * b0
  add rdi, [r9]       // a0 += rp[i]
  adc rbx, 0
  add rax, rdi        // column i
  adc rbx, 0          // h0 + carries, cannot wrap
  mov [r9], rax
  mulx rdi, rax, rsi  // rdi:rax = ap[i] * b1
  add rax, r8         // l1 + a1
  adc rdi, 0
  add rax, rbx        // + h0 part
  adc rdi, 0          // h1 + carries, cannot wrap (invariant < B^2)
  mov r8, rdi         // new a1
  mov rdi, rax        // new a0
  lea r10, [r10 + 8]
  lea r9, [r9 + 8]
  dec rcx
  jnz @loop
  add [r9], rdi       // rp[n] += a0
  mov rax, r8
  adc rax, 0
  pop rdi
  pop rsi
  pop rbx
end;

// current 1x subN
function MpnSubN1(rp, ap, bp: PLimb; n: SizeInt): TLimb; assembler; nostackframe;
asm
  xor eax, eax
  test r9, r9
  jz @done
@loop:
  mov r10, [rdx]
  sbb r10, [r8]
  mov [rcx], r10
  lea rdx, [rdx + 8]
  lea r8, [r8 + 8]
  lea rcx, [rcx + 8]
  dec r9
  jnz @loop
  setc al
@done:
end;

// 4x unrolled sbb chain
function MpnSubN4(rp, ap, bp: PLimb; n: SizeInt): TLimb; assembler; nostackframe;
asm
  mov r10, r9
  shr r9, 2
  and r10d, 3
  xor eax, eax
  test r9, r9
  jz @tail
  align 32
@q:
  mov r11, [rdx]
  sbb r11, [r8]
  mov [rcx], r11
  mov r11, [rdx + 8]
  sbb r11, [r8 + 8]
  mov [rcx + 8], r11
  mov r11, [rdx + 16]
  sbb r11, [r8 + 16]
  mov [rcx + 16], r11
  mov r11, [rdx + 24]
  sbb r11, [r8 + 24]
  mov [rcx + 24], r11
  lea rdx, [rdx + 32]
  lea r8, [r8 + 32]
  lea rcx, [rcx + 32]
  dec r9
  jnz @q
@tail:
  dec r10
  js @fin
@t:
  mov r11, [rdx]
  sbb r11, [r8]
  mov [rcx], r11
  lea rdx, [rdx + 8]
  lea r8, [r8 + 8]
  lea rcx, [rcx + 8]
  dec r10
  jns @t
@fin:
  setc al
end;

// current mul-based mul_1
function MpnMul1Gen(rp, ap: PLimb; n: SizeInt; b: TLimb): TLimb; assembler; nostackframe;
asm
  mov r10, rdx
  xor r11d, r11d
  test r8, r8
  jz @done
@loop:
  mov rax, [r10]
  mul r9
  add rax, r11
  adc rdx, 0
  mov [rcx], rax
  mov r11, rdx
  lea r10, [r10 + 8]
  lea rcx, [rcx + 8]
  dec r8
  jnz @loop
@done:
  mov rax, r11
end;

// mulx + adcx carry chain, 4 limbs per pass
function MpnMul1Adx4(rp, ap: PLimb; n: SizeInt; b: TLimb): TLimb; assembler; nostackframe;
asm
  push rbx
  mov r10, rdx             // ap
  mov rdx, r9              // b
  mov r9, rcx              // rp
  xor r11d, r11d           // carry limb
  mov rcx, r8
  and ecx, 3
  shr r8, 2
  jrcxz @main
@peel:
  mulx rbx, rax, [r10]
  add rax, r11
  adc rbx, 0
  mov [r9], rax
  mov r11, rbx
  lea r10, [r10 + 8]
  lea r9, [r9 + 8]
  dec ecx
  jnz @peel
@main:
  mov rcx, r8
  test rcx, rcx            // CF = 0
  jz @fold
  align 32
@loop:
  mulx r8, rax, [r10]
  adcx rax, r11
  mov [r9], rax
  mulx r11, rax, [r10 + 8]
  adcx rax, r8
  mov [r9 + 8], rax
  mulx r8, rax, [r10 + 16]
  adcx rax, r11
  mov [r9 + 16], rax
  mulx r11, rax, [r10 + 24]
  adcx rax, r8
  mov [r9 + 24], rax
  lea r10, [r10 + 32]
  lea r9, [r9 + 32]
  lea rcx, [rcx - 1]
  jrcxz @fold
  jmp @loop
@fold:
  mov rax, r11
  mov ebx, 0
  adcx rax, rbx
  pop rbx
end;

// current subMul adx (1 limb per pass, sbb borrow chain in memory)
function MpnSubMul1Adx1(rp, ap: PLimb; n: SizeInt; b: TLimb): TLimb; assembler; nostackframe;
asm
  mov r10, rdx
  mov rdx, r9
  xor r11d, r11d
  test r8, r8
  jz @done
@loop:
  mulx r9, rax, [r10]
  adox rax, r11
  mov r11d, 0
  adox r11, r9
  sbb [rcx], rax
  lea r10, [r10 + 8]
  lea rcx, [rcx + 8]
  dec r8
  jnz @loop
@done:
  mov rax, r11
  adc rax, 0
end;

// 4x unrolled accumulate-then-commit: the product row for a quad is carried
// through registers on the OF chain, then four sbb commits ride the CF chain.
// sbb clobbers OF, so the row must never resume adox after an sbb; the dec
// closing each pass resets OF for the next quad and leaves CF alone
function MpnSubMul1Adx4(rp, ap: PLimb; n: SizeInt; b: TLimb): TLimb; assembler; nostackframe;
asm
  push rbx
  push rsi
  push rdi
  mov r10, rdx             // ap
  mov rdx, r9              // b, implicit mulx operand
  mov r9, rcx              // rp
  mov rcx, r8
  and ecx, 3
  shr r8, 2
  xor r11d, r11d           // row carry = 0; clears the CF/OF the shr left over
  jrcxz @main
@peel:
  mulx rbx, rax, [r10]
  adox rax, r11
  mov r11d, 0
  adox r11, rbx
  sbb [r9], rax
  lea r10, [r10 + 8]
  lea r9, [r9 + 8]
  dec ecx                  // OF := 0 for the next adox, CF (borrow) survives
  jnz @peel
@main:
  // CF is live, so no test here; jrcxz cannot reach past the body, hence the
  // short trampoline
  mov rcx, r8
  jrcxz @tramp
  jmp @go
@tramp:
  jmp @done
@go:
  align 32
@loop:
  mulx r8, rax, [r10]
  adox rax, r11            // p0 = lo0 + row carry
  mulx r11, rbx, [r10 + 8]
  adox rbx, r8             // p1 = lo1 + hi0
  mulx r8, rsi, [r10 + 16]
  adox rsi, r11            // p2 = lo2 + hi1
  mulx r11, rdi, [r10 + 24]
  adox rdi, r8             // p3 = lo3 + hi2
  mov r8d, 0
  adox r11, r8             // row carry = hi3 + OF, cannot wrap, OF = 0 after
  sbb [r9], rax
  sbb [r9 + 8], rbx
  sbb [r9 + 16], rsi
  sbb [r9 + 24], rdi
  lea r10, [r10 + 32]
  lea r9, [r9 + 32]
  dec rcx                  // OF := 0 for the next quad, CF survives
  jnz @loop
@done:
  mov rax, r11
  adc rax, 0
  pop rdi
  pop rsi
  pop rbx
end;

// -- basecase drivers ----------------------

// rows of addmul_1 (current bigints.pas shape)
procedure MulBase1(rp, ap: PLimb; la: SizeInt; bp: PLimb; lb: SizeInt);
begin
  FillChar(rp^, (la + lb) * SizeOf(TLimb), 0);
  rp[la] := MpnAddMul1Adx4(rp, ap, la, bp[0]);
  for var j := 1 to lb - 1 do rp[la + j] := MpnAddMul1Adx4(@rp[j], ap, la, bp[j]);
end;

procedure MulBase1Adx2(rp, ap: PLimb; la: SizeInt; bp: PLimb; lb: SizeInt);
begin
  FillChar(rp^, (la + lb) * SizeOf(TLimb), 0);
  rp[la] := MpnAddMul1Adx2(rp, ap, la, bp[0]);
  for var j := 1 to lb - 1 do rp[la + j] := MpnAddMul1Adx2(@rp[j], ap, la, bp[j]);
end;

// rows of addmul_2, odd final row via addmul_1
procedure MulBase2(rp, ap: PLimb; la: SizeInt; bp: PLimb; lb: SizeInt);
begin
  FillChar(rp^, (la + lb) * SizeOf(TLimb), 0);
  var j := 0;
  while j + 1 < lb do begin
    rp[la + j + 1] := MpnAddMul2(@rp[j], ap, la, @bp[j]);
    j := j + 2;
  end;
  if j < lb then rp[la + j] := rp[la + j] + MpnAddMul1Adx2(@rp[j], ap, la, bp[j]);
end;

// -- reference and checking ----------------------

procedure MulRef(rp, ap: PLimb; la: SizeInt; bp: PLimb; lb: SizeInt);
begin
  FillChar(rp^, (la + lb) * SizeOf(TLimb), 0);
  for var j := 0 to lb - 1 do begin
    var carry: QWord := 0;
    for var i := 0 to la - 1 do begin
      var p := UInt128(ap[i]) * bp[j] + rp[i + j] + carry;
      rp[i + j] := QWord(p);
      carry := QWord(p shr 64);
    end;
    rp[la + j] := carry;
  end;
end;

var
  rng: QWord = 88172645463325252;

function Rnd64: QWord;
begin
  rng := rng xor (rng shl 13);
  rng := rng xor (rng shr 7);
  rng := rng xor (rng shl 17);
  result := rng;
end;

var
  freq: Int64;

function Ticks: Int64;
begin
  QueryPerformanceCounter(result);
end;

function Secs(t: Int64): double;
begin
  result := t / freq;
end;

var
  fails: integer = 0;

procedure Check(cond: boolean; const name: string);
begin
  if cond then exit;
  writeln('FAIL: ', name);
  inc(fails);
end;

const
  SIZES: array[0..7] of SizeInt = (16, 32, 64, 128, 256, 512, 2048, 16384);
  BASESIZES: array[0..5] of SizeInt = (16, 32, 48, 64, 96, 128);

type
  TAddMulFn = function(rp, ap: PLimb; n: SizeInt; b: TLimb): TLimb;
  TAddFn = function(rp, ap, bp: PLimb; n: SizeInt): TLimb;
  TBaseFn = procedure(rp, ap: PLimb; la: SizeInt; bp: PLimb; lb: SizeInt);

var
  a, b, r0, r1: array of TLimb;

// time one addmul kernel: reps chosen for ~50M limb-products per size
procedure BenchAddMul(const name: string; fn: TAddMulFn);
begin
  write(name:16);
  for var s in SIZES do begin
    var reps := 50 * 1000 * 1000 div s;
    if reps < 8 then reps := 8;
    for var i := 0 to s - 1 do r0[i] := Rnd64;
    var t0 := Ticks;
    var sink: QWord := 0;
    for var rep := 1 to reps do sink := sink + fn(@r0[0], @a[0], s, b[0]);
    var dt := Secs(Ticks - t0);
    if sink = QWord($DEADBEEF) then write('!');
    // ns per limb-product
    write((dt * 1e9 / (double(reps) * s)):8:3);
  end;
  writeln;
end;

procedure BenchAdd(const name: string; fn: TAddFn);
begin
  write(name:16);
  for var s in SIZES do begin
    var reps := 100 * 1000 * 1000 div s;
    if reps < 8 then reps := 8;
    var t0 := Ticks;
    var sink: QWord := 0;
    for var rep := 1 to reps do sink := sink + fn(@r0[0], @a[0], @b[0], s);
    var dt := Secs(Ticks - t0);
    if sink = QWord($DEADBEEF) then write('!');
    write((dt * 1e9 / (double(reps) * s)):8:3);
  end;
  writeln;
end;

procedure BenchBase(const name: string; fn: TBaseFn);
begin
  write(name:16);
  for var s in BASESIZES do begin
    var reps := 30 * 1000 * 1000 div (s * s);
    if reps < 8 then reps := 8;
    var t0 := Ticks;
    for var rep := 1 to reps do fn(@r0[0], @a[0], s, @b[0], s);
    var dt := Secs(Ticks - t0);
    // ns per limb-product (s*s products)
    write((dt * 1e9 / (double(reps) * s * s)):8:3);
  end;
  writeln;
end;

const
  NMAX = 16384;

begin
  QueryPerformanceFrequency(freq);
  SetLength(a, NMAX + 2);
  SetLength(b, NMAX + 2);
  SetLength(r0, 2 * NMAX + 2);
  SetLength(r1, 2 * NMAX + 2);
  for var i := 0 to NMAX + 1 do a[i] := Rnd64;
  for var i := 0 to NMAX + 1 do b[i] := Rnd64;

  // correctness: addmul_1 variants vs Gen
  for var n := 1 to 130 do begin
    for var i := 0 to n do begin
      r0[i] := a[i + 7];
      r1[i] := a[i + 7];
    end;
    var c0 := MpnAddMul1Gen(@r0[0], @a[0], n, b[0]);
    var c1 := MpnAddMul1Adx4(@r1[0], @a[0], n, b[0]);
    Check(c0 = c1, 'addmul1adx4 carry n='+IntToStr(n));
    for var i := 0 to n - 1 do Check(r0[i] = r1[i], 'addmul1adx4 limb n='+IntToStr(n));
    // addmul_2 vs two addmul_1 rows
    for var i := 0 to n + 1 do begin
      r0[i] := a[i + 3];
      r1[i] := a[i + 3];
    end;
    r0[n] := 0;
    r0[n + 1] := 0;
    r1[n] := 0;
    r1[n + 1] := 0;
    var cx := MpnAddMul1Gen(@r0[0], @a[0], n, b[0]);
    r0[n] := r0[n] + cx;
    cx := MpnAddMul1Gen(@r0[1], @a[0], n, b[1]);
    r0[n + 1] := r0[n + 1] + cx;
    r1[n + 1] := MpnAddMul2(@r1[0], @a[0], n, @b[0]);
    for var i := 0 to n + 1 do Check(r0[i] = r1[i], 'addmul2 limb n='+IntToStr(n));
    // addN / subN
    var ca := MpnAddN1(@r0[0], @a[0], @b[0], n);
    var cb := MpnAddN4(@r1[0], @a[0], @b[0], n);
    Check(ca = cb, 'addn4 carry n='+IntToStr(n));
    for var i := 0 to n - 1 do Check(r0[i] = r1[i], 'addn4 limb n='+IntToStr(n));
    ca := MpnSubN1(@r0[0], @a[0], @b[0], n);
    cb := MpnSubN4(@r1[0], @a[0], @b[0], n);
    Check(ca = cb, 'subn4 carry n='+IntToStr(n));
    for var i := 0 to n - 1 do Check(r0[i] = r1[i], 'subn4 limb n='+IntToStr(n));
    // mul1
    ca := MpnMul1Gen(@r0[0], @a[0], n, b[0]);
    cb := MpnMul1Adx4(@r1[0], @a[0], n, b[0]);
    Check(ca = cb, 'mul1adx4 carry n='+IntToStr(n));
    for var i := 0 to n - 1 do Check(r0[i] = r1[i], 'mul1adx4 limb n='+IntToStr(n));
    // submul
    for var i := 0 to n do begin
      r0[i] := a[i + 5];
      r1[i] := a[i + 5];
    end;
    ca := MpnSubMul1Adx1(@r0[0], @a[0], n, b[0]);
    cb := MpnSubMul1Adx4(@r1[0], @a[0], n, b[0]);
    Check(ca = cb, 'submul1adx4 borrow n='+IntToStr(n));
    for var i := 0 to n - 1 do Check(r0[i] = r1[i], 'submul1adx4 limb n='+IntToStr(n));
  end;
  // basecase drivers vs reference
  for var n in BASESIZES do begin
    MulRef(@r0[0], @a[0], n, @b[0], n);
    MulBase2(@r1[0], @a[0], n, @b[0], n);
    for var i := 0 to 2 * n - 1 do Check(r0[i] = r1[i], 'mulbase2 n='+IntToStr(n));
    MulBase1(@r1[0], @a[0], n, @b[0], n);
    for var i := 0 to 2 * n - 1 do Check(r0[i] = r1[i], 'mulbase1 n='+IntToStr(n));
  end;
  if fails = 0 then writeln('correctness OK') else begin
    writeln(fails, ' failures, aborting');
    halt(1);
  end;
  writeln;

  write('ns/limb':16);
  for var s in SIZES do write(s:8);
  writeln;
  BenchAdd('addN 1x', @MpnAddN1);
  BenchAdd('addN 4x', @MpnAddN4);
  BenchAdd('subN 1x', @MpnSubN1);
  BenchAdd('subN 4x', @MpnSubN4);
  writeln;
  write('ns/product':16);
  for var s in SIZES do write(s:8);
  writeln;
  BenchAddMul('mul1 gen', @MpnMul1Gen);
  BenchAddMul('mul1 adx4', @MpnMul1Adx4);
  BenchAddMul('addmul1 gen', @MpnAddMul1Gen);
  BenchAddMul('addmul1 adx2', @MpnAddMul1Adx2);
  BenchAddMul('addmul1 adx4', @MpnAddMul1Adx4);
  BenchAddMul('submul1 adx1', @MpnSubMul1Adx1);
  BenchAddMul('submul1 adx4', @MpnSubMul1Adx4);
  writeln;
  write('ns/product':16);
  for var s in BASESIZES do write(s:8);
  writeln;
  BenchBase('base rows1 adx2', @MulBase1Adx2);
  BenchBase('base rows1 adx4', @MulBase1);
  BenchBase('base rows2', @MulBase2);
end.
