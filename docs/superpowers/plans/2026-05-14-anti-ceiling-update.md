# Anti-Ceiling Update Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the trivial eval tasks and bloated education sessions with shorter, harder tasks plus auto-scoring and token tracking to eliminate the 20/20 ceiling effect observed in the first pilot.

**Architecture:** Difficulty-ladder tasks (L1–L6) with machine-checkable expected values enable automatic scoring without LLM calls. A shared `TokenTracker` instance is passed through all phases. The `Scorer` module handles answer/token/mistake matching; LLM evaluator is used only as fallback. Report gains ceiling detection, token metrics, and difficulty breakdown.

**Tech Stack:** Ruby stdlib, sqlite3 gem (no new gems needed)

---

## File Map

```
MODIFIED:
  experiments/bloom_1n_vs_1on1/config.yml
  experiments/bloom_1n_vs_1on1/prompts/memory_summarizer.md
  experiments/bloom_1n_vs_1on1/prompts/problem_solver.md
  experiments/bloom_1n_vs_1on1/lib/llm.rb
  experiments/bloom_1n_vs_1on1/lib/phases/classroom.rb
  experiments/bloom_1n_vs_1on1/lib/phases/tutoring.rb
  experiments/bloom_1n_vs_1on1/lib/phases/memory.rb
  experiments/bloom_1n_vs_1on1/lib/phases/solver.rb
  experiments/bloom_1n_vs_1on1/lib/phases/evaluator.rb
  experiments/bloom_1n_vs_1on1/lib/report.rb
  experiments/bloom_1n_vs_1on1/scripts/run_experiment.rb
  experiments/bloom_1n_vs_1on1/tests/run_tests.sh

CREATED:
  experiments/bloom_1n_vs_1on1/domains/zarn_tokens/eval_tasks_v2.json
  experiments/bloom_1n_vs_1on1/lib/token_tracker.rb
  experiments/bloom_1n_vs_1on1/lib/scorer.rb
  experiments/bloom_1n_vs_1on1/tests/test_scorer.rb
```

---

## Task 1: New Evaluation Tasks (eval_tasks_v2.json)

**Files:**
- Create: `experiments/bloom_1n_vs_1on1/domains/zarn_tokens/eval_tasks_v2.json`

All tasks include the rules in their prompt so learners don't need to recall them from memory alone — the difficulty comes from applying the rules correctly, not from memorization.

Learner response format required for all tasks:
```json
{"answer": "...", "active_tokens": [], "mistakes_found": [], "reason": "<40 words"}
```

- [ ] **Step 1: Create eval_tasks_v2.json**

```json
[
  {
    "id": "l1_recall_01",
    "difficulty": "L1",
    "task_type": "recall",
    "prompt": "Rules:\n- Red: modifier only (0 pts), doubles the token immediately to its right.\n- Blue: active (5 pts) only if Green appears somewhere to its left; else 0.\n- Green: inactive (0) if last in sequence; else active (2).\n- Yellow: always active (7 pts).\n\nCalculate the final score for: [Green, Blue, Yellow]\n\nRespond in JSON only:\n{\"answer\": \"<score>\", \"active_tokens\": [\"list active token names\"], \"mistakes_found\": [], \"reason\": \"<under 40 words>\"}",
    "expected_answer": "14",
    "expected_active_tokens": ["Green", "Blue", "Yellow"],
    "expected_mistakes": [],
    "acceptable_aliases": {"14": ["14 points", "score: 14", "total: 14", "score is 14"]}
  },
  {
    "id": "l2_edge_case_01",
    "difficulty": "L2",
    "task_type": "edge_case",
    "prompt": "Rules:\n- Red: modifier only (0 pts), doubles the token immediately to its right.\n- Blue: active (5 pts) only if Green appears somewhere to its left; else 0.\n- Green: inactive (0) if last in sequence; else active (2).\n- Yellow: always active (7 pts).\n\nCalculate the final score for: [Blue, Green]\n\nRespond in JSON only:\n{\"answer\": \"<score>\", \"active_tokens\": [], \"mistakes_found\": [], \"reason\": \"<under 40 words>\"}",
    "expected_answer": "0",
    "expected_active_tokens": [],
    "expected_mistakes": [],
    "acceptable_aliases": {"0": ["zero", "0 points", "score: 0", "score is 0"]}
  },
  {
    "id": "l2_edge_case_02",
    "difficulty": "L2",
    "task_type": "edge_case",
    "prompt": "Rules:\n- Red: modifier only (0 pts), doubles the token immediately to its right.\n- Blue: active (5 pts) only if Green appears somewhere to its left; else 0.\n- Green: inactive (0) if last in sequence; else active (2).\n- Yellow: always active (7 pts).\n- If a token is inactive, doubling it still gives 0.\n\nCalculate the final score for: [Red, Blue, Yellow]\n\nRespond in JSON only:\n{\"answer\": \"<score>\", \"active_tokens\": [\"list active token names\"], \"mistakes_found\": [], \"reason\": \"<under 40 words>\"}",
    "expected_answer": "7",
    "expected_active_tokens": ["Yellow"],
    "expected_mistakes": [],
    "acceptable_aliases": {"7": ["7 points", "score: 7", "score is 7"]}
  },
  {
    "id": "l3_rule_interaction_01",
    "difficulty": "L3",
    "task_type": "rule_interaction",
    "prompt": "Rules:\n- Red: modifier only (0 pts), doubles the token immediately to its right.\n- Blue: active (5 pts) only if Green appears somewhere to its left; else 0.\n- Green: inactive (0) if last in sequence; else active (2).\n- Yellow: always active (7 pts).\n- If a token is inactive, doubling it still gives 0.\n\nCalculate the final score for: [Green, Red, Blue]\n\nRespond in JSON only:\n{\"answer\": \"<score>\", \"active_tokens\": [\"list active token names\"], \"mistakes_found\": [], \"reason\": \"<under 40 words>\"}",
    "expected_answer": "12",
    "expected_active_tokens": ["Green", "Blue"],
    "expected_mistakes": [],
    "acceptable_aliases": {"12": ["12 points", "score: 12", "score is 12"]}
  },
  {
    "id": "l4_debug_01",
    "difficulty": "L4",
    "task_type": "debugging",
    "prompt": "Rules:\n- Red: modifier only (0 pts), doubles the token immediately to its right.\n- Blue: active (5 pts) only if Green appears somewhere to its left; else 0.\n- Green: inactive (0) if last in sequence; else active (2).\n- Yellow: always active (7 pts).\n- If a token is inactive, doubling it still gives 0.\n\nA student solved [Green, Red, Blue, Yellow, Green] and wrote:\n\"Score = 2 + 10 + 7 + 2 = 21\"\n\nFind ALL mistakes and give the correct score.\n\nRespond in JSON only:\n{\"answer\": \"<correct score>\", \"active_tokens\": [\"list actually active token names\"], \"mistakes_found\": [\"describe each mistake\"], \"reason\": \"<under 40 words>\"}",
    "expected_answer": "19",
    "expected_active_tokens": ["Green", "Blue", "Yellow"],
    "expected_mistakes": ["Green at last position is inactive"],
    "acceptable_aliases": {"19": ["19 points", "score: 19", "score is 19"]}
  },
  {
    "id": "l4_debug_02",
    "difficulty": "L4",
    "task_type": "debugging",
    "prompt": "Rules:\n- Red: modifier only (0 pts), doubles the token immediately to its right.\n- Blue: active (5 pts) only if Green appears somewhere to its left; else 0.\n- Green: inactive (0) if last in sequence; else active (2).\n- Yellow: always active (7 pts).\n- If a token is inactive, doubling it still gives 0.\n\nA student solved [Blue, Red, Green] and wrote:\n\"Score = 0 + 0 + 4 = 4, because Red doubles Green to 4\"\n\nFind ALL mistakes and give the correct score.\n\nRespond in JSON only:\n{\"answer\": \"<correct score>\", \"active_tokens\": [], \"mistakes_found\": [\"describe each mistake\"], \"reason\": \"<under 40 words>\"}",
    "expected_answer": "0",
    "expected_active_tokens": [],
    "expected_mistakes": ["Green at last position is inactive", "inactive tokens cannot be activated by Red"],
    "acceptable_aliases": {"0": ["zero", "0 points", "score: 0"]}
  },
  {
    "id": "l5_counterexample_01",
    "difficulty": "L5",
    "task_type": "counterexample",
    "prompt": "Rules:\n- Red: modifier only (0 pts), doubles the token immediately to its right.\n- Blue: active (5 pts) only if Green appears somewhere to its left; else 0.\n- Green: inactive (0) if last in sequence; else active (2).\n- Yellow: always active (7 pts).\n\nClaim: \"If a sequence contains at least one Green that is not at the last position, then every Blue token in the sequence is active.\"\n\nTrue or false? If false, give a sequence where at least one Blue is still inactive despite a non-final Green existing.\n\nRespond in JSON only:\n{\"answer\": \"false\", \"active_tokens\": [\"active tokens in your counterexample\"], \"mistakes_found\": [\"which Blue is inactive and why\"], \"reason\": \"<under 40 words>\"}",
    "expected_answer": "false",
    "expected_active_tokens": ["Green", "Blue"],
    "expected_mistakes": ["Blue before Green has no Green to its left"],
    "acceptable_aliases": {"false": ["False", "FALSE", "no", "incorrect", "the claim is false"]}
  },
  {
    "id": "l6_induction_01",
    "difficulty": "L6",
    "task_type": "short_rule_induction",
    "prompt": "Standard rules:\n- Red: modifier only (0 pts), doubles the token immediately to its right.\n- Blue: active (5 pts) only if Green appears somewhere to its left; else 0.\n- Green: inactive (0) if last in sequence; else active (2).\n- Yellow: always active (7 pts).\n- If a token is inactive, doubling it still gives 0.\n\nNew token: Orange Zarn (base value 4).\nNew rule: Orange is active (4 pts) only if the token IMMEDIATELY to its left is Yellow. Otherwise Orange is inactive (0).\n\nCalculate the score for: [Yellow, Orange, Blue, Green]\n\nRespond in JSON only:\n{\"answer\": \"<score>\", \"active_tokens\": [\"list active token names\"], \"mistakes_found\": [], \"reason\": \"<under 40 words>\"}",
    "expected_answer": "11",
    "expected_active_tokens": ["Yellow", "Orange"],
    "expected_mistakes": [],
    "acceptable_aliases": {"11": ["11 points", "score: 11", "score is 11"]}
  }
]
```

