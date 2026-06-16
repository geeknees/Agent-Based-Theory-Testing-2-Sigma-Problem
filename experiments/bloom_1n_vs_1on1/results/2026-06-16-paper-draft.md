# Can LLM Agents Test Social-Science Theory? A Confound-Aware Framework and a Seven-Generation Negative Result on Bloom's 2-Sigma Problem in LLM Agents

**Author:** Kawasaki, Masumi
**Affiliation:** Independent researcher
**Contact:** geeknees@gmail.com
**Date:** 2026-06-16
**Preprint category (intended):** cs.AI, cs.MA
**Artifact:** Full code, configs, per-run databases, and version-by-version analyses are released with this paper.

---

## Abstract

Large language model (LLM) agents are increasingly proposed as simulated subjects for social-science research: cheaper, faster, and more controllable than human participants. We ask whether such agents can serve as a genuine *test bed* for an educational theory — Benjamin Bloom's "2-sigma problem," the claim that one-to-one mastery tutoring produces learning gains roughly two standard deviations above conventional group instruction. Over seven design generations (v3–v9c2) we operationalize "learning" as the formation of condition-specific compact memory from an education-phase transcript, evaluated on a synthetic rule domain (*Zarn Tokens*) under a strict memory-only protocol that prevents the model from answering from prior knowledge.

We report two contributions. First, a **negative result for LLM agents**: across every generation, group instruction met or exceeded one-to-one tutoring, and in our most rigorous experiment (v9c2; 154 learners, 2.4M tokens) the spread across pedagogical conditions collapsed to 10 percentage points while *learner-type* differences spanned 38 points. Bloom's social-interaction advantage did not robustly reproduce in this agent environment; what looked like a large discussion effect in an earlier generation (v9c, 37-point spread) is, we argue, largely attributable to an uncontrolled prerequisite-knowledge confound (we are candid in §8–§9 that this attribution rests on a single before/after comparison, not an ablation). Second, and more durable, a **confound-aware methodology**: an independent audit of our own pipeline surfaced five families of confound (F1–F5, two of which decompose into sub-confounds, for seven specific threats in total) — static corrective feedback, an exact-match scoring artifact, missing context injection into discussion agents, pseudoreplication, and single-instance role agents plus learning-budget asymmetry — that silently inflated effect sizes in agent-based theory testing. We give a remediation recipe (A0/A3/A4/A5/A6/A8), including a *population-multiplication* design for true replication and a *readiness gate* that controls prerequisite knowledge before the manipulated phase. We argue these confounds are not specific to our study but are structural risks for the broader program of using LLM agents to test social-scientific claims, and that negative results obtained under such controls are themselves informative.

---

## 1. Introduction

A growing literature treats LLMs as *silicon subjects* — generative agents that can stand in for human participants in economics games, opinion surveys, social simulations, and pedagogy. The appeal is obvious: an agent population can be instantiated in minutes, perfectly logged, and re-run under counterfactual manipulations that would be unethical or impossible with people. If LLM agents reproduce known human findings, they promise a fast loop for theory exploration; if they diverge, the divergence itself may be diagnostic.

This promise rests on an assumption that is rarely stress-tested: that an agent experiment, once built, actually measures the construct it claims to measure. Our paper is a sustained attempt to falsify that assumption on a single, well-specified theory.

We chose Bloom's **2-sigma problem** (Bloom, 1984) as the target. Bloom reported that students tutored one-to-one under mastery-learning conditions performed about two standard deviations above students in conventional 30-to-1 classrooms — a gap large enough that the bottom of the tutored distribution roughly matched the top of the conventional one. The finding has shaped decades of educational technology research and is frequently invoked today to motivate AI tutors. It is also a *structural* claim — about class size, individualization, and active engagement — which makes it a natural candidate for agent-based operationalization: the structural variables (who talks to whom, how large the group, how much each learner participates) are exactly the variables an agent harness can manipulate cleanly.

Our central question is therefore two-layered:

1. **Substantive:** When the structural conditions of Bloom's theory are operationalized as LLM-agent education sessions, do tutoring/small-group conditions produce measurably better downstream problem-solving than large-group or lecture conditions?
2. **Methodological:** Can we trust the answer? What does it take to make an agent-based theory test internally valid?

We answer the first question in the negative and treat the second as our main contribution. Over seven design generations we repeatedly found that group instruction matched or beat one-to-one tutoring — the opposite of Bloom's prediction — and that the apparent effect sizes were extremely sensitive to methodological choices that have nothing to do with pedagogy. An independent audit of our own code uncovered five confound families that had inflated earlier results. After remediating them, the most rigorous experiment showed pedagogical condition to be a minor factor (10-point spread) dwarfed by the *cognitive profile* of the learner agent (38-point spread).

We make the following contributions:

