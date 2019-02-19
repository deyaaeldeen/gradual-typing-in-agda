open import Types
open import Data.Nat
open import Data.Product using (_×_; proj₁; proj₂; Σ; Σ-syntax) renaming (_,_ to ⟨_,_⟩)
open import Data.Sum using (_⊎_; inj₁; inj₂)
open import Data.Bool
open import Variables
open import Relation.Nullary using (¬_)
open import Relation.Nullary.Negation using (contradiction)
open import Relation.Binary.PropositionalEquality using (_≡_;_≢_; refl; trans; sym; cong; cong₂; cong-app)
open import Data.Empty using (⊥; ⊥-elim)

module EfficientParamCasts
  (Cast : Type → Set)
  (Inert : ∀{A} → Cast A → Set)
  (Active : ∀{A} → Cast A → Set)  
  (ActiveOrInert : ∀{A} → (c : Cast A) → Active c ⊎ Inert c)
  where

  import ParamCastCalculus
  module CastCalc = ParamCastCalculus Cast
  open CastCalc

  data Value : ∀ {Γ A} → Γ ⊢ A → Set where

    V-ƛ : ∀ {Γ A B} {N : Γ , A ⊢ B}
        ---------------
      → Value (ƛ A , N)

    V-const : ∀ {Γ} {A : Type} {k : rep A} {f : Prim A}
        ------------------------
      → Value {Γ} {A} (($ k){f})

    V-pair : ∀ {Γ A B} {V : Γ ⊢ A} {W : Γ ⊢ B}
      → Value V → Value W
        -----------------
      → Value (cons V W)

    V-inl : ∀ {Γ A B} {V : Γ ⊢ A}
      → Value V
        ---------------------------
      → Value {Γ} {A `⊎ B} (inl V)

    V-inr : ∀ {Γ A B} {V : Γ ⊢ B}
      → Value V
        -----------------
      → Value {Γ} {A `⊎ B} (inr V)

    V-cast : ∀ {Γ : Context} {A B : Type} {V : Γ ⊢ A} {c : Cast (A ⇒ B)}
        {i : Inert c}
      → Value V
        -----------------------------------
      → Value (V ⟨ c ⟩)


  canonical⋆ : ∀ {Γ} → (M : Γ ⊢ ⋆) → (Value M)
             → Σ[ A ∈ Type ] Σ[ M' ∈ (Γ ⊢ A) ] Σ[ c ∈ (Cast (A ⇒ ⋆)) ] Inert c × (M ≡ (M' ⟨ c ⟩))
  canonical⋆ .($ _) (V-const {k = ()})  
  canonical⋆ .(_ ⟨ _ ⟩) (V-cast{Γ}{A}{B}{V}{c}{i} v) = ⟨ A , ⟨ V , ⟨ c , ⟨ i , refl ⟩ ⟩ ⟩ ⟩


  module Reduction
    (applyCast : ∀{Γ A B} → (M : Γ ⊢ A) → Value M → (c : Cast (A ⇒ B)) → ∀ {a : Active c} → Γ ⊢ B)
    (funCast : ∀{Γ A A' B'} → Γ ⊢ A → (c : Cast (A ⇒ (A' ⇒ B'))) → ∀ {i : Inert c} → Γ ⊢ A' → Γ ⊢ B')
    (fstCast : ∀{Γ A A' B'} → Γ ⊢ A → (c : Cast (A ⇒ (A' `× B'))) → ∀ {i : Inert c} → Γ ⊢ A')
    (sndCast : ∀{Γ A A' B'} → Γ ⊢ A → (c : Cast (A ⇒ (A' `× B'))) → ∀ {i : Inert c} → Γ ⊢ B')
    (caseCast : ∀{Γ A A' B' C} → Γ ⊢ A → (c : Cast (A ⇒ (A' `⊎ B'))) → ∀ {i : Inert c} → Γ ⊢ A' ⇒ C → Γ ⊢ B' ⇒ C → Γ ⊢ C)
    (baseNotInert : ∀ {A B} → (c : Cast (A ⇒ B)) → Base B → ¬ Inert c)
    (compose : ∀{A B C} → (c : Cast (A ⇒ B)) → (d : Cast (B ⇒ C)) → Cast (A ⇒ C))
    where

    data Frame : {Γ : Context} → Type → Type → Set where

      F-·₁ : ∀ {Γ A B}
        → Γ ⊢ A
        → Frame {Γ} (A ⇒ B) B

      F-·₂ : ∀ {Γ A B}
        → (M : Γ ⊢ A ⇒ B) → ∀{v : Value {Γ} M}
        → Frame {Γ} A B

      F-if : ∀ {Γ A}
        → Γ ⊢ A
        → Γ ⊢ A    
        → Frame {Γ} 𝔹 A

      F-×₁ : ∀ {Γ A B}
        → Γ ⊢ A
        → Frame {Γ} B (A `× B)

      F-×₂ : ∀ {Γ A B}
        → Γ ⊢ B
        → Frame {Γ} A (A `× B)

      F-fst : ∀ {Γ A B}
        → Frame {Γ} (A `× B) A

      F-snd : ∀ {Γ A B}
        → Frame {Γ} (A `× B) B

      F-inl : ∀ {Γ A B}
        → Frame {Γ} A (A `⊎ B)

      F-inr : ∀ {Γ A B}
        → Frame {Γ} B (A `⊎ B)

      F-case : ∀ {Γ A B C}
        → Γ ⊢ A ⇒ C
        → Γ ⊢ B ⇒ C
        → Frame {Γ} (A `⊎ B) C

    plug : ∀{Γ A B} → Γ ⊢ A → Frame {Γ} A B → Γ ⊢ B
    plug L (F-·₁ M)      = L · M
    plug M (F-·₂ L)      = L · M
    plug L (F-if M N)    = if L M N
    plug L (F-×₁ M)      = cons M L
    plug M (F-×₂ L)      = cons M L
    plug M (F-fst)      = fst M
    plug M (F-snd)      = snd M
    plug M (F-inl)      = inl M
    plug M (F-inr)      = inr M
    plug L (F-case M N) = case L M N

    data BypassCast : Set where
      allow : BypassCast
      disallow : BypassCast

    infix 2 _/_—→_
    data _/_—→_ : ∀ {Γ A} → BypassCast → (Γ ⊢ A) → (Γ ⊢ A) → Set where

      switch : ∀ {Γ A} {M M′ : Γ ⊢ A} 
        → disallow / M —→ M′
          ------------------
        → allow / M —→ M′       

      ξ : ∀ {Γ A B} {M M′ : Γ ⊢ A} {F : Frame A B}
        → allow / M —→ M′
          ---------------------
        → disallow / plug M F —→ plug M′ F

      ξ-cast : ∀ {Γ A B} {c : Cast (A ⇒ B)} {M M′ : Γ ⊢ A}
        → disallow / M —→ M′
          -----------------------------
        → allow / (M ⟨ c ⟩) —→ M′ ⟨ c ⟩

      ξ-blame : ∀ {Γ A B} {F : Frame {Γ} A B} {ℓ}
          ---------------------------
        → disallow / plug (blame ℓ) F —→ blame ℓ

      ξ-cast-blame : ∀ {Γ A B} {c : Cast (A ⇒ B)} {ℓ}
          ----------------------------------------------
        → allow / ((blame {Γ}{A} ℓ) ⟨ c ⟩) —→ blame ℓ

      β : ∀ {Γ A B} {N : Γ , A ⊢ B} {W : Γ ⊢ A}
        → Value W
          ------------------------
        → disallow / (ƛ A , N) · W —→ N [ W ]

      δ : ∀ {Γ : Context} {A B} {f : rep A → rep B} {k : rep A} {ab} {a} {b}
          --------------------------------------------
        → disallow / ($_ {Γ} f {ab}) · (($ k){a}) —→ ($ (f k)){b}

      β-if-true : ∀{Γ A} {M : Γ ⊢ A} {N : Γ ⊢ A}{f}
          --------------------------------------
        → disallow / if (($ true){f}) M N —→ M

      β-if-false : ∀ {Γ A} {M : Γ ⊢ A} {N : Γ ⊢ A}{f}
          ---------------------
        → disallow / if (($ false){f}) M N —→ N

      β-fst : ∀ {Γ A B} {V : Γ ⊢ A} {W : Γ ⊢ B}
        → Value V → Value W
          --------------------
        → disallow / fst (cons V W) —→ V

      β-snd :  ∀ {Γ A B} {V : Γ ⊢ A} {W : Γ ⊢ B}
        → Value V → Value W
          --------------------
        → disallow / snd (cons V W) —→ W

      β-caseL : ∀ {Γ A B C} {V : Γ ⊢ A} {L : Γ ⊢ A ⇒ C} {M : Γ ⊢ B ⇒ C}
        → Value V
          --------------------------
        → disallow / case (inl V) L M —→ L · V

      β-caseR : ∀ {Γ A B C} {V : Γ ⊢ B} {L : Γ ⊢ A ⇒ C} {M : Γ ⊢ B ⇒ C}
        → Value V
          --------------------------
        → disallow / case (inr V) L M —→ M · V

      cast : ∀ {Γ A B} {V : Γ ⊢ A} {c : Cast (A ⇒ B)}
        → (v : Value V) → {a : Active c}
          ----------------------------
        → disallow / V ⟨ c ⟩ —→ applyCast V v c {a}

      fun-cast : ∀ {Γ A A' B'} {V : Γ ⊢ A} {W : Γ ⊢ A'}
          {c : Cast (A ⇒ (A' ⇒ B'))}
        → Value V → Value W → {i : Inert c}
          ---------------------------------
        → disallow / (V ⟨ c ⟩) · W —→ funCast V c {i} W 

      fst-cast : ∀ {Γ A A' B'} {V : Γ ⊢ A}
          {c : Cast (A ⇒ (A' `× B'))}
        → Value V → {i : Inert c}
          ---------------------------------
        → disallow / fst (V ⟨ c ⟩) —→ fstCast V c {i}

      snd-cast : ∀ {Γ A A' B'} {V : Γ ⊢ A}
          {c : Cast (A ⇒ (A' `× B'))}
        → Value V → {i : Inert c}
          ---------------------------------
        → disallow / snd (V ⟨ c ⟩) —→ sndCast V c {i}

      case-cast : ∀ { Γ A A' B' C} {V : Γ ⊢ A}
          {W : Γ ⊢ A' ⇒ C } {W' : Γ ⊢ B' ⇒ C}
          {c : Cast (A ⇒ (A' `⊎ B'))}
        → Value V → {i : Inert c}
          --------------------------------------------
        → disallow / case (V ⟨ c ⟩) W W' —→ caseCast V c {i} W W'

      compose-casts : ∀{Γ A B C} {M : Γ ⊢ A } {c : Cast (A ⇒ B)} {d : Cast (B ⇒ C)}
          ------------------------------------------
        → disallow / (M ⟨ c ⟩) ⟨ d ⟩ —→ M ⟨ compose c d ⟩


    data Error : ∀ {Γ A} → Γ ⊢ A → Set where

      E-blame : ∀ {Γ}{A}{ℓ}
          ---------------------
        → Error{Γ}{A} (blame ℓ)


    data Progress {A} (M : ∅ ⊢ A) : Set where

      step : ∀ {N : ∅ ⊢ A}
        → disallow / M —→ N
          -------------
        → Progress M

      stepc : ∀ {N : ∅ ⊢ A}
        → allow / M —→ N
          -------------
        → Progress M

      done :
          Value M
          ----------
        → Progress M

      error :
          Error M
          ----------
        → Progress M

    data CastOrNot : ∀ {A} → (M : ∅ ⊢ A) → Set where
      iscast : ∀{A B}
        → (M' : ∅ ⊢ B) → (c : Cast (B ⇒ A))
          --------------------------------
        → CastOrNot (M' ⟨ c ⟩)
      notcast : ∀ {A } {M : ∅ ⊢ A}{B} {M' : ∅ ⊢ B} {c : Cast (B ⇒ A)}
         → M ≢ (M' ⟨ c ⟩)
           --------------
         → CastOrNot M

    progress : ∀ {A} → (M : ∅ ⊢ A) → Progress M
    progress (` ())
    progress (ƛ A , M) = done V-ƛ
    progress (_·_ {∅}{A}{B} M₁ M₂) with progress M₁
    ... | step R = step (ξ {F = F-·₁ M₂} (switch R))
    ... | stepc R = step (ξ {F = F-·₁ M₂} R)
    ... | error E-blame = step (ξ-blame {F = F-·₁ M₂})
    ... | done V₁ with progress M₂
    ...     | step R' = step (ξ {F = (F-·₂ M₁){V₁}} (switch R'))
    ...     | stepc R' = step (ξ {F = (F-·₂ M₁){V₁}} R')
    ...     | error E-blame = step (ξ-blame {F = (F-·₂ M₁){V₁}})
    ...     | done V₂ with V₁
    ...         | V-ƛ = step (β V₂)
    ...         | V-cast {∅}{A = A'}{B = A ⇒ B}{V}{c}{i} v =
                    step (fun-cast{∅}{A'}{A}{B}{V}{M₂}{c} v V₂ {i})
    ...         | V-const {k = k₁} {f = f₁} with V₂
    ...             | V-const {k = k₂} {f = f₂} =
                      step (δ {ab = f₁} {a = f₂} {b = P-Fun2 f₁})
    ...             | V-ƛ = contradiction f₁ ¬P-Fun
    ...             | V-pair v w = contradiction f₁ ¬P-Pair
    ...             | V-cast {∅}{A'}{A}{W}{c}{i} w =
                       contradiction i (baseNotInert c (P-Fun1 f₁))
    ...             | V-inl v = contradiction f₁ ¬P-Sum
    ...             | V-inr v = contradiction f₁ ¬P-Sum
    progress ($ k) = done V-const
    progress (if L M N) with progress L
    ... | step R = step (ξ{F = F-if M N} (switch R))
    ... | stepc R = step (ξ{F = F-if M N} R)
    ... | error E-blame = step (ξ-blame{F = F-if M N})
    ... | done (V-const {k = true}) = step β-if-true
    ... | done (V-const {k = false}) = step β-if-false
    ... | done (V-cast {c = c} {i = i} v) =
            contradiction i (baseNotInert c B-Bool)
    progress (_⟨_⟩ {∅}{A}{B} M c) with progress M
    ... | step {N} R = stepc (ξ-cast R)
    ... | stepc (switch R) = stepc (ξ-cast R)
    ... | stepc (ξ-cast R) = step compose-casts
    ... | stepc (ξ-cast-blame) = step compose-casts
    ... | error E-blame = stepc ξ-cast-blame
    ... | done v with ActiveOrInert c
    ...    | inj₁ a = step (cast v {a})
    ...    | inj₂ i = done (V-cast {c = c} {i = i} v)
    progress {C₁ `× C₂} (cons M₁ M₂) with progress M₁
    ... | step R = step (ξ {F = F-×₂ M₂} (switch R))
    ... | stepc R = step (ξ {F = F-×₂ M₂} R)
    ... | error E-blame = step (ξ-blame {F = F-×₂ M₂})
    ... | done V with progress M₂
    ...    | step {N} R' = step (ξ {F = F-×₁ M₁} (switch R'))
    ...    | stepc R' = step (ξ {F = F-×₁ M₁} R')
    ...    | done V' = done (V-pair V V')
    ...    | error E-blame = step (ξ-blame{F = F-×₁ M₁})
    progress (fst {Γ}{A}{B} M) with progress M
    ... | step R = step (ξ {F = F-fst} (switch R))
    ... | stepc R = step (ξ {F = F-fst} R)
    ... | error E-blame = step (ξ-blame{F = F-fst})
    ... | done V with V
    ...     | V-cast {c = c} {i = i} v = step (fst-cast {c = c} v {i = i})
    ...     | V-pair {V = V₁}{W = V₂} v w = step {N = V₁} (β-fst v w)
    ...     | V-const {k = k} with k
    ...        | ()
    progress (snd {Γ}{A}{B} M) with progress M
    ... | step R = step (ξ {F = F-snd} (switch R))
    ... | stepc R = step (ξ {F = F-snd} R)
    ... | error E-blame = step (ξ-blame{F = F-snd})
    ... | done V with V
    ...     | V-cast {c = c} {i = i} v = step (snd-cast {c = c} v {i = i})
    ...     | V-pair {V = V₁}{W = V₂} v w = step {N = V₂} (β-snd v w)
    ...     | V-const {k = k} with k
    ...        | ()
    progress (inl M) with progress M
    ... | step R = step (ξ {F = F-inl} (switch R))
    ... | stepc R = step (ξ {F = F-inl} R)
    ... | error E-blame = step (ξ-blame {F = F-inl})
    ... | done V = done (V-inl V)

    progress (inr M) with progress M
    ... | step R = step (ξ {F = F-inr} (switch R))
    ... | stepc R = step (ξ {F = F-inr} R)
    ... | error E-blame = step (ξ-blame {F = F-inr})
    ... | done V = done (V-inr V)

    progress (case L M N) with progress L
    ... | step R = step (ξ {F = F-case M N} (switch R))
    ... | stepc R = step (ξ {F = F-case M N} R)
    ... | error E-blame = step (ξ-blame {F = F-case M N})
    ... | done V with V
    ...    | V-cast {c = c} {i = i} v = step (case-cast {c = c} v {i = i})
    ...    | V-const {k = k} = ⊥-elim k
    ...    | V-inl v = step (β-caseL v)
    ...    | V-inr v = step (β-caseR v)

    progress (blame ℓ) = error E-blame

