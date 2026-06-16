# Bloom's 2 Sigma Problem — Agent-Based Experiment

## Research Question

Can the structural conditions of Bloom's 2 Sigma Problem (class size, individual vs. social learning, ownership) be operationalized as an LLM agent experiment, and do those conditions produce measurable differences in subsequent problem-solving performance?

## Important Caveats

This experiment does not claim LLM agents are human learners.

Learning is operationalized as the creation of condition-specific memory from educational interaction transcripts. Model weights are not updated.

This is exploratory theory testing and protocol development, not a proof of educational claims.

## Experiment Versions

| Version | Script | Config | Key Focus |
|---------|--------|--------|-----------|
| v6 | `run_experiment.rb` | `config/config_v6.yml` | Learner type heterogeneity (7 types with memory constraints) |
| v7a | `run_experiment_a.rb` | `config/config_v7a.yml` | Mechanism test: passive_listener rescue |
| v7b | `run_experiment_b.rb` | `config/config_v7b.yml` | Mechanism test: order_confused intervention |
| v8 | `run_experiment_v8.rb` | `config/config_v8.yml` | Flipped learning: Readiness gate + fixed lecture |
| v9b | `run_experiment_v9b.rb` | `config/config_v9b.yml` | Classroom size effect (4 sizes × population-multiplication) |
| v9c | `run_experiment_v9c.rb` | `config/config_v9c.yml` | Readiness-controlled classroom size (v9b + Readiness gate) |
| v9c2 | `run_experiment_v9c2.rb` | `config/config_v9c2.yml` | v9c confound fixes (A0/A3/A5/A6/A8), 5 conditions, n=154 |

Each version has a corresponding smoke test config (`config/*_smoke.yml`) for fast validation at reduced scale with haiku.

## How to Run

```bash
bundle install
```

### v6 — Learner Type Heterogeneity

```bash
bundle exec ruby experiments/bloom_1n_vs_1on1/scripts/run_experiment.rb \
  experiments/bloom_1n_vs_1on1/config/config_v6.yml
```

### v7a — Passive Listener Rescue

```bash
# Smoke test
bundle exec ruby experiments/bloom_1n_vs_1on1/scripts/run_experiment_a.rb \
  experiments/bloom_1n_vs_1on1/config/config_v7a_smoke.yml

# Full run
bundle exec ruby experiments/bloom_1n_vs_1on1/scripts/run_experiment_a.rb \
  experiments/bloom_1n_vs_1on1/config/config_v7a.yml
```

### v7b — Order Confused Intervention

```bash
# Smoke test
bundle exec ruby experiments/bloom_1n_vs_1on1/scripts/run_experiment_b.rb \
  experiments/bloom_1n_vs_1on1/config/config_v7b_smoke.yml

# Full run
bundle exec ruby experiments/bloom_1n_vs_1on1/scripts/run_experiment_b.rb \
  experiments/bloom_1n_vs_1on1/config/config_v7b.yml
```

### v8 — Flipped Learning

```bash
# Smoke test
bundle exec ruby experiments/bloom_1n_vs_1on1/scripts/run_experiment_v8.rb \
  experiments/bloom_1n_vs_1on1/config/config_v8_smoke.yml

# Full run
bundle exec ruby experiments/bloom_1n_vs_1on1/scripts/run_experiment_v8.rb \
  experiments/bloom_1n_vs_1on1/config/config_v8.yml
```

### v9b — Classroom Size

```bash
# Smoke test
bundle exec ruby experiments/bloom_1n_vs_1on1/scripts/run_experiment_v9b.rb \
  experiments/bloom_1n_vs_1on1/config/config_v9b_smoke.yml

# Full run
bundle exec ruby experiments/bloom_1n_vs_1on1/scripts/run_experiment_v9b.rb \
  experiments/bloom_1n_vs_1on1/config/config_v9b.yml
```

### v9c — Readiness-Controlled Classroom Size

```bash
# Smoke test
bundle exec ruby experiments/bloom_1n_vs_1on1/scripts/run_experiment_v9c.rb \
  experiments/bloom_1n_vs_1on1/config/config_v9c_smoke.yml

# Full run
bundle exec ruby experiments/bloom_1n_vs_1on1/scripts/run_experiment_v9c.rb \
  experiments/bloom_1n_vs_1on1/config/config_v9c.yml
```