- **A reusable paradigm** for agent-based theory testing in which learning is operationalized as memory formation under a memory-only evaluation protocol on a synthetic domain immune to prior knowledge (§4).
- **A seven-generation case study** documenting how design decisions changed conclusions, with all run identifiers, sample sizes, and token costs reported for reproducibility (§5).
- **A confound taxonomy (F1–F5) and remediation recipe (A-codes)** for agent experiments, including the *population-multiplication* design that converts pseudoreplicated single discussions into genuinely replicated ones, and a *readiness gate* that controls prerequisite knowledge (§6).
- **A confound-controlled negative result** on Bloom's 2-sigma problem in this environment, plus the finding that learner-profile heterogeneity dominates pedagogical condition (§7–§8).

We are explicit about scope (§9): we do not claim LLM agents are human learners, that Zarn Tokens resemble any real curriculum, or that Bloom's theory is false for humans. We claim something narrower and, we think, more useful: that the *naive* agent-based test of this theory yields a strong but spurious effect, and that obtaining a trustworthy null requires controls that the agent-simulation literature does not yet treat as standard.

---

## 2. Related Work

**LLMs as simulated human subjects.** Recent work uses LLMs to emulate survey respondents, economic-game players, and populations of social agents, and to build "generative agent" societies whose emergent behavior is studied as data. A parallel strand cautions that such simulations can exhibit *caricatured* or distributionally narrow behavior, that prompt and sampling choices drive results, and that apparent realism can mask the absence of the underlying mechanism. Our work contributes a concrete, auditable instance of the latter caution: an agent experiment that produced a large, theory-consistent-looking effect which dissolved under replication and confound control.

**Bloom's 2-sigma problem and its modern reception.** Bloom's original claim motivated the "search for group methods as effective as one-to-one tutoring" and is routinely cited in intelligent-tutoring-systems and AI-in-education work. Subsequent human research has complicated the 2-sigma figure (effect sizes for tutoring are typically smaller, and mastery learning, feedback, and time-on-task each contribute). We do not adjudicate the human literature; we use the theory's *structural* form as a target that agent harnesses can manipulate.

**Internal validity in computational experiments.** Pseudoreplication — treating non-independent measurements as independent replicates — is a classic threat in ecology and the behavioral sciences and, we argue, a pervasive and under-recognized threat in agent simulations, where it is tempting to generate one interaction transcript and let many "learner" reads of it act as a sample. Likewise, single-instance "role" agents (one teacher, one judge) confound the manipulated variable with the idiosyncrasies of a particular generated persona. Our F1–F5 taxonomy collects these and other threats into a checklist tailored to LLM-agent pedagogy experiments.

**Evaluation artifacts in LLM scoring.** Exact-match grading of free-text model output is known to undercount semantically correct answers. We document a concrete case (our "L6" inductive task scoring 0% for three generations) in which an exact-match scorer, not the agents, produced a null, and we discuss when a semantic judge is required.

---

## 3. Bloom's Theory, Operationalized

Bloom's argument has three structural levers that an agent experiment can manipulate independently:

1. **Group size** — one tutor's attention divided among 1, 2, …, N learners.
2. **Individualization** — whether instruction adapts to the specific learner's errors (diagnose → correct → retest) or is delivered uniformly.
3. **Active engagement / ownership** — whether a learner is "called on," contributes, and receives feedback, versus passively receiving a lecture.

Bloom predicts that small group size, high individualization, and high engagement jointly produce the 2-sigma gain. Our generations probe these levers in different combinations: early generations (v4–v6) contrast a 1:N classroom against 1-on-1 tutoring (levers 1+2); the mechanism tests (v7) isolate engagement vs. individualization; the later generations (v8–v9c2) hold a common lecture fixed and vary group size and ownership in the *post-lecture* phase (levers 1+3), which most directly matches a "flipped classroom" reading of mastery learning.

A crucial operational decision is what counts as "learning." We do **not** fine-tune weights. We operationalize learning as the creation, during an education phase, of a compact **memory** object that the agent must rely on at evaluation time — the rules are withheld from the evaluation prompt (§4.2). Condition differences thus manifest as differences in the *content and structure of memory* that each pedagogical format induces, and in downstream task accuracy that depends on that memory. This is a deliberately modest construal of learning, but it is the one an agent harness can measure without confounding "learning" with "rule reading."

---

## 4. The Zarn Token Paradigm

### 4.1 A synthetic domain immune to prior knowledge

To prevent the model from solving tasks from pre-training, we invented a closed scoring system, **Zarn Tokens**, with no presence in any training corpus. A sequence of colored tokens is scored by four interacting rules plus a stacking rule:

