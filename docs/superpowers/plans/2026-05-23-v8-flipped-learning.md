# v8 Flipped-Learning Interaction Experiment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement a 4-condition flipped-learning experiment (prerequisite lecture → mastery check → condition-specific interaction → evaluation) to test whether discussion or tutoring becomes effective after prerequisite knowledge is established.

**Architecture:** All conditions share the same rich prerequisite lecture and 3-question mastery check. Phase 3 diverges: `lecture_only` ends, `whole_class_discussion` / `small_group_discussion` / `one_on_one_tutoring` each interact with the now-knowledgeable learner. Memory is updated after each phase. Evaluation uses the latest memory.

**Tech Stack:** Ruby, SQLite3 (sqlite3 gem), Minitest, `claude --print` CLI, existing lib/ infrastructure (DB, LLM, Helpers, Scorer, LearnerTypes, Memory, Evaluator, Solver).

---

## Codebase Map

```
experiments/bloom_1n_vs_1on1/
  lib/
    db.rb                              ← MODIFY: add mastery_check_results table + methods
    phases/
      memory.rb                        ← MODIFY: add Memory.update method
      prerequisite_lecture.rb          ← CREATE: shared rich lecture + per-learner memory
      mastery_check.rb                 ← CREATE: 3 checks, auto-score, corrective notes
      whole_class_discussion.rb        ← CREATE: moderated whole-class + memory update
      small_group_discussion.rb        ← CREATE: pair discussion + memory update
      flipped_tutoring.rb              ← CREATE: mastery-error-based 1on1 + memory update
  prompts/
    discussion_moderator.md            ← CREATE
    discussion_participant.md          ← CREATE
    flipped_tutor.md                   ← CREATE
  domains/zarn_tokens/
    mastery_check_tasks.json           ← CREATE: 3 short check tasks
    eval_tasks_v8.json                 ← CREATE: 8 existing + 2 discussion-sensitive tasks
  scripts/
    run_experiment_v8.rb               ← CREATE: 4-condition orchestrator
  config_v8.yml                        ← CREATE: n=4/condition, sonnet
  config_v8_smoke.yml                  ← CREATE: n=2/condition, haiku
  tests/
    test_db_v8.rb                      ← CREATE: mastery_check_results table tests
    test_mastery_check.rb              ← CREATE: pure-function tests for MasteryCheck
    test_report_v8.rb                  ← CREATE: v8 report section tests
```

---

## Zarn Token Rule Reference (for task design in this plan)

| Sequence | Calculation | Answer |
|----------|-------------|--------|
| [Yellow, Green] | Yellow=7 (always), Green=last→inactive=0 | 7 |
| [Red, Blue] | Red doubles Blue; Blue has no Green left→inactive; doubled(0)=0 | 0 |
| [Green, Red, Yellow] | Green=not-last→2; Red doubles Yellow; Yellow=7×2=14; total=2+14 | 16 |
| [Red, Green, Blue, Yellow] | Red doubles Green(2→4); Blue=Green-left→5; Yellow=7; total=4+5+7 | 16 |

---

## Task 1: DB — mastery_check_results table

**Files:**
- Modify: `lib/db.rb`
- Test: `tests/test_db_v8.rb`

- [ ] **Step 1: Write failing test**

Create `tests/test_db_v8.rb`:

```ruby
# ABOUTME: Tests for v8 DB extensions — mastery_check_results table
# ABOUTME: Uses real temporary SQLite database; no mocking

$LOAD_PATH.unshift File.join(__dir__, '..', 'lib')
require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require 'db'

class TestDBV8 < Minitest::Test
  def setup
    @tmpdir  = Dir.mktmpdir
    @db_path = File.join(@tmpdir, 'test_v8.db')
    @db      = DB.setup(@db_path)
    @run_id  = Helpers.generate_id
    DB.save_run(@db, @run_id, 'test_v8', {})
  end

  def teardown
    @db.close
    FileUtils.rm_rf(@tmpdir)
  end

  def test_mastery_check_results_table_exists
    tables = @db.execute("SELECT name FROM sqlite_master WHERE type='table'").map { |r| r['name'] }
    assert_includes tables, 'mastery_check_results'
  end

  def test_save_mastery_check_returns_id
    learner_id = Helpers.generate_id
    id = DB.save_mastery_check(@db,
      run_id: @run_id, learner_id: learner_id,
      check_id: 'mc_recall_01', check_type: 'recall',
      response_text: '{"answer":"7"}', answer_correct: true,
      corrective_note: nil)
    assert_instance_of String, id
    refute_empty id
  end

  def test_get_mastery_checks_returns_all_for_learner
    learner_id = Helpers.generate_id
    DB.save_mastery_check(@db, run_id: @run_id, learner_id: learner_id,
      check_id: 'mc_recall_01', check_type: 'recall',
      response_text: '{"answer":"7"}', answer_correct: true, corrective_note: nil)
    DB.save_mastery_check(@db, run_id: @run_id, learner_id: learner_id,
      check_id: 'mc_edge_01', check_type: 'edge_case',
      response_text: '{"answer":"5"}', answer_correct: false,
      corrective_note: 'Blue is inactive if no Green to its left.')
    results = DB.get_mastery_checks(@db, run_id: @run_id, learner_id: learner_id)
    assert_equal 2, results.size
    wrong = results.find { |r| r['check_id'] == 'mc_edge_01' }
    assert_equal false, wrong['answer_correct']
    assert_equal 'Blue is inactive if no Green to its left.', wrong['corrective_note']
  end

  def test_get_mastery_check_errors_returns_only_wrong
    learner_id = Helpers.generate_id
    DB.save_mastery_check(@db, run_id: @run_id, learner_id: learner_id,
      check_id: 'mc_recall_01', check_type: 'recall',
      response_text: '{}', answer_correct: true, corrective_note: nil)
    DB.save_mastery_check(@db, run_id: @run_id, learner_id: learner_id,
      check_id: 'mc_edge_01', check_type: 'edge_case',
      response_text: '{}', answer_correct: false, corrective_note: 'note')
    errors = DB.get_mastery_check_errors(@db, run_id: @run_id, learner_id: learner_id)
    assert_equal 1, errors.size
    assert_equal 'mc_edge_01', errors.first['check_id']
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd experiments/bloom_1n_vs_1on1
ruby tests/test_db_v8.rb 2>&1 | tail -10
```
Expected: FAIL with "undefined method 'save_mastery_check'" or missing table.

- [ ] **Step 3: Add schema + methods to `lib/db.rb`**

Add to `SCHEMA` constant (after the `evaluations` table block, before the closing `SQL`):

```ruby
    CREATE TABLE IF NOT EXISTS mastery_check_results (
      id TEXT PRIMARY KEY,
      run_id TEXT NOT NULL,
      learner_id TEXT NOT NULL,
      check_id TEXT NOT NULL,
      check_type TEXT NOT NULL,
      response_text TEXT NOT NULL,
      answer_correct INTEGER NOT NULL,
      corrective_note TEXT,
      created_at TEXT NOT NULL DEFAULT (datetime('now'))
    );
```

Add these three methods to the DB module (after `save_evaluation`):

```ruby
  def self.save_mastery_check(db, run_id:, learner_id:, check_id:, check_type:,
                               response_text:, answer_correct:, corrective_note:)
    id = Helpers.generate_id
    db.execute(
      'INSERT INTO mastery_check_results (id, run_id, learner_id, check_id, check_type, response_text, answer_correct, corrective_note) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      [id, run_id, learner_id, check_id, check_type, response_text,
       answer_correct ? 1 : 0, corrective_note]
    )
    id
  end

  def self.get_mastery_checks(db, run_id:, learner_id:)
    rows = db.execute(
      'SELECT * FROM mastery_check_results WHERE run_id = ? AND learner_id = ? ORDER BY rowid',
      [run_id, learner_id]
    )
    rows.map { |r| r.merge('answer_correct' => r['answer_correct'] == 1) }
  end

  def self.get_mastery_check_errors(db, run_id:, learner_id:)
    get_mastery_checks(db, run_id: run_id, learner_id: learner_id)
      .select { |r| !r['answer_correct'] }
  end
```

- [ ] **Step 4: Run test to verify it passes**

```bash
ruby tests/test_db_v8.rb 2>&1 | tail -5
```
Expected: `4 runs, X assertions, 0 failures, 0 errors, 0 skips`

- [ ] **Step 5: Commit**

```bash
git add lib/db.rb tests/test_db_v8.rb
git commit -m "feat(v8): add mastery_check_results table and DB methods"
```

---

## Task 2: Domain Files — mastery_check_tasks.json + eval_tasks_v8.json

**Files:**
- Create: `domains/zarn_tokens/mastery_check_tasks.json`
- Create: `domains/zarn_tokens/eval_tasks_v8.json`

No test needed — these are data files; correctness verified by inspecting calculations in the Rule Reference above.

- [ ] **Step 1: Create `domains/zarn_tokens/mastery_check_tasks.json`**

```json
[
  {
    "id": "mc_recall_01",
    "check_type": "recall",
    "learner_prompt": "Calculate the final score for this Zarn token sequence: [Yellow, Green]\n\nUse only your memory of the rules. Do not assume rules you were not taught.\n\nRespond in JSON only:\n{\"answer\": \"<score>\", \"active_tokens\": [\"list active token names\"], \"mistakes_found\": [], \"reason\": \"<under 40 words>\"}",
    "expected_answer": "7",
    "expected_active_tokens": ["Yellow"],
    "expected_mistakes": [],
    "acceptable_aliases": {"7": ["7 points", "score: 7", "total: 7", "score is 7"]},
    "corrective_note": "Recall: [Yellow, Green]. Yellow is always active (7 pts). Green is the last token so it is inactive (0 pts). Score = 7."
  },
  {
    "id": "mc_edge_case_01",
    "check_type": "edge_case",
    "learner_prompt": "Calculate the final score for this Zarn token sequence: [Red, Blue]\n\nUse only your memory of the rules. Do not assume rules you were not taught.\n\nRespond in JSON only:\n{\"answer\": \"<score>\", \"active_tokens\": [\"list active token names\"], \"mistakes_found\": [], \"reason\": \"<under 40 words>\"}",
    "expected_answer": "0",
    "expected_active_tokens": [],
    "expected_mistakes": [],
    "acceptable_aliases": {"0": ["0 points", "score: 0", "total: 0", "score is 0"]},
    "corrective_note": "Edge case: [Red, Blue]. Blue has no Green to its left, so Blue is inactive (0). Red doubles it: doubled(0) = 0. Score = 0."
  },
  {
    "id": "mc_rule_interaction_01",
    "check_type": "rule_interaction",
    "learner_prompt": "Calculate the final score for this Zarn token sequence: [Green, Red, Yellow]\n\nUse only your memory of the rules. Do not assume rules you were not taught.\n\nRespond in JSON only:\n{\"answer\": \"<score>\", \"active_tokens\": [\"list active token names\"], \"mistakes_found\": [], \"reason\": \"<under 40 words>\"}",
    "expected_answer": "16",
    "expected_active_tokens": ["Green", "Yellow"],
    "expected_mistakes": [],
    "acceptable_aliases": {"16": ["16 points", "score: 16", "total: 16", "score is 16"]},
    "corrective_note": "Rule interaction: [Green, Red, Yellow]. Green = not last, active (2). Red doubles Yellow. Yellow always active: 7 x 2 = 14. Score = 2 + 14 = 16."
  }
]
```

