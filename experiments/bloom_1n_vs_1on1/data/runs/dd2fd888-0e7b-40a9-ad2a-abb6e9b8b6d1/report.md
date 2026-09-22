# Experiment Report (v2)

## Run Metadata

| Field | Value |
|-------|-------|
| run_id | dd2fd888-0e7b-40a9-ad2a-abb6e9b8b6d1 |
| date | 2026-05-23 |
| models | claude-sonnet-4-6 |
| n_classroom |  |
| n_tutoring |  |
| domain | zarn_tokens |
| tutoring_turns | 4 |

## Ceiling Effect Summary

> Classification: too_easy (all≥90%), education_sensitive (edu>baseline+10pp), condition_sensitive (tutoring≠classroom by >10pp), too_hard (all<30%), unclear

| Task Type | Difficulty | No-Ed Correct% | Classroom Correct% | Tutoring Correct% | Classification |
|-----------|-----------|----------------|-------------------|-------------------|----------------|
| recall | L1 | 0% | 38% | 75% | condition_sensitive |
| edge_case | L2 | 0% | 81% | 88% | education_sensitive |
| rule_interaction | L3 | 0% | 63% | 0% | education_sensitive |
| debugging | L4 | 0% | 88% | 33% | condition_sensitive |
| short_rule_induction | L6 | 0% | 38% | 50% | condition_sensitive |

**No ceiling effects detected.**

## Score by Condition (answer_correct rate)

| Condition | Learners | Attempts | Correct% |
|-----------|---------|---------|---------|
| classroom_forced_checkin | 4 | 32 | 53% |
| classroom_public_qa | 4 | 32 | 88% |
| one_on_one_tutoring | 4 | 32 | 50% |

## Score by Task Type × Condition

| Task Type | Difficulty | No-Ed Correct% | Classroom Correct% | Tutoring Correct% |
|-----------|-----------|----------------|-------------------|-------------------|
| debugging | L4 | 0% | 88% | 33% |
| edge_case | L2 | 0% | 81% | 88% |
| recall | L1 | 0% | 38% | 75% |
| rule_interaction | L3 | 0% | 63% | 0% |
| short_rule_induction | L6 | 0% | 38% | 50% |

## Score by Difficulty Level

| Level | Task Types | No-Ed Correct% | Classroom Correct% | Tutoring Correct% |
|-------|-----------|----------------|-------------------|-------------------|
| L1 | recall | 0% | 38% | 75% |
| L2 | edge_case | 0% | 81% | 88% |
| L3 | rule_interaction | 0% | 63% | 0% |
| L4 | debugging | 0% | 94% | 50% |
| L5 | debugging | 0% | 75% | 0% |
| L6 | short_rule_induction | 0% | 38% | 50% |

## Token Usage by Phase (estimated)

| Phase | Input | Output | Total |
|-------|-------|--------|-------|
| education_classroom_public_qa | 738 | 900 | 1638 |
| education_classroom_forced_checkin | 9726 | 670 | 10396 |
| education_tutoring | 30465 | 4668 | 35133 |
| memory | 15680 | 2357 | 18037 |
| evaluation | 56114 | 14505 | 70619 |
| **TOTAL** | | | **135823** |

| Metric | Value |
|--------|-------|
| Classroom correct% | 70% |
| Tutoring correct% | 50% |
| Tutoring gain | -20.3pp |
| Extra education tokens (tutoring vs classroom) | 23099 |
| Tutoring gain per 1k extra tokens | -0.88pp |

## Score by Learner Profile

### By Ability

| Ability | Correct% |
|---------|---------|
| unknown | 64% |

### By Misconception

| Misconception | Correct% |
|---------------|---------|
| unknown | 64% |

### By Interest

| Interest | Correct% |
|----------|---------|
| unknown | 64% |

## Score Variance by Condition (std dev of per-learner correct%)

| Condition | Std Dev |
|-----------|--------|
| classroom_forced_checkin | 0.12 |
| classroom_public_qa | 0.102 |
| one_on_one_tutoring | 0.177 |

**Token cost per correct answer:** 2227 tokens

## Heterogeneity Interpretation

- **classroom_advantage_under_homogeneity** ✓

## Score by Learner Type

| Type | Correct% |
|------|---------|
| passive_listener | 64% |

## Misconception Correction by Condition

| Condition | Correction Rate | Avg Remaining Misconceptions |
|-----------|----------------|------------------------------|
| classroom_forced_checkin | 0% | 0.0 |
| classroom_public_qa | 0% | 0.0 |
| one_on_one_tutoring | 75% | 0.25 |

## Confidence Calibration

| Metric | Rate |
|--------|------|
| High-confidence wrong | 20% |
| Abstention | 9% |

## Passive Listener Rescue Effect

| Condition | Learners | Correct% |
|-----------|---------|---------|
| classroom_public_qa | 4 | 88% |
| classroom_forced_checkin | 4 | 53% |
| one_on_one_tutoring | 4 | 50% |

## Recommended Next Steps

- No ceiling effects at current difficulty. Increase n to improve statistical power.

## Limitations

- Token counts are estimated (chars/4). Actual API token counts may differ by ±20%.
- Auto-scoring uses keyword matching for mistake detection — may under-count partial credit.
- LLM agents are not human learners. Learning is operationalized as condition-specific memory from transcripts.
- Small n. Results are exploratory.

