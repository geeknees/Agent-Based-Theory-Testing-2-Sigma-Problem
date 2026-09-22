# Experiment Report (v2)

## Run Metadata

| Field | Value |
|-------|-------|
| run_id | ab268bd8-6a57-4079-8118-33ea3163502a |
| date | 2026-05-15 |
| models | claude-sonnet-4-6 |
| n_classroom | 1 |
| n_tutoring | 1 |
| domain | zarn_tokens |
| tutoring_turns | 2 |

## Ceiling Effect Summary

> Classification: too_easy (all≥90%), education_sensitive (edu>baseline+10pp), condition_sensitive (tutoring≠classroom by >10pp), too_hard (all<30%), unclear

| Task Type | Difficulty | No-Ed Correct% | Classroom Correct% | Tutoring Correct% | Classification |
|-----------|-----------|----------------|-------------------|-------------------|----------------|
| recall | L1 | 0% | 0% | 100% | education_sensitive |
| edge_case | L2 | 0% | 50% | 0% | education_sensitive |
| rule_interaction | L3 | 0% | 0% | 100% | education_sensitive |
| debugging | L4 | 0% | 100% | 0% | education_sensitive |
| counterexample | L5 | 100% | 100% | 0% | unclear |
| short_rule_induction | L6 | 0% | 0% | 0% | too_hard |

**No ceiling effects detected.**

## Score by Condition (answer_correct rate)

| Condition | Learners | Attempts | Correct% |
|-----------|---------|---------|---------|
| no_education | 1 | 8 | 13% |
| classroom | 1 | 8 | 50% |
| 1on1 | 1 | 8 | 25% |

## Score by Task Type × Condition

| Task Type | Difficulty | No-Ed Correct% | Classroom Correct% | Tutoring Correct% |
|-----------|-----------|----------------|-------------------|-------------------|
| counterexample | L5 | 100% | 100% | 0% |
| debugging | L4 | 0% | 100% | 0% |
| edge_case | L2 | 0% | 50% | 0% |
| recall | L1 | 0% | 0% | 100% |
| rule_interaction | L3 | 0% | 0% | 100% |
| short_rule_induction | L6 | 0% | 0% | 0% |

## Score by Difficulty Level

| Level | Task Types | No-Ed Correct% | Classroom Correct% | Tutoring Correct% |
|-------|-----------|----------------|-------------------|-------------------|
| L1 | recall | 0% | 0% | 100% |
| L2 | edge_case | 0% | 50% | 0% |
| L3 | rule_interaction | 0% | 0% | 100% |
| L4 | debugging | 0% | 100% | 0% |
| L5 | counterexample | 100% | 100% | 0% |
| L6 | short_rule_induction | 0% | 0% | 0% |

## Token Usage by Phase (estimated)

| Phase | Input | Output | Total |
|-------|-------|--------|-------|
| education_classroom | 3173 | 1042 | 4215 |
| education_tutoring | 2578 | 524 | 3102 |
| memory | 2058 | 298 | 2356 |
| evaluation | 8512 | 1753 | 10265 |
| **TOTAL** | | | **19938** |

## Recommended Next Steps

- No ceiling effects at current difficulty. Increase n to improve statistical power.

## Limitations

- Token counts are estimated (chars/4). Actual API token counts may differ by ±20%.
- Auto-scoring uses keyword matching for mistake detection — may under-count partial credit.
- LLM agents are not human learners. Learning is operationalized as condition-specific memory from transcripts.
- Small n. Results are exploratory.

