# v4 Longer Tutoring + Task Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the two design problems identified in v3 — tutoring sessions are too short to show advantage over classroom, and L5/L6 tasks have validity issues — while increasing n to produce statistically meaningful condition comparisons.

**Architecture:** Tutoring extends from 2 exchanges (4 turns) to 4 exchanges (8 turns) by adding a feedback turn and a second diagnostic; eval_tasks_v4.json replaces L5 (unsolvable without domain rules) and simplifies L6 (was too hard); n increases to 6/6/4. No new modules needed.

**Tech Stack:** Ruby stdlib, sqlite3 — identical to v3, no new dependencies.

---

## Why these changes

### Tutoring was too short
2 exchanges = opener → learner response → diagnostic Q → learner answer.  
The tutor identifies a misconception in exchange 2 but has no chance to correct it. The learner exits with the wrong understanding. Bloom's tutoring advantage comes precisely from the **feedback-correction loop** — the tutor says "that's wrong, here's why", the learner adjusts, and the tutor tests again. Without this loop, 1on1 tutoring is just a short lecture.

Adding exchanges 3 and 4:
- Exchange 3: Tutor gives targeted feedback → Learner reflects on what was wrong
- Exchange 4: Tutor asks a harder Q testing a different rule → Learner applies corrected understanding

### L5 was solvable without domain knowledge
"Claim: if a sequence has a non-final Green, every Blue is active. True or false?"  
A model can answer "false" by pure logical reasoning: "a Blue before any Green obviously can't have Green to its left." This tests logical refutation, not Zarn Token knowledge. No_education correctly answered this at 100%.

New L5: A debugging task for `[Red, Green, Blue, Green]` where the student's mistake involves misidentifying which token Red doubles. Requires knowing: Red doubles the IMMEDIATELY adjacent token (not any token to its right), and Green at last = inactive.

### L6 sequence was too complex
`[Yellow, Orange, Blue, Green]` required simultaneously applying the new Orange rule + Blue activation (needs Green to left) + Green end rule. Everyone scored 0%. Simplifying to `[Yellow, Orange, Green]` removes the Blue dependency while still testing the Orange rule + Green end rule.

---

## File Map

```
CREATED:
  experiments/bloom_1n_vs_1on1/domains/zarn_tokens/eval_tasks_v4.json

MODIFIED:
  experiments/bloom_1n_vs_1on1/config.yml
  experiments/bloom_1n_vs_1on1/lib/phases/tutoring.rb
  experiments/bloom_1n_vs_1on1/README.md
```

---

## Task 1: eval_tasks_v4.json

**Files:**
- Create: `experiments/bloom_1n_vs_1on1/domains/zarn_tokens/eval_tasks_v4.json`

Tasks L1–L4 are identical to v3 (already working well as memory-only tests). Only L5 and L6 change.

**L5 math verification:**  
`[Red, Green, Blue, Green]` with student answer "Score = 0 + 2 + 10 + 2 = 14":
- Red(pos1): modifier=0, doubles Green(pos2)
- Green(pos2): active=2, doubled by Red → 4 (student missed the doubling: wrote 2)
- Blue(pos3): Green to its left → active=5 (student incorrectly doubled this to 10, thinking Red applied here)
- Green(pos4): last position → inactive=0 (student counted this as 2)
- Correct score = 0+4+5+0 = **9**

**L6 math verification:**  
`[Yellow, Orange, Green]`:
- Yellow(pos1): always active → 7
- Orange(pos2): Yellow immediately to left → active=4
- Green(pos3): last position → inactive=0
- Score = 7+4+0 = **11**

