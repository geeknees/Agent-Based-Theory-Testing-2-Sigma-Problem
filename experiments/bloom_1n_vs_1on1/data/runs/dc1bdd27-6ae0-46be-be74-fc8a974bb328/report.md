# Experiment Report (v2)

## Run Metadata

| Field | Value |
|-------|-------|
| run_id | dc1bdd27-6ae0-46be-be74-fc8a974bb328 |
| date | 2026-06-15 |
| models | claude-sonnet-4-6 |
| n_classroom |  |
| n_tutoring |  |
| domain | zarn_tokens |
| tutoring_turns |  |

## Ceiling Effect Summary

> Classification: too_easy (all≥90%), education_sensitive (edu>baseline+10pp), condition_sensitive (tutoring≠classroom by >10pp), too_hard (all<30%), unclear

| Task Type | Difficulty | No-Ed Correct% | Classroom Correct% | Tutoring Correct% | Classification |
|-----------|-----------|----------------|-------------------|-------------------|----------------|
| recall | L1 | 75% | 74% | 0% | unclear |
| edge_case | L2 | 88% | 85% | 0% | unclear |
| rule_interaction | L3 | 75% | 70% | 0% | unclear |
| debugging | L4 | 75% | 74% | 0% | unclear |
| explanation_choice | L7 | 100% | 99% | 0% | unclear |
| peer_error_detection | L7 | 100% | 99% | 0% | unclear |

**No ceiling effects detected.**

## Score by Condition (answer_correct rate)

| Condition | Learners | Attempts | Correct% |
|-----------|---------|---------|---------|
| large_class_discussion_size_16 | 80 | 720 | 81% |
| lecture_only | 4 | 36 | 83% |
| medium_class_discussion_size_8 | 40 | 360 | 86% |
| pair_discussion_size_2 | 10 | 90 | 80% |
| small_class_discussion_size_4 | 20 | 180 | 76% |

## Score by Task Type × Condition

| Task Type | Difficulty | large_class_discussion_size_16 | lecture_only | medium_class_discussion_size_8 | pair_discussion_size_2 | small_class_discussion_size_4 |
|-----------|-----------| ---- | ---- | ---- | ---- | ---- |
| debugging | L4 | 73% | 75% | 79% | 70% | 67% |
| edge_case | L2 | 85% | 88% | 90% | 80% | 80% |
| explanation_choice | L7 | 100% | 100% | 100% | 100% | 95% |
| peer_error_detection | L7 | 99% | 100% | 100% | 100% | 100% |
| recall | L1 | 74% | 75% | 80% | 80% | 60% |
| rule_interaction | L3 | 68% | 75% | 78% | 70% | 65% |

## Score by Difficulty Level × Condition

| Level | Task Types | large_class_discussion_size_16 | lecture_only | medium_class_discussion_size_8 | pair_discussion_size_2 | small_class_discussion_size_4 |
|-------|-----------| ---- | ---- | ---- | ---- | ---- |
| L1 | recall | 74% | 75% | 80% | 80% | 60% |
| L2 | edge_case | 85% | 88% | 90% | 80% | 80% |
| L3 | rule_interaction | 68% | 75% | 78% | 70% | 65% |
| L4 | debugging | 73% | 75% | 79% | 65% | 68% |
| L5 | debugging | 75% | 75% | 80% | 80% | 65% |

## Token Usage by Phase (estimated)

| Phase | Input | Output | Total |
|-------|-------|--------|-------|
| memory | 523087 | 70328 | 593415 |
| mastery_check | 382844 | 72887 | 455731 |
| education_lecture_only | 1945 | 771 | 2716 |
| education_pair_discussion_size_2 | 41497 | 4278 | 45775 |
| education_small_class_discussion_size_4 | 38159 | 4431 | 42590 |
| education_medium_class_discussion_size_8 | 37260 | 4320 | 41580 |
| education_large_class_discussion_size_16 | 31484 | 3551 | 35035 |
| evaluation | 994941 | 164810 | 1159751 |
| **TOTAL** | | | **2376593** |

## Score by Learner Profile

### By Ability

| Ability | Correct% |
|---------|---------|
| unknown | 82% |

### By Misconception

