# v9c Readiness-Controlled Classroom-Size / Ownership Experiment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Re-run the v9b classroom-size / ownership experiment with (1) a fixed rich lecture instead of LLM-generated lecture, (2) a 4-type readiness check gate before discussion, and (3) extended 10-item memory diagnostics — ensuring learners are discussion-ready before Phase 3.

**Architecture:** Fixed lecture artifact (no LLM) → Memory fork → 4-type readiness check with corrective notes → snapshot pre-discussion memory → condition-specific discussion → evaluation → report with readiness summary + fine-grained memory delta + interpretation flags. All other infrastructure (SizedDiscussion, MasteryCheck, Solver, Evaluator, report.rb scaffolding, DB schema) is inherited from v9b.

**Tech Stack:** Ruby, SQLite3, Minitest, `claude --print` CLI, YAML config, existing `lib/phases/*`, `lib/report.rb`, `lib/db.rb`

---

## File Map

| File | Action | Responsibility |
|------|--------|----------------|
| `experiments/bloom_1n_vs_1on1/domains/zarn_tokens/fixed_lecture_v9c.md` | Create | Hardcoded comprehensive lecture artifact (no LLM) |
| `experiments/bloom_1n_vs_1on1/domains/zarn_tokens/readiness_check_tasks_v9c.json` | Create | 4-type readiness check tasks (recall, edge_case, rule_interaction, procedure_order) |
| `experiments/bloom_1n_vs_1on1/lib/memory_diagnostics.rb` | Modify | Extend from 6 to 10 knowledge items (backward compatible) |
| `experiments/bloom_1n_vs_1on1/scripts/run_experiment_v9c.rb` | Create | Orchestrator: load fixed lecture, readiness gate, fork memory, discussion, report |
| `experiments/bloom_1n_vs_1on1/lib/report.rb` | Modify | Add v9c: readiness_summary_section, fine_grained_memory_delta_section, interpretation_flags_section |
| `config_v9c_smoke.yml` | Create | Smoke test config (haiku, small n) |
| `config_v9c.yml` | Create | Full run config (sonnet, production n) |
| `experiments/bloom_1n_vs_1on1/tests/test_memory_diagnostics_v9c.rb` | Create | Tests for 4 new MemoryDiagnostics items |
| `experiments/bloom_1n_vs_1on1/tests/test_report_v9c.rb` | Create | Tests for readiness_summary, fine_grained_memory_delta, interpretation_flags sections |
| `experiments/bloom_1n_vs_1on1/tests/run_tests.sh` | Modify | Add 2 new test files |

---

## Task 1: Fixed Rich Lecture Artifact

**Files:**
- Create: `experiments/bloom_1n_vs_1on1/domains/zarn_tokens/fixed_lecture_v9c.md`

This is a hardcoded comprehensive lecture (no LLM generation). It must explicitly include all canonical rules, edge cases, worked examples (≥ 4), rule interaction examples, procedure order, common mistakes, and a debugging example. Target: ≥ 80% readiness pass rate after corrective notes.

- [ ] **Step 1: Write the fixed lecture file**

```markdown
# Zarn Token System — Complete Reference Lecture (v9c Fixed)

This lecture is a fixed reference artifact used in v9c experiments.

## Token Base Values

| Token  | Base Value | Notes                         |
|--------|------------|-------------------------------|
| Red    | 3          | Acts as modifier; own score = 0 |
| Blue   | 5          | Conditional activation         |
| Green  | 2          | Inactive at last position      |
| Yellow | 7          | Always active                  |

---

## Rule 1: Red — Pure Modifier (own score = 0)

Red is a modifier-only token. It always contributes 0 to the final score.
Its only effect: double the base value of the token immediately to its right.

**Red itself never scores. Red doubles the next token's base value, but Red = 0.**

Example: [Red, Yellow]
- Red: modifier → 0 pts
- Yellow: always active, base 7, doubled by Red → 14
- Score: 14

Common mistake: Adding Red's base value (3) to the score. Red always contributes 0.

---

## Rule 2: Blue — Conditional Activation

Blue is active (contributes 5) only if there is at least one Green token ANYWHERE to its left in the sequence. "Anywhere to its left" means any earlier position, not just immediately before.

If no Green exists to Blue's left, Blue is inactive → contributes 0.

Example: [Green, Yellow, Blue]
- Green: not last → active (2)
- Yellow: always active (7)
- Blue: Green is to its left → ACTIVE (5)
- Score: 2 + 7 + 5 = 14

Counter-example: [Blue, Green, Yellow]
- Blue: no Green to its left → INACTIVE (0)
- Green: not last → active (2)
- Yellow: always active (7)
- Score: 0 + 2 + 7 = 9

---

## Rule 3: Green — End-Position Rule

Green is active (contributes 2) in any position EXCEPT the last.
If Green is the last token in the sequence, it is inactive (contributes 0).

Example: [Green, Yellow]
- Green at pos 1: NOT last → active (2)
- Yellow at pos 2: active (7)
- Score: 9

Example: [Yellow, Green]
- Yellow at pos 1: active (7)
- Green at pos 2: LAST → INACTIVE (0)
- Score: 7

---

## Rule 4: Yellow — Always Active

Yellow is always active regardless of position. It always contributes 7.
Yellow is never affected by Green, Blue, or positional rules.

---

## Rule 5: Stacking — Doubled Inactive Token

If Red doubles a token that is inactive, the result is still 0.
Doubling 0 = 0. An inactive token contributes nothing, even when multiplied.

Critical example: [Red, Blue] (no Green anywhere)
- Red: modifier → 0
- Blue: no Green to its left → INACTIVE (0). Red doubles inactive Blue: 0 × 2 = 0.
- Score: 0

Common mistake: counting Red × Blue as 5 × 2 = 10 without first checking Blue's activation.

---

## Evaluation Procedure (Correct Order)

Evaluate each sequence left to right:

1. For each token, identify its type.
2. **Check activation status BEFORE applying modifiers:**
   - Red: always modifier, never active (contributes 0).
   - Blue: active only if Green appears anywhere to its left.
   - Green: active if not the last token; inactive if last.
   - Yellow: always active.
3. Note whether the previous token is Red (= this token gets doubled).
4. **If the token is ACTIVE**, apply any Red doubling.
5. **If the token is INACTIVE**, its contribution is 0 — even if doubled by Red.
6. Sum all active token values.

**Procedure order: Activation check → then Modifier application.**
Never apply Red's doubling first and then check activation.

---

## Worked Examples

### Example 1: [Green, Blue, Yellow] → 14
- Green at pos 1: not last → active (2)
- Blue at pos 2: Green is to its left → active (5)
- Yellow at pos 3: always active (7)
- Score: 2 + 5 + 7 = **14**

### Example 2: [Blue, Green] → 0
- Blue at pos 1: no Green to its left → inactive (0)
- Green at pos 2: last position → inactive (0)
- Score: 0 + 0 = **0**

### Example 3: [Green, Red, Yellow, Blue] → 21
- Green at pos 1: not last → active (2)
- Red at pos 2: modifier → 0. Doubles pos 3 (Yellow).
- Yellow at pos 3: always active, base 7, doubled by Red → 14
- Blue at pos 4: Green is to its left (pos 1) → active (5)
- Score: 2 + 0 + 14 + 5 = **21**

### Example 4: [Red, Green, Blue, Yellow] → 16
- Red at pos 1: modifier → 0. Doubles pos 2 (Green).
- Green at pos 2: not last → active, base 2, doubled by Red → 4
- Blue at pos 3: Green is to its left (pos 2) → active (5)
- Yellow at pos 4: always active (7)
- Score: 0 + 4 + 5 + 7 = **16**

### Example 5: [Red, Blue, Green] → 0 (Debugging Example)
This sequence demonstrates why activation must be checked BEFORE applying Red:

Step-by-step diagnostic:
1. Red at pos 1: modifier → 0. Next token is Blue at pos 2.
2. Blue at pos 2: **First, check activation** — any Green to its left? No (Red is not Green). Blue is INACTIVE (0). Red doubles inactive Blue: 0 × 2 = 0.
3. Green at pos 3: last position → INACTIVE (0)
4. Score: 0 + 0 + 0 = **0**

Learner mistake: assuming Blue is "partially" active because Red precedes it. Red never activates Blue. Only Green activates Blue.

---

## Edge Case Checklist

Before finalizing your answer, verify:

1. **Green-at-end**: Is the last token Green? → Green is inactive (0).
2. **Blue-without-Green**: Is there a Green anywhere to Blue's left? If no → Blue is inactive (0).
3. **Doubled-inactive**: Did Red precede an inactive token? → Result is still 0.
4. **Red-own-score**: Did you accidentally count Red's base value (3)? → Red always contributes 0.

---

## Common Mistakes Reference

| Mistake | Why It's Wrong | Correct Rule |
|---------|----------------|--------------|
| Counting Red's base (3) in the score | Red is modifier-only | Red always contributes 0 |
| Assuming Blue is always active | Blue needs Green anywhere to its left | If no Green to left → Blue = 0 |
| Counting Green when it is last | Green is inactive at last position | Green = 0 if last |
| Applying Red doubling before checking activation | Doubling an inactive token is still 0 | Always check activation first |
| Thinking Blue needs Green immediately before | Any Green to left activates Blue, not just adjacent | |

---

## Debugging Strategy

When you get an unexpected result:
1. Work left to right, writing each token's status:
   `[token_type] → [activation: active/inactive] → [modifier applied: yes/no] → [effective value]`
2. Identify Red modifiers and which token each Red doubles.
3. Re-check Blue: is there ANY Green before it?
4. Re-check Green: is it the last token?
5. Re-check any Red-doubled token: was it active when doubled?
6. Sum only the effective values of active tokens.
```

