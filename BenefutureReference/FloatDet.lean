/-
  BenefutureReference.FloatDet
  Cross-platform deterministic IEEE-754 binary64 software math primitives (FDLIBM kernels).
  MANDATORY REQUIREMENT: ZERO imports from Mathlib, ZERO imports from Benefuture.
  All transcendental constants are explicit IEEE-754 Float64 bit patterns and must stay
  bit-identical to `sim/src/deterministic.jl` (compiled with `-ffp-contract=off`).
  Constants are non-inlined top-level `private def`s so Lean initializes them once and emits
  pure unboxed `double`/`int64_t`/`uint64_t` arithmetic with zero `l_Float_ofScientific` or boxing.
-/

namespace BenefutureReference

private def fZero     : Float := Float.ofBits 0x0000000000000000
private def fHalf     : Float := Float.ofBits 0x3fe0000000000000
private def fOne      : Float := Float.ofBits 0x3ff0000000000000
private def fNegOne   : Float := Float.ofBits 0xbff0000000000000
private def fTwo      : Float := Float.ofBits 0x4000000000000000
private def fPosInf   : Float := Float.ofBits 0x7ff0000000000000
private def fNegInf   : Float := Float.ofBits 0xfff0000000000000
private def fNaN      : Float := Float.ofBits 0x7ff8000000000000
private def fTinyExp  : Float := Float.ofBits 0x3e30000000000000
private def fExpMax   : Float := Float.ofBits 0x40862e42fefa39ef
private def fExpMin   : Float := Float.ofBits 0xc0874910d52d3052
private def fExp2Max  : Float := Float.ofBits 0x4090000000000000
private def fExp2Min  : Float := Float.ofBits 0xc090cc0000000000
private def fTwo54    : Float := Float.ofBits 0x4350000000000000
private def fTwo53    : Float := Float.ofBits 0x4340000000000000
private def f1e20     : Float := Float.ofBits 0x4415af1d78b58c40
private def f1e54     : Float := Float.ofBits 0x4b24e1878814c9ce
private def fLog1pThr : Float := Float.ofBits 0x3fd2bec333018866
private def fSub2m512 : Float := Float.ofBits 0x1ff0000000000000

private def ln2Hi   : Float := Float.ofBits 0x3fe62e42fee00000
private def ln2Lo   : Float := Float.ofBits 0x3dea39ef35793c76
private def invLn2  : Float := Float.ofBits 0x3ff71547652b82fe
private def ln2H26  : Float := Float.ofBits 0x3fe62e42f8000000
private def ln2L26  : Float := Float.ofBits 0x3e4be8e7bcd5e4f2
private def ln2Full : Float := Float.ofBits 0x3fe62e42fefa39ef
private def invLn2H : Float := Float.ofBits 0x3ff7154760000000
private def invLn2L : Float := Float.ofBits 0x3e54ae0bf85ddf44

private def expP1 : Float := Float.ofBits 0x3fc555555555553e
private def expP2 : Float := Float.ofBits 0xbf66c16c16bebd93
private def expP3 : Float := Float.ofBits 0x3f11566aaf25de2c
private def expP4 : Float := Float.ofBits 0xbebbbd41c5d26bf1
private def expP5 : Float := Float.ofBits 0x3e66376972bea4d0

private def lg1 : Float := Float.ofBits 0x3fe5555555555593
private def lg2 : Float := Float.ofBits 0x3fd999999997fa04
private def lg3 : Float := Float.ofBits 0x3fd2492494229359
private def lg4 : Float := Float.ofBits 0x3fcc71c51d8e78af
private def lg5 : Float := Float.ofBits 0x3fc7466496cb03de
private def lg6 : Float := Float.ofBits 0x3fc39a09d078c69f
private def lg7 : Float := Float.ofBits 0x3fc2f112df3e5244

private def i0       : Int64 := 0
private def i1       : Int64 := 1
private def iNeg510  : Int64 := -510
private def i510     : Int64 := 510
private def i512     : Int64 := 512
private def iNeg512  : Int64 := -512
private def i1022    : Int64 := 1022
private def i1023    : Int64 := 1023
private def iNeg1021 : Int64 := -1021
private def iNeg1022 : Int64 := -1022
private def i1077    : Int64 := 1077
private def iNeg1075 : Int64 := -1075
private def i1535    : Int64 := 1535
private def i2200    : Int64 := 2200
private def iNeg2200 : Int64 := -2200

@[inline] def detAbs (x : Float) : Float :=
  Float.ofBits (x.toBits &&& 0x7fffffffffffffff)

@[inline] def detSignbit (x : Float) : Bool :=
  (x.toBits >>> 63) == 1

@[inline] def detTrunc (x : Float) : Float :=
  if x >= fZero then Float.floor x else Float.ceil x

@[inline] def sq (x : Float) : Float :=
  x * x

@[inline] private def pow2Norm (k : Int64) : Float :=
  Float.ofBits (((k + i1023).toUInt64) <<< 52)