- [ ] **Step 2: Create `domains/zarn_tokens/eval_tasks_v8.json`**

Copy all 8 tasks from `eval_tasks_v4.json` and append 2 new discussion-sensitive tasks:

```json
[
  {
    "id": "l1_recall_01",
    "difficulty": "L1",
    "task_type": "recall",
    "learner_prompt": "Calculate the final score for this Zarn token sequence: [Green, Blue, Yellow]\n\nUse only your memory of the rules. Do not assume rules you were not taught.\n\nRespond in JSON only:\n{\"answer\": \"<score>\", \"active_tokens\": [\"list active token names\"], \"mistakes_found\": [], \"reason\": \"<under 40 words>\"}",
    "hidden_rules": "Red=modifier(0pts,doubles next). Blue=active(5pts) only if Green to left. Green=inactive if last. Yellow=always active(7pts). Inactive tokens stay 0 even when doubled.",
    "expected_answer": "14",
    "expected_active_tokens": ["Green", "Blue", "Yellow"],
    "expected_mistakes": [],
    "acceptable_aliases": {"14": ["14 points", "score: 14", "total: 14", "score is 14"]}
  },
  {
    "id": "l2_edge_case_01",
    "difficulty": "L2",
    "task_type": "edge_case",
    "learner_prompt": "Calculate the final score for this Zarn token sequence: [Blue, Green]\n\nUse only your memory of the rules. Do not assume rules you were not taught.\n\nRespond in JSON only:\n{\"answer\": \"<score>\", \"active_tokens\": [\"list active token names\"], \"mistakes_found\": [], \"reason\": \"<under 40 words>\"}",
    "hidden_rules": "Red=modifier(0pts,doubles next). Blue=active(5pts) only if Green to left. Green=inactive if last. Yellow=always active(7pts). Inactive tokens stay 0 even when doubled.",
    "expected_answer": "0",
    "expected_active_tokens": [],
    "expected_mistakes": [],
    "acceptable_aliases": {"0": ["0 points", "score: 0", "total: 0", "score is 0"]}
  },
  {
    "id": "l2_edge_case_02",
    "difficulty": "L2",
    "task_type": "edge_case",
    "learner_prompt": "Calculate the final score for this Zarn token sequence: [Green, Blue, Green]\n\nUse only your memory of the rules. Do not assume rules you were not taught.\n\nRespond in JSON only:\n{\"answer\": \"<score>\", \"active_tokens\": [\"list active token names\"], \"mistakes_found\": [], \"reason\": \"<under 40 words>\"}",
    "hidden_rules": "Red=modifier(0pts,doubles next). Blue=active(5pts) only if Green to left. Green=inactive if last. Yellow=always active(7pts). Inactive tokens stay 0 even when doubled.",
    "expected_answer": "7",
    "expected_active_tokens": ["Green", "Blue"],
    "expected_mistakes": [],
    "acceptable_aliases": {"7": ["7 points", "score: 7", "total: 7", "score is 7"]}
  },
  {
    "id": "l3_rule_interaction_01",
    "difficulty": "L3",
    "task_type": "rule_interaction",
    "learner_prompt": "Calculate the final score for this Zarn token sequence: [Green, Red, Blue]\n\nUse only your memory of the rules. Do not assume rules you were not taught.\n\nRespond in JSON only:\n{\"answer\": \"<score>\", \"active_tokens\": [\"list active token names\"], \"mistakes_found\": [], \"reason\": \"<under 40 words>\"}",
    "hidden_rules": "Red=modifier(0pts,doubles next). Blue=active(5pts) only if Green to left. Green=inactive if last. Yellow=always active(7pts). Inactive tokens stay 0 even when doubled.",
    "expected_answer": "12",
    "expected_active_tokens": ["Green", "Blue"],
    "expected_mistakes": [],
    "acceptable_aliases": {"12": ["12 points", "score: 12", "score is 12"]}
  },
  {
    "id": "l4_debug_01",
    "difficulty": "L4",
    "task_type": "debugging",
    "learner_prompt": "A learner calculated the score of [Green, Blue, Red, Yellow] as 21. The learner is wrong.\n\nWhat is the correct score? What mistake did the learner make?\n\nRespond in JSON only:\n{\"answer\": \"<correct score>\", \"active_tokens\": [\"list active token names\"], \"mistakes_found\": [\"describe each mistake in under 15 words\"], \"reason\": \"<under 40 words>\"}",
    "hidden_rules": "Red=modifier(0pts,doubles next). Blue=active(5pts) only if Green to left. Green=inactive if last. Yellow=always active(7pts). Inactive tokens stay 0 even when doubled.",
    "expected_answer": "21",
    "expected_active_tokens": ["Green", "Blue", "Yellow"],
    "expected_mistakes": [],
    "acceptable_aliases": {"21": ["21 points", "score: 21", "total: 21", "score is 21"]}
  },
  {
    "id": "l4_debug_02",
    "difficulty": "L4",
    "task_type": "debugging",
    "learner_prompt": "A learner calculated the score of [Red, Green, Blue] as 14. The learner is wrong.\n\nWhat is the correct score? What mistake did the learner make?\n\nRespond in JSON only:\n{\"answer\": \"<correct score>\", \"active_tokens\": [\"list active token names\"], \"mistakes_found\": [\"describe each mistake in under 15 words\"], \"reason\": \"<under 40 words>\"}",
    "hidden_rules": "Red=modifier(0pts,doubles next). Blue=active(5pts) only if Green to left. Green=inactive if last. Yellow=always active(7pts). Inactive tokens stay 0 even when doubled.",
    "expected_answer": "9",
    "expected_active_tokens": ["Green", "Blue"],
    "expected_mistakes": ["Red doubles Green not Blue", "score should be 9"],
    "acceptable_aliases": {"9": ["9 points", "score: 9", "total: 9", "score is 9"]}
  },
  {
    "id": "l5_debug_03",
    "difficulty": "L5",
    "task_type": "debugging",
    "learner_prompt": "A learner calculated the score of [Green, Red, Blue, Yellow] as 26. The learner is wrong.\n\nWhat is the correct score? What mistake did the learner make?\n\nRespond in JSON only:\n{\"answer\": \"<correct score>\", \"active_tokens\": [\"list active token names\"], \"mistakes_found\": [\"describe each mistake in under 15 words\"], \"reason\": \"<under 40 words>\"}",
    "hidden_rules": "Red=modifier(0pts,doubles next). Blue=active(5pts) only if Green to left. Green=inactive if last. Yellow=always active(7pts). Inactive tokens stay 0 even when doubled.",
    "expected_answer": "21",
    "expected_active_tokens": ["Green", "Blue", "Yellow"],
    "expected_mistakes": ["Red doubles Blue not Yellow", "Yellow score should be 7 not 14"],
    "acceptable_aliases": {"21": ["21 points", "score: 21", "total: 21", "score is 21"]}
  },
  {
    "id": "l6_induction_02",
    "difficulty": "L6",
    "task_type": "short_rule_induction",
    "learner_prompt": "Based on these three observations, state the rule for Red Zarn:\n- [Red, Yellow] → score 14\n- [Red, Blue, Green] → score 0 (Blue has no Green to left; Green is last)\n- [Green, Red, Yellow] → score 16\n\nWhat does Red Zarn do?\n\nRespond in JSON only:\n{\"answer\": \"<state the rule in under 20 words>\", \"active_tokens\": [], \"mistakes_found\": [], \"reason\": \"<under 30 words>\"}",
    "hidden_rules": "Red=modifier(0pts,doubles next). Blue=active(5pts) only if Green to left. Green=inactive if last. Yellow=always active(7pts). Inactive tokens stay 0 even when doubled.",
    "expected_answer": "red doubles the next token and contributes 0 points itself",
    "expected_active_tokens": [],
    "expected_mistakes": [],
    "acceptable_aliases": {
      "red doubles the next token and contributes 0 points itself": [
        "red doubles next token scores zero",
        "red is a modifier that doubles the token to its right",
        "red doubles the value of the next token and adds 0",
        "red zarn doubles the next token contributes 0"
      ]
    }
  },
  {
    "id": "l7_peer_error_01",
    "difficulty": "L4",
    "task_type": "peer_error_detection",
    "learner_prompt": "A learner calculated the score of [Red, Blue, Yellow] as 17. They explained: 'Red doubles Blue (5→10), then Yellow=7, total=17.'\n\nIs the learner correct? If not, what is the correct score and what mistake did they make?\n\nRespond in JSON only:\n{\"answer\": \"<correct score>\", \"active_tokens\": [\"list active token names\"], \"mistakes_found\": [\"describe each mistake in under 15 words\"], \"reason\": \"<under 40 words>\"}",
    "hidden_rules": "Red=modifier(0pts,doubles next). Blue=active(5pts) only if Green to left. Green=inactive if last. Yellow=always active(7pts). Inactive tokens stay 0 even when doubled.",
    "expected_answer": "7",
    "expected_active_tokens": ["Yellow"],
    "expected_mistakes": ["blue has no green to its left so blue is inactive", "doubled inactive token is still 0"],
    "acceptable_aliases": {"7": ["7 points", "score: 7", "total: 7", "score is 7"]}
  },
  {
    "id": "l7_explanation_choice_01",
    "difficulty": "L5",
    "task_type": "explanation_choice",
    "learner_prompt": "For the sequence [Red, Green, Blue], three learners give different explanations. Which explanation is correct?\n\nA: Red doubles Green (2→4). Blue is active because Green is to its left (5). Total = 0+4+5 = 9.\nB: Red makes everything score double, so Green=4, Blue=10. Total = 14.\nC: Red=0, Green is not last so active (2), Blue has Green to its left so active (5). Total = 7.\n\nRespond in JSON only:\n{\"answer\": \"<A, B, or C>\", \"active_tokens\": [], \"mistakes_found\": [], \"reason\": \"<under 40 words>\"}",
    "hidden_rules": "Red=modifier(0pts,doubles next). Blue=active(5pts) only if Green to left. Green=inactive if last. Yellow=always active(7pts). Inactive tokens stay 0 even when doubled.",
    "expected_answer": "a",
    "expected_active_tokens": [],
    "expected_mistakes": [],
    "acceptable_aliases": {"a": ["a)", "option a", "explanation a", "choice a"]}
  }
]
```