- [ ] **Step 2: Verify valid JSON**

```bash
cd /Users/masumi/tmp/Agent-Based-Theory-Testing-2-Sigma-Problem
ruby -e "require 'json'; JSON.parse(File.read('experiments/bloom_1n_vs_1on1/domains/zarn_tokens/eval_tasks_v2.json')); puts 'valid JSON, #{$_.size rescue 0} tasks'"
```

Actually run:
```bash
bundle exec ruby -e "
require 'json'
tasks = JSON.parse(File.read('experiments/bloom_1n_vs_1on1/domains/zarn_tokens/eval_tasks_v2.json'))
puts \"#{tasks.size} tasks: #{tasks.map { |t| t['id'] }.join(', ')}\"
"
```

Expected: `8 tasks: l1_recall_01, l2_edge_case_01, l2_edge_case_02, l3_rule_interaction_01, l4_debug_01, l4_debug_02, l5_counterexample_01, l6_induction_01`

- [ ] **Step 3: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/domains/zarn_tokens/eval_tasks_v2.json
git commit -m "feat: add L1-L6 eval tasks with machine-checkable expected values"
```

---

## Task 2: Update Config and Prompts

**Files:**
- Modify: `experiments/bloom_1n_vs_1on1/config.yml`
- Modify: `experiments/bloom_1n_vs_1on1/prompts/memory_summarizer.md`
- Modify: `experiments/bloom_1n_vs_1on1/prompts/problem_solver.md`

- [ ] **Step 1: Update config.yml**

Replace the entire file content with:

```yaml
experiment:
  name: "bloom_1n_vs_1on1_v2"
  domain: "zarn_tokens"
  n_classroom: 4
  n_tutoring: 4
  classroom_questions_per_learner: 1
  tutoring_turns: 2
  eval_tasks_file: "eval_tasks_v2.json"
  max_memory_words: 120
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
  db: "experiments/bloom_1n_vs_1on1/data/experiment.db"
```

- [ ] **Step 2: Rewrite memory_summarizer.md**

Replace entire file:

```markdown
You are a learning memory compressor.

Analyze the educational session transcript and extract a compact structured memory for the learner.

Output ONLY valid JSON. No prose before or after. Total output must be under 120 words.

Schema:
{
  "rules": ["one rule per item — be concise, max 12 words each"],
  "mistakes": ["common mistakes to avoid — max 12 words each"],
  "strategy": ["step-by-step problem approach — max 12 words each"],
  "edge_cases": ["tricky conditions to check — max 12 words each"]
}

Constraints:
- Maximum 8 items total across all arrays
- No examples with long sequences
- No repetition across fields
- If the learner had misconceptions corrected, include them under "mistakes"
```

- [ ] **Step 3: Rewrite problem_solver.md**

Replace entire file:

```markdown
You are a learner solving a problem using your learning memory.

Your memory contains the rules you learned. Apply them carefully to the problem.

IMPORTANT: Respond ONLY with valid JSON in exactly this format — no text outside the JSON:

{
  "answer": "<your numeric answer, or true/false for claim tasks>",
  "active_tokens": ["<token names that are active in the final sequence>"],
  "mistakes_found": ["<for debugging tasks: describe each mistake you found>"],
  "reason": "<your reasoning in under 40 words>"
}

Do not include any text, explanation, or prose outside this JSON object.
```

- [ ] **Step 4: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/config.yml \
        experiments/bloom_1n_vs_1on1/prompts/memory_summarizer.md \
        experiments/bloom_1n_vs_1on1/prompts/problem_solver.md
git commit -m "feat: update config for v2 and rewrite memory/solver prompts for compactness"
```

---

## Task 3: TokenTracker Module + LLM Update

**Files:**
- Create: `experiments/bloom_1n_vs_1on1/lib/token_tracker.rb`
- Modify: `experiments/bloom_1n_vs_1on1/lib/llm.rb`

- [ ] **Step 1: Create lib/token_tracker.rb**

```ruby
# ABOUTME: Accumulates estimated token usage per phase across an experiment run
# ABOUTME: Estimates input/output tokens from character counts (1 token ≈ 4 chars)

class TokenTracker
  CHARS_PER_TOKEN = 4.0

  def initialize
    @phase_totals = Hash.new { |h, k| h[k] = { input: 0, output: 0 } }
  end

  def track(phase, prompt, response)
    input  = (prompt.to_s.length  / CHARS_PER_TOKEN).ceil
    output = (response.to_s.length / CHARS_PER_TOKEN).ceil
    @phase_totals[phase.to_s][:input]  += input
    @phase_totals[phase.to_s][:output] += output
    input + output
  end

  def summary
    @phase_totals.transform_values do |counts|
      {
        'input_tokens'  => counts[:input],
        'output_tokens' => counts[:output],
        'total_tokens'  => counts[:input] + counts[:output]
      }
    end
  end

  def total_for_phase(phase)
    t = @phase_totals[phase.to_s]
    t[:input] + t[:output]
  end

  def grand_total
    @phase_totals.values.sum { |v| v[:input] + v[:output] }
  end
end
```

- [ ] **Step 2: Update lib/llm.rb to accept optional tracker**

Replace the entire file:

```ruby
# ABOUTME: Thin wrapper around `claude --print` for synchronous LLM calls
# ABOUTME: Accepts optional TokenTracker and phase name for token usage tracking

require 'open3'

module LLM
  def self.call(prompt, model: nil, tracker: nil, phase: nil)
    args = ['claude', '--print']
    args += ['--model', model] if model
    stdout, stderr, status = Open3.capture3(*args, stdin_data: prompt)
    unless status.success?
      raise "LLM call failed (exit #{status.exitstatus}): #{stderr.strip}"
    end
    text = stdout.strip
    tracker.track(phase, prompt, text) if tracker && phase
    text
  end
end
```

- [ ] **Step 3: Verify syntax**

```bash
bundle exec ruby -c experiments/bloom_1n_vs_1on1/lib/token_tracker.rb
bundle exec ruby -c experiments/bloom_1n_vs_1on1/lib/llm.rb
```

Expected: `Syntax OK` for both.