| Token | Base value | Rule |
|-------|-----------|------|
| Red | 3 (but see below) | **Modifier only.** Red's own contribution is always 0; it doubles the base value of the token immediately to its right. |
| Blue | 5 | **Conditional.** Active (5) only if at least one Green appears *anywhere* to its left; otherwise 0. |
| Green | 2 | **Positional.** Active (2) in any position *except* last; inactive (0) if it is the final token. |
| Yellow | 7 | **Always active** (7), regardless of position or neighbors. |

**Stacking rule:** doubling an *inactive* token still yields 0 (e.g., `[Red, Blue]` with no Green scores 0, not 10). The intended evaluation procedure is *activation-check first, then modifier application* — a procedural-ordering requirement that becomes a probe for one of our learner types (§4.3).

The domain is small enough to teach in one lecture yet rich enough to support a difficulty ladder: conditional activation (Blue), positional inactivation (Green-at-end), modifier composition (Red doubling), and the interaction of all three (doubled-inactive). Worked example: `[Green, Red, Yellow, Blue]` → Green active (2); Red modifies Yellow; Yellow doubled (14); Blue active because Green is to its left (5) → **21**.

### 4.2 Memory-only evaluation protocol

Each evaluation task carries two fields: a `learner_prompt` with the rules **removed**, and `hidden_rules` used **only** by the auto-scorer. The learner must answer from memory formed during the education phase, with an explicit instruction *"Use only your memory of the rules. Do not assume rules you were not taught."* This split is the methodological heart of the paradigm: in pilot generations (v1–v2) where rules appeared in the evaluation prompt, every condition scored 100% (a complete ceiling), masking all pedagogical effects. Removing the rules dropped the no-education baseline to 0% and opened measurable variance.

### 4.3 Learner types as post-generation memory constraints

The memory object is a structured artifact the model produces from the education transcript. It has seven fields:

```json
{
  "rules": [], "examples": [], "edge_cases": [], "strategy": [],
  "corrected_misconceptions": [], "remaining_misconceptions": [], "uncertain_rules": []
}
```

At evaluation time this object — not the transcript — is what the learner reasons from. "Learning differences" between conditions are therefore differences in the content of these fields.

A recurring early failure (v5) was that *prompt-level* learner personas ("low-ability," "forgets edge cases") barely changed behavior, because the underlying model capability is fixed. From v6 onward we instead impose **hard constraints on the memory object after the model generates it**, yielding theory-driven learner types:

| Type | Memory budget | Edge-case retention | Rule-order retention | Asks questions |
|------|--------------|--------------------|--------------------|----------------|
| rule_extractor | 150 words | 90% | 90% | 30% |
| edge_case_dropper | 120 words | 10% | 70% | 20% |
| order_confused | 100 words | 60% | 20% | 40% |
| passive_listener | 80 words | 20% | 40% | 0% |

(Three further types — help_seeker, answer_first, example_memorizer — were defined in v6 and used in early generations.) Constraints are applied mechanically: each edge-case memory item is dropped independently with probability `1 − retention`; with probability `1 − rule_order_retention` the ordered rule list is shuffled (degrading procedural knowledge); memory is then trimmed to the word budget by dropping lowest-priority fields first; and a `passive_listener` with question probability 0 never speaks in discussion (its turn is skipped with no model call). These constraints make learner heterogeneity *real* at the representation level rather than role-played.

### 4.4 Phase structure

The mature protocol (v8 onward) runs four phases:

1. **Lecture (Phase 1).** A common instructional artifact. Early generations let the model generate the lecture per run; from v9c we fix a single rich reference lecture (6,493 characters, five worked examples, an edge-case checklist, and a common-mistakes table) so that lecture quality is held constant across conditions.
2. **Readiness check (Phase 2).** A short diagnostic (3 items in v8; 4 types — recall, edge_case, rule_interaction, procedure_order — in v9c+) that auto-scores each learner and appends a corrective note to memory on wrong answers. From v9c we add a **readiness gate**: if the cohort does not reach an 80% pass rate, a `readiness_failed` flag is set, signaling that prerequisite knowledge was *not* established and that any downstream condition contrast is confounded.
3. **Condition-specific interaction (Phase 3).** The manipulated phase: lecture-only vs. discussion of various group sizes, or tutoring, depending on the generation.
4. **Evaluation (Phase 4).** Ten memory-only tasks spanning a Bloom-style ladder.

### 4.5 Tasks, scoring, and metrics

The evaluation ladder has ten tasks: `recall` (L1), `edge_case` ×2 (L2), `rule_interaction` (L3), `debugging` ×3 (L4/L4/L5), `short_rule_induction` (L6), `peer_error_detection`, and `explanation_choice`. Numeric and multiple-choice answers are graded by **exact match** against a hidden answer; this is reliable for the nine closed-form tasks but, as §6 details, fails badly for the free-text inductive task (L6), which we ultimately exclude from the main score and re-route to a semantic judge.

