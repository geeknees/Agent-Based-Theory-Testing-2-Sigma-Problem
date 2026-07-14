# Experiment Report (v2)

## Run Metadata

| Field | Value |
|-------|-------|
| run_id | 4b1ac552-68da-4db7-83eb-33252a0c65ff |
| date | 2026-05-14 |
| models | claude-sonnet-4-6 |
| n_classroom | 2 |
| n_tutoring | 2 |
| domain | zarn_tokens |
| tutoring_turns | 2 |

## Ceiling Effect Summary

> Tasks where both conditions score >90% correct answers are flagged as too easy.

| Task Type | Difficulty | Classroom Correct% | Tutoring Correct% | Ceiling? |
|-----------|-----------|-------------------|-------------------|---------|
| recall | L1 | 100% | 100% | YES ⚠️ |
| edge_case | L2 | 100% | 100% | YES ⚠️ |
| rule_interaction | L3 | 100% | 100% | YES ⚠️ |
| debugging | L4 | 100% | 100% | YES ⚠️ |
| counterexample | L5 | 100% | 100% | YES ⚠️ |
| short_rule_induction | L6 | 100% | 100% | YES ⚠️ |

**Task types too easy:** recall, edge_case, rule_interaction, debugging, counterexample, short_rule_induction

## Score by Condition (answer_correct rate)

| Condition | Learners | Attempts | Correct% |
|-----------|---------|---------|---------|
| classroom | 2 | 16 | 100% |
| 1on1 | 2 | 16 | 100% |

## Score by Task Type × Condition

| Task Type | Difficulty | Classroom Correct% | Tutoring Correct% |
|-----------|-----------|-------------------|-------------------|
| counterexample | L5 | 100% | 100% |
| debugging | L4 | 100% | 100% |
| edge_case | L2 | 100% | 100% |
| recall | L1 | 100% | 100% |
| rule_interaction | L3 | 100% | 100% |
| short_rule_induction | L6 | 100% | 100% |

## Score by Difficulty Level

| Level | Task Types | Classroom Correct% | Tutoring Correct% |
|-------|-----------|-------------------|-------------------|
| L1 | recall | 100% | 100% |
| L2 | edge_case | 100% | 100% |
| L3 | rule_interaction | 100% | 100% |
| L4 | debugging | 100% | 100% |
| L5 | counterexample | 100% | 100% |
| L6 | short_rule_induction | 100% | 100% |

## Token Usage by Phase (estimated)

| Phase | Input | Output | Total |
|-------|-------|--------|-------|
| education_classroom | 3930 | 1023 | 4953 |
| education_tutoring | 5061 | 882 | 5943 |
| memory | 3933 | 626 | 4559 |
| evaluation | 14595 | 2200 | 16795 |
| **TOTAL** | | | **32250** |

| Metric | Value |
|--------|-------|
| Classroom correct% | 100% |
| Tutoring correct% | 100% |
| Tutoring gain | +0.0pp |
| Extra education tokens (tutoring vs classroom) | 990 |
| Tutoring gain per 1k extra tokens | 0.00pp |

## Recommended Next Steps

- All task types showed ceiling effects. Replace or skip L1/L2, increase L4–L6 share.

## Limitations

- Token counts are estimated (chars/4). Actual API token counts may differ by ±20%.
- Auto-scoring uses keyword matching for mistake detection — may under-count partial credit.
- LLM agents are not human learners. Learning is operationalized as condition-specific memory from transcripts.
- Small n. Results are exploratory.