- [ ] **Step 4: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/lib/token_tracker.rb \
        experiments/bloom_1n_vs_1on1/lib/llm.rb
git commit -m "feat: add TokenTracker module and optional tracking params to LLM.call"
```

---

## Task 4: Scorer Module (TDD)

**Files:**
- Create: `experiments/bloom_1n_vs_1on1/tests/test_scorer.rb` (write first)
- Create: `experiments/bloom_1n_vs_1on1/lib/scorer.rb` (write to make tests pass)

- [ ] **Step 1: Write the failing tests**

Create `experiments/bloom_1n_vs_1on1/tests/test_scorer.rb`:

```ruby
# ABOUTME: Tests for the auto-scorer and token tracker pure logic
# ABOUTME: No LLM calls; all deterministic inputs and outputs

$LOAD_PATH.unshift File.join(__dir__, '..', 'lib')
require 'minitest/autorun'
require 'token_tracker'

# ------------------------------------------------------------------
# TokenTracker tests
# ------------------------------------------------------------------
class TestTokenTracker < Minitest::Test
  def test_tracks_single_call
    t = TokenTracker.new
    t.track('education', 'a' * 400, 'b' * 200)
    summary = t.summary
    assert_equal 100, summary['education']['input_tokens']
    assert_equal 50,  summary['education']['output_tokens']
    assert_equal 150, summary['education']['total_tokens']
  end

  def test_accumulates_same_phase
    t = TokenTracker.new
    t.track('education', 'a' * 400, 'b' * 200)
    t.track('education', 'c' * 400, 'd' * 200)
    assert_equal 300, t.summary['education']['total_tokens']
  end

  def test_separate_phases_are_independent
    t = TokenTracker.new
    t.track('education', 'a' * 400, 'b' * 200)
    t.track('memory',    'c' * 800, 'd' * 100)
    assert_equal 150, t.total_for_phase('education')
    assert_equal 225, t.total_for_phase('memory')
  end

  def test_grand_total_sums_all_phases
    t = TokenTracker.new
    t.track('education', 'a' * 400, 'b' * 200)
    t.track('memory',    'c' * 400, 'd' * 200)
    assert_equal 300, t.grand_total
  end

  def test_unknown_phase_returns_zero
    t = TokenTracker.new
    assert_equal 0, t.total_for_phase('nonexistent')
  end
end

# ------------------------------------------------------------------
# Scorer tests (require scorer to be implemented)
# ------------------------------------------------------------------
require 'scorer'

class TestScorerCorrectAnswer < Minitest::Test
  def recall_task
    {
      'expected_answer' => '14',
      'expected_active_tokens' => ['Green', 'Blue', 'Yellow'],
      'expected_mistakes' => [],
      'acceptable_aliases' => { '14' => ['14 points', 'score: 14'] }
    }
  end

  def test_correct_answer_scores_4
    parsed = { 'answer' => '14', 'active_tokens' => ['Green', 'Blue', 'Yellow'], 'mistakes_found' => [], 'reason' => 'ok' }
    score = Scorer.score_attempt(parsed, recall_task)
    assert_equal true,  score['answer_correct']
    assert_equal 4,     score['correctness']
    assert_equal true,  score['auto_scored']
  end

  def test_wrong_answer_scores_0
    parsed = { 'answer' => '9', 'active_tokens' => [], 'mistakes_found' => [], 'reason' => 'wrong' }
    score = Scorer.score_attempt(parsed, recall_task)
    assert_equal false, score['answer_correct']
    assert_equal 0,     score['correctness']
  end

  def test_alias_is_accepted
    parsed = { 'answer' => '14 points', 'active_tokens' => [], 'mistakes_found' => [], 'reason' => 'ok' }
    score = Scorer.score_attempt(parsed, recall_task)
    assert_equal true, score['answer_correct']
  end

  def test_case_insensitive_answer_match
    parsed = { 'answer' => 'FALSE', 'active_tokens' => [], 'mistakes_found' => [], 'reason' => 'ok' }
    task = { 'expected_answer' => 'false', 'expected_active_tokens' => [], 'expected_mistakes' => [], 'acceptable_aliases' => {} }
    score = Scorer.score_attempt(parsed, task)
    assert_equal true, score['answer_correct']
  end
end

class TestScorerActiveTokens < Minitest::Test
  def test_correct_tokens_scores_4
    parsed = { 'answer' => '14', 'active_tokens' => ['Blue', 'Green', 'Yellow'], 'mistakes_found' => [], 'reason' => 'ok' }
    task = { 'expected_answer' => '14', 'expected_active_tokens' => ['Green', 'Blue', 'Yellow'], 'expected_mistakes' => [], 'acceptable_aliases' => {} }
    score = Scorer.score_attempt(parsed, task)
    assert_equal 4, score['rule_application']
    assert_equal true, score['active_tokens_correct']
  end

  def test_wrong_tokens_scores_0
    parsed = { 'answer' => '14', 'active_tokens' => ['Red', 'Green'], 'mistakes_found' => [], 'reason' => 'ok' }
    task = { 'expected_answer' => '14', 'expected_active_tokens' => ['Green', 'Blue', 'Yellow'], 'expected_mistakes' => [], 'acceptable_aliases' => {} }
    score = Scorer.score_attempt(parsed, task)
    assert_equal 0, score['rule_application']
    assert_equal false, score['active_tokens_correct']
  end
end

class TestScorerMistakes < Minitest::Test
  def debug_task
    {
      'expected_answer' => '19',
      'expected_active_tokens' => ['Green', 'Blue', 'Yellow'],
      'expected_mistakes' => ['Green at last position is inactive'],
      'acceptable_aliases' => {}
    }
  end

  def test_mistake_keyword_match_scores_4
    parsed = {
      'answer' => '19',
      'active_tokens' => ['Green', 'Blue', 'Yellow'],
      'mistakes_found' => ['Green at last position is inactive and should be 0'],
      'reason' => 'ok'
    }
    score = Scorer.score_attempt(parsed, debug_task)
    assert score['mistakes_found_ratio'] >= 0.5
    assert_equal 4, score['error_checking']
  end

  def test_missing_mistake_scores_0
    parsed = { 'answer' => '19', 'active_tokens' => [], 'mistakes_found' => [], 'reason' => 'ok' }
    score = Scorer.score_attempt(parsed, debug_task)
    assert_equal 0, score['error_checking']
  end
end

class TestScorerNilInput < Minitest::Test
  def test_nil_response_returns_safe_fallback
    task = { 'expected_answer' => '14', 'expected_active_tokens' => [], 'expected_mistakes' => [], 'acceptable_aliases' => {} }
    score = Scorer.score_attempt(nil, task)
    assert_equal false, score['answer_correct']
    assert_equal 0,     score['total']
    assert_equal true,  score['auto_scored']
    assert_includes     score['comments'], 'parse'
  end

  def test_empty_hash_response_returns_safe_fallback
    task = { 'expected_answer' => '14', 'expected_active_tokens' => [], 'expected_mistakes' => [], 'acceptable_aliases' => {} }
    score = Scorer.score_attempt({}, task)
    assert_equal false, score['answer_correct']
    assert_equal true,  score['auto_scored']
  end
end
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
cd /Users/masumi/tmp/Agent-Based-Theory-Testing-2-Sigma-Problem
bundle exec ruby experiments/bloom_1n_vs_1on1/tests/test_scorer.rb 2>&1 | tail -5
```

Expected: errors like `cannot load such file -- scorer` — confirming the tests need implementation.

- [ ] **Step 3: Implement lib/scorer.rb**

```ruby
# ABOUTME: Automatic scoring for eval tasks with machine-checkable expected values
# ABOUTME: Matches answer strings, active token lists, and mistake keywords

