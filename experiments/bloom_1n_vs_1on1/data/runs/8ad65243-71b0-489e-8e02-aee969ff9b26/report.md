# Experiment Report (v2)

## Run Metadata

| Field | Value |
|-------|-------|
| run_id | 8ad65243-71b0-489e-8e02-aee969ff9b26 |
| date | 2026-05-15 |
| models | claude-sonnet-4-6 |
| n_classroom | 1 |
| n_tutoring | 1 |
| domain | zarn_tokens |
| tutoring_turns | 4 |

## Ceiling Effect Summary

> Classification: too_easy (all≥90%), education_sensitive (edu>baseline+10pp), condition_sensitive (tutoring≠classroom by >10pp), too_hard (all<30%), unclear

| Task Type | Difficulty | No-Ed Correct% | Classroom Correct% | Tutoring Correct% | Classification |
|-----------|-----------|----------------|-------------------|-------------------|----------------|
| recall | L1 | 0% | 0% | 0% | too_hard |
| edge_case | L2 | 0% | 50% | 50% | education_sensitive |
| rule_interaction | L3 | 0% | 0% | 0% | too_hard |
| debugging | L4 | 0% | 67% | 67% | education_sensitive |
| short_rule_induction | L6 | 0% | 0% | 0% | too_hard |

**No ceiling effects detected.**

## Score by Condition (answer_correct rate)

| Condition | Learners | Attempts | Correct% |
|-----------|---------|---------|---------|
| no_education | 1 | 8 | 0% |
| classroom | 1 | 8 | 38% |
| 1on1 | 1 | 8 | 38% |

## Score by Task Type × Condition

| Task Type | Difficulty | No-Ed Correct% | Classroom Correct% | Tutoring Correct% |
|-----------|-----------|----------------|-------------------|-------------------|
| debugging | L4 | 0% | 67% | 67% |
| edge_case | L2 | 0% | 50% | 50% |
| recall | L1 | 0% | 0% | 0% |
| rule_interaction | L3 | 0% | 0% | 0% |
| short_rule_induction | L6 | 0% | 0% | 0% |

## Score by Difficulty Level

| Level | Task Types | No-Ed Correct% | Classroom Correct% | Tutoring Correct% |
|-------|-----------|----------------|-------------------|-------------------|
| L1 | recall | 0% | 0% | 0% |
| L2 | edge_case | 0% | 50% | 50% |
| L3 | rule_interaction | 0% | 0% | 0% |
| L4 | debugging | 0% | 100% | 100% |
| L5 | debugging | 0% | 0% | 0% |
| L6 | short_rule_induction | 0% | 0% | 0% |

## Token Usage by Phase (estimated)

| Phase | Input | Output | Total |
|-------|-------|--------|-------|
| education_classroom | 3066 | 966 | 4032 |
| education_tutoring | 7751 | 1103 | 8854 |
| memory | 2571 | 355 | 2926 |
| evaluation | 8894 | 1888 | 10782 |
| **TOTAL** | | | **26594** |

| Metric | Value |
|--------|-------|
| Classroom correct% | 38% |
| Tutoring correct% | 38% |
| Tutoring gain | +0.0pp |
| Extra education tokens (tutoring vs classroom) | 4822 |
| Tutoring gain per 1k extra tokens | 0.00pp |

## Recommended Next Steps

- No ceiling effects at current difficulty. Increase n to improve statistical power.

## Limitations

- Token counts are estimated (chars/4). Actual API token counts may differ by ±20%.
- Auto-scoring uses keyword matching for mistake detection — may under-count partial credit.
- LLM agents are not human learners. Learning is operationalized as condition-specific memory from transcripts.
- Small n. Results are exploratory.