Beyond accuracy we log: an **ownership** score (contributions, share called-on, share receiving feedback), a **misconception-correction** rate (did the diagnosed misconception disappear from later memory?), a 10-item **memory-coverage** vector and its pre/post-discussion **delta**, **confidence calibration** (high-confidence-wrong rate), and full **token accounting** per phase. Token accounting matters because tutoring and large-discussion conditions are far more expensive than lecture-only, and a fair comparison must report cost as well as accuracy.

---

## 5. The Experimental Arc (v3–v9c)

We summarize seven production generations. All production runs use `claude-sonnet-4-6` for every agent role (one v9b smoke run used `claude-haiku-4-5`). The no-education baseline scored 0% wherever it was run, confirming that the memory-only design removes the prior-knowledge ceiling; we omit it from the tables below except where noted.

### 5.1 v4–v6: classroom vs. tutoring, and the homogenization effect

| Gen | run_id (prefix) | Conditions and main accuracy | Headline |
|-----|-----------------|------------------------------|----------|
| v4 | `19b39e20` | no-ed 0%, **classroom 47%**, tutoring 28% (n=3/4/4) | Bloom reversed: classroom > tutoring |
| v5 | `02070b48` | homogeneous-classroom 44%, heterogeneous-classroom 41%, **tutoring 38%** (n≈4 each) | Tutoring lowest; highest variance |
| v6 | `cd5d2f0e` | homogeneous-classroom **94%**, heterogeneous-classroom 59%, tutoring 59% (n=4 each) | Format effect ≈ 0 (hetero = 1on1); homogenization effect appears |

Three findings recur and survive into the later generations. (i) **Bloom's tutoring advantage never appears**: classroom matches or beats one-to-one in every generation. (ii) A **homogenization effect**: in v6, relative to a heterogeneous classroom, one-to-one tutoring raised the weakest learner type (passive_listener +25 points) and lowered the strongest (order_confused −25 points), compressing variance — tutoring made the group more uniform without raising the mean. (The variance-compression direction is consistent with v5, where tutoring also showed the highest per-learner spread; the ±25-point figure itself is a v6 n=4-per-type result and should be read as a hypothesis, not an estimate.) (iii) **Misconception correction is decoupled from score**: v6 tutoring corrected diagnosed misconceptions 75% of the time yet did not outscore the classroom, because correcting a *propositional* misconception ("Blue is always active") does nothing for a *procedural* deficit (shuffled rule order). This decoupling reappeared in v7b (generic tutoring: 100% correction, 47% accuracy) and v8. The v6 "homogeneous classroom 94%" is the one apparent win for group instruction, but it is a confounded one: that condition's teacher was told the whole class shared a single misconception and to target it — an efficiency artifact of asymmetric design, not a clean format comparison.

### 5.2 v7: mechanism tests

Two targeted experiments tried to explain the v6 cross-over.

- **v7a (passive_listener rescue; `dd2fd888`):** Does tutoring help the passive learner via *forced interaction* or via *personalization*? Conditions: public-Q&A lecture (88%), forced-check-in lecture (53%), one-to-one (50%). Forced-check-in ≈ one-to-one (3 points) suggested the benefit is contact, not personalization — but a lecture-length asymmetry (a stray "under 200 words" constraint shortened the check-in lecture to 1,022 vs. 3,599 characters) confounds the comparison, and the richest *passive* lecture scored highest.
- **v7b (order_confused intervention; `32ffaa49`):** Does procedure-scaffolded tutoring beat generic tutoring for the procedurally confused learner? Conditions: public-Q&A (69%), generic tutoring (47%), procedure-scaffolded tutoring (41%). Scaffolding did not help and slightly hurt; generic tutoring reached 100% misconception correction yet 47% accuracy — again, correction decoupled from outcome. A bimodal `order_confused` distribution (one learner at 0/8) made n=4 means unstable.

The v7 mechanism tests thus reinforced the negative result but also exposed how fragile n=4 condition means are and how easily an incidental prompt difference (lecture length) masquerades as a pedagogical effect — foreshadowing the formal confound audit.

### 5.3 v8–v9c: flipped learning, class size, and the readiness problem

From v8 we adopt the flipped design: a *common* lecture for all conditions, then a manipulated post-lecture phase.

| Gen | run_id (prefix) | n | Main accuracy by condition | Headline |
|-----|-----------------|---|----------------------------|----------|
| v8 | `ef107ef9` | 16 | whole-class-discussion **83%**, one-to-one 78%, lecture-only 70%, small-group 68% | Discussion ≥ lecture; but lecture length still varied by condition |
| v9b | `772d2ce7` | 34 | lecture-only **60%** = pair **60%**, small 48%, large 47%, medium 45% | Class size **not** monotone; ownership–score correlation ≈ 0 |
| v9c | `b412cfdb` | 34 | pair **65%**, small 57%, large 52%, medium 40%, lecture-only **28%** | 37-point spread; "discussion adds value" — *but readiness failed (69%)* |