### v9c2 — Confound-Corrected Full Run

```bash
# Smoke test (3 conditions × n=2, haiku)
bundle exec ruby experiments/bloom_1n_vs_1on1/scripts/run_experiment_v9c2.rb \
  experiments/bloom_1n_vs_1on1/config/config_v9c2_smoke.yml

# Full run (5 conditions × n=5 discussions, sonnet, ~2.4M tokens)
bundle exec ruby experiments/bloom_1n_vs_1on1/scripts/run_experiment_v9c2.rb \
  experiments/bloom_1n_vs_1on1/config/config_v9c2.yml
```

## Regenerating a Report

To regenerate `report.md` for an existing run without re-running the experiment:

```bash
bundle exec ruby experiments/bloom_1n_vs_1on1/scripts/regen_report.rb \
  experiments/bloom_1n_vs_1on1/data/runs/<run_id>
```

## Running Tests

```bash
bash experiments/bloom_1n_vs_1on1/tests/run_tests.sh
```

## Output Files

Run output is written to `experiments/bloom_1n_vs_1on1/data/runs/<run_id>/`.

| File | Contents |
|------|----------|
| `config.json` | Frozen config for this run |
| `transcripts.jsonl` | All education session transcripts |
| `memories.jsonl` | All learner memories (includes `post_readiness` snapshots in v9c+) |
| `attempts.jsonl` | All problem-solving attempts |
| `evaluations.jsonl` | All blind evaluator scores |
| `scores.csv` | Tabular scores for analysis |
| `report.md` | Markdown summary report |

## Results and Analysis

Human-authored analysis documents are in `results/`. Each version has a corresponding analysis report.

| Document | Version |
|----------|---------|
| `results/2026-05-16-development-log.md` | v3–v4 development |
| `results/2026-05-23-v7a-analysis.md` | v7a |
| `results/2026-05-23-v7b-analysis.md` | v7b |
| `results/2026-05-29-v8-analysis.md` | v8 |
| `results/2026-06-04-v9b-full-analysis.md` | v9b |
| `results/2026-06-06-v9c-full-analysis.md` | v9c |
| `results/2026-06-15-v9c2-full-analysis.md` | v9c2（最新） |

Methodology addenda (confound audits, remediation plans) are also in `results/`.

## Repository Layout

```
experiments/bloom_1n_vs_1on1/
├── config/           ← 全バージョンの設定ファイル（本番 + smoke）
├── data/
│   ├── runs/         ← run ごとの出力（.gitignore 済み）
│   └── *.db          ← SQLite DB（.gitignore 済み）
├── domains/          ← ドメイン定義（zarn_tokens）
├── lib/              ← 実験ライブラリ（phases, report, db, ...）
├── prompts/          ← LLM プロンプトテンプレート
├── results/          ← 分析レポート・方法論メモ
├── scripts/          ← 実験実行・分析スクリプト
└── tests/            ← Minitest テストスイート
```

## Key Design Concepts (v9c2)

### Conditions

| 条件 | 基本サイズ | n_disc | 総学習者数 |
|------|----------|--------|-----------|
| lecture_plus_self_reflection | — | — | 4 |
| pair_discussion_size_2 | 2 | 5 | 10 |
| small_class_discussion_size_4 | 4 | 5 | 20 |
| medium_class_discussion_size_8 | 8 | 5 | 40 |
| large_class_discussion_size_16 | 16 | 5 | 80 |

### Confound Fixes Applied in v9c2

| 項目 | 内容 |
|------|------|
| A0 | learner memory を discussion プロンプトに注入 |
| A3 | n_disc=5 の独立反復（population-multiplication design） |
| A5 | 各 discussion 反復に別インスタンスの classroom_teacher を割り当て |
| A6 | lecture_plus_self_reflection に SelfReflection phase を追加 |
| A8 | L6 (short_rule_induction) を main score から除外、LLM semantic scorer を実装済み |

### Learner Types (v9c2)

| Type | Memory Budget | Edge Case Retention | Rule Order Retention |
|------|-------------|--------------------|--------------------|
| rule_extractor | 150 words | 90% | 90% |
| edge_case_dropper | 120 words | 10% | 70% |
| order_confused | 100 words | 60% | 20% |
| passive_listener | 80 words | 20% | 40% |
