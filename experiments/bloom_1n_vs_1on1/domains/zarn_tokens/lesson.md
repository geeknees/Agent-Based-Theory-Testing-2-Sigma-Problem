# Zarn Token Rules

A **Zarn sequence** is an ordered list of colored tokens, each with a base value.

## Token Base Values

| Token       | Base Value |
|-------------|------------|
| Red Zarn    | 3          |
| Blue Zarn   | 5          |
| Green Zarn  | 2          |
| Yellow Zarn | 7          |

## Modifier Rules

1. **Red Modifier**: A Red Zarn doubles the base value of the token immediately to its right. The Red Zarn itself contributes 0 to the score (it is a pure modifier).
2. **Blue Activation**: A Blue Zarn is active (counts its value) only if there is at least one Green Zarn anywhere to its left in the sequence. Otherwise it is inactive (counts 0).
3. **Green End Rule**: A Green Zarn is inactive if it is the last token in the sequence. In any other position it is active.
4. **Stacking**: If a Red Zarn doubles a Blue Zarn that is itself inactive, the doubled value is also 0.
5. **Score**: The final score is the sum of all active token values after applying all modifiers.

## Worked Examples

**Example A**: [Red, Blue, Green]

- Position 1: Red → modifier only (0)
- Position 2: Blue → no Green to its left, so inactive (0). But Red doubles it → doubled(0) = 0.
- Position 3: Green → last position, so inactive (0)
- Score: 0

**Example B**: [Green, Blue, Yellow]

- Position 1: Green → not last, so active (2)
- Position 2: Blue → Green is to its left, so active (5)
- Position 3: Yellow → active, no modifier (7)
- Score: 2 + 5 + 7 = 14

**Example C**: [Green, Red, Yellow, Blue]

- Position 1: Green → not last, active (2)
- Position 2: Red → modifier only (0). Doubles position 3.
- Position 3: Yellow → base 7, doubled by Red → 14
- Position 4: Blue → Green is to its left (position 1), active → 5
- Score: 2 + 0 + 14 + 5 = 21

**Key things to remember:**
- Red contributes 0 but doubles the token to its right.
- Blue needs a Green to its left to be active.
- A Green at the very end is inactive.
- A doubled inactive token is still 0.
