# Experiment Report (v2)

## Run Metadata

| Field | Value |
|-------|-------|
| run_id | b412cfdb-0522-4997-a47e-1738eb414f4b |
| date | 2026-06-06 |
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
| large_class_discussion_size_16 | 16 | 160 | 52% |
| lecture_only | 4 | 40 | 28% |
| medium_class_discussion_size_8 | 8 | 80 | 40% |
| pair_discussion_size_2 | 2 | 20 | 65% |
| small_class_discussion_size_4 | 4 | 40 | 57% |

## Score by Task Type × Condition

| Task Type | Difficulty | large_class_discussion_size_16 | lecture_only | medium_class_discussion_size_8 | pair_discussion_size_2 | small_class_discussion_size_4 |
|-----------|-----------| ---- | ---- | ---- | ---- | ---- |
| debugging | L4 | 35% | 25% | 17% | 33% | 33% |
| edge_case | L2 | 41% | 25% | 25% | 75% | 50% |
| explanation_choice | L7 | 100% | 50% | 88% | 100% | 100% |
| peer_error_detection | L7 | 100% | 100% | 100% | 100% | 100% |
| recall | L1 | 63% | 0% | 75% | 100% | 100% |
| rule_interaction | L3 | 69% | 0% | 38% | 100% | 75% |
| short_rule_induction | L6 | 0% | 0% | 0% | 0% | 0% |

## Score by Difficulty Level × Condition

| Level | Task Types | large_class_discussion_size_16 | lecture_only | medium_class_discussion_size_8 | pair_discussion_size_2 | small_class_discussion_size_4 |
|-------|-----------| ---- | ---- | ---- | ---- | ---- |
| L1 | recall | 63% | 0% | 75% | 100% | 100% |
| L2 | edge_case | 41% | 25% | 25% | 75% | 50% |
| L3 | rule_interaction | 69% | 0% | 38% | 100% | 75% |
| L4 | debugging | 31% | 25% | 13% | 25% | 38% |
| L5 | debugging | 44% | 25% | 25% | 50% | 25% |
| L6 | short_rule_induction | 0% | 0% | 0% | 0% | 0% |

## Token Usage by Phase (estimated)

| Phase | Input | Output | Total |
|-------|-------|--------|-------|
| memory | 109783 | 14368 | 124151 |
| mastery_check | 82263 | 20566 | 102829 |
| education_pair_discussion_size_2 | 7159 | 815 | 7974 |
| education_small_class_discussion_size_4 | 6149 | 723 | 6872 |
| education_medium_class_discussion_size_8 | 6487 | 800 | 7287 |
| education_large_class_discussion_size_16 | 5687 | 713 | 6400 |
| evaluation | 285591 | 90851 | 376442 |
| **TOTAL** | | | **631955** |

## Score by Learner Profile

### By Ability

| Ability | Correct% |
|---------|---------|
| unknown | 48% |

### By Misconception

| Misconception | Correct% |
|---------------|---------|
| unknown | 48% |

### By Interest

| Interest | Correct% |
|----------|---------|
| unknown | 48% |

## Score Variance by Condition (std dev of per-learner correct%)

| Condition | Std Dev |
|-----------|--------|
| large_class_discussion_size_16 | 0.168 |
| lecture_only | 0.096 |
| medium_class_discussion_size_8 | 0.214 |
| pair_discussion_size_2 | 0.071 |
| small_class_discussion_size_4 | 0.126 |

**Token cost per correct answer:** 3901 tokens

## Readiness Summary

| Metric | Value |
|--------|-------|
| Overall readiness pass rate | 69% |
| Target (80%) | ✗ READINESS TARGET NOT MET |

### Pass Rate by Check Type

| Check Type | Total | Correct | Pass Rate |
|------------|-------|---------|-----------|
| edge_case | 34 | 34 | 100% |
| procedure_order | 34 | 20 | 59% |
| recall | 34 | 23 | 68% |
| rule_interaction | 34 | 17 | 50% |