module Scorer
  def self.score_attempt(parsed_response, task)
    return nil_score('Could not parse learner response as JSON') unless parsed_response.is_a?(Hash) && !parsed_response.empty?

    expected_answer  = task['expected_answer'].to_s.strip.downcase
    expected_tokens  = (task['expected_active_tokens'] || []).map { |t| t.to_s.downcase.strip }.sort
    expected_mistakes = task['expected_mistakes'] || []
    aliases          = task['acceptable_aliases'] || {}

    given_answer = parsed_response['answer'].to_s.strip.downcase
    given_tokens = (parsed_response['active_tokens'] || []).map { |t| t.to_s.downcase.strip }.sort
    given_mistakes = parsed_response['mistakes_found'] || []

    # Check answer: exact match or alias match
    answer_correct = given_answer == expected_answer
    unless answer_correct
      aliases.each do |_key, vals|
        answer_correct = true if Array(vals).map { |v| v.to_s.downcase }.include?(given_answer)
      end
    end

    # Check active tokens (order-independent)
    tokens_correct = given_tokens == expected_tokens

    # Check mistakes found: keyword overlap (for debugging tasks)
    mistakes_ratio = if expected_mistakes.empty?
      1.0
    else
      matched = expected_mistakes.count { |em|
        keywords = em.downcase.split(/\W+/).select { |w| w.length > 3 }
        given_mistakes.any? { |gm| keywords.any? { |kw| gm.to_s.downcase.include?(kw) } }
      }
      matched.to_f / expected_mistakes.size
    end

    correctness   = answer_correct ? 4 : 0
    rule_app      = tokens_correct ? 4 : 0
    error_check   = case mistakes_ratio
                    when 1.0       then 4
                    when 0.5..0.99 then 2
                    else                0
                    end

    total = correctness + rule_app + error_check

    {
      'answer_correct'       => answer_correct,
      'active_tokens_correct' => tokens_correct,
      'mistakes_found_ratio' => mistakes_ratio.round(2),
      'correctness'          => correctness,
      'reasoning_quality'    => 0,
      'rule_application'     => rule_app,
      'error_checking'       => error_check,
      'autonomy'             => 0,
      'total'                => total,
      'auto_scored'          => true,
      'comments'             => build_comment(answer_correct, tokens_correct, mistakes_ratio)
    }
  end

  def self.nil_score(reason = 'Scoring failed')
    {
      'answer_correct' => false, 'active_tokens_correct' => false,
      'mistakes_found_ratio' => 0.0, 'correctness' => 0,
      'reasoning_quality' => 0, 'rule_application' => 0,
      'error_checking' => 0, 'autonomy' => 0, 'total' => 0,
      'auto_scored' => true, 'comments' => "Auto: #{reason}"
    }
  end

  def self.build_comment(answer_correct, tokens_correct, mistakes_ratio)
    parts = [answer_correct ? 'answer correct' : 'answer wrong']
    parts << (tokens_correct ? 'tokens matched' : 'token mismatch')
    parts << "mistakes #{(mistakes_ratio * 100).round}%" unless mistakes_ratio == 1.0
    "Auto: #{parts.join(', ')}"
  end
end
```

- [ ] **Step 4: Run tests to confirm they pass**

```bash
bundle exec ruby experiments/bloom_1n_vs_1on1/tests/test_scorer.rb
```

Expected:
```
# Running:
.....................
21 runs, N assertions, 0 failures, 0 errors, 0 skips
```

- [ ] **Step 5: Update run_tests.sh to include the new test file**

In `experiments/bloom_1n_vs_1on1/tests/run_tests.sh`, add before the final `echo` line:
```bash
bundle exec ruby "$EXPERIMENT_DIR/tests/test_scorer.rb"
```

- [ ] **Step 6: Run full test suite**

```bash
bash experiments/bloom_1n_vs_1on1/tests/run_tests.sh
```

Expected: `All tests passed.`

- [ ] **Step 7: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/lib/scorer.rb \
        experiments/bloom_1n_vs_1on1/tests/test_scorer.rb \
        experiments/bloom_1n_vs_1on1/tests/run_tests.sh
git commit -m "feat: add auto-scorer module and token tracker tests (TDD)"
```

---

## Task 5: Shorten Classroom Phase

**Files:**
- Modify: `experiments/bloom_1n_vs_1on1/lib/phases/classroom.rb`

Remove the per-learner notes step (Step 4 in the current file). Add `tracker:` and `phase:` to all `LLM.call` invocations.

- [ ] **Step 1: Replace entire classroom.rb**

```ruby
# ABOUTME: Orchestrates the 1:N classroom education phase for the A-group learners
# ABOUTME: Teacher lectures; learners ask one question each; teacher answers publicly

require_relative '../llm'
require_relative '../helpers'

module Phases
  module Classroom
    def self.run(teacher_id:, learner_ids:, teacher_prompt:, learner_prompt:, lesson:, config:, tracker: nil)
      model        = config.dig('models', 'teacher') || 'claude-sonnet-4-6'
      learner_model = config.dig('models', 'learner') || 'claude-sonnet-4-6'

      turns = []

      # Step 1: Teacher delivers lecture
      lecture_prompt = Helpers.build_prompt(
        system: teacher_prompt,
        context: "DOMAIN LESSON:\n#{lesson}",
        instruction: "Deliver a clear, structured lesson to all learners. Cover all rules with examples. End with: \"Are there any questions?\""
      )
      lecture = LLM.call(lecture_prompt, model: model, tracker: tracker, phase: 'education_classroom')
      turns << { 'speaker' => 'teacher', 'type' => 'lecture', 'content' => lecture }
      $stderr.puts "[classroom] Teacher delivered lecture (#{lecture.length} chars)"

      # Step 2: Each learner asks one question
      questions = learner_ids.map do |learner_id|
        question_prompt = Helpers.build_prompt(
          system: learner_prompt,
          context: "CLASS LECTURE:\n#{lecture}",
          instruction: "You are #{learner_id}. Ask ONE question about something you want to clarify. If you understood everything, write exactly: No questions."
        )
        question = LLM.call(question_prompt, model: learner_model, tracker: tracker, phase: 'education_classroom')
        turns << { 'speaker' => learner_id, 'type' => 'question', 'content' => question }
        $stderr.puts "[classroom] #{learner_id} asked question"
        { learner_id: learner_id, question: question }
      end

      real_questions = questions.reject { |q| q[:question].strip.downcase.start_with?('no questions') }

      # Step 3: Teacher answers all questions in one response
      if real_questions.any?
        questions_text = real_questions.map { |q| "#{q[:learner_id]}: #{q[:question]}" }.join("\n\n")
        answer_prompt = Helpers.build_prompt(
          system: teacher_prompt,
          context: "DOMAIN LESSON:\n#{lesson}\n\nLECTURE DELIVERED:\n#{lecture}",
          instruction: "Answer these student questions publicly. Address each question clearly.\n\n#{questions_text}"
        )
        answers = LLM.call(answer_prompt, model: model, tracker: tracker, phase: 'education_classroom')
        turns << { 'speaker' => 'teacher', 'type' => 'answers', 'content' => answers }
        $stderr.puts "[classroom] Teacher answered questions"
      end

      {
        'condition'   => 'classroom',
        'teacher_id'  => teacher_id,
        'learner_ids' => learner_ids,
        'turns'       => turns
      }
    end
  end
end
```

- [ ] **Step 2: Verify syntax**

```bash
bundle exec ruby -c experiments/bloom_1n_vs_1on1/lib/phases/classroom.rb
```

Expected: `Syntax OK`

- [ ] **Step 3: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/lib/phases/classroom.rb
git commit -m "feat: shorten classroom phase (remove notes step, add token tracking)"
```

---

## Task 6: Shorten Tutoring Phase

**Files:**
- Modify: `experiments/bloom_1n_vs_1on1/lib/phases/tutoring.rb`

Reduce from 6 turns to 4 turns (2 exchanges). Remove feedback and summary turns.

- [ ] **Step 1: Replace entire tutoring.rb**

```ruby
# ABOUTME: Orchestrates individual 1on1 tutoring sessions for each B-group learner
# ABOUTME: Two exchanges per learner: opener+response, diagnostic question+answer

require_relative '../llm'
require_relative '../helpers'

