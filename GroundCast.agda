{-

  This module formalizes the λB calculus (Siek, Thiemann, Wadler
  2015), aka. the blame calculus without predicate types, and proves
  type safety via progress and preservation.  

  This module is relatively small because it reuses the definitions
  and proofs from the Parameterized Cast Calculus. This module just
  has to provide the appropriate parameters.

-}

module GroundCast where

  open import Data.Nat
  open import Data.Bool
  open import Types
  open import Variables
  open import Labels
  open import Relation.Nullary using (¬_; Dec; yes; no)
  open import Relation.Nullary.Negation using (contradiction)
  open import Relation.Binary.PropositionalEquality
     using (_≡_;_≢_; refl; trans; sym; cong; cong₂; cong-app)
  open import Data.Product using (_×_; proj₁; proj₂; Σ; Σ-syntax)
     renaming (_,_ to [_,_])
  open import Data.Sum using (_⊎_; inj₁; inj₂)
  open import Data.Empty using (⊥; ⊥-elim)

  {-

   The λB calculus represents a cast as a pair of types, the source and target,
   and a blame label. The two types must be consistent.

   -}

  data Cast : Type → Set where
    cast : (A : Type) → (B : Type) → Label → A ~ B → Cast (A ⇒ B)

  import ParamCastCalculus
  module CastCalc = ParamCastCalculus Cast
  open CastCalc

  import GTLC2CC
  module Compile = GTLC2CC Cast (λ A B ℓ {c} → cast A B ℓ c)
  
  {-

  We categorize casts into the inert ones (that form values) and
  the active ones (that reduce).  

  For λB, there are two kinds of inert casts, those from a ground
  type to ⋆ and those between two function types.

n  -}

  data Inert : ∀ {A} → Cast A → Set where
    I-inj : ∀{A} → Ground A → (c : Cast (A ⇒ ⋆)) → Inert c
    I-fun : ∀{A B A' B'} → (c : Cast ((A ⇒ B) ⇒ (A' ⇒ B'))) → Inert c

  {-

  The rest of the casts are active casts, which we further subdivide
  according to which reduction rule is applicable. We have the
  identity casts, the injections from non-ground types, the casts
  between pair types, and the casts between sum types.

  -}

  data Active : ∀ {A} → Cast A → Set where
    A-id : ∀{A} → {a : Atomic A} → (c : Cast (A ⇒ A)) → Active c
    A-inj : ∀{A} → (c : Cast (A ⇒ ⋆)) → ¬ Ground A → A ≢ ⋆ → Active c
    A-proj : ∀{B} → (c : Cast (⋆ ⇒ B)) → B ≢ ⋆ → Active c
    A-pair : ∀{A B A' B'} → (c : Cast ((A `× B) ⇒ (A' `× B'))) → Active c
    A-sum : ∀{A B A' B'} → (c : Cast ((A `⊎ B) ⇒ (A' `⊎ B'))) → Active c    

  {-

   To show that every cast is either active or inert, we
   consider all the cases between two consistent types.

   -}

  ActiveOrInert : ∀{A} → (c : Cast A) → Active c ⊎ Inert c
  ActiveOrInert (cast .⋆ B ℓ unk~L) with eq-unk B
  ... | yes eqb rewrite eqb = inj₁ (A-id {⋆} {A-Unk} (cast ⋆ ⋆ ℓ unk~L))
  ... | no neqb = inj₁ (A-proj (cast ⋆ B ℓ unk~L) neqb)
  ActiveOrInert (cast A .⋆ ℓ unk~R) with eq-unk A
  ... | yes eqa rewrite eqa = inj₁ (A-id {⋆}{A-Unk} (cast ⋆ ⋆ ℓ unk~R))
  ... | no neqa with ground? A
  ...    | yes g = inj₂ (I-inj g (cast A ⋆ ℓ unk~R))
  ...    | no ng = inj₁ (A-inj (cast A ⋆ ℓ unk~R) ng neqa)
  ActiveOrInert (cast (` ι) (` ι) ℓ base~) =
     inj₁ (A-id {` ι}{A-Base} (cast (` ι) (` ι) ℓ base~))
  ActiveOrInert (cast (A ⇒ B) (A' ⇒ B') ℓ (fun~ c c₁)) =
     inj₂ (I-fun (cast (A ⇒ B) (A' ⇒ B') ℓ (fun~ c c₁)))
  ActiveOrInert (cast (A `× B) (A' `× B') ℓ (pair~ c c₁)) =
     inj₁ (A-pair (cast (A `× B) (A' `× B') ℓ (pair~ c c₁)))
  ActiveOrInert (cast (A `⊎ B) (A' `⊎ B') ℓ (sum~ c c₁)) =
     inj₁ (A-sum (cast (A `⊎ B) (A' `⊎ B') ℓ (sum~ c c₁)))

  {-

   We take the first step of instantiating the reduction semantics of
   the Parametric Cast Calculus by applying the outer module.

   -}

  import ParamCastReduction
  module PCR = ParamCastReduction Cast Inert Active ActiveOrInert
  open PCR

  inert-ground : ∀{A} → (c : Cast (A ⇒ ⋆)) → Inert c → Ground A
  inert-ground c (I-inj g .c) = g

  {-

   To instantiate the inner module, we must provide several functions,
   the first of which is applyCast. This handles applying an active
   cast to a value. We comment each case with the reduction rule from
   Siek, Thiemann, and Wadler (2015). The definition of applyCast
   is driven by pattern matching on the parameter {a : Active c}.

   -}

  applyCast : ∀ {Γ A B} → (M : Γ ⊢ A) → (Value M) → (c : Cast (A ⇒ B))
     → ∀ {a : Active c} → Γ ⊢ B
  {-
    V : ι ⇒ ι   —→   V 
   -}
  applyCast M v c {A-id c} = M
  {-
    V : A ⇒ ⋆   —→   V : A ⇒ G ⇒ ⋆
   -}
  applyCast M v (cast A ⋆ ℓ cn) {A-inj c a-ng a-nd} with ground A {a-nd}
  ... | [ G , cns ] = (M ⟨ cast A G ℓ (proj₂ cns) ⟩) ⟨ cast G ⋆ ℓ unk~R ⟩
  {-
    V : G ⇒p ⋆ ⇒q G  —→   V
    V : G ⇒p ⋆ ⇒q H  —→   blame q
   -}
  applyCast M v (cast ⋆ B ℓ cn) {A-proj c b-nd} with ground? B
  ... | yes b-g with PCR.canonical⋆ M v
  ...      | [ G , [ V , [ c' , [ i , meq ] ] ] ] rewrite meq
                 with gnd-eq? G B {inert-ground c' i} {b-g}
  ...          | yes ap-b rewrite ap-b = V
  ...          | no ap-b = blame ℓ
  {-
    V : ⋆ ⇒ B   —→   V : ⋆ ⇒ H ⇒ B
   -}
  applyCast M v (cast ⋆ B ℓ cn) {A-proj c b-nd} | no b-ng with ground B {b-nd}
  ...    | [ H , [ h-g , cns ] ] =
           (M ⟨ cast ⋆ H ℓ unk~L ⟩) ⟨ cast H B ℓ (Sym~ cns) ⟩
  
  applyCast M v (cast (A₁ `× A₂) (B₁ `× B₂) ℓ (pair~ c c₁)) {A-pair _} =
    cons (fst M ⟨ cast A₁ B₁ ℓ c ⟩) (snd M ⟨ cast A₂ B₂ ℓ c₁ ⟩)
    
  applyCast M v (cast (A₁ `⊎ A₂) (B₁ `⊎ B₂) ℓ (sum~ c c₁)) {A-sum _} =
    let l = inl ((` Z) ⟨ cast A₁ B₁ ℓ c ⟩) in
    let r = inr ((` Z) ⟨ cast A₂ B₂ ℓ c₁ ⟩) in
    case M (ƛ l) (ƛ r)


  funSrc : ∀{A A' B'}
         → (c : Cast (A ⇒ (A' ⇒ B'))) → (i : Inert c)
          → Σ[ A₁ ∈ Type ] Σ[ A₂ ∈ Type ] A ≡ A₁ ⇒ A₂
  funSrc (cast (A₁ ⇒ A₂) (A' ⇒ B') x cn) (I-fun _) = [ A₁ , [ A₂ , refl ] ]

  pairSrc : ∀{A A' B'}
         → (c : Cast (A ⇒ (A' `× B'))) → (i : Inert c)
          → Σ[ A₁ ∈ Type ] Σ[ A₂ ∈ Type ] A ≡ A₁ `× A₂
  pairSrc c ()

  sumSrc : ∀{A A' B'}
         → (c : Cast (A ⇒ (A' `⊎ B'))) → (i : Inert c)
          → Σ[ A₁ ∈ Type ] Σ[ A₂ ∈ Type ] A ≡ A₁ `⊎ A₂
  sumSrc c ()

  dom : ∀{A₁ A₂ A' B'} → (c : Cast ((A₁ ⇒ A₂) ⇒ (A' ⇒ B'))) → Inert c
         → Cast (A' ⇒ A₁)
  dom (cast (A₁ ⇒ A₂) (A' ⇒ B') ℓ (fun~ c d)) (I-fun _) =
      cast A' A₁ ℓ c

  cod : ∀{A₁ A₂ A' B'} → (c : Cast ((A₁ ⇒ A₂) ⇒ (A' ⇒ B'))) → Inert c
         →  Cast (A₂ ⇒ B')
  cod (cast (A₁ ⇒ A₂) (A' ⇒ B') ℓ (fun~ c d)) (I-fun _) =
      cast A₂ B' ℓ d

  fstC : ∀{A₁ A₂ A' B'} → (c : Cast ((A₁ `× A₂) ⇒ (A' `× B'))) → Inert c
         → Cast (A₁ ⇒ A')
  fstC c ()

  sndC : ∀{A₁ A₂ A' B'} → (c : Cast ((A₁ `× A₂) ⇒ (A' `× B'))) → Inert c
         →  Cast (A₂ ⇒ B')
  sndC c ()

  inlC : ∀{A₁ A₂ A' B'} → (c : Cast ((A₁ `⊎ A₂) ⇒ (A' `⊎ B'))) → Inert c
         → Cast (A₁ ⇒ A')
  inlC c ()

  inrC : ∀{A₁ A₂ A' B'} → (c : Cast ((A₁ `⊎ A₂) ⇒ (A' `⊎ B'))) → Inert c
         →  Cast (A₂ ⇒ B')
  inrC c ()

  {-
  Finally, we show that casts to base type are not inert.
  -}
  
  baseNotInert : ∀ {A ι} → (c : Cast (A ⇒ ` ι)) → ¬ Inert c
  baseNotInert c ()


  {-
  We now instantiate the inner module of ParamCastReduction, thereby
  proving type safety for λB. 
  -}

  module Red = PCR.Reduction applyCast funSrc pairSrc sumSrc
                   dom cod fstC sndC inlC inrC
                   baseNotInert
  open Red

  open import CastStructure

  struct : CastStruct
  struct = record
             { Cast = Cast
             ; Inert = Inert
             ; Active = Active
             ; ActiveOrInert = ActiveOrInert
             ; applyCast = applyCast
             ; funSrc = funSrc
             ; pairSrc = pairSrc
             ; sumSrc = sumSrc
             ; dom = dom
             ; cod = cod
             ; fstC = fstC
             ; sndC = sndC
             ; inlC = inlC
             ; inrC = inrC
             ; baseNotInert = baseNotInert
             }