> **WARNING:** Readiness target not met. Do not make strong claims about
> ownership or class-size effects from this run.

## Mastery Check Score by Check Type

| Check Type | Total | Correct | Pass Rate |
|------------|-------|---------|-----------|
| edge_case | 34 | 34 | 100% |
| procedure_order | 34 | 20 | 59% |
| recall | 34 | 23 | 68% |
| rule_interaction | 34 | 17 | 50% |

## Memory Coverage by Condition

| Condition | Avg Rules | Edge Cases (%) | Procedure (%) |
|-----------|-----------|----------------|---------------|
| large_class_discussion_size_16 | 4.9 | 58% | 100% |
| lecture_only | 5.0 | 75% | 100% |
| medium_class_discussion_size_8 | 5.0 | 50% | 100% |
| pair_discussion_size_2 | 5.0 | 50% | 100% |
| small_class_discussion_size_4 | 5.0 | 50% | 100% |

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
| large_class_discussion_size_16 | 0.06 |
| lecture_only | 0.0 |
| medium_class_discussion_size_8 | 0.25 |
| pair_discussion_size_2 | 0.0 |
| small_class_discussion_size_4 | 0.25 |

## Fine-Grained Memory Coverage Post-Discussion (10 items)

| Condition | blue_activation | green_end | red_modifier | yellow_always | activation_before | final_summing | inactive_token | edge_case | debugging_strategy | common_mistake |
|-----------| :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| large_class_discussion_size_16 | 100% | 100% | 100% | 100% | 90% | 10% | 65% | 69% | 75% | 17% |
| lecture_only | 100% | 100% | 100% | 100% | 100% | 38% | 100% | 75% | 75% | 38% |
| medium_class_discussion_size_8 | 100% | 100% | 100% | 100% | 96% | 17% | 79% | 67% | 88% | 0% |
| pair_discussion_size_2 | 100% | 100% | 100% | 100% | 100% | 17% | 50% | 100% | 100% | 0% |
| small_class_discussion_size_4 | 100% | 100% | 100% | 100% | 100% | 17% | 92% | 92% | 83% | 25% |

## Fine-Grained Memory Delta (pre → post discussion)

| Condition | Avg Acquired | Avg Lost | Avg Stable |
|-----------|:------------:|:--------:|:----------:|
| large_class_discussion_size_16 | 0.0 | 0.9 | 7.2 |
| lecture_only | 0.0 | 0.5 | 8.3 |
| medium_class_discussion_size_8 | 0.1 | 0.5 | 7.4 |
| pair_discussion_size_2 | 0.0 | 0.3 | 7.7 |
| small_class_discussion_size_4 | 0.1 | 0.3 | 8.0 |

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
| edge_case_dropper | 50% |
| order_confused | 44% |
| passive_listener | 44% |
| rule_extractor | 52% |

## Misconception Correction by Condition

| Condition | Correction Rate | Avg Remaining Misconceptions |
|-----------|----------------|------------------------------|
| large_class_discussion_size_16 | 94% | 0.0 |
| lecture_only | 100% | 0.0 |
| medium_class_discussion_size_8 | 88% | 0.0 |
| pair_discussion_size_2 | 50% | 0.0 |
| small_class_discussion_size_4 | 83% | 0.0 |

## Confidence Calibration

| Metric | Rate |
|--------|------|
| High-confidence wrong | 13% |
| Abstention | 1% |

## Recommended Next Steps

- No ceiling effects at current difficulty. Increase n to improve statistical power.

## Limitations

- Token counts are estimated (chars/4). Actual API token counts may differ by ±20%.
- Auto-scoring uses keyword matching for mistake detection — may under-count partial credit.
- LLM agents are not human learners. Learning is operationalized as condition-specific memory from transcripts.
- Small n. Results are exploratory.

