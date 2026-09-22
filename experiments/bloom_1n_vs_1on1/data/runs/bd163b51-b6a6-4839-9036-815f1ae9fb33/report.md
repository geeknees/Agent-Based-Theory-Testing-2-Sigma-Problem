# Experiment Report (v2)

## Run Metadata

| Field | Value |
|-------|-------|
| run_id | bd163b51-b6a6-4839-9036-815f1ae9fb33 |
| date | 2026-06-16 |
| models | claude-haiku-4-5-20251001 |
| n_classroom |  |
| n_tutoring |  |
| domain | zarn_tokens |
| tutoring_turns |  |

## Ceiling Effect Summary

> Classification: too_easy (all≥90%), education_sensitive (edu>baseline+10pp), condition_sensitive (tutoring≠classroom by >10pp), too_hard (all<30%), unclear

| Task Type | Difficulty | No-Ed Correct% | Classroom Correct% | Tutoring Correct% | Classification |
|-----------|-----------|----------------|-------------------|-------------------|----------------|
| recall | L1 | 50% | 100% | 0% | education_sensitive |
| edge_case | L2 | 75% | 100% | 0% | education_sensitive |
| rule_interaction | L3 | 50% | 83% | 0% | education_sensitive |
| debugging | L4 | 33% | 61% | 0% | education_sensitive |
| explanation_choice | L7 | 100% | 100% | 0% | unclear |
| peer_error_detection | L7 | 100% | 100% | 0% | unclear |

**No ceiling effects detected.**

## Score by Condition (answer_correct rate)

| Condition | Learners | Attempts | Correct% |
|-----------|---------|---------|---------|
| large_class_discussion_size_16 | 4 | 36 | 92% |
| lecture_plus_self_reflection | 2 | 18 | 61% |
| pair_discussion_size_2 | 2 | 18 | 72% |

## Score by Task Type × Condition

| Task Type | Difficulty | large_class_discussion_size_16 | lecture_plus_self_reflection | pair_discussion_size_2 |
|-----------|-----------| ---- | ---- | ---- |
| debugging | L4 | 75% | 33% | 33% |
| edge_case | L2 | 100% | 75% | 100% |
| explanation_choice | L7 | 100% | 100% | 100% |
| peer_error_detection | L7 | 100% | 100% | 100% |
| recall | L1 | 100% | 50% | 100% |
| rule_interaction | L3 | 100% | 50% | 50% |

## Score by Difficulty Level × Condition

| Level | Task Types | large_class_discussion_size_16 | lecture_plus_self_reflection | pair_discussion_size_2 |
|-------|-----------| ---- | ---- | ---- |
| L1 | recall | 100% | 50% | 100% |
| L2 | edge_case | 100% | 75% | 100% |
| L3 | rule_interaction | 100% | 50% | 50% |
| L4 | debugging | 63% | 25% | 25% |
| L5 | debugging | 100% | 50% | 50% |

## Token Usage by Phase (estimated)

| Phase | Input | Output | Total |
|-------|-------|--------|-------|
| memory | 25392 | 3163 | 28555 |
| mastery_check | 18580 | 4262 | 22842 |
| education_lecture_plus_self_reflection | 957 | 421 | 1378 |
| education_pair_discussion_size_2 | 8388 | 875 | 9263 |
| education_large_class_discussion_size_16 | 5317 | 570 | 5887 |
| evaluation | 48502 | 12169 | 60671 |
| evaluator | 6787 | 681 | 7468 |
| **TOTAL** | | | **136064** |

## Score by Learner Profile

### By Ability

| Ability | Correct% |
|---------|---------|
| unknown | 79% |

### By Misconception

| Misconception | Correct% |
|---------------|---------|
| unknown | 79% |

### By Interest

| Interest | Correct% |
|----------|---------|
| unknown | 79% |

## Score Variance by Condition (std dev of per-learner correct%)

| Condition | Std Dev |
|-----------|--------|
| large_class_discussion_size_16 | 0.056 |
| lecture_plus_self_reflection | 0.393 |
| pair_discussion_size_2 | 0.236 |

## Score Variance by Condition (discussion-level unit of analysis)

> Each SD is computed across N independent discussion instances — the correct
> unit of analysis for comparing discussion designs (corrects F4 pseudoreplication).
> Learners are nested observations within each discussion instance.

| Condition | N (independent discussions) | SD (discussion-level) |
|-----------|------------------------------|----------------------|
| large_class_discussion_size_16 | 1 | 0.0 |
| lecture_plus_self_reflection | 2 | 0.393 |
| pair_discussion_size_2 | 1 | 0.0 |

**Token cost per correct answer:** 2387 tokens

## Readiness Summary

| Metric | Value |
|--------|-------|
| Overall readiness pass rate | 72% |
| Target (80%) | ✗ READINESS TARGET NOT MET |

### Pass Rate by Check Type

