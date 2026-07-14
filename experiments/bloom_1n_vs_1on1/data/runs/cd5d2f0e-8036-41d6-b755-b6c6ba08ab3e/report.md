# Experiment Report (v2)

## Run Metadata

| Field | Value |
|-------|-------|
| run_id | cd5d2f0e-8036-41d6-b755-b6c6ba08ab3e |
| date | 2026-05-21 |
| models | claude-sonnet-4-6 |
| n_classroom |  |
| n_tutoring | 4 |
| domain | zarn_tokens |
| tutoring_turns | 4 |

## Ceiling Effect Summary

> Classification: too_easy (all≥90%), education_sensitive (edu>baseline+10pp), condition_sensitive (tutoring≠classroom by >10pp), too_hard (all<30%), unclear

| Task Type | Difficulty | No-Ed Correct% | Classroom Correct% | Tutoring Correct% | Classification |
|-----------|-----------|----------------|-------------------|-------------------|----------------|
| recall | L1 | 0% | 88% | 50% | condition_sensitive |
| edge_case | L2 | 0% | 88% | 75% | condition_sensitive |
| rule_interaction | L3 | 0% | 50% | 50% | education_sensitive |
| debugging | L4 | 0% | 88% | 58% | condition_sensitive |
| short_rule_induction | L6 | 0% | 38% | 50% | condition_sensitive |

**No ceiling effects detected.**

## Score by Condition (answer_correct rate)

| Condition | Learners | Attempts | Correct% |
|-----------|---------|---------|---------|
| no_education | 3 | 24 | 0% |
| homogeneous_classroom | 4 | 32 | 94% |
| heterogeneous_classroom | 4 | 32 | 59% |
| 1on1 | 4 | 32 | 59% |

## Score by Task Type × Condition

| Task Type | Difficulty | No-Ed Correct% | Classroom Correct% | Tutoring Correct% |
|-----------|-----------|----------------|-------------------|-------------------|
| debugging | L4 | 0% | 88% | 58% |
| edge_case | L2 | 0% | 88% | 75% |
| recall | L1 | 0% | 88% | 50% |
| rule_interaction | L3 | 0% | 50% | 50% |
| short_rule_induction | L6 | 0% | 38% | 50% |

## Score by Difficulty Level

| Level | Task Types | No-Ed Correct% | Classroom Correct% | Tutoring Correct% |
|-------|-----------|----------------|-------------------|-------------------|
| L1 | recall | 0% | 88% | 50% |
| L2 | edge_case | 0% | 88% | 75% |
| L3 | rule_interaction | 0% | 50% | 50% |
| L4 | debugging | 0% | 94% | 63% |
| L5 | debugging | 0% | 75% | 50% |
| L6 | short_rule_induction | 0% | 38% | 50% |

## Token Usage by Phase (estimated)

| Phase | Input | Output | Total |
|-------|-------|--------|-------|
| education_homogeneous_classroom | 744 | 907 | 1651 |
| education_heterogeneous_classroom | 814 | 796 | 1610 |
| education_tutoring | 34440 | 6043 | 40483 |
| memory | 17540 | 2667 | 20207 |
| evaluation | 69293 | 16793 | 86086 |
| **TOTAL** | | | **150037** |

| Metric | Value |
|--------|-------|
| Classroom correct% | 77% |
| Tutoring correct% | 59% |
| Tutoring gain | -17.2pp |
| Extra education tokens (tutoring vs classroom) | 37222 |
| Tutoring gain per 1k extra tokens | -0.46pp |

## Score by Learner Profile

### By Ability

| Ability | Correct% |
|---------|---------|
| unknown | 57% |

### By Misconception

| Misconception | Correct% |
|---------------|---------|
| unknown | 57% |

### By Interest

| Interest | Correct% |
|----------|---------|
| unknown | 57% |

## Score Variance by Condition (std dev of per-learner correct%)

| Condition | Std Dev |
|-----------|--------|
| 1on1 | 0.157 |
| heterogeneous_classroom | 0.329 |
| homogeneous_classroom | 0.072 |
| no_education | 0.0 |

**Token cost per correct answer:** 2206 tokens

## Heterogeneity Interpretation

- **classroom_advantage_under_homogeneity** ✓
- **heterogeneity_penalty** ✓

## Score by Learner Type

| Type | Correct% |
|------|---------|
| edge_case_dropper | 88% |
| order_confused | 75% |
| passive_listener | 25% |
| rule_extractor | 63% |
| unknown | 0% |

## Misconception Correction by Condition

| Condition | Correction Rate | Avg Remaining Misconceptions |
|-----------|----------------|------------------------------|
| 1on1 | 75% | 0.75 |
| heterogeneous_classroom | 0% | 0.0 |
| homogeneous_classroom | 0% | 0.0 |
| no_education | 0% | 0.0 |

## Confidence Calibration

| Metric | Rate |
|--------|------|
| High-confidence wrong | 14% |
| Abstention | 20% |

## Recommended Next Steps

- No ceiling effects at current difficulty. Increase n to improve statistical power.

## Limitations

- Token counts are estimated (chars/4). Actual API token counts may differ by ±20%.
- Auto-scoring uses keyword matching for mistake detection — may under-count partial credit.
- LLM agents are not human learners. Learning is operationalized as condition-specific memory from transcripts.
- Small n. Results are exploratory.

