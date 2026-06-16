# Agent Handoff — Bloom 2-Sigma Paper & Ablation (2026-06-16)

Paste the section below into a fresh agent session. It is self-contained.

---

## Handoff Prompt

You are taking over an in-progress research-engineering task in the repository
`/Users/masumi/tmp/Agent-Based-Theory-Testing-2-Sigma-Problem`.

### What this project is

An agent-based experiment testing Bloom's "2-sigma problem" (does one-to-one
tutoring beat group instruction?) using LLM agents on a synthetic rule domain
("Zarn Tokens"). "Learning" is operationalized as compact memory formed during
an education phase, evaluated under a memory-only protocol (rules withheld from
the eval prompt). Seven design generations (v3–v9c2) were run. The work has
reached the stage of writing a publication (arXiv/Zenodo) and is now resolving
the paper's main methodological weakness via an ablation.

### Current state (read these first)

- **Git:** on branch `paper-draft-and-ablation-configs` (branched from `main`).
  Two commits made this session, **not pushed**. `main` is protected — never
  push to it directly; push this feature branch and open a PR if asked.
- **The paper:** `experiments/bloom_1n_vs_1on1/results/2026-06-16-paper-draft.md`
  — English, ~6,000 words, target cs.AI/cs.MA, full paper. Dual contribution:
  (1) a confound-aware methodology (F1–F5 confound taxonomy → A-code
  remediations; population-multiplication design; readiness gate), and (2) a
  confound-controlled **negative result** — Bloom's social-interaction
  advantage does not robustly reproduce in this agent environment.
  Author: **Kawasaki, Masumi / Independent researcher / geeknees@gmail.com**
  (style matched to Zenodo DOI 10.5281/zenodo.20034240).
- **All quantitative claims in the paper were fact-checked** against the
  per-version analysis docs in `experiments/bloom_1n_vs_1on1/results/` and all
  MATCH. Do not change numbers without re-verifying against those docs.
- A fresh peer-review pass was already incorporated: the v9c→v9c2 causal claim
  is deliberately softened to "did not survive control" because there is **no
  single-variable ablation yet** (that is pending task #1 below).

### Key facts you will need

- **Headline results.** v9c (run `b412cfdb`, n=34): readiness FAILED at 69%,
  condition spread 37pp (pair 65% … lecture 28%). v9c2 (run `dc1bdd27`, n=154):
  readiness 90%, condition spread collapsed to 10pp (medium 86% … small 76%),
  learner-type spread 38pp (edge_case_dropper 96% vs passive_listener 58%);
  flags class_size/ownership/discussion_added_value all false. ~2.38M tokens.
- **Confound→remediation map.** F1 static corrective note (open); F2 exact-match
  scoring artifact → A8 (exclude L6 + LLM semantic judge); F3 no context in
  discussion → A0 (inject memory); F4 pseudoreplication (`unique_discussions=1`)
  → A3 (population-multiplication, n_disc=5 independent discussions); F5a learner
  diversity → A4 (already satisfied v8+); F5b single-instance roles → A5 (fresh
  teacher per discussion); F5c learning-budget asymmetry → A6 (self-reflection
  phase for the lecture condition). A-codes are real change-IDs, hence
  non-contiguous; see paper Appendix B.

### How the harness runs (critical gotchas)

- **LLM calls shell out to `claude --print`** (`lib/llm.rb`), NOT an API key.
  This **consumes the user's Claude Code token quota**, pauses 2s between calls,
  and **sleeps 5.5 hours on a rate-limit hit** (auto-resumes). Real runs are
  long background jobs (hundreds of calls). NEVER launch a sonnet run without
  explicit user authorization — it spends their quota over hours.
- Run Ruby commands as: `eval "$(mise activate zsh)"` then
  `bundle exec ruby <script> <config>`. Ruby 4.0.5, bundle 4.0.10 are installed.
- Configs live in `experiments/bloom_1n_vs_1on1/config/` (all consolidated this
  session). Run scripts in `scripts/`. `data/runs/` and `*.db` are gitignored.
- **Naming:** the lecture condition was renamed `lecture_only` →
  `lecture_plus_self_reflection`. The OLD production DB (`dc1bdd27`) still has
  `lecture_only`; NEW runs emit `lecture_plus_self_reflection`. `regen_report.rb`
  handles both. Don't "fix" this mismatch.
- **L6** (`short_rule_induction`) is excluded from the main score and routed to
  an LLM semantic judge via `SEMANTIC_TASK_TYPES` in `lib/phases/evaluator.rb`.

### Pending tasks (priority order)

1. **Run the production ablation, then integrate it into the paper.** This is
   the top priority and resolves the paper's main weakness. Config is ready:
   `config/config_v9c2_ablation_ndisc1.yml` (sonnet, all 5 conditions,
   **n_disc=1** = single discussion per condition like v9c, but with A0/A5/A6/A8
   still ON). The haiku smoke (`config/config_v9c2_ablation_smoke.yml`) already
   passed end-to-end (exit 0; rename and L6 semantic scoring confirmed). To run
   (ONLY after the user explicitly authorizes the token spend):
   ```
   eval "$(mise activate zsh)"
   bundle exec ruby experiments/bloom_1n_vs_1on1/scripts/run_experiment_v9c2.rb \
     experiments/bloom_1n_vs_1on1/config/config_v9c2_ablation_ndisc1.yml
   ```
   Run it as a background job; expect 1–3h wall-clock if no rate limits, longer
   if hit. **Interpretation:** if the n_disc=1 condition spread re-inflates
   toward ~37pp, pseudoreplication (F4/A3) was the driver; if it stays ~10pp,
   readiness/A0/A6 were. Also re-measures readiness at n~34 with current code —
   if it comes out ~90% (not 69%), v9c's failure was a small-sample draw and the
   paper's readiness-confound narrative must be weakened. Update paper §7/§8/§9
   accordingly and report the new run_id.

2. **Add formal references/citations to §2 Related Work.** Currently
   descriptive prose with no formal citations. Needs at minimum: Bloom (1984,
   "The 2 Sigma Problem"); generative agents (Park et al. 2023); LLMs as
   simulated/"silicon" subjects (e.g. Argyle et al. 2023, Aher et al. 2023) and
   critiques of their fidelity; pseudoreplication (Hurlbert 1984); and a
   citation for exact-match scoring artifacts. Add an inline citation style and
   a References section.

3. **LaTeX conversion** for arXiv submission (the draft is Markdown).

4. **Add an MIT license note + "working paper / not peer-reviewed" disclaimer**
   at the top of the paper, matching the author's Zenodo release style.

5. **Optional:** push the branch and open a PR (only if asked).

### Working agreements (from the repo's CLAUDE.md / AGENTS.md)

- Propose-first for multi-file or significant changes; commit only when asked;
  never push to `main`; no `--no-verify`, no GPG signing.
- Verify before claiming done; report failures honestly with output.
- Re-read files before editing after long context; match surrounding style.

Start by reading the paper draft and `results/2026-06-15-v9c2-full-analysis.md`,
then confirm with the user which pending task to take first (default: #1, the
ablation — but it costs their token quota, so get explicit go-ahead before
launching the sonnet run).
