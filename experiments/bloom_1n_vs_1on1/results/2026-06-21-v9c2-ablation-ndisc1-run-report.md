# Experiment Report (v2)

## Run Metadata

| Field | Value |
|-------|-------|
| run_id | a551c74d-aaed-498f-82cb-188b610380a8 |
| date | 2026-06-21 |
| models | claude-sonnet-4-6 |
| n_classroom |  |
| n_tutoring |  |
| domain | zarn_tokens |
| tutoring_turns |  |

## Ceiling Effect Summary

> Classification: too_easy (all≥90%), education_sensitive (edu>baseline+10pp), condition_sensitive (tutoring≠classroom by >10pp), too_hard (all<30%), unclear

| Task Type | Difficulty | No-Ed Correct% | Classroom Correct% | Tutoring Correct% | Classification |
|-----------|-----------|----------------|-------------------|-------------------|----------------|
| recall | L1 | 25% | 57% | 0% | education_sensitive |
| edge_case | L2 | 38% | 42% | 0% | unclear |
| rule_interaction | L3 | 25% | 20% | 0% | too_hard |
| debugging | L4 | 33% | 39% | 0% | unclear |
| explanation_choice | L7 | 100% | 97% | 0% | unclear |
| peer_error_detection | L7 | 100% | 100% | 0% | unclear |

**No ceiling effects detected.**

## Score by Condition (answer_correct rate)

| Condition | Learners | Attempts | Correct% |
|-----------|---------|---------|---------|
| large_class_discussion_size_16 | 16 | 144 | 51% |
| lecture_plus_self_reflection | 4 | 36 | 47% |
| medium_class_discussion_size_8 | 8 | 72 | 49% |
| pair_discussion_size_2 | 2 | 18 | 72% |
| small_class_discussion_size_4 | 4 | 36 | 58% |

## Score by Task Type × Condition

| Task Type | Difficulty | large_class_discussion_size_16 | lecture_plus_self_reflection | medium_class_discussion_size_8 | pair_discussion_size_2 | small_class_discussion_size_4 |
|-----------|-----------| ---- | ---- | ---- | ---- | ---- |
| debugging | L4 | 38% | 33% | 29% | 67% | 50% |
| edge_case | L2 | 38% | 38% | 44% | 50% | 50% |
| explanation_choice | L7 | 100% | 100% | 88% | 100% | 100% |
| peer_error_detection | L7 | 100% | 100% | 100% | 100% | 100% |
| recall | L1 | 50% | 25% | 63% | 100% | 50% |
| rule_interaction | L3 | 19% | 25% | 13% | 50% | 25% |

## Score by Difficulty Level × Condition

| Level | Task Types | large_class_discussion_size_16 | lecture_plus_self_reflection | medium_class_discussion_size_8 | pair_discussion_size_2 | small_class_discussion_size_4 |
|-------|-----------| ---- | ---- | ---- | ---- | ---- |
| L1 | recall | 50% | 25% | 63% | 100% | 50% |
| L2 | edge_case | 38% | 38% | 44% | 50% | 50% |
| L3 | rule_interaction | 19% | 25% | 13% | 50% | 25% |
| L4 | debugging | 38% | 13% | 19% | 50% | 38% |
| L5 | debugging | 38% | 75% | 50% | 100% | 75% |

## Token Usage by Phase (estimated)

| Phase | Input | Output | Total |
|-------|-------|--------|-------|
| memory | 110751 | 15658 | 126409 |
| mastery_check | 82269 | 22527 | 104796 |
| education_lecture_plus_self_reflection | 2100 | 713 | 2813 |
| education_pair_discussion_size_2 | 8112 | 765 | 8877 |
| education_small_class_discussion_size_4 | 7267 | 691 | 7958 |
| education_medium_class_discussion_size_8 | 7491 | 721 | 8212 |
| education_large_class_discussion_size_16 | 6071 | 558 | 6629 |
| evaluation | 260927 | 74259 | 335186 |
| evaluator | 27485 | 2878 | 30363 |
| **TOTAL** | | | **631243** |

## Score by Learner Profile

### By Ability

| Ability | Correct% |
|---------|---------|
| unknown | 52% |

