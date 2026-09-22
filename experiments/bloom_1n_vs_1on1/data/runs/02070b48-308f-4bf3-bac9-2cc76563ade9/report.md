# Experiment Report (v2)

## Run Metadata

| Field | Value |
|-------|-------|
| run_id | 02070b48-308f-4bf3-bac9-2cc76563ade9 |
| date | 2026-05-17 |
| models | claude-sonnet-4-6 |
| n_classroom |  |
| n_tutoring | 4 |
| domain | zarn_tokens |
| tutoring_turns | 4 |

## Ceiling Effect Summary

> Classification: too_easy (all≥90%), education_sensitive (edu>baseline+10pp), condition_sensitive (tutoring≠classroom by >10pp), too_hard (all<30%), unclear

| Task Type | Difficulty | No-Ed Correct% | Classroom Correct% | Tutoring Correct% | Classification |
|-----------|-----------|----------------|-------------------|-------------------|----------------|
| recall | L1 | 0% | 0% | 25% | too_hard |
| edge_case | L2 | 0% | 0% | 50% | education_sensitive |
| rule_interaction | L3 | 0% | 0% | 25% | too_hard |
| debugging | L4 | 0% | 0% | 42% | education_sensitive |
| short_rule_induction | L6 | 0% | 0% | 25% | too_hard |

**No ceiling effects detected.**

## Score by Condition (answer_correct rate)

| Condition | Learners | Attempts | Correct% |
|-----------|---------|---------|---------|
| no_education | 3 | 24 | 0% |
| homogeneous_classroom | 4 | 32 | 44% |
| heterogeneous_classroom | 4 | 32 | 41% |
| 1on1 | 4 | 32 | 38% |

## Score by Task Type × Condition

| Task Type | Difficulty | No-Ed Correct% | Classroom Correct% | Tutoring Correct% |
|-----------|-----------|----------------|-------------------|-------------------|
| debugging | L4 | 0% | 0% | 42% |
| edge_case | L2 | 0% | 0% | 50% |
| recall | L1 | 0% | 0% | 25% |
| rule_interaction | L3 | 0% | 0% | 25% |
| short_rule_induction | L6 | 0% | 0% | 25% |

## Score by Difficulty Level

| Level | Task Types | No-Ed Correct% | Classroom Correct% | Tutoring Correct% |
|-------|-----------|----------------|-------------------|-------------------|
| L1 | recall | 0% | 0% | 25% |
| L2 | edge_case | 0% | 0% | 50% |
| L3 | rule_interaction | 0% | 0% | 25% |
| L4 | debugging | 0% | 0% | 50% |
| L5 | debugging | 0% | 0% | 25% |
| L6 | short_rule_induction | 0% | 0% | 25% |

## Token Usage by Phase (estimated)

| Phase | Input | Output | Total |
|-------|-------|--------|-------|
| education_homogeneous_classroom | 6660 | 1520 | 8180 |
| education_heterogeneous_classroom | 7168 | 1593 | 8761 |
| education_tutoring | 31000 | 4095 | 35095 |
| memory | 19790 | 1912 | 21702 |
| evaluation | 45648 | 9755 | 55403 |
| **TOTAL** | | | **129141** |

| Metric | Value |
|--------|-------|
| Classroom correct% | 0% |
| Tutoring correct% | 38% |
| Tutoring gain | +37.5pp |
| Extra education tokens (tutoring vs classroom) | 35095 |
| Tutoring gain per 1k extra tokens | 1.07pp |

## Score by Learner Profile

### By Ability

| Ability | Correct% |
|---------|---------|
| high | 38% |
| low | 38% |
| medium | 42% |
| unknown | 0% |

### By Misconception

| Misconception | Correct% |
|---------------|---------|
| applies_modifiers_before_activation | 38% |
| forgets_edge_cases | 40% |
| none | 38% |
| thinks_blue_always_active | 50% |
| unknown | 0% |

### By Interest

| Interest | Correct% |
|----------|---------|
| abstract_rules | 38% |
| simple_sequences | 38% |
| unknown | 0% |
| worked_examples | 42% |

## Score Variance by Condition (std dev of per-learner correct%)

| Condition | Std Dev |
|-----------|--------|
| 1on1 | 0.177 |
| heterogeneous_classroom | 0.063 |
| homogeneous_classroom | 0.125 |
| no_education | 0.0 |

**Token cost per correct answer:** 3311 tokens

## Heterogeneity Interpretation

- **classroom_advantage_under_homogeneity** ✓
- **heterogeneity_penalty** ✓

## Recommended Next Steps

- No ceiling effects at current difficulty. Increase n to improve statistical power.

## Limitations

- Token counts are estimated (chars/4). Actual API token counts may differ by ±20%.
- Auto-scoring uses keyword matching for mistake detection — may under-count partial credit.
- LLM agents are not human learners. Learning is operationalized as condition-specific memory from transcripts.
- Small n. Results are exploratory.

