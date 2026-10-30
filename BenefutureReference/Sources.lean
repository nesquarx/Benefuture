/-
  BenefutureReference.Sources
  Source tags in information handling (L133 IH; author ruling on 8.45): a reading carries the tags
  of the sources it came from, so an echo never passes for a source. A listener hearing several
  contacts that repeat one origin hears it once, and an echo of the listener itself is not a source.
  Tags inform; they move no voting weight (author ruling 8.60: every voter votes or delegates with its
  full expertise and impact weight, sources are credited through their records). Tags are outputs: AdvAp audits them
  against the origins' logged outputs (misattribution) and audits outputs presented as one's own
  against what was heard (laundering by omission).
-/

namespace BenefutureReference

/-- Count once by origin, with `seen` already heard: each weight stands at the first occurrence of
    its origin id and is zero at every repeat (and wherever the id is in `seen`). -/
def count_once_from (seen ids ws : Array Float) : Array Float :=
  ((ids.zip ws).foldl (fun (acc : Array Float × Array Float) (p : Float × Float) =>
    if acc.2.contains p.1 then (acc.1.push 0.0, acc.2) else (acc.1.push p.2, acc.2.push p.1))
    (#[], seen)).1

/-- Count once by origin (8.45): repeats of an origin carry no weight. -/
def count_once_ref (ids ws : Array Float) : Array Float := count_once_from #[] ids ws

/-- A tagged reading (8.45): own weight × own side, plus each distinct origin's weight × its side;
    an origin equal to the listener (`self`) is its own echo and adds nothing. -/
def tagged_reading_ref (self own ownSide : Float) (ids sides ws : Array Float) : Float :=
  own * ownSide + ((count_once_from #[self] ids ws).zip sides).foldl (fun s p => s + p.1 * p.2) 0.0

/-- Falsified tags (8.45; L160): how many claimed sides differ from the origins' logged outputs. -/
def tags_falsified_ref (claimed logged : Array Float) : Nat :=
  ((claimed.zip logged).filter fun p => p.1 != p.2).size

/-- Undisclosed echo (8.45; L160): over `n` outputs presented as one's own, `agree` matched what one
    heard. Two independent judges of accuracies `aSelf` and `aSrc` agree at
    aSelf·aSrc + (1 − aSelf)(1 − aSrc); the output is flagged as an echo when agreement exceeds that
    plus the governed `margin` by more than `z` standard errors. -/
def undisclosed_echo_ref (agree n aSelf aSrc margin z : Float) : Bool :=
  let e := aSelf * aSrc + (1.0 - aSelf) * (1.0 - aSrc)
  let e' := min (e + margin) 0.999999
  n > 0.0 && (agree - n * e') / Float.sqrt (n * e' * (1.0 - e')) > z

end BenefutureReference