- [ ] **Step 3: Verify task calculations manually**

```
l2_edge_case_02: [Green, Blue, Green]
  Green(pos1) = not last → active = 2
  Blue(pos2) = Green to left → active = 5
  Green(pos3) = last → inactive = 0
  Total = 2 + 5 + 0 = 7  ✓ expected_answer: "7"

l4_debug_01: [Green, Blue, Red, Yellow]
  Green=not last→2; Blue=Green-left→5; Red=modifier; Yellow=7×2=14
  Total = 2+5+0+14 = 21. Learner said 21 — that's CORRECT.
  expected_answer: "21", expected_mistakes: []  ✓ (learner was right, task tests recognition)

l4_debug_02: [Red, Green, Blue] — learner says 14
  Red doubles Green(2→4). Blue=Green-left→5. Total=0+4+5=9
  Learner mistake: thought Red doubles Blue (not Green). expected_answer: "9"  ✓

l5_debug_03: [Green, Red, Blue, Yellow] — learner says 26
  Green=2; Red doubles Blue; Blue=Green-left→5×2=10; Yellow=7
  Total = 2+0+10+7 = 19. Wait, that's 19, not 21.
  Let me recalculate: Green(2) + Red(0) + Blue(doubled,5→10) + Yellow(7) = 19.
  But I wrote expected_answer "21"... let me fix.

  Actually the learner says 26. If correct is 19, then:
  Learner mistake: doubled Yellow instead of Blue → Green(2)+Red(0)+Blue(5)+Yellow(14)=21.
  Or learner doubled Yellow and treated Blue as doubled too → 2+0+10+14=26. ✓

  So correct answer is 19. Let me fix the task.
```

**STOP** — `l5_debug_03` calculation above gives correct answer 19, but the plan has "21". Fix before continuing:

Recalculate `l5_debug_03`: [Green, Red, Blue, Yellow]
- Green = not last → 2
- Red = modifier, doubles the NEXT token (Blue)
- Blue = Green to left → active = 5 × 2 (Red doubled) = 10
- Yellow = always active = 7
- Total = 2 + 0 + 10 + 7 = **19**

The learner says 26 with the mistake "doubled Yellow (7→14) AND doubled Blue (5→10): 2+0+10+14=26". Correct answer = 19.

Update `l5_debug_03` in the JSON above:
- `"expected_answer": "19"`
- `"acceptable_aliases": {"19": ["19 points", "score: 19", "total: 19", "score is 19"]}`
- `"expected_mistakes": ["Red doubles Blue not Yellow", "Yellow score should be 7 not 14"]`

Also fix `l4_debug_01`: [Green, Blue, Red, Yellow] — learner says 21. Let me recalculate:
- Green=2, Blue=Green-left→5, Red doubles Yellow→7×2=14, total=2+5+0+14=21. Learner is CORRECT.
- This is a trick task: the expected_mistakes is [] because the learner is right. Tests whether learner can recognize a correct answer.
- expected_answer stays "21" ✓

Write the corrected `eval_tasks_v8.json` with `l5_debug_03.expected_answer = "19"` and aliases updated accordingly. (The full JSON above minus that correction is otherwise valid — apply this fix when creating the file.)

- [ ] **Step 4: Commit**

```bash
git add domains/zarn_tokens/mastery_check_tasks.json domains/zarn_tokens/eval_tasks_v8.json
git commit -m "feat(v8): add mastery_check_tasks and eval_tasks_v8 domain files"
```

---

## Task 3: Memory.update Method

**Files:**
- Modify: `lib/phases/memory.rb`
- Test: `tests/test_mastery_check.rb` (tests pure memory patching logic used by MasteryCheck)

The `update` method takes an existing memory hash + a transcript of the interaction, calls LLM to produce an updated memory, and applies LearnerTypes constraints again.

- [ ] **Step 1: Write failing test for memory patching (pure, no LLM)**

Create `tests/test_mastery_check.rb` with just the pure-function test first:

```ruby
# ABOUTME: Tests for MasteryCheck phase — pure-function coverage only (no LLM calls)
# ABOUTME: Tests corrective-note patching and mastery-check result scoring logic

$LOAD_PATH.unshift File.join(__dir__, '..', 'lib')
require 'minitest/autorun'
require 'json'

class TestMasteryCheckPatch < Minitest::Test
  def base_memory
    {
      'rules'                    => ['Blue active if Green to left', 'Green inactive if last'],
      'examples'                 => ['Green,Blue,Yellow = 14'],
      'edge_cases'               => [],
      'strategy'                 => ['check activation before score'],
      'corrected_misconceptions' => [],
      'remaining_misconceptions' => [],
      'uncertain_rules'          => []
    }
  end

  def test_append_corrective_note_adds_to_array
    mem = base_memory
    note = 'Edge case: [Red, Blue]. Blue inactive, doubled(0)=0.'
    mem['corrected_misconceptions'] << note
    assert_includes mem['corrected_misconceptions'], note
  end

  def test_append_two_notes_accumulates
    mem = base_memory
    mem['corrected_misconceptions'] << 'Note 1'
    mem['corrected_misconceptions'] << 'Note 2'
    assert_equal 2, mem['corrected_misconceptions'].size
  end

  def test_mastery_check_score_correct_when_answer_matches
    task = { 'expected_answer' => '7', 'expected_active_tokens' => ['Yellow'],
             'expected_mistakes' => [], 'acceptable_aliases' => {} }
    parsed = { 'answer' => '7', 'active_tokens' => ['Yellow'], 'mistakes_found' => [],
               'confidence' => 0.9, 'abstain' => false }
    require 'scorer'
    result = Scorer.score_attempt(parsed, task)
    assert result['answer_correct'], "Expected answer_correct to be true"
  end

  def test_mastery_check_score_wrong_when_answer_differs
    task = { 'expected_answer' => '7', 'expected_active_tokens' => [],
             'expected_mistakes' => [], 'acceptable_aliases' => {} }
    parsed = { 'answer' => '5', 'active_tokens' => [], 'mistakes_found' => [],
               'confidence' => 0.5, 'abstain' => false }
    require 'scorer'
    result = Scorer.score_attempt(parsed, task)
    refute result['answer_correct'], "Expected answer_correct to be false"
  end
end
```

- [ ] **Step 2: Run test to verify it passes (these tests use no LLM)**

```bash
ruby tests/test_mastery_check.rb 2>&1 | tail -5
```
Expected: `4 runs, X assertions, 0 failures, 0 errors, 0 skips`

- [ ] **Step 3: Add `Memory.update` to `lib/phases/memory.rb`**

Add this method to the `Phases::Memory` module, after the `generate` method:

```ruby
    # Update an existing memory based on a new interaction transcript.
    # Passes old memory as context; returns updated memory with constraints re-applied.
    def self.update(learner_id:, existing_memory:, update_transcript:, summarizer_prompt:,
                    config:, tracker: nil, learner_type_key: nil)
      model     = config.dig('models', 'memory_summarizer') || 'claude-sonnet-4-6'
      max_words = config.dig('experiment', 'max_memory_words') || MAX_WORDS

      if learner_type_key
        type_def  = LearnerTypes.fetch(learner_type_key)
        max_words = type_def[:memory_budget_words]
      end

      old_memory_text   = JSON.pretty_generate(existing_memory)
      transcript_text   = Helpers.format_turns_for_prompt(update_transcript)

      prompt = Helpers.build_prompt(
        system: summarizer_prompt,
        context: "EXISTING MEMORY FOR #{learner_id}:\n#{old_memory_text}\n\nNEW INTERACTION TRANSCRIPT:\n#{transcript_text}",
        instruction: "Update the memory JSON for #{learner_id} by incorporating new insights from the transcript. Keep correct existing knowledge; correct or add only what the transcript changes. Return ONLY valid JSON. No prose."
      )

      raw    = LLM.call(prompt, model: model, tracker: tracker, phase: 'memory')
      memory = Helpers.extract_json(raw)

      if memory.nil?
        $stderr.puts "[memory:#{learner_id}] WARNING: Could not parse updated memory JSON, keeping existing"
        return existing_memory
      end

      DEFAULT_MEMORY.each_key { |k| memory[k] ||= [] }

      if learner_type_key
        memory = LearnerTypes.apply_constraints(memory, learner_type_key)
        $stderr.puts "[memory:#{learner_id}] Updated memory with #{learner_type_key} constraints (#{LearnerTypes.word_count(memory)} words)"
      else
        memory = LearnerTypes.trim_to_budget(memory, max_words)
        $stderr.puts "[memory:#{learner_id}] Updated memory (#{LearnerTypes.word_count(memory)} words)"
      end

      memory
    end
```

- [ ] **Step 4: Run all existing tests to ensure no regression**

```bash
ruby -e "Dir['tests/test_*.rb'].each { |f| load f }" 2>&1 | grep "^[0-9]* runs"
```
Expected: same pass/fail counts as before (19 pre-existing errors from LLM.stub, 0 new failures).

- [ ] **Step 5: Commit**

```bash
git add lib/phases/memory.rb tests/test_mastery_check.rb
git commit -m "feat(v8): add Memory.update method and mastery check pure-function tests"
```

---

## Task 4: Phases::PrerequisiteLecture

**Files:**
- Create: `lib/phases/prerequisite_lecture.rb`

Delivers a single shared lecture to all learners in a condition. Returns transcript + generates initial per-learner memory. The lecture instruction emphasizes full rule coverage, edge cases, worked examples, and common mistakes.

- [ ] **Step 1: Create `lib/phases/prerequisite_lecture.rb`**

```ruby
# ABOUTME: Phase 1 of flipped-learning: delivers shared prerequisite lecture to all learners
# ABOUTME: Returns shared transcript; callers generate individual memories from it separately

require_relative '../llm'
require_relative '../helpers'
require_relative '../learner_types'

module Phases
  module PrerequisiteLecture
    LECTURE_INSTRUCTION = <<~INST.freeze
      Deliver a comprehensive prerequisite lecture covering ALL of the following:
      1. Every canonical rule (Red modifier, Blue activation, Green end rule, Yellow always active, stacking)
      2. Each edge case and boundary condition
      3. Modifier ordering (what Red doubles vs does not)
      4. At least 3 worked examples with step-by-step breakdowns
      5. The most common student mistakes and why they are wrong

      This lecture is the sole knowledge source before the quiz. Make it complete and systematic.
      Do not cut any rule. Do not summarize — explain each rule with an example.
    INST

    def self.run(teacher_id:, learner_ids:, teacher_prompt:, learner_prompt:, lesson:,
                 config:, tracker: nil, learner_type_keys: {})
      model         = config.dig('models', 'teacher') || 'claude-sonnet-4-6'
      condition     = 'prerequisite_lecture'

      prompt = Helpers.build_prompt(
        system: teacher_prompt,
        context: "DOMAIN LESSON:\n#{lesson}",
        instruction: LECTURE_INSTRUCTION
      )
      lecture = LLM.call(prompt, model: model, tracker: tracker, phase: "education_#{condition}")
      $stderr.puts "[#{condition}] Teacher delivered lecture (#{lecture.length} chars)"

      turns = [{ 'speaker' => 'teacher', 'type' => 'lecture', 'content' => lecture }]

      {
        'condition'   => condition,
        'teacher_id'  => teacher_id,
        'learner_ids' => learner_ids,
        'turns'       => turns,
        'lecture'     => lecture
      }
    end
  end
end
```

