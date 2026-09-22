# Experiment Report (v2)

## Run Metadata

| Field | Value |
|-------|-------|
| run_id | 7bfe6060-8d73-455a-97ec-60fc1e245673 |
| date | 2026-06-05 |
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
| large_class_discussion_size_16 | 4 | 40 | 50% |
| lecture_only | 2 | 20 | 55% |
| medium_class_discussion_size_8 | 4 | 40 | 75% |
| pair_discussion_size_2 | 2 | 20 | 70% |
| small_class_discussion_size_4 | 2 | 20 | 85% |

## Score by Task Type × Condition

| Task Type | Difficulty | large_class_discussion_size_16 | lecture_only | medium_class_discussion_size_8 | pair_discussion_size_2 | small_class_discussion_size_4 |
|-----------|-----------| ---- | ---- | ---- | ---- | ---- |
| debugging | L4 | 42% | 33% | 67% | 50% | 83% |
| edge_case | L2 | 63% | 75% | 88% | 100% | 100% |
| explanation_choice | L7 | 100% | 100% | 100% | 100% | 100% |
| peer_error_detection | L7 | 100% | 100% | 100% | 50% | 100% |
| recall | L1 | 25% | 50% | 100% | 100% | 100% |
| rule_interaction | L3 | 25% | 50% | 75% | 100% | 100% |
| short_rule_induction | L6 | 0% | 0% | 0% | 0% | 0% |

## Score by Difficulty Level × Condition

| Level | Task Types | large_class_discussion_size_16 | lecture_only | medium_class_discussion_size_8 | pair_discussion_size_2 | small_class_discussion_size_4 |
|-------|-----------| ---- | ---- | ---- | ---- | ---- |
| L1 | recall | 25% | 50% | 100% | 100% | 100% |
| L2 | edge_case | 63% | 75% | 88% | 100% | 100% |
| L3 | rule_interaction | 25% | 50% | 75% | 100% | 100% |
| L4 | debugging | 38% | 25% | 63% | 50% | 75% |
| L5 | debugging | 50% | 50% | 75% | 50% | 100% |
| L6 | short_rule_induction | 0% | 0% | 0% | 0% | 0% |

## Token Usage by Phase (estimated)

| Phase | Input | Output | Total |
|-------|-------|--------|-------|
| memory | 43159 | 5025 | 48184 |
| mastery_check | 32498 | 7732 | 40230 |
| education_pair_discussion_size_2 | 7349 | 886 | 8235 |
| education_small_class_discussion_size_4 | 4814 | 561 | 5375 |
| education_medium_class_discussion_size_8 | 4903 | 610 | 5513 |
| education_large_class_discussion_size_16 | 4883 | 602 | 5485 |
| evaluation | 85616 | 21595 | 107211 |
| **TOTAL** | | | **220233** |

## Score by Learner Profile

### By Ability

| Ability | Correct% |
|---------|---------|
| unknown | 66% |

### By Misconception

| Misconception | Correct% |
|---------------|---------|
| unknown | 66% |

### By Interest

| Interest | Correct% |
|----------|---------|
| unknown | 66% |

## Score Variance by Condition (std dev of per-learner correct%)

| Condition | Std Dev |
|-----------|--------|
| large_class_discussion_size_16 | 0.216 |
| lecture_only | 0.354 |
| medium_class_discussion_size_8 | 0.173 |
| pair_discussion_size_2 | 0.141 |
| small_class_discussion_size_4 | 0.071 |

**Token cost per correct answer:** 2394 tokens

## Readiness Summary

| Metric | Value |
|--------|-------|
| Overall readiness pass rate | 66% |
| Target (80%) | ✗ READINESS TARGET NOT MET |

### Pass Rate by Check Type

| Check Type | Total | Correct | Pass Rate |
|------------|-------|---------|-----------|
| edge_case | 14 | 14 | 100% |
| procedure_order | 14 | 6 | 43% |
| recall | 14 | 12 | 86% |
| rule_interaction | 14 | 5 | 36% |

> **WARNING:** Readiness target not met. Do not make strong claims about
> ownership or class-size effects from this run.