| Check Type | Total | Correct | Pass Rate |
|------------|-------|---------|-----------|
| edge_case | 8 | 8 | 100% |
| procedure_order | 8 | 4 | 50% |
| recall | 8 | 7 | 88% |
| rule_interaction | 8 | 4 | 50% |

> **WARNING:** Readiness target not met. Do not make strong claims about
> ownership or class-size effects from this run.

## Mastery Check Score by Check Type

| Check Type | Total | Correct | Pass Rate |
|------------|-------|---------|-----------|
| edge_case | 8 | 8 | 100% |
| procedure_order | 8 | 4 | 50% |
| recall | 8 | 7 | 88% |
| rule_interaction | 8 | 4 | 50% |

## Memory Coverage by Condition

| Condition | Avg Rules | Edge Cases (%) | Procedure (%) |
|-----------|-----------|----------------|---------------|
| large_class_discussion_size_16 | 3.9 | 50% | 50% |
| lecture_plus_self_reflection | 4.5 | 50% | 100% |
| pair_discussion_size_2 | 4.2 | 33% | 100% |

## Ownership Metrics by Condition

| Condition | Avg Ownership Score | Avg Contributions | % Attempted | % Received Feedback |
|-----------|--------------------|--------------------|-------------|---------------------|
| large_class_discussion_size_16 | 1.5 | 0.5 | 50% | 50% |
| lecture_plus_self_reflection | 2.0 | 1.0 | 100% | 0% |
| pair_discussion_size_2 | 3.0 | 2.0 | 100% | 100% |

## Memory Delta by Condition (knowledge items acquired during discussion)

| Condition | Avg Memory Delta (items) |
|-----------|--------------------------|
| large_class_discussion_size_16 | 0.0 |
| lecture_plus_self_reflection | 0.5 |
| pair_discussion_size_2 | 0.0 |

## Fine-Grained Memory Coverage Post-Discussion (10 items)

| Condition | blue_activation | green_end | red_modifier | yellow_always | activation_before | final_summing | inactive_token | edge_case | debugging_strategy | common_mistake |
|-----------| :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| large_class_discussion_size_16 | 100% | 100% | 100% | 100% | 58% | 0% | 100% | 50% | 25% | 50% |
| lecture_plus_self_reflection | 100% | 100% | 100% | 100% | 100% | 0% | 50% | 67% | 50% | 50% |
| pair_discussion_size_2 | 100% | 100% | 100% | 100% | 17% | 0% | 33% | 100% | 100% | 0% |

## Fine-Grained Memory Delta (pre → post discussion)

| Condition | Avg Acquired | Avg Lost | Avg Stable |
|-----------|:------------:|:--------:|:----------:|
| large_class_discussion_size_16 | 0.0 | 0.4 | 6.8 |
| lecture_plus_self_reflection | 0.2 | 0.0 | 7.0 |
| pair_discussion_size_2 | 0.0 | 0.5 | 6.5 |

## Interpretation Flags

| Flag | Value |
|------|-------|
| readiness_failed | true |
| ownership_effect_supported | false |
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
| large_class_discussion_size_16 | 92% | 5887 | 5.61 |
| lecture_plus_self_reflection | 61% | 1378 | 7.98 |
| pair_discussion_size_2 | 72% | 9263 | 1.40 |

## L6 (short_rule_induction) — Appendix

> L6 is excluded from the main score. The evaluator uses LLM semantic scoring
> (Option B) for short_rule_induction tasks — exact-match produced 0% across all
> runs (F2: scorer artifact, v8/v9b/v9c). Results below use LLM judge scores.
> Do not compare directly with exact-match scores from earlier runs.

**L6 task IDs in this run:** l6_induction_02

| Condition | L6 Attempts | Correct (exact-match) | Note |
|-----------|-------------|----------------------|------|
| large_class_discussion_size_16 | 4 | 0 | exact-match only — likely undercount |
| lecture_plus_self_reflection | 2 | 0 | exact-match only — likely undercount |
| pair_discussion_size_2 | 2 | 0 | exact-match only — likely undercount |

## Heterogeneity Interpretation

- **classroom_advantage_under_homogeneity** ✓

## Score by Learner Type

| Type | Correct% |
|------|---------|
| passive_listener | 67% |
| rule_extractor | 92% |

## Misconception Correction by Condition

| Condition | Correction Rate | Avg Remaining Misconceptions |
|-----------|----------------|------------------------------|
| large_class_discussion_size_16 | 100% | 0.0 |
| lecture_plus_self_reflection | 100% | 0.0 |
| pair_discussion_size_2 | 100% | 0.0 |

## Confidence Calibration

| Metric | Rate |
|--------|------|
| High-confidence wrong | 6% |
| Abstention | 4% |

## Recommended Next Steps

- No ceiling effects at current difficulty. Increase n to improve statistical power.

## Limitations

- Token counts are estimated (chars/4). Actual API token counts may differ by ±20%.
- Auto-scoring uses keyword matching for mistake detection — may under-count partial credit.
- LLM agents are not human learners. Learning is operationalized as condition-specific memory from transcripts.
- Small n. Results are exploratory.

