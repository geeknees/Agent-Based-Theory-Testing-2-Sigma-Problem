# Experiment Report (v2)

## Run Metadata

| Field | Value |
|-------|-------|
| run_id | 7e808848-47ad-4447-803d-136f6c1ed7b5 |
| date | 2026-06-10 |
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
| explanation_choice | L7 | 0% | 0% | 0% | too_hard |
| peer_error_detection | L7 | 0% | 0% | 0% | too_hard |

**No ceiling effects detected.**

## Score by Condition (answer_correct rate)

| Condition | Learners | Attempts | Correct% |
|-----------|---------|---------|---------|
| large_class_discussion_size_16 | 8 | 72 | 65% |
| lecture_only | 2 | 18 | 61% |
| pair_discussion_size_2 | 4 | 36 | 58% |

## Score by Task Type × Condition

| Task Type | Difficulty | No-Ed Correct% | Classroom Correct% | Tutoring Correct% |
|-----------|-----------|----------------|-------------------|-------------------|
| debugging | L4 | 0% | 0% | 0% |
| edge_case | L2 | 0% | 0% | 0% |
| explanation_choice | L7 | 0% | 0% | 0% |
| peer_error_detection | L7 | 0% | 0% | 0% |
| recall | L1 | 0% | 0% | 0% |
| rule_interaction | L3 | 0% | 0% | 0% |

## Score by Difficulty Level

| Level | Task Types | No-Ed Correct% | Classroom Correct% | Tutoring Correct% |
|-------|-----------|----------------|-------------------|-------------------|
| L1 | recall | 0% | 0% | 0% |
| L2 | edge_case | 0% | 0% | 0% |
| L3 | rule_interaction | 0% | 0% | 0% |
| L4 | debugging | 0% | 0% | 0% |
| L5 | debugging | 0% | 0% | 0% |

## Token Usage by Phase (estimated)

| Phase | Input | Output | Total |
|-------|-------|--------|-------|
| memory | 45256 | 5788 | 51044 |
| mastery_check | 32629 | 7790 | 40419 |
| education_lecture_only | 997 | 410 | 1407 |
| education_pair_discussion_size_2 | 17240 | 1784 | 19024 |
| education_large_class_discussion_size_16 | 10491 | 1083 | 11574 |
| evaluation | 83078 | 20604 | 103682 |
| **TOTAL** | | | **227150** |

## Score by Learner Profile

### By Ability

| Ability | Correct% |
|---------|---------|
| unknown | 63% |

### By Misconception

| Misconception | Correct% |
|---------------|---------|
| unknown | 63% |

### By Interest

| Interest | Correct% |
|----------|---------|
| unknown | 63% |

## Score Variance by Condition (std dev of per-learner correct%)

| Condition | Std Dev |
|-----------|--------|
| large_class_discussion_size_16 | 0.233 |
| lecture_only | 0.393 |
| pair_discussion_size_2 | 0.292 |

## Score Variance by Condition (discussion-level unit of analysis)

> Each SD is computed across N independent discussion instances — the correct
> unit of analysis for comparing discussion designs (corrects F4 pseudoreplication).
> Learners are nested observations within each discussion instance.

| Condition | N (independent discussions) | SD (discussion-level) |
|-----------|------------------------------|----------------------|
| large_class_discussion_size_16 | 2 | 0.02 |
| lecture_only | 2 | 0.393 |
| pair_discussion_size_2 | 2 | 0.039 |

**Token cost per correct answer:** 2875 tokens

## Readiness Summary

| Metric | Value |
|--------|-------|
| Overall readiness pass rate | 64% |
| Target (80%) | ✗ READINESS TARGET NOT MET |

### Pass Rate by Check Type

| Check Type | Total | Correct | Pass Rate |
|------------|-------|---------|-----------|
| edge_case | 14 | 14 | 100% |
| procedure_order | 14 | 5 | 36% |
| recall | 14 | 11 | 79% |
| rule_interaction | 14 | 6 | 43% |

> **WARNING:** Readiness target not met. Do not make strong claims about
> ownership or class-size effects from this run.

## Mastery Check Score by Check Type

| Check Type | Total | Correct | Pass Rate |
|------------|-------|---------|-----------|
| edge_case | 14 | 14 | 100% |
| procedure_order | 14 | 5 | 36% |
| recall | 14 | 11 | 79% |
| rule_interaction | 14 | 6 | 43% |

