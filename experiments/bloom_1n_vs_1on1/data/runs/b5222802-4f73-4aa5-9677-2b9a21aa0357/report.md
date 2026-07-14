# Experiment Report (v2)

## Run Metadata

| Field | Value |
|-------|-------|
| run_id | b5222802-4f73-4aa5-9677-2b9a21aa0357 |
| date | 2026-05-18 |
| models | claude-haiku-4-5-20251001 |
| n_classroom |  |
| n_tutoring | 1 |
| domain | zarn_tokens |
| tutoring_turns | 4 |

## Ceiling Effect Summary

> Classification: too_easy (all≥90%), education_sensitive (edu>baseline+10pp), condition_sensitive (tutoring≠classroom by >10pp), too_hard (all<30%), unclear

| Task Type | Difficulty | No-Ed Correct% | Classroom Correct% | Tutoring Correct% | Classification |
|-----------|-----------|----------------|-------------------|-------------------|----------------|
| recall | L1 | 0% | 100% | 100% | education_sensitive |
| edge_case | L2 | 0% | 75% | 100% | condition_sensitive |
| rule_interaction | L3 | 0% | 50% | 100% | condition_sensitive |
| debugging | L4 | 0% | 83% | 100% | condition_sensitive |
| short_rule_induction | L6 | 0% | 50% | 100% | condition_sensitive |

**No ceiling effects detected.**

## Score by Condition (answer_correct rate)

| Condition | Learners | Attempts | Correct% |
|-----------|---------|---------|---------|
| no_education | 1 | 8 | 0% |
| homogeneous_classroom | 1 | 8 | 50% |
| heterogeneous_classroom | 1 | 8 | 100% |
| 1on1 | 1 | 8 | 100% |

## Score by Task Type × Condition

| Task Type | Difficulty | No-Ed Correct% | Classroom Correct% | Tutoring Correct% |
|-----------|-----------|----------------|-------------------|-------------------|
| debugging | L4 | 0% | 0% | 100% |
| edge_case | L2 | 0% | 0% | 100% |
| recall | L1 | 0% | 0% | 100% |
| rule_interaction | L3 | 0% | 0% | 100% |
| short_rule_induction | L6 | 0% | 0% | 100% |

## Score by Difficulty Level

| Level | Task Types | No-Ed Correct% | Classroom Correct% | Tutoring Correct% |
|-------|-----------|----------------|-------------------|-------------------|
| L1 | recall | 0% | 0% | 100% |
| L2 | edge_case | 0% | 0% | 100% |
| L3 | rule_interaction | 0% | 0% | 100% |
| L4 | debugging | 0% | 0% | 100% |
| L5 | debugging | 0% | 0% | 100% |
| L6 | short_rule_induction | 0% | 0% | 100% |

## Token Usage by Phase (estimated)

| Phase | Input | Output | Total |
|-------|-------|--------|-------|
| education_homogeneous_classroom | 744 | 814 | 1558 |
| education_heterogeneous_classroom | 743 | 751 | 1494 |
| education_tutoring | 9018 | 1507 | 10525 |
| memory | 4164 | 550 | 4714 |
| evaluation | 17910 | 4109 | 22019 |
| **TOTAL** | | | **40310** |

| Metric | Value |
|--------|-------|
| Classroom correct% | 75% |
| Tutoring correct% | 100% |
| Tutoring gain | +25.0pp |
| Extra education tokens (tutoring vs classroom) | 7473 |
| Tutoring gain per 1k extra tokens | 3.35pp |

## Score by Learner Profile

### By Ability

| Ability | Correct% |
|---------|---------|
| unknown | 63% |

### By Misconception

| Misconception | Correct% |
|---------------|---------|
| unknown | 63% |

### By Interest

| Interest | Correct% |
|----------|---------|
| unknown | 63% |

## Score Variance by Condition (std dev of per-learner correct%)

| Condition | Std Dev |
|-----------|--------|
| 1on1 | 0.0 |
| heterogeneous_classroom | 0.0 |
| homogeneous_classroom | 0.0 |
| no_education | 0.0 |

**Token cost per correct answer:** 2016 tokens

## Heterogeneity Interpretation

No strong heterogeneity signal detected.

## Score by Learner Type

| Type | Correct% |
|------|---------|
| edge_case_dropper | 50% |
| rule_extractor | 100% |
| unknown | 0% |

## Misconception Correction by Condition

| Condition | Correction Rate | Avg Remaining Misconceptions |
|-----------|----------------|------------------------------|
| 1on1 | 100% | 0.0 |
| heterogeneous_classroom | 0% | 0.0 |
| homogeneous_classroom | 100% | 0.0 |
| no_education | 0% | 0.0 |

## Confidence Calibration

| Metric | Rate |
|--------|------|
| High-confidence wrong | 6% |
| Abstention | 22% |

## Recommended Next Steps

- No ceiling effects at current difficulty. Increase n to improve statistical power.

## Limitations

- Token counts are estimated (chars/4). Actual API token counts may differ by ±20%.
- Auto-scoring uses keyword matching for mistake detection — may under-count partial credit.
- LLM agents are not human learners. Learning is operationalized as condition-specific memory from transcripts.
- Small n. Results are exploratory.