- [ ] **Step 2: Verify the file was written and has expected content**

```bash
wc -c experiments/bloom_1n_vs_1on1/domains/zarn_tokens/fixed_lecture_v9c.md
grep -c "Example" experiments/bloom_1n_vs_1on1/domains/zarn_tokens/fixed_lecture_v9c.md
```

Expected: file exists, ≥ 3000 chars, ≥ 5 occurrences of "Example"

- [ ] **Step 3: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/domains/zarn_tokens/fixed_lecture_v9c.md
git commit -m "feat(v9c): add fixed rich lecture artifact for readiness-controlled experiment"
```

---

## Task 2: Readiness Check Tasks (4 types)

**Files:**
- Create: `experiments/bloom_1n_vs_1on1/domains/zarn_tokens/readiness_check_tasks_v9c.json`

This extends v9b's 3-type mastery check (recall, edge_case, rule_interaction) with a 4th type: procedure_order. The procedure_order task specifically tests whether learners check activation BEFORE applying Red's modifier.

- [ ] **Step 1: Write the readiness check tasks file**

```json
[
  {
    "id": "rc_recall_01",
    "check_type": "recall",
    "learner_prompt": "Calculate the final score for this Zarn token sequence: [Yellow, Green]\n\nUse only your memory of the rules. Do not assume rules you were not taught.\n\nRespond in JSON only:\n{\"answer\": \"<score>\", \"active_tokens\": [\"list active token names\"], \"mistakes_found\": [], \"reason\": \"<under 40 words>\"}",
    "expected_answer": "7",
    "expected_active_tokens": ["Yellow"],
    "expected_mistakes": [],
    "acceptable_aliases": {"7": ["7 points", "score: 7", "total: 7", "score is 7"]},
    "corrective_note": "Recall: [Yellow, Green]. Yellow is always active (7 pts). Green is the last token so it is inactive (0 pts). Score = 7."
  },
  {
    "id": "rc_edge_case_01",
    "check_type": "edge_case",
    "learner_prompt": "Calculate the final score for this Zarn token sequence: [Red, Blue]\n\nUse only your memory of the rules. Do not assume rules you were not taught.\n\nRespond in JSON only:\n{\"answer\": \"<score>\", \"active_tokens\": [\"list active token names\"], \"mistakes_found\": [], \"reason\": \"<under 40 words>\"}",
    "expected_answer": "0",
    "expected_active_tokens": [],
    "expected_mistakes": [],
    "acceptable_aliases": {"0": ["0 points", "score: 0", "total: 0", "score is 0"]},
    "corrective_note": "Edge case: [Red, Blue]. Blue has no Green to its left, so Blue is inactive (0). Red doubles inactive Blue: doubled(0) = 0. Score = 0."
  },
  {
    "id": "rc_rule_interaction_01",
    "check_type": "rule_interaction",
    "learner_prompt": "Calculate the final score for this Zarn token sequence: [Green, Red, Yellow]\n\nUse only your memory of the rules. Do not assume rules you were not taught.\n\nRespond in JSON only:\n{\"answer\": \"<score>\", \"active_tokens\": [\"list active token names\"], \"mistakes_found\": [], \"reason\": \"<under 40 words>\"}",
    "expected_answer": "16",
    "expected_active_tokens": ["Green", "Yellow"],
    "expected_mistakes": [],
    "acceptable_aliases": {"16": ["16 points", "score: 16", "total: 16", "score is 16"]},
    "corrective_note": "Rule interaction: [Green, Red, Yellow]. Green = not last, active (2). Red doubles Yellow. Yellow always active: 7 × 2 = 14. Score = 2 + 14 = 16."
  },
  {
    "id": "rc_procedure_order_01",
    "check_type": "procedure_order",
    "learner_prompt": "Calculate the final score for this Zarn token sequence: [Red, Blue, Green, Yellow]\n\nIMPORTANT: Show your evaluation procedure step by step.\n\nUse only your memory of the rules. Do not assume rules you were not taught.\n\nRespond in JSON only:\n{\"answer\": \"<score>\", \"active_tokens\": [\"list active token names\"], \"mistakes_found\": [], \"reason\": \"<under 60 words>\"}",
    "expected_answer": "9",
    "expected_active_tokens": ["Green", "Yellow"],
    "expected_mistakes": [],
    "acceptable_aliases": {"9": ["9 points", "score: 9", "total: 9", "score is 9"]},
    "corrective_note": "Procedure order: [Red, Blue, Green, Yellow]. First check Blue's activation: no Green to its left, so Blue is INACTIVE (0). Then apply Red: doubles inactive Blue = 0. Green (pos 3) not last = active (2). Yellow always active (7). Score = 0 + 0 + 2 + 7 = 9. Always check activation BEFORE applying modifiers."
  }
]
```

- [ ] **Step 2: Verify the JSON is valid and has 4 tasks**

```bash
ruby -e "require 'json'; tasks = JSON.parse(File.read('experiments/bloom_1n_vs_1on1/domains/zarn_tokens/readiness_check_tasks_v9c.json')); puts tasks.size; puts tasks.map { |t| t['check_type'] }.inspect"
```

Expected output:
```
4
["recall", "edge_case", "rule_interaction", "procedure_order"]
```

- [ ] **Step 3: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/domains/zarn_tokens/readiness_check_tasks_v9c.json
git commit -m "feat(v9c): add 4-type readiness check tasks including procedure_order"
```

---

## Task 3: Extend MemoryDiagnostics to 10 Items

**Files:**
- Modify: `experiments/bloom_1n_vs_1on1/lib/memory_diagnostics.rb`
- Create: `experiments/bloom_1n_vs_1on1/tests/test_memory_diagnostics_v9c.rb`

Add 4 new knowledge items: `inactive_token_modifier_rule`, `edge_case_checklist`, `debugging_strategy`, `common_mistake_notes`. Must remain backward compatible — existing 6 items and delta/coverage_count methods are unchanged.

- [ ] **Step 1: Write the failing tests**