## Memory Coverage by Condition

| Condition | Avg Rules | Edge Cases (%) | Procedure (%) |
|-----------|-----------|----------------|---------------|
| large_class_discussion_size_16 | 4.6 | 54% | 75% |
| lecture_only | 4.5 | 50% | 50% |
| pair_discussion_size_2 | 4.5 | 25% | 75% |

## Ownership Metrics by Condition

| Condition | Avg Ownership Score | Avg Contributions | % Attempted | % Received Feedback |
|-----------|--------------------|--------------------|-------------|---------------------|
| large_class_discussion_size_16 | 1.5 | 0.5 | 50% | 50% |
| lecture_only | 2.0 | 1.0 | 100% | 0% |
| pair_discussion_size_2 | 3.0 | 2.0 | 100% | 100% |

## Memory Delta by Condition (knowledge items acquired during discussion)

| Condition | Avg Memory Delta (items) |
|-----------|--------------------------|
| large_class_discussion_size_16 | 0.0 |
| lecture_only | 0.0 |
| pair_discussion_size_2 | 0.0 |

## Fine-Grained Memory Coverage Post-Discussion (10 items)

| Condition | blue_activation | green_end | red_modifier | yellow_always | activation_before | final_summing | inactive_token | edge_case | debugging_strategy | common_mistake |
|-----------| :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| large_class_discussion_size_16 | 100% | 100% | 100% | 100% | 96% | 42% | 38% | 88% | 50% | 29% |
| lecture_only | 100% | 100% | 100% | 67% | 67% | 0% | 0% | 100% | 50% | 0% |
| pair_discussion_size_2 | 100% | 100% | 100% | 92% | 100% | 8% | 67% | 92% | 67% | 42% |

## Fine-Grained Memory Delta (pre → post discussion)

| Condition | Avg Acquired | Avg Lost | Avg Stable |
|-----------|:------------:|:--------:|:----------:|
| large_class_discussion_size_16 | 0.0 | 0.5 | 7.4 |
| lecture_only | 0.0 | 0.7 | 5.8 |
| pair_discussion_size_2 | 0.0 | 0.6 | 7.7 |

## Interpretation Flags

| Flag | Value |
|------|-------|
| readiness_failed | true |
| ownership_effect_supported | false |
| class_size_effect_supported | false |
| lecture_only_dominant | false |
| discussion_added_value | false |

## Interpretation

**WARNING: readiness_failed = true** — prerequisite readiness target (80%) not met.
Ownership and class-size conclusions from this run are unreliable.

## L6 (short_rule_induction) — Exploratory Appendix

> L6 is excluded from the main score. The exact-match scorer cannot reliably
> grade free-text rule induction (F2: scorer artifact confirmed across v8/v9b/v9c).
> These results are exploratory only — do not use them for condition comparisons.

**L6 task IDs in this run:** l6_induction_02

| Condition | L6 Attempts | Correct (exact-match) | Note |
|-----------|-------------|----------------------|------|
| large_class_discussion_size_16 | 8 | 0 | exact-match only — likely undercount |
| lecture_only | 2 | 0 | exact-match only — likely undercount |
| pair_discussion_size_2 | 4 | 0 | exact-match only — likely undercount |

## Heterogeneity Interpretation

- **classroom_advantage_under_homogeneity** ✓

## Score by Learner Type

| Type | Correct% |
|------|---------|
| passive_listener | 59% |
| rule_extractor | 67% |

## Misconception Correction by Condition

| Condition | Correction Rate | Avg Remaining Misconceptions |
|-----------|----------------|------------------------------|
| large_class_discussion_size_16 | 100% | 0.0 |
| lecture_only | 100% | 0.0 |
| pair_discussion_size_2 | 92% | 0.0 |

## Confidence Calibration

| Metric | Rate |
|--------|------|
| High-confidence wrong | 15% |
| Abstention | 6% |

## Recommended Next Steps

- No ceiling effects at current difficulty. Increase n to improve statistical power.

## Limitations

- Token counts are estimated (chars/4). Actual API token counts may differ by ±20%.
- Auto-scoring uses keyword matching for mistake detection — may under-count partial credit.
- LLM agents are not human learners. Learning is operationalized as condition-specific memory from transcripts.
- Small n. Results are exploratory.

