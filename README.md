# Agent-Based Theory Testing: Bloom's 2-Sigma Problem

[![DOI](https://zenodo.org/badge/1240576444.svg)](https://doi.org/10.5281/zenodo.21186082)

*English / [日本語](README.ja.md)*

Can LLM agents serve as a genuine *test bed* for a social-science theory? This
repository operationalizes Benjamin Bloom's **"2-sigma problem"** — the claim
that one-to-one mastery tutoring produces learning gains roughly two standard
deviations above conventional group instruction — as an experiment on
populations of LLM agents, and asks whether the effect reproduces.

It does not. Across seven design generations (v3–v9c2) on a synthetic rule
domain (*Zarn Tokens*), group instruction met or exceeded one-to-one tutoring.
In the most rigorous experiment (v9c2; 154 learners, 2.4M tokens) the spread
across pedagogical conditions collapsed to **10 percentage points**, while
differences between *learner cognitive profiles* spanned **38 points**. An
apparent 37-point "discussion advantage" in an earlier generation did not
survive replication and prerequisite control.

The paper's more durable contribution is methodological: a **confound-aware
framework** for agent-based theory testing — a five-family confound taxonomy
(F1–F5), a remediation recipe (A-codes), a *population-multiplication* design
for genuine replication, and a *readiness gate* for prerequisite control.

> **Status:** Working paper — not peer-reviewed. This is exploratory theory
> testing and protocol development, not a proof of any educational claim. The
> experiment does not claim LLM agents are human learners; "learning" is
> operationalized as condition-specific memory formed from interaction
> transcripts (model weights are not updated).
>
> **AI involvement:** The manuscript and the entire research artifact — code,
> experiments, analyses, and paper text — were produced end-to-end by LLM
> agents (Anthropic Claude) under the direction and review of the human
> author, who takes full responsibility for the content.

## The paper

- **Markdown:** [`experiments/bloom_1n_vs_1on1/results/2026-06-16-paper-draft.md`](experiments/bloom_1n_vs_1on1/results/2026-06-16-paper-draft.md)
- **LaTeX:** [`experiments/bloom_1n_vs_1on1/results/2026-06-16-paper-draft.tex`](experiments/bloom_1n_vs_1on1/results/2026-06-16-paper-draft.tex)

## Repository layout

| Path | Contents |
|------|----------|
| `experiments/bloom_1n_vs_1on1/` | The experiment: code, configs, prompts, domain, tests, results |
| `experiments/bloom_1n_vs_1on1/README.md` | How to run each generation (v6–v9c2) |
| `experiments/bloom_1n_vs_1on1/results/` | Per-version analyses, methodology addenda, and the paper |
| `experiments/bloom_1n_vs_1on1/config/` | One config per generation (plus haiku `*_smoke.yml` variants) |
| `docs/superpowers/plans/` | Design plans for each generation (development record) |

The raw per-run SQLite databases (`data/*.db`) and run directories
(`data/runs/`) are included in the repository (the ablation run's database was
lost — its generated report is preserved verbatim in `results/`). The
per-version analysis documents in `results/` carry the reported numbers and
run identifiers (see the paper's Appendix A run index), and every production
run's headline figures have been re-verified against the released databases.

## Running the experiment

LLM calls shell out to the Claude Code CLI (`claude --print`), not an API key,
so a full run consumes Claude Code token quota over a long background job. See
[`experiments/bloom_1n_vs_1on1/README.md`](experiments/bloom_1n_vs_1on1/README.md)
for per-generation commands. In brief:

```bash
bundle install
bundle exec ruby experiments/bloom_1n_vs_1on1/scripts/run_experiment_v9c2.rb \
  experiments/bloom_1n_vs_1on1/config/config_v9c2.yml
```

Each generation ships a reduced-scale `*_smoke.yml` config (haiku) for fast
end-to-end validation before committing to a production run.

## Citation

If you use this work, please cite the working paper.

```
Kawasaki, Masumi. "Can LLM Agents Test Social-Science Theory? A Confound-Aware
Framework and a Seven-Generation Negative Result on Bloom's 2-Sigma Problem in
LLM Agents." Working paper, 2026. https://doi.org/10.5281/zenodo.21186083
```

(The badge above resolves the concept DOI `10.5281/zenodo.21186082`, which
always points to the latest version; the citation uses the v1.0.0 version DOI.)

## License

[MIT](LICENSE) © 2026 Masumi Kawasaki