### By Misconception

| Misconception | Correct% |
|---------------|---------|
| unknown | 52% |

### By Interest

| Interest | Correct% |
|----------|---------|
| unknown | 52% |

## Score Variance by Condition (std dev of per-learner correct%)

| Condition | Std Dev |
|-----------|--------|
| large_class_discussion_size_16 | 0.243 |
| lecture_plus_self_reflection | 0.14 |
| medium_class_discussion_size_8 | 0.178 |
| pair_discussion_size_2 | 0.236 |
| small_class_discussion_size_4 | 0.229 |

## Score Variance by Condition (discussion-level unit of analysis)

> Each SD is computed across N independent discussion instances — the correct
> unit of analysis for comparing discussion designs (corrects F4 pseudoreplication).
> Learners are nested observations within each discussion instance.

| Condition | N (independent discussions) | SD (discussion-level) |
|-----------|------------------------------|----------------------|
| large_class_discussion_size_16 | 1 | 0.0 |
| lecture_plus_self_reflection | 4 | 0.14 |
| medium_class_discussion_size_8 | 1 | 0.0 |
| pair_discussion_size_2 | 1 | 0.0 |
| small_class_discussion_size_4 | 1 | 0.0 |

**Token cost per correct answer:** 3970 tokens

## Readiness Summary

| Metric | Value |
|--------|-------|
| Overall readiness pass rate | 53% |
| Target (80%) | ✗ READINESS TARGET NOT MET |

### Pass Rate by Check Type

| Check Type | Total | Correct | Pass Rate |
|------------|-------|---------|-----------|
| edge_case | 34 | 34 | 100% |
| procedure_order | 34 | 16 | 47% |
| recall | 34 | 18 | 53% |
| rule_interaction | 34 | 4 | 12% |

> **WARNING:** Readiness target not met. Do not make strong claims about
> ownership or class-size effects from this run.

## Mastery Check Score by Check Type

| Check Type | Total | Correct | Pass Rate |
|------------|-------|---------|-----------|
| edge_case | 34 | 34 | 100% |
| procedure_order | 34 | 16 | 47% |
| recall | 34 | 18 | 53% |
| rule_interaction | 34 | 4 | 12% |

## Memory Coverage by Condition

| Condition | Avg Rules | Edge Cases (%) | Procedure (%) |
|-----------|-----------|----------------|---------------|
| large_class_discussion_size_16 | 5.0 | 65% | 100% |
| lecture_plus_self_reflection | 4.8 | 50% | 100% |
| medium_class_discussion_size_8 | 4.9 | 58% | 100% |
| pair_discussion_size_2 | 5.0 | 50% | 100% |
| small_class_discussion_size_4 | 4.8 | 50% | 100% |

## Ownership Metrics by Condition

| Condition | Avg Ownership Score | Avg Contributions | % Attempted | % Received Feedback |
|-----------|--------------------|--------------------|-------------|---------------------|
| large_class_discussion_size_16 | 0.56 | 0.2 | 19% | 19% |
| lecture_plus_self_reflection | 2.0 | 1.0 | 100% | 0% |
| medium_class_discussion_size_8 | 1.5 | 0.5 | 50% | 50% |
| pair_discussion_size_2 | 3.0 | 2.0 | 100% | 100% |
| small_class_discussion_size_4 | 3.0 | 1.0 | 100% | 100% |

## Memory Delta by Condition (knowledge items acquired during discussion)

| Condition | Avg Memory Delta (items) |
|-----------|--------------------------|
| large_class_discussion_size_16 | 0.44 |
| lecture_plus_self_reflection | 0.25 |
| medium_class_discussion_size_8 | 0.25 |
| pair_discussion_size_2 | 0.0 |
| small_class_discussion_size_4 | 0.0 |

## Fine-Grained Memory Coverage Post-Discussion (10 items)

