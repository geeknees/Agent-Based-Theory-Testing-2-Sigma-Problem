# Experiment Report (v2)

## Run Metadata

| Field | Value |
|-------|-------|
| run_id | 19b39e20-6901-4c90-8f3c-e24b352f23ae |
| date | 2026-05-16 |
| models | claude-sonnet-4-6 |
| n_classroom | 4 |
| n_tutoring | 4 |
| domain | zarn_tokens |
| tutoring_turns | 4 |

## Ceiling Effect Summary

> Classification: too_easy (all≥90%), education_sensitive (edu>baseline+10pp), condition_sensitive (tutoring≠classroom by >10pp), too_hard (all<30%), unclear

| Task Type | Difficulty | No-Ed Correct% | Classroom Correct% | Tutoring Correct% | Classification |
|-----------|-----------|----------------|-------------------|-------------------|----------------|
| recall | L1 | 0% | 0% | 0% | too_hard |
| edge_case | L2 | 0% | 50% | 38% | condition_sensitive |
| rule_interaction | L3 | 0% | 25% | 0% | too_hard |
| debugging | L4 | 0% | 83% | 50% | condition_sensitive |
| short_rule_induction | L6 | 0% | 0% | 0% | too_hard |

**No ceiling effects detected.**

## Score by Condition (answer_correct rate)

| Condition | Learners | Attempts | Correct% |
|-----------|---------|---------|---------|
| no_education | 3 | 24 | 0% |
| classroom | 4 | 32 | 47% |
| 1on1 | 4 | 32 | 28% |

## Score by Task Type × Condition

| Task Type | Difficulty | No-Ed Correct% | Classroom Correct% | Tutoring Correct% |
|-----------|-----------|----------------|-------------------|-------------------|
| debugging | L4 | 0% | 83% | 50% |
| edge_case | L2 | 0% | 50% | 38% |
| recall | L1 | 0% | 0% | 0% |
| rule_interaction | L3 | 0% | 25% | 0% |
| short_rule_induction | L6 | 0% | 0% | 0% |

## Score by Difficulty Level

| Level | Task Types | No-Ed Correct% | Classroom Correct% | Tutoring Correct% |
|-------|-----------|----------------|-------------------|-------------------|
| L1 | recall | 0% | 0% | 0% |
| L2 | edge_case | 0% | 50% | 38% |
| L3 | rule_interaction | 0% | 25% | 0% |
| L4 | debugging | 0% | 100% | 75% |
| L5 | debugging | 0% | 50% | 0% |
| L6 | short_rule_induction | 0% | 0% | 0% |

## Token Usage by Phase (estimated)

| Phase | Input | Output | Total |
|-------|-------|--------|-------|
| education_classroom | 5871 | 1201 | 7072 |
| education_tutoring | 28846 | 4100 | 32946 |
| memory | 11027 | 1337 | 12364 |
| evaluation | 33193 | 6875 | 40068 |
| **TOTAL** | | | **92450** |

| Metric | Value |
|--------|-------|
| Classroom correct% | 47% |
| Tutoring correct% | 28% |
| Tutoring gain | -18.8pp |
| Extra education tokens (tutoring vs classroom) | 25874 |
| Tutoring gain per 1k extra tokens | -0.72pp |

## Recommended Next Steps

- No ceiling effects at current difficulty. Increase n to improve statistical power.

## Limitations

- Token counts are estimated (chars/4). Actual API token counts may differ by ±20%.
- Auto-scoring uses keyword matching for mistake detection — may under-count partial credit.
- LLM agents are not human learners. Learning is operationalized as condition-specific memory from transcripts.
- Small n. Results are exploratory.

