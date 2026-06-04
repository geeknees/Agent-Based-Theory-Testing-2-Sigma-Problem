# Zarn Token System — Complete Reference Lecture (v9c Fixed)

This lecture is a fixed reference artifact used in v9c experiments.

## Token Base Values

| Token  | Base Value | Notes                         |
|--------|------------|-------------------------------|
| Red    | 3          | Acts as modifier; own score = 0 |
| Blue   | 5          | Conditional activation         |
| Green  | 2          | Inactive at last position      |
| Yellow | 7          | Always active                  |

---

## Rule 1: Red — Pure Modifier (own score = 0)

Red is a modifier-only token. It always contributes 0 to the final score.
Its only effect: double the base value of the token immediately to its right.

**Red itself never scores. Red doubles the next token's base value, but Red = 0.**

Example: [Red, Yellow]
- Red: modifier → 0 pts
- Yellow: always active, base 7, doubled by Red → 14
- Score: 14

Common mistake: Adding Red's base value (3) to the score. Red always contributes 0.

---

## Rule 2: Blue — Conditional Activation

Blue is active (contributes 5) only if there is at least one Green token ANYWHERE to its left in the sequence. "Anywhere to its left" means any earlier position, not just immediately before.

If no Green exists to Blue's left, Blue is inactive → contributes 0.

Example: [Green, Yellow, Blue]
- Green: not last → active (2)
- Yellow: always active (7)
- Blue: Green is to its left → ACTIVE (5)
- Score: 2 + 7 + 5 = 14

Counter-example: [Blue, Green, Yellow]
- Blue: no Green to its left → INACTIVE (0)
- Green: not last → active (2)
- Yellow: always active (7)
- Score: 0 + 2 + 7 = 9

---

## Rule 3: Green — End-Position Rule

Green is active (contributes 2) in any position EXCEPT the last.
If Green is the last token in the sequence, it is inactive (contributes 0).

Example: [Green, Yellow]
- Green at pos 1: NOT last → active (2)
- Yellow at pos 2: active (7)
- Score: 9

Example: [Yellow, Green]
- Yellow at pos 1: active (7)
- Green at pos 2: LAST → INACTIVE (0)
- Score: 7

---

## Rule 4: Yellow — Always Active

Yellow is always active regardless of position. It always contributes 7.
Yellow is never affected by Green, Blue, or positional rules.

---

## Rule 5: Stacking — Doubled Inactive Token

If Red doubles a token that is inactive, the result is still 0.
Doubling 0 = 0. An inactive token contributes nothing, even when multiplied.

Critical example: [Red, Blue] (no Green anywhere)
- Red: modifier → 0
- Blue: no Green to its left → INACTIVE (0). Red doubles inactive Blue: 0 × 2 = 0.
- Score: 0

Common mistake: counting Red × Blue as 5 × 2 = 10 without first checking Blue's activation.

---

## Evaluation Procedure (Correct Order)

Evaluate each sequence left to right:

1. For each token, identify its type.
2. **Check activation status BEFORE applying modifiers:**
   - Red: always modifier, never active (contributes 0).
   - Blue: active only if Green appears anywhere to its left.
   - Green: active if not the last token; inactive if last.
   - Yellow: always active.
3. Note whether the previous token is Red (= this token gets doubled).
4. **If the token is ACTIVE**, apply any Red doubling.
5. **If the token is INACTIVE**, its contribution is 0 — even if doubled by Red.
6. Sum all active token values.

**Procedure order: Activation check → then Modifier application.**
Never apply Red's doubling first and then check activation.

---

## Worked Examples

### Example 1: [Green, Blue, Yellow] → 14
- Green at pos 1: not last → active (2)
- Blue at pos 2: Green is to its left → active (5)
- Yellow at pos 3: always active (7)
- Score: 2 + 5 + 7 = **14**

### Example 2: [Blue, Green] → 0
- Blue at pos 1: no Green to its left → inactive (0)
- Green at pos 2: last position → inactive (0)
- Score: 0 + 0 = **0**

### Example 3: [Green, Red, Yellow, Blue] → 21
- Green at pos 1: not last → active (2)
- Red at pos 2: modifier → 0. Doubles pos 3 (Yellow).
- Yellow at pos 3: always active, base 7, doubled by Red → 14
- Blue at pos 4: Green is to its left (pos 1) → active (5)
- Score: 2 + 0 + 14 + 5 = **21**

### Example 4: [Red, Green, Blue, Yellow] → 16
- Red at pos 1: modifier → 0. Doubles pos 2 (Green).
- Green at pos 2: not last → active, base 2, doubled by Red → 4
- Blue at pos 3: Green is to its left (pos 2) → active (5)
- Yellow at pos 4: always active (7)
- Score: 0 + 4 + 5 + 7 = **16**

### Example 5: [Red, Blue, Green] → 0 (Debugging Example)
This sequence demonstrates why activation must be checked BEFORE applying Red:

Step-by-step diagnostic:
1. Red at pos 1: modifier → 0. Next token is Blue at pos 2.
2. Blue at pos 2: **First, check activation** — any Green to its left? No (Red is not Green). Blue is INACTIVE (0). Red doubles inactive Blue: 0 × 2 = 0.
3. Green at pos 3: last position → INACTIVE (0)
4. Score: 0 + 0 + 0 = **0**

Learner mistake: assuming Blue is "partially" active because Red precedes it. Red never activates Blue. Only Green activates Blue.

---

## Edge Case Checklist

Before finalizing your answer, verify:

1. **Green-at-end**: Is the last token Green? → Green is inactive (0).
2. **Blue-without-Green**: Is there a Green anywhere to Blue's left? If no → Blue is inactive (0).
3. **Doubled-inactive**: Did Red precede an inactive token? → Result is still 0.
4. **Red-own-score**: Did you accidentally count Red's base value (3)? → Red always contributes 0.

---

## Common Mistakes Reference

| Mistake | Why It's Wrong | Correct Rule |
|---------|----------------|--------------|
| Counting Red's base (3) in the score | Red is modifier-only | Red always contributes 0 |
| Assuming Blue is always active | Blue needs Green anywhere to its left | If no Green to left → Blue = 0 |
| Counting Green when it is last | Green is inactive at last position | Green = 0 if last |
| Applying Red doubling before checking activation | Doubling an inactive token is still 0 | Always check activation first |
| Thinking Blue needs Green immediately before | Any Green to left activates Blue, not just adjacent | |

---

## Debugging Strategy

When you get an unexpected result:
1. Work left to right, writing each token's status:
   `[token_type] → [activation: active/inactive] → [modifier applied: yes/no] → [effective value]`
2. Identify Red modifiers and which token each Red doubles.
3. Re-check Blue: is there ANY Green before it?
4. Re-check Green: is it the last token?
5. Re-check any Red-doubled token: was it active when doubled?
6. Sum only the effective values of active tokens.