| Misconception | Correct% |
|---------------|---------|
| unknown | 82% |

### By Interest

| Interest | Correct% |
|----------|---------|
| unknown | 82% |

## Score Variance by Condition (std dev of per-learner correct%)

| Condition | Std Dev |
|-----------|--------|
| large_class_discussion_size_16 | 0.279 |
| lecture_only | 0.333 |
| medium_class_discussion_size_8 | 0.234 |
| pair_discussion_size_2 | 0.276 |
| small_class_discussion_size_4 | 0.303 |

## Score Variance by Condition (discussion-level unit of analysis)

> Each SD is computed across N independent discussion instances — the correct
> unit of analysis for comparing discussion designs (corrects F4 pseudoreplication).
> Learners are nested observations within each discussion instance.

| Condition | N (independent discussions) | SD (discussion-level) |
|-----------|------------------------------|----------------------|
| large_class_discussion_size_16 | 5 | 0.099 |
| lecture_only | 4 | 0.333 |
| medium_class_discussion_size_8 | 5 | 0.076 |
| pair_discussion_size_2 | 5 | 0.16 |
| small_class_discussion_size_4 | 5 | 0.072 |

**Token cost per correct answer:** 2099 tokens

## Readiness Summary

| Metric | Value |
|--------|-------|
| Overall readiness pass rate | 90% |
| Target (80%) | ✓ Readiness target met |

### Pass Rate by Check Type

| Check Type | Total | Correct | Pass Rate |
|------------|-------|---------|-----------|
| edge_case | 154 | 154 | 100% |
| procedure_order | 154 | 131 | 85% |
| recall | 154 | 140 | 91% |
| rule_interaction | 154 | 131 | 85% |

## Mastery Check Score by Check Type

| Check Type | Total | Correct | Pass Rate |
|------------|-------|---------|-----------|
| edge_case | 154 | 154 | 100% |
| procedure_order | 154 | 131 | 85% |
| recall | 154 | 140 | 91% |
| rule_interaction | 154 | 131 | 85% |

## Memory Coverage by Condition

| Condition | Avg Rules | Edge Cases (%) | Procedure (%) |
|-----------|-----------|----------------|---------------|
| large_class_discussion_size_16 | 5.1 | 57% | 98% |
| lecture_only | 5.3 | 67% | 100% |
| medium_class_discussion_size_8 | 5.1 | 63% | 100% |
| pair_discussion_size_2 | 5.0 | 57% | 100% |
| small_class_discussion_size_4 | 5.5 | 55% | 100% |

## Ownership Metrics by Condition

| Condition | Avg Ownership Score | Avg Contributions | % Attempted | % Received Feedback |
|-----------|--------------------|--------------------|-------------|---------------------|
| large_class_discussion_size_16 | 0.56 | 0.2 | 19% | 19% |
| lecture_only | 2.0 | 1.0 | 100% | 0% |
| medium_class_discussion_size_8 | 1.5 | 0.5 | 50% | 50% |
| pair_discussion_size_2 | 3.0 | 2.0 | 100% | 100% |
| small_class_discussion_size_4 | 3.0 | 1.0 | 100% | 100% |

## Memory Delta by Condition (knowledge items acquired during discussion)

| Condition | Avg Memory Delta (items) |
|-----------|--------------------------|
| large_class_discussion_size_16 | 0.15 |
| lecture_only | 0.25 |
| medium_class_discussion_size_8 | 0.38 |
| pair_discussion_size_2 | 0.2 |
| small_class_discussion_size_4 | 0.3 |

## Fine-Grained Memory Coverage Post-Discussion (10 items)

| Condition | blue_activation | green_end | red_modifier | yellow_always | activation_before | final_summing | inactive_token | edge_case | debugging_strategy | common_mistake |
|-----------| :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| large_class_discussion_size_16 | 100% | 98% | 100% | 98% | 63% | 90% | 77% | 73% | 89% | 13% |
| lecture_only | 100% | 100% | 100% | 100% | 50% | 100% | 50% | 75% | 58% | 50% |
| medium_class_discussion_size_8 | 100% | 100% | 100% | 97% | 75% | 85% | 71% | 75% | 92% | 13% |
| pair_discussion_size_2 | 100% | 93% | 100% | 93% | 57% | 100% | 70% | 87% | 80% | 10% |
| small_class_discussion_size_4 | 100% | 100% | 100% | 100% | 77% | 100% | 62% | 83% | 82% | 13% |

