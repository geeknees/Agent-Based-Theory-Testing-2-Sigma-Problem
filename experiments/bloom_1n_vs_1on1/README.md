# Bloom's 2 Sigma Problem — Agent-Based Experiment

## Research Question

Can the structural conditions of Bloom's 2 Sigma Problem (1:N classroom vs. 1on1 tutoring) be operationalized as an LLM agent experiment, and do those conditions produce measurable differences in subsequent autonomous problem-solving behavior?

## Hypotheses

- **H1 (Tutoring Effect):** 1on1 learner agents outperform classroom learner agents on evaluation tasks.
- **H2 (Memory Quality):** 1on1 learners form more specific, strategy-rich learning memories.
- **H3 (Transfer):** Condition differences are larger on near/far transfer tasks than recall tasks.
- **H4 (Method):** This protocol is a viable scaffold for translating social-scientific theories into agent experiments.

## Important Caveats

This experiment does not claim LLM agents are human learners.

Learning is operationalized as the creation of condition-specific memory from educational interaction transcripts. Model weights are not updated.

This is exploratory theory testing and protocol development, not a proof of educational claims.

## v3 Methodology: Memory-Only Evaluation

In v3, evaluation tasks no longer include the rules in the learner-visible prompt.

Learners must rely on compact memory generated during the education phase. Hidden rules are used only by the auto-scorer.

This prevents the experiment from measuring simple in-context rule reading and better isolates the effect of the educational condition.

### Three conditions in v3

| Condition | Education | Memory |
|-----------|-----------|--------|
| no_education | None | Empty (baseline) |
| classroom | 1:N lesson + Q&A | Compact memory from transcript |
| tutoring | 1on1 (2 exchanges) | Compact memory from transcript |

### Task classification

| Classification | Meaning |
|---------------|---------|
| too_easy | All 3 conditions ≥ 90% correct |
| too_hard | All 3 conditions < 30% correct |
| education_sensitive | Classroom or tutoring clearly outperforms no_education |
| condition_sensitive | Education helps AND tutoring differs from classroom |
| unclear | No strong signal in any direction |

### Calibration with weaker model

To diagnose task difficulty, set `learner_diagnostic` in config to a weaker model (e.g., `claude-haiku-4-5-20251001`) and re-run with `learner` pointing to that model. If the weaker model performs much worse, the task is genuinely hard. If it also solves easily, the task design needs rethinking.

## v4 Methodology: Longer Tutoring + Task Validity Fixes

### Changes from v3

**Tutoring extended to 4 exchanges (8 turns):**

| Exchange | Tutor | Learner |
|----------|-------|---------|
| 1 | Opener — teach first concept with example | Response — state understanding or ask question |
| 2 | Diagnostic Q1 — apply a rule to a sequence | Answer Q1 — step-by-step reasoning |
| 3 | **Targeted feedback** — correct errors explicitly | **Reflection** — restate corrected rule in own words |
| 4 | Diagnostic Q2 — harder, tests different rule | Answer Q2 — apply corrected understanding |

Exchange 3 (feedback + reflection) is the critical addition. In v3, the tutor identified a misconception in Exchange 2 but had no chance to correct it. Exchange 3 closes this loop.

**Task redesigns:**

| Task | v3 problem | v4 fix |
|------|------------|--------|
| L5 counterexample | Solvable by pure logic (no domain rules needed) | Replaced with l5_debug_03: debugging [Red,Green,Blue,Green] where Red doubles Green, not Blue |
| L6 induction | Sequence [Yellow,Orange,Blue,Green] required 3 simultaneous rules | Simplified to [Yellow,Orange,Green] — tests Orange rule + Green end rule only |

**n increased:** n_classroom=6, n_tutoring=6, n_no_education=4 for better statistical power.

## v5 Methodology: Learner Heterogeneity

### Core hypothesis

Tutoring advantage should increase as learner heterogeneity increases. v4 assumed homogeneous learners; v5 makes heterogeneity explicit.

### Four conditions

| Condition | Education | Learner profiles |
|-----------|-----------|-----------------|
| no_education | None | No profile |
| homogeneous_classroom | 1:N shared lesson | All medium ability, same misconception (forgets edge cases) |
| heterogeneous_classroom | 1:N shared lesson | Mixed: high/medium/low ability, different misconceptions |
| 1on1 tutoring | 1on1 adapted session | Same profiles as heterogeneous_classroom |

Tutoring learners use the **same profiles as heterogeneous_classroom** for direct comparison.

### Heterogeneity interpretation

| Classification | Meaning |
|---------------|---------|
| tutoring_advantage_under_heterogeneity | 1on1 > heterogeneous_classroom |
| classroom_advantage_under_homogeneity | homogeneous_classroom ≥ 1on1 |
| heterogeneity_penalty | heterogeneous_classroom < homogeneous_classroom |
| bottom_learner_rescue | low-ability learners do better in tutoring than in heterogeneous_classroom |

## v6 Methodology: Theory-Driven Learner Types

### Core change

v5 used role-play profiles (ability/misconception/interest attributes) which did not produce meaningful agent differences because the underlying LLM capability was unchanged. v6 replaces profiles with **post-LLM memory constraints** applied after the LLM generates memory from a transcript.

### 7 learner types

