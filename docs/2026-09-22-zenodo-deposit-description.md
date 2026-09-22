# Zenodo deposit description(次リリース用ドラフト)

作成: 2026-09-22 / 対象: セルフ査読完了後の新バージョン

> **使い方:** 下の「Description(HTML)」を Zenodo の Description 欄に貼る。
> Zenodo はバージョンごとに DOI を発行するため、既存 deposit の "New version" として上げる。
> Title / Authors / License / Keywords は既存バージョンを踏襲し、下の変更点だけ反映する。

---

## メタデータ

| 項目 | 値 |
|------|-----|
| Title | Can LLM Agents Test Social-Science Theory? A Confound-Aware Framework and a Seven-Generation Negative Result on Bloom's 2-Sigma Problem in LLM Agents |
| Authors | Kawasaki, Masumi(川崎 真素実)— Independent researcher |
| Upload type | Publication → Working paper |
| License | MIT(コード・データ) |
| Language | eng(日本語訳を同梱) |
| Keywords | LLM agents; agent-based simulation; Bloom's 2-sigma problem; internal validity; pseudoreplication; confound analysis; educational technology; negative results |
| Related identifiers | Research journal: `https://kotowari-modoki.github.io/experimental-commons/research/agent-based-theory-testing-2-sigma-problem/`(is documented by) |

---

## Description(HTML — Zenodo の Description 欄にそのまま貼る)

```html
<p><strong>Working paper — not peer-reviewed.</strong> This version adds a completed
author self-review of every experimental generation, a Japanese translation, and a
typeset PDF.</p>

<p>We ask whether LLM agents can serve as a genuine test bed for an educational
theory — Bloom's "2-sigma problem," the claim that one-to-one mastery tutoring
produces learning gains roughly two standard deviations above group instruction.
Over seven design generations we operationalize learning as the formation of
condition-specific compact memory from an education-phase transcript, evaluated on a
synthetic rule domain under a strict memory-only protocol.</p>

<p><strong>Two contributions.</strong> First, a negative result: across every
generation, group instruction met or exceeded one-to-one tutoring, and in the most
rigorous experiment (154 learners, 2.4M tokens) the spread across pedagogical
conditions collapsed to 10 percentage points while learner-type differences spanned
38 points. Class size, learner ownership and discussion each failed to predict
outcome once prerequisites were controlled and discussions were genuinely replicated.
Second, a confound-aware methodology: an audit of our own pipeline surfaced five
confound families (F1–F5) — static corrective feedback, an exact-match scoring
artifact, missing context injection into discussion agents, pseudoreplication, and
single-instance role agents plus learning-budget asymmetry — with a remediation
recipe centred on a population-multiplication design for true replication and a
readiness gate for prerequisite control.</p>

<p><strong>What changed in this version.</strong> The author reviewed all thirteen
units of the work — every generation, the confound audit, and the paper itself —
tracing each reported figure to the released databases. Every number in the paper
body reconciles. The review also changed the paper:</p>

<ul>
  <li>Section 8 now states the three null results as separate findings rather than
      bundling them into one sentence; a null reported only as a flag value is easy
      to miss.</li>
  <li>Section 9 gains three limitations: two of the four readiness items appear as
      worked examples in the fixed lecture; the L6 semantic judge's verdict never
      reaches the score field, so no generation here has a validated L6 measurement;
      and one of the four learner types was never actually instantiated.</li>
  <li>The explanation that attributed correction-outcome decoupling to a procedural
      deficit is withdrawn in all three places it appeared — the constraint that was
      supposed to create that deficit never did.</li>
  <li>Section 9 now quantifies run-to-run variation: on the same lecture and the same
      readiness check, one check type passed at 50%, 85% and 12% across three runs.</li>
  <li>The cross-version audit table is extended to v9c2, so the generation that
      resolved the pseudoreplication confound is recorded as having done so.</li>
  <li>One reference DOI was wrong and is corrected.</li>
</ul>

<p><strong>Artifact.</strong> Code, configs, prompts, the synthetic domain, per-run
SQLite databases and raw run directories are included. The ablation run's database
was lost; its generated report is released verbatim, with a note that the report
generator emits sections that run did not have. The author's review records are
released under <code>results/reviews/</code>, stating for each generation what was
verified against the databases and what is taken on trust. A day-by-day research
journal is published separately at Experimental Commons.</p>

<p><strong>AI involvement.</strong> The experiments, analyses and manuscript were
produced end-to-end by LLM agents under the human author's direction and review. The
same model family serves as the experimental subjects; the paper discusses this
reflexivity and notes that independent human replication of the confound audit is
the obvious external check.</p>
```

---

## Description(プレーンテキスト版 — HTML が使えない場合)

<details>
<summary>展開</summary>

Working paper — not peer-reviewed. This version adds a completed author self-review
of every experimental generation, a Japanese translation, and a typeset PDF.

We ask whether LLM agents can serve as a genuine test bed for an educational theory —
Bloom's "2-sigma problem," the claim that one-to-one mastery tutoring produces
learning gains roughly two standard deviations above group instruction. Over seven
design generations we operationalize learning as the formation of condition-specific
compact memory from an education-phase transcript, evaluated on a synthetic rule
domain under a strict memory-only protocol.

Two contributions. First, a negative result: across every generation, group
instruction met or exceeded one-to-one tutoring, and in the most rigorous experiment
(154 learners, 2.4M tokens) the spread across pedagogical conditions collapsed to 10
percentage points while learner-type differences spanned 38 points. Class size,
learner ownership and discussion each failed to predict outcome once prerequisites
were controlled and discussions were genuinely replicated. Second, a confound-aware
methodology: an audit of our own pipeline surfaced five confound families (F1-F5)
with a remediation recipe centred on a population-multiplication design for true
replication and a readiness gate for prerequisite control.

What changed in this version: the author reviewed all thirteen units of the work —
every generation, the confound audit, and the paper itself — tracing each reported
figure to the released databases. Section 8 now states the three null results as
separate findings. Section 9 gains three limitations (readiness items overlapping the
lecture; the L6 semantic judge's verdict never reaching the score field; one learner
type never instantiated) and quantifies run-to-run variation. The procedural-deficit
explanation is withdrawn. The audit table is extended to v9c2. One reference DOI is
corrected.

Artifact: code, configs, prompts, the synthetic domain, per-run SQLite databases and
raw run directories. The ablation run's database was lost; its generated report is
released verbatim. Review records are under results/reviews/. A day-by-day research
journal is published separately at Experimental Commons.

AI involvement: the experiments, analyses and manuscript were produced end-to-end by
LLM agents under the human author's direction and review.

</details>

---

## 確認事項(アップロード前)

- [ ] 既存 deposit の **"New version"** として上げる(新規 deposit にしない。Concept DOI が保たれる)
- [ ] アップロードするファイル: リポジトリのアーカイブ(GitHub リリース連携なら自動)。
      PDF 単体も添える場合は `2026-06-16-paper-draft.pdf`
- [ ] **Related identifiers** に研究日誌の URL を "is documented by" で追加
- [ ] Version 欄に識別子を入れる(例: `v2-self-reviewed`)
- [ ] 論文本文に Zenodo DOI の記載は**現状なし**。入れるなら次バージョンで本文へ追記が要る
      (Concept DOI を使えばバージョン間で不変)