@[noinline] private def ldexp1 (m : Float) (e : Int64) : Float :=
  if e == i0 then m
  else if e > i0 then
    let s := if e > i1023 then i1023 else e
    m * pow2Norm s
  else if e >= iNeg1022 then m * pow2Norm e
  else if detAbs m >= fOne then m * pow2Norm iNeg1022
  else if detAbs m < fSub2m512 then m * fZero
  else m * pow2Norm iNeg510

@[noinline] private def ldexp2 (m : Float) (e : Int64) : Float :=
  if e == i0 then m
  else if e > i0 then
    let s := if e > i1023 then i1023 else e
    ldexp1 (m * pow2Norm s) (e - s)
  else if e >= iNeg1022 then m * pow2Norm e
  else if detAbs m >= fOne then ldexp1 (m * pow2Norm iNeg1022) (e + i1022)
  else if detAbs m < fSub2m512 then m * fZero
  else ldexp1 (m * pow2Norm iNeg510) (e + i510)

@[noinline] private def ldexp3 (m : Float) (e : Int64) : Float :=
  if e == i0 then m
  else if e > i0 then
    let s := if e > i1023 then i1023 else e
    ldexp2 (m * pow2Norm s) (e - s)
  else if e >= iNeg1022 then m * pow2Norm e
  else if detAbs m >= fOne then ldexp2 (m * pow2Norm iNeg1022) (e + i1022)
  else if detAbs m < fSub2m512 then m * fZero
  else ldexp2 (m * pow2Norm iNeg510) (e + i510)

/-- Scale `x` by `2^e` using exact IEEE-754 binary64 power-of-2 multiplications. -/
@[inline] def det_ldexp (x : Float) (e : Int64) : Float :=
  if x == fZero || x.isNaN || x.isInf || e == i0 then x
  else
    let e0 := if e > i2200 then i2200 else if e < iNeg2200 then iNeg2200 else e
    if iNeg1022 <= e0 && e0 <= i1023 then x * pow2Norm e0
    else ldexp3 x e0

@[inline] private def scale2 (y : Float) (k : Int64) : Float :=
  if k >= iNeg1021 && k <= i1023 then y * pow2Norm k
  else if k > i1023 then
    let s := if k > i1535 then i1535 else k
    (y * pow2Norm i512) * pow2Norm (s - i512)
  else if k < iNeg1075 then fZero
  else (y * pow2Norm iNeg512) * pow2Norm (k + i512)

@[inline] private def expKernel (hi lo : Float) (k : Int64) : Float :=
  let r := hi - lo
  let t := r * r
  let c := r - t * (expP1 + t * (expP2 + t * (expP3 + t * (expP4 + t * expP5))))
  let y := fOne - ((lo - (r * c) / (fTwo - c)) - hi)
  scale2 y k

@[inline] private def det_exp2_dd (xhi xlo : Float) : Float :=
  if xhi.isNaN then xhi
  else if xhi >= fExp2Max then fPosInf
  else if xhi <= fExp2Min then fZero
  else
    let kf := Float.floor (xhi + fHalf)
    let k := kf.toInt64
    let dx := xhi - kf
    let f := dx + xlo
    if f == fZero then scale2 fOne k
    else
      let fh := Float.ofBits (f.toBits &&& 0xfffffffff8000000)
      let fl := (dx - fh) + xlo
      expKernel (fh * ln2H26) (-(fl * ln2Full + fh * ln2L26)) k

/-- Deterministic `exp(x)` across platforms. -/
def det_exp (x : Float) : Float :=
  if x.isNaN then x
  else if x >= fExpMax then fPosInf
  else if x <= fExpMin then fZero
  else if detAbs x < fTinyExp then fOne + x
  else
    let kf := Float.floor (x * invLn2 + fHalf)
    let k := kf.toInt64
    expKernel (x - kf * ln2Hi) (kf * ln2Lo) k

@[inline] private def det_log_pos_add (x extra : Float) : Float :=
  let u0 := x.toBits
  let biased := u0 >>> 52
  let u := if biased == 0 then (x * fTwo54).toBits else u0
  let k0 : Int64 := (u >>> 52).toInt64 - (if biased == 0 then i1077 else i1023)
  let frac := u &&& 0x000fffffffffffff
  let m0 := Float.ofBits (frac ||| 0x3ff0000000000000)
  let hi := frac >= 0x0006a09e667f3bcd
  let m := if hi then m0 * fHalf else m0
  let k := if hi then k0 + i1 else k0
  let f := m - fOne
  let s := f / (fTwo + f)
  let z := s * s
  let w := z * z
  let t1 := w * (lg2 + w * (lg4 + w * lg6))
  let t2 := z * (lg1 + w * (lg3 + w * (lg5 + w * lg7)))
  let hfsq := fHalf * f * f
  let dk := k.toFloat
  dk * ln2Hi - ((hfsq - (s * (hfsq + (t2 + t1)) + (dk * ln2Lo + extra))) - f)

