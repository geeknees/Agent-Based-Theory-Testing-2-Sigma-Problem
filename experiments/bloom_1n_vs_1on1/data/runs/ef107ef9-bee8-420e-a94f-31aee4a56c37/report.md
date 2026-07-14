# Experiment Report (v2)

## Run Metadata

| Field | Value |
|-------|-------|
| run_id | ef107ef9-bee8-420e-a94f-31aee4a56c37 |
| date | 2026-05-29 |
| models | claude-sonnet-4-6 |
| n_classroom |  |
| n_tutoring |  |
| domain | zarn_tokens |
| tutoring_turns |  |

## Ceiling Effect Summary

> Classification: too_easy (all≥90%), education_sensitive (edu>baseline+10pp), condition_sensitive (tutoring≠classroom by >10pp), too_hard (all<30%), unclear

| Task Type | Difficulty | No-Ed Correct% | Classroom Correct% | Tutoring Correct% | Classification |
|-----------|-----------|----------------|-------------------|-------------------|----------------|
| recall | L1 | 0% | 0% | 100% | education_sensitive |
| edge_case | L2 | 0% | 0% | 100% | education_sensitive |
| rule_interaction | L3 | 0% | 0% | 100% | education_sensitive |
| debugging | L4 | 0% | 0% | 67% | education_sensitive |
| short_rule_induction | L6 | 0% | 0% | 0% | too_hard |
| explanation_choice | L7 | 0% | 0% | 75% | education_sensitive |
| peer_error_detection | L7 | 0% | 0% | 100% | education_sensitive |

**No ceiling effects detected.**

## Score by Condition (answer_correct rate)

| Condition | Learners | Attempts | Correct% |
|-----------|---------|---------|---------|
| lecture_only | 4 | 40 | 70% |
| lecture_plus_one_on_one_tutoring | 4 | 40 | 78% |
| lecture_plus_small_group_discussion | 4 | 40 | 68% |
| lecture_plus_whole_class_discussion | 4 | 40 | 83% |

## Score by Task Type × Condition

| Task Type | Difficulty | No-Ed Correct% | Classroom Correct% | Tutoring Correct% |
|-----------|-----------|----------------|-------------------|-------------------|
| debugging | L4 | 0% | 0% | 67% |
| edge_case | L2 | 0% | 0% | 100% |
| explanation_choice | L7 | 0% | 0% | 75% |
| peer_error_detection | L7 | 0% | 0% | 100% |
| recall | L1 | 0% | 0% | 100% |
| rule_interaction | L3 | 0% | 0% | 100% |
| short_rule_induction | L6 | 0% | 0% | 0% |

## Score by Difficulty Level

| Level | Task Types | No-Ed Correct% | Classroom Correct% | Tutoring Correct% |
|-------|-----------|----------------|-------------------|-------------------|
| L1 | recall | 0% | 0% | 100% |
| L2 | edge_case | 0% | 0% | 100% |
| L3 | rule_interaction | 0% | 0% | 100% |
| L4 | debugging | 0% | 0% | 50% |
| L5 | debugging | 0% | 0% | 100% |
| L6 | short_rule_induction | 0% | 0% | 0% |

## Token Usage by Phase (estimated)

| Phase | Input | Output | Total |
|-------|-------|--------|-------|
| education_prerequisite_lecture | 3144 | 11089 | 14233 |
| memory | 63779 | 6004 | 69783 |
| mastery_check | 28359 | 5664 | 34023 |
| education_lecture_plus_whole_class_discussion | 4223 | 768 | 4991 |
| education_lecture_plus_small_group_discussion | 6482 | 1098 | 7580 |
| education_lecture_plus_one_on_one_tutoring | 4434 | 1146 | 5580 |
| evaluation | 99263 | 21877 | 121140 |
| **TOTAL** | | | **257330** |

| Metric | Value |
|--------|-------|
| Classroom correct% | 0% |
| Tutoring correct% | 78% |
| Tutoring gain | +77.5pp |
| Extra education tokens (tutoring vs classroom) | 5580 |
| Tutoring gain per 1k extra tokens | 13.89pp |

## Score by Learner Profile

### By Ability

| Ability | Correct% |
|---------|---------|
| unknown | 74% |

### By Misconception

| Misconception | Correct% |
|---------------|---------|
| unknown | 74% |

### By Interest

| Interest | Correct% |
|----------|---------|
| unknown | 74% |

## Score Variance by Condition (std dev of per-learner correct%)

| Condition | Std Dev |
|-----------|--------|
| lecture_only | 0.2 |
| lecture_plus_one_on_one_tutoring | 0.05 |
| lecture_plus_small_group_discussion | 0.287 |
| lecture_plus_whole_class_discussion | 0.096 |

**Token cost per correct answer:** 2162 tokens

## Mastery Check Score by Check Type

| Check Type | Total | Correct | Pass Rate |
|------------|-------|---------|-----------|
| edge_case | 16 | 16 | 100% |
| recall | 16 | 13 | 81% |
| rule_interaction | 16 | 13 | 81% |

## Memory Coverage by Condition

| Condition | Avg Rules | Edge Cases (%) | Procedure (%) |
|-----------|-----------|----------------|---------------|
| lecture_only | 4.3 | 75% | 100% |
| lecture_plus_one_on_one_tutoring | 4.7 | 58% | 100% |
| lecture_plus_small_group_discussion | 4.2 | 42% | 100% |
| lecture_plus_whole_class_discussion | 4.4 | 67% | 100% |

## Heterogeneity Interpretation

- **classroom_advantage_under_homogeneity** ✓

## Score by Learner Type

| Type | Correct% |
|------|---------|
| edge_case_dropper | 80% |
| order_confused | 85% |
| passive_listener | 60% |
| rule_extractor | 73% |

## Misconception Correction by Condition

| Condition | Correction Rate | Avg Remaining Misconceptions |
|-----------|----------------|------------------------------|
| lecture_only | 25% | 0.0 |
| lecture_plus_one_on_one_tutoring | 33% | 0.25 |
| lecture_plus_small_group_discussion | 75% | 0.0 |
| lecture_plus_whole_class_discussion | 50% | 0.0 |

## Confidence Calibration

| Metric | Rate |
|--------|------|
| High-confidence wrong | 9% |
| Abstention | 3% |

## Recommended Next Steps

- No ceiling effects at current difficulty. Increase n to improve statistical power.

## Limitations

- Token counts are estimated (chars/4). Actual API token counts may differ by ±20%.
- Auto-scoring uses keyword matching for mistake detection — may under-count partial credit.
- LLM agents are not human learners. Learning is operationalized as condition-specific memory from transcripts.
- Small n. Results are exploratory.