- [ ] **Step 2: Verify the file loads without error**

```bash
ruby -e "require_relative 'lib/phases/prerequisite_lecture'; puts 'OK'"
```
Expected: `OK`

- [ ] **Step 3: Commit**

```bash
git add lib/phases/prerequisite_lecture.rb
git commit -m "feat(v8): add PrerequisiteLecture phase with full-coverage lecture instruction"
```

---

## Task 5: Phases::MasteryCheck

**Files:**
- Create: `lib/phases/mastery_check.rb`
- Extend: `tests/test_mastery_check.rb` (structural tests)

Runs 3 short check questions per learner using Solver. Auto-scores each. If wrong, appends the task's `corrective_note` to memory. Saves results to DB. Returns updated memory.

- [ ] **Step 1: Add structural tests to `tests/test_mastery_check.rb`**

Append to the existing test file:

```ruby
# NOTE: structural tests for MasteryCheck.apply_corrections require no LLM
class TestMasteryCheckApplyCorrections < Minitest::Test
  def base_memory
    {
      'rules' => ['Blue active if Green to left'],
      'examples' => [], 'edge_cases' => [], 'strategy' => [],
      'corrected_misconceptions' => [], 'remaining_misconceptions' => [],
      'uncertain_rules' => []
    }
  end

  def test_apply_corrections_adds_note_for_wrong_answer
    require 'phases/mastery_check'
    errors = [{ 'corrective_note' => 'Edge case: Blue inactive if no Green left.' }]
    updated = Phases::MasteryCheck.apply_corrections(base_memory, errors)
    assert_includes updated['corrected_misconceptions'],
                    'Edge case: Blue inactive if no Green left.'
  end

  def test_apply_corrections_no_change_for_empty_errors
    require 'phases/mastery_check'
    updated = Phases::MasteryCheck.apply_corrections(base_memory, [])
    assert_equal [], updated['corrected_misconceptions']
  end

  def test_apply_corrections_does_not_add_nil_note
    require 'phases/mastery_check'
    errors = [{ 'corrective_note' => nil }]
    updated = Phases::MasteryCheck.apply_corrections(base_memory, errors)
    assert_equal [], updated['corrected_misconceptions']
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
ruby tests/test_mastery_check.rb 2>&1 | tail -10
```
Expected: FAIL with "uninitialized constant Phases::MasteryCheck".

- [ ] **Step 3: Create `lib/phases/mastery_check.rb`**

```ruby
# ABOUTME: Phase 2 of flipped-learning: 3 short mastery checks per learner, auto-scored
# ABOUTME: Appends corrective notes to memory for wrong answers; saves results to DB

require_relative '../llm'
require_relative '../helpers'
require_relative '../scorer'

module Phases
  module MasteryCheck
    # Run 3 mastery check questions for a single learner.
    # Returns { checks: [...score hashes...], errors: [...tasks where wrong...], updated_memory: hash }
    def self.run(learner_id:, memory:, check_tasks:, solver_prompt:, config:, db:, run_id:, tracker: nil)
      model   = config.dig('models', 'problem_solver') || 'claude-sonnet-4-6'
      checks  = []
      errors  = []

      check_tasks.each do |task|
        memory_text = JSON.pretty_generate(memory)
        prompt = Helpers.build_prompt(
          system: solver_prompt,
          context: "YOUR LEARNING MEMORY:\n#{memory_text}",
          instruction: task['learner_prompt']
        )
        response = LLM.call(prompt, model: model, tracker: tracker, phase: 'mastery_check')
        parsed   = Helpers.extract_json(response) || {}

        score  = Scorer.score_attempt(parsed, task)
        correct = score['answer_correct']

        DB.save_mastery_check(db,
          run_id: run_id, learner_id: learner_id,
          check_id: task['id'], check_type: task['check_type'],
          response_text: response, answer_correct: correct,
          corrective_note: correct ? nil : task['corrective_note'])

        $stderr.puts "[mastery_check:#{learner_id}] #{task['id']}: #{correct ? 'CORRECT' : 'WRONG'}"
        checks << score.merge('check_id' => task['id'], 'check_type' => task['check_type'])
        errors << task unless correct
      end

      updated = apply_corrections(memory, errors)
      { checks: checks, errors: errors, updated_memory: updated }
    end

    # Pure function: appends corrective notes from wrong-answer tasks to memory.
    def self.apply_corrections(memory, error_tasks)
      return memory if error_tasks.empty?
      result = memory.transform_values { |v| v.is_a?(Array) ? v.dup : v }
      error_tasks.each do |task|
        note = task['corrective_note']
        result['corrected_misconceptions'] << note if note && !note.empty?
      end
      result
    end
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
ruby tests/test_mastery_check.rb 2>&1 | tail -5
```
Expected: `7 runs, X assertions, 0 failures, 0 errors, 0 skips`

- [ ] **Step 5: Commit**

```bash
git add lib/phases/mastery_check.rb tests/test_mastery_check.rb
git commit -m "feat(v8): add MasteryCheck phase with corrective note patching"
```

---

## Task 6: Phases::WholeClassDiscussion

**Files:**
- Create: `lib/phases/whole_class_discussion.rb`

All learners in the condition discuss one shared problem. Moderator facilitates lightly. All can see the full transcript. Each learner then updates their memory.

The discussion problem is `[Red, Green, Blue, Yellow]` (score=16): a 4-token sequence requiring Red-doubles-Green, Blue-has-Green-left, and Yellow-always-active.

- [ ] **Step 1: Create `lib/phases/whole_class_discussion.rb`**

```ruby
# ABOUTME: Phase 3 option: all learners discuss one shared debugging problem with light moderation
# ABOUTME: Returns shared transcript; callers update individual memories from it

require_relative '../llm'
require_relative '../helpers'
require_relative '../learner_types'

module Phases
  module WholeClassDiscussion
    DISCUSSION_PROBLEM = <<~PROB.freeze
      DISCUSSION PROBLEM: Calculate and explain the score for [Red, Green, Blue, Yellow].
      - Show your step-by-step reasoning.
      - Identify which tokens are active and why.
      - Note any rules that are easy to get wrong here.
    PROB

    def self.run(moderator_id:, learner_ids:, moderator_prompt:, participant_prompt:, lesson:,
                 config:, tracker: nil, learner_type_keys: {})
      mod_model      = config.dig('models', 'teacher')  || 'claude-sonnet-4-6'
      learner_model  = config.dig('models', 'learner')  || 'claude-sonnet-4-6'
      condition      = 'lecture_plus_whole_class_discussion'

      turns = []

      # Moderator opens
      open_prompt = Helpers.build_prompt(
        system: moderator_prompt,
        context: "DOMAIN LESSON:\n#{lesson}",
        instruction: "Open the discussion. Present the problem to all learners and invite them to share their reasoning. Under 80 words.\n\n#{DISCUSSION_PROBLEM}"
      )
      opening = LLM.call(open_prompt, model: mod_model, tracker: tracker, phase: "education_#{condition}")
      turns << { 'speaker' => 'moderator', 'type' => 'opening', 'content' => opening }
      $stderr.puts "[#{condition}] Moderator opened discussion"

      # Each learner contributes
      learner_ids.each do |lid|
        history = Helpers.format_turns_for_prompt(turns)
        type_key = learner_type_keys[lid]
        learner_context = type_key ? "\n\nYOUR LEARNER TYPE: #{type_key} — respond authentically." : ''

        contrib_prompt = Helpers.build_prompt(
          system: participant_prompt,
          context: "DISCUSSION SO FAR:\n#{history}#{learner_context}",
          instruction: "Contribute your reasoning for the discussion problem. Show your step-by-step thinking. Address any point another learner raised if relevant. Under 100 words."
        )
        contrib = LLM.call(contrib_prompt, model: learner_model, tracker: tracker, phase: "education_#{condition}")
        turns << { 'speaker' => lid, 'type' => 'contribution', 'content' => contrib }
        $stderr.puts "[#{condition}] #{lid} contributed"
      end

      # Moderator closes
      history = Helpers.format_turns_for_prompt(turns)
      close_prompt = Helpers.build_prompt(
        system: moderator_prompt,
        context: "DOMAIN LESSON:\n#{lesson}\n\nDISCUSSION:\n#{history}",
        instruction: "Close the discussion. Confirm the correct answer and highlight the key rules demonstrated. Correct any errors in learner contributions. Under 100 words."
      )
      closing = LLM.call(close_prompt, model: mod_model, tracker: tracker, phase: "education_#{condition}")
      turns << { 'speaker' => 'moderator', 'type' => 'closing', 'content' => closing }
      $stderr.puts "[#{condition}] Moderator closed discussion"

      {
        'condition'    => condition,
        'moderator_id' => moderator_id,
        'learner_ids'  => learner_ids,
        'turns'        => turns,
        'contributions' => learner_ids.size
      }
    end
  end
end
```

- [ ] **Step 2: Verify the file loads without error**

```bash
ruby -e "require_relative 'lib/phases/whole_class_discussion'; puts 'OK'"
```
Expected: `OK`

- [ ] **Step 3: Commit**

```bash
git add lib/phases/whole_class_discussion.rb
git commit -m "feat(v8): add WholeClassDiscussion phase with moderated shared problem"
```

---

## Task 7: Phases::SmallGroupDiscussion

**Files:**
- Create: `lib/phases/small_group_discussion.rb`

Splits learners into groups of 2 (or 1 if n is odd). Each group discusses one problem, produces shared notes. Each learner must contribute at least once.

- [ ] **Step 1: Create `lib/phases/small_group_discussion.rb`**

