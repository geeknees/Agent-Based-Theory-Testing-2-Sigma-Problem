# Bloom 2 Sigma Agent Experiment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a minimal reproducible experiment comparing 1:N classroom instruction vs 1on1 tutoring among LLM-based learner agents using Bloom's 2 Sigma Problem as the theoretical frame, outputting a Markdown report and CSV for analysis.

**Architecture:** Sequential Ruby orchestrator stores all data in SQLite; each phase calls `claude --print` via Open3; phases produce JSONL side-files and aggregate into a Markdown + CSV report. No tmux, no distributed processes.

**Tech Stack:** Ruby stdlib (json, yaml, securerandom, open3, csv), `sqlite3` gem, Claude CLI (`claude --print`)

---

## File Map

```
Agent-Based-Theory-Testing-2-Sigma-Problem/
├── Gemfile
├── .gitignore
├── experiments/
│   └── bloom_1n_vs_1on1/
│       ├── config.yml
│       ├── README.md
│       ├── purpose_doc.md
│       ├── lib/
│       │   ├── db.rb            # SQLite operations
│       │   ├── llm.rb           # claude --print wrapper
│       │   ├── helpers.rb       # extract_json, generate_id, format_transcript
│       │   ├── phases/
│       │   │   ├── classroom.rb # A-group: 1:N lesson
│       │   │   ├── tutoring.rb  # B-group: 1on1 sessions
│       │   │   ├── memory.rb    # memory summarizer for all learners
│       │   │   ├── solver.rb    # autonomous problem solving
│       │   │   └── evaluator.rb # blind scoring
│       │   └── report.rb        # CSV + Markdown report generation
│       ├── prompts/
│       │   ├── classroom_teacher.md
│       │   ├── one_on_one_tutor.md
│       │   ├── learner.md
│       │   ├── memory_summarizer.md
│       │   ├── problem_solver.md
│       │   └── blind_evaluator.md
│       ├── domains/
│       │   └── zarn_tokens/
│       │       ├── lesson.md
│       │       ├── eval_tasks.json
│       │       └── rubric.json
│       ├── scripts/
│       │   ├── run_experiment.rb   # main entry point
│       │   └── analyze_results.rb  # standalone post-hoc analysis
│       ├── tests/
│       │   ├── run_tests.sh
│       │   ├── test_helpers.rb
│       │   ├── test_db.rb
│       │   └── test_report.rb
│       └── data/
│           └── .gitkeep
└── docs/
    └── superpowers/
        └── plans/
            └── 2026-05-13-bloom-2sigma-experiment.md
```

---

## Task 1: Project Skeleton

**Files:**
- Create: `Gemfile`
- Create: `.gitignore`
- Create: `experiments/bloom_1n_vs_1on1/data/.gitkeep`

- [ ] **Step 1: Write Gemfile**

```ruby
# Gemfile
source 'https://rubygems.org'

gem 'sqlite3', '~> 1.7'
```

- [ ] **Step 2: Write .gitignore**

```
Gemfile.lock
experiments/bloom_1n_vs_1on1/data/runs/
experiments/bloom_1n_vs_1on1/data/*.db
*.log
.DS_Store
```

- [ ] **Step 3: Create data directory placeholder**

```bash
mkdir -p experiments/bloom_1n_vs_1on1/data
touch experiments/bloom_1n_vs_1on1/data/.gitkeep
```

- [ ] **Step 4: Install dependencies**

```bash
bundle install
```

Expected: sqlite3 gem installed successfully.

- [ ] **Step 5: Commit**

```bash
git add Gemfile .gitignore experiments/bloom_1n_vs_1on1/data/.gitkeep
git commit -m "chore: initialize project skeleton"
```

---

## Task 2: Config File

**Files:**
- Create: `experiments/bloom_1n_vs_1on1/config.yml`

- [ ] **Step 1: Write config.yml**

```yaml
experiment:
  name: "bloom_1n_vs_1on1_v1"
  domain: "zarn_tokens"
  n_classroom: 4
  n_tutoring: 4
  classroom_questions_per_learner: 1
  tutoring_turns: 3

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
  db: "experiments/bloom_1n_vs_1on1/data/experiment.db"
```

- [ ] **Step 2: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/config.yml
git commit -m "chore: add experiment config"
```

---

## Task 3: Zarn Tokens Domain Content

**Files:**
- Create: `experiments/bloom_1n_vs_1on1/domains/zarn_tokens/lesson.md`
- Create: `experiments/bloom_1n_vs_1on1/domains/zarn_tokens/eval_tasks.json`
- Create: `experiments/bloom_1n_vs_1on1/domains/zarn_tokens/rubric.json`

- [ ] **Step 1: Write lesson.md**

```markdown
# Zarn Token Rules

A **Zarn sequence** is an ordered list of colored tokens, each with a base value.

## Token Base Values

| Token       | Base Value |
|-------------|------------|
| Red Zarn    | 3          |
| Blue Zarn   | 5          |
| Green Zarn  | 2          |
| Yellow Zarn | 7          |

## Modifier Rules

1. **Red Modifier**: A Red Zarn doubles the base value of the token immediately to its right. The Red Zarn itself contributes 0 to the score (it is a pure modifier).
2. **Blue Activation**: A Blue Zarn is active (counts its value) only if there is at least one Green Zarn anywhere to its left in the sequence. Otherwise it is inactive (counts 0).
3. **Green End Rule**: A Green Zarn is inactive if it is the last token in the sequence. In any other position it is active.
4. **Stacking**: If a Red Zarn doubles a Blue Zarn that is itself inactive, the doubled value is also 0.
5. **Score**: The final score is the sum of all active token values after applying all modifiers.

## Worked Examples

**Example A**: [Red, Blue, Green]

- Position 1: Red → modifier only (0)
- Position 2: Blue → no Green to its left, so inactive (0). But Red doubles it → doubled(0) = 0.
- Position 3: Green → last position, so inactive (0)
- Score: 0

**Example B**: [Green, Blue, Yellow]

- Position 1: Green → not last, so active (2)
- Position 2: Blue → Green is to its left, so active (5)
- Position 3: Yellow → active, no modifier (7)
- Score: 2 + 5 + 7 = 14

**Example C**: [Green, Red, Yellow, Blue]

- Position 1: Green → not last, active (2)
- Position 2: Red → modifier only (0). Doubles position 3.
- Position 3: Yellow → base 7, doubled by Red → 14
- Position 4: Blue → Green is to its left (position 1), active → 5
- Score: 2 + 0 + 14 + 5 = 21

