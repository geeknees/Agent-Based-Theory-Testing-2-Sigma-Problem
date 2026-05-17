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

## How to Run

```bash
bundle install
bundle exec ruby experiments/bloom_1n_vs_1on1/scripts/run_experiment.rb experiments/bloom_1n_vs_1on1/config.yml
```

Output will be written to `experiments/bloom_1n_vs_1on1/data/runs/<run_id>/`.

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
