# Experiment Report

## Run Metadata

| Field | Value |
|-------|-------|
| run_id | ab4061b6-5c7d-4689-8c69-18df5957730e |
| date | 2026-05-14 |
| models | claude-sonnet-4-6 |
| n_classroom | 2 |
| n_tutoring | 2 |
| domain | zarn_tokens |

## Average Scores by Condition

| Condition | Avg Total (out of 20) |
|-----------|----------------------|
| classroom (1:N) | 20.00 |
| tutoring (1on1) | 20.00 |

## Average Scores by Task Type

| Task Type | Condition | Avg Total |
|-----------|-----------|-----------|
| recall | classroom | 20.00 |
| recall | 1on1 | 20.00 |
| near_transfer | classroom | 20.00 |
| near_transfer | 1on1 | 20.00 |
| far_transfer | classroom | 20.00 |
| far_transfer | 1on1 | 20.00 |

## Dimension Breakdown

| Dimension | Classroom Avg | Tutoring Avg |
|-----------|---------------|--------------|
| correctness | 4.00 | 4.00 |
| reasoning_quality | 4.00 | 4.00 |
| rule_application | 4.00 | 4.00 |
| error_checking | 4.00 | 4.00 |
| autonomy | 4.00 | 4.00 |

## Sample Evaluator Comments

- **12f545cf-21b9-4d05-b42b-89d4dad63a14** (1on1, far_transfer): Exemplary response with fully correct answer, explicit step-by-step reasoning, complete rule application including the novel Purple rule, thorough self-verification table, and autonomous problem-solving with a thoughtful edge-case note.
- **12f545cf-21b9-4d05-b42b-89d4dad63a14** (1on1, near_transfer): Flawless response with explicit step-by-step reasoning, correct application of all rules including the Red modifier and Green activation condition, a thorough verification table, and fully autonomous problem-solving.
- **12f545cf-21b9-4d05-b42b-89d4dad63a14** (1on1, recall): Exemplary response with fully correct answer, explicit step-by-step reasoning, accurate application of all rules, thorough verification via summary table, and completely autonomous problem-solving.
- **42eee4cd-bb69-445b-8a2f-799480cfaab1** (1on1, far_transfer): Perfect response: all rules identified and applied correctly, explicit step-by-step reasoning, thorough verification table, and fully autonomous problem-solving reaching the correct answer of 25.
- **42eee4cd-bb69-445b-8a2f-799480cfaab1** (1on1, near_transfer): Exemplary response with fully correct answer, explicit step-by-step reasoning, all rules correctly identified and applied, thorough self-verification of each token, and no reliance on hints or scaffolding.
- **42eee4cd-bb69-445b-8a2f-799480cfaab1** (1on1, recall): Exemplary response with fully correct answer, explicit step-by-step reasoning, all rules correctly identified and applied, thorough self-verification, and completely autonomous problem-solving.

## Limitations

- LLM agents are not human learners. Learning is operationalized as condition-specific memory formation from session transcripts, not model weight updates.
- Small sample size (4 learners). Results are exploratory.
- The evaluator is the same model as the learner, which may introduce systematic bias.
- All scores are produced by a single blind-evaluator LLM call per attempt. No inter-rater reliability check.
- This experiment tests whether the experimental protocol is viable, not whether Bloom's theory applies to LLMs.

## How to Inspect Results

```bash
# Open SQLite DB directly
sqlite3 experiments/bloom_1n_vs_1on1/data/experiment.db

# View scores CSV
cat experiments/bloom_1n_vs_1on1/data/runs/ab4061b6-5c7d-4689-8c69-18df5957730e/scores.csv
```