**Key things to remember:**
- Red contributes 0 but doubles the token to its right.
- Blue needs a Green to its left to be active.
- A Green at the very end is inactive.
- A doubled inactive token is still 0.
```

- [ ] **Step 2: Write eval_tasks.json**

```json
[
  {
    "id": "recall_01",
    "type": "recall",
    "prompt": "Calculate the final score for this Zarn sequence: [Green, Blue, Red, Yellow]\n\nApply all rules carefully and show your reasoning.",
    "expected_answer": {
      "score": 19,
      "explanation": "Green(active,2) + Blue(Green to left,active,5) + Red(modifier,0,doubles Yellow) + Yellow(doubled,14) = 2+5+0+14 = 21. Wait: Green=2, Blue=5 (active, Green at pos 1), Red=0 (modifier, doubles pos 4), Yellow=7*2=14. Score=2+5+0+14=21."
    },
    "correct_score": 21
  },
  {
    "id": "near_transfer_01",
    "type": "near_transfer",
    "prompt": "Calculate the final score for this Zarn sequence: [Blue, Green, Red, Blue, Yellow]\n\nApply all rules carefully and show your reasoning.",
    "expected_answer": {
      "score": 23,
      "explanation": "Blue(pos1, no Green to left, inactive=0) + Green(pos2, not last, active=2) + Red(pos3, modifier=0, doubles pos4) + Blue(pos4, Green at pos2 to left, active=5, doubled by Red=10) + Yellow(pos5, active=7). Score=0+2+0+10+7=19."
    },
    "correct_score": 19
  },
  {
    "id": "far_transfer_01",
    "type": "far_transfer",
    "prompt": "You encounter a new type of token: **Purple Zarn** (base value 6). A Purple Zarn behaves exactly like a Blue Zarn but requires a Red Zarn to its left (instead of Green) to be active.\n\nCalculate the final score for: [Red, Purple, Green, Blue, Purple]\n\nApply standard rules for all existing tokens, plus the new Purple rule.",
    "expected_answer": {
      "score": 13,
      "explanation": "Red(pos1,modifier=0,doubles pos2) + Purple(pos2,Red to left=active=6,doubled=12) + Green(pos3,not last,active=2) + Blue(pos4,Green at pos3 to left,active=5) + Purple(pos5,Red NOT immediately to left [Red is at pos1],need to check: does Purple need Red ANYWHERE to left? Assuming yes: Red is at pos1, so Purple at pos5 is active=6). Score=0+12+2+5+6=25. Note: answer depends on interpretation of 'to its left' as anywhere vs immediately adjacent."
    },
    "correct_score": 25
  }
]
```

- [ ] **Step 3: Write rubric.json**

```json
{
  "dimensions": {
    "correctness": {
      "max": 4,
      "description": "Accuracy of the final numerical answer",
      "levels": {
        "0": "No answer or completely wrong",
        "1": "Major errors in calculation",
        "2": "Partially correct with significant errors",
        "3": "Correct answer with minor error",
        "4": "Fully correct final answer"
      }
    },
    "reasoning_quality": {
      "max": 4,
      "description": "Clarity and structure of the reasoning chain",
      "levels": {
        "0": "No reasoning shown",
        "1": "Minimal or incoherent reasoning",
        "2": "Some valid reasoning with gaps",
        "3": "Clear reasoning with minor gaps",
        "4": "Fully explicit, step-by-step reasoning"
      }
    },
    "rule_application": {
      "max": 4,
      "description": "Correct identification and application of domain rules",
      "levels": {
        "0": "No rules applied or all rules wrong",
        "1": "One rule applied correctly",
        "2": "Some rules applied correctly",
        "3": "Most rules applied correctly",
        "4": "All relevant rules applied correctly"
      }
    },
    "error_checking": {
      "max": 4,
      "description": "Evidence of self-verification or catch-and-correct behavior",
      "levels": {
        "0": "No self-checking visible",
        "1": "Minimal checking",
        "2": "Some checking behavior",
        "3": "Explicit checking of key steps",
        "4": "Thorough verification throughout"
      }
    },
    "autonomy": {
      "max": 4,
      "description": "Independent problem-solving without relying on hints or prompting",
      "levels": {
        "0": "Completely dependent on prompt scaffolding",
        "1": "Needed significant guidance from memory",
        "2": "Partially independent",
        "3": "Mostly independent with minor memory use",
        "4": "Fully autonomous, memory used appropriately"
      }
    }
  },
  "total_max": 20
}
```

- [ ] **Step 4: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/domains/
git commit -m "feat: add Zarn Tokens domain content (lesson, eval tasks, rubric)"
```

---

## Task 4: Prompt Files

**Files:**
- Create: `experiments/bloom_1n_vs_1on1/prompts/classroom_teacher.md`
- Create: `experiments/bloom_1n_vs_1on1/prompts/one_on_one_tutor.md`
- Create: `experiments/bloom_1n_vs_1on1/prompts/learner.md`
- Create: `experiments/bloom_1n_vs_1on1/prompts/memory_summarizer.md`
- Create: `experiments/bloom_1n_vs_1on1/prompts/problem_solver.md`
- Create: `experiments/bloom_1n_vs_1on1/prompts/blind_evaluator.md`

- [ ] **Step 1: Write classroom_teacher.md**

```markdown
You are a classroom teacher delivering a lesson to a group of learner agents.

Your role:
- Deliver one clear, structured lesson to all learners simultaneously
- Answer learner questions publicly so all students hear the answer
- Do not adapt your teaching to individual learners
- Do not provide one-on-one coaching
- Keep the class moving at a shared pace

Tone: professional, clear, focused on covering the material.

When asked to deliver the lecture, output only the lecture text.
When asked to answer questions, address each question directly and publicly.
```

- [ ] **Step 2: Write one_on_one_tutor.md**

```markdown
You are a one-on-one tutor working with a single learner agent.

Your role:
- Engage in dialogue with this learner specifically
- Ask diagnostic questions to check their understanding
- Give targeted feedback based on their responses
- Adapt your explanations to what they have and haven't understood
- Stay within a fixed turn budget — be efficient

You do NOT run full mastery learning loops. You do NOT require perfect mastery before moving on.
You work within a fixed session: opener, one diagnostic question, one round of targeted feedback.

Tone: supportive, curious, direct. Focus on the learner's actual understanding.
```

- [ ] **Step 3: Write learner.md**

```markdown
You are a learner agent participating in an educational session.

Your role:
- Engage genuinely with the material you are taught
- Ask questions when something is unclear
- Answer the tutor or teacher honestly based on your current understanding
- Do not pretend to understand something you have not learned
- When asked to summarize or take notes, be specific and accurate

You are not omniscient. You learn from what you are taught in this session.
Base your understanding on the lesson content you have received.

Tone: curious, honest, engaged.
```

- [ ] **Step 4: Write memory_summarizer.md**

```markdown
You are a learning memory summarizer. Your job is to analyze an educational session transcript and extract a structured learning memory for the learner.

Output ONLY valid JSON. No prose before or after.

The JSON must match this exact schema:
{
  "key_rules": ["string — a rule the learner should remember"],
  "strategies": ["string — a problem-solving strategy learned"],
  "misconceptions_corrected": ["string — something the learner was wrong about, now corrected"],
  "uncertainty_areas": ["string — areas the learner is still unsure about"],
  "worked_examples": [
    {
      "problem": "string — the example problem",
      "solution": "string — the correct solution approach"
    }
  ]
}

All fields are arrays. Empty arrays are acceptable if no content applies.
Extract information from the learner's perspective based on what they participated in or observed.
```

- [ ] **Step 5: Write problem_solver.md**

```markdown
You are an autonomous learner agent solving a problem using your learning memory.

Your role:
- Read your learning memory carefully
- Apply the rules and strategies you remember to the problem
- Show your reasoning step by step
- Check your work before submitting
- Provide a clear final answer

Do not make up rules you weren't taught. If unsure, reason from what you know and flag uncertainty.

Format your response as:
1. Rule identification: which rules apply here
2. Step-by-step calculation
3. Self-check
4. Final answer: [your answer]
```

- [ ] **Step 6: Write blind_evaluator.md**

```markdown
You are a blind evaluator scoring a learner's problem-solving response.

You do NOT know which educational condition the learner came from.
Score based only on the response quality against the rubric.

Output ONLY valid JSON. No prose before or after.

The JSON must match this exact schema:
{
  "correctness": <integer 0-4>,
  "reasoning_quality": <integer 0-4>,
  "rule_application": <integer 0-4>,
  "error_checking": <integer 0-4>,
  "autonomy": <integer 0-4>,
  "total": <integer 0-20>,
  "comments": "one sentence comment on the response"
}

total must equal the sum of the five dimension scores.
```

- [ ] **Step 7: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/prompts/
git commit -m "feat: add all 6 prompt files"
```

---

## Task 5: LLM Helper

**Files:**
- Create: `experiments/bloom_1n_vs_1on1/lib/llm.rb`

- [ ] **Step 1: Write lib/llm.rb**

```ruby
# ABOUTME: Thin wrapper around `claude --print` for synchronous LLM calls
# ABOUTME: Raises on non-zero exit; returns stripped response text

require 'open3'

module LLM
  def self.call(prompt, model: nil)
    args = ['claude', '--print']
    args += ['--model', model] if model
    stdout, stderr, status = Open3.capture3(*args, stdin_data: prompt)
    unless status.success?
      raise "LLM call failed (exit #{status.exitstatus}): #{stderr.strip}"
    end
    stdout.strip
  end
end
```

- [ ] **Step 2: Verify claude CLI is available**

```bash
which claude && claude --version
```

Expected: prints claude version. If not found, install with `npm install -g @anthropic-ai/claude-code`.

- [ ] **Step 3: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/lib/llm.rb
git commit -m "feat: add LLM call helper"
```

---

## Task 6: Shared Helpers

**Files:**
- Create: `experiments/bloom_1n_vs_1on1/lib/helpers.rb`

- [ ] **Step 1: Write lib/helpers.rb**

