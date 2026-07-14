# Experiment Report (v2)

## Run Metadata

| Field | Value |
|-------|-------|
| run_id | 5c0c1e93-4547-4225-8443-0cc289978430 |
| date | 2026-05-17 |
| models | claude-sonnet-4-6 |
| n_classroom |  |
| n_tutoring | 1 |
| domain | zarn_tokens |
| tutoring_turns | 4 |

## Ceiling Effect Summary

> Classification: too_easy (all≥90%), education_sensitive (edu>baseline+10pp), condition_sensitive (tutoring≠classroom by >10pp), too_hard (all<30%), unclear

| Task Type | Difficulty | No-Ed Correct% | Classroom Correct% | Tutoring Correct% | Classification |
|-----------|-----------|----------------|-------------------|-------------------|----------------|
| recall | L1 | 0% | 0% | 0% | too_hard |
| edge_case | L2 | 0% | 0% | 50% | education_sensitive |
| rule_interaction | L3 | 0% | 0% | 100% | education_sensitive |
| debugging | L4 | 0% | 0% | 100% | education_sensitive |
| short_rule_induction | L6 | 0% | 0% | 0% | too_hard |

**No ceiling effects detected.**

## Score by Condition (answer_correct rate)

| Condition | Learners | Attempts | Correct% |
|-----------|---------|---------|---------|
| no_education | 1 | 8 | 0% |
| homogeneous_classroom | 1 | 8 | 100% |
| heterogeneous_classroom | 1 | 8 | 50% |
| 1on1 | 1 | 8 | 63% |

## Score by Task Type × Condition

| Task Type | Difficulty | No-Ed Correct% | Classroom Correct% | Tutoring Correct% |
|-----------|-----------|----------------|-------------------|-------------------|
| debugging | L4 | 0% | 0% | 100% |
| edge_case | L2 | 0% | 0% | 50% |
| recall | L1 | 0% | 0% | 0% |
| rule_interaction | L3 | 0% | 0% | 100% |
| short_rule_induction | L6 | 0% | 0% | 0% |

## Score by Difficulty Level

| Level | Task Types | No-Ed Correct% | Classroom Correct% | Tutoring Correct% |
|-------|-----------|----------------|-------------------|-------------------|
| L1 | recall | 0% | 0% | 0% |
| L2 | edge_case | 0% | 0% | 50% |
| L3 | rule_interaction | 0% | 0% | 100% |
| L4 | debugging | 0% | 0% | 100% |
| L5 | debugging | 0% | 0% | 100% |
| L6 | short_rule_induction | 0% | 0% | 0% |

## Token Usage by Phase (estimated)

| Phase | Input | Output | Total |
|-------|-------|--------|-------|
| education_homogeneous_classroom | 1865 | 919 | 2784 |
| education_heterogeneous_classroom | 3042 | 986 | 4028 |
| education_tutoring | 8090 | 1108 | 9198 |
| memory | 3761 | 489 | 4250 |
| evaluation | 11924 | 2595 | 14519 |
| **TOTAL** | | | **34779** |

| Metric | Value |
|--------|-------|
| Classroom correct% | 0% |
| Tutoring correct% | 63% |
| Tutoring gain | +62.5pp |
| Extra education tokens (tutoring vs classroom) | 9198 |
| Tutoring gain per 1k extra tokens | 6.79pp |

## Score by Learner Profile

### By Ability

| Ability | Correct% |
|---------|---------|
| high | 56% |
| medium | 100% |
| unknown | 0% |

### By Misconception

| Misconception | Correct% |
|---------------|---------|
| forgets_edge_cases | 100% |
| none | 56% |
| unknown | 0% |

### By Interest

| Interest | Correct% |
|----------|---------|
| abstract_rules | 56% |
| unknown | 0% |
| worked_examples | 100% |

## Score Variance by Condition (std dev of per-learner correct%)

| Condition | Std Dev |
|-----------|--------|
| 1on1 | 0.0 |
| heterogeneous_classroom | 0.0 |
| homogeneous_classroom | 0.0 |
| no_education | 0.0 |

**Token cost per correct answer:** 2046 tokens

## Heterogeneity Interpretation

- **tutoring_advantage_under_heterogeneity** ✓
- **classroom_advantage_under_homogeneity** ✓
- **heterogeneity_penalty** ✓

## Recommended Next Steps

- No ceiling effects at current difficulty. Increase n to improve statistical power.

## Limitations

- Token counts are estimated (chars/4). Actual API token counts may differ by ±20%.
- Auto-scoring uses keyword matching for mistake detection — may under-count partial credit.
- LLM agents are not human learners. Learning is operationalized as condition-specific memory from transcripts.
- Small n. Results are exploratory.

