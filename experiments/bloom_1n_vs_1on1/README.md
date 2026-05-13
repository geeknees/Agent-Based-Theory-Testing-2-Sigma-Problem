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