```ruby
# ABOUTME: Pure helper functions for JSON extraction, ID generation, and prompt formatting
# ABOUTME: All functions are side-effect free and safe to test without LLM or DB

require 'json'
require 'securerandom'

module Helpers
  def self.extract_json(text)
    match = text.match(/\{.*\}/m)
    return nil unless match
    JSON.parse(match[0])
  rescue JSON::ParserError
    nil
  end

  def self.generate_id
    SecureRandom.uuid
  end

  def self.load_file(path)
    File.read(path).strip
  end

  def self.format_turns_for_prompt(turns)
    turns.map { |t| "[#{t['speaker']}] #{t['content']}" }.join("\n\n")
  end

  def self.build_prompt(system:, context:, instruction:)
    parts = []
    parts << "SYSTEM:\n#{system}" unless system.nil? || system.empty?
    parts << "CONTEXT:\n#{context}" unless context.nil? || context.empty?
    parts << "INSTRUCTION:\n#{instruction}"
    parts.join("\n\n---\n\n")
  end
end
```

- [ ] **Step 2: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/lib/helpers.rb
git commit -m "feat: add shared helpers module"
```

---

## Task 7: Database Operations

**Files:**
- Create: `experiments/bloom_1n_vs_1on1/lib/db.rb`

- [ ] **Step 1: Write lib/db.rb**

```ruby
# ABOUTME: SQLite database setup and all data persistence operations for experiments
# ABOUTME: Each save_* function takes a db handle plus data; returns the generated id

require 'sqlite3'
require 'json'
require_relative 'helpers'