v9b introduced the **population-multiplication** design (instantiating 2/4/8/16-learner classes) and an explicit ownership metric, and found neither a monotone class-size effect nor an ownership–outcome correlation: lecture-only tied the smallest discussion for the top score, and memory "delta" from discussion was ~0 (agents acquired essentially no new rule knowledge from discussing). v9c fixed the lecture and added a four-type readiness check — and produced the most Bloom-friendly numbers in the entire program: a 37-point spread with every discussion condition beating lecture-only (28%). It would have been tempting to stop here and report a discussion advantage.

We did not, because the readiness gate had **failed**: the cohort reached only 69% on the readiness check (recall 68%, rule_interaction 50%), below the 80% target. The condition contrast was therefore measured over learners who had *not* reliably acquired the prerequisites — exactly the regime in which downstream differences reflect noise in prerequisite acquisition rather than the manipulated phase. The lecture-only condition, moreover, had *zero* learning sessions in Phase 3 while discussion conditions had one, a raw learning-budget asymmetry. Notably, the *learner-type* spread in v9c was only 8 points (rule_extractor 52% vs. passive_listener 44%) — far below the 37-point *condition* spread, the inverse of the controlled v9c2 ordering (§7) — which is itself a signature that the v9c condition differences were not stable learner-driven effects. The striking v9c effect was a prime suspect for confounding, which motivated a formal audit.

---

## 6. Confound Taxonomy and Remediation

We commissioned an independent audit of our own pipeline (a fresh analysis pass over code and per-run databases, using two scripts — `check_replication.py` and `check_confounds.py` — that we release). It produced a cross-version audit table and five confound families (F1–F5; F5 decomposes into F5a/b/c). We present them as a reusable checklist for agent-based experiments, with the remediation codes (A-codes) we implemented. The A-codes are the project's internal change-IDs from the v9c2 implementation plan, not a re-derived sequence; they are therefore non-contiguous (A0, A3, A4, A5, A6, A8) and do **not** align numerically with the F-codes. Appendix B gives the explicit confound→remediation map; we retain the original IDs so the paper matches the released code rather than renaming for cosmetic alignment.

**F1 — Static corrective feedback.** Wrong readiness-check answers append a *fixed, pre-written* corrective note to memory, identical regardless of which misconception caused the error. This does not bias the pass/fail score (scoring precedes the note) but undermines any claim that "adaptive feedback" drove learning. *Status:* acknowledged design limitation; not fully remediated (LLM-generated per-error notes are the proper fix and remain future work).

**F2 — Exact-match scoring artifact → A8.** The free-text inductive task (L6, *short_rule_induction*) scored 0% in v8, v9b, and v9c. Re-scoring with curated aliases recovered almost nothing and did not generalize, but inspection confirmed the agents were producing *semantically correct* rule statements that the exact-match scorer rejected. This is an evaluation artifact, not an agent failure. *Remediation A8:* exclude L6 from the main score and route it to an LLM semantic judge (`SEMANTIC_TASK_TYPES`), implemented for subsequent runs. (The nine closed-form tasks are unaffected and remain exact-match.)

**F3 — Discussion context not injected → A0.** In the discussion phase, *participant* agents received neither the lecture text nor their own prior memory in their prompt — only the moderator did. Transcripts confirmed called-on learners literally opening with "I don't actually know the rules." Between-condition differences therefore partly measured *how an agent improvises from an empty context*, not collaborative knowledge construction. *Remediation A0:* inject each learner's memory into the contribution and reply prompts so that participants reason from what they know.

**F4 — Pseudoreplication → A3.** This is the most consequential confound. In v4–v9c, each discussion/classroom condition generated **one** transcript (`unique_discussions = 1`); the multiple "learners" in a condition were all readers of that single conversation. The per-condition standard deviation therefore reflected learner-response variance to one N=1 event, *not* uncertainty about the pedagogical design — yet it is exactly the quantity one would (wrongly) use to claim "condition A > condition B." *Remediation A3:* a **population-multiplication** design that generates `n_disc` (=5) *independent* discussions per condition, each with freshly sampled learners, and aggregates at the discussion level. This converts pseudoreplicates into genuine replicates and is, we believe, the single most important control for agent-based social experiments.

**F5a — Learner-profile homogeneity → A4 (already satisfied).** Whether the learner population is diverse. v7a/v7b deliberately used a single type (a scoped choice, not a confound); v8/v9b/v9c already used four balanced types. *Status:* satisfied from v8 on; an erroneous audit note claiming "all learners were one type" was traced to a smoke-config database and corrected.