```ruby
# experiments/bloom_1n_vs_1on1/tests/test_memory_diagnostics_v9c.rb
# ABOUTME: Tests the 4 new MemoryDiagnostics items added for v9c (10-item schema)
# ABOUTME: Verifies detection and coverage_count for inactive_token, edge_case_checklist, debugging, mistakes

$LOAD_PATH.unshift File.join(__dir__, '..', 'lib')
require 'minitest/autorun'
require 'memory_diagnostics'

class TestMemoryDiagnosticsV9c < Minitest::Test
  def empty_memory
    {
      'rules'                    => [],
      'examples'                 => [],
      'edge_cases'               => [],
      'strategy'                 => [],
      'corrected_misconceptions' => [],
      'remaining_misconceptions' => [],
      'uncertain_rules'          => []
    }
  end

  def test_detect_inactive_token_modifier_rule_present
    mem = empty_memory.merge('edge_cases' => ['doubled inactive token is still 0'])
    assert MemoryDiagnostics.detect(mem)[:inactive_token_modifier_rule]
  end

  def test_detect_inactive_token_modifier_rule_absent
    mem = empty_memory.merge('rules' => ['Red doubles the next token'])
    refute MemoryDiagnostics.detect(mem)[:inactive_token_modifier_rule]
  end

  def test_detect_inactive_token_modifier_rule_variant_wording
    mem = empty_memory.merge('edge_cases' => ['if Blue is inactive, Red doubled(0) = 0'])
    assert MemoryDiagnostics.detect(mem)[:inactive_token_modifier_rule]
  end

  def test_detect_edge_case_checklist_present
    mem = empty_memory.merge('strategy' => ['check Green end, check Blue left, checklist complete'])
    assert MemoryDiagnostics.detect(mem)[:edge_case_checklist]
  end

  def test_detect_edge_case_checklist_absent
    mem = empty_memory.merge('rules' => ['Blue needs Green to its left'])
    refute MemoryDiagnostics.detect(mem)[:edge_case_checklist]
  end

  def test_detect_debugging_strategy_present
    mem = empty_memory.merge('strategy' => ['work left to right, token by token through the sequence'])
    assert MemoryDiagnostics.detect(mem)[:debugging_strategy]
  end

  def test_detect_debugging_strategy_variant_wording
    mem = empty_memory.merge('strategy' => ['debug by checking each position systematically'])
    assert MemoryDiagnostics.detect(mem)[:debugging_strategy]
  end

  def test_detect_debugging_strategy_absent
    mem = empty_memory.merge('strategy' => ['sum all active tokens at the end'])
    refute MemoryDiagnostics.detect(mem)[:debugging_strategy]
  end

  def test_detect_common_mistake_notes_present
    mem = empty_memory.merge('corrected_misconceptions' => ['common mistake: counting Red base value (3)'])
    assert MemoryDiagnostics.detect(mem)[:common_mistake_notes]
  end

  def test_detect_common_mistake_notes_variant
    mem = empty_memory.merge('corrected_misconceptions' => ['avoid assuming Blue is always active'])
    assert MemoryDiagnostics.detect(mem)[:common_mistake_notes]
  end

  def test_detect_common_mistake_notes_absent
    mem = empty_memory.merge('rules' => ['Blue is active only with Green to its left'])
    refute MemoryDiagnostics.detect(mem)[:common_mistake_notes]
  end

  def test_coverage_count_includes_all_10_items
    mem = empty_memory.merge(
      'rules'   => [
        'Blue is active if there is a Green to its left',
        'Red is a modifier: doubles the next token. Red itself scores 0.',
        'Yellow is always active and scores 7 in any position',
        'doubled inactive token is still 0'
      ],
      'edge_cases' => [
        'Green is inactive when it is the last token',
        'checklist: check Green end, check Blue left, check doubled inactive'
      ],
      'strategy' => [
        'Check activation status before applying the modifier doubling',
        'Sum all active token values for the final score',
        'work left to right, token by token to debug'
      ],
      'corrected_misconceptions' => [
        'common mistake: counting Red base value instead of 0'
      ]
    )
    assert_equal 10, MemoryDiagnostics.coverage_count(mem)
  end

  def test_existing_6_items_still_detected
    mem = empty_memory.merge(
      'rules'    => ['Blue is active if there is a Green to its left',
                     'Red is a modifier: doubles next token, Red scores 0',
                     'Yellow is always active and scores 7'],
      'edge_cases' => ['Green is inactive when it is the last token'],
      'strategy' => ['Check activation status before applying modifier doubling',
                     'Sum all active token values for the final score']
    )
    diag = MemoryDiagnostics.detect(mem)
    assert diag[:blue_activation]
    assert diag[:red_modifier]
    assert diag[:yellow_always_active]
    assert diag[:green_end_position]
    assert diag[:activation_before_modification]
    assert diag[:final_summing]
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd /Users/masumi/tmp/Agent-Based-Theory-Testing-2-Sigma-Problem
eval "$(mise activate zsh)" 2>/dev/null || true
bundle exec ruby experiments/bloom_1n_vs_1on1/tests/test_memory_diagnostics_v9c.rb 2>&1 | tail -5
```

Expected: FAIL with "undefined method" or "assert failed" — the 4 new items don't exist yet.

- [ ] **Step 3: Add 4 new items to MemoryDiagnostics**

In `experiments/bloom_1n_vs_1on1/lib/memory_diagnostics.rb`, replace the `ITEMS` constant:

```ruby
  ITEMS = {
    blue_activation:               /blue.*green.*left|green.*left.*blue|blue.*active.*if.*green|need.*green.*before.*blue/i,
    green_end_position:            /green.*last|green.*end.*inactive|last.*green.*inactive|green.*inactive.*last/i,
    red_modifier:                  /red.*double|red.*modifier|red.*pure.*modifier|red.*scores.*0|red.*itself.*0/i,
    yellow_always_active:          /yellow.*always|yellow.*7.*any|yellow.*active.*any.*position|always.*active.*yellow/i,
    activation_before_modification: /activation.*before.*modifier|activation.*first.*modifier|check.*active.*before.*double|activation.*status.*before/i,
    final_summing:                 /sum.*active|add.*active|total.*active|sum.*all.*active/i,
    inactive_token_modifier_rule:  /doubled.*inactive|inactive.*doubled|doubled.*zero|0.*doubled|inactive.*still.*0/i,
    edge_case_checklist:           /checklist|check.*green.*end|check.*blue.*left|green.*end.*check|blue.*activation.*check/i,
    debugging_strategy:            /left.*to.*right|token.*by.*token|position.*by.*position|debug.*each|systematic.*token/i,
    common_mistake_notes:          /common.*mistake|avoid.*assuming|avoid.*red|never.*count.*red|mistake.*counting/i
  }.freeze
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
bundle exec ruby experiments/bloom_1n_vs_1on1/tests/test_memory_diagnostics_v9c.rb 2>&1 | tail -3
```

Expected: `10 runs, 0 failures, 0 errors`

- [ ] **Step 5: Verify existing diagnostics tests still pass**

```bash
bundle exec ruby experiments/bloom_1n_vs_1on1/tests/test_memory_diagnostics.rb 2>&1 | tail -3
```