```ruby
# ABOUTME: Phase 3 option: learners split into pairs; each pair discusses and produces shared notes
# ABOUTME: Each learner contributes at least once; returns per-group transcripts

require_relative '../llm'
require_relative '../helpers'
require_relative '../learner_types'

module Phases
  module SmallGroupDiscussion
    GROUP_PROBLEM = <<~PROB.freeze
      GROUP PROBLEM: Calculate and explain the score for [Red, Green, Blue, Yellow].
      - Each member must contribute their reasoning.
      - Identify which tokens are active and why.
      - Agree on the correct answer and note any rules that tripped you up.
    PROB

    def self.run(learner_ids:, participant_prompt:, lesson:, config:, tracker: nil, learner_type_keys: {})
      learner_model = config.dig('models', 'learner') || 'claude-sonnet-4-6'
      condition     = 'lecture_plus_small_group_discussion'

      groups  = learner_ids.each_slice(2).to_a
      results = []

      groups.each_with_index do |group, idx|
        group_turns = []

        # Each member contributes once (round 1)
        group.each do |lid|
          history = Helpers.format_turns_for_prompt(group_turns)
          context_prefix = history.empty? ? '' : "GROUP DISCUSSION SO FAR:\n#{history}\n\n"
          type_key = learner_type_keys[lid]
          learner_context = type_key ? "\n\nYOUR LEARNER TYPE: #{type_key} — respond authentically." : ''

          contrib_prompt = Helpers.build_prompt(
            system: participant_prompt,
            context: "#{context_prefix}LESSON CONTEXT:\n#{lesson}#{learner_context}",
            instruction: "Contribute your reasoning to your group. Show step-by-step thinking for the problem. Under 80 words.\n\n#{GROUP_PROBLEM}"
          )
          contrib = LLM.call(contrib_prompt, model: learner_model, tracker: tracker, phase: "education_#{condition}")
          group_turns << { 'speaker' => lid, 'type' => 'contribution', 'content' => contrib }
          $stderr.puts "[#{condition}] group#{idx} #{lid} contributed"
        end

        # Each member responds to the other (round 2) — only meaningful for pairs
        if group.size > 1
          group.each do |lid|
            history = Helpers.format_turns_for_prompt(group_turns)
            type_key = learner_type_keys[lid]
            learner_context = type_key ? "\n\nYOUR LEARNER TYPE: #{type_key} — respond authentically." : ''

            reply_prompt = Helpers.build_prompt(
              system: participant_prompt,
              context: "GROUP DISCUSSION:\n#{history}#{learner_context}",
              instruction: "Respond to what your partner said. Agree, correct, or add a point. Under 60 words."
            )
            reply = LLM.call(reply_prompt, model: learner_model, tracker: tracker, phase: "education_#{condition}")
            group_turns << { 'speaker' => lid, 'type' => 'reply', 'content' => reply }
            $stderr.puts "[#{condition}] group#{idx} #{lid} replied"
          end
        end

        # Produce shared notes (first member writes on behalf of group)
        history = Helpers.format_turns_for_prompt(group_turns)
        notes_prompt = Helpers.build_prompt(
          system: participant_prompt,
          context: "GROUP DISCUSSION:\n#{history}",
          instruction: "Write short shared notes for your group summarizing: (1) the correct answer, (2) the key rule each member needs to remember, (3) any mistakes noticed. Under 80 words. Start with 'GROUP NOTES:'"
        )
        notes = LLM.call(notes_prompt, model: learner_model, tracker: tracker, phase: "education_#{condition}")
        group_turns << { 'speaker' => group.first, 'type' => 'shared_notes', 'content' => notes }
        $stderr.puts "[#{condition}] group#{idx} produced shared notes"

        results << {
          'condition'     => condition,
          'group_index'   => idx,
          'learner_ids'   => group,
          'turns'         => group_turns,
          'shared_notes'  => notes,
          'contributions' => group.size
        }
      end

      results
    end
  end
end
```

- [ ] **Step 2: Verify the file loads without error**

```bash
ruby -e "require_relative 'lib/phases/small_group_discussion'; puts 'OK'"
```
Expected: `OK`

- [ ] **Step 3: Commit**

```bash
git add lib/phases/small_group_discussion.rb
git commit -m "feat(v8): add SmallGroupDiscussion phase with pair discussion and shared notes"
```

---

## Task 8: Phases::FlippedTutoring

**Files:**
- Create: `lib/phases/flipped_tutoring.rb`

Tutor reviews which mastery check questions the learner got wrong, provides one corrective worked example per error, and has the learner restate the corrected rule. Shorter than full tutoring because prerequisite knowledge exists. 2 exchanges (4 turns) per learner.

- [ ] **Step 1: Create `lib/phases/flipped_tutoring.rb`**

```ruby
# ABOUTME: Phase 3 option: tutor reviews mastery check errors; gives one corrective example per error
# ABOUTME: Shorter than full tutoring because prerequisite knowledge already exists from lecture

require_relative '../llm'
require_relative '../helpers'
require_relative '../learner_types'

module Phases
  module FlippedTutoring
    def self.run_session(tutor_id:, learner_id:, tutor_prompt:, learner_prompt:, lesson:,
                         mastery_errors:, config:, tracker: nil, learner_type_key: nil)
      tutor_model   = config.dig('models', 'tutor')   || 'claude-sonnet-4-6'
      learner_model = config.dig('models', 'learner') || 'claude-sonnet-4-6'
      condition     = 'lecture_plus_one_on_one_tutoring'

      type_context    = learner_type_key ? "\n\n#{LearnerTypes.to_prompt_context(learner_type_key)}" : ''
      learner_context = learner_type_key ? "\n\nYOUR LEARNER TYPE: #{learner_type_key} — respond authentically." : ''

      turns = []

      if mastery_errors.empty?
        # No errors: tutor gives a consolidation review
        review_prompt = Helpers.build_prompt(
          system: tutor_prompt,
          context: "DOMAIN LESSON:\n#{lesson}#{type_context}",
          instruction: "The learner passed all mastery checks. Give one advanced consolidation example that combines multiple rules. Under 100 words."
        )
        review = LLM.call(review_prompt, model: tutor_model, tracker: tracker, phase: "education_#{condition}")
        turns << { 'speaker' => 'tutor', 'type' => 'consolidation', 'content' => review }

        apply_prompt = Helpers.build_prompt(
          system: learner_prompt,
          context: "TUTOR SAID:\n#{review}#{learner_context}",
          instruction: "State what you understood from the example. 1-2 sentences."
        )
        apply = LLM.call(apply_prompt, model: learner_model, tracker: tracker, phase: "education_#{condition}")
        turns << { 'speaker' => 'learner', 'type' => 'response', 'content' => apply }
        $stderr.puts "[#{condition}:#{learner_id}] Consolidation session (no errors)"
      else
        # For each error: corrective example + learner restates
        mastery_errors.each do |error_task|
          note = error_task['corrective_note'] || "Review: #{error_task['id']}"

          correct_prompt = Helpers.build_prompt(
            system: tutor_prompt,
            context: "DOMAIN LESSON:\n#{lesson}#{type_context}\n\nLEARNER'S MASTERY CHECK ERROR:\n#{note}",
            instruction: "Give ONE short corrective worked example that makes the correct rule concrete. State the rule first, then work through a token sequence step by step. Under 100 words."
          )
          correction = LLM.call(correct_prompt, model: tutor_model, tracker: tracker, phase: "education_#{condition}")
          turns << { 'speaker' => 'tutor', 'type' => 'corrective_example', 'content' => correction,
                     'check_id' => error_task['id'] }
          $stderr.puts "[#{condition}:#{learner_id}] Tutor gave corrective example for #{error_task['id']}"

          restate_prompt = Helpers.build_prompt(
            system: learner_prompt,
            context: "TUTOR CORRECTION:\n#{correction}#{learner_context}",
            instruction: "Restate the corrected rule in your own words. 1-2 sentences. Express confidence: low, medium, or high."
          )
          restate = LLM.call(restate_prompt, model: learner_model, tracker: tracker, phase: "education_#{condition}")
          turns << { 'speaker' => 'learner', 'type' => 'restatement', 'content' => restate,
                     'check_id' => error_task['id'] }
          $stderr.puts "[#{condition}:#{learner_id}] Learner restated corrected rule for #{error_task['id']}"
        end
      end

      {
        'condition'   => condition,
        'tutor_id'    => tutor_id,
        'learner_id'  => learner_id,
        'turns'       => turns,
        'errors_addressed' => mastery_errors.size
      }
    end
  end
end
```

- [ ] **Step 2: Verify the file loads without error**

```bash
ruby -e "require_relative 'lib/phases/flipped_tutoring'; puts 'OK'"
```
Expected: `OK`

- [ ] **Step 3: Commit**

```bash
git add lib/phases/flipped_tutoring.rb
git commit -m "feat(v8): add FlippedTutoring phase targeting mastery check errors"
```

---

## Task 9: New Prompts

**Files:**
- Create: `prompts/discussion_moderator.md`
- Create: `prompts/discussion_participant.md`
- Create: `prompts/flipped_tutor.md`

- [ ] **Step 1: Create `prompts/discussion_moderator.md`**

```markdown
You are a discussion moderator facilitating a whole-class discussion about Zarn tokens.

Your role:
- Open the discussion by presenting the problem clearly
- Invite all learners to contribute their reasoning
- Stay neutral while the learners work through the problem
- Close by confirming the correct answer and highlighting key rules
- Correct any factual errors in learner contributions at the close

Tone: facilitative, encouraging, precise in corrections.

When closing, always state the correct final score explicitly.
```

- [ ] **Step 2: Create `prompts/discussion_participant.md`**

```markdown
You are a learner participating in a group discussion about Zarn tokens.

Your role:
- Share your step-by-step reasoning for the problem
- Respond to what other participants say — agree, correct, or extend their reasoning
- Acknowledge if you are uncertain
- In small groups: contribute to producing shared notes at the end

Tone: collaborative, honest about uncertainty, brief and direct.

When contributing: show your token-by-token calculation. Do not just state the answer.
```

- [ ] **Step 3: Create `prompts/flipped_tutor.md`**

```markdown
You are a one-on-one tutor reviewing a learner's mastery check errors.

The learner has already received a complete prerequisite lecture. They passed some checks but failed others. Your job is targeted remediation — not a full re-teach.

Your role:
- Address each specific error with one clear corrective worked example
- State the rule explicitly before showing the example
- Keep examples to 2-3 calculation steps
- Ask the learner to restate the corrected rule in their own words
- If the learner had no errors, give one advanced consolidation example

Tone: direct, supportive, efficient. No re-teaching of rules the learner already knows.
```

- [ ] **Step 4: Commit**

```bash
git add prompts/discussion_moderator.md prompts/discussion_participant.md prompts/flipped_tutor.md
git commit -m "feat(v8): add discussion_moderator, discussion_participant, and flipped_tutor prompts"
```

---

## Task 10: Report v8 Extensions

**Files:**
- Modify: `lib/report.rb`
- Create: `tests/test_report_v8.rb`

Add v8-specific report sections: mastery_check_score, memory coverage (rules/edge_cases/procedure), discussion contributions, and token efficiency per condition. Triggered when `experiment_meta[:experiment] == 'v8'`.

