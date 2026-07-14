# Experiment Report (v2)

## Run Metadata

| Field | Value |
|-------|-------|
| run_id | 8b9df115-e435-4305-ac18-3898a0babc52 |
| date | 2026-05-24 |
| models | claude-haiku-4-5-20251001 |
| n_classroom |  |
| n_tutoring |  |
| domain | zarn_tokens |
| tutoring_turns |  |

## Ceiling Effect Summary

> Classification: too_easy (all≥90%), education_sensitive (edu>baseline+10pp), condition_sensitive (tutoring≠classroom by >10pp), too_hard (all<30%), unclear

| Task Type | Difficulty | No-Ed Correct% | Classroom Correct% | Tutoring Correct% | Classification |
|-----------|-----------|----------------|-------------------|-------------------|----------------|
| recall | L1 | 0% | 0% | 50% | education_sensitive |
| edge_case | L2 | 0% | 0% | 75% | education_sensitive |
| rule_interaction | L3 | 0% | 0% | 50% | education_sensitive |
| debugging | L4 | 0% | 0% | 50% | education_sensitive |
| short_rule_induction | L6 | 0% | 0% | 0% | too_hard |
| explanation_choice | L7 | 0% | 0% | 100% | education_sensitive |
| peer_error_detection | L7 | 0% | 0% | 100% | education_sensitive |

**No ceiling effects detected.**

## Score by Condition (answer_correct rate)

| Condition | Learners | Attempts | Correct% |
|-----------|---------|---------|---------|
| lecture_only | 2 | 20 | 60% |
| lecture_plus_one_on_one_tutoring | 2 | 20 | 60% |
| lecture_plus_small_group_discussion | 2 | 20 | 55% |
| lecture_plus_whole_class_discussion | 2 | 20 | 45% |

## Score by Task Type × Condition

| Task Type | Difficulty | No-Ed Correct% | Classroom Correct% | Tutoring Correct% |
|-----------|-----------|----------------|-------------------|-------------------|
| debugging | L4 | 0% | 0% | 50% |
| edge_case | L2 | 0% | 0% | 75% |
| explanation_choice | L7 | 0% | 0% | 100% |
| peer_error_detection | L7 | 0% | 0% | 100% |
| recall | L1 | 0% | 0% | 50% |
| rule_interaction | L3 | 0% | 0% | 50% |
| short_rule_induction | L6 | 0% | 0% | 0% |

## Score by Difficulty Level

| Level | Task Types | No-Ed Correct% | Classroom Correct% | Tutoring Correct% |
|-------|-----------|----------------|-------------------|-------------------|
| L1 | recall | 0% | 0% | 50% |
| L2 | edge_case | 0% | 0% | 75% |
| L3 | rule_interaction | 0% | 0% | 50% |
| L4 | debugging | 0% | 0% | 50% |
| L5 | debugging | 0% | 0% | 50% |
| L6 | short_rule_induction | 0% | 0% | 0% |

## Token Usage by Phase (estimated)

| Phase | Input | Output | Total |
|-------|-------|--------|-------|
| education_prerequisite_lecture | 3144 | 14888 | 18032 |
| memory | 38696 | 2829 | 41525 |
| mastery_check | 14067 | 2888 | 16955 |
| education_lecture_plus_whole_class_discussion | 2512 | 516 | 3028 |
| education_lecture_plus_small_group_discussion | 3127 | 495 | 3622 |
| education_lecture_plus_one_on_one_tutoring | 2200 | 536 | 2736 |
| evaluation | 49613 | 12028 | 61641 |
| **TOTAL** | | | **147539** |

| Metric | Value |
|--------|-------|
| Classroom correct% | 0% |
| Tutoring correct% | 60% |
| Tutoring gain | +60.0pp |
| Extra education tokens (tutoring vs classroom) | 2736 |
| Tutoring gain per 1k extra tokens | 21.93pp |

## Score by Learner Profile

### By Ability

| Ability | Correct% |
|---------|---------|
| unknown | 55% |

### By Misconception

| Misconception | Correct% |
|---------------|---------|
| unknown | 55% |

### By Interest

| Interest | Correct% |
|----------|---------|
| unknown | 55% |

## Score Variance by Condition (std dev of per-learner correct%)

| Condition | Std Dev |
|-----------|--------|
| lecture_only | 0.424 |
| lecture_plus_one_on_one_tutoring | 0.424 |
| lecture_plus_small_group_discussion | 0.212 |
| lecture_plus_whole_class_discussion | 0.071 |

**Token cost per correct answer:** 3353 tokens

## Mastery Check Score by Check Type

| Check Type | Total | Correct | Pass Rate |
|------------|-------|---------|-----------|
| edge_case | 8 | 8 | 100% |
| recall | 8 | 6 | 75% |
| rule_interaction | 8 | 5 | 63% |

## Memory Coverage by Condition

| Condition | Avg Rules | Edge Cases (%) | Procedure (%) |
|-----------|-----------|----------------|---------------|
| lecture_only | 3.0 | 50% | 100% |
| lecture_plus_one_on_one_tutoring | 4.2 | 50% | 0% |
| lecture_plus_small_group_discussion | 4.0 | 0% | 100% |
| lecture_plus_whole_class_discussion | 4.0 | 50% | 100% |

## Heterogeneity Interpretation

- **classroom_advantage_under_homogeneity** ✓

## Score by Learner Type

| Type | Correct% |
|------|---------|
| passive_listener | 35% |
| rule_extractor | 75% |

## Misconception Correction by Condition

| Condition | Correction Rate | Avg Remaining Misconceptions |
|-----------|----------------|------------------------------|
| lecture_only | 100% | 0.0 |
| lecture_plus_one_on_one_tutoring | 100% | 0.0 |
| lecture_plus_small_group_discussion | 100% | 0.0 |
| lecture_plus_whole_class_discussion | 100% | 0.0 |

## Confidence Calibration

| Metric | Rate |
|--------|------|
| High-confidence wrong | 24% |
| Abstention | 10% |

## Recommended Next Steps

- No ceiling effects at current difficulty. Increase n to improve statistical power.

## Limitations

- Token counts are estimated (chars/4). Actual API token counts may differ by ±20%.
- Auto-scoring uses keyword matching for mistake detection — may under-count partial credit.
- LLM agents are not human learners. Learning is operationalized as condition-specific memory from transcripts.
- Small n. Results are exploratory.