**F5b — Single-instance role agents → A5.** One `classroom_teacher`, one tutor, one evaluator instance served every condition in all of v4–v9c. The manipulated variable is thus confounded with the idiosyncrasies of a single generated persona/judge. *Remediation A5:* instantiate a fresh teacher agent for each of the `n_disc` independent discussions (five distinct teachers). We deliberately did **not** triplicate the evaluator: because the nine retained tasks are exact-match graded, the scoring path never reaches an LLM judge, so evaluator multiplication would be a no-op for them (it becomes relevant only once the L6 semantic judge is in use).

**F5c — Learning-budget asymmetry → A6.** Lecture-only learners had zero Phase-3 sessions while discussion learners had one, so "lecture-only vs. discussion" confounded *format* with *amount of post-lecture learning opportunity*. *Remediation A6:* a **self-reflection phase** giving lecture-only learners a structured individual-reflection session — an *additional learning opportunity* matched in kind (though, as we report candidly, not in token volume; see §7 and §9).

The cross-version audit table (released as an artifact) records, for every generation v4–v9c, the run-id↔database mapping, the `sessions` vs. `unique_discussions` count per condition (F4), and the single-instance/diversity status (F5). Its summary matrix shows F4 present (✓) in every generation except v8 (partial) and F5b present in all — i.e., the two structural confounds were *baked in from the first experiment* and silently shaped six generations of results before the audit caught them. This is the cautionary core of the paper: the confounds were invisible at the level of "the code runs and produces plausible numbers," and only a replication-and-independence audit surfaced them.

---

## 7. v9c2: The Confound-Controlled Experiment

v9c2 applies A0/A3/A4/A5/A6/A8 together and re-asks the v9c questions under control. (run_id `dc1bdd27`; `claude-sonnet-4-6`; 154 learners; 2,376,593 tokens.)

**Design.** Five conditions: `lecture_plus_self_reflection` (n=4; the renamed, A6-corrected lecture-only) and four discussion sizes — pair (2), small (4), medium (8), large (16) — each realized via population-multiplication with `n_disc = 5` independent discussions and a fresh teacher per discussion. Four balanced learner types. Common fixed lecture; four-type readiness check with the 80% gate.

**The readiness gate passed.** The cohort reached **90%** readiness (edge_case 100%, recall 91%, procedure_order 85%, rule_interaction 85%) — the first generation to clear the gate, so the condition contrast is, for the first time, measured over learners who genuinely held the prerequisites.

**Main result — the effect collapses.**

| Condition | Accuracy | Edu tokens | Correct per 1k edu tokens |
|-----------|---------|-----------|---------------------------|
| lecture_plus_self_reflection | 83% | 2,716 | 11.05 |
| pair_discussion_size_2 | 80% | 45,775 | 1.57 |
| small_class_discussion_size_4 | 76% | 42,590 | 3.19 |
| medium_class_discussion_size_8 | 86% | 41,580 | 7.46 |
| large_class_discussion_size_16 | 81% | 35,035 | 16.67 |

The spread across pedagogical conditions is **10 percentage points** (medium 86% vs. small 76%), down from v9c's 37 — and the ordering is non-monotone in both class size and ownership. The interpretation flags computed by the harness are: `class_size_effect_supported = false`, `ownership_effect_supported = false`, `discussion_added_value = false`. We stress that these flags are *threshold* tests (an effect must exceed a fixed margin over the lecture baseline), not significance tests; the honest reading is "no *large* effect," not "exactly zero." Indeed the numerically top condition is a discussion condition (medium, 86%), one point above lecture-plus-self-reflection (83%) — so we do not claim discussion *hurts*, only that no condition clears a meaningful margin and the v9c "discussion advantage" (every discussion condition far above a 28% lecture baseline) did **not** survive readiness control and replication.

**Learner type dominates.** The spread across learner *types* is **38 points** (edge_case_dropper 96% vs. passive_listener 58%) — nearly four times the condition spread. On the same n that makes us cautious about the condition contrast, this larger and directionally stable gap (the passive_listener, the most memory-constrained type, is lowest in v6, v9b, v9c, and v9c2) is the more defensible comparative claim: the single largest determinant of downstream accuracy is the cognitive profile (the memory constraint), not the pedagogical format. The v9c learner-type spread had been only 8 points; with the larger, readiness-controlled sample the profile differences resolve far more clearly. We still report this as a spread, not a tested effect (§9).

