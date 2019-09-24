open import Types
open import CastStructure

open import Data.Nat
open import Data.Product using (_×_; proj₁; proj₂; Σ; Σ-syntax) renaming (_,_ to ⟨_,_⟩)
open import Data.Sum using (_⊎_; inj₁; inj₂)
open import Data.Bool
open import Variables
open import Relation.Nullary using (¬_)
open import Relation.Nullary.Negation using (contradiction)
open import Relation.Binary.PropositionalEquality using (_≡_;_≢_; refl; trans; sym; cong; cong₂; cong-app)
open import Data.Empty using (⊥; ⊥-elim)

module EquivCast
  (CastCalc₁ : CastStruct)
  (CastCalc₂ : CastStruct)
  where

  module CC₁ = CastCalc CastCalc₁
  module CC₂ = CastCalc CastCalc₂
  open CastStruct CastCalc₁ using () renaming (Cast to Cast₁)
  open CastStruct CastCalc₂ using () renaming (Cast to Cast₂)
  open CC₁ using (`_; _·_; $_) renaming (
       _⊢_ to _⊢₁_; ƛ_ to ƛ₁_; _⟨_⟩ to _⟨_⟩₁;
       if to if₁; cons to cons₁; fst to fst₁; snd to snd₁;
       inl to inl₁; inr to inr₁; case to case₁; blame to blame₁)
  open CC₂ using ()
     renaming (
       _⊢_ to _⊢₂_; `_ to ``_; ƛ_ to ƛ₂_; _·_ to _●_; $_ to #_;
       if to if₂; cons to cons₂; fst to fst₂; snd to snd₂;
       inl to inl₂; inr to inr₂; case to case₂; _⟨_⟩ to _⟨_⟩₂;
       blame to blame₂)

  module Equiv 
    (EqCast : ∀{A B} → Cast₁ (A ⇒ B) → Cast₂ (A ⇒ B) → Set)
    where

    data _≈_ : ∀{Γ A} → Γ ⊢₁ A → Γ ⊢₂ A → Set where
      ≈-var : ∀ {Γ}{A}{x : Γ ∋ A} → (` x) ≈ (`` x)
      ≈-lam : ∀ {Γ}{A B}{M₁ : Γ , A ⊢₁ B}{M₂ : Γ , A ⊢₂ B}
            → M₁ ≈ M₂ → (ƛ₁ M₁) ≈ (ƛ₂ M₂)
      ≈-app : ∀ {Γ}{A B}{L₁ : Γ ⊢₁ A ⇒ B}{L₂ : Γ ⊢₂ A ⇒ B}
                {M₁ : Γ ⊢₁ A}{M₂ : Γ ⊢₂ A}
            → L₁ ≈ L₂ → M₁ ≈ M₂ → (L₁ · M₁) ≈ (L₂ ● M₂)
      ≈-lit : ∀ {Γ}{A}{k : rep A}{f : Prim A}
            → ($_ {Γ}{A} k {f}) ≈ (#_ {Γ}{A} k {f})
      ≈-if : ∀ {Γ}{A}
                {N₁ : Γ ⊢₁ ` 𝔹}{N₂ : Γ ⊢₂ ` 𝔹}
                {L₁ : Γ ⊢₁ A}{L₂ : Γ ⊢₂ A}
                {M₁ : Γ ⊢₁ A}{M₂ : Γ ⊢₂ A}
            → N₁ ≈ N₂ → L₁ ≈ L₂ → M₁ ≈ M₂
            → (if₁ N₁ L₁ M₁) ≈ (if₂ N₂ L₂ M₂)
      ≈-cons : ∀ {Γ}{A B}{L₁ : Γ ⊢₁ A}{L₂ : Γ ⊢₂ A}
                {M₁ : Γ ⊢₁ B}{M₂ : Γ ⊢₂ B}
            → L₁ ≈ L₂ → M₁ ≈ M₂ → (cons₁ L₁ M₁) ≈ (cons₂ L₂ M₂)
      ≈-fst : ∀ {Γ}{A B}{M₁ : Γ ⊢₁ A `× B}{M₂ : Γ ⊢₂ A `× B}
            → M₁ ≈ M₂ → (fst₁ M₁) ≈ (fst₂ M₂)
      ≈-snd : ∀ {Γ}{A B}{M₁ : Γ ⊢₁ A `× B}{M₂ : Γ ⊢₂ A `× B}
            → M₁ ≈ M₂ → (snd₁ M₁) ≈ (snd₂ M₂)
      ≈-inl : ∀ {Γ}{A B}{M₁ : Γ ⊢₁ A}{M₂ : Γ ⊢₂ A}
            → M₁ ≈ M₂ → (inl₁ {B = B} M₁) ≈ (inl₂ M₂)
      ≈-inr : ∀ {Γ}{A B}{M₁ : Γ ⊢₁ B}{M₂ : Γ ⊢₂ B}
            → M₁ ≈ M₂ → (inr₁ {A = A} M₁) ≈ (inr₂ M₂)
      ≈-case : ∀ {Γ}{A B C}
                {N₁ : Γ ⊢₁ A `⊎ B}{N₂ : Γ ⊢₂ A `⊎ B}
                {L₁ : Γ ⊢₁ A ⇒ C}{L₂ : Γ ⊢₂ A ⇒ C}
                {M₁ : Γ ⊢₁ B ⇒ C}{M₂ : Γ ⊢₂ B ⇒ C}
            → N₁ ≈ N₂ → L₁ ≈ L₂ → M₁ ≈ M₂
            → (case₁ N₁ L₁ M₁) ≈ (case₂ N₂ L₂ M₂)
      ≈-cast : ∀ {Γ}{A B}{M₁ : Γ ⊢₁ A}{M₂ : Γ ⊢₂ A}
                 {c₁ : Cast₁ (A ⇒ B)}{c₂ : Cast₂ (A ⇒ B)}
            → M₁ ≈ M₂ → EqCast c₁ c₂
            → (_⟨_⟩₁ M₁ c₁) ≈ (_⟨_⟩₂ M₂ c₂)
      ≈-blame : ∀ {Γ}{A}{ℓ} → (blame₁{Γ}{A} ℓ) ≈ (blame₂{Γ}{A} ℓ)