module Phases
  module Tutoring
    def self.run_session(tutor_id:, learner_id:, tutor_prompt:, learner_prompt:, lesson:, config:, tracker: nil)
      tutor_model   = config.dig('models', 'tutor')   || 'claude-sonnet-4-6'
      learner_model = config.dig('models', 'learner') || 'claude-sonnet-4-6'

      turns = []

      # Exchange 1, Turn 1: Tutor opens session
      opener_prompt = Helpers.build_prompt(
        system: tutor_prompt,
        context: "DOMAIN LESSON MATERIAL:\n#{lesson}",
        instruction: "Begin a tutoring session with #{learner_id}. Introduce the topic briefly and start teaching the first key concept. Be concise — under 120 words."
      )
      opener = LLM.call(opener_prompt, model: tutor_model, tracker: tracker, phase: 'education_tutoring')
      turns << { 'speaker' => 'tutor', 'type' => 'opener', 'content' => opener }
      $stderr.puts "[tutoring:#{learner_id}] Tutor opened session"

      # Exchange 1, Turn 2: Learner responds
      response_prompt = Helpers.build_prompt(
        system: learner_prompt,
        context: "TUTOR SAID:\n#{opener}",
        instruction: "Respond to your tutor. Ask a question if something is unclear, or confirm your understanding in 1-2 sentences."
      )
      response = LLM.call(response_prompt, model: learner_model, tracker: tracker, phase: 'education_tutoring')
      turns << { 'speaker' => 'learner', 'type' => 'response', 'content' => response }
      $stderr.puts "[tutoring:#{learner_id}] Learner responded"

      # Exchange 2, Turn 3: Tutor asks diagnostic question
      history = Helpers.format_turns_for_prompt(turns)
      diagnostic_prompt = Helpers.build_prompt(
        system: tutor_prompt,
        context: "DOMAIN LESSON:\n#{lesson}\n\nSESSION SO FAR:\n#{history}",
        instruction: "Ask ONE short diagnostic question to test the learner's understanding of a specific rule. Require application, not recitation. Under 60 words."
      )
      diagnostic = LLM.call(diagnostic_prompt, model: tutor_model, tracker: tracker, phase: 'education_tutoring')
      turns << { 'speaker' => 'tutor', 'type' => 'diagnostic_question', 'content' => diagnostic }
      $stderr.puts "[tutoring:#{learner_id}] Tutor asked diagnostic question"

      # Exchange 2, Turn 4: Learner answers
      history = Helpers.format_turns_for_prompt(turns)
      answer_prompt = Helpers.build_prompt(
        system: learner_prompt,
        context: "SESSION SO FAR:\n#{history}",
        instruction: "Answer the tutor's question. Show your reasoning briefly. If unsure, say so."
      )
      answer = LLM.call(answer_prompt, model: learner_model, tracker: tracker, phase: 'education_tutoring')
      turns << { 'speaker' => 'learner', 'type' => 'answer', 'content' => answer }
      $stderr.puts "[tutoring:#{learner_id}] Learner answered"

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

- [ ] **Step 2: Verify syntax**

```bash
bundle exec ruby -c experiments/bloom_1n_vs_1on1/lib/phases/tutoring.rb
```

Expected: `Syntax OK`

- [ ] **Step 3: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/lib/phases/tutoring.rb
git commit -m "feat: shorten tutoring to 4 turns (2 exchanges), add token tracking"
```

---

## Task 7: Update Memory Phase

**Files:**
- Modify: `experiments/bloom_1n_vs_1on1/lib/phases/memory.rb`

New compact memory format (4 fields instead of 5), word count enforcement, tracker support.

- [ ] **Step 1: Replace entire memory.rb**

```ruby
# ABOUTME: Generates compact structured learning memory from each learner's session transcript
# ABOUTME: Enforces 120-word limit; falls back to empty default if JSON parse fails

require_relative '../llm'
require_relative '../helpers'

module Phases
  module Memory
    MAX_WORDS = 120
    DEFAULT_MEMORY = { 'rules' => [], 'mistakes' => [], 'strategy' => [], 'edge_cases' => [] }.freeze

    def self.generate(learner_id:, transcript:, summarizer_prompt:, config:, tracker: nil)
      model = config.dig('models', 'memory_summarizer') || 'claude-sonnet-4-6'
      max_words = config.dig('experiment', 'max_memory_words') || MAX_WORDS

      transcript_text = Helpers.format_turns_for_prompt(transcript['turns'])

      prompt = Helpers.build_prompt(
        system: summarizer_prompt,
        context: "EDUCATIONAL SESSION TRANSCRIPT FOR #{learner_id}:\n\n#{transcript_text}",
        instruction: "Generate a compact learning memory JSON for #{learner_id}. Return ONLY valid JSON. No prose."
      )

      raw = LLM.call(prompt, model: model, tracker: tracker, phase: 'memory')
      $stderr.puts "[memory:#{learner_id}] LLM returned raw memory (#{raw.length} chars)"

      memory = Helpers.extract_json(raw)

      if memory.nil?
        $stderr.puts "[memory:#{learner_id}] WARNING: Could not parse memory JSON, using default"
        return DEFAULT_MEMORY.transform_values(&:dup)
      end

      memory = enforce_word_limit(memory, max_words)
      $stderr.puts "[memory:#{learner_id}] Memory generated (#{word_count(memory)} words, #{memory.values.flatten.size} items)"
      memory
    end

    def self.enforce_word_limit(memory, max_words)
      return memory if word_count(memory) <= max_words

      # Trim each array by half until under limit
      result = memory.transform_values { |arr| arr.is_a?(Array) ? arr.dup : arr }
      while word_count(result) > max_words
        longest_key = result.select { |_, v| v.is_a?(Array) && v.size > 0 }
                             .max_by { |_, v| v.join(' ').split.size }
                             &.first
        break unless longest_key
        result[longest_key] = result[longest_key][0..-2]
      end
      result
    end

    def self.word_count(memory)
      memory.values.flatten.join(' ').split.size
    end
  end
end
```

- [ ] **Step 2: Verify syntax**

```bash
bundle exec ruby -c experiments/bloom_1n_vs_1on1/lib/phases/memory.rb
```

- [ ] **Step 3: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/lib/phases/memory.rb
git commit -m "feat: update memory phase for compact format, word limit, token tracking"
```

---

## Task 8: Update Solver Phase

**Files:**
- Modify: `experiments/bloom_1n_vs_1on1/lib/phases/solver.rb`

Parse JSON response, retry once on parse failure, expose `parsed` field in return value, add tracker.

- [ ] **Step 1: Replace entire solver.rb**

```ruby
# ABOUTME: Runs each learner through evaluation tasks; parses JSON response with one retry on failure
# ABOUTME: Returns both raw response text and parsed JSON for auto-scoring downstream

require 'json'
require_relative '../llm'
require_relative '../helpers'

module Phases
  module Solver
    PARSE_FAILED = { 'answer' => '', 'active_tokens' => [], 'mistakes_found' => [], 'reason' => 'parse failed' }.freeze

    def self.solve(learner_id:, memory:, task:, solver_prompt:, config:, tracker: nil)
      model = config.dig('models', 'problem_solver') || 'claude-sonnet-4-6'

      memory_text = JSON.pretty_generate(memory)
      prompt = Helpers.build_prompt(
        system: solver_prompt,
        context: "YOUR LEARNING MEMORY:\n#{memory_text}",
        instruction: task['prompt']
      )

      response = LLM.call(prompt, model: model, tracker: tracker, phase: 'evaluation')
      parsed   = Helpers.extract_json(response)

      if parsed.nil?
        $stderr.puts "[solver:#{learner_id}] WARNING: non-JSON response, retrying once"
        retry_prompt = Helpers.build_prompt(
          system: solver_prompt,
          context: "YOUR LEARNING MEMORY:\n#{memory_text}",
          instruction: task['prompt'] + "\n\nIMPORTANT: Respond ONLY with the JSON object. No other text."
        )
        response = LLM.call(retry_prompt, model: model, tracker: tracker, phase: 'evaluation')
        parsed   = Helpers.extract_json(response)
      end

      parsed ||= PARSE_FAILED.dup

      $stderr.puts "[solver:#{learner_id}] Solved task #{task['id']} (#{response.length} chars)"
      { 'response' => response, 'parsed' => parsed, 'trace' => { 'memory_size' => memory.to_s.length } }
    end
  end
end
```

- [ ] **Step 2: Verify syntax**

```bash
bundle exec ruby -c experiments/bloom_1n_vs_1on1/lib/phases/solver.rb
```

- [ ] **Step 3: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/lib/phases/solver.rb
git commit -m "feat: update solver phase — JSON parsing, retry, tracker, exposes parsed field"
```

---

## Task 9: Update Evaluator Phase

**Files:**
- Modify: `experiments/bloom_1n_vs_1on1/lib/phases/evaluator.rb`

Try auto-scoring first via `Scorer`. Only call LLM when auto-scoring is unavailable (no `expected_answer` string on task).

- [ ] **Step 1: Replace entire evaluator.rb**

```ruby
# ABOUTME: Scores task attempts — tries auto-scoring first, falls back to LLM evaluator
# ABOUTME: Auto-scoring uses Scorer module; LLM is reserved for ambiguous cases only