**Token efficiency reframes "what won."** Because A6 matched lecture-only's learning opportunity in *kind* but not in *volume*, lecture_plus_self_reflection spent ~2.7k education tokens against 35–46k for discussion conditions. Per-1k-token learning efficiency therefore ranks lecture-only (11.05) and large-class (16.67) far above pair/small discussion (1.57/3.19). Two caveats apply. Large-class scores highest on this metric only because one teacher's tokens are amortized over 16 learners — this is an instructional-cost-per-head statement, not a learning-quality one, and should not be read as endorsing large classes. And the same metric exposes the principal remaining confound in v9c2 (§9): A6 achieved "equal learning opportunity" structurally (a reflection session) but not in compute (~1/15th the tokens), so lecture-only's 83% is either impressively cheap or unfairly under-resourced depending on which budget one holds fixed. The robust statement is the weaker one: across a 1–2 order-of-magnitude range of token spend, downstream accuracy moved by at most 10 points.

---

## 8. Cross-Cutting Findings

1. **The education effect is real; the social-interaction effect is not.** No-education baselines sat at 0% throughout, so the pipeline does measure learning. But across seven generations the *Bloom-specific* prediction — tutoring/small-group > large-group/lecture — never robustly reproduced; the strongest pro-Bloom signal (v9c) was an artifact of an uncontrolled readiness confound.

2. **The headline numbers are best explained by confounds, not pedagogy — though the comparison is not a clean ablation.** The v9c→v9c2 contrast moved the condition spread from 37 to 10 points and flipped three interpretation flags. We are deliberately careful about the inference: v9c2 changed six remediations *at once* and raised n from 34 to 154, so we cannot attribute the collapse to any single control. The two mechanisms are also partly entangled by design — A3 (replication) inherently increases n, and a 37-point spread built on `unique_discussions = 1` per condition (F4) was, by definition, learner-response variance to a single discussion rather than a stable effect. So "we removed confounds and the effect collapsed" and "we added replication and N=1 noise averaged out" are, here, two descriptions of the *same* remediation rather than rival explanations. What we can claim firmly is the conditional: a spread that does not survive replication and prerequisite control was not safe to report as a pedagogical effect. What we cannot claim is a variable-isolated causal decomposition; a single-control ablation is the obvious next experiment (§9).

3. **Learner heterogeneity is the dominant variable.** When prerequisites are controlled, *who the learner is* (its memory constraints) explains far more variance (38 points) than *how it was taught* (10 points). This is itself a substantive result: in this environment, instructional format is a second-order factor behind learner representation.

4. **Two robust micro-mechanisms.** (i) *Homogenization*: one-to-one tutoring compresses the outcome distribution (raising the weakest type, lowering the strongest) without raising the mean. (ii) *Correction-outcome decoupling*: high misconception-correction rates do not translate into higher accuracy, because correcting a stated misconception leaves procedural deficits (and unrelated task demands) untouched. Both held across multiple generations and are candidate hypotheses for human study, stated here as agent-environment findings only.

5. **Cost asymmetry is large and usually ignored.** Tutoring and large discussions cost 4–24× the tokens of lecture/self-reflection for equal-or-worse accuracy. Any agent-based pedagogy claim should report cost-normalized outcomes; otherwise the "expensive condition" can look better simply because it did more.

---

## 9. Limitations and Scope

We constrain our claims tightly.

- **Agents are not students.** We measure memory formation and rule application by a single LLM under imposed memory constraints, not human cognition. Nothing here bears directly on whether Bloom's 2-sigma effect holds for people.
- **One domain, one model family.** All results are on Zarn Tokens with `claude-sonnet-4-6`. The synthetic domain was chosen for prior-knowledge immunity, not ecological validity; generalization across domains and model families is untested.
- **Residual token asymmetry (the live confound).** A6 equalized the *kind* of learning opportunity for lecture-only but not its token volume (~2.7k vs. ~35–46k). A cleaner future design would equalize compute budget across conditions or report a budget-matched arm.
- **No single-variable ablation.** The pivotal v9c→v9c2 comparison bundles six remediations and a 4.5× sample-size increase. We can show the inflated effect did not survive control, but not which control was responsible. The natural confirmatory design is a factorial or one-at-a-time ablation (e.g., v9c with *only* the readiness gate fixed, or *only* replication added), which we did not run.
- **Statistical power.** Even with `n_disc = 5`, five independent discussions per condition do not support strong inferential tests; the 10-point condition spread is best read as "no large effect," not "exactly zero." The same caution applies in principle to the 38-point learner-type spread — we lean on it more heavily only because it is larger and directionally consistent across four generations, not because it is statistically established. We report descriptive statistics and interpretation flags, not p-values, and recommend `n_disc = 10–15` for a confirmatory run.
- **F1 unresolved.** Corrective feedback remains static; adaptive per-error feedback is unimplemented.
- **Construct of "learning."** Memory-only evaluation is a deliberate, narrow operationalization; richer constructs (transfer, retention over sessions) are out of scope.

We view the open items as a strength of the artifact: each is logged, located in code, and prioritized for the next generation, which is the posture we advocate for agent-based theory testing generally.

---

## 10. Conclusion