- [ ] **Step 1: Create eval_tasks_v4.json**

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
    "learner_prompt": "Calculate the final score for this Zarn token sequence: [Blue, Green]\n\nUse only your memory of the rules. Do not assume rules you were not taught.\n\nRespond in JSON only:\n{\"answer\": \"<score>\", \"active_tokens\": [], \"mistakes_found\": [], \"reason\": \"<under 40 words>\"}",
    "hidden_rules": "Red=modifier(0pts,doubles next). Blue=active(5pts) only if Green to left. Green=inactive if last. Yellow=always active(7pts). Inactive tokens stay 0 even when doubled.",
    "expected_answer": "0",
    "expected_active_tokens": [],
    "expected_mistakes": [],
    "acceptable_aliases": {"0": ["zero", "0 points", "score: 0", "score is 0"]}
  },
  {
    "id": "l2_edge_case_02",
    "difficulty": "L2",
    "task_type": "edge_case",
    "learner_prompt": "Calculate the final score for this Zarn token sequence: [Red, Blue, Yellow]\n\nUse only your memory of the rules. Do not assume rules you were not taught.\n\nRespond in JSON only:\n{\"answer\": \"<score>\", \"active_tokens\": [\"list active token names\"], \"mistakes_found\": [], \"reason\": \"<under 40 words>\"}",
    "hidden_rules": "Red=modifier(0pts,doubles next). Blue=active(5pts) only if Green to left. Green=inactive if last. Yellow=always active(7pts). Inactive tokens stay 0 even when doubled.",
    "expected_answer": "7",
    "expected_active_tokens": ["Yellow"],
    "expected_mistakes": [],
    "acceptable_aliases": {"7": ["7 points", "score: 7", "score is 7"]}
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
    "learner_prompt": "A student solved this Zarn sequence: [Green, Red, Blue, Yellow, Green]\nThey wrote: \"Score = 2 + 10 + 7 + 2 = 21\"\n\nFind ALL mistakes and give the correct score. Use only your memory of the rules.\n\nRespond in JSON only:\n{\"answer\": \"<correct score>\", \"active_tokens\": [\"list actually active token names\"], \"mistakes_found\": [\"describe each mistake\"], \"reason\": \"<under 40 words>\"}",
    "hidden_rules": "Red=modifier(0pts,doubles next). Blue=active(5pts) only if Green to left. Green=inactive if last. Yellow=always active(7pts). Inactive tokens stay 0 even when doubled.",
    "expected_answer": "19",
    "expected_active_tokens": ["Green", "Blue", "Yellow"],
    "expected_mistakes": ["Green at last position is inactive"],
    "acceptable_aliases": {"19": ["19 points", "score: 19", "score is 19"]}
  },
  {
    "id": "l4_debug_02",
    "difficulty": "L4",
    "task_type": "debugging",
    "learner_prompt": "A student solved this Zarn sequence: [Blue, Red, Green]\nThey wrote: \"Score = 0 + 0 + 4 = 4, because Red doubles Green to 4\"\n\nFind ALL mistakes and give the correct score. Use only your memory of the rules.\n\nRespond in JSON only:\n{\"answer\": \"<correct score>\", \"active_tokens\": [], \"mistakes_found\": [\"describe each mistake\"], \"reason\": \"<under 40 words>\"}",
    "hidden_rules": "Red=modifier(0pts,doubles next). Blue=active(5pts) only if Green to left. Green=inactive if last. Yellow=always active(7pts). Inactive tokens stay 0 even when doubled.",
    "expected_answer": "0",
    "expected_active_tokens": [],
    "expected_mistakes": ["Green at last position is inactive", "inactive tokens cannot be activated by Red"],
    "acceptable_aliases": {"0": ["zero", "0 points", "score: 0"]}
  },
  {
    "id": "l5_debug_03",
    "difficulty": "L5",
    "task_type": "debugging",
    "learner_prompt": "A student solved this Zarn sequence: [Red, Green, Blue, Green]\nThey wrote: \"Score = 0 + 2 + 10 + 2 = 14\"\n\nFind ALL mistakes and give the correct score. Use only your memory of the rules.\n\nRespond in JSON only:\n{\"answer\": \"<correct score>\", \"active_tokens\": [\"list actually active token names\"], \"mistakes_found\": [\"describe each mistake\"], \"reason\": \"<under 40 words>\"}",
    "hidden_rules": "Red=modifier(0pts,doubles next immediately adjacent token only). Blue=active(5pts) only if Green to left. Green=inactive if last. Yellow=always active(7pts). Inactive tokens stay 0 even when doubled.",
    "expected_answer": "9",
    "expected_active_tokens": ["Green", "Blue"],
    "expected_mistakes": ["Red doubles Green not Blue", "Green at last position is inactive"],
    "acceptable_aliases": {"9": ["9 points", "score: 9", "score is 9"]}
  },
  {
    "id": "l6_induction_02",
    "difficulty": "L6",
    "task_type": "short_rule_induction",
    "learner_prompt": "A new token type has been introduced: Orange Zarn (base value 4).\nNew rule: Orange is active (4 pts) only if the token IMMEDIATELY to its left is Yellow. Otherwise Orange is inactive (0).\n\nCalculate the score for: [Yellow, Orange, Green]\n\nUse your memory of the standard rules plus the new Orange rule above.\n\nRespond in JSON only:\n{\"answer\": \"<score>\", \"active_tokens\": [\"list active token names\"], \"mistakes_found\": [], \"reason\": \"<under 40 words>\"}",
    "hidden_rules": "Standard: Red=modifier(0pts,doubles next). Blue=active(5pts) only if Green to left. Green=inactive if last. Yellow=always active(7pts). New: Orange=active(4pts) only if immediately preceded by Yellow.",
    "expected_answer": "11",
    "expected_active_tokens": ["Yellow", "Orange"],
    "expected_mistakes": [],
    "acceptable_aliases": {"11": ["11 points", "score: 11", "score is 11"]}
  }
]
```

- [ ] **Step 2: Verify JSON and check no rules in learner_prompts (L1–L5)**

```bash
cd /Users/masumi/tmp/Agent-Based-Theory-Testing-2-Sigma-Problem
bundle exec ruby -e "
require 'json'
tasks = JSON.parse(File.read('experiments/bloom_1n_vs_1on1/domains/zarn_tokens/eval_tasks_v4.json'))
puts \"#{tasks.size} tasks\"
tasks.each { |t| puts \"#{t['id']}: has_rules=#{t['learner_prompt'].include?('active (5 pts)') || t['learner_prompt'].include?('doubles the token')}\" }
"
```

Expected: `8 tasks`, all `has_rules=false`

- [ ] **Step 3: Verify L5 and L6 math**

```bash
bundle exec ruby -e "
require 'json'
tasks = JSON.parse(File.read('experiments/bloom_1n_vs_1on1/domains/zarn_tokens/eval_tasks_v4.json'))
l5 = tasks.find { |t| t['id'] == 'l5_debug_03' }
l6 = tasks.find { |t| t['id'] == 'l6_induction_02' }
puts \"L5 expected: #{l5['expected_answer']} (want 9)\"
puts \"L5 mistakes: #{l5['expected_mistakes'].join(', ')}\"
puts \"L6 expected: #{l6['expected_answer']} (want 11)\"
puts \"L6 active: #{l6['expected_active_tokens'].join(', ')} (want Yellow, Orange)\"
"
```

Expected:
```
L5 expected: 9 (want 9)
L5 mistakes: Red doubles Green not Blue, Green at last position is inactive
L6 expected: 11 (want 11)
L6 active: Yellow, Orange (want Yellow, Orange)
```

- [ ] **Step 4: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/domains/zarn_tokens/eval_tasks_v4.json
git commit -m "feat: add v4 eval tasks — redesigned L5 (domain-knowledge required), simplified L6 sequence"
```

---

## Task 2: Update Config

**Files:**
- Modify: `experiments/bloom_1n_vs_1on1/config.yml`

- [ ] **Step 1: Replace config.yml entirely**

```yaml
experiment:
  name: "bloom_1n_vs_1on1_v4"
  domain: "zarn_tokens"
  n_classroom: 6
  n_tutoring: 6
  n_no_education: 4
  classroom_questions_per_learner: 1
  tutoring_turns: 4
  eval_tasks_file: "eval_tasks_v4.json"
  max_memory_words: 120
  ceiling_threshold: 0.9

models:
  teacher: "claude-sonnet-4-6"
  tutor: "claude-sonnet-4-6"
  learner: "claude-sonnet-4-6"
  # learner_diagnostic: "claude-haiku-4-5-20251001"  # optional: set to weaker model for calibration
  memory_summarizer: "claude-sonnet-4-6"
  problem_solver: "claude-sonnet-4-6"
  evaluator: "claude-sonnet-4-6"

paths:
  prompts: "experiments/bloom_1n_vs_1on1/prompts"
  domain: "experiments/bloom_1n_vs_1on1/domains/zarn_tokens"
  output: "experiments/bloom_1n_vs_1on1/data"
  db: "experiments/bloom_1n_vs_1on1/data/experiment.db"
```

- [ ] **Step 2: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/config.yml
git commit -m "feat: update config for v4 — n=6/6/4, tutoring_turns=4, eval_tasks_v4"
```

---

## Task 3: Extend Tutoring to 4 Exchanges (8 turns)

**Files:**
- Modify: `experiments/bloom_1n_vs_1on1/lib/phases/tutoring.rb`

The critical addition is **Exchange 3**: tutor gives targeted feedback, learner reflects on the correction. Without this, the tutor diagnoses a misconception in Exchange 2 but never corrects it. Exchange 4 then tests with a harder question to confirm the correction stuck.

- [ ] **Step 1: Read current tutoring.rb**

Read `experiments/bloom_1n_vs_1on1/lib/phases/tutoring.rb` to confirm current structure (4 turns, 2 exchanges).

- [ ] **Step 2: Replace tutoring.rb entirely**

```ruby
# ABOUTME: Orchestrates individual 1on1 tutoring sessions for each B-group learner
# ABOUTME: Four exchanges: teach, diagnose, feedback+correction, deeper application

require_relative '../llm'
require_relative '../helpers'

module Phases
  module Tutoring
    def self.run_session(tutor_id:, learner_id:, tutor_prompt:, learner_prompt:, lesson:, config:, tracker: nil)
      tutor_model   = config.dig('models', 'tutor')   || 'claude-sonnet-4-6'
      learner_model = config.dig('models', 'learner') || 'claude-sonnet-4-6'

      turns = []

      # Exchange 1, Turn 1: Tutor opens session and teaches first concept
      opener_prompt = Helpers.build_prompt(
        system: tutor_prompt,
        context: "DOMAIN LESSON MATERIAL:\n#{lesson}",
        instruction: "Begin a tutoring session with #{learner_id}. Teach the most important concept with a concrete example. Be concise — under 150 words."
      )
      opener = LLM.call(opener_prompt, model: tutor_model, tracker: tracker, phase: 'education_tutoring')
      turns << { 'speaker' => 'tutor', 'type' => 'opener', 'content' => opener }
      $stderr.puts "[tutoring:#{learner_id}] Tutor opened session"

      # Exchange 1, Turn 2: Learner responds
      response_prompt = Helpers.build_prompt(
        system: learner_prompt,
        context: "TUTOR SAID:\n#{opener}",
        instruction: "Respond to your tutor. State what you understood, or ask a question if something is unclear. 1-2 sentences."
      )
      response = LLM.call(response_prompt, model: learner_model, tracker: tracker, phase: 'education_tutoring')
      turns << { 'speaker' => 'learner', 'type' => 'response', 'content' => response }
      $stderr.puts "[tutoring:#{learner_id}] Learner responded"

      # Exchange 2, Turn 3: Tutor asks first diagnostic question
      history = Helpers.format_turns_for_prompt(turns)
      diag1_prompt = Helpers.build_prompt(
        system: tutor_prompt,
        context: "DOMAIN LESSON:\n#{lesson}\n\nSESSION SO FAR:\n#{history}",
        instruction: "Ask ONE diagnostic question requiring the learner to apply a rule to a specific sequence. Require calculation, not recitation. Under 60 words. Do not give the answer."
      )
      diag1 = LLM.call(diag1_prompt, model: tutor_model, tracker: tracker, phase: 'education_tutoring')
      turns << { 'speaker' => 'tutor', 'type' => 'diagnostic_q1', 'content' => diag1 }
      $stderr.puts "[tutoring:#{learner_id}] Tutor asked diagnostic Q1"

      # Exchange 2, Turn 4: Learner answers Q1
      history = Helpers.format_turns_for_prompt(turns)
      answer1_prompt = Helpers.build_prompt(
        system: learner_prompt,
        context: "SESSION SO FAR:\n#{history}",
        instruction: "Answer the tutor's question. Show your step-by-step reasoning. If unsure about any step, say so."
      )
      answer1 = LLM.call(answer1_prompt, model: learner_model, tracker: tracker, phase: 'education_tutoring')
      turns << { 'speaker' => 'learner', 'type' => 'answer1', 'content' => answer1 }
      $stderr.puts "[tutoring:#{learner_id}] Learner answered Q1"

      # Exchange 3, Turn 5: Tutor gives targeted feedback on Q1 answer
      history = Helpers.format_turns_for_prompt(turns)
      feedback_prompt = Helpers.build_prompt(
        system: tutor_prompt,
        context: "DOMAIN LESSON:\n#{lesson}\n\nSESSION SO FAR:\n#{history}",
        instruction: "Give targeted feedback on the learner's answer. If they made an error, identify exactly what was wrong and give the correct reasoning. If correct, confirm and point out one edge case to watch for. Under 100 words."
      )
      feedback = LLM.call(feedback_prompt, model: tutor_model, tracker: tracker, phase: 'education_tutoring')
      turns << { 'speaker' => 'tutor', 'type' => 'feedback', 'content' => feedback }
      $stderr.puts "[tutoring:#{learner_id}] Tutor gave feedback"

      # Exchange 3, Turn 6: Learner reflects and confirms correction
      history = Helpers.format_turns_for_prompt(turns)
      reflect_prompt = Helpers.build_prompt(
        system: learner_prompt,
        context: "SESSION SO FAR:\n#{history}",
        instruction: "Acknowledge the tutor's feedback. State in your own words: what was wrong (if anything) and what the correct rule application is. 1-3 sentences."
      )
      reflect = LLM.call(reflect_prompt, model: learner_model, tracker: tracker, phase: 'education_tutoring')
      turns << { 'speaker' => 'learner', 'type' => 'reflection', 'content' => reflect }
      $stderr.puts "[tutoring:#{learner_id}] Learner reflected"

      # Exchange 4, Turn 7: Tutor asks harder second diagnostic question
      history = Helpers.format_turns_for_prompt(turns)
      diag2_prompt = Helpers.build_prompt(
        system: tutor_prompt,
        context: "DOMAIN LESSON:\n#{lesson}\n\nSESSION SO FAR:\n#{history}",
        instruction: "Ask a second, harder diagnostic question that tests a DIFFERENT rule from Q1 or tests two rules interacting. This checks whether the learner can generalize. Under 80 words. Do not give the answer."
      )
      diag2 = LLM.call(diag2_prompt, model: tutor_model, tracker: tracker, phase: 'education_tutoring')
      turns << { 'speaker' => 'tutor', 'type' => 'diagnostic_q2', 'content' => diag2 }
      $stderr.puts "[tutoring:#{learner_id}] Tutor asked diagnostic Q2"

      # Exchange 4, Turn 8: Learner answers Q2
      history = Helpers.format_turns_for_prompt(turns)
      answer2_prompt = Helpers.build_prompt(
        system: learner_prompt,
        context: "SESSION SO FAR:\n#{history}",
        instruction: "Answer the tutor's second question. Apply what you learned and corrected in this session. Show your reasoning."
      )
      answer2 = LLM.call(answer2_prompt, model: learner_model, tracker: tracker, phase: 'education_tutoring')
      turns << { 'speaker' => 'learner', 'type' => 'answer2', 'content' => answer2 }
      $stderr.puts "[tutoring:#{learner_id}] Learner answered Q2"

      {
        'condition'  => '1on1',
        'tutor_id'   => tutor_id,
        'learner_id' => learner_id,
        'turns'      => turns
      }
    end
  end
end
```

- [ ] **Step 3: Verify syntax**

```bash
bundle exec ruby -c experiments/bloom_1n_vs_1on1/lib/phases/tutoring.rb
```

Expected: `Syntax OK`

- [ ] **Step 4: Count turns in new implementation**

```bash
grep "'type' =>" experiments/bloom_1n_vs_1on1/lib/phases/tutoring.rb | wc -l
```

Expected: `8` (opener, response, diagnostic_q1, answer1, feedback, reflection, diagnostic_q2, answer2)

- [ ] **Step 5: Verify no remaining v3 turn types (diagnostic_question, answer)**

```bash
grep "'type' => 'diagnostic_question'\|'type' => 'answer'" experiments/bloom_1n_vs_1on1/lib/phases/tutoring.rb
```

Expected: no output

- [ ] **Step 6: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/lib/phases/tutoring.rb
git commit -m "feat: extend tutoring to 4 exchanges (8 turns) — add feedback loop and second diagnostic"
```

---

## Task 4: Update README (v4 methodology note)

**Files:**
- Modify: `experiments/bloom_1n_vs_1on1/README.md`

- [ ] **Step 1: Read the current README to find the right insertion point**

Read `experiments/bloom_1n_vs_1on1/README.md`.

- [ ] **Step 2: Add v4 section after the v3 methodology section**

Append this section before "How to Run":

```markdown
## v4 Methodology: Longer Tutoring + Task Validity Fixes

### Changes from v3

**Tutoring extended to 4 exchanges (8 turns):**

| Exchange | Tutor | Learner |
|----------|-------|---------|
| 1 | Opener — teach first concept with example | Response — state understanding or ask question |
| 2 | Diagnostic Q1 — apply a rule to a sequence | Answer Q1 — step-by-step reasoning |
| 3 | **Targeted feedback** — correct errors explicitly | **Reflection** — restate corrected rule in own words |
| 4 | Diagnostic Q2 — harder, tests different rule | Answer Q2 — apply corrected understanding |

Exchange 3 (feedback + reflection) is the critical addition. In v3, the tutor identified a misconception in Exchange 2 but had no chance to correct it. The learner exited with the wrong understanding. Exchange 3 closes this loop.

**Task redesigns:**

| Task | v3 problem | v4 fix |
|------|------------|--------|
| L5 counterexample | Solvable by pure logic (no domain rules needed) | Replaced with `l5_debug_03`: debugging `[Red, Green, Blue, Green]` where Red doubles Green, not Blue |
| L6 induction | Sequence `[Yellow, Orange, Blue, Green]` required 3 simultaneous rules — too hard | Simplified to `[Yellow, Orange, Green]` — tests Orange rule + Green end rule only |

**n increased:** n_classroom=6, n_tutoring=6, n_no_education=4 for better statistical power.

### Expected effect

If Bloom's tutoring advantage holds in this agent setting:
- Tutoring should build richer memory than classroom (feedback corrects specific errors)
- Condition-sensitive tasks should show: tutoring > classroom > no_education
- At minimum, education_sensitive tasks should improve in count vs v3
```

- [ ] **Step 3: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/README.md
git commit -m "docs: add v4 methodology section — longer tutoring, task validity fixes"
```

---

## Task 5: Smoke Test (n=1 per condition)

- [ ] **Step 1: Run full test suite**

```bash
bash experiments/bloom_1n_vs_1on1/tests/run_tests.sh
```

Expected: `All tests passed.`

- [ ] **Step 2: Temporarily set n=1**

Edit `experiments/bloom_1n_vs_1on1/config.yml`: set `n_classroom: 1`, `n_tutoring: 1`, `n_no_education: 1`.

- [ ] **Step 3: Run experiment**

```bash
bundle exec ruby experiments/bloom_1n_vs_1on1/scripts/run_experiment.rb \
  experiments/bloom_1n_vs_1on1/config.yml 2>&1
```

Monitor stderr. Expected sequence:
```
[main] Phase 1: Classroom education (1 learners)
[main] Phase 2: 1on1 tutoring (1 sessions)
[tutoring:...] Tutor opened session
[tutoring:...] Learner responded
[tutoring:...] Tutor asked diagnostic Q1
[tutoring:...] Learner answered Q1
[tutoring:...] Tutor gave feedback        ← NEW in v4
[tutoring:...] Learner reflected          ← NEW in v4
[tutoring:...] Tutor asked diagnostic Q2  ← NEW in v4
[tutoring:...] Learner answered Q2        ← NEW in v4
[main] Phase 2.5: No-education baseline (1 learners, zero LLM calls)
...
[main] Done.
```

- [ ] **Step 4: Verify 7 output files and 8-turn tutoring transcript**

```bash
RUN_DIR=<path from step 3>
ls -la "$RUN_DIR"
echo "---"
# Verify tutoring transcript has 8 turns
bundle exec ruby -e "
require 'json'
File.readlines('$RUN_DIR/transcripts.jsonl').each do |line|
  t = JSON.parse(line)
  if t['condition'] == '1on1'
    puts \"Tutoring turns: #{t['turns'].size} (want 8)\"
    puts t['turns'].map { |turn| turn['type'] }.join(', ')
  end
end
"
```

Expected: `Tutoring turns: 8` and turn types: `opener, response, diagnostic_q1, answer1, feedback, reflection, diagnostic_q2, answer2`

- [ ] **Step 5: Check L5 and L6 are scored**

```bash
grep "l5_debug_03\|l6_induction_02" "$RUN_DIR/scores.csv"
```

Expected: rows for both tasks across all 3 conditions.

- [ ] **Step 6: Show report ceiling section**

```bash
grep -A 14 "Ceiling Effect Summary" "$RUN_DIR/report.md" | head -16
```

Expected: 6 task types shown with no_education / classroom / tutoring columns and a classification column.

- [ ] **Step 7: Restore n=4/4/4 wait, n=6/6/4**

Edit config.yml: `n_classroom: 6`, `n_tutoring: 6`, `n_no_education: 4`.

- [ ] **Step 8: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/config.yml
git commit -m "chore: restore n=6/6/4 after v4 smoke test"
```

---

## Self-Review

### Spec Coverage

| Problem identified | Fix | Task |
|-------------------|-----|------|
| Tutoring too short — no feedback loop | 4 exchanges, feedback + reflection + Q2 | Task 3 |
| L5 solvable without domain knowledge | Replaced with debugging task requiring positional rule precision | Task 1 |
| L6 too hard (all 0%) — 3 rules at once | Simplified sequence [Yellow, Orange, Green] — 2 rules only | Task 1 |
| n too small for statistical comparison | n_classroom=6, n_tutoring=6, n_no_education=4 | Task 2 |
| tutoring_turns config reflects new count | tutoring_turns: 4 | Task 2 |
| README documents changes | v4 section added | Task 4 |

### Placeholder Scan

No TBD/TODO items. All code is complete and verifiable.

### Type Consistency

- `turns` array elements use string keys (`'type'`, `'speaker'`, `'content'`) — consistent with all other phases and with `Helpers.format_turns_for_prompt` which reads `t['speaker']` and `t['content']` ✓
- New turn types: `'diagnostic_q1'`, `'answer1'`, `'feedback'`, `'reflection'`, `'diagnostic_q2'`, `'answer2'` — these are stored in `transcripts.jsonl` and `learning_sessions` DB but not read by any other module (memory summarizer uses `format_turns_for_prompt` which is type-agnostic) ✓
- `task['learner_prompt']` in solver.rb (unchanged from v3) — eval_tasks_v4.json provides `learner_prompt` on all 8 tasks ✓
- L5 task id changed from `l5_counterexample_01` to `l5_debug_03` — `extract_difficulty` reads the `l5` prefix → still returns `'L5'` ✓
- L6 task id changed from `l6_induction_01` to `l6_induction_02` — prefix `l6` → still `'L6'` ✓