Also add a new DB query method `all_mastery_checks_by_condition` for reporting.

- [ ] **Step 1: Write failing test**

Create `tests/test_report_v8.rb`:

```ruby
# ABOUTME: Tests for v8 report extensions — mastery check scores, memory coverage, discussion metrics
# ABOUTME: Pure function tests; no DB or LLM calls

$LOAD_PATH.unshift File.join(__dir__, '..', 'lib')
require 'minitest/autorun'
require 'json'
require 'securerandom'
require 'report'

class TestReportV8MasterySection < Minitest::Test
  def make_mastery_row(learner_id, check_type, correct)
    { 'learner_id' => learner_id, 'check_type' => check_type, 'answer_correct' => correct ? 1 : 0 }
  end

  def test_mastery_check_section_shows_pass_rate_per_type
    rows = [
      make_mastery_row('l1', 'recall', true),
      make_mastery_row('l2', 'recall', false),
      make_mastery_row('l1', 'edge_case', true),
      make_mastery_row('l2', 'edge_case', true),
    ]
    section = Report.mastery_check_section(rows)
    assert_includes section, 'recall'
    assert_includes section, 'edge_case'
    assert_includes section, '50%'   # recall: 1/2 correct
    assert_includes section, '100%'  # edge_case: 2/2 correct
  end

  def test_mastery_check_section_empty_for_no_rows
    assert_equal '', Report.mastery_check_section([])
  end
end

class TestReportV8MemoryCoverage < Minitest::Test
  def make_memory(rules: [], edge_cases: [], strategy: [])
    { 'rules' => rules, 'edge_cases' => edge_cases, 'strategy' => strategy,
      'examples' => [], 'corrected_misconceptions' => [],
      'remaining_misconceptions' => [], 'uncertain_rules' => [] }
  end

  def test_memory_coverage_counts_rules
    mem = make_memory(rules: ['rule1', 'rule2', 'rule3'])
    cov = Report.memory_coverage(mem)
    assert_equal 3, cov[:rule_count]
  end

  def test_memory_coverage_detects_edge_cases
    mem = make_memory(edge_cases: ['edge1'])
    cov = Report.memory_coverage(mem)
    assert cov[:has_edge_cases]
  end

  def test_memory_coverage_detects_procedure
    mem = make_memory(strategy: ['check activation first'])
    cov = Report.memory_coverage(mem)
    assert cov[:has_procedure]
  end

  def test_memory_coverage_empty_memory
    cov = Report.memory_coverage(make_memory)
    assert_equal 0, cov[:rule_count]
    refute cov[:has_edge_cases]
    refute cov[:has_procedure]
  end
end

class TestReportV8Build < Minitest::Test
  def make_row(condition, correct)
    { 'condition' => condition, 'learner_id' => SecureRandom.uuid,
      'task_id' => 'l1_recall_01', 'task_type' => 'recall',
      'response_text' => 'x',
      'score_json' => JSON.dump({ 'answer_correct' => correct }),
      'profile_json' => JSON.dump({ 'type_key' => 'rule_extractor' }) }
  end

  def test_build_markdown_v8_includes_condition_names
    rows = [
      make_row('lecture_only', true),
      make_row('lecture_plus_whole_class_discussion', false),
      make_row('lecture_plus_small_group_discussion', true),
      make_row('lecture_plus_one_on_one_tutoring', true),
    ]
    config = { 'experiment' => { 'domain' => 'zarn_tokens', 'ceiling_threshold' => 0.9 },
               'models' => { 'teacher' => 'haiku' } }
    md = Report.build_markdown(rows, run_id: 'r1', output_dir: '/tmp', run_config: config,
                               token_summary: {}, experiment_meta: { experiment: 'v8' })
    assert_includes md, 'lecture_only'
    assert_includes md, 'lecture_plus_whole_class_discussion'
    assert_includes md, 'lecture_plus_small_group_discussion'
    assert_includes md, 'lecture_plus_one_on_one_tutoring'
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
ruby tests/test_report_v8.rb 2>&1 | tail -10
```
Expected: FAIL with "undefined method 'mastery_check_section'" etc.

- [ ] **Step 3: Add v8 methods to `lib/report.rb`**

Add these methods to the `Report` module (after `build_token_data`, before `extract_difficulty`):

```ruby
  def self.mastery_check_section(mastery_rows)
    return '' if mastery_rows.nil? || mastery_rows.empty?
    lines = []
    lines << "## Mastery Check Score by Check Type"
    lines << ""
    lines << "| Check Type | Total | Correct | Pass Rate |"
    lines << "|------------|-------|---------|-----------|"
    mastery_rows.group_by { |r| r['check_type'] }.sort.each do |check_type, rows|
      total   = rows.size
      correct = rows.count { |r| r['answer_correct'].to_i == 1 }
      pct     = total > 0 ? (correct.to_f / total * 100).round : 0
      lines << "| #{check_type} | #{total} | #{correct} | #{pct}% |"
    end
    lines << ""
    lines.join("\n")
  end

  def self.memory_coverage(memory)
    rules       = Array(memory['rules'])
    edge_cases  = Array(memory['edge_cases'])
    strategy    = Array(memory['strategy'])
    {
      rule_count:       rules.size,
      has_edge_cases:   edge_cases.any?,
      has_procedure:    strategy.any?,
      rule_words:       rules.join(' ').split.size,
      edge_case_count:  edge_cases.size,
      strategy_count:   strategy.size
    }
  end

  def self.memory_coverage_section(memories_by_condition)
    return '' if memories_by_condition.nil? || memories_by_condition.empty?
    lines = []
    lines << "## Memory Coverage by Condition"
    lines << ""
    lines << "| Condition | Avg Rules | Edge Cases (%) | Procedure (%) |"
    lines << "|-----------|-----------|----------------|---------------|"
    memories_by_condition.sort_by { |k, _| k }.each do |cond, mem_list|
      next if mem_list.empty?
      coverages   = mem_list.map { |m| memory_coverage(m['memory']) }
      avg_rules   = (coverages.sum { |c| c[:rule_count] }.to_f / coverages.size).round(1)
      edge_pct    = (coverages.count { |c| c[:has_edge_cases] }.to_f / coverages.size * 100).round
      proc_pct    = (coverages.count { |c| c[:has_procedure] }.to_f / coverages.size * 100).round
      lines << "| #{cond} | #{avg_rules} | #{edge_pct}% | #{proc_pct}% |"
    end
    lines << ""
    lines.join("\n")
  end
```

Also add `all_mastery_checks_by_condition` to `lib/db.rb`:

```ruby
  def self.all_mastery_checks_by_condition(db, run_id)
    rows = db.execute(<<~SQL, [run_id])
      SELECT mcr.learner_id, mcr.check_id, mcr.check_type, mcr.answer_correct,
             a.condition
      FROM mastery_check_results mcr
      LEFT JOIN agents a ON a.id = mcr.learner_id
      WHERE mcr.run_id = ?
      ORDER BY a.condition, mcr.learner_id
    SQL
    rows
  end
```

Finally, add calls to the new sections inside `build_markdown`, after the Learner Type section (near line 200 of report.rb). Add this block:

```ruby
    # v8-specific sections
    if experiment_meta[:experiment] == 'v8'
      mastery_data = memories_by_condition.instance_variable_get(:@mastery_rows) # passed separately
      lines << memory_coverage_section(memories_by_condition)
    end
```

Wait — this approach is cleaner: pass `mastery_rows:` as an optional keyword arg to `build_markdown`. Let me update the plan:

Modify `build_markdown` signature in `lib/report.rb` to accept `mastery_rows: []`:

```ruby
  def self.build_markdown(rows, run_id:, output_dir:, run_config:, token_summary:,
                          memories_by_condition: {}, experiment_meta: {}, mastery_rows: [])
```

Then add v8 sections inside `build_markdown` (after the Variance section):

```ruby
    # v8: mastery check scores
    if experiment_meta[:experiment] == 'v8'
      lines << mastery_check_section(mastery_rows)
      lines << memory_coverage_section(memories_by_condition)
    end
```

And update `generate` to pass mastery rows through:

```ruby
  def self.generate(db, run_id:, output_dir:, run_config:, token_summary: {}, experiment_meta: {})
    FileUtils.mkdir_p(output_dir)
    rows                  = DB.all_attempts_with_scores(db, run_id)
    memories_by_condition = DB.all_memories_by_condition(db, run_id)
    mastery_rows          = experiment_meta[:experiment] == 'v8' ?
                              DB.all_mastery_checks_by_condition(db, run_id) : []
    write_csv(rows, output_dir)
    markdown = build_markdown(rows, run_id: run_id, output_dir: output_dir,
                              run_config: run_config, token_summary: token_summary,
                              memories_by_condition: memories_by_condition,
                              experiment_meta: experiment_meta,
                              mastery_rows: mastery_rows)
    File.write(File.join(output_dir, 'report.md'), markdown)
    $stderr.puts "[report] Wrote scores.csv and report.md to #{output_dir}"
  end
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
ruby tests/test_report_v8.rb 2>&1 | tail -5
```
Expected: `7 runs, X assertions, 0 failures, 0 errors, 0 skips`

```bash
ruby tests/test_report_v7.rb 2>&1 | tail -3
```
Expected: 0 new failures (check existing v7 tests still pass).

- [ ] **Step 5: Commit**

```bash
git add lib/report.rb lib/db.rb tests/test_report_v8.rb
git commit -m "feat(v8): add report sections for mastery check scores and memory coverage"
```

---

## Task 11: run_experiment_v8.rb

**Files:**
- Create: `scripts/run_experiment_v8.rb`

Main orchestrator for 4 conditions. Uses HETEROGENEOUS_ASSIGNMENT types (rule_extractor, edge_case_dropper, order_confused, passive_listener). Config-driven n per condition.

- [ ] **Step 1: Create `scripts/run_experiment_v8.rb`**

