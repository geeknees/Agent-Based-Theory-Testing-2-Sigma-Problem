# Experiment Report (v2)

## Run Metadata

| Field | Value |
|-------|-------|
| run_id | 6ea56fa1-4852-42ac-bf60-076c756b8700 |
| date | 2026-05-21 |
| models | claude-haiku-4-5-20251001 |
| n_classroom |  |
| n_tutoring |  |
| domain | zarn_tokens |
| tutoring_turns | 4 |

## Ceiling Effect Summary

> Classification: too_easy (all≥90%), education_sensitive (edu>baseline+10pp), condition_sensitive (tutoring≠classroom by >10pp), too_hard (all<30%), unclear

| Task Type | Difficulty | No-Ed Correct% | Classroom Correct% | Tutoring Correct% | Classification |
|-----------|-----------|----------------|-------------------|-------------------|----------------|
| recall | L1 | 0% | 0% | 0% | too_hard |
| edge_case | L2 | 0% | 0% | 0% | too_hard |
| rule_interaction | L3 | 0% | 0% | 0% | too_hard |
| debugging | L4 | 0% | 0% | 0% | too_hard |
| short_rule_induction | L6 | 0% | 0% | 0% | too_hard |

**No ceiling effects detected.**

## Score by Condition (answer_correct rate)

| Condition | Learners | Attempts | Correct% |
|-----------|---------|---------|---------|
| classroom_forced_checkin | 1 | 8 | 50% |
| classroom_public_qa | 1 | 8 | 100% |
| one_on_one_tutoring | 1 | 8 | 13% |

## Score by Task Type × Condition

| Task Type | Difficulty | No-Ed Correct% | Classroom Correct% | Tutoring Correct% |
|-----------|-----------|----------------|-------------------|-------------------|
| debugging | L4 | 0% | 0% | 0% |
| edge_case | L2 | 0% | 0% | 0% |
| recall | L1 | 0% | 0% | 0% |
| rule_interaction | L3 | 0% | 0% | 0% |
| short_rule_induction | L6 | 0% | 0% | 0% |

## Score by Difficulty Level

| Level | Task Types | No-Ed Correct% | Classroom Correct% | Tutoring Correct% |
|-------|-----------|----------------|-------------------|-------------------|
| L1 | recall | 0% | 0% | 0% |
| L2 | edge_case | 0% | 0% | 0% |
| L3 | rule_interaction | 0% | 0% | 0% |
| L4 | debugging | 0% | 0% | 0% |
| L5 | debugging | 0% | 0% | 0% |
| L6 | short_rule_induction | 0% | 0% | 0% |

## Token Usage by Phase (estimated)

| Phase | Input | Output | Total |
|-------|-------|--------|-------|
| education_classroom_public_qa | 738 | 708 | 1446 |
| education_classroom_forced_checkin | 2976 | 363 | 3339 |
| education_tutoring | 7714 | 1183 | 8897 |
| memory | 3349 | 496 | 3845 |
| evaluation | 13662 | 3590 | 17252 |
| **TOTAL** | | | **34779** |

| Metric | Value |
|--------|-------|
| Classroom correct% | 0% |
| Tutoring correct% | 0% |
| Tutoring gain | +0.0pp |
| Extra education tokens (tutoring vs classroom) | 8897 |
| Tutoring gain per 1k extra tokens | 0.00pp |

## Score by Learner Profile

### By Ability

| Ability | Correct% |
|---------|---------|
| unknown | 54% |

### By Misconception

| Misconception | Correct% |
|---------------|---------|
| unknown | 54% |

### By Interest

| Interest | Correct% |
|----------|---------|
| unknown | 54% |

## Score Variance by Condition (std dev of per-learner correct%)

| Condition | Std Dev |
|-----------|--------|
| classroom_forced_checkin | 0.0 |
| classroom_public_qa | 0.0 |
| one_on_one_tutoring | 0.0 |

**Token cost per correct answer:** 2675 tokens

## Heterogeneity Interpretation

- **classroom_advantage_under_homogeneity** ✓

## Score by Learner Type

| Type | Correct% |
|------|---------|
| passive_listener | 54% |

## Misconception Correction by Condition

| Condition | Correction Rate | Avg Remaining Misconceptions |
|-----------|----------------|------------------------------|
| classroom_forced_checkin | 0% | 0.0 |
| classroom_public_qa | 0% | 0.0 |
| one_on_one_tutoring | 100% | 0.0 |

## Confidence Calibration

| Metric | Rate |
|--------|------|
| High-confidence wrong | 17% |
| Abstention | 13% |

## Passive Listener Rescue Effect

| Condition | Learners | Correct% |
|-----------|---------|---------|
| classroom_public_qa | 1 | 100% |
| classroom_forced_checkin | 1 | 50% |
| one_on_one_tutoring | 1 | 13% |

## Recommended Next Steps

- No ceiling effects at current difficulty. Increase n to improve statistical power.

## Limitations

- Token counts are estimated (chars/4). Actual API token counts may differ by ±20%.
- Auto-scoring uses keyword matching for mistake detection — may under-count partial credit.
- LLM agents are not human learners. Learning is operationalized as condition-specific memory from transcripts.
- Small n. Results are exploratory.

