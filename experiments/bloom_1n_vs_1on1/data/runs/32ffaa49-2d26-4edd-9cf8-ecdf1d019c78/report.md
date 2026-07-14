# Experiment Report (v2)

## Run Metadata

| Field | Value |
|-------|-------|
| run_id | 32ffaa49-2d26-4edd-9cf8-ecdf1d019c78 |
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
| recall | L1 | 0% | 75% | 25% | condition_sensitive |
| edge_case | L2 | 0% | 75% | 56% | condition_sensitive |
| rule_interaction | L3 | 0% | 25% | 38% | condition_sensitive |
| debugging | L4 | 0% | 75% | 46% | condition_sensitive |
| short_rule_induction | L6 | 0% | 75% | 38% | condition_sensitive |

**No ceiling effects detected.**

## Score by Condition (answer_correct rate)

| Condition | Learners | Attempts | Correct% |
|-----------|---------|---------|---------|
| classroom_public_qa | 4 | 32 | 69% |
| generic_one_on_one_tutoring | 4 | 32 | 47% |
| procedure_scaffolded_one_on_one_tutoring | 4 | 32 | 41% |

## Score by Task Type × Condition

| Task Type | Difficulty | No-Ed Correct% | Classroom Correct% | Tutoring Correct% |
|-----------|-----------|----------------|-------------------|-------------------|
| debugging | L4 | 0% | 75% | 46% |
| edge_case | L2 | 0% | 75% | 56% |
| recall | L1 | 0% | 75% | 25% |
| rule_interaction | L3 | 0% | 25% | 38% |
| short_rule_induction | L6 | 0% | 75% | 38% |

## Score by Difficulty Level

| Level | Task Types | No-Ed Correct% | Classroom Correct% | Tutoring Correct% |
|-------|-----------|----------------|-------------------|-------------------|
| L1 | recall | 0% | 75% | 25% |
| L2 | edge_case | 0% | 75% | 56% |
| L3 | rule_interaction | 0% | 25% | 38% |
| L4 | debugging | 0% | 75% | 63% |
| L5 | debugging | 0% | 75% | 13% |
| L6 | short_rule_induction | 0% | 75% | 38% |

## Token Usage by Phase (estimated)

| Phase | Input | Output | Total |
|-------|-------|--------|-------|
| education_classroom_public_qa | 6855 | 1869 | 8724 |
| education_tutoring | 36189 | 6872 | 43061 |
| education_procedure_scaffolded_one_on_one_tutoring | 41255 | 7079 | 48334 |
| memory | 26171 | 2816 | 28987 |
| evaluation | 59542 | 15572 | 75114 |
| **TOTAL** | | | **204220** |

| Metric | Value |
|--------|-------|
| Classroom correct% | 69% |
| Tutoring correct% | 44% |
| Tutoring gain | -25.0pp |
| Extra education tokens (tutoring vs classroom) | 82671 |
| Tutoring gain per 1k extra tokens | -0.30pp |

## Score by Learner Profile

### By Ability

| Ability | Correct% |
|---------|---------|
| unknown | 52% |

### By Misconception

| Misconception | Correct% |
|---------------|---------|
| unknown | 52% |

### By Interest

| Interest | Correct% |
|----------|---------|
| unknown | 52% |

## Score Variance by Condition (std dev of per-learner correct%)

| Condition | Std Dev |
|-----------|--------|
| classroom_public_qa | 0.462 |
| generic_one_on_one_tutoring | 0.313 |
| procedure_scaffolded_one_on_one_tutoring | 0.157 |

**Token cost per correct answer:** 4084 tokens

## Heterogeneity Interpretation

- **classroom_advantage_under_homogeneity** ✓

## Score by Learner Type

| Type | Correct% |
|------|---------|
| order_confused | 52% |

## Misconception Correction by Condition

| Condition | Correction Rate | Avg Remaining Misconceptions |
|-----------|----------------|------------------------------|
| classroom_public_qa | 50% | 0.0 |
| generic_one_on_one_tutoring | 100% | 0.5 |
| procedure_scaffolded_one_on_one_tutoring | 25% | 0.25 |

## Confidence Calibration

| Metric | Rate |
|--------|------|
| High-confidence wrong | 25% |
| Abstention | 13% |

## Order Confused Scaffold Effect

| Condition | Learners | Correct% | Procedure Order Errors% |
|-----------|---------|---------|------------------------|
| classroom_public_qa | 4 | 69% | 0% |
| generic_one_on_one_tutoring | 4 | 47% | 0% |
| procedure_scaffolded_one_on_one_tutoring | 4 | 41% | 0% |

## Procedure Order Errors

| Metric | Rate |
|--------|------|
| Responses with modifier-before-activation error | 0% |

## Recommended Next Steps

- No ceiling effects at current difficulty. Increase n to improve statistical power.

## Limitations

- Token counts are estimated (chars/4). Actual API token counts may differ by ±20%.
- Auto-scoring uses keyword matching for mistake detection — may under-count partial credit.
- LLM agents are not human learners. Learning is operationalized as condition-specific memory from transcripts.
- Small n. Results are exploratory.