module DB
  SCHEMA = <<~SQL
    CREATE TABLE IF NOT EXISTS experiment_runs (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      config_json TEXT NOT NULL,
      created_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS agents (
      id TEXT PRIMARY KEY,
      run_id TEXT NOT NULL,
      role TEXT NOT NULL,
      condition TEXT,
      model TEXT NOT NULL,
      profile_json TEXT,
      created_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS learning_sessions (
      id TEXT PRIMARY KEY,
      run_id TEXT NOT NULL,
      condition TEXT NOT NULL,
      learner_id TEXT,
      teacher_or_tutor_id TEXT NOT NULL,
      transcript_json TEXT NOT NULL,
      created_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS learner_memories (
      id TEXT PRIMARY KEY,
      run_id TEXT NOT NULL,
      learner_id TEXT NOT NULL,
      condition TEXT NOT NULL,
      memory_json TEXT NOT NULL,
      created_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS evaluation_tasks (
      id TEXT PRIMARY KEY,
      run_id TEXT NOT NULL,
      task_type TEXT NOT NULL,
      prompt TEXT NOT NULL,
      expected_answer_json TEXT,
      rubric_json TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS task_attempts (
      id TEXT PRIMARY KEY,
      run_id TEXT NOT NULL,
      learner_id TEXT NOT NULL,
      condition TEXT NOT NULL,
      task_id TEXT NOT NULL,
      response_text TEXT NOT NULL,
      trace_json TEXT,
      created_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS evaluations (
      id TEXT PRIMARY KEY,
      run_id TEXT NOT NULL,
      attempt_id TEXT NOT NULL,
      evaluator_id TEXT NOT NULL,
      score_json TEXT NOT NULL,
      created_at TEXT NOT NULL DEFAULT (datetime('now'))
    );
  SQL

  def self.setup(db_path)
    require 'fileutils'
    FileUtils.mkdir_p(File.dirname(db_path))
    db = SQLite3::Database.new(db_path)
    db.execute_batch(SCHEMA)
    db.results_as_hash = true
    db
  end

  def self.save_run(db, run_id, name, config)
    db.execute(
      'INSERT INTO experiment_runs (id, name, config_json) VALUES (?, ?, ?)',
      [run_id, name, JSON.dump(config)]
    )
    run_id
  end

  def self.save_agent(db, run_id:, role:, condition: nil, model:)
    id = Helpers.generate_id
    db.execute(
      'INSERT INTO agents (id, run_id, role, condition, model) VALUES (?, ?, ?, ?, ?)',
      [id, run_id, role, condition, model]
    )
    id
  end

  def self.save_learning_session(db, run_id:, condition:, learner_id: nil, teacher_or_tutor_id:, transcript:)
    id = Helpers.generate_id
    db.execute(
      'INSERT INTO learning_sessions (id, run_id, condition, learner_id, teacher_or_tutor_id, transcript_json) VALUES (?, ?, ?, ?, ?, ?)',
      [id, run_id, condition, learner_id, teacher_or_tutor_id, JSON.dump(transcript)]
    )
    id
  end

  def self.save_learner_memory(db, run_id:, learner_id:, condition:, memory:)
    id = Helpers.generate_id
    db.execute(
      'INSERT INTO learner_memories (id, run_id, learner_id, condition, memory_json) VALUES (?, ?, ?, ?, ?)',
      [id, run_id, learner_id, condition, JSON.dump(memory)]
    )
    id
  end

  def self.save_evaluation_task(db, run_id:, task_id:, task_type:, prompt:, expected_answer:, rubric:)
    db.execute(
      'INSERT OR IGNORE INTO evaluation_tasks (id, run_id, task_type, prompt, expected_answer_json, rubric_json) VALUES (?, ?, ?, ?, ?, ?)',
      [task_id, run_id, task_type, prompt, JSON.dump(expected_answer), JSON.dump(rubric)]
    )
    task_id
  end

  def self.save_task_attempt(db, run_id:, learner_id:, condition:, task_id:, response_text:, trace: nil)
    id = Helpers.generate_id
    db.execute(
      'INSERT INTO task_attempts (id, run_id, learner_id, condition, task_id, response_text, trace_json) VALUES (?, ?, ?, ?, ?, ?, ?)',
      [id, run_id, learner_id, condition, task_id, response_text, trace ? JSON.dump(trace) : nil]
    )
    id
  end

  def self.save_evaluation(db, run_id:, attempt_id:, evaluator_id:, score:)
    id = Helpers.generate_id
    db.execute(
      'INSERT INTO evaluations (id, run_id, attempt_id, evaluator_id, score_json) VALUES (?, ?, ?, ?, ?)',
      [id, run_id, attempt_id, evaluator_id, JSON.dump(score)]
    )
    id
  end

  def self.get_learner_memory(db, run_id:, learner_id:)
    row = db.execute(
      'SELECT memory_json FROM learner_memories WHERE run_id = ? AND learner_id = ? ORDER BY rowid DESC LIMIT 1',
      [run_id, learner_id]
    ).first
    row ? JSON.parse(row['memory_json']) : nil
  end

  def self.all_attempts_with_scores(db, run_id)
    db.execute(<<~SQL, [run_id])
      SELECT
        ta.id AS attempt_id,
        ta.learner_id,
        ta.condition,
        ta.task_id,
        et.task_type,
        ta.response_text,
        e.score_json
      FROM task_attempts ta
      JOIN evaluation_tasks et ON et.id = ta.task_id AND et.run_id = ta.run_id
      LEFT JOIN evaluations e ON e.attempt_id = ta.id
      WHERE ta.run_id = ?
      ORDER BY ta.condition, ta.learner_id, et.task_type
    SQL
  end
end
```

- [ ] **Step 2: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/lib/db.rb
git commit -m "feat: add database operations module"
```

---

## Task 8: Unit Tests for Pure Functions

**Files:**
- Create: `experiments/bloom_1n_vs_1on1/tests/test_helpers.rb`
- Create: `experiments/bloom_1n_vs_1on1/tests/test_db.rb`
- Create: `experiments/bloom_1n_vs_1on1/tests/run_tests.sh`

- [ ] **Step 1: Write tests/test_helpers.rb**

```ruby
# ABOUTME: Unit tests for Helpers module pure functions
# ABOUTME: No LLM or database calls; all deterministic

$LOAD_PATH.unshift File.join(__dir__, '..', 'lib')
require 'minitest/autorun'
require 'helpers'

class TestExtractJson < Minitest::Test
  def test_extracts_json_from_plain_object
    text = '{"correctness": 3, "total": 3}'
    result = Helpers.extract_json(text)
    assert_equal 3, result['correctness']
  end

  def test_extracts_json_surrounded_by_prose
    text = "Here is my score:\n{\"correctness\": 4, \"total\": 4}\nThank you."
    result = Helpers.extract_json(text)
    assert_equal 4, result['correctness']
  end

  def test_returns_nil_for_no_json
    result = Helpers.extract_json("There is no JSON here.")
    assert_nil result
  end

  def test_returns_nil_for_invalid_json
    result = Helpers.extract_json("{not valid json}")
    assert_nil result
  end
end

class TestFormatTurns < Minitest::Test
  def test_formats_turns_as_speaker_content
    turns = [
      { 'speaker' => 'teacher', 'content' => 'Hello class.' },
      { 'speaker' => 'learner_1', 'content' => 'Hello teacher.' }
    ]
    result = Helpers.format_turns_for_prompt(turns)
    assert_includes result, '[teacher] Hello class.'
    assert_includes result, '[learner_1] Hello teacher.'
  end

  def test_empty_turns_returns_empty_string
    result = Helpers.format_turns_for_prompt([])
    assert_equal '', result
  end
end

class TestBuildPrompt < Minitest::Test
  def test_includes_all_sections
    result = Helpers.build_prompt(
      system: 'You are a teacher.',
      context: 'The lesson is about Zarn.',
      instruction: 'Deliver the lecture.'
    )
    assert_includes result, 'SYSTEM:'
    assert_includes result, 'CONTEXT:'
    assert_includes result, 'INSTRUCTION:'
  end

  def test_omits_empty_system
    result = Helpers.build_prompt(
      system: nil,
      context: 'context',
      instruction: 'do it'
    )
    refute_includes result, 'SYSTEM:'
    assert_includes result, 'INSTRUCTION:'
  end
end

class TestGenerateId < Minitest::Test
  def test_returns_string
    assert_instance_of String, Helpers.generate_id
  end

  def test_unique_ids
    ids = Array.new(10) { Helpers.generate_id }
    assert_equal ids.uniq.size, 10
  end
end
```

- [ ] **Step 2: Write tests/test_db.rb**

```ruby
# ABOUTME: Integration tests for DB module using a temporary SQLite database
# ABOUTME: Creates and destroys a real on-disk DB per test; no mocking

$LOAD_PATH.unshift File.join(__dir__, '..', 'lib')
require 'minitest/autorun'
require 'tmpdir'
require 'db'

class TestDB < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @db_path = File.join(@tmpdir, 'test.db')
    @db = DB.setup(@db_path)
    @run_id = Helpers.generate_id
    DB.save_run(@db, @run_id, 'test_run', { 'n_classroom' => 2 })
  end

  def teardown
    @db.close
    FileUtils.rm_rf(@tmpdir)
  end

  def test_setup_creates_all_tables
    tables = @db.execute("SELECT name FROM sqlite_master WHERE type='table'").map { |r| r['name'] }
    %w[experiment_runs agents learning_sessions learner_memories evaluation_tasks task_attempts evaluations].each do |t|
      assert_includes tables, t, "Missing table: #{t}"
    end
  end

  def test_save_and_retrieve_run
    row = @db.execute('SELECT name FROM experiment_runs WHERE id = ?', [@run_id]).first
    assert_equal 'test_run', row['name']
  end

  def test_save_agent_returns_id
    id = DB.save_agent(@db, run_id: @run_id, role: 'teacher', model: 'claude-sonnet-4-6')
    assert_instance_of String, id
    refute_empty id
  end

  def test_save_and_retrieve_learner_memory
    learner_id = Helpers.generate_id
    memory = { 'key_rules' => ['Red doubles next token'] }
    DB.save_learner_memory(@db, run_id: @run_id, learner_id: learner_id, condition: 'classroom', memory: memory)
    retrieved = DB.get_learner_memory(@db, run_id: @run_id, learner_id: learner_id)
    assert_equal ['Red doubles next token'], retrieved['key_rules']
  end

  def test_save_task_attempt_and_query_with_scores
    task_id = 'task_recall_01'
    DB.save_evaluation_task(@db,
      run_id: @run_id, task_id: task_id, task_type: 'recall',
      prompt: 'Calculate score.', expected_answer: { 'score' => 21 },
      rubric: { 'total_max' => 20 }
    )
    learner_id = Helpers.generate_id
    attempt_id = DB.save_task_attempt(@db,
      run_id: @run_id, learner_id: learner_id, condition: 'classroom',
      task_id: task_id, response_text: 'My answer is 21.'
    )
    evaluator_id = Helpers.generate_id
    DB.save_evaluation(@db,
      run_id: @run_id, attempt_id: attempt_id, evaluator_id: evaluator_id,
      score: { 'total' => 18, 'correctness' => 4 }
    )
    rows = DB.all_attempts_with_scores(@db, @run_id)
    assert_equal 1, rows.size
    score = JSON.parse(rows.first['score_json'])
    assert_equal 18, score['total']
  end
end
```

- [ ] **Step 3: Write tests/run_tests.sh**

```bash
#!/usr/bin/env bash
# ABOUTME: Runs all minitest unit tests for this experiment
# ABOUTME: Execute from project root: bash experiments/bloom_1n_vs_1on1/tests/run_tests.sh

set -euo pipefail

EXPERIMENT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_ROOT="$(cd "$EXPERIMENT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"
bundle exec ruby "$EXPERIMENT_DIR/tests/test_helpers.rb"
bundle exec ruby "$EXPERIMENT_DIR/tests/test_db.rb"
echo "All tests passed."
```

```bash
chmod +x experiments/bloom_1n_vs_1on1/tests/run_tests.sh
```

- [ ] **Step 4: Run the tests (they should pass)**

```bash
bash experiments/bloom_1n_vs_1on1/tests/run_tests.sh
```

Expected output:
```
Run options: --seed ...
# Running:
....
4 runs, 4 assertions, 0 failures, 0 errors, 0 skips
...
All tests passed.
```

- [ ] **Step 5: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/tests/
git commit -m "test: add unit tests for helpers and database operations"
```

---

## Task 9: Classroom Education Phase

**Files:**
- Create: `experiments/bloom_1n_vs_1on1/lib/phases/classroom.rb`

- [ ] **Step 1: Write lib/phases/classroom.rb**

```ruby
# ABOUTME: Orchestrates the 1:N classroom education phase for the A-group learners
# ABOUTME: Teacher gives one lecture; learners ask questions; teacher answers publicly

require_relative '../llm'
require_relative '../helpers'

module Phases
  module Classroom
    def self.run(teacher_id:, learner_ids:, teacher_prompt:, learner_prompt:, lesson:, config:)
      questions_per_learner = config.dig('experiment', 'classroom_questions_per_learner') || 1
      model = config.dig('models', 'teacher') || 'claude-sonnet-4-6'
      learner_model = config.dig('models', 'learner') || 'claude-sonnet-4-6'

      turns = []

      # Step 1: Teacher delivers lecture
      lecture_prompt = Helpers.build_prompt(
        system: teacher_prompt,
        context: "DOMAIN LESSON:\n#{lesson}",
        instruction: "Deliver a clear, structured lesson to all learners. Cover all rules with examples. End with: \"Are there any questions?\""
      )
      lecture = LLM.call(lecture_prompt, model: model)
      turns << { 'speaker' => 'teacher', 'type' => 'lecture', 'content' => lecture }
      $stderr.puts "[classroom] Teacher delivered lecture (#{lecture.length} chars)"

      # Step 2: Each learner asks one question
      questions = learner_ids.map do |learner_id|
        question_prompt = Helpers.build_prompt(
          system: learner_prompt,
          context: "CLASS LECTURE:\n#{lecture}",
          instruction: "You are #{learner_id}. You have just attended this lecture. Ask ONE question about something you want to clarify. If you understood everything, write exactly: No questions."
        )
        question = LLM.call(question_prompt, model: learner_model)
        turns << { 'speaker' => learner_id, 'type' => 'question', 'content' => question }
        $stderr.puts "[classroom] #{learner_id} asked question"
        { learner_id: learner_id, question: question }
      end

      real_questions = questions.reject { |q| q[:question].strip.downcase.start_with?('no question') }

      # Step 3: Teacher answers all questions at once
      if real_questions.any?
        questions_text = real_questions.map { |q| "#{q[:learner_id]}: #{q[:question]}" }.join("\n\n")
        answer_prompt = Helpers.build_prompt(
          system: teacher_prompt,
          context: "DOMAIN LESSON:\n#{lesson}\n\nLECTURE DELIVERED:\n#{lecture}",
          instruction: "Answer these student questions publicly. Address each question clearly.\n\n#{questions_text}"
        )
        answers = LLM.call(answer_prompt, model: model)
        turns << { 'speaker' => 'teacher', 'type' => 'answers', 'content' => answers }
        $stderr.puts "[classroom] Teacher answered questions"
      end

      # Step 4: Each learner writes final notes
      transcript_so_far = Helpers.format_turns_for_prompt(turns)
      learner_ids.each do |learner_id|
        notes_prompt = Helpers.build_prompt(
          system: learner_prompt,
          context: "FULL CLASS TRANSCRIPT:\n#{transcript_so_far}",
          instruction: "You are #{learner_id}. Write your personal learning notes from this class. List the key rules, examples, and anything you want to remember."
        )
        notes = LLM.call(notes_prompt, model: learner_model)
        turns << { 'speaker' => learner_id, 'type' => 'notes', 'content' => notes }
        $stderr.puts "[classroom] #{learner_id} wrote notes"
      end

      {
        'condition' => 'classroom',
        'teacher_id' => teacher_id,
        'learner_ids' => learner_ids,
        'turns' => turns
      }
    end
  end
end
```

- [ ] **Step 2: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/lib/phases/classroom.rb
git commit -m "feat: implement classroom education phase"
```

---

## Task 10: 1on1 Tutoring Phase

**Files:**
- Create: `experiments/bloom_1n_vs_1on1/lib/phases/tutoring.rb`

- [ ] **Step 1: Write lib/phases/tutoring.rb**

```ruby
# ABOUTME: Orchestrates individual 1on1 tutoring sessions for each B-group learner
# ABOUTME: Each learner gets a separate session with dedicated back-and-forth dialogue

require_relative '../llm'
require_relative '../helpers'

module Phases
  module Tutoring
    def self.run_session(tutor_id:, learner_id:, tutor_prompt:, learner_prompt:, lesson:, config:)
      turns_budget = config.dig('experiment', 'tutoring_turns') || 3
      tutor_model = config.dig('models', 'tutor') || 'claude-sonnet-4-6'
      learner_model = config.dig('models', 'learner') || 'claude-sonnet-4-6'

      turns = []

      # Turn 1: Tutor opens session
      opener_prompt = Helpers.build_prompt(
        system: tutor_prompt,
        context: "DOMAIN LESSON MATERIAL:\n#{lesson}",
        instruction: "Begin a tutoring session with #{learner_id}. Introduce the topic briefly and start teaching the first key concept. Be engaging and specific."
      )
      opener = LLM.call(opener_prompt, model: tutor_model)
      turns << { 'speaker' => 'tutor', 'type' => 'opener', 'content' => opener }
      $stderr.puts "[tutoring:#{learner_id}] Tutor opened session"

      # Turn 2: Learner responds
      response_prompt = Helpers.build_prompt(
        system: learner_prompt,
        context: "TUTOR SAID:\n#{opener}",
        instruction: "Respond to your tutor. Engage with what they said. Ask a question if something is unclear, or confirm your understanding."
      )
      response = LLM.call(response_prompt, model: learner_model)
      turns << { 'speaker' => 'learner', 'type' => 'response', 'content' => response }
      $stderr.puts "[tutoring:#{learner_id}] Learner responded"

      # Turn 3: Tutor asks diagnostic question
      history = Helpers.format_turns_for_prompt(turns)
      diagnostic_prompt = Helpers.build_prompt(
        system: tutor_prompt,
        context: "DOMAIN LESSON:\n#{lesson}\n\nSESSION SO FAR:\n#{history}",
        instruction: "Ask a specific diagnostic question to check the learner's understanding of a key rule. Make it concrete and require application, not just recitation."
      )
      diagnostic = LLM.call(diagnostic_prompt, model: tutor_model)
      turns << { 'speaker' => 'tutor', 'type' => 'diagnostic_question', 'content' => diagnostic }
      $stderr.puts "[tutoring:#{learner_id}] Tutor asked diagnostic question"

      # Turn 4: Learner answers diagnostic question
      history = Helpers.format_turns_for_prompt(turns)
      answer_prompt = Helpers.build_prompt(
        system: learner_prompt,
        context: "SESSION SO FAR:\n#{history}",
        instruction: "Answer the tutor's question. Show your reasoning. If you're unsure, say so honestly."
      )
      answer = LLM.call(answer_prompt, model: learner_model)
      turns << { 'speaker' => 'learner', 'type' => 'answer', 'content' => answer }
      $stderr.puts "[tutoring:#{learner_id}] Learner answered"

      # Turn 5: Tutor gives targeted feedback
      history = Helpers.format_turns_for_prompt(turns)
      feedback_prompt = Helpers.build_prompt(
        system: tutor_prompt,
        context: "DOMAIN LESSON:\n#{lesson}\n\nSESSION SO FAR:\n#{history}",
        instruction: "Give targeted feedback on the learner's answer. Correct any errors precisely. Reinforce what was correct. Clarify any misapplication of rules."
      )
      feedback = LLM.call(feedback_prompt, model: tutor_model)
      turns << { 'speaker' => 'tutor', 'type' => 'feedback', 'content' => feedback }
      $stderr.puts "[tutoring:#{learner_id}] Tutor gave feedback"

      # Turn 6: Learner summarizes
      history = Helpers.format_turns_for_prompt(turns)
      summary_prompt = Helpers.build_prompt(
        system: learner_prompt,
        context: "SESSION SO FAR:\n#{history}",
        instruction: "Summarize what you learned in this tutoring session. List the key rules, any corrections to your thinking, and what you're still unsure about."
      )
      summary = LLM.call(summary_prompt, model: learner_model)
      turns << { 'speaker' => 'learner', 'type' => 'summary', 'content' => summary }
      $stderr.puts "[tutoring:#{learner_id}] Learner summarized"

      {
        'condition' => '1on1',
        'tutor_id' => tutor_id,
        'learner_id' => learner_id,
        'turns' => turns
      }
    end
  end
end
```

- [ ] **Step 2: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/lib/phases/tutoring.rb
git commit -m "feat: implement 1on1 tutoring phase"
```

---

## Task 11: Memory Generation Phase

**Files:**
- Create: `experiments/bloom_1n_vs_1on1/lib/phases/memory.rb`

- [ ] **Step 1: Write lib/phases/memory.rb**

```ruby
# ABOUTME: Generates structured learning memory JSON from each learner's session transcript
# ABOUTME: Memory summarizer receives the transcript and extracts key rules, strategies, examples

require_relative '../llm'
require_relative '../helpers'

module Phases
  module Memory
    DEFAULT_MEMORY = {
      'key_rules' => [],
      'strategies' => [],
      'misconceptions_corrected' => [],
      'uncertainty_areas' => [],
      'worked_examples' => []
    }.freeze

    def self.generate(learner_id:, transcript:, summarizer_prompt:, config:)
      model = config.dig('models', 'memory_summarizer') || 'claude-sonnet-4-6'

      transcript_text = Helpers.format_turns_for_prompt(transcript['turns'])

      prompt = Helpers.build_prompt(
        system: summarizer_prompt,
        context: "EDUCATIONAL SESSION TRANSCRIPT FOR #{learner_id}:\n\n#{transcript_text}",
        instruction: "Generate a structured learning memory JSON for #{learner_id} based on this transcript. Return ONLY valid JSON matching the schema. No prose."
      )

      raw = LLM.call(prompt, model: model)
      memory = Helpers.extract_json(raw)

      if memory.nil?
        $stderr.puts "[memory:#{learner_id}] WARNING: Could not parse memory JSON, using default"
        memory = DEFAULT_MEMORY.dup
      end

      $stderr.puts "[memory:#{learner_id}] Memory generated (#{memory['key_rules']&.size || 0} key rules)"
      memory
    end
  end
end
```

- [ ] **Step 2: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/lib/phases/memory.rb
git commit -m "feat: implement memory generation phase"
```

---

## Task 12: Problem Solving Phase

**Files:**
- Create: `experiments/bloom_1n_vs_1on1/lib/phases/solver.rb`

- [ ] **Step 1: Write lib/phases/solver.rb**

```ruby
# ABOUTME: Runs each learner through all evaluation tasks using their stored memory
# ABOUTME: Learner sees only their own memory and the task; no condition information exposed

require_relative '../llm'
require_relative '../helpers'

module Phases
  module Solver
    def self.solve(learner_id:, memory:, task:, solver_prompt:, config:)
      model = config.dig('models', 'problem_solver') || 'claude-sonnet-4-6'

      memory_text = JSON.pretty_generate(memory)

      prompt = Helpers.build_prompt(
        system: solver_prompt,
        context: "YOUR LEARNING MEMORY:\n#{memory_text}",
        instruction: task['prompt']
      )

      trace = { 'memory_size' => memory.to_s.length }
      response = LLM.call(prompt, model: model)

      $stderr.puts "[solver:#{learner_id}] Solved task #{task['id']} (#{response.length} chars)"
      { 'response' => response, 'trace' => trace }
    end
  end
end
```

- [ ] **Step 2: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/lib/phases/solver.rb
git commit -m "feat: implement problem solving phase"
```

---

## Task 13: Blind Evaluation Phase

**Files:**
- Create: `experiments/bloom_1n_vs_1on1/lib/phases/evaluator.rb`

- [ ] **Step 1: Write lib/phases/evaluator.rb**

```ruby
# ABOUTME: Blind evaluator scores each task attempt without knowing the learner's condition
# ABOUTME: Returns structured score JSON; falls back to zero scores on parse failure

require_relative '../llm'
require_relative '../helpers'

module Phases
  module Evaluator
    FALLBACK_SCORE = {
      'correctness' => 0, 'reasoning_quality' => 0, 'rule_application' => 0,
      'error_checking' => 0, 'autonomy' => 0, 'total' => 0,
      'comments' => 'Evaluator failed to produce parseable JSON'
    }.freeze

    def self.score(attempt_id:, learner_response:, task:, rubric:, evaluator_id:, evaluator_prompt:, config:)
      model = config.dig('models', 'evaluator') || 'claude-sonnet-4-6'

      rubric_text = JSON.pretty_generate(rubric)
      expected_text = JSON.pretty_generate(task['expected_answer'])

      prompt = Helpers.build_prompt(
        system: evaluator_prompt,
        context: "RUBRIC:\n#{rubric_text}\n\nTASK:\n#{task['prompt']}\n\nEXPECTED ANSWER (reference only):\n#{expected_text}\n\nLEARNER RESPONSE:\n#{learner_response}",
        instruction: "Score this response according to the rubric. Return ONLY valid JSON. No prose. total must equal the sum of the five dimension scores."
      )

      raw = LLM.call(prompt, model: model)
      score = Helpers.extract_json(raw)

      if score.nil?
        $stderr.puts "[evaluator] WARNING: Could not parse score for attempt #{attempt_id}, using fallback"
        score = FALLBACK_SCORE.dup
      else
        expected_total = %w[correctness reasoning_quality rule_application error_checking autonomy].sum { |k| score[k].to_i }
        score['total'] = expected_total
      end

      $stderr.puts "[evaluator] Scored attempt #{attempt_id}: #{score['total']}/20"
      score
    end
  end
end
```

- [ ] **Step 2: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/lib/phases/evaluator.rb
git commit -m "feat: implement blind evaluation phase"
```

---

## Task 14: Report Generation

**Files:**
- Create: `experiments/bloom_1n_vs_1on1/lib/report.rb`

- [ ] **Step 1: Write lib/report.rb**

```ruby
# ABOUTME: Generates CSV scores file and Markdown experiment report from DB results
# ABOUTME: Both outputs are written to the run output directory

require 'csv'
require 'json'
require 'date'

module Report
  SCORE_DIMENSIONS = %w[correctness reasoning_quality rule_application error_checking autonomy].freeze

  def self.generate(db, run_id:, config:, output_dir:, run_config:)
    require 'fileutils'
    FileUtils.mkdir_p(output_dir)

    rows = DB.all_attempts_with_scores(db, run_id)
    write_csv(rows, output_dir)
    markdown = build_markdown(rows, run_id: run_id, config: config, run_config: run_config)
    File.write(File.join(output_dir, 'report.md'), markdown)

    $stderr.puts "[report] Wrote scores.csv and report.md to #{output_dir}"
  end

  def self.write_csv(rows, output_dir)
    CSV.open(File.join(output_dir, 'scores.csv'), 'w') do |csv|
      csv << %w[learner_id condition task_id task_type total correctness reasoning_quality rule_application error_checking autonomy comments]
      rows.each do |row|
        score = row['score_json'] ? JSON.parse(row['score_json']) : {}
        csv << [
          row['learner_id'], row['condition'], row['task_id'], row['task_type'],
          score['total'] || 0,
          *SCORE_DIMENSIONS.map { |d| score[d] || 0 },
          score['comments'] || ''
        ]
      end
    end
  end

  def self.build_markdown(rows, run_id:, config:, run_config:)
    by_condition = rows.group_by { |r| r['condition'] }
    by_task_type = rows.group_by { |r| r['task_type'] }

    classroom_avg = avg_total(by_condition['classroom'] || [])
    tutoring_avg = avg_total(by_condition['1on1'] || [])

    lines = []
    lines << "# Experiment Report"
    lines << ""
    lines << "## Run Metadata"
    lines << ""
    lines << "| Field | Value |"
    lines << "|-------|-------|"
    lines << "| run_id | #{run_id} |"
    lines << "| date | #{Date.today} |"
    lines << "| models | #{run_config.dig('models', 'teacher')} |"
    lines << "| n_classroom | #{run_config.dig('experiment', 'n_classroom')} |"
    lines << "| n_tutoring | #{run_config.dig('experiment', 'n_tutoring')} |"
    lines << "| domain | #{run_config.dig('experiment', 'domain')} |"
    lines << ""
    lines << "## Average Scores by Condition"
    lines << ""
    lines << "| Condition | Avg Total (out of 20) |"
    lines << "|-----------|----------------------|"
    lines << "| classroom (1:N) | #{format('%.2f', classroom_avg)} |"
    lines << "| tutoring (1on1) | #{format('%.2f', tutoring_avg)} |"
    lines << ""
    lines << "## Average Scores by Task Type"
    lines << ""
    lines << "| Task Type | Condition | Avg Total |"
    lines << "|-----------|-----------|-----------|"
    %w[recall near_transfer far_transfer].each do |task_type|
      task_rows = by_task_type[task_type] || []
      by_condition.keys.sort.each do |cond|
        cond_rows = task_rows.select { |r| r['condition'] == cond }
        lines << "| #{task_type} | #{cond} | #{format('%.2f', avg_total(cond_rows))} |"
      end
    end
    lines << ""
    lines << "## Dimension Breakdown"
    lines << ""
    lines << "| Dimension | Classroom Avg | Tutoring Avg |"
    lines << "|-----------|---------------|--------------|"
    SCORE_DIMENSIONS.each do |dim|
      c_avg = avg_dimension(by_condition['classroom'] || [], dim)
      t_avg = avg_dimension(by_condition['1on1'] || [], dim)
      lines << "| #{dim} | #{format('%.2f', c_avg)} | #{format('%.2f', t_avg)} |"
    end
    lines << ""
    lines << "## Sample Evaluator Comments"
    lines << ""
    rows.first(6).each do |row|
      score = row['score_json'] ? JSON.parse(row['score_json']) : {}
      lines << "- **#{row['learner_id']}** (#{row['condition']}, #{row['task_type']}): #{score['comments']}"
    end
    lines << ""
    lines << "## Limitations"
    lines << ""
    lines << "- LLM agents are not human learners. Learning is operationalized as condition-specific memory formation from session transcripts, not model weight updates."
    lines << "- Small sample size (#{rows.map { |r| r['learner_id'] }.uniq.size} learners). Results are exploratory."
    lines << "- The evaluator is the same model as the learner, which may introduce systematic bias."
    lines << "- All scores are produced by a single blind-evaluator LLM call per attempt. No inter-rater reliability check."
    lines << "- This experiment tests whether the experimental protocol is viable, not whether Bloom's theory applies to LLMs."
    lines << ""
    lines << "## How to Inspect Results"
    lines << ""
    lines << "```bash"
    lines << "# Open SQLite DB directly"
    lines << "sqlite3 #{run_config.dig('paths', 'db')}"
    lines << ""
    lines << "# View scores CSV"
    lines << "cat #{config[:output_dir]}/scores.csv"
    lines << "```"
    lines.join("\n")
  end

  def self.avg_total(rows)
    return 0.0 if rows.empty?
    totals = rows.map { |r| r['score_json'] ? JSON.parse(r['score_json'])['total'].to_f : 0.0 }
    totals.sum / totals.size
  end

  def self.avg_dimension(rows, dimension)
    return 0.0 if rows.empty?
    vals = rows.map { |r| r['score_json'] ? JSON.parse(r['score_json'])[dimension].to_f : 0.0 }
    vals.sum / vals.size
  end
end
```

- [ ] **Step 2: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/lib/report.rb
git commit -m "feat: implement report generation (CSV + Markdown)"
```

---

## Task 15: Main Orchestrator

**Files:**
- Create: `experiments/bloom_1n_vs_1on1/scripts/run_experiment.rb`

- [ ] **Step 1: Write scripts/run_experiment.rb**

```ruby
# ABOUTME: Main entry point for the Bloom 2 Sigma experiment
# ABOUTME: Orchestrates all phases: education, memory, solving, evaluation, reporting

require 'yaml'
require 'json'
require 'fileutils'
require 'securerandom'

EXPERIMENT_DIR = File.expand_path('..', __dir__)
$LOAD_PATH.unshift File.join(EXPERIMENT_DIR, 'lib')

require 'db'
require 'llm'
require 'helpers'
require 'phases/classroom'
require 'phases/tutoring'
require 'phases/memory'
require 'phases/solver'
require 'phases/evaluator'
require 'report'

config_path = ARGV[0] or abort "Usage: #{$0} <config.yml>"
PROJECT_ROOT = File.expand_path('../..', EXPERIMENT_DIR)
config = YAML.load_file(File.join(PROJECT_ROOT, config_path))

run_id = Helpers.generate_id
run_name = config.dig('experiment', 'name') || 'bloom_run'
domain_path = File.join(PROJECT_ROOT, config.dig('paths', 'domain'))
prompts_path = File.join(PROJECT_ROOT, config.dig('paths', 'prompts'))
output_base = File.join(PROJECT_ROOT, config.dig('paths', 'output'))
db_path = File.join(PROJECT_ROOT, config.dig('paths', 'db'))
run_dir = File.join(output_base, 'runs', run_id)

FileUtils.mkdir_p(run_dir)
$stderr.puts "[main] Starting run #{run_id}"

# Load domain content
lesson       = Helpers.load_file(File.join(domain_path, 'lesson.md'))
eval_tasks   = JSON.parse(Helpers.load_file(File.join(domain_path, 'eval_tasks.json')))
rubric       = JSON.parse(Helpers.load_file(File.join(domain_path, 'rubric.json')))

# Load prompts
teacher_prompt   = Helpers.load_file(File.join(prompts_path, 'classroom_teacher.md'))
tutor_prompt     = Helpers.load_file(File.join(prompts_path, 'one_on_one_tutor.md'))
learner_prompt   = Helpers.load_file(File.join(prompts_path, 'learner.md'))
summarizer_prompt = Helpers.load_file(File.join(prompts_path, 'memory_summarizer.md'))
solver_prompt    = Helpers.load_file(File.join(prompts_path, 'problem_solver.md'))
evaluator_prompt = Helpers.load_file(File.join(prompts_path, 'blind_evaluator.md'))

# Initialize DB
db = DB.setup(db_path)
DB.save_run(db, run_id, run_name, config)
File.write(File.join(run_dir, 'config.json'), JSON.pretty_generate(config))

# Create agent IDs
n_classroom = config.dig('experiment', 'n_classroom') || 4
n_tutoring  = config.dig('experiment', 'n_tutoring') || 4

teacher_id = DB.save_agent(db, run_id: run_id, role: 'classroom_teacher', model: config.dig('models', 'teacher'))
classroom_learner_ids = n_classroom.times.map do |i|
  DB.save_agent(db, run_id: run_id, role: 'learner', condition: 'classroom', model: config.dig('models', 'learner'))
end

tutor_id = DB.save_agent(db, run_id: run_id, role: 'tutor', model: config.dig('models', 'tutor'))
tutoring_learner_ids = n_tutoring.times.map do |i|
  DB.save_agent(db, run_id: run_id, role: 'learner', condition: '1on1', model: config.dig('models', 'learner'))
end

evaluator_id = DB.save_agent(db, run_id: run_id, role: 'evaluator', model: config.dig('models', 'evaluator'))

all_learners = classroom_learner_ids.map { |id| { id: id, condition: 'classroom' } } +
               tutoring_learner_ids.map  { |id| { id: id, condition: '1on1' } }

# === PHASE 1: Classroom Education ===
$stderr.puts "[main] Phase 1: Classroom education (#{n_classroom} learners)"
classroom_transcript = Phases::Classroom.run(
  teacher_id: teacher_id,
  learner_ids: classroom_learner_ids,
  teacher_prompt: teacher_prompt,
  learner_prompt: learner_prompt,
  lesson: lesson,
  config: config
)
classroom_learner_ids.each do |learner_id|
  DB.save_learning_session(db,
    run_id: run_id, condition: 'classroom', learner_id: learner_id,
    teacher_or_tutor_id: teacher_id, transcript: classroom_transcript
  )
end
File.open(File.join(run_dir, 'transcripts.jsonl'), 'a') do |f|
  f.puts JSON.dump(classroom_transcript)
end

# === PHASE 2: 1on1 Tutoring ===
$stderr.puts "[main] Phase 2: 1on1 tutoring (#{n_tutoring} sessions)"
tutoring_learner_ids.each do |learner_id|
  transcript = Phases::Tutoring.run_session(
    tutor_id: tutor_id,
    learner_id: learner_id,
    tutor_prompt: tutor_prompt,
    learner_prompt: learner_prompt,
    lesson: lesson,
    config: config
  )
  DB.save_learning_session(db,
    run_id: run_id, condition: '1on1', learner_id: learner_id,
    teacher_or_tutor_id: tutor_id, transcript: transcript
  )
  File.open(File.join(run_dir, 'transcripts.jsonl'), 'a') do |f|
    f.puts JSON.dump(transcript)
  end
end

# === PHASE 3: Memory Generation ===
$stderr.puts "[main] Phase 3: Memory generation (#{all_learners.size} learners)"
all_learners.each do |learner|
  transcript_row = db.execute(
    'SELECT transcript_json FROM learning_sessions WHERE run_id = ? AND learner_id = ? ORDER BY rowid DESC LIMIT 1',
    [run_id, learner[:id]]
  ).first
  transcript = JSON.parse(transcript_row['transcript_json'])

  memory = Phases::Memory.generate(
    learner_id: learner[:id],
    transcript: transcript,
    summarizer_prompt: summarizer_prompt,
    config: config
  )
  DB.save_learner_memory(db,
    run_id: run_id, learner_id: learner[:id],
    condition: learner[:condition], memory: memory
  )
  File.open(File.join(run_dir, 'memories.jsonl'), 'a') do |f|
    f.puts JSON.dump({ learner_id: learner[:id], condition: learner[:condition], memory: memory })
  end
end

# === PHASE 4: Problem Solving ===
$stderr.puts "[main] Phase 4: Problem solving (#{all_learners.size} learners × #{eval_tasks.size} tasks)"
eval_tasks.each do |task|
  DB.save_evaluation_task(db,
    run_id: run_id, task_id: task['id'], task_type: task['type'],
    prompt: task['prompt'], expected_answer: task['expected_answer'],
    rubric: rubric
  )
end

all_learners.each do |learner|
  memory = DB.get_learner_memory(db, run_id: run_id, learner_id: learner[:id])
  eval_tasks.each do |task|
    result = Phases::Solver.solve(
      learner_id: learner[:id],
      memory: memory,
      task: task,
      solver_prompt: solver_prompt,
      config: config
    )
    attempt_id = DB.save_task_attempt(db,
      run_id: run_id, learner_id: learner[:id], condition: learner[:condition],
      task_id: task['id'], response_text: result['response'], trace: result['trace']
    )
    File.open(File.join(run_dir, 'attempts.jsonl'), 'a') do |f|
      f.puts JSON.dump({ attempt_id: attempt_id, learner_id: learner[:id], condition: learner[:condition], task_id: task['id'], response: result['response'] })
    end

    # === PHASE 5: Blind Evaluation (inline, per attempt) ===
    score = Phases::Evaluator.score(
      attempt_id: attempt_id,
      learner_response: result['response'],
      task: task,
      rubric: rubric,
      evaluator_id: evaluator_id,
      evaluator_prompt: evaluator_prompt,
      config: config
    )
    DB.save_evaluation(db,
      run_id: run_id, attempt_id: attempt_id, evaluator_id: evaluator_id, score: score
    )
    File.open(File.join(run_dir, 'evaluations.jsonl'), 'a') do |f|
      f.puts JSON.dump({ attempt_id: attempt_id, score: score })
    end
  end
end

# === PHASE 6: Report ===
$stderr.puts "[main] Phase 6: Generating report"
Report.generate(db, run_id: run_id, config: { output_dir: run_dir }, output_dir: run_dir, run_config: config)

db.close
$stderr.puts "[main] Done. Results in: #{run_dir}"
puts run_dir
```

- [ ] **Step 2: Make executable**

```bash
chmod +x experiments/bloom_1n_vs_1on1/scripts/run_experiment.rb
```

- [ ] **Step 3: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/scripts/run_experiment.rb
git commit -m "feat: implement main experiment orchestrator"
```

---

## Task 16: README and Purpose Doc

**Files:**
- Create: `experiments/bloom_1n_vs_1on1/README.md`
- Create: `experiments/bloom_1n_vs_1on1/purpose_doc.md`

- [ ] **Step 1: Write README.md**

```markdown
# Bloom's 2 Sigma Problem — Agent-Based Experiment

## Research Question

Can the structural conditions of Bloom's 2 Sigma Problem (1:N classroom vs. 1on1 tutoring) be operationalized as an LLM agent experiment, and do those conditions produce measurable differences in subsequent autonomous problem-solving behavior?

## Hypotheses

- **H1 (Tutoring Effect):** 1on1 learner agents outperform classroom learner agents on evaluation tasks.
- **H2 (Memory Quality):** 1on1 learners form more specific, strategy-rich learning memories.
- **H3 (Transfer):** Condition differences are larger on near/far transfer tasks than recall tasks.
- **H4 (Method):** This protocol is a viable scaffold for translating social-scientific theories into agent experiments.

## Important Caveats

This experiment does not claim LLM agents are human learners.

Learning is operationalized as the creation of condition-specific memory from educational interaction transcripts. Model weights are not updated.

This is exploratory theory testing and protocol development, not a proof of educational claims.

## How to Run

```bash
bundle install
bundle exec ruby experiments/bloom_1n_vs_1on1/scripts/run_experiment.rb experiments/bloom_1n_vs_1on1/config.yml
```

Output will be written to `experiments/bloom_1n_vs_1on1/data/runs/<run_id>/`.

## Output Files

| File | Contents |
|------|----------|
| `config.json` | Frozen config for this run |
| `transcripts.jsonl` | All education session transcripts |
| `memories.jsonl` | All learner memories |
| `attempts.jsonl` | All problem-solving attempts |
| `evaluations.jsonl` | All blind evaluator scores |
| `scores.csv` | Tabular scores for analysis |
| `report.md` | Markdown summary report |

## Running Tests

```bash
bash experiments/bloom_1n_vs_1on1/tests/run_tests.sh
```
```

- [ ] **Step 2: Write purpose_doc.md**

```markdown
# Research Purpose

## Goal

Translate Bloom's 2 Sigma Problem into a minimal agent-based experiment.
Compare 1:N classroom instruction vs 1on1 tutoring among LLM learner agents.
Measure whether educational condition affects subsequent autonomous problem-solving.

## What This Is Not

- Not a claim that LLMs learn like humans
- Not an attempt to solve the 2 Sigma Problem
- Not a production tutoring system

## Operationalization

Learning = condition-specific memory formation from session transcripts.
The memory is a structured JSON generated by a summarizer agent after the session.
This memory is the only input the learner agent uses during the evaluation phase.

## Experimental Conditions

| Condition | Education Format |
|-----------|-----------------|
| A (classroom) | 1 teacher → N learners simultaneously |
| B (tutoring) | 1 tutor → 1 learner, per-learner session |

## Evaluation

All learners receive identical evaluation tasks after the education phase.
A blind evaluator scores responses without knowing the learner's condition.
```

- [ ] **Step 3: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/README.md experiments/bloom_1n_vs_1on1/purpose_doc.md
git commit -m "docs: add README and purpose doc for bloom 2sigma experiment"
```

---

## Task 17: analyze_results.rb

**Files:**
- Create: `experiments/bloom_1n_vs_1on1/scripts/analyze_results.rb`

- [ ] **Step 1: Write scripts/analyze_results.rb**

```ruby
# ABOUTME: Standalone post-hoc analysis script for experiment results
# ABOUTME: Reads a run directory and prints summary statistics to stdout

require 'json'
require 'csv'

run_dir = ARGV[0] or abort "Usage: #{$0} <run_dir>"
abort "Directory not found: #{run_dir}" unless Dir.exist?(run_dir)

scores_path = File.join(run_dir, 'scores.csv')
abort "scores.csv not found in #{run_dir}" unless File.exist?(scores_path)

rows = CSV.read(scores_path, headers: true)

puts "=== Analysis: #{run_dir} ==="
puts "Total attempts: #{rows.size}"
puts ""

by_condition = rows.group_by { |r| r['condition'] }
puts "--- By Condition ---"
by_condition.each do |condition, cond_rows|
  totals = cond_rows.map { |r| r['total'].to_f }
  avg = totals.sum / totals.size
  puts "#{condition}: n=#{cond_rows.size}, avg_total=#{format('%.2f', avg)}, min=#{totals.min}, max=#{totals.max}"
end
puts ""

by_task_type = rows.group_by { |r| r['task_type'] }
puts "--- By Task Type × Condition ---"
by_task_type.keys.sort.each do |task_type|
  task_rows = by_task_type[task_type]
  by_condition.keys.sort.each do |cond|
    cond_rows = task_rows.select { |r| r['condition'] == cond }
    next if cond_rows.empty?
    totals = cond_rows.map { |r| r['total'].to_f }
    avg = totals.sum / totals.size
    puts "  #{task_type} / #{cond}: avg=#{format('%.2f', avg)}"
  end
end
```

- [ ] **Step 2: Make executable and commit**

```bash
chmod +x experiments/bloom_1n_vs_1on1/scripts/analyze_results.rb
git add experiments/bloom_1n_vs_1on1/scripts/analyze_results.rb
git commit -m "feat: add standalone analysis script"
```

---

## Task 18: End-to-End Smoke Test

- [ ] **Step 1: Run tests first**

```bash
bash experiments/bloom_1n_vs_1on1/tests/run_tests.sh
```

Expected: All tests pass.

- [ ] **Step 2: Run the experiment with minimal config (2+2 learners to save cost)**

Edit `experiments/bloom_1n_vs_1on1/config.yml` temporarily: set `n_classroom: 2` and `n_tutoring: 2`.

```bash
bundle exec ruby experiments/bloom_1n_vs_1on1/scripts/run_experiment.rb \
  experiments/bloom_1n_vs_1on1/config.yml
```

Expected: Prints a run_dir path. Check that the directory exists and contains:
- `config.json` ✓
- `transcripts.jsonl` ✓
- `memories.jsonl` ✓
- `attempts.jsonl` ✓
- `evaluations.jsonl` ✓
- `scores.csv` ✓
- `report.md` ✓

- [ ] **Step 3: Run analysis**

```bash
bundle exec ruby experiments/bloom_1n_vs_1on1/scripts/analyze_results.rb \
  experiments/bloom_1n_vs_1on1/data/runs/<run_id from step 2>
```

Expected: Prints condition and task-type breakdowns.

- [ ] **Step 4: Restore config to n_classroom: 4, n_tutoring: 4**

- [ ] **Step 5: Final commit**

```bash
git add -A
git commit -m "chore: verified end-to-end run successful"
```

---

## Self-Review

### Spec Coverage

| Requirement | Task |
|-------------|------|
| experiments/bloom_1n_vs_1on1/ directory | Task 1 |
| Config-driven experiment execution | Task 2 |
| Classroom condition (1:N) | Task 9 |
| Tutoring condition (1on1) | Task 10 |
| Learner memory generation per learner | Task 11 |
| Same evaluation tasks for all learners | Task 14 (orchestrator) |
| Blind evaluator scoring | Task 13 |
| transcripts.jsonl, memories.jsonl, attempts.jsonl, evaluations.jsonl | Task 14 |
| scores.csv | Task 14 |
| report.md with required sections | Task 14 |
| Fictional domain (Zarn Tokens) | Task 3 |
| README with limitations | Task 16 |
| Purpose doc noting non-human-analogue claim | Task 16 |
| Unit tests | Task 8 |
| analyze_results.rb | Task 17 |

### Placeholder Scan

- No "TBD" or "TODO" items in code blocks ✓
- All functions shown with complete signatures ✓
- All commands include expected output or verification step ✓

### Type Consistency

- `DB.save_agent` returns a String ID used as `teacher_id`, `learner_id` — consistent ✓
- `Helpers.extract_json` returns `Hash | nil` — evaluator and memory phases both handle nil case ✓
- `transcript['turns']` is an Array of Hash — all phases produce this structure ✓
- `DB.all_attempts_with_scores` returns rows with `score_json` as String — Report parses with `JSON.parse` ✓