| Condition | blue_activation | green_end | red_modifier | yellow_always | activation_before | final_summing | inactive_token | edge_case | debugging_strategy | common_mistake |
|-----------| :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| large_class_discussion_size_16 | 100% | 100% | 100% | 100% | 100% | 33% | 71% | 73% | 94% | 23% |
| lecture_plus_self_reflection | 100% | 100% | 100% | 100% | 100% | 33% | 67% | 58% | 50% | 8% |
| medium_class_discussion_size_8 | 100% | 100% | 100% | 100% | 96% | 13% | 50% | 71% | 75% | 13% |
| pair_discussion_size_2 | 100% | 100% | 100% | 100% | 83% | 50% | 100% | 83% | 100% | 0% |
| small_class_discussion_size_4 | 100% | 100% | 100% | 100% | 92% | 25% | 50% | 75% | 75% | 58% |

## Fine-Grained Memory Delta (pre → post discussion)

| Condition | Avg Acquired | Avg Lost | Avg Stable |
|-----------|:------------:|:--------:|:----------:|
| large_class_discussion_size_16 | 0.1 | 0.5 | 7.8 |
| lecture_plus_self_reflection | 0.1 | 0.4 | 7.1 |
| medium_class_discussion_size_8 | 0.1 | 0.5 | 7.1 |
| pair_discussion_size_2 | 0.0 | 0.8 | 8.2 |
| small_class_discussion_size_4 | 0.0 | 0.8 | 7.8 |

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

## Token-Normalized Score by Condition (education tokens)

> Learning efficiency: correct answers per 1k tokens spent in the education phase.
> Education tokens = `education_<condition>` phase only (excludes evaluation, memory, readiness).

| Condition | Correct% | Edu Tokens | Correct / 1k Edu Tokens |
|-----------|---------|------------|------------------------|
| large_class_discussion_size_16 | 51% | 6629 | 11.01 |
| lecture_plus_self_reflection | 47% | 2813 | 6.04 |
| medium_class_discussion_size_8 | 49% | 8212 | 4.26 |
| pair_discussion_size_2 | 72% | 8877 | 1.46 |
| small_class_discussion_size_4 | 58% | 7958 | 2.64 |

## L6 (short_rule_induction) — Appendix

> L6 is excluded from the main score. The evaluator uses LLM semantic scoring
> (Option B) for short_rule_induction tasks — exact-match produced 0% across all
> runs (F2: scorer artifact, v8/v9b/v9c). Results below use LLM judge scores.
> Do not compare directly with exact-match scores from earlier runs.

**L6 task IDs in this run:** l6_induction_02

| Condition | L6 Attempts | Correct (exact-match) | Note |
|-----------|-------------|----------------------|------|
| large_class_discussion_size_16 | 16 | 0 | exact-match only — likely undercount |
| lecture_plus_self_reflection | 4 | 0 | exact-match only — likely undercount |
| medium_class_discussion_size_8 | 8 | 0 | exact-match only — likely undercount |
| pair_discussion_size_2 | 2 | 0 | exact-match only — likely undercount |
| small_class_discussion_size_4 | 4 | 0 | exact-match only — likely undercount |

## Heterogeneity Interpretation

- **classroom_advantage_under_homogeneity** ✓

## Score by Learner Type

| Type | Correct% |
|------|---------|
| edge_case_dropper | 63% |
| order_confused | 43% |
| passive_listener | 36% |
| rule_extractor | 63% |

## Misconception Correction by Condition

| Condition | Correction Rate | Avg Remaining Misconceptions |
|-----------|----------------|------------------------------|
| large_class_discussion_size_16 | 100% | 0.0 |
| lecture_plus_self_reflection | 100% | 0.0 |
| medium_class_discussion_size_8 | 100% | 0.0 |
| pair_discussion_size_2 | 100% | 0.0 |
| small_class_discussion_size_4 | 100% | 0.0 |

## Confidence Calibration

| Metric | Rate |
|--------|------|
| High-confidence wrong | 15% |
| Abstention | 3% |

## Recommended Next Steps

- No ceiling effects at current difficulty. Increase n to improve statistical power.

## Limitations

- Token counts are estimated (chars/4). Actual API token counts may differ by ±20%.
- Auto-scoring uses keyword matching for mistake detection — may under-count partial credit.
- LLM agents are not human learners. Learning is operationalized as condition-specific memory from transcripts.
- Small n. Results are exploratory.

