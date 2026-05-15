# v3 Memory-Only Evaluation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace rule-embedded evaluation prompts with memory-only prompts and add a no-education baseline condition so the experiment measures education effect rather than in-context rule reading.

**Architecture:** Tasks gain a `learner_prompt` field (no rules) plus `hidden_rules` (scorer-only). A new `no_education` condition generates empty memory with no LLM calls. Report gains 3-condition ceiling detection and a classification column (too_easy / education_sensitive / condition_sensitive / too_hard).

**Tech Stack:** Ruby stdlib, sqlite3 gem — no new dependencies.

---

## File Map

```
CREATED:
  experiments/bloom_1n_vs_1on1/domains/zarn_tokens/eval_tasks_v3.json
  experiments/bloom_1n_vs_1on1/lib/phases/no_education.rb
  experiments/bloom_1n_vs_1on1/tests/test_report_classification.rb

MODIFIED:
  experiments/bloom_1n_vs_1on1/config.yml
  experiments/bloom_1n_vs_1on1/lib/phases/solver.rb        (task['learner_prompt'] not task['prompt'])
  experiments/bloom_1n_vs_1on1/lib/report.rb               (3-condition ceiling + classify_task_type)
  experiments/bloom_1n_vs_1on1/scripts/run_experiment.rb   (no_education condition block)
  experiments/bloom_1n_vs_1on1/tests/run_tests.sh          (add test_report_classification.rb)
  experiments/bloom_1n_vs_1on1/README.md                   (v3 methodology note)
```

---

## Task 1: eval_tasks_v3.json

**Files:**
- Create: `experiments/bloom_1n_vs_1on1/domains/zarn_tokens/eval_tasks_v3.json`

The learner_prompt contains only the question — no rules. Rules are in hidden_rules for documentation only. The auto-scorer uses expected_answer / expected_active_tokens / expected_mistakes / acceptable_aliases, identical in structure to v2.