require 'json'
require_relative '../llm'
require_relative '../helpers'
require_relative '../scorer'

module Phases
  module Evaluator
    LLM_FALLBACK_SCORE = {
      'correctness' => 0, 'reasoning_quality' => 0, 'rule_application' => 0,
      'error_checking' => 0, 'autonomy' => 0, 'total' => 0,
      'auto_scored' => false, 'comments' => 'LLM evaluator failed to produce parseable JSON'
    }.freeze

    def self.score(attempt_id:, learner_response:, parsed_response:, task:, rubric:,
                   evaluator_id:, evaluator_prompt:, config:, tracker: nil)
      # Auto-score if task has machine-checkable expected_answer string
      if task['expected_answer'].is_a?(String)
        auto = Scorer.score_attempt(parsed_response, task)
        $stderr.puts "[evaluator] Auto-scored attempt #{attempt_id}: #{auto['total']} (answer_correct=#{auto['answer_correct']})"
        return auto
      end

      # LLM fallback for tasks without machine-checkable fields
      model = config.dig('models', 'evaluator') || 'claude-sonnet-4-6'
      rubric_text   = JSON.pretty_generate(rubric)
      expected_text = JSON.pretty_generate(task['expected_answer'])

      prompt = Helpers.build_prompt(
        system: evaluator_prompt,
        context: "RUBRIC:\n#{rubric_text}\n\nTASK:\n#{task['prompt']}\n\nEXPECTED ANSWER (reference only):\n#{expected_text}\n\nLEARNER RESPONSE:\n#{learner_response}",
        instruction: "Score this response according to the rubric. Return ONLY valid JSON. total must equal the sum of the five dimension scores."
      )

      raw   = LLM.call(prompt, model: model, tracker: tracker, phase: 'evaluator')
      score = Helpers.extract_json(raw)

      if score.nil?
        $stderr.puts "[evaluator] WARNING: LLM evaluator parse failed for attempt #{attempt_id}"
        return LLM_FALLBACK_SCORE.dup
      end

      score['total'] = %w[correctness reasoning_quality rule_application error_checking autonomy].sum { |k| score[k].to_f.round }
      score['auto_scored'] = false
      $stderr.puts "[evaluator] LLM-scored attempt #{attempt_id}: #{score['total']}/20"
      score
    end
  end
end
```

- [ ] **Step 2: Verify syntax**

```bash
bundle exec ruby -c experiments/bloom_1n_vs_1on1/lib/phases/evaluator.rb
```

- [ ] **Step 3: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/lib/phases/evaluator.rb
git commit -m "feat: update evaluator — auto-score first via Scorer, LLM only as fallback"
```

---

## Task 10: Update Report

**Files:**
- Modify: `experiments/bloom_1n_vs_1on1/lib/report.rb`

Add ceiling detection, difficulty-level breakdown, token usage metrics, and score-per-1000-tokens.

- [ ] **Step 1: Replace entire report.rb**

```ruby
# ABOUTME: Generates CSV scores and Markdown experiment report from database results
# ABOUTME: Includes ceiling effect detection, token usage metrics, and difficulty breakdown

require 'csv'
require 'json'
require 'date'
require 'fileutils'
require_relative 'db'

module Report
  SCORE_DIMENSIONS   = %w[correctness reasoning_quality rule_application error_checking autonomy].freeze
  CEILING_THRESHOLD  = 0.9
  DIFFICULTY_LEVELS  = %w[L1 L2 L3 L4 L5 L6].freeze

  def self.generate(db, run_id:, output_dir:, run_config:, token_summary: {})
    FileUtils.mkdir_p(output_dir)
    rows = DB.all_attempts_with_scores(db, run_id)
    write_csv(rows, output_dir)
    markdown = build_markdown(rows, run_id: run_id, output_dir: output_dir,
                              run_config: run_config, token_summary: token_summary)
    File.write(File.join(output_dir, 'report.md'), markdown)
    $stderr.puts "[report] Wrote scores.csv and report.md to #{output_dir}"
  end

  def self.write_csv(rows, output_dir)
    CSV.open(File.join(output_dir, 'scores.csv'), 'w') do |csv|
      csv << %w[learner_id condition task_id task_type difficulty total correctness
                rule_application error_checking answer_correct auto_scored comments]
      rows.each do |row|
        score = row['score_json'] ? JSON.parse(row['score_json']) : {}
        csv << [
          row['learner_id'], row['condition'], row['task_id'], row['task_type'],
          extract_difficulty(row['task_id']),
          score['total'] || 0, score['correctness'] || 0, score['rule_application'] || 0,
          score['error_checking'] || 0, score['answer_correct'],
          score['auto_scored'], score['comments'] || ''
        ]
      end
    end
  end

  def self.build_markdown(rows, run_id:, output_dir:, run_config:, token_summary:)
    by_condition = rows.group_by { |r| r['condition'] }
    ceiling_data = detect_ceiling(rows, run_config)
    token_data   = build_token_table(token_summary, by_condition, rows)

    lines = []
    lines << "# Experiment Report (v2)"
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
    lines << "| tutoring_turns | #{run_config.dig('experiment', 'tutoring_turns')} |"
    lines << ""

    # Ceiling effect summary
    lines << "## Ceiling Effect Summary"
    lines << ""
    lines << "> Tasks where both conditions score >#{(CEILING_THRESHOLD * 100).round}% correct are flagged as too easy."
    lines << ""
    lines << "| Task Type | Classroom Correct% | Tutoring Correct% | Ceiling? |"
    lines << "|-----------|-------------------|-------------------|---------|"
    ceiling_data.each do |row|
      ceiling_flag = row[:ceiling_effect] ? "⚠️ YES" : "no"
      lines << "| #{row[:task_type]} | #{(row[:classroom_pct] * 100).round}% | #{(row[:tutoring_pct] * 100).round}% | #{ceiling_flag} |"
    end
    too_easy = ceiling_data.select { |r| r[:ceiling_effect] }.map { |r| r[:task_type] }
    lines << ""
    lines << too_easy.any? ?
      "**Task types too easy:** #{too_easy.join(', ')}" :
      "**No ceiling effects detected.**"
    lines << ""

    # Score by condition
    lines << "## Score by Condition (answer_correct rate)"
    lines << ""
    lines << "| Condition | n_learners | n_attempts | Correct% | Avg total |"
    lines << "|-----------|-----------|-----------|---------|----------|"
    %w[classroom 1on1].each do |cond|
      cond_rows = by_condition[cond] || []
      correct_pct = avg_correctness(cond_rows)
      avg_tot = avg_total(cond_rows)
      n_learners = cond_rows.map { |r| r['learner_id'] }.uniq.size
      lines << "| #{cond} | #{n_learners} | #{cond_rows.size} | #{(correct_pct * 100).round}% | #{format('%.1f', avg_tot)} |"
    end
    lines << ""

    # Score by task type
    lines << "## Score by Task Type × Condition"
    lines << ""
    lines << "| Task Type | Difficulty | Classroom Correct% | Tutoring Correct% |"
    lines << "|-----------|-----------|-------------------|-------------------|"
    by_task_type = rows.group_by { |r| r['task_type'] }
    by_task_type.sort.each do |task_type, type_rows|
      difficulty = extract_difficulty(type_rows.first['task_id'])
      c_pct = avg_correctness(type_rows.select { |r| r['condition'] == 'classroom' })
      t_pct = avg_correctness(type_rows.select { |r| r['condition'] == '1on1' })
      lines << "| #{task_type} | #{difficulty} | #{(c_pct * 100).round}% | #{(t_pct * 100).round}% |"
    end
    lines << ""

    # Score by difficulty level
    lines << "## Score by Difficulty Level"
    lines << ""
    lines << "| Level | Task Types | Classroom Correct% | Tutoring Correct% |"
    lines << "|-------|-----------|-------------------|-------------------|"
    DIFFICULTY_LEVELS.each do |level|
      level_rows = rows.select { |r| extract_difficulty(r['task_id']) == level }
      next if level_rows.empty?
      types = level_rows.map { |r| r['task_type'] }.uniq.join(', ')
      c_pct = avg_correctness(level_rows.select { |r| r['condition'] == 'classroom' })
      t_pct = avg_correctness(level_rows.select { |r| r['condition'] == '1on1' })
      lines << "| #{level} | #{types} | #{(c_pct * 100).round}% | #{(t_pct * 100).round}% |"
    end
    lines << ""

    # Token usage
    lines << "## Token Usage by Phase (estimated)"
    lines << ""
    lines << "| Phase | Input | Output | Total |"
    lines << "|-------|-------|--------|-------|"
    token_summary.each do |phase, counts|
      lines << "| #{phase} | #{counts['input_tokens']} | #{counts['output_tokens']} | #{counts['total_tokens']} |"
    end
    grand = token_summary.values.sum { |v| v['total_tokens'] || 0 }
    lines << "| **TOTAL** | | | **#{grand}** |"
    lines << ""
    if token_data[:tutoring_extra] > 0 && token_data[:tutoring_gain] != 0
      lines << "| Metric | Value |"
      lines << "|--------|-------|"
      lines << "| Classroom correct% | #{(token_data[:classroom_pct] * 100).round}% |"
      lines << "| Tutoring correct% | #{(token_data[:tutoring_pct] * 100).round}% |"
      lines << "| Tutoring gain | #{format('%+.1f', token_data[:tutoring_gain] * 100)}pp |"
      lines << "| Extra education tokens (tutoring vs classroom) | #{token_data[:tutoring_extra]} |"
      lines << "| Tutoring gain per 1k extra tokens | #{format('%.2f', token_data[:gain_per_1k])}pp |"
      lines << ""
    end

    # Recommendations
    highest_solved = ceiling_data.reject { |r| r[:ceiling_effect] }
                                 .min_by { |r| DIFFICULTY_LEVELS.index(r[:difficulty]) || 99 }
    lines << "## Recommended Next Steps"
    lines << ""
    if too_easy.size == ceiling_data.size
      lines << "- All task types showed ceiling effects. Replace L1/L2 tasks entirely, increase L4–L6 share."
    elsif too_easy.any?
      lines << "- Task types flagged as too easy: #{too_easy.join(', ')} — remove or replace with harder variants."
    else
      lines << "- No ceiling effects at current difficulty. Increase n to improve statistical power."
    end
    lines << ""
    lines << "## Limitations"
    lines << ""
    lines << "- Token counts are estimated (chars/4). Actual API token counts may differ."
    lines << "- Auto-scoring uses keyword matching for mistake detection — may under-count partial credit."
    lines << "- LLM agents are not human learners. Learning is operationalized as condition-specific memory from transcripts."
    lines << "- Small n. Results are exploratory."
    lines << ""
    lines.join("\n") + "\n"
  end

  # ---- helpers ----

  def self.detect_ceiling(rows, run_config)
    threshold = (run_config.dig('experiment', 'ceiling_threshold') || CEILING_THRESHOLD).to_f
    rows.group_by { |r| r['task_type'] }.map do |task_type, type_rows|
      c_rows = type_rows.select { |r| r['condition'] == 'classroom' }
      t_rows = type_rows.select { |r| r['condition'] == '1on1' }
      c_pct = avg_correctness(c_rows)
      t_pct = avg_correctness(t_rows)
      difficulty = extract_difficulty(type_rows.first['task_id'])
      {
        task_type: task_type, difficulty: difficulty,
        classroom_pct: c_pct, tutoring_pct: t_pct,
        ceiling_effect: c_pct >= threshold && t_pct >= threshold
      }
    end.sort_by { |r| DIFFICULTY_LEVELS.index(r[:difficulty]) || 99 }
  end

  def self.build_token_table(token_summary, by_condition, rows)
    edu_classroom = (token_summary['education_classroom'] || {})['total_tokens'].to_i
    edu_tutoring  = (token_summary['education_tutoring']  || {})['total_tokens'].to_i
    c_pct = avg_correctness(by_condition['classroom'] || [])
    t_pct = avg_correctness(by_condition['1on1'] || [])
    gain  = t_pct - c_pct
    extra = edu_tutoring - edu_classroom
    gain_per_1k = extra > 0 ? (gain * 100) / (extra / 1000.0) : 0.0
    { classroom_pct: c_pct, tutoring_pct: t_pct, tutoring_gain: gain,
      tutoring_extra: extra, gain_per_1k: gain_per_1k }
  end

  def self.extract_difficulty(task_id)
    m = task_id.to_s.match(/^(l\d)/i)
    m ? m[1].upcase : 'unknown'
  end

  def self.avg_correctness(rows)
    return 0.0 if rows.empty?
    correct = rows.count do |r|
      score = r['score_json'] ? JSON.parse(r['score_json']) : {}
      score['answer_correct'] == true
    end
    correct.to_f / rows.size
  end

  def self.avg_total(rows)
    return 0.0 if rows.empty?
    rows.map { |r| r['score_json'] ? JSON.parse(r['score_json'])['total'].to_f : 0.0 }.sum / rows.size
  end
end
```