/-- Deterministic natural logarithm across platforms. -/
def det_log (x : Float) : Float :=
  if x.isNaN then x
  else if x < fZero then fNaN
  else if x == fZero then fNegInf
  else if x.isInf then fPosInf
  else if x == fOne then fZero
  else det_log_pos_add x fZero

/-- Deterministic `log(1 + x)` across platforms. -/
def det_log1p (x : Float) : Float :=
  if x.isNaN then x
  else if x < fNegOne then fNaN
  else if x == fNegOne then fNegInf
  else if x.isInf then fPosInf
  else if x == fZero then x
  else
    let ax := detAbs x
    if ax < fLog1pThr then
      let s := x / (fTwo + x)
      let z := s * s
      let w := z * z
      let t1 := w * (lg2 + w * (lg4 + w * lg6))
      let t2 := z * (lg1 + w * (lg3 + w * (lg5 + w * lg7)))
      let hfsq := fHalf * x * x
      x - (hfsq - s * (hfsq + (t2 + t1)))
    else if x > f1e54 then
      det_log x
    else
      let u := fOne + x
      let c := if ax <= fOne then x - (u - fOne) else fOne - (u - x)
      det_log_pos_add u (c / u)

@[inline] private def det_log2_dd_k (x : Float) (k : Float → Float → Float) : Float :=
  let u0 := x.toBits
  let biased := u0 >>> 52
  let u := if biased == 0 then (x * fTwo54).toBits else u0
  let k0 : Int64 := (u >>> 52).toInt64 - (if biased == 0 then i1077 else i1023)
  let frac := u &&& 0x000fffffffffffff
  let m0 := Float.ofBits (frac ||| 0x3ff0000000000000)
  let hi := frac >= 0x0006a09e667f3bcd
  let m := if hi then m0 * fHalf else m0
  let expK := if hi then k0 + i1 else k0
  let f := m - fOne
  let tf := fTwo + f
  let s := f / tf
  let s2 := s * s
  let s4 := s2 * s2
  let t1 := s4 * (lg2 + s4 * (lg4 + s4 * lg6))
  let t2 := s2 * (lg1 + s4 * (lg3 + s4 * (lg5 + s4 * lg7)))
  let rPoly := t2 + t1
  let sh := Float.ofBits (s.toBits &&& 0xfffffffff8000000)
  let th := Float.ofBits (tf.toBits &&& 0xfffffffff8000000)
  let tl := f - (th - fTwo)
  let sl := (f - sh * th - sh * tl) / tf
  let uh := fTwo * sh
  let ul := fTwo * sl + s * rPoly
  let lh := uh * invLn2H
  let ll := ul * invLn2H + (uh + ul) * invLn2L
  let dk := expK.toFloat
  let totH := dk + lh
  let comp := if detAbs dk >= detAbs lh then (dk - totH) + lh else (lh - totH) + dk
  let totL := ll + comp
  k totH totL

/-- Deterministic `x^y` across platforms, matching IEEE-754 `pow` edge semantics. -/
def det_pow (x y : Float) : Float :=
  if y == fZero then fOne
  else if x.isNaN then fNaN
  else if y.isNaN then if x == fOne then fOne else fNaN
  else if x == fOne then fOne
  else if y == fOne then x
  else if y == fTwo then x * x
  else if y == fNegOne then fOne / x
  else if y == fHalf && x >= fZero then Float.sqrt (if x == fZero then fZero else x)
  else if x == fTwo then det_exp2_dd y fZero
  else if y.isInf then
    let ax := detAbs x
    if ax == fOne then fOne
    else if (ax > fOne) == (y > fZero) then fPosInf else fZero
  else
    let yi := detTrunc y
    let isInt := y == yi
    let ayi := detAbs yi
    let isOdd := isInt && ayi < fTwo53 && ((ayi.toUInt64 &&& 1) != 0)
    if x == fZero then
      if y > fZero then (if isOdd && detSignbit x then Float.ofBits 0x8000000000000000 else fZero)
      else (if isOdd && detSignbit x then fNegInf else fPosInf)
    else if x.isInf then
      if x > fZero then (if y > fZero then fPosInf else fZero)
      else if y > fZero then (if isOdd then fNegInf else fPosInf)
      else (if isOdd then Float.ofBits 0x8000000000000000 else fZero)
    else if x < fZero && !isInt then fNaN
    else
      let sgn := if x < fZero && isOdd then fNegOne else fOne
      let ax := detAbs x
      if ax == fOne then sgn
      else if detAbs y > f1e20 then
        if (ax > fOne) == (y > fZero) then fPosInf else fZero
      else
        det_log2_dd_k ax fun lh ll =>
        let yh := Float.ofBits (y.toBits &&& 0xfffffffff8000000)
        let yl := y - yh
        let lhh := Float.ofBits (lh.toBits &&& 0xfffffffff8000000)
        let lhl := (lh - lhh) + ll
        let ph := yh * lhh
        let pl := yh * lhl + yl * lh + yl * ll
        let sh := ph + pl
        let sl := (ph - sh) + pl
        let res := det_exp2_dd sh sl
        if sgn < fZero then -res else res

end BenefutureReference