## Fine-Grained Memory Delta (pre → post discussion)

| Condition | Avg Acquired | Avg Lost | Avg Stable |
|-----------|:------------:|:--------:|:----------:|
| large_class_discussion_size_16 | 0.1 | 0.1 | 8.0 |
| lecture_only | 0.1 | 0.0 | 7.8 |
| medium_class_discussion_size_8 | 0.1 | 0.1 | 7.9 |
| pair_discussion_size_2 | 0.1 | 0.3 | 7.8 |
| small_class_discussion_size_4 | 0.1 | 0.2 | 8.1 |

## Interpretation Flags

| Flag | Value |
|------|-------|
| readiness_failed | false |
| ownership_effect_supported | false |
| class_size_effect_supported | false |
| lecture_only_dominant | false |
| discussion_added_value | false |

## Interpretation

Readiness target met (90%). Interpretations below are valid.

- **Ownership hypothesis NOT supported**: ownership score did not predict final score.
- **Class-size effect NOT supported**: no clear linear relationship between class size and score.

## Token-Normalized Score by Condition (education tokens)

> Learning efficiency: correct answers per 1k tokens spent in the education phase.
> Education tokens = `education_<condition>` phase only (excludes evaluation, memory, readiness).

| Condition | Correct% | Edu Tokens | Correct / 1k Edu Tokens |
|-----------|---------|------------|------------------------|
| large_class_discussion_size_16 | 81% | 35035 | 16.67 |
| lecture_only | 83% | 2716 | 11.05 |
| medium_class_discussion_size_8 | 86% | 41580 | 7.46 |
| pair_discussion_size_2 | 80% | 45775 | 1.57 |
| small_class_discussion_size_4 | 76% | 42590 | 3.19 |

## L6 (short_rule_induction) — Appendix

> L6 is excluded from the main score. The evaluator uses LLM semantic scoring
> (Option B) for short_rule_induction tasks — exact-match produced 0% across all
> runs (F2: scorer artifact, v8/v9b/v9c). Results below use LLM judge scores.
> Do not compare directly with exact-match scores from earlier runs.

**L6 task IDs in this run:** l6_induction_02

| Condition | L6 Attempts | Correct (exact-match) | Note |
|-----------|-------------|----------------------|------|
| large_class_discussion_size_16 | 80 | 0 | exact-match only — likely undercount |
| lecture_only | 4 | 0 | exact-match only — likely undercount |
| medium_class_discussion_size_8 | 40 | 0 | exact-match only — likely undercount |
| pair_discussion_size_2 | 10 | 0 | exact-match only — likely undercount |
| small_class_discussion_size_4 | 20 | 0 | exact-match only — likely undercount |

## Heterogeneity Interpretation

- **classroom_advantage_under_homogeneity** ✓

## Score by Learner Type

| Type | Correct% |
|------|---------|
| edge_case_dropper | 96% |
| order_confused | 77% |
| passive_listener | 58% |
| rule_extractor | 95% |

## Misconception Correction by Condition

| Condition | Correction Rate | Avg Remaining Misconceptions |
|-----------|----------------|------------------------------|
| large_class_discussion_size_16 | 100% | 0.05 |
| lecture_only | 100% | 0.08 |
| medium_class_discussion_size_8 | 99% | 0.03 |
| pair_discussion_size_2 | 100% | 0.03 |
| small_class_discussion_size_4 | 97% | 0.08 |

## Confidence Calibration

| Metric | Rate |
|--------|------|
| High-confidence wrong | 2% |
| Abstention | 4% |

## Recommended Next Steps

- No ceiling effects at current difficulty. Increase n to improve statistical power.

## Limitations

- Token counts are estimated (chars/4). Actual API token counts may differ by ±20%.
- Auto-scoring uses keyword matching for mistake detection — may under-count partial credit.
- LLM agents are not human learners. Learning is operationalized as condition-specific memory from transcripts.
- Small n. Results are exploratory.