- [ ] **Step 2: Verify syntax**

```bash
bundle exec ruby -c experiments/bloom_1n_vs_1on1/lib/report.rb
```

- [ ] **Step 3: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/lib/report.rb
git commit -m "feat: update report with ceiling detection, token metrics, difficulty breakdown"
```

---

## Task 11: Wire Up Orchestrator

**Files:**
- Modify: `experiments/bloom_1n_vs_1on1/scripts/run_experiment.rb`

Add `TokenTracker`, pass it through all phases, use configurable eval tasks file, pass `parsed:` to evaluator, pass token summary to report.

- [ ] **Step 1: Replace entire run_experiment.rb**

```ruby
# ABOUTME: Main entry point for the Bloom 2 Sigma experiment orchestrator
# ABOUTME: Runs all phases with token tracking; outputs 7 files per run including report

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
require 'phases/classroom'
require 'phases/tutoring'
require 'phases/memory'
require 'phases/solver'
require 'phases/evaluator'
require 'report'

config_path = ARGV[0] or abort "Usage: #{$0} <config.yml>"
PROJECT_ROOT = File.expand_path('../..', EXPERIMENT_DIR)
config       = YAML.load_file(File.join(PROJECT_ROOT, config_path))

run_id       = SecureRandom.uuid
run_name     = config.dig('experiment', 'name') || 'bloom_run'
domain_path  = File.join(PROJECT_ROOT, config.dig('paths', 'domain'))
prompts_path = File.join(PROJECT_ROOT, config.dig('paths', 'prompts'))
output_base  = File.join(PROJECT_ROOT, config.dig('paths', 'output'))
db_path      = File.join(PROJECT_ROOT, config.dig('paths', 'db'))
run_dir      = File.join(output_base, 'runs', run_id)

FileUtils.mkdir_p(run_dir)
$stderr.puts "[main] Starting run #{run_id}"

tracker = TokenTracker.new

# Load domain content
tasks_file = config.dig('experiment', 'eval_tasks_file') || 'eval_tasks_v2.json'
lesson     = Helpers.load_file(File.join(domain_path, 'lesson.md'))
eval_tasks = JSON.parse(Helpers.load_file(File.join(domain_path, tasks_file)))
rubric     = JSON.parse(Helpers.load_file(File.join(domain_path, 'rubric.json')))

# Load prompts
teacher_prompt    = Helpers.load_file(File.join(prompts_path, 'classroom_teacher.md'))
tutor_prompt      = Helpers.load_file(File.join(prompts_path, 'one_on_one_tutor.md'))
learner_prompt    = Helpers.load_file(File.join(prompts_path, 'learner.md'))
summarizer_prompt = Helpers.load_file(File.join(prompts_path, 'memory_summarizer.md'))
solver_prompt     = Helpers.load_file(File.join(prompts_path, 'problem_solver.md'))
evaluator_prompt  = Helpers.load_file(File.join(prompts_path, 'blind_evaluator.md'))

db = DB.setup(db_path)
DB.save_run(db, run_id, run_name, config)
File.write(File.join(run_dir, 'config.json'), JSON.pretty_generate(config))

n_classroom = config.dig('experiment', 'n_classroom') || 4
n_tutoring  = config.dig('experiment', 'n_tutoring')  || 4

teacher_id = DB.save_agent(db, run_id: run_id, role: 'classroom_teacher',
                            model: config.dig('models', 'teacher'))