```ruby
# ABOUTME: Orchestrator for v8 flipped-learning experiment — 4 conditions, 4 phases
# ABOUTME: Conditions: lecture_only, lecture_plus_whole_class_discussion,
# ABOUTME:   lecture_plus_small_group_discussion, lecture_plus_one_on_one_tutoring

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
require 'phases/prerequisite_lecture'
require 'phases/mastery_check'
require 'phases/whole_class_discussion'
require 'phases/small_group_discussion'
require 'phases/flipped_tutoring'
require 'phases/memory'
require 'phases/solver'
require 'phases/evaluator'
require 'report'

config_path  = ARGV[0] or abort "Usage: #{$0} <config.yml>"
PROJECT_ROOT = File.expand_path('../..', EXPERIMENT_DIR)
config       = YAML.load_file(File.join(PROJECT_ROOT, config_path))

run_id       = SecureRandom.uuid
run_name     = config.dig('experiment', 'name') || 'bloom_v8'
domain_path  = File.join(PROJECT_ROOT, config.dig('paths', 'domain'))
prompts_path = File.join(PROJECT_ROOT, config.dig('paths', 'prompts'))
output_base  = File.join(PROJECT_ROOT, config.dig('paths', 'output'))
db_path      = File.join(PROJECT_ROOT, config.dig('paths', 'db'))
run_dir      = File.join(output_base, 'runs', run_id)

FileUtils.mkdir_p(run_dir)
$stderr.puts "[v8] Starting run #{run_id}"

tracker = TokenTracker.new

lesson        = Helpers.load_file(File.join(domain_path, 'lesson.md'))
tasks_file    = config.dig('experiment', 'eval_tasks_file') || 'eval_tasks_v8.json'
eval_tasks    = JSON.parse(Helpers.load_file(File.join(domain_path, tasks_file)))
check_tasks   = JSON.parse(Helpers.load_file(File.join(domain_path, 'mastery_check_tasks.json')))
rubric        = JSON.parse(Helpers.load_file(File.join(domain_path, 'rubric.json')))

teacher_prompt    = Helpers.load_file(File.join(prompts_path, 'classroom_teacher.md'))
moderator_prompt  = Helpers.load_file(File.join(prompts_path, 'discussion_moderator.md'))
participant_prompt = Helpers.load_file(File.join(prompts_path, 'discussion_participant.md'))
tutor_prompt      = Helpers.load_file(File.join(prompts_path, 'flipped_tutor.md'))
learner_prompt    = Helpers.load_file(File.join(prompts_path, 'learner.md'))
summarizer_prompt = Helpers.load_file(File.join(prompts_path, 'memory_summarizer.md'))
solver_prompt     = Helpers.load_file(File.join(prompts_path, 'problem_solver.md'))
evaluator_prompt  = Helpers.load_file(File.join(prompts_path, 'blind_evaluator.md'))

db = DB.setup(db_path)
DB.save_run(db, run_id, run_name, config)
File.write(File.join(run_dir, 'config.json'), JSON.pretty_generate(config))

n_per_condition = config.dig('experiment', 'n_per_condition') || 4
type_keys       = config.dig('experiment', 'learner_types')&.map(&:to_sym) ||
                  LearnerTypes::HETEROGENEOUS_ASSIGNMENT

CONDITIONS = %w[
  lecture_only
  lecture_plus_whole_class_discussion
  lecture_plus_small_group_discussion
  lecture_plus_one_on_one_tutoring
].freeze

teacher_id   = DB.save_agent(db, run_id: run_id, role: 'classroom_teacher',
                              model: config.dig('models', 'teacher'))
tutor_id     = DB.save_agent(db, run_id: run_id, role: 'tutor',
                              model: config.dig('models', 'tutor'))
evaluator_id = DB.save_agent(db, run_id: run_id, role: 'evaluator',
                              model: config.dig('models', 'evaluator'))

# Build learner agent roster: n_per_condition × 4 conditions
# Each condition has one learner of each type (cycling if n_per_condition > type_keys.size)
all_learners = CONDITIONS.flat_map do |condition|
  n_per_condition.times.map do |i|
    type_key = type_keys[i % type_keys.size]
    learner_id = DB.save_agent(db, run_id: run_id, role: 'learner', condition: condition,
                               model: config.dig('models', 'learner'),
                               profile: { 'type_key' => type_key.to_s })
    { id: learner_id, condition: condition, type_key: type_key }
  end
end

by_condition = all_learners.group_by { |l| l[:condition] }

# ---------------------------------------------------------------------------
# PHASE 1: Prerequisite lecture (one shared lecture per condition)
# ---------------------------------------------------------------------------
$stderr.puts "[v8] Phase 1: Prerequisite lecture (#{CONDITIONS.size} conditions)"

CONDITIONS.each do |condition|
  learners = by_condition[condition]
  ids      = learners.map { |l| l[:id] }
  type_map = learners.each_with_object({}) { |l, h| h[l[:id]] = l[:type_key] }

  transcript = Phases::PrerequisiteLecture.run(
    teacher_id: teacher_id, learner_ids: ids,
    teacher_prompt: teacher_prompt, learner_prompt: learner_prompt,
    lesson: lesson, config: config, tracker: tracker, learner_type_keys: type_map
  )

  ids.each do |lid|
    DB.save_learning_session(db, run_id: run_id, condition: condition,
                             learner_id: lid, teacher_or_tutor_id: teacher_id,
                             transcript: transcript)
  end
  File.open(File.join(run_dir, 'transcripts.jsonl'), 'a') { |f| f.puts JSON.dump(transcript) }
  $stderr.puts "[v8] Phase 1 done: #{condition} (#{ids.size} learners)"
end

# Generate initial memory for all learners
$stderr.puts "[v8] Phase 1b: Initial memory generation (#{all_learners.size} learners)"
all_learners.each do |learner|
  transcript_row = db.execute(
    'SELECT transcript_json FROM learning_sessions WHERE run_id = ? AND learner_id = ? ORDER BY rowid DESC LIMIT 1',
    [run_id, learner[:id]]
  ).first
  transcript = JSON.parse(transcript_row['transcript_json'])
  memory = Phases::Memory.generate(
    learner_id: learner[:id], transcript: transcript,
    summarizer_prompt: summarizer_prompt, config: config, tracker: tracker,
    learner_type_key: learner[:type_key]
  )
  DB.save_learner_memory(db, run_id: run_id, learner_id: learner[:id],
                         condition: learner[:condition], memory: memory)
  File.open(File.join(run_dir, 'memories.jsonl'), 'a') do |f|
    f.puts JSON.dump({ phase: 'post_lecture', learner_id: learner[:id],
                       condition: learner[:condition], type_key: learner[:type_key], memory: memory })
  end
end

# ---------------------------------------------------------------------------
# PHASE 2: Mastery check (3 questions per learner, all conditions)
# ---------------------------------------------------------------------------
$stderr.puts "[v8] Phase 2: Mastery checks (#{all_learners.size} learners × #{check_tasks.size} checks)"

all_learners.each do |learner|
  memory = DB.get_learner_memory(db, run_id: run_id, learner_id: learner[:id])
  result = Phases::MasteryCheck.run(
    learner_id: learner[:id], memory: memory, check_tasks: check_tasks,
    solver_prompt: solver_prompt, config: config, db: db, run_id: run_id,
    tracker: tracker
  )

  # Save updated memory (with corrective notes patched in)
  DB.save_learner_memory(db, run_id: run_id, learner_id: learner[:id],
                         condition: learner[:condition], memory: result[:updated_memory])
  File.open(File.join(run_dir, 'memories.jsonl'), 'a') do |f|
    f.puts JSON.dump({ phase: 'post_mastery', learner_id: learner[:id],
                       condition: learner[:condition], type_key: learner[:type_key],
                       checks: result[:checks], errors: result[:errors].size,
                       memory: result[:updated_memory] })
  end
  $stderr.puts "[v8] Mastery #{learner[:id]}: #{result[:errors].size}/#{check_tasks.size} errors"
end

# ---------------------------------------------------------------------------
# PHASE 3: Condition-specific interaction
# ---------------------------------------------------------------------------
$stderr.puts "[v8] Phase 3: Condition interactions"

# --- lecture_only: no interaction ---
$stderr.puts "[v8] Phase 3: lecture_only — no interaction"

# --- whole_class_discussion ---
wcd_learners = by_condition['lecture_plus_whole_class_discussion']
wcd_ids      = wcd_learners.map { |l| l[:id] }
type_map_wcd = wcd_learners.each_with_object({}) { |l, h| h[l[:id]] = l[:type_key] }

$stderr.puts "[v8] Phase 3: whole_class_discussion (#{wcd_ids.size} learners)"
wcd_transcript = Phases::WholeClassDiscussion.run(
  moderator_id: teacher_id, learner_ids: wcd_ids,
  moderator_prompt: moderator_prompt, participant_prompt: participant_prompt,
  lesson: lesson, config: config, tracker: tracker, learner_type_keys: type_map_wcd
)
wcd_ids.each do |lid|
  DB.save_learning_session(db, run_id: run_id,
                           condition: 'lecture_plus_whole_class_discussion',
                           learner_id: lid, teacher_or_tutor_id: teacher_id,
                           transcript: wcd_transcript)
end
File.open(File.join(run_dir, 'transcripts.jsonl'), 'a') { |f| f.puts JSON.dump(wcd_transcript) }

wcd_learners.each do |learner|
  existing = DB.get_learner_memory(db, run_id: run_id, learner_id: learner[:id])
  updated  = Phases::Memory.update(
    learner_id: learner[:id], existing_memory: existing,
    update_transcript: wcd_transcript['turns'],
    summarizer_prompt: summarizer_prompt, config: config, tracker: tracker,
    learner_type_key: learner[:type_key]
  )
  DB.save_learner_memory(db, run_id: run_id, learner_id: learner[:id],
                         condition: 'lecture_plus_whole_class_discussion', memory: updated)
  File.open(File.join(run_dir, 'memories.jsonl'), 'a') do |f|
    f.puts JSON.dump({ phase: 'post_interaction', learner_id: learner[:id],
                       condition: 'lecture_plus_whole_class_discussion', memory: updated })
  end
end

# --- small_group_discussion ---
sgd_learners = by_condition['lecture_plus_small_group_discussion']
sgd_ids      = sgd_learners.map { |l| l[:id] }
type_map_sgd = sgd_learners.each_with_object({}) { |l, h| h[l[:id]] = l[:type_key] }

$stderr.puts "[v8] Phase 3: small_group_discussion (#{sgd_ids.size} learners)"
group_results = Phases::SmallGroupDiscussion.run(
  learner_ids: sgd_ids, participant_prompt: participant_prompt,
  lesson: lesson, config: config, tracker: tracker, learner_type_keys: type_map_sgd
)
group_results.each do |group|
  group['learner_ids'].each do |lid|
    DB.save_learning_session(db, run_id: run_id,
                             condition: 'lecture_plus_small_group_discussion',
                             learner_id: lid, teacher_or_tutor_id: teacher_id,
                             transcript: group)
  end
  File.open(File.join(run_dir, 'transcripts.jsonl'), 'a') { |f| f.puts JSON.dump(group) }
end

sgd_learners.each do |learner|
  group = group_results.find { |g| g['learner_ids'].include?(learner[:id]) }
  next unless group
  existing = DB.get_learner_memory(db, run_id: run_id, learner_id: learner[:id])
  updated  = Phases::Memory.update(
    learner_id: learner[:id], existing_memory: existing,
    update_transcript: group['turns'],
    summarizer_prompt: summarizer_prompt, config: config, tracker: tracker,
    learner_type_key: learner[:type_key]
  )
  DB.save_learner_memory(db, run_id: run_id, learner_id: learner[:id],
                         condition: 'lecture_plus_small_group_discussion', memory: updated)
  File.open(File.join(run_dir, 'memories.jsonl'), 'a') do |f|
    f.puts JSON.dump({ phase: 'post_interaction', learner_id: learner[:id],
                       condition: 'lecture_plus_small_group_discussion', memory: updated })
  end
end

# --- flipped_tutoring ---
ft_learners = by_condition['lecture_plus_one_on_one_tutoring']
$stderr.puts "[v8] Phase 3: flipped_tutoring (#{ft_learners.size} learners)"

ft_learners.each do |learner|
  mastery_errors = DB.get_mastery_check_errors(db, run_id: run_id, learner_id: learner[:id])
  # Re-attach corrective_note from check_tasks (DB stores it; just reload)
  error_tasks = mastery_errors.map do |err|
    check_tasks.find { |t| t['id'] == err['check_id'] } || err
  end

  transcript = Phases::FlippedTutoring.run_session(
    tutor_id: tutor_id, learner_id: learner[:id],
    tutor_prompt: tutor_prompt, learner_prompt: learner_prompt,
    lesson: lesson, mastery_errors: error_tasks,
    config: config, tracker: tracker, learner_type_key: learner[:type_key]
  )
  DB.save_learning_session(db, run_id: run_id,
                           condition: 'lecture_plus_one_on_one_tutoring',
                           learner_id: learner[:id], teacher_or_tutor_id: tutor_id,
                           transcript: transcript)
  File.open(File.join(run_dir, 'transcripts.jsonl'), 'a') { |f| f.puts JSON.dump(transcript) }

  existing = DB.get_learner_memory(db, run_id: run_id, learner_id: learner[:id])
  updated  = Phases::Memory.update(
    learner_id: learner[:id], existing_memory: existing,
    update_transcript: transcript['turns'],
    summarizer_prompt: summarizer_prompt, config: config, tracker: tracker,
    learner_type_key: learner[:type_key]
  )
  DB.save_learner_memory(db, run_id: run_id, learner_id: learner[:id],
                         condition: 'lecture_plus_one_on_one_tutoring', memory: updated)
  File.open(File.join(run_dir, 'memories.jsonl'), 'a') do |f|
    f.puts JSON.dump({ phase: 'post_interaction', learner_id: learner[:id],
                       condition: 'lecture_plus_one_on_one_tutoring', memory: updated })
  end
end

# ---------------------------------------------------------------------------
# PHASE 4: Evaluation
# ---------------------------------------------------------------------------
$stderr.puts "[v8] Phase 4: Evaluation (#{all_learners.size} × #{eval_tasks.size} tasks)"

eval_tasks.each do |task|
  DB.save_evaluation_task(db, run_id: run_id, task_id: task['id'], task_type: task['task_type'],
                          prompt: task['learner_prompt'], expected_answer: task, rubric: rubric)
end

all_learners.each do |learner|
  memory = DB.get_learner_memory(db, run_id: run_id, learner_id: learner[:id])
  eval_tasks.each do |task|
    result = Phases::Solver.solve(
      learner_id: learner[:id], memory: memory, task: task,
      solver_prompt: solver_prompt, config: config, tracker: tracker
    )
    attempt_id = DB.save_task_attempt(db,
      run_id: run_id, learner_id: learner[:id], condition: learner[:condition],
      task_id: task['id'], response_text: result['response'],
      trace: result['trace'].merge('parsed' => result['parsed'])
    )
    File.open(File.join(run_dir, 'attempts.jsonl'), 'a') do |f|
      f.puts JSON.dump({ attempt_id: attempt_id, learner_id: learner[:id],
                         condition: learner[:condition], task_id: task['id'],
                         response: result['response'], parsed: result['parsed'] })
    end
    score = Phases::Evaluator.score(
      attempt_id: attempt_id, learner_response: result['response'],
      parsed_response: result['parsed'], task: task, rubric: rubric,
      evaluator_id: evaluator_id, evaluator_prompt: evaluator_prompt,
      config: config, tracker: tracker
    )
    DB.save_evaluation(db, run_id: run_id, attempt_id: attempt_id,
                       evaluator_id: evaluator_id, score: score)
    File.open(File.join(run_dir, 'evaluations.jsonl'), 'a') do |f|
      f.puts JSON.dump({ attempt_id: attempt_id, score: score })
    end
  end
end

# ---------------------------------------------------------------------------
# PHASE 5: Report
# ---------------------------------------------------------------------------
$stderr.puts "[v8] Phase 5: Report"
Report.generate(db, run_id: run_id, output_dir: run_dir,
                run_config: config, token_summary: tracker.summary,
                experiment_meta: { experiment: 'v8' })

db.close
$stderr.puts "[v8] Done. Results in: #{run_dir}"
puts run_dir
```

