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
