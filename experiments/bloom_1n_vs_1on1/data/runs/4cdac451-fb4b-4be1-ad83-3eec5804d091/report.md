# Experiment Report (v2)

## Run Metadata

| Field | Value |
|-------|-------|
| run_id | 4cdac451-fb4b-4be1-ad83-3eec5804d091 |
| date | 2026-05-14 |
| models | claude-sonnet-4-6 |
| n_classroom | 1 |
| n_tutoring | 1 |
| domain | zarn_tokens |
| tutoring_turns | 2 |

## Ceiling Effect Summary

> Classification: too_easy (all≥90%), education_sensitive (edu>baseline+10pp), condition_sensitive (tutoring≠classroom by >10pp), too_hard (all<30%), unclear

| Task Type | Difficulty | No-Ed Correct% | Classroom Correct% | Tutoring Correct% | Classification |
|-----------|-----------|----------------|-------------------|-------------------|----------------|

**No ceiling effects detected.**

## Score by Condition (answer_correct rate)

| Condition | Learners | Attempts | Correct% |
|-----------|---------|---------|---------|
| no_education | 0 | 0 | 0% |
| classroom | 0 | 0 | 0% |
| 1on1 | 0 | 0 | 0% |

## Score by Task Type × Condition

| Task Type | Difficulty | No-Ed Correct% | Classroom Correct% | Tutoring Correct% |
|-----------|-----------|----------------|-------------------|-------------------|

## Score by Difficulty Level

| Level | Task Types | No-Ed Correct% | Classroom Correct% | Tutoring Correct% |
|-------|-----------|----------------|-------------------|-------------------|

## Token Usage by Phase (estimated)

| Phase | Input | Output | Total |
|-------|-------|--------|-------|
| education_classroom | 1621 | 757 | 2378 |
| education_tutoring | 2546 | 416 | 2962 |
| memory | 1664 | 308 | 1972 |
| evaluation | 8595 | 1791 | 10386 |
| **TOTAL** | | | **17698** |

| Metric | Value |
|--------|-------|
| Classroom correct% | 0% |
| Tutoring correct% | 0% |
| Tutoring gain | +0.0pp |
| Extra education tokens (tutoring vs classroom) | 584 |
| Tutoring gain per 1k extra tokens | 0.00pp |

## Recommended Next Steps

- No ceiling effects at current difficulty. Increase n to improve statistical power.

## Limitations

- Token counts are estimated (chars/4). Actual API token counts may differ by ±20%.
- Auto-scoring uses keyword matching for mistake detection — may under-count partial credit.
- LLM agents are not human learners. Learning is operationalized as condition-specific memory from transcripts.
- Small n. Results are exploratory.

