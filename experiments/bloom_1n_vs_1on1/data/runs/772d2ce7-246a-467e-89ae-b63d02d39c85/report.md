# Experiment Report (v2)

## Run Metadata

| Field | Value |
|-------|-------|
| run_id | 772d2ce7-246a-467e-89ae-b63d02d39c85 |
| date | 2026-06-04 |
| models | claude-sonnet-4-6 |
| n_classroom |  |
| n_tutoring |  |
| domain | zarn_tokens |
| tutoring_turns |  |

## Ceiling Effect Summary

> Classification: too_easy (all≥90%), education_sensitive (edu>baseline+10pp), condition_sensitive (tutoring≠classroom by >10pp), too_hard (all<30%), unclear

| Task Type | Difficulty | No-Ed Correct% | Classroom Correct% | Tutoring Correct% | Classification |
|-----------|-----------|----------------|-------------------|-------------------|----------------|
| recall | L1 | 0% | 0% | 0% | too_hard |
| edge_case | L2 | 0% | 0% | 0% | too_hard |
| rule_interaction | L3 | 0% | 0% | 0% | too_hard |
| debugging | L4 | 0% | 0% | 0% | too_hard |
| short_rule_induction | L6 | 0% | 0% | 0% | too_hard |
| explanation_choice | L7 | 0% | 0% | 0% | too_hard |
| peer_error_detection | L7 | 0% | 0% | 0% | too_hard |

**No ceiling effects detected.**

## Score by Condition (answer_correct rate)

| Condition | Learners | Attempts | Correct% |
|-----------|---------|---------|---------|
| large_class_discussion_size_16 | 16 | 160 | 47% |
| lecture_only | 4 | 40 | 60% |
| medium_class_discussion_size_8 | 8 | 80 | 45% |
| pair_discussion_size_2 | 2 | 20 | 60% |
| small_class_discussion_size_4 | 4 | 40 | 48% |

## Score by Task Type × Condition

| Task Type | Difficulty | large_class_discussion_size_16 | lecture_only | medium_class_discussion_size_8 | pair_discussion_size_2 | small_class_discussion_size_4 |
|-----------|-----------| ---- | ---- | ---- | ---- | ---- |
| debugging | L4 | 42% | 58% | 33% | 67% | 33% |
| edge_case | L2 | 34% | 25% | 13% | 0% | 38% |
| explanation_choice | L7 | 100% | 100% | 100% | 100% | 100% |
| peer_error_detection | L7 | 94% | 100% | 75% | 100% | 100% |
| recall | L1 | 38% | 100% | 75% | 100% | 50% |
| rule_interaction | L3 | 44% | 75% | 75% | 100% | 50% |
| short_rule_induction | L6 | 0% | 0% | 0% | 0% | 0% |

## Score by Difficulty Level × Condition

| Level | Task Types | large_class_discussion_size_16 | lecture_only | medium_class_discussion_size_8 | pair_discussion_size_2 | small_class_discussion_size_4 |
|-------|-----------| ---- | ---- | ---- | ---- | ---- |
| L1 | recall | 38% | 100% | 75% | 100% | 50% |
| L2 | edge_case | 34% | 25% | 13% | 0% | 38% |
| L3 | rule_interaction | 44% | 75% | 75% | 100% | 50% |
| L4 | debugging | 28% | 50% | 31% | 50% | 38% |
| L5 | debugging | 69% | 75% | 38% | 100% | 25% |
| L6 | short_rule_induction | 0% | 0% | 0% | 0% | 0% |

## Token Usage by Phase (estimated)

| Phase | Input | Output | Total |
|-------|-------|--------|-------|
| education_prerequisite_lecture | 786 | 2774 | 3560 |
| memory | 145674 | 15702 | 161376 |
| mastery_check | 62367 | 14612 | 76979 |
| education_pair_discussion_size_2 | 4716 | 776 | 5492 |
| education_small_class_discussion_size_4 | 3576 | 628 | 4204 |
| education_medium_class_discussion_size_8 | 3891 | 725 | 4616 |
| education_large_class_discussion_size_16 | 3038 | 590 | 3628 |
| evaluation | 279994 | 79658 | 359652 |
| **TOTAL** | | | **619507** |