## Mastery Check Score by Check Type

| Check Type | Total | Correct | Pass Rate |
|------------|-------|---------|-----------|
| edge_case | 14 | 14 | 100% |
| procedure_order | 14 | 6 | 43% |
| recall | 14 | 12 | 86% |
| rule_interaction | 14 | 5 | 36% |

## Memory Coverage by Condition

| Condition | Avg Rules | Edge Cases (%) | Procedure (%) |
|-----------|-----------|----------------|---------------|
| large_class_discussion_size_16 | 4.6 | 50% | 100% |
| lecture_only | 4.5 | 50% | 50% |
| medium_class_discussion_size_8 | 4.3 | 67% | 75% |
| pair_discussion_size_2 | 5.2 | 50% | 17% |
| small_class_discussion_size_4 | 4.5 | 50% | 50% |

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
| medium_class_discussion_size_8 | 0.0 |
| pair_discussion_size_2 | 0.0 |
| small_class_discussion_size_4 | 0.0 |

## Fine-Grained Memory Coverage Post-Discussion (10 items)

| Condition | blue_activation | green_end | red_modifier | yellow_always | activation_before | final_summing | inactive_token | edge_case | debugging_strategy | common_mistake |
|-----------| :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| large_class_discussion_size_16 | 100% | 100% | 100% | 100% | 92% | 50% | 0% | 58% | 75% | 25% |
| lecture_only | 100% | 100% | 100% | 100% | 75% | 25% | 100% | 75% | 50% | 50% |
| medium_class_discussion_size_8 | 100% | 100% | 100% | 100% | 83% | 17% | 67% | 67% | 50% | 0% |
| pair_discussion_size_2 | 100% | 100% | 100% | 100% | 100% | 0% | 50% | 50% | 0% | 33% |
| small_class_discussion_size_4 | 100% | 100% | 100% | 100% | 100% | 0% | 33% | 100% | 0% | 67% |

## Fine-Grained Memory Delta (pre → post discussion)

| Condition | Avg Acquired | Avg Lost | Avg Stable |
|-----------|:------------:|:--------:|:----------:|
| large_class_discussion_size_16 | 0.0 | 0.3 | 7.0 |
| lecture_only | 0.0 | 0.8 | 7.8 |
| medium_class_discussion_size_8 | 0.0 | 0.4 | 6.8 |
| pair_discussion_size_2 | 0.0 | 0.2 | 6.3 |
| small_class_discussion_size_4 | 0.0 | 0.5 | 7.0 |

## Interpretation Flags

| Flag | Value |
|------|-------|
| readiness_failed | true |
| ownership_effect_supported | true |
| class_size_effect_supported | false |
| lecture_only_dominant | false |
| discussion_added_value | true |

## Interpretation

**WARNING: readiness_failed = true** — prerequisite readiness target (80%) not met.
Ownership and class-size conclusions from this run are unreliable.

## Heterogeneity Interpretation

- **classroom_advantage_under_homogeneity** ✓

## Score by Learner Type

| Type | Correct% |
|------|---------|
| passive_listener | 60% |
| rule_extractor | 71% |

## Misconception Correction by Condition

| Condition | Correction Rate | Avg Remaining Misconceptions |
|-----------|----------------|------------------------------|
| large_class_discussion_size_16 | 50% | 0.0 |
| lecture_only | 100% | 0.0 |
| medium_class_discussion_size_8 | 67% | 0.0 |
| pair_discussion_size_2 | 100% | 0.0 |
| small_class_discussion_size_4 | 100% | 0.0 |

## Confidence Calibration

| Metric | Rate |
|--------|------|
| High-confidence wrong | 21% |
| Abstention | 4% |

## Recommended Next Steps

- No ceiling effects at current difficulty. Increase n to improve statistical power.

## Limitations

- Token counts are estimated (chars/4). Actual API token counts may differ by ±20%.
- Auto-scoring uses keyword matching for mistake detection — may under-count partial credit.
- LLM agents are not human learners. Learning is operationalized as condition-specific memory from transcripts.
- Small n. Results are exploratory.