classroom_learner_ids = n_classroom.times.map do
  DB.save_agent(db, run_id: run_id, role: 'learner', condition: 'classroom',
                model: config.dig('models', 'learner'))
end

tutor_id = DB.save_agent(db, run_id: run_id, role: 'tutor',
                          model: config.dig('models', 'tutor'))
tutoring_learner_ids = n_tutoring.times.map do
  DB.save_agent(db, run_id: run_id, role: 'learner', condition: '1on1',
                model: config.dig('models', 'learner'))
end
evaluator_id = DB.save_agent(db, run_id: run_id, role: 'evaluator',
                              model: config.dig('models', 'evaluator'))

all_learners = classroom_learner_ids.map { |id| { id: id, condition: 'classroom' } } +
               tutoring_learner_ids.map  { |id| { id: id, condition: '1on1' } }

# === PHASE 1: Classroom Education ===
$stderr.puts "[main] Phase 1: Classroom education (#{n_classroom} learners)"
classroom_transcript = Phases::Classroom.run(
  teacher_id: teacher_id, learner_ids: classroom_learner_ids,
  teacher_prompt: teacher_prompt, learner_prompt: learner_prompt,
  lesson: lesson, config: config, tracker: tracker
)
classroom_learner_ids.each do |learner_id|
  DB.save_learning_session(db,
    run_id: run_id, condition: 'classroom', learner_id: learner_id,
    teacher_or_tutor_id: teacher_id, transcript: classroom_transcript
  )
end
File.open(File.join(run_dir, 'transcripts.jsonl'), 'a') { |f| f.puts JSON.dump(classroom_transcript) }

# === PHASE 2: 1on1 Tutoring ===
$stderr.puts "[main] Phase 2: 1on1 tutoring (#{n_tutoring} sessions)"
tutoring_learner_ids.each do |learner_id|
  transcript = Phases::Tutoring.run_session(
    tutor_id: tutor_id, learner_id: learner_id,
    tutor_prompt: tutor_prompt, learner_prompt: learner_prompt,
    lesson: lesson, config: config, tracker: tracker
  )
  DB.save_learning_session(db,
    run_id: run_id, condition: '1on1', learner_id: learner_id,
    teacher_or_tutor_id: tutor_id, transcript: transcript
  )
  File.open(File.join(run_dir, 'transcripts.jsonl'), 'a') { |f| f.puts JSON.dump(transcript) }
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
    learner_id: learner[:id], transcript: transcript,
    summarizer_prompt: summarizer_prompt, config: config, tracker: tracker
  )
  DB.save_learner_memory(db,
    run_id: run_id, learner_id: learner[:id],
    condition: learner[:condition], memory: memory
  )
  File.open(File.join(run_dir, 'memories.jsonl'), 'a') do |f|
    f.puts JSON.dump({ learner_id: learner[:id], condition: learner[:condition], memory: memory })
  end
end

# === PHASE 4+5: Problem Solving + Auto-Scoring ===
$stderr.puts "[main] Phase 4+5: Solving + scoring (#{all_learners.size} × #{eval_tasks.size} tasks)"

eval_tasks.each do |task|
  DB.save_evaluation_task(db,
    run_id: run_id, task_id: task['id'], task_type: task['task_type'],
    prompt: task['prompt'], expected_answer: task, rubric: rubric
  )
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
Report.generate(db, run_id: run_id, output_dir: run_dir,
                run_config: config, token_summary: tracker.summary)

db.close
$stderr.puts "[main] Done. Results in: #{run_dir}"
puts run_dir
```

- [ ] **Step 2: Verify syntax**

```bash
bundle exec ruby -c experiments/bloom_1n_vs_1on1/scripts/run_experiment.rb
```

Expected: `Syntax OK`

- [ ] **Step 3: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/scripts/run_experiment.rb
git commit -m "feat: wire token tracker, auto-scorer, and v2 eval tasks into orchestrator"
```

---

## Task 12: Run All Tests

**Files:**
- No new files — verify existing test suite still passes with updated modules

- [ ] **Step 1: Run full test suite**

```bash
bash experiments/bloom_1n_vs_1on1/tests/run_tests.sh
```

Expected output:
```
10 runs, 21 assertions, 0 failures, 0 errors, 0 skips
5 runs, 21 assertions, 0 failures, 0 errors, 0 skips
N runs, M assertions, 0 failures, 0 errors, 0 skips
All tests passed.
```

If any test fails, fix the failing module before proceeding.

- [ ] **Step 2: Commit fix if needed (only if Step 1 had failures)**

```bash
git add <files>
git commit -m "fix: <description of what was wrong>"
```

---

## Task 13: Smoke Test with Real LLM

- [ ] **Step 1: Set n=2 temporarily**

Edit `experiments/bloom_1n_vs_1on1/config.yml`: set `n_classroom: 2` and `n_tutoring: 2`.

- [ ] **Step 2: Run the experiment**

```bash
bundle exec ruby experiments/bloom_1n_vs_1on1/scripts/run_experiment.rb \
  experiments/bloom_1n_vs_1on1/config.yml 2>&1
```

Expected: runs to completion, prints a run_dir path. Monitor stderr for `[main] Done.`

- [ ] **Step 3: Verify all 7 output files exist and are non-empty**

```bash
RUN_DIR=<path from step 2>
ls -la "$RUN_DIR"
```

Must see: `config.json`, `transcripts.jsonl`, `memories.jsonl`, `attempts.jsonl`, `evaluations.jsonl`, `scores.csv`, `report.md`

- [ ] **Step 4: Verify scores.csv has new columns**

```bash
head -3 "$RUN_DIR/scores.csv"
```

Expected first line: `learner_id,condition,task_id,task_type,difficulty,total,...`

- [ ] **Step 5: Verify report.md has ceiling section**

```bash
grep "Ceiling Effect" "$RUN_DIR/report.md"
```

Expected: `## Ceiling Effect Summary`

- [ ] **Step 6: Run analyze_results.rb**

```bash
bundle exec ruby experiments/bloom_1n_vs_1on1/scripts/analyze_results.rb "$RUN_DIR"
```

Expected: prints condition and task_type breakdown with at least some non-trivial percentages.

- [ ] **Step 7: Restore n=4 in config.yml**

Change `n_classroom` and `n_tutoring` back to 4.

- [ ] **Step 8: Final commit**

```bash
git add experiments/bloom_1n_vs_1on1/config.yml
git commit -m "chore: restore n=4 after smoke test; v2 anti-ceiling update complete"
```

---

## Self-Review

### Spec Coverage

| Requirement | Task |
|-------------|------|
| Shorter classroom (lecture + one Q&A) | Task 5 |
| Shorter tutoring (2 exchanges) | Task 6 |
| Compact memory ≤120 words, 4 fields | Task 7 + Task 2 (prompt) |
| L1–L6 difficulty ladder, 1-2 per level | Task 1 |
| Debugging tasks prioritized (2 of 8) | Task 1 |
| JSON-only learner responses | Task 8 + Task 2 (prompt) |
| Retry on parse failure (once) | Task 8 |
| Auto-scoring with expected_answer, expected_active_tokens, expected_mistakes, aliases | Tasks 4 + 9 |
| LLM evaluator only as fallback | Task 9 |
| Ceiling effect detection (>90% → flag) | Task 10 |
| Token tracking per phase | Tasks 3 + 5–11 |
| Score per 1k tokens, tutoring gain | Task 10 |
| Difficulty breakdown in report | Task 10 |
| task types flagged as too easy | Task 10 |
| Recommended next difficulty | Task 10 |

### Placeholder Scan

No TBD/TODO items. All code blocks are complete and syntactically verifiable.

### Type Consistency

- `Phases::Evaluator.score` gains `parsed_response:` keyword — orchestrator passes `result['parsed']` ✓
- `Phases::Solver.solve` returns `{ 'response' => ..., 'parsed' => ..., 'trace' => ... }` — orchestrator reads all three ✓
- `Report.generate` gains `token_summary:` keyword — orchestrator passes `tracker.summary` ✓
- `TokenTracker#summary` returns `{ phase => { 'total_tokens' => n } }` — Report reads `counts['total_tokens']` ✓
- `Scorer.score_attempt` uses `task['expected_answer']` (String), `task['expected_active_tokens']` (Array), `task['expected_mistakes']` (Array) — eval_tasks_v2.json provides all three ✓