Expected: `9 runs, 0 failures, 0 errors` (coverage_count test may show 6 not 10 — that's correct for the existing test which only puts 6 items)

Note: The existing `test_coverage_count_full_memory` test checks for 6 items with the original data set — it will still pass because the 4 new items are not present in that test's memory fixture.

- [ ] **Step 6: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/lib/memory_diagnostics.rb \
        experiments/bloom_1n_vs_1on1/tests/test_memory_diagnostics_v9c.rb
git commit -m "feat(v9c): extend MemoryDiagnostics from 6 to 10 items for fine-grained diagnostics"
```

---

## Task 4: v9c Report Sections

**Files:**
- Modify: `experiments/bloom_1n_vs_1on1/lib/report.rb`
- Create: `experiments/bloom_1n_vs_1on1/tests/test_report_v9c.rb`

Add three new report sections for v9c: `readiness_summary_section`, `fine_grained_memory_delta_section`, and `interpretation_flags_section`. Also extend the `build_markdown` guard to handle `experiment == 'v9c'` using the same task-type/difficulty helpers as v9b.

- [ ] **Step 1: Write failing tests**

```ruby
# experiments/bloom_1n_vs_1on1/tests/test_report_v9c.rb
# ABOUTME: Tests for v9c-specific report sections: readiness summary, fine-grained delta, flags
# ABOUTME: All helpers are pure functions using pre-built fixture data — no LLM calls

$LOAD_PATH.unshift File.join(__dir__, '..', 'lib')
require 'minitest/autorun'
require 'report'
require 'memory_diagnostics'

class TestReadinessSummarySection < Minitest::Test
  def mastery_rows_all_pass
    [
      { 'check_type' => 'recall',           'answer_correct' => 1, 'condition' => 'lecture_only' },
      { 'check_type' => 'edge_case',        'answer_correct' => 1, 'condition' => 'lecture_only' },
      { 'check_type' => 'rule_interaction', 'answer_correct' => 1, 'condition' => 'lecture_only' },
      { 'check_type' => 'procedure_order',  'answer_correct' => 1, 'condition' => 'lecture_only' }
    ]
  end

  def mastery_rows_partial
    [
      { 'check_type' => 'recall',           'answer_correct' => 1, 'condition' => 'pair_discussion_size_2' },
      { 'check_type' => 'edge_case',        'answer_correct' => 1, 'condition' => 'pair_discussion_size_2' },
      { 'check_type' => 'rule_interaction', 'answer_correct' => 0, 'condition' => 'pair_discussion_size_2' },
      { 'check_type' => 'procedure_order',  'answer_correct' => 0, 'condition' => 'pair_discussion_size_2' }
    ]
  end

  def test_readiness_summary_shows_procedure_order_check_type
    section = Report.send(:readiness_summary_section, mastery_rows_all_pass, 1.0)
    assert_includes section, 'procedure_order'
  end

  def test_readiness_summary_shows_pass_rate
    section = Report.send(:readiness_summary_section, mastery_rows_all_pass, 1.0)
    assert_includes section, '100%'
  end

  def test_readiness_summary_flags_failure_when_below_80
    section = Report.send(:readiness_summary_section, mastery_rows_partial, 0.50)
    assert_includes section, 'READINESS TARGET NOT MET'
  end

  def test_readiness_summary_confirms_target_when_met
    section = Report.send(:readiness_summary_section, mastery_rows_all_pass, 1.0)
    assert_includes section, 'Readiness target met'
  end
end

class TestFineGrainedMemoryDeltaSection < Minitest::Test
  def pre_snapshots
    [
      {
        'learner_id' => 'l-001',
        'condition'  => 'pair_discussion_size_2',
        'diag'       => { blue_activation: true, green_end_position: false,
                          red_modifier: true, yellow_always_active: true,
                          activation_before_modification: false, final_summing: true,
                          inactive_token_modifier_rule: false, edge_case_checklist: false,
                          debugging_strategy: false, common_mistake_notes: false }
      }
    ]
  end

  def memories_by_condition
    {
      'pair_discussion_size_2' => [
        {
          'learner_id' => 'l-001',
          'memory'     => {
            'rules'       => ['Blue is active if there is a Green to its left',
                              'Red is a modifier: doubles next token, Red scores 0',
                              'Yellow is always active and scores 7',
                              'doubled inactive token is still 0'],
            'edge_cases'  => ['Green is inactive when it is the last token',
                              'checklist: check Green end, check Blue left'],
            'strategy'    => ['Check activation status before applying modifier doubling',
                              'Sum all active token values for the final score',
                              'work left to right, token by token to debug'],
            'corrected_misconceptions' => ['common mistake: counting Red base value'],
            'examples'                 => [],
            'remaining_misconceptions' => [],
            'uncertain_rules'          => []
          },
          'type_key' => 'rule_extractor'
        }
      ]
    }
  end

  def test_section_contains_condition_name
    section = Report.send(:fine_grained_memory_delta_section, pre_snapshots, memories_by_condition)
    assert_includes section, 'pair_discussion_size_2'
  end

  def test_section_contains_delta_header
    section = Report.send(:fine_grained_memory_delta_section, pre_snapshots, memories_by_condition)
    assert_includes section, 'Memory Delta'
  end

  def test_section_shows_acquired_items
    section = Report.send(:fine_grained_memory_delta_section, pre_snapshots, memories_by_condition)
    # Pre-diag has 4 true items; post-diag (full fixture) has 10 true items → ~6 acquired
    assert_includes section, 'Acquired'
  end
end

class TestInterpretationFlagsSection < Minitest::Test
  def rows_lecture_only_dominates
    conds = %w[lecture_only pair_discussion_size_2 large_class_discussion_size_16]
    conds.flat_map do |cond|
      score = cond == 'lecture_only' ? 1 : 0
      3.times.map do
        { 'condition' => cond, 'learner_id' => "l-#{rand}",
          'score_json' => JSON.dump('answer_correct' => score == 1),
          'profile_json' => nil }
      end
    end
  end

  def ownership_rows_lecture_only
    [
      { 'condition' => 'lecture_only', 'ownership_score' => 0,
        'contribution_count' => 0, 'attempted_answer' => 0, 'received_feedback' => 0,
        'memory_delta_after_discussion' => 0 },
      { 'condition' => 'pair_discussion_size_2', 'ownership_score' => 3,
        'contribution_count' => 2, 'attempted_answer' => 1, 'received_feedback' => 1,
        'memory_delta_after_discussion' => 0 }
    ]
  end

  def test_flags_section_shows_readiness_failed_true_when_below_target
    section = Report.send(:interpretation_flags_section,
                          rows_lecture_only_dominates, [], ownership_rows_lecture_only, 0.50)
    assert_includes section, 'readiness_failed'
    assert_includes section, 'true'
  end

  def test_flags_section_shows_lecture_only_dominant_true
    section = Report.send(:interpretation_flags_section,
                          rows_lecture_only_dominates, [], ownership_rows_lecture_only, 0.90)
    assert_includes section, 'lecture_only_dominant'
    assert_includes section, 'true'
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
bundle exec ruby experiments/bloom_1n_vs_1on1/tests/test_report_v9c.rb 2>&1 | tail -5
```

Expected: FAIL — `readiness_summary_section`, `fine_grained_memory_delta_section`, `interpretation_flags_section` not yet defined.

- [ ] **Step 3: Add v9c sections to report.rb**

In `experiments/bloom_1n_vs_1on1/lib/report.rb`, after the existing `build_markdown` method guard block for v9b (around line 199), add the v9c guard block:

```ruby
    # v9c: readiness + ownership + memory delta + interpretation flags
    if experiment_meta[:experiment] == 'v9c'
      lines << readiness_summary_section(mastery_rows, experiment_meta[:readiness_pass_rate] || 0.0)
      lines << mastery_check_section(mastery_rows)
      lines << memory_coverage_section(memories_by_condition)
      lines << ownership_section(experiment_meta[:ownership_rows] || [])
      lines << memory_delta_section(experiment_meta[:ownership_rows] || [])
      lines << fine_grained_memory_delta_section(
        experiment_meta[:pre_discussion_snapshots] || [],
        memories_by_condition
      )
      lines << interpretation_flags_section(
        rows, mastery_rows,
        experiment_meta[:ownership_rows] || [],
        experiment_meta[:readiness_pass_rate] || 0.0
      )
    end
```

Also update the `mastery_rows` assignment to include 'v9c':
```ruby
    mastery_rows = %w[v8 v9b v9c].include?(experiment_meta[:experiment]) ?
                    DB.all_mastery_checks_by_condition(db, run_id) : []
```

And update the score-by-task-type guard:
```ruby
    if %w[v9b v9c].include?(experiment_meta[:experiment])
      lines << score_by_task_type_v9b(rows, all_conds.sort)
      lines << score_by_difficulty_v9b(rows, all_conds.sort)
    else
```

Then add these three new private methods at the bottom of `report.rb` (before the last `end`):

```ruby
  def self.readiness_summary_section(mastery_rows, readiness_pass_rate)
    return '' if mastery_rows.nil? || mastery_rows.empty?
    target_met = readiness_pass_rate >= 0.80
    lines = []
    lines << "## Readiness Summary"
    lines << ""
    lines << "| Metric | Value |"
    lines << "|--------|-------|"
    lines << "| Overall readiness pass rate | #{(readiness_pass_rate * 100).round}% |"
    lines << "| Target (80%) | #{target_met ? '✓ Readiness target met' : '✗ READINESS TARGET NOT MET'} |"
    lines << ""
    lines << "### Pass Rate by Check Type"
    lines << ""
    lines << "| Check Type | Total | Correct | Pass Rate |"
    lines << "|------------|-------|---------|-----------|"
    mastery_rows.group_by { |r| r['check_type'] }.sort.each do |check_type, type_rows|
      total   = type_rows.size
      correct = type_rows.count { |r| r['answer_correct'].to_i == 1 }
      pct     = total > 0 ? (correct.to_f / total * 100).round : 0
      lines << "| #{check_type} | #{total} | #{correct} | #{pct}% |"
    end
    lines << ""
    unless target_met
      lines << "> **WARNING:** Readiness target not met. Do not make strong claims about"
      lines << "> ownership or class-size effects from this run."
      lines << ""
    end
    lines.join("\n")
  end

  def self.fine_grained_memory_delta_section(pre_snapshots, memories_by_condition)
    return '' if pre_snapshots.empty? || memories_by_condition.empty?
    pre_by_learner = pre_snapshots.each_with_object({}) { |s, h| h[s['learner_id']] = s['diag'] }
    items = MemoryDiagnostics::ITEMS.keys
    short = items.map { |k| k.to_s.split('_').first(2).join('_') }

    lines = []
    lines << "## Fine-Grained Memory Coverage Post-Discussion (10 items)"
    lines << ""
    lines << "| Condition | " + short.map { |s| "#{s} |" }.join(' ')
    lines << "|-----------|" + items.map { " :---: |" }.join
    memories_by_condition.sort_by { |k, _| k }.each do |cond, mem_list|
      next if mem_list.empty?
      post_diags = mem_list.map { |m| MemoryDiagnostics.detect(m['memory']) }
      cols = items.map do |item|
        pct = (post_diags.count { |d| d[item] }.to_f / post_diags.size * 100).round
        "#{pct}% |"
      end
      lines << "| #{cond} | #{cols.join(' ')}"
    end
    lines << ""

    lines << "## Fine-Grained Memory Delta (pre → post discussion)"
    lines << ""
    lines << "| Condition | Avg Acquired | Avg Lost | Avg Stable |"
    lines << "|-----------|:------------:|:--------:|:----------:|"
    memories_by_condition.sort_by { |k, _| k }.each do |cond, mem_list|
      next if mem_list.empty?
      deltas = mem_list.map do |m|
        pre_diag  = pre_by_learner[m['learner_id']] || {}
        post_diag = MemoryDiagnostics.detect(m['memory'])
        {
          acquired: items.count { |k| !pre_diag[k] && post_diag[k] },
          lost:     items.count { |k|  pre_diag[k] && !post_diag[k] },
          stable:   items.count { |k|  pre_diag[k] &&  post_diag[k] }
        }
      end
      avg_acq    = (deltas.sum { |d| d[:acquired] }.to_f / deltas.size).round(1)
      avg_lost   = (deltas.sum { |d| d[:lost]     }.to_f / deltas.size).round(1)
      avg_stable = (deltas.sum { |d| d[:stable]   }.to_f / deltas.size).round(1)
      lines << "| #{cond} | #{avg_acq} | #{avg_lost} | #{avg_stable} |"
    end
    lines << ""
    lines.join("\n")
  end

  def self.interpretation_flags_section(rows, mastery_rows, ownership_rows, readiness_pass_rate)
    by_condition  = rows.group_by { |r| r['condition'] }
    score_by_cond = by_condition.transform_values { |rs| avg_correctness(rs) }
    own_summary   = OwnershipMetrics.summary_by_condition(ownership_rows)

    readiness_failed = readiness_pass_rate < 0.80

    # Ownership × score Kendall-tau concordance
    pairs = own_summary.map { |cond, s| [s[:avg_ownership_score], score_by_cond[cond] || 0] }
    n_concordant = n_discordant = 0
    pairs.combination(2).each do |(o1, s1), (o2, s2)|
      diff = (o1 - o2) * (s1 - s2)
      n_concordant += 1 if diff > 0
      n_discordant += 1 if diff < 0
    end
    ownership_effect_supported = n_concordant > n_discordant

    # Class-size effect: do larger classes score lower?
    sizes = {
      'pair_discussion_size_2'        => 2,
      'small_class_discussion_size_4' => 4,
      'medium_class_discussion_size_8' => 8,
      'large_class_discussion_size_16' => 16
    }
    disc_scores = score_by_cond.select { |k, _| sizes.key?(k) }.sort_by { |k, _| sizes[k] }
    ordered_scores = disc_scores.map { |_, v| v }
    class_size_effect_supported = ordered_scores == ordered_scores.sort.reverse && ordered_scores.size >= 2

    # Lecture-only dominance
    lecture_score = score_by_cond['lecture_only'] || 0.0
    disc_cond_scores = score_by_cond.reject { |k, _| k == 'lecture_only' }
    lecture_only_dominant = disc_cond_scores.values.all? { |s| s <= lecture_score } && disc_cond_scores.any?

    # Discussion added value (any discussion > lecture_only + 5pp)
    discussion_added_value = disc_cond_scores.values.any? { |s| s > lecture_score + 0.05 }

    lines = []
    lines << "## Interpretation Flags"
    lines << ""
    lines << "| Flag | Value |"
    lines << "|------|-------|"
    lines << "| readiness_failed | #{readiness_failed} |"
    lines << "| ownership_effect_supported | #{ownership_effect_supported} |"
    lines << "| class_size_effect_supported | #{class_size_effect_supported} |"
    lines << "| lecture_only_dominant | #{lecture_only_dominant} |"
    lines << "| discussion_added_value | #{discussion_added_value} |"
    lines << ""
    lines << "## Interpretation"
    lines << ""
    if readiness_failed
      lines << "**WARNING: readiness_failed = true** — prerequisite readiness target (80%) not met."
      lines << "Ownership and class-size conclusions from this run are unreliable."
    else
      lines << "Readiness target met (#{(readiness_pass_rate * 100).round}%). Interpretations below are valid."
      lines << ""
      if ownership_effect_supported
        lines << "- **Ownership hypothesis supported**: higher ownership score conditions outperformed lower."
      else
        lines << "- **Ownership hypothesis NOT supported**: ownership score did not predict final score."
      end
      if class_size_effect_supported
        lines << "- **Class-size effect supported**: scores decreased as class size increased."
      else
        lines << "- **Class-size effect NOT supported**: no clear linear relationship between class size and score."
      end
      if lecture_only_dominant
        lines << "- **Lecture-only dominant**: lecture_only outperformed all discussion conditions."
        lines << "  Discussion may add little beyond prerequisite lecture + readiness correction."
      end
      if discussion_added_value
        lines << "- **Discussion added value**: at least one discussion condition outperformed lecture_only by > 5pp."
      end
    end
    lines << ""
    lines.join("\n")
  end
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
bundle exec ruby experiments/bloom_1n_vs_1on1/tests/test_report_v9c.rb 2>&1 | tail -5
```

Expected: `11 runs, 0 failures, 0 errors`

- [ ] **Step 5: Verify existing report tests still pass**

```bash
bundle exec ruby experiments/bloom_1n_vs_1on1/tests/test_report_v9b.rb 2>&1 | tail -3
bundle exec ruby experiments/bloom_1n_vs_1on1/tests/test_report_v5.rb   2>&1 | tail -3
```

Expected: 0 failures each.

- [ ] **Step 6: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/lib/report.rb \
        experiments/bloom_1n_vs_1on1/tests/test_report_v9c.rb
git commit -m "feat(v9c): add readiness_summary, fine_grained_memory_delta, interpretation_flags report sections"
```

---

## Task 5: v9c Orchestrator

**Files:**
- Create: `experiments/bloom_1n_vs_1on1/scripts/run_experiment_v9c.rb`

This orchestrator is a fork of `run_experiment_v9b.rb` with three key changes:
1. Phase 1 loads the fixed lecture from file instead of calling LLM.
2. Phase 2 uses `readiness_check_tasks_v9c.json` (4 types) and tracks `readiness_pass_rate`.
3. Phase 5 passes `readiness_pass_rate`, `readiness_failed`, and `pre_discussion_snapshots` to `Report.generate` via `experiment_meta`.

- [ ] **Step 1: Write the orchestrator**

```ruby
# experiments/bloom_1n_vs_1on1/scripts/run_experiment_v9c.rb
# ABOUTME: Orchestrator for v9c readiness-controlled classroom-size / ownership experiment
# ABOUTME: Fixed lecture → 4-type readiness gate → memory fork → sized discussion → evaluation → report

require 'yaml'
require 'json'
require 'fileutils'
require 'securerandom'

EXPERIMENT_DIR = File.expand_path('..', __dir__)
$LOAD_PATH.unshift File.join(EXPERIMENT_DIR, 'lib')

require 'db'
require 'llm'
require 'helpers'
require 'token_tracker'
require 'scorer'
require 'learner_types'
require 'memory_diagnostics'
require 'phases/mastery_check'
require 'phases/sized_discussion'
require 'phases/memory'
require 'phases/solver'
require 'phases/evaluator'
require 'report'

config_path  = ARGV[0] or abort "Usage: #{$0} <config.yml>"
PROJECT_ROOT = File.expand_path('../..', EXPERIMENT_DIR)
config       = YAML.load_file(File.join(PROJECT_ROOT, config_path))

run_id       = SecureRandom.uuid
run_name     = config.dig('experiment', 'name') || 'bloom_v9c'
domain_path  = File.join(PROJECT_ROOT, config.dig('paths', 'domain'))
prompts_path = File.join(PROJECT_ROOT, config.dig('paths', 'prompts'))
output_base  = File.join(PROJECT_ROOT, config.dig('paths', 'output'))
db_path      = File.join(PROJECT_ROOT, config.dig('paths', 'db'))
run_dir      = File.join(output_base, 'runs', run_id)

FileUtils.mkdir_p(run_dir)
$stderr.puts "[v9c] Starting run #{run_id}"

tracker = TokenTracker.new

fixed_lecture_file = config.dig('experiment', 'fixed_lecture_file') || 'fixed_lecture_v9c.md'
fixed_lecture_text = File.read(File.join(domain_path, fixed_lecture_file))

tasks_file       = config.dig('experiment', 'eval_tasks_file')       || 'eval_tasks_v8.json'
readiness_file   = config.dig('experiment', 'readiness_tasks_file')  || 'readiness_check_tasks_v9c.json'
eval_tasks       = JSON.parse(Helpers.load_file(File.join(domain_path, tasks_file)))
readiness_tasks  = JSON.parse(Helpers.load_file(File.join(domain_path, readiness_file)))
rubric           = JSON.parse(Helpers.load_file(File.join(domain_path, 'rubric.json')))

summarizer_prompt  = Helpers.load_file(File.join(prompts_path, 'memory_summarizer.md'))
moderator_prompt   = Helpers.load_file(File.join(prompts_path, 'discussion_moderator.md'))
participant_prompt = Helpers.load_file(File.join(prompts_path, 'discussion_participant.md'))
solver_prompt      = Helpers.load_file(File.join(prompts_path, 'problem_solver.md'))
evaluator_prompt   = Helpers.load_file(File.join(prompts_path, 'blind_evaluator.md'))

db = DB.setup(db_path)
DB.save_run(db, run_id, run_name, config)
File.write(File.join(run_dir, 'config.json'), JSON.pretty_generate(config))

type_keys       = (config.dig('experiment', 'learner_types') || []).map(&:to_sym)
type_keys       = LearnerTypes::HETEROGENEOUS_ASSIGNMENT if type_keys.empty?
class_sizes     = config.dig('experiment', 'class_sizes') || {}
lecture_only_n  = config.dig('experiment', 'lecture_only_n') || 4
called_on_cfg   = config.dig('experiment', 'called_on_counts') || {}

CONDITIONS = %w[
  lecture_only
  pair_discussion_size_2
  small_class_discussion_size_4
  medium_class_discussion_size_8
  large_class_discussion_size_16
].freeze

teacher_id   = DB.save_agent(db, run_id: run_id, role: 'classroom_teacher',
                              model: config.dig('models', 'teacher'))
evaluator_id = DB.save_agent(db, run_id: run_id, role: 'evaluator',
                              model: config.dig('models', 'evaluator'))

all_learners = CONDITIONS.flat_map do |condition|
  n = condition == 'lecture_only' ? lecture_only_n : (class_sizes[condition] || 4)
  n.times.map do |i|
    type_key   = type_keys[i % type_keys.size]
    learner_id = DB.save_agent(db, run_id: run_id, role: 'learner', condition: condition,
                               model: config.dig('models', 'learner'),
                               profile: { 'type_key' => type_key.to_s })
    { id: learner_id, condition: condition, type_key: type_key }
  end
end

by_condition = all_learners.group_by { |l| l[:condition] }
$stderr.puts "[v9c] Learner distribution: #{by_condition.transform_values(&:size)}"

# ---------------------------------------------------------------------------
# PHASE 1: Load fixed lecture — log coverage metrics
# ---------------------------------------------------------------------------
$stderr.puts "[v9c] Phase 1: Loading fixed lecture (#{fixed_lecture_text.length} chars)"

shared_transcript = {
  'condition'   => 'prerequisite_lecture',
  'teacher_id'  => teacher_id,
  'learner_ids' => all_learners.map { |l| l[:id] },
  'turns'       => [{ 'speaker' => 'teacher', 'type' => 'lecture', 'content' => fixed_lecture_text }],
  'lecture'     => fixed_lecture_text
}
File.write(File.join(run_dir, 'shared_lecture.json'), JSON.pretty_generate(shared_transcript))

lecture_stats = {
  chars:             fixed_lecture_text.length,
  est_tokens:        (fixed_lecture_text.length / 4.0).ceil,
  worked_examples:   fixed_lecture_text.scan(/###\s+Example\s+\d/i).size,
  debugging_example: fixed_lecture_text.include?('Debugging Example') ? 1 : 0
}
$stderr.puts "[v9c] Lecture stats: #{lecture_stats.inspect}"

# ---------------------------------------------------------------------------
# PHASE 1b: Memory fork — all learners generate memory from fixed lecture
# ---------------------------------------------------------------------------
$stderr.puts "[v9c] Phase 1b: Memory fork (#{all_learners.size} learners)"

all_learners.each do |learner|
  memory = Phases::Memory.generate(
    learner_id: learner[:id], transcript: shared_transcript,
    summarizer_prompt: summarizer_prompt, config: config, tracker: tracker,
    learner_type_key: learner[:type_key]
  )
  DB.save_learner_memory(db, run_id: run_id, learner_id: learner[:id],
                         condition: learner[:condition], memory: memory)
  File.open(File.join(run_dir, 'memories.jsonl'), 'a') do |f|
    f.puts JSON.dump({ phase: 'post_lecture', learner_id: learner[:id],
                       condition: learner[:condition], type_key: learner[:type_key].to_s,
                       diag: MemoryDiagnostics.detect(memory), memory: memory })
  end
end

# ---------------------------------------------------------------------------
# PHASE 2: Readiness check (4 types) — with corrective notes; compute pass rate
# ---------------------------------------------------------------------------
$stderr.puts "[v9c] Phase 2: Readiness checks (#{all_learners.size} × #{readiness_tasks.size})"

readiness_correct = 0
readiness_total   = 0
pre_discussion_snapshots = []

all_learners.each do |learner|
  memory = DB.get_learner_memory(db, run_id: run_id, learner_id: learner[:id])
  result = Phases::MasteryCheck.run(
    learner_id: learner[:id], memory: memory, check_tasks: readiness_tasks,
    solver_prompt: solver_prompt, config: config, db: db, run_id: run_id,
    tracker: tracker
  )
  readiness_correct += result[:checks].count { |c| c['answer_correct'] }
  readiness_total   += readiness_tasks.size

  DB.save_learner_memory(db, run_id: run_id, learner_id: learner[:id],
                         condition: learner[:condition], memory: result[:updated_memory])

  pre_diag = MemoryDiagnostics.detect(result[:updated_memory])
  pre_discussion_snapshots << {
    'learner_id' => learner[:id],
    'condition'  => learner[:condition],
    'memory'     => result[:updated_memory],
    'diag'       => pre_diag
  }

  File.open(File.join(run_dir, 'memories.jsonl'), 'a') do |f|
    f.puts JSON.dump({ phase: 'post_readiness', learner_id: learner[:id],
                       condition: learner[:condition], type_key: learner[:type_key].to_s,
                       checks: result[:checks], errors: result[:errors].size,
                       diag: pre_diag, memory: result[:updated_memory] })
  end
  $stderr.puts "[v9c] Readiness #{learner[:id]}: #{result[:errors].size}/#{readiness_tasks.size} errors"
end

readiness_pass_rate = readiness_total > 0 ? readiness_correct.to_f / readiness_total : 0.0
readiness_failed    = readiness_pass_rate < 0.80

$stderr.puts "[v9c] Readiness pass rate: #{(readiness_pass_rate * 100).round}% (target: 80%) — #{readiness_failed ? 'FAILED' : 'OK'}"

# ---------------------------------------------------------------------------
# PHASE 3: Condition-specific discussion + memory update
# ---------------------------------------------------------------------------
$stderr.puts "[v9c] Phase 3: Condition interactions"

all_ownership_data = {}

by_condition['lecture_only']&.each do |learner|
  all_ownership_data[learner[:id]] = {
    'contribution_count' => 0, 'attempted_answer' => false,
    'received_feedback' => false, 'misconception_exposed' => false,
    'misconception_corrected' => false, 'observed_peer_reasoning_count' => 0,
    'discussion_exposure_count' => 0, 'direct_participation_count' => 0,
    'moderator_feedback_count' => 0, 'ownership_score' => 0
  }
end
$stderr.puts "[v9c] Phase 3: lecture_only — no interaction"

DISCUSSION_CONDITIONS = %w[
  pair_discussion_size_2
  small_class_discussion_size_4
  medium_class_discussion_size_8
  large_class_discussion_size_16
].freeze

pre_snap_by_id = pre_discussion_snapshots.each_with_object({}) { |s, h| h[s['learner_id']] = s['memory'] }

DISCUSSION_CONDITIONS.each do |condition|
  learners = by_condition[condition]
  next unless learners&.any?

  ids             = learners.map { |l| l[:id] }
  type_map        = learners.each_with_object({}) { |l, h| h[l[:id]] = l[:type_key] }
  called_on_count = called_on_cfg[condition]&.to_i
  lesson          = fixed_lecture_text

  $stderr.puts "[v9c] Phase 3: #{condition} (#{ids.size} learners, #{called_on_count || 'all'} called on)"

  result = Phases::SizedDiscussion.run(
    condition: condition, learner_ids: ids,
    called_on_count: called_on_count,
    moderator_id: teacher_id, moderator_prompt: moderator_prompt,
    participant_prompt: participant_prompt, lesson: lesson,
    config: config, tracker: tracker, learner_type_keys: type_map
  )

  ids.each do |lid|
    DB.save_learning_session(db, run_id: run_id, condition: condition,
                             learner_id: lid, teacher_or_tutor_id: teacher_id,
                             transcript: result)
  end
  File.open(File.join(run_dir, 'transcripts.jsonl'), 'a') { |f| f.puts JSON.dump(result) }

  learners.each do |learner|
    existing = DB.get_learner_memory(db, run_id: run_id, learner_id: learner[:id])
    updated  = Phases::Memory.update(
      learner_id: learner[:id], existing_memory: existing,
      update_transcript: result['turns'],
      summarizer_prompt: summarizer_prompt, config: config, tracker: tracker,
      learner_type_key: learner[:type_key]
    )
    DB.save_learner_memory(db, run_id: run_id, learner_id: learner[:id],
                           condition: condition, memory: updated)

    pre_mem    = pre_snap_by_id[learner[:id]] || {}
    diag_delta = MemoryDiagnostics.delta(pre_mem, updated)

    File.open(File.join(run_dir, 'memories.jsonl'), 'a') do |f|
      f.puts JSON.dump({ phase: 'post_interaction', learner_id: learner[:id],
                         condition: condition, type_key: learner[:type_key].to_s,
                         diag_delta: diag_delta,
                         diag_post: MemoryDiagnostics.detect(updated),
                         memory: updated })
    end

    own_data = result['ownership_data'][learner[:id]] || {}
    all_ownership_data[learner[:id]] = own_data.merge(
      'memory_delta_after_discussion' => diag_delta[:acquired]
    )
  end
end

$stderr.puts "[v9c] Saving ownership metrics (#{all_ownership_data.size} learners)"
all_learners.each do |learner|
  own = all_ownership_data[learner[:id]] || {}
  DB.save_ownership_metrics(db,
    run_id: run_id, learner_id: learner[:id], condition: learner[:condition],
    contribution_count:             (own['contribution_count'] || 0).to_i,
    attempted_answer:               own['attempted_answer'],
    received_feedback:              own['received_feedback'],
    misconception_exposed:          own['misconception_exposed'],
    misconception_corrected:        own['misconception_corrected'],
    observed_peer_reasoning_count:  (own['observed_peer_reasoning_count'] || 0).to_i,
    memory_delta_after_discussion:  (own['memory_delta_after_discussion'] || 0).to_i,
    ownership_score:                (own['ownership_score'] || 0).to_i,
    discussion_exposure_count:      (own['discussion_exposure_count'] || 0).to_i,
    direct_participation_count:     (own['direct_participation_count'] || 0).to_i,
    moderator_feedback_count:       (own['moderator_feedback_count'] || 0).to_i
  )
end

# ---------------------------------------------------------------------------
# PHASE 4: Evaluation
# ---------------------------------------------------------------------------
$stderr.puts "[v9c] Phase 4: Evaluation (#{all_learners.size} × #{eval_tasks.size} tasks)"

eval_tasks.each do |task|
  DB.save_evaluation_task(db, run_id: run_id, task_id: task['id'],
                          task_type: task['task_type'], prompt: task['learner_prompt'],
                          expected_answer: task['expected_answer'], rubric: rubric)
end

all_learners.each do |learner|
  memory = DB.get_learner_memory(db, run_id: run_id, learner_id: learner[:id])
  eval_tasks.each do |task|
    result = Phases::Solver.solve(
      learner_id: learner[:id], memory: memory, task: task,
      solver_prompt: solver_prompt, config: config, tracker: tracker
    )
    attempt_id = DB.save_task_attempt(db, run_id: run_id,
                                      learner_id: learner[:id],
                                      condition: learner[:condition],
                                      task_id: task['id'],
                                      response_text: result['response'],
                                      trace: result['trace'].merge('parsed' => result['parsed']))
    score = Phases::Evaluator.score(
      attempt_id: attempt_id, learner_response: result['response'],
      parsed_response: result['parsed'], task: task, rubric: rubric,
      evaluator_id: evaluator_id, evaluator_prompt: evaluator_prompt,
      config: config, tracker: tracker
    )
    DB.save_evaluation(db, run_id: run_id, attempt_id: attempt_id,
                       evaluator_id: evaluator_id, score: score)
  end
  $stderr.puts "[v9c] Evaluated #{learner[:id]} (#{learner[:condition]})"
end

# ---------------------------------------------------------------------------
# PHASE 5: Report
# ---------------------------------------------------------------------------
$stderr.puts "[v9c] Phase 5: Generating report"

ownership_rows = DB.all_ownership_metrics_by_condition(db, run_id).values.flatten

Report.generate(db, run_id: run_id, output_dir: run_dir,
                run_config: config,
                token_summary: tracker.summary,
                experiment_meta: {
                  experiment: 'v9c',
                  ownership_rows: ownership_rows,
                  pre_discussion_snapshots: pre_discussion_snapshots,
                  readiness_pass_rate: readiness_pass_rate,
                  readiness_failed: readiness_failed
                })

$stderr.puts "[v9c] Run complete: #{run_dir}"
$stderr.puts "[v9c] Readiness pass rate: #{(readiness_pass_rate * 100).round}%"
$stderr.puts "[v9c] Total tokens: #{tracker.grand_total}"
```

- [ ] **Step 2: Verify the orchestrator has the correct require list and no syntax errors**

```bash
cd /Users/masumi/tmp/Agent-Based-Theory-Testing-2-Sigma-Problem
ruby -c experiments/bloom_1n_vs_1on1/scripts/run_experiment_v9c.rb
```

Expected: `Syntax OK`

- [ ] **Step 3: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/scripts/run_experiment_v9c.rb
git commit -m "feat(v9c): add orchestrator with fixed lecture, 4-type readiness gate, and extended diagnostics"
```

---

## Task 6: Config Files

**Files:**
- Create: `config_v9c_smoke.yml` (at project root, same location as `config_v9b_smoke.yml`)
- Create: `config_v9c.yml` (at project root)

- [ ] **Step 1: Write the smoke test config**

```yaml
# config_v9c_smoke.yml
experiment:
  name: "bloom_v9c_smoke"
  domain: "zarn_tokens"
  lecture_only_n: 2
  class_sizes:
    pair_discussion_size_2: 2
    small_class_discussion_size_4: 2
    medium_class_discussion_size_8: 4
    large_class_discussion_size_16: 4
  called_on_counts:
    medium_class_discussion_size_8: 2
    large_class_discussion_size_16: 2
  learner_types:
    - rule_extractor
    - passive_listener
  eval_tasks_file: "eval_tasks_v8.json"
  readiness_tasks_file: "readiness_check_tasks_v9c.json"
  fixed_lecture_file: "fixed_lecture_v9c.md"
  ceiling_threshold: 0.9

models:
  teacher: "claude-haiku-4-5-20251001"
  tutor: "claude-haiku-4-5-20251001"
  learner: "claude-haiku-4-5-20251001"
  memory_summarizer: "claude-haiku-4-5-20251001"
  problem_solver: "claude-haiku-4-5-20251001"
  evaluator: "claude-haiku-4-5-20251001"

paths:
  prompts: "experiments/bloom_1n_vs_1on1/prompts"
  domain: "experiments/bloom_1n_vs_1on1/domains/zarn_tokens"
  output: "experiments/bloom_1n_vs_1on1/data"
  db: "experiments/bloom_1n_vs_1on1/data/experiment_v9c_smoke.db"
```

- [ ] **Step 2: Write the full run config**

```yaml
# config_v9c.yml
experiment:
  name: "bloom_v9c_classroom_size"
  domain: "zarn_tokens"
  lecture_only_n: 4
  class_sizes:
    pair_discussion_size_2: 2
    small_class_discussion_size_4: 4
    medium_class_discussion_size_8: 8
    large_class_discussion_size_16: 16
  called_on_counts:
    medium_class_discussion_size_8: 4
    large_class_discussion_size_16: 3
  learner_types:
    - rule_extractor
    - edge_case_dropper
    - order_confused
    - passive_listener
  eval_tasks_file: "eval_tasks_v8.json"
  readiness_tasks_file: "readiness_check_tasks_v9c.json"
  fixed_lecture_file: "fixed_lecture_v9c.md"
  ceiling_threshold: 0.9

models:
  teacher: "claude-sonnet-4-6"
  tutor: "claude-sonnet-4-6"
  learner: "claude-sonnet-4-6"
  memory_summarizer: "claude-sonnet-4-6"
  problem_solver: "claude-sonnet-4-6"
  evaluator: "claude-sonnet-4-6"

paths:
  prompts: "experiments/bloom_1n_vs_1on1/prompts"
  domain: "experiments/bloom_1n_vs_1on1/domains/zarn_tokens"
  output: "experiments/bloom_1n_vs_1on1/data"
  db: "experiments/bloom_1n_vs_1on1/data/experiment_v9c.db"
```

- [ ] **Step 3: Verify configs are valid YAML**

```bash
ruby -e "require 'yaml'; puts YAML.load_file('config_v9c_smoke.yml').dig('experiment', 'readiness_tasks_file')"
ruby -e "require 'yaml'; puts YAML.load_file('config_v9c.yml').dig('models', 'teacher')"
```

Expected:
```
readiness_check_tasks_v9c.json
claude-sonnet-4-6
```

- [ ] **Step 4: Commit**

```bash
git add config_v9c_smoke.yml config_v9c.yml
git commit -m "feat(v9c): add smoke and full run config files"
```

---

## Task 7: Update Test Runner and Run Full Test Suite

**Files:**
- Modify: `experiments/bloom_1n_vs_1on1/tests/run_tests.sh`

- [ ] **Step 1: Add new test files to run_tests.sh**

In `experiments/bloom_1n_vs_1on1/tests/run_tests.sh`, add these two lines after the `test_report_v9b.rb` line:

```bash
bundle exec ruby "$EXPERIMENT_DIR/tests/test_memory_diagnostics_v9c.rb"
bundle exec ruby "$EXPERIMENT_DIR/tests/test_report_v9c.rb"
```

- [ ] **Step 2: Run the full test suite to verify no regressions**

```bash
cd /Users/masumi/tmp/Agent-Based-Theory-Testing-2-Sigma-Problem
eval "$(mise activate zsh)" 2>/dev/null || true
bash experiments/bloom_1n_vs_1on1/tests/run_tests.sh
```

Expected: `All tests passed.`

- [ ] **Step 3: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/tests/run_tests.sh
git commit -m "test(v9c): add v9c test files to test runner"
```

---

## Task 8: Smoke Test

Run the v9c orchestrator with the smoke config to verify the full pipeline works end-to-end.

- [ ] **Step 1: Run smoke test**

```bash
cd /Users/masumi/tmp/Agent-Based-Theory-Testing-2-Sigma-Problem
eval "$(mise activate zsh)" 2>/dev/null || true
bundle exec ruby experiments/bloom_1n_vs_1on1/scripts/run_experiment_v9c.rb config_v9c_smoke.yml 2>&1 | tee /tmp/v9c_smoke.log
```

- [ ] **Step 2: Verify all phases completed**

```bash
grep -E "\[v9c\] (Phase|Run complete|Readiness pass rate|Total tokens)" /tmp/v9c_smoke.log
```

Expected output should include all of:
```
[v9c] Phase 1: Loading fixed lecture
[v9c] Phase 1b: Memory fork
[v9c] Phase 2: Readiness checks
[v9c] Phase 3: Condition interactions
[v9c] Phase 3: lecture_only — no interaction
[v9c] Phase 3: pair_discussion_size_2
[v9c] Phase 3: small_class_discussion_size_4
[v9c] Phase 3: medium_class_discussion_size_8
[v9c] Phase 3: large_class_discussion_size_16
[v9c] Phase 4: Evaluation
[v9c] Phase 5: Generating report
[v9c] Run complete:
[v9c] Readiness pass rate:
[v9c] Total tokens:
```

- [ ] **Step 3: Verify report.md was generated with v9c sections**

```bash
# Find the latest run dir
RUN_DIR=$(ls -dt experiments/bloom_1n_vs_1on1/data/runs/*/ | head -1)
echo "Run dir: $RUN_DIR"
grep -E "(Readiness Summary|Interpretation Flags|Fine-Grained Memory|procedure_order)" "${RUN_DIR}report.md"
```

Expected: All four patterns appear in the report.

- [ ] **Step 4: Verify scores table is populated (not empty)**

```bash
grep "Correct%" "${RUN_DIR}report.md" | head -10
```

Expected: Lines showing percentages like `| lecture_only | 2 | 20 | XX% |`

- [ ] **Step 5: Commit smoke test report**

```bash
# The run artifacts (DB, report) are in gitignored data/ directory — nothing to commit
# Only commit if smoke test log reveals bugs that needed fixes
git add -p  # review any changes made during debugging
git commit -m "test(v9c): smoke test passes — all 5 conditions complete cleanly" || echo "No fixes needed"
```

---

## Self-Review

### Spec Coverage Check

| Spec Requirement | Covered By |
|-----------------|-----------|
| Fixed rich lecture artifact | Task 1: `fixed_lecture_v9c.md` |
| All canonical rules, edge cases, worked examples, debugging | Task 1: content of fixed_lecture_v9c.md |
| 4-type readiness check (recall, edge_case, rule_interaction, procedure_order) | Task 2 |
| Auto-scoring with corrective notes | Task 5 orchestrator (reuses `MasteryCheck.run`) |
| 80% readiness pass rate target | Task 5 (`readiness_pass_rate`, `readiness_failed`) |
| Fork corrected pre-discussion memory to all conditions | Task 5 Phase 2 → Phase 3 uses DB.get_learner_memory |
| 5 conditions (lecture_only, pair, small, medium, large) | Config Task 6, orchestrator Task 5 |
| 4 learner types (full run) | Config `config_v9c.yml` |
| Ownership metrics per learner | Task 5 Phase 3 (inherits `SizedDiscussion.run`) |
| ownership_score definition | Inherited from v9b (`SizedDiscussion.compute_ownership_score`) |
| 10-item fine-grained memory diagnostics | Task 3 |
| memory_delta_by_condition | Task 4 `fine_grained_memory_delta_section` |
| Report: readiness summary | Task 4 `readiness_summary_section` |
| Report: score by condition, task type, learner type | Inherited from v9b helpers |
| Report: ownership metrics | Inherited from v9b `ownership_section` |
| Report: interpretation flags | Task 4 `interpretation_flags_section` |
| readiness_failed flag | Task 5 computed, Task 4 displayed |
| ownership_effect_supported flag | Task 4 (Kendall-tau concordance) |
| class_size_effect_supported flag | Task 4 (sorted by size) |
| lecture_only_dominant flag | Task 4 |
| discussion_added_value flag | Task 4 |
| Smoke config (haiku) + full config (sonnet) | Task 6 |

### No Placeholder Check

All steps contain:
- Actual file paths ✓
- Complete code for every code step ✓
- Expected command output ✓
- No "TBD", "TODO", "implement later" ✓

### Type Consistency Check

- `pre_discussion_snapshots`: array of `{ 'learner_id' => String, 'condition' => String, 'memory' => Hash, 'diag' => Hash }` — consistent across Task 5 (producer) and Task 4 (consumer in `fine_grained_memory_delta_section`)
- `readiness_pass_rate`: Float in `[0.0, 1.0]` — consistent across Task 5 (producer) and Tasks 4+5 (consumers)
- `MemoryDiagnostics::ITEMS` now has 10 keys — `coverage_count` and `delta` still work since they iterate `ITEMS.keys`
- `DB.all_mastery_checks_by_condition` returns `check_type` column — now returns 4 types including `procedure_order` ✓
- `report.rb` mastery_rows guard updated to include `'v9c'` ✓
- Score-by-task-type guard updated to `%w[v9b v9c]` ✓