- [ ] **Step 1: Create eval_tasks_v3.json**

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
    "id": "l5_counterexample_01",
    "difficulty": "L5",
    "task_type": "counterexample",
    "learner_prompt": "Is this claim true or false?\n\"If a Zarn sequence contains at least one Green token that is not in the last position, then every Blue token in that sequence is active.\"\n\nIf false, give a specific counterexample sequence. Use only your memory of the rules.\n\nRespond in JSON only:\n{\"answer\": \"true or false\", \"active_tokens\": [\"active tokens in your counterexample if false\"], \"mistakes_found\": [\"which Blue is inactive and why\"], \"reason\": \"<under 40 words>\"}",
    "hidden_rules": "Red=modifier(0pts,doubles next). Blue=active(5pts) only if Green to left. Green=inactive if last. Yellow=always active(7pts). Inactive tokens stay 0 even when doubled.",
    "expected_answer": "false",
    "expected_active_tokens": ["Green", "Blue"],
    "expected_mistakes": ["Blue before Green has no Green to its left"],
    "acceptable_aliases": {"false": ["False", "FALSE", "no", "incorrect", "the claim is false"]}
  },
  {
    "id": "l6_induction_01",
    "difficulty": "L6",
    "task_type": "short_rule_induction",
    "learner_prompt": "A new token type has been introduced: Orange Zarn (base value 4).\nNew rule: Orange is active (4 pts) only if the token IMMEDIATELY to its left is Yellow. Otherwise Orange is inactive (0).\n\nCalculate the score for: [Yellow, Orange, Blue, Green]\n\nUse your memory of the standard rules plus the new Orange rule above.\n\nRespond in JSON only:\n{\"answer\": \"<score>\", \"active_tokens\": [\"list active token names\"], \"mistakes_found\": [], \"reason\": \"<under 40 words>\"}",
    "hidden_rules": "Standard: Red=modifier(0pts,doubles next). Blue=active(5pts) only if Green to left. Green=inactive if last. Yellow=always active(7pts). New: Orange=active(4pts) only if immediately preceded by Yellow.",
    "expected_answer": "11",
    "expected_active_tokens": ["Yellow", "Orange"],
    "expected_mistakes": [],
    "acceptable_aliases": {"11": ["11 points", "score: 11", "score is 11"]}
  }
]
```

- [ ] **Step 2: Verify valid JSON and task count**

```bash
cd /Users/masumi/tmp/Agent-Based-Theory-Testing-2-Sigma-Problem
bundle exec ruby -e "
require 'json'
tasks = JSON.parse(File.read('experiments/bloom_1n_vs_1on1/domains/zarn_tokens/eval_tasks_v3.json'))
puts \"#{tasks.size} tasks\"
puts tasks.map { |t| \"#{t['id']}: learner_prompt_has_rules=#{t['learner_prompt'].include?('active (5 pts)')}\" }.join(\"\n\")
"
```

Expected: `8 tasks` and all `learner_prompt_has_rules=false`

- [ ] **Step 3: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/domains/zarn_tokens/eval_tasks_v3.json
git commit -m "feat: add v3 eval tasks — rules-free learner_prompt, hidden_rules separate"
```

---

## Task 2: Update Config

**Files:**
- Modify: `experiments/bloom_1n_vs_1on1/config.yml`

- [ ] **Step 1: Replace config.yml entirely**

```yaml
experiment:
  name: "bloom_1n_vs_1on1_v3"
  domain: "zarn_tokens"
  n_classroom: 4
  n_tutoring: 4
  n_no_education: 4
  classroom_questions_per_learner: 1
  tutoring_turns: 2
  eval_tasks_file: "eval_tasks_v3.json"
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
git commit -m "feat: update config for v3 (n_no_education, eval_tasks_v3, diagnostic model comment)"
```

---

## Task 3: NoEducation Phase Module

**Files:**
- Create: `experiments/bloom_1n_vs_1on1/lib/phases/no_education.rb`

No LLM calls. Returns an empty memory dict immediately.

- [ ] **Step 1: Create lib/phases/no_education.rb**

```ruby
# ABOUTME: Baseline condition — no lesson, no tutor, empty memory
# ABOUTME: Zero LLM calls; used to measure base model performance without education

module Phases
  module NoEducation
    EMPTY_MEMORY = {
      'rules'      => [],
      'mistakes'   => [],
      'strategy'   => [],
      'edge_cases' => []
    }.freeze

    def self.generate_memory(learner_id:)
      $stderr.puts "[no_education:#{learner_id}] Empty memory generated (baseline condition)"
      EMPTY_MEMORY.transform_values(&:dup)
    end
  end
end
```

- [ ] **Step 2: Verify syntax**

```bash
bundle exec ruby -c experiments/bloom_1n_vs_1on1/lib/phases/no_education.rb
```

Expected: `Syntax OK`

- [ ] **Step 3: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/lib/phases/no_education.rb
git commit -m "feat: add NoEducation phase — empty memory baseline, zero LLM calls"
```

---

## Task 4: Update Solver Phase (learner_prompt key)

**Files:**
- Modify: `experiments/bloom_1n_vs_1on1/lib/phases/solver.rb`

Change `task['prompt']` → `task['learner_prompt']` in both places (initial call and retry call).

- [ ] **Step 1: Read the file to find exact lines**

Read `experiments/bloom_1n_vs_1on1/lib/phases/solver.rb` and locate the two lines containing `task['prompt']`.

- [ ] **Step 2: Apply edits**

In `solver.rb`, change:
```ruby
        instruction: task['prompt']
```
to:
```ruby
        instruction: task['learner_prompt']
```

And change:
```ruby
          instruction: task['prompt'] + "\n\nIMPORTANT: Respond ONLY with the JSON object. No other text."
```
to:
```ruby
          instruction: task['learner_prompt'] + "\n\nIMPORTANT: Respond ONLY with the JSON object. No other text."
```

- [ ] **Step 3: Verify syntax**

```bash
bundle exec ruby -c experiments/bloom_1n_vs_1on1/lib/phases/solver.rb
```

- [ ] **Step 4: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/lib/phases/solver.rb
git commit -m "feat: solver uses task learner_prompt (rules-free) for memory-only evaluation"
```

---

## Task 5: TDD — Report Classification Logic

**Files:**
- Create: `experiments/bloom_1n_vs_1on1/tests/test_report_classification.rb` (write first)
- Modify: `experiments/bloom_1n_vs_1on1/lib/report.rb` (add classify_task_type + update 3-condition ceiling)

### Step A: Write the tests

- [ ] **Step 1: Create test_report_classification.rb**

```ruby
# ABOUTME: TDD tests for Report.classify_task_type pure function
# ABOUTME: Tests all four classification outcomes with boundary cases

$LOAD_PATH.unshift File.join(__dir__, '..', 'lib')
require 'minitest/autorun'
require 'report'

class TestClassifyTaskType < Minitest::Test
  def classify(no_ed, classroom, tutoring)
    Report.classify_task_type(no_ed, classroom, tutoring, threshold: 0.9)
  end

  def test_too_easy_when_all_at_or_above_threshold
    assert_equal 'too_easy', classify(1.0, 1.0, 1.0)
    assert_equal 'too_easy', classify(0.9, 0.95, 1.0)
    assert_equal 'too_easy', classify(0.9, 0.9, 0.9)
  end

  def test_too_hard_when_all_below_30_percent
    assert_equal 'too_hard', classify(0.0, 0.0, 0.0)
    assert_equal 'too_hard', classify(0.1, 0.2, 0.29)
  end

  def test_condition_sensitive_when_tutoring_diverges_from_classroom
    # tutoring > classroom > no_education, large spread
    assert_equal 'condition_sensitive', classify(0.2, 0.5, 0.85)
  end

  def test_education_sensitive_when_edu_helps_but_conditions_similar
    # both classroom and tutoring outperform no_education, but similar to each other
    assert_equal 'education_sensitive', classify(0.1, 0.75, 0.80)
  end

  def test_education_sensitive_when_only_classroom_helps
    assert_equal 'education_sensitive', classify(0.1, 0.8, 0.3)
  end

  def test_unclear_when_no_strong_signal
    # education doesn't help much, not too easy, not too hard
    assert_equal 'unclear', classify(0.5, 0.55, 0.6)
  end

  def test_condition_sensitive_requires_education_to_also_help
    # tutoring differs from classroom but neither beats no_education
    assert_equal 'unclear', classify(0.8, 0.5, 0.9)
  end
end

class TestDetectCeiling3Conditions < Minitest::Test
  def make_rows(condition, task_type, task_id, answer_correct)
    Array.new(2) do
      {
        'condition' => condition,
        'task_type' => task_type,
        'task_id'   => task_id,
        'score_json' => JSON.dump({ 'answer_correct' => answer_correct, 'total' => answer_correct ? 4 : 0 })
      }
    end
  end

  def test_ceiling_flagged_when_all_three_conditions_score_high
    rows = make_rows('no_education', 'recall', 'l1_recall_01', true) +
           make_rows('classroom',    'recall', 'l1_recall_01', true) +
           make_rows('1on1',         'recall', 'l1_recall_01', true)
    config = { 'experiment' => { 'ceiling_threshold' => 0.9 } }
    result = Report.detect_ceiling(rows, config)
    assert_equal 1, result.size
    assert_equal true, result.first[:ceiling_effect]
    assert_equal 'too_easy', result.first[:classification]
  end

  def test_no_ceiling_when_no_education_scores_low
    rows = make_rows('no_education', 'debugging', 'l4_debug_01', false) +
           make_rows('classroom',    'debugging', 'l4_debug_01', true)  +
           make_rows('1on1',         'debugging', 'l4_debug_01', true)
    config = { 'experiment' => { 'ceiling_threshold' => 0.9 } }
    result = Report.detect_ceiling(rows, config)
    assert_equal false, result.first[:ceiling_effect]
    refute_equal 'too_easy', result.first[:classification]
  end
end
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
cd /Users/masumi/tmp/Agent-Based-Theory-Testing-2-Sigma-Problem
bundle exec ruby experiments/bloom_1n_vs_1on1/tests/test_report_classification.rb 2>&1 | head -10
```

Expected: `NoMethodError: undefined method 'classify_task_type' for Report:Module`

### Step B: Implement in report.rb

- [ ] **Step 3: Add `classify_task_type` method to report.rb**

After the `detect_ceiling` method (around line 178), add:

```ruby
  def self.classify_task_type(no_ed_pct, classroom_pct, tutoring_pct, threshold:)
    all_high   = no_ed_pct >= threshold && classroom_pct >= threshold && tutoring_pct >= threshold
    all_low    = no_ed_pct < 0.3 && classroom_pct < 0.3 && tutoring_pct < 0.3
    edu_helps  = classroom_pct > no_ed_pct + 0.1 || tutoring_pct > no_ed_pct + 0.1
    cond_diff  = (tutoring_pct - classroom_pct).abs > 0.1

    return 'too_easy'            if all_high
    return 'too_hard'            if all_low
    return 'condition_sensitive' if edu_helps && cond_diff
    return 'education_sensitive' if edu_helps
    'unclear'
  end
```

- [ ] **Step 4: Update `detect_ceiling` to use 3 conditions and call `classify_task_type`**

Replace the entire `detect_ceiling` method with:

```ruby
  def self.detect_ceiling(rows, run_config)
    threshold = (run_config.dig('experiment', 'ceiling_threshold') || CEILING_THRESHOLD).to_f
    rows.group_by { |r| r['task_type'] }.map do |task_type, type_rows|
      no_ed_pct  = avg_correctness(type_rows.select { |r| r['condition'] == 'no_education' })
      c_pct      = avg_correctness(type_rows.select { |r| r['condition'] == 'classroom' })
      t_pct      = avg_correctness(type_rows.select { |r| r['condition'] == '1on1' })
      difficulty = extract_difficulty(type_rows.first['task_id'])
      ceiling    = no_ed_pct >= threshold && c_pct >= threshold && t_pct >= threshold
      {
        task_type:      task_type,
        difficulty:     difficulty,
        no_ed_pct:      no_ed_pct,
        classroom_pct:  c_pct,
        tutoring_pct:   t_pct,
        ceiling_effect: ceiling,
        classification: classify_task_type(no_ed_pct, c_pct, t_pct, threshold: threshold)
      }
    end.sort_by { |r| DIFFICULTY_LEVELS.index(r[:difficulty]) || 99 }
  end
```

- [ ] **Step 5: Update ceiling table in `build_markdown` to show 3 conditions + classification**

In `build_markdown`, replace the ceiling table lines (find the block starting with `lines << "## Ceiling Effect Summary"`):

```ruby
    # Ceiling effect summary
    too_easy = ceiling_data.select { |r| r[:ceiling_effect] }.map { |r| r[:task_type] }
    lines << "## Ceiling Effect Summary"
    lines << ""
    lines << "> Classification: too_easy (all≥90%), education_sensitive (edu>baseline), condition_sensitive (tutoring≠classroom), too_hard (all<30%), unclear"
    lines << ""
    lines << "| Task Type | Difficulty | No-Ed Correct% | Classroom Correct% | Tutoring Correct% | Classification |"
    lines << "|-----------|-----------|----------------|-------------------|-------------------|----------------|"
    ceiling_data.each do |row|
      lines << "| #{row[:task_type]} | #{row[:difficulty]} | #{(row[:no_ed_pct] * 100).round}% | #{(row[:classroom_pct] * 100).round}% | #{(row[:tutoring_pct] * 100).round}% | #{row[:classification]} |"
    end
    lines << ""
    lines << (too_easy.any? ? "**Task types too easy:** #{too_easy.join(', ')}" : "**No ceiling effects detected.**")
    lines << ""
```

- [ ] **Step 6: Update score-by-condition table to include no_education**

Replace the condition loop:
```ruby
    %w[classroom 1on1].each do |cond|
```
with:
```ruby
    %w[no_education classroom 1on1].each do |cond|
```

- [ ] **Step 7: Update score-by-task-type table to show 3 conditions**

Replace the task-type table block:
```ruby
    rows.group_by { |r| r['task_type'] }.sort.each do |task_type, type_rows|
      diff  = extract_difficulty(type_rows.first['task_id'])
      c_pct = avg_correctness(type_rows.select { |r| r['condition'] == 'classroom' })
      t_pct = avg_correctness(type_rows.select { |r| r['condition'] == '1on1' })
      lines << "| #{task_type} | #{diff} | #{(c_pct * 100).round}% | #{(t_pct * 100).round}% |"
    end
```
with:
```ruby
    rows.group_by { |r| r['task_type'] }.sort.each do |task_type, type_rows|
      diff   = extract_difficulty(type_rows.first['task_id'])
      no_pct = avg_correctness(type_rows.select { |r| r['condition'] == 'no_education' })
      c_pct  = avg_correctness(type_rows.select { |r| r['condition'] == 'classroom' })
      t_pct  = avg_correctness(type_rows.select { |r| r['condition'] == '1on1' })
      lines << "| #{task_type} | #{diff} | #{(no_pct * 100).round}% | #{(c_pct * 100).round}% | #{(t_pct * 100).round}% |"
    end
```

And update the task-type table header accordingly:
```ruby
    lines << "| Task Type | Difficulty | No-Ed Correct% | Classroom Correct% | Tutoring Correct% |"
    lines << "|-----------|-----------|----------------|-------------------|-------------------|"
```

- [ ] **Step 8: Update score-by-difficulty table similarly**

Replace:
```ruby
    DIFFICULTY_LEVELS.each do |level|
      level_rows = rows.select { |r| extract_difficulty(r['task_id']) == level }
      next if level_rows.empty?
      types = level_rows.map { |r| r['task_type'] }.uniq.join(', ')
      c_pct = avg_correctness(level_rows.select { |r| r['condition'] == 'classroom' })
      t_pct = avg_correctness(level_rows.select { |r| r['condition'] == '1on1' })
      lines << "| #{level} | #{types} | #{(c_pct * 100).round}% | #{(t_pct * 100).round}% |"
    end
```
with:
```ruby
    DIFFICULTY_LEVELS.each do |level|
      level_rows = rows.select { |r| extract_difficulty(r['task_id']) == level }
      next if level_rows.empty?
      types  = level_rows.map { |r| r['task_type'] }.uniq.join(', ')
      no_pct = avg_correctness(level_rows.select { |r| r['condition'] == 'no_education' })
      c_pct  = avg_correctness(level_rows.select { |r| r['condition'] == 'classroom' })
      t_pct  = avg_correctness(level_rows.select { |r| r['condition'] == '1on1' })
      lines << "| #{level} | #{types} | #{(no_pct * 100).round}% | #{(c_pct * 100).round}% | #{(t_pct * 100).round}% |"
    end
```

And update header:
```ruby
    lines << "| Level | Task Types | No-Ed Correct% | Classroom Correct% | Tutoring Correct% |"
    lines << "|-------|-----------|----------------|-------------------|-------------------|"
```

- [ ] **Step 9: Update `build_token_data` — no_education has zero education tokens**

Replace `build_token_data` method:

```ruby
  def self.build_token_data(token_summary, by_condition)
    edu_classroom  = (token_summary['education_classroom'] || {})['total_tokens'].to_i
    edu_tutoring   = (token_summary['education_tutoring']  || {})['total_tokens'].to_i
    c_pct   = avg_correctness(by_condition['classroom']    || [])
    t_pct   = avg_correctness(by_condition['1on1']         || [])
    no_pct  = avg_correctness(by_condition['no_education'] || [])
    gain    = t_pct - c_pct
    extra   = [edu_tutoring - edu_classroom, 0].max
    gain_per_1k = extra > 0 ? (gain * 100) / (extra / 1000.0) : 0.0
    { classroom_pct: c_pct, tutoring_pct: t_pct, no_ed_pct: no_pct,
      tutoring_gain: gain, tutoring_extra: extra, gain_per_1k: gain_per_1k }
  end
```

- [ ] **Step 10: Verify syntax**

```bash
bundle exec ruby -c experiments/bloom_1n_vs_1on1/lib/report.rb
```

Expected: `Syntax OK`

- [ ] **Step 11: Run classification tests — they should PASS now**

```bash
bundle exec ruby experiments/bloom_1n_vs_1on1/tests/test_report_classification.rb
```

Expected: `0 failures, 0 errors, 0 skips`

- [ ] **Step 12: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/lib/report.rb \
        experiments/bloom_1n_vs_1on1/tests/test_report_classification.rb
git commit -m "feat: add classify_task_type TDD; update report for 3-condition ceiling detection"
```

---

## Task 6: Update Test Runner

**Files:**
- Modify: `experiments/bloom_1n_vs_1on1/tests/run_tests.sh`

- [ ] **Step 1: Add test_report_classification.rb to run_tests.sh**

In `run_tests.sh`, add before the final `echo "All tests passed."`:
```bash
bundle exec ruby "$EXPERIMENT_DIR/tests/test_report_classification.rb"
```

- [ ] **Step 2: Run full suite**

```bash
bash experiments/bloom_1n_vs_1on1/tests/run_tests.sh
```

Expected: `All tests passed.`

- [ ] **Step 3: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/tests/run_tests.sh
git commit -m "test: add report classification tests to test runner"
```

---

## Task 7: Update Orchestrator (run_experiment.rb)

**Files:**
- Modify: `experiments/bloom_1n_vs_1on1/scripts/run_experiment.rb`

Add `no_education` condition block and update `task['prompt']` → `task['learner_prompt']` in `DB.save_evaluation_task`.

- [ ] **Step 1: Read the file to understand the current structure**

Read `experiments/bloom_1n_vs_1on1/scripts/run_experiment.rb`.

- [ ] **Step 2: Add `require 'phases/no_education'` after the other phase requires**

After `require 'phases/evaluator'`, add:
```ruby
require 'phases/no_education'
```

- [ ] **Step 3: Add `n_no_education` variable after `n_tutoring`**

After the line `n_tutoring = config.dig('experiment', 'n_tutoring') || 4`, add:
```ruby
n_no_education = config.dig('experiment', 'n_no_education') || 4
```

- [ ] **Step 4: Add no_education agent creation after tutoring agents**

After the `tutoring_learner_ids` block and before `evaluator_id`, add:
```ruby
no_education_learner_ids = n_no_education.times.map do
  DB.save_agent(db, run_id: run_id, role: 'learner', condition: 'no_education',
                model: config.dig('models', 'problem_solver'))
end
```

- [ ] **Step 5: Update `all_learners` to include no_education**

Change the `all_learners` line to:
```ruby
all_learners = classroom_learner_ids.map { |id| { id: id, condition: 'classroom' } } +
               tutoring_learner_ids.map  { |id| { id: id, condition: '1on1' } } +
               no_education_learner_ids.map { |id| { id: id, condition: 'no_education' } }
```

- [ ] **Step 6: Add Phase 2.5 — NoEducation memory generation**

After the Phase 2 tutoring block (after the `end` that closes the `tutoring_learner_ids.each` block), add a new section before Phase 3:

```ruby
# === PHASE 2.5: No-Education Baseline Memory ===
$stderr.puts "[main] Phase 2.5: No-education baseline (#{n_no_education} learners, zero LLM calls)"
no_education_learner_ids.each do |learner_id|
  memory = Phases::NoEducation.generate_memory(learner_id: learner_id)
  DB.save_learner_memory(db,
    run_id: run_id, learner_id: learner_id,
    condition: 'no_education', memory: memory
  )
  File.open(File.join(run_dir, 'memories.jsonl'), 'a') do |f|
    f.puts JSON.dump({ learner_id: learner_id, condition: 'no_education', memory: memory })
  end
end
```

- [ ] **Step 7: Update Phase 3 to skip no_education learners (they already have memory)**

In Phase 3, change the `all_learners.each` loop to only process classroom and tutoring:
```ruby
# === PHASE 3: Memory Generation (classroom and tutoring only) ===
$stderr.puts "[main] Phase 3: Memory generation (#{classroom_learner_ids.size + tutoring_learner_ids.size} learners)"
(classroom_learner_ids.map { |id| { id: id, condition: 'classroom' } } +
 tutoring_learner_ids.map  { |id| { id: id, condition: '1on1' } }).each do |learner|
```

(Keep the rest of Phase 3 body unchanged, just change the array being iterated.)

- [ ] **Step 8: Fix `DB.save_evaluation_task` to use `learner_prompt` as the stored prompt**

Find the line:
```ruby
    prompt: task['prompt'], expected_answer: task, rubric: rubric
```
Change to:
```ruby
    prompt: task['learner_prompt'], expected_answer: task, rubric: rubric
```

- [ ] **Step 9: Verify syntax**

```bash
bundle exec ruby -c experiments/bloom_1n_vs_1on1/scripts/run_experiment.rb
```

Expected: `Syntax OK`

- [ ] **Step 10: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/scripts/run_experiment.rb
git commit -m "feat: add no_education baseline condition to orchestrator; use learner_prompt for eval"
```

---

## Task 8: Update README

**Files:**
- Modify: `experiments/bloom_1n_vs_1on1/README.md`

- [ ] **Step 1: Read the current README**

Read `experiments/bloom_1n_vs_1on1/README.md`.

- [ ] **Step 2: Add v3 methodology section**

After the existing "Important Caveats" section, add:

```markdown
## v3 Methodology: Memory-Only Evaluation

In v3, evaluation tasks no longer include the rules in the learner-visible prompt.

Learners must rely on compact memory generated during the education phase. Hidden rules are used only by the auto-scorer.

This prevents the experiment from measuring simple in-context rule reading and better isolates the effect of the educational condition.

### Three conditions in v3

| Condition | Education | Memory |
|-----------|-----------|--------|
| no_education | None | Empty (baseline) |
| classroom | 1:N lesson + Q&A | Compact memory from transcript |
| tutoring | 1on1 (2 exchanges) | Compact memory from transcript |

### Task classification

| Classification | Meaning |
|---------------|---------|
| too_easy | All 3 conditions ≥ 90% correct |
| too_hard | All 3 conditions < 30% correct |
| education_sensitive | Classroom or tutoring outperforms no_education by >10pp |
| condition_sensitive | Education helps AND tutoring differs from classroom by >10pp |
| unclear | No strong signal in any direction |

### Calibration with weaker model

To diagnose task difficulty, set `learner_diagnostic` in config to a weaker model (e.g., `claude-haiku-4-5-20251001`) and re-run. If haiku performs much worse, the task is genuinely hard. If haiku also solves it easily, the task design needs rethinking.
```

- [ ] **Step 3: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/README.md
git commit -m "docs: add v3 methodology section — memory-only eval, 3 conditions, task classification"
```

---

## Task 9: Smoke Test (n=1 per condition)

- [ ] **Step 1: Run full test suite**

```bash
bash experiments/bloom_1n_vs_1on1/tests/run_tests.sh
```

Expected: `All tests passed.`

- [ ] **Step 2: Set n=1 for all conditions temporarily**

Edit `experiments/bloom_1n_vs_1on1/config.yml`: set `n_classroom: 1`, `n_tutoring: 1`, `n_no_education: 1`.

- [ ] **Step 3: Run the experiment**

```bash
bundle exec ruby experiments/bloom_1n_vs_1on1/scripts/run_experiment.rb \
  experiments/bloom_1n_vs_1on1/config.yml 2>&1
```

Expected: prints a run_dir path. Monitor stderr for `[main] Done.`

- [ ] **Step 4: Verify output files**

```bash
RUN_DIR=<path from step 3>
ls -la "$RUN_DIR"
```

Must see all 7 files: `config.json`, `transcripts.jsonl`, `memories.jsonl`, `attempts.jsonl`, `evaluations.jsonl`, `scores.csv`, `report.md`

- [ ] **Step 5: Verify no_education condition appears in scores.csv**

```bash
grep "no_education" "$RUN_DIR/scores.csv" | head -3
```

Expected: rows with `no_education` in the condition column.

- [ ] **Step 6: Verify classification column in report.md**

```bash
grep -A 12 "Ceiling Effect Summary" "$RUN_DIR/report.md" | head -15
```

Expected: table with columns including `Classification`.

- [ ] **Step 7: Verify Phase 2.5 ran with zero education tokens for no_education**

```bash
grep "no_education" "$RUN_DIR/memories.jsonl" | head -2
grep "education_no_education" "$RUN_DIR/report.md" || echo "no_education has no education tokens (correct)"
```

- [ ] **Step 8: Restore config to n=4**

Change `n_classroom: 4`, `n_tutoring: 4`, `n_no_education: 4`.

- [ ] **Step 9: Final commit**

```bash
git add experiments/bloom_1n_vs_1on1/config.yml
git commit -m "chore: restore n=4 after v3 smoke test"
```

---

## Self-Review

### Spec Coverage

| Requirement | Task |
|-------------|------|
| learner_prompt separate from hidden_rules | Task 1 |
| Learner receives only memory + learner_prompt + JSON format | Task 4 (solver) |
| Learner does NOT receive hidden_rules, full lesson, transcript | Task 4 (solver) |
| Compact memory, max 120 words (already in v2) | config unchanged |
| no_education baseline condition | Tasks 2, 3, 7 |
| Auto-scorer uses expected_answer etc. (unchanged from v2) | no change needed |
| 3-condition ceiling detection | Task 5 (report) |
| Task classification: too_easy, education_sensitive, condition_sensitive, too_hard | Task 5 (report) |
| Optional learner_diagnostic model in config | Task 2 (comment in config) |
| README methodology note | Task 8 |

### Placeholder Scan

No TBD/TODO items. All code blocks are complete.

### Type Consistency

- `task['learner_prompt']` used in solver.rb (Task 4) and `DB.save_evaluation_task` (Task 7) — eval_tasks_v3.json provides this key on all 8 tasks ✓
- `Report.classify_task_type(no_ed, classroom, tutoring, threshold:)` — called in `detect_ceiling` and tested with exact same signature ✓
- `detect_ceiling` returns `:no_ed_pct`, `:classroom_pct`, `:tutoring_pct`, `:classification` — `build_markdown` ceiling table reads all four ✓
- `Phases::NoEducation.generate_memory(learner_id:)` — called in orchestrator Phase 2.5 with keyword arg ✓
- `all_learners` includes no_education entries with `condition: 'no_education'` — Phase 4+5 loop iterates all, DB stores condition string ✓