## Score by Learner Profile

### By Ability

| Ability | Correct% |
|---------|---------|
| unknown | 49% |

### By Misconception

| Misconception | Correct% |
|---------------|---------|
| unknown | 49% |

### By Interest

| Interest | Correct% |
|----------|---------|
| unknown | 49% |

## Score Variance by Condition (std dev of per-learner correct%)

| Condition | Std Dev |
|-----------|--------|
| large_class_discussion_size_16 | 0.158 |
| lecture_only | 0.141 |
| medium_class_discussion_size_8 | 0.107 |
| pair_discussion_size_2 | 0.0 |
| small_class_discussion_size_4 | 0.222 |

**Token cost per correct answer:** 3732 tokens

## Mastery Check Score by Check Type

| Check Type | Total | Correct | Pass Rate |
|------------|-------|---------|-----------|
| edge_case | 34 | 34 | 100% |
| recall | 34 | 16 | 47% |
| rule_interaction | 34 | 9 | 26% |

## Memory Coverage by Condition

| Condition | Avg Rules | Edge Cases (%) | Procedure (%) |
|-----------|-----------|----------------|---------------|
| large_class_discussion_size_16 | 4.3 | 60% | 96% |
| lecture_only | 4.3 | 75% | 100% |
| medium_class_discussion_size_8 | 4.2 | 46% | 100% |
| pair_discussion_size_2 | 4.0 | 50% | 100% |
| small_class_discussion_size_4 | 3.9 | 42% | 100% |

## Ownership Metrics by Condition

| Condition | Avg Ownership Score | Avg Contributions | % Attempted | % Received Feedback |
|-----------|--------------------|--------------------|-------------|---------------------|
| large_class_discussion_size_16 | 0.56 | 0.2 | 19% | 19% |
| lecture_only | 0.0 | 0.0 | 0% | 0% |
| medium_class_discussion_size_8 | 1.5 | 0.5 | 50% | 50% |
| pair_discussion_size_2 | 3.0 | 2.0 | 100% | 100% |
| small_class_discussion_size_4 | 3.0 | 1.0 | 100% | 100% |

## Memory Delta by Condition (knowledge items acquired during discussion)

| Condition | Avg Memory Delta (items) |
|-----------|--------------------------|
| large_class_discussion_size_16 | 0.0 |
| lecture_only | 0.0 |
| medium_class_discussion_size_8 | 0.0 |
| pair_discussion_size_2 | 0.0 |
| small_class_discussion_size_4 | 0.0 |

## Heterogeneity Interpretation

- **classroom_advantage_under_homogeneity** ✓

## Score by Learner Type

| Type | Correct% |
|------|---------|
| edge_case_dropper | 59% |
| order_confused | 39% |
| passive_listener | 38% |
| rule_extractor | 58% |

## Misconception Correction by Condition

| Condition | Correction Rate | Avg Remaining Misconceptions |
|-----------|----------------|------------------------------|
| large_class_discussion_size_16 | 85% | 0.0 |
| lecture_only | 75% | 0.0 |
| medium_class_discussion_size_8 | 83% | 0.0 |
| pair_discussion_size_2 | 67% | 0.0 |
| small_class_discussion_size_4 | 92% | 0.0 |

## Confidence Calibration

| Metric | Rate |
|--------|------|
| High-confidence wrong | 16% |
| Abstention | 0% |

## Recommended Next Steps

- No ceiling effects at current difficulty. Increase n to improve statistical power.

## Limitations

- Token counts are estimated (chars/4). Actual API token counts may differ by ±20%.
- Auto-scoring uses keyword matching for mistake detection — may under-count partial credit.
- LLM agents are not human learners. Learning is operationalized as condition-specific memory from transcripts.
- Small n. Results are exploratory.