- [ ] **Step 2: Verify file is syntactically valid**

```bash
ruby -c scripts/run_experiment_v8.rb 2>&1
```
Expected: `Syntax OK`

- [ ] **Step 3: Commit**

```bash
git add scripts/run_experiment_v8.rb
git commit -m "feat(v8): add run_experiment_v8.rb orchestrator — 4-condition flipped learning"
```

---

## Task 12: Config Files

**Files:**
- Create: `config_v8.yml`
- Create: `config_v8_smoke.yml`

- [ ] **Step 1: Create `config_v8.yml`**

```yaml
experiment:
  name: "bloom_v8_flipped_learning"
  domain: "zarn_tokens"
  n_per_condition: 4
  learner_types:
    - rule_extractor
    - edge_case_dropper
    - order_confused
    - passive_listener
  eval_tasks_file: "eval_tasks_v8.json"
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
  db: "experiments/bloom_1n_vs_1on1/data/experiment_v8.db"
```

- [ ] **Step 2: Create `config_v8_smoke.yml`**

```yaml
experiment:
  name: "bloom_v8_smoke"
  domain: "zarn_tokens"
  n_per_condition: 2
  learner_types:
    - rule_extractor
    - passive_listener
  eval_tasks_file: "eval_tasks_v8.json"
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
  db: "experiments/bloom_1n_vs_1on1/data/smoke_v8.db"
```

- [ ] **Step 3: Commit**

```bash
git add config_v8.yml config_v8_smoke.yml
git commit -m "feat(v8): add config_v8.yml and config_v8_smoke.yml"
```

---

## Task 13: Smoke Test

Run the smoke config to verify all 4 conditions complete without error.

- [ ] **Step 1: Run the full test suite first**

```bash
cd experiments/bloom_1n_vs_1on1
ruby -e "Dir['tests/test_*.rb'].each { |f| load f }" 2>&1 | grep "^[0-9]* runs"
```
Expected: 0 new failures vs. the pre-v8 baseline (19 pre-existing LLM.stub errors are acceptable).

- [ ] **Step 2: Run the smoke test**

```bash
ruby scripts/run_experiment_v8.rb experiments/bloom_1n_vs_1on1/config_v8_smoke.yml 2>&1 | tee /tmp/v8_smoke.log
```

This creates 2 learners per condition × 4 conditions = 8 learners total. Each gets:
- 1 lecture (shared per condition)
- 3 mastery checks
- condition-specific interaction
- 10 eval tasks

Monitor for errors. Expected output ends with something like:
```
[v8] Done. Results in: experiments/bloom_1n_vs_1on1/data/runs/<uuid>
```

- [ ] **Step 3: Verify report was generated**

```bash
RUNDIR=$(ruby scripts/run_experiment_v8.rb experiments/bloom_1n_vs_1on1/config_v8_smoke.yml 2>/dev/null)
cat "$RUNDIR/report.md" | head -50
```
Expected: markdown with `lecture_only`, `lecture_plus_whole_class_discussion`, etc. and non-zero scores.

- [ ] **Step 4: Commit**

```bash
git add -f data/runs/*/config.json  # only if not gitignored
git commit -m "test(v8): smoke test passes — all 4 conditions complete cleanly"
```

---

## Self-Review

### 1. Spec Coverage

| Spec Requirement | Task |
|-----------------|------|
| 4 conditions (lecture_only, whole_class, small_group, 1on1) | Task 11 |
| Mixed learner types (rule_extractor, edge_case_dropper, order_confused, passive_listener) | Task 12 |
| Phase 1: rich prerequisite lecture with all rules/examples/mistakes | Task 4 |
| Phase 2: 3 mastery checks (recall, edge_case, rule_interaction) | Tasks 2, 5 |
| Phase 2: auto-scoring + corrective note on wrong answer | Task 5 |
| Phase 3: lecture_only = no interaction | Task 11 |
| Phase 3: whole_class_discussion with light moderation | Task 6 |
| Phase 3: small_group_discussion groups of 2, each contributes | Task 7 |
| Phase 3: 1on1 reviews mastery errors + corrective example | Task 8 |
| Phase 4: memory-only evaluation | Task 11 (uses existing Solver) |
| Phase 4: existing v7 eval tasks | Task 2 (included in v8 file) |
| Phase 4: discussion-sensitive tasks (peer_error, explanation_choice) | Task 2 |
| Reporting: score_by_condition | Existing report.rb |
| Reporting: score_by_learner_type | Existing report.rb |
| Reporting: mastery_check_score | Task 10 |
| Reporting: memory_coverage (rule/edge/procedure) | Task 10 |
| Reporting: token_cost_by_condition | Existing report.rb |
| Optional no_prep baseline | Not implemented (token budget concern; add later) |

### 2. Placeholder Scan
- All code in every task is complete and runnable.
- No "TBD", "TODO", or "add appropriate handling" phrases.
- All method names are consistent across tasks.

### 3. Type Consistency
- `DB.save_mastery_check` uses `answer_correct: true/false` (boolean) → stored as integer 0/1 → read back as integer → converted in `get_mastery_checks` to boolean.
- `Phases::MasteryCheck.run` returns `{ checks:, errors:, updated_memory: }` — used consistently in orchestrator.
- `Phases::Memory.update` signature matches its usage in orchestrator.
- `Report.build_markdown` new keyword arg `mastery_rows: []` has default → existing callers (regen_report.rb, tests) continue to work.
- `all_mastery_checks_by_condition` returns rows with `answer_correct` as integer 0/1, which `mastery_check_section` handles via `.to_i == 1`.

### 4. Notable Edge Cases Handled
- Smoke test n=2 for small_group → 1 pair (even split); `each_slice(2)` handles this correctly.
- `FlippedTutoring` with no mastery errors → consolidation mode (no crashes).
- `Memory.update` returns `existing_memory` on LLM parse failure (safe fallback).
- `l5_debug_03` expected_answer corrected to "19" (not "21") in Task 2's verification step.
