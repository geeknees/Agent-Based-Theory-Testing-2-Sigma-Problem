# Experiment Report (v2)

## Run Metadata

| Field | Value |
|-------|-------|
| run_id | 9b599c12-ab43-42f8-8af4-de26551b3981 |
| date | 2026-05-30 |
| models | claude-haiku-4-5-20251001 |
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
| large_class_discussion_size_16 | 4 | 40 | 45% |
| lecture_only | 2 | 20 | 80% |
| medium_class_discussion_size_8 | 4 | 40 | 45% |
| pair_discussion_size_2 | 2 | 20 | 80% |
| small_class_discussion_size_4 | 2 | 20 | 40% |

## Score by Task Type × Condition

| Task Type | Difficulty | large_class_discussion_size_16 | lecture_only | medium_class_discussion_size_8 | pair_discussion_size_2 | small_class_discussion_size_4 |
|-----------|-----------| ---- | ---- | ---- | ---- | ---- |
| debugging | L4 | 33% | 67% | 17% | 67% | 17% |
| edge_case | L2 | 63% | 100% | 75% | 100% | 50% |
| explanation_choice | L7 | 75% | 100% | 100% | 100% | 100% |
| peer_error_detection | L7 | 50% | 100% | 100% | 100% | 100% |
| recall | L1 | 50% | 100% | 25% | 100% | 50% |
| rule_interaction | L3 | 50% | 100% | 25% | 100% | 0% |
| short_rule_induction | L6 | 0% | 0% | 0% | 0% | 0% |

## Score by Difficulty Level × Condition

| Level | Task Types | large_class_discussion_size_16 | lecture_only | medium_class_discussion_size_8 | pair_discussion_size_2 | small_class_discussion_size_4 |
|-------|-----------| ---- | ---- | ---- | ---- | ---- |
| L1 | recall | 50% | 100% | 25% | 100% | 50% |
| L2 | edge_case | 63% | 100% | 75% | 100% | 50% |
| L3 | rule_interaction | 50% | 100% | 25% | 100% | 0% |
| L4 | debugging | 25% | 50% | 13% | 50% | 0% |
| L5 | debugging | 50% | 100% | 25% | 100% | 50% |
| L6 | short_rule_induction | 0% | 0% | 0% | 0% | 0% |

## Token Usage by Phase (estimated)

| Phase | Input | Output | Total |
|-------|-------|--------|-------|
| **TOTAL** | | | **0** |

## Score by Learner Profile

### By Ability

| Ability | Correct% |
|---------|---------|
| unknown | 54% |

### By Misconception

| Misconception | Correct% |
|---------------|---------|
| unknown | 54% |

### By Interest

| Interest | Correct% |
|----------|---------|
| unknown | 54% |

## Score Variance by Condition (std dev of per-learner correct%)

| Condition | Std Dev |
|-----------|--------|
| large_class_discussion_size_16 | 0.37 |
| lecture_only | 0.141 |
| medium_class_discussion_size_8 | 0.238 |
| pair_discussion_size_2 | 0.0 |
| small_class_discussion_size_4 | 0.141 |

**Token cost per correct answer:** 0 tokens

## Mastery Check Score by Check Type

| Check Type | Total | Correct | Pass Rate |
|------------|-------|---------|-----------|
| edge_case | 14 | 14 | 100% |
| recall | 14 | 4 | 29% |
| rule_interaction | 14 | 3 | 21% |

## Memory Coverage by Condition

| Condition | Avg Rules | Edge Cases (%) | Procedure (%) |
|-----------|-----------|----------------|---------------|
| large_class_discussion_size_16 | 3.3 | 42% | 50% |
| lecture_only | 4.0 | 100% | 50% |
| medium_class_discussion_size_8 | 4.1 | 0% | 75% |
| pair_discussion_size_2 | 3.5 | 33% | 50% |
| small_class_discussion_size_4 | 3.5 | 50% | 100% |

## Ownership Metrics by Condition

| Condition | Avg Ownership Score | Avg Contributions | % Attempted | % Received Feedback |
|-----------|--------------------|--------------------|-------------|---------------------|
| large_class_discussion_size_16 | 1.5 | 0.5 | 50% | 50% |
| lecture_only | 0.0 | 0.0 | 0% | 0% |
| medium_class_discussion_size_8 | 1.5 | 0.5 | 50% | 50% |
| pair_discussion_size_2 | 3.0 | 2.0 | 100% | 100% |
| small_class_discussion_size_4 | 3.0 | 1.0 | 100% | 100% |

## Memory Delta by Condition (knowledge items acquired during discussion)

| Condition | Avg Memory Delta (items) |
|-----------|--------------------------|
| large_class_discussion_size_16 | 0.0 |
| lecture_only | 0.0 |
| medium_class_discussion_size_8 | 0.25 |
| pair_discussion_size_2 | 0.0 |
| small_class_discussion_size_4 | 0.0 |

## Heterogeneity Interpretation

- **classroom_advantage_under_homogeneity** ✓

## Score by Learner Type

| Type | Correct% |
|------|---------|
| passive_listener | 51% |
| rule_extractor | 57% |

## Misconception Correction by Condition

| Condition | Correction Rate | Avg Remaining Misconceptions |
|-----------|----------------|------------------------------|
| large_class_discussion_size_16 | 92% | 0.0 |
| lecture_only | 100% | 0.0 |
| medium_class_discussion_size_8 | 100% | 0.0 |
| pair_discussion_size_2 | 100% | 0.0 |
| small_class_discussion_size_4 | 100% | 0.0 |

## Confidence Calibration

| Metric | Rate |
|--------|------|
| High-confidence wrong | 29% |
| Abstention | 6% |

## Recommended Next Steps

- No ceiling effects at current difficulty. Increase n to improve statistical power.

## Limitations

- Token counts are estimated (chars/4). Actual API token counts may differ by ±20%.
- Auto-scoring uses keyword matching for mistake detection — may under-count partial credit.
- LLM agents are not human learners. Learning is operationalized as condition-specific memory from transcripts.
- Small n. Results are exploratory.