We set out to test whether LLM agents can serve as a test bed for Bloom's 2-sigma problem, and answered on two levels. Substantively, in this environment the theory's social-interaction advantage does not reproduce: under confound control, pedagogical format is a minor factor (10-point spread) dominated by learner cognitive profile (38-point spread), and the social conditions are far more expensive for no accuracy gain. Methodologically — and this is the contribution we expect to outlast the specific result — we showed that the *naive* version of the same experiment produced a large, theory-flattering effect (a 37-point spread, "discussion adds value") that **did not survive** replication and prerequisite control. We are careful not to over-attribute: because the controls were applied together, we demonstrate that the effect was unsafe to report, not which confound created it. We distilled the threats into a five-family confound taxonomy (F1–F5) and a remediation recipe (A-codes), centered on a population-multiplication design for genuine replication and a readiness gate for prerequisite control.

The broader lesson for the "LLM-as-simulated-subject" program is sobering and, we hope, constructive: an agent experiment can run cleanly, produce plausible numbers, and still be measuring the wrong thing. Negative results obtained *after* explicit internal-validity controls are more informative than positive results obtained before them. We release all code, configurations, per-run databases, and version-by-version analyses so that the confound checklist — and the cautionary tale — can be reused.

---

## Appendix A. Run Index

| Gen | Experiment name | run_id | Model | n | Notes |
|-----|----------------|--------|-------|---|-------|
| v4 | bloom_1n_vs_1on1_v4 | 19b39e20-6901-4c90-8f3c-e24b352f23ae | sonnet-4-6 | 11 | shared experiment.db |
| v5 | bloom_heterogeneity_v5 | 02070b48-308f-4bf3-bac9-2cc76563ade9 | sonnet-4-6 | 15 | shared experiment.db |
| v6 | bloom_learner_types_v6 | cd5d2f0e-8036-41d6-b755-b6c6ba08ab3e | sonnet-4-6 | 15 | shared experiment.db |
| v7a | (passive_listener rescue) | dd2fd888-0e7b-40a9-ad2a-abb6e9b8b6d1 | sonnet-4-6 | 12 | |
| v7b | (order_confused intervention) | 32ffaa49-2d26-4edd-9cf8-ecdf1d019c78 | sonnet-4-6 | 12 | |
| v8 | (flipped learning) | ef107ef9-bee8-420e-a94f-31aee4a56c37 | sonnet-4-6 | 16 | |
| v9b | bloom_v9b (smoke) | 9b599c12-ab43-42f8-8af4-de26551b3981 | haiku-4-5 | 14 | smoke |
| v9b | bloom_v9b (prod) | 772d2ce7-246a-467e-89ae-b63d02d39c85 | sonnet-4-6 | 34 | 619,507 tokens |
| v9c | bloom_v9c_classroom_size | b412cfdb-0522-4997-a47e-1738eb414f4b | sonnet-4-6 | 34 | readiness_failed (69%); 631,955 tokens |
| v9c2 | bloom_v9c2_classroom_size | dc1bdd27-6ae0-46be-be74-fc8a974bb328 | sonnet-4-6 | 154 | readiness 90%; 2,376,593 tokens |

## Appendix B. Confound → Remediation Map

| Confound | Description | Affected generations | Remediation |
|----------|-------------|---------------------|-------------|
| F1 | Static corrective feedback | v8–v9c2 | (open) |
| F2 | Exact-match scoring artifact (L6) | v8, v9b, v9c | A8: exclude L6 + semantic judge |
| F3 | Discussion context not injected | v8 (partial), v9b, v9c | A0: inject learner memory |
| F4 | Pseudoreplication (unique_discussions = 1) | v4–v9c (v8 partial) | A3: population-multiplication, n_disc = 5 |
| F5a | Learner-profile homogeneity | v4, v7a, v7b (scoped) | A4: 4 balanced types (satisfied v8+) |
| F5b | Single-instance role agents | v4–v9c | A5: per-discussion teacher instances |
| F5c | Learning-budget asymmetry (lecture-only) | v9b, v9c | A6: self-reflection phase |

## Appendix C. Reproducibility

Each generation has a version-pinned config (`experiments/bloom_1n_vs_1on1/config/config_v*.yml`) and run script (`scripts/run_experiment_v*.rb`). Reports regenerate from a frozen run database via `scripts/regen_report.rb`. Audit scripts `check_replication.py` (counts `unique_discussions` per condition) and `check_confounds.py` (single-instance and profile-diversity checks) reproduce the cross-version audit table. The Zarn Token reference lecture, evaluation tasks, and rubric are included under `domains/zarn_tokens/`.

---

*Acknowledgement of method:* This paper's negative result was only trustworthy because we audited our own instrument before believing it. We recommend the same discipline — replication counting, single-instance checks, prerequisite gating, and cost normalization — as a default for agent-based theory testing.