| Type | Memory Budget | Edge Case Retention | Rule Order Retention | Question Prob |
|------|-------------|--------------------|--------------------|--------------|
| rule_extractor | 150 words | 90% | 90% | 30% |
| edge_case_dropper | 120 words | 10% | 70% | 20% |
| order_confused | 100 words | 60% | 20% | 40% |
| passive_listener | 80 words | 20% | 40% | 0% |
| help_seeker | 130 words | 70% | 80% | 90% |
| answer_first | 100 words | 30% | 50% | 10% |
| example_memorizer | 120 words | 40% | 50% | 20% |

### Constraints applied post-LLM

1. **edge_case_retention**: each edge_case item is independently dropped with probability `1 - retention`
2. **rule_order_retention**: if `rand >= retention`, the rules array is shuffled
3. **memory_budget_words**: memory is trimmed to budget by dropping lowest-priority fields first
4. **question_asking_probability**: in classroom, `passive_listener` (prob=0.0) never asks — the LLM call is skipped entirely

### 7-field memory schema

```json
{
  "rules": [],
  "examples": [],
  "edge_cases": [],
  "strategy": [],
  "corrected_misconceptions": [],
  "remaining_misconceptions": [],
  "uncertain_rules": []
}
```

### Tutoring: diagnostic-correct-retest loop

Exchange 3 changed from "feedback + reflection" to "correction + correction_application". Exchange 4 became a **retest** on the same misconception, confirming whether the correction stuck.

### v6 key results (run_id: cd5d2f0e)

| Condition | Correct% |
|-----------|---------|
| no_education | 0% |
| homogeneous_classroom (4× edge_case_dropper) | 94% |
| heterogeneous_classroom (mixed 4 types) | 59% |
| 1on1 (same mixed 4 types) | 59% |

Type breakdown: passive_listener=13% (hetero_classroom) vs 38% (1on1); order_confused=88% (hetero_classroom) vs 63% (1on1). These opposing effects motivated v7.

## v7 Methodology: Mechanism Tests

### Research question

v6 showed 1on1 tutoring helped passive_listener (+25pp) but hurt order_confused (−25pp) compared to heterogeneous_classroom. v7 is a targeted mechanism test to explain why.

### Experiment A — Passive Listener Rescue

**All learners: passive_listener**

| Condition | Description |
|-----------|-------------|
| classroom_public_qa | Standard shared lesson; passive_listener never asks (prob=0.0) |
| classroom_forced_checkin | Shared lesson + teacher asks each learner one check-in question (forced) |
| one_on_one_tutoring | Standard 1on1 diagnostic-correct-retest session |

**Interpretation:** If `classroom_forced_checkin ≈ one_on_one_tutoring`, the benefit is forced interaction, not personalization.

### Experiment B — Order Confused Intervention

**All learners: order_confused**

| Condition | Description |
|-----------|-------------|
| classroom_public_qa | Standard shared lesson with order-focused context hint |
| generic_one_on_one_tutoring | Standard 1on1 targeting the `applies_modifiers_before_activation` misconception |
| procedure_scaffolded_one_on_one_tutoring | 1on1 with explicit 4-step procedure: ① check activation → ② apply modifiers → ③ edge cases → ④ sum. Learner must restate procedure; must label steps during retest |

**Interpretation:** If `procedure_scaffolded > generic`, the v6 failure was intervention mismatch (generic tutoring targets propositional misconceptions, not procedural ordering). If scaffolded still fails, order_confused may require mastery loops.

## How to Run

### v6 (full heterogeneity experiment)

```bash
bundle install
bundle exec ruby experiments/bloom_1n_vs_1on1/scripts/run_experiment.rb \
  experiments/bloom_1n_vs_1on1/config.yml
```

### v7 Experiment A — Passive Listener Rescue

```bash
# Smoke test (n=1, haiku)
bundle exec ruby experiments/bloom_1n_vs_1on1/scripts/run_experiment_a.rb \
  experiments/bloom_1n_vs_1on1/config_v7a_smoke.yml

# Full run (n=4, sonnet)
bundle exec ruby experiments/bloom_1n_vs_1on1/scripts/run_experiment_a.rb \
  experiments/bloom_1n_vs_1on1/config_v7a.yml
```

### v7 Experiment B — Order Confused Intervention

```bash
# Smoke test (n=1, haiku)
bundle exec ruby experiments/bloom_1n_vs_1on1/scripts/run_experiment_b.rb \
  experiments/bloom_1n_vs_1on1/config_v7b_smoke.yml

# Full run (n=4, sonnet)
bundle exec ruby experiments/bloom_1n_vs_1on1/scripts/run_experiment_b.rb \
  experiments/bloom_1n_vs_1on1/config_v7b.yml
```

Output is written to `experiments/bloom_1n_vs_1on1/data/runs/<run_id>/`.

## Output Files

| File | Contents |
|------|----------|
| `config.json` | Frozen config for this run |
| `transcripts.jsonl` | All education session transcripts |
| `memories.jsonl` | All learner memories |
| `attempts.jsonl` | All problem-solving attempts |
| `evaluations.jsonl` | All blind evaluator scores |
| `scores.csv` | Tabular scores for analysis |
| `report.md` | Markdown summary report |

## Running Tests

```bash
bash experiments/bloom_1n_vs_1on1/tests/run_tests.sh
```

## Analyzing Results

```bash
bundle exec ruby experiments/bloom_1n_vs_1on1/scripts/analyze_results.rb \
  experiments/bloom_1n_vs_1on1/data/runs/<run_id>
```
