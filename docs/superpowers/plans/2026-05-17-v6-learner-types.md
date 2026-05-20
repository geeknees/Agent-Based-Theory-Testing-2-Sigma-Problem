# v6 Theory-Driven Learner Types Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace v5 persona-style profiles with 7 theory-driven learner types whose behavioral differences are operationalized as post-LLM memory constraints (word budget, edge-case retention, rule-order retention, question probability) rather than role-play instructions.

**Architecture:** New `LearnerTypes` module defines 7 types as numeric constraint hashes. `Phases::Memory` applies `LearnerTypes.apply_constraints` after LLM generation, producing structurally different memories without touching prompt wording. `Phases::Tutoring` adds a diagnose-correct-retest exchange (exchange 3 = identify misconception + corrective example; exchange 4 = retest Q + retest answer). `Phases::Classroom` gates each learner's question on `LearnerTypes.should_ask_question?`. Solver gains confidence/abstention fields; `Scorer` adds `calibrated_confidence`, `high_confidence_wrong`, and `abstention_quality` flags. Report gains four new sections powered by a new `DB.all_memories_by_condition` query. Known v5 report bugs (hardcoded `'classroom'` condition) are fixed.

**Tech Stack:** Ruby, SQLite3, Minitest, Anthropic Claude API via `claude` CLI

---

## File Map

| File | Action |
|------|--------|
| `experiments/bloom_1n_vs_1on1/lib/learner_types.rb` | Create |
| `experiments/bloom_1n_vs_1on1/tests/test_learner_types.rb` | Create |
| `experiments/bloom_1n_vs_1on1/tests/run_tests.sh` | Modify (add test_learner_types.rb) |
| `experiments/bloom_1n_vs_1on1/config.yml` | Modify (name → v6) |
| `experiments/bloom_1n_vs_1on1/prompts/memory_summarizer.md` | Modify (4-field → 7-field schema) |
| `experiments/bloom_1n_vs_1on1/prompts/problem_solver.md` | Modify (add confidence/abstention fields) |
| `experiments/bloom_1n_vs_1on1/prompts/one_on_one_tutor.md` | Modify (add diagnostic-loop description) |
| `experiments/bloom_1n_vs_1on1/lib/phases/memory.rb` | Modify (7-field default, type constraints) |
| `experiments/bloom_1n_vs_1on1/lib/phases/tutoring.rb` | Modify (exchange 3-4 → diagnose-retest) |
| `experiments/bloom_1n_vs_1on1/lib/phases/classroom.rb` | Modify (gate questions on type) |
| `experiments/bloom_1n_vs_1on1/lib/scorer.rb` | Modify (calibrated_confidence, abstention_quality) |
| `experiments/bloom_1n_vs_1on1/lib/db.rb` | Modify (add all_memories_by_condition) |
| `experiments/bloom_1n_vs_1on1/lib/report.rb` | Modify (fix v5 bugs + 4 new sections) |
| `experiments/bloom_1n_vs_1on1/scripts/run_experiment.rb` | Modify (use LearnerTypes, pass type keys) |
| `experiments/bloom_1n_vs_1on1/tests/test_scorer.rb` | Modify (new score fields) |
| `experiments/bloom_1n_vs_1on1/tests/test_db.rb` | Modify (all_memories_by_condition) |
| `experiments/bloom_1n_vs_1on1/tests/test_report_v5.rb` | Modify (new report section tests) |

---

### Task 1: Create `lib/learner_types.rb` with 7 types

**Files:**
- Create: `experiments/bloom_1n_vs_1on1/lib/learner_types.rb`
- Create: `experiments/bloom_1n_vs_1on1/tests/test_learner_types.rb`
- Modify: `experiments/bloom_1n_vs_1on1/tests/run_tests.sh`

- [ ] **Step 1.1: Write the failing test**

Create `experiments/bloom_1n_vs_1on1/tests/test_learner_types.rb`:

```ruby
# ABOUTME: Tests for LearnerTypes module — 7 type definitions and behavioral constraint helpers
# ABOUTME: No LLM calls; purely deterministic type definitions and constraint application

$LOAD_PATH.unshift File.join(__dir__, '..', 'lib')
require 'minitest/autorun'
require 'learner_types'

class TestLearnerTypeDefinitions < Minitest::Test
  def test_all_seven_types_defined
    expected = %i[rule_extractor example_memorizer edge_case_dropper order_confused
                  answer_first help_seeker passive_listener]
    expected.each { |t| assert LearnerTypes::TYPES.key?(t), "Missing type: #{t}" }
    assert_equal 7, LearnerTypes::TYPES.size
  end

  def test_each_type_has_required_keys
    LearnerTypes::TYPES.each do |name, attrs|
      LearnerTypes::REQUIRED_KEYS.each do |key|
        assert attrs.key?(key), "Type #{name} missing key: #{key}"
      end
    end
  end

  def test_homogeneous_assignment_is_four_edge_case_droppers
    assert_equal 4, LearnerTypes::HOMOGENEOUS_ASSIGNMENT.size
    assert LearnerTypes::HOMOGENEOUS_ASSIGNMENT.all? { |t| t == :edge_case_dropper }
  end

  def test_heterogeneous_assignment_has_four_distinct_types
    assert_equal 4, LearnerTypes::HETEROGENEOUS_ASSIGNMENT.size
    assert_includes LearnerTypes::HETEROGENEOUS_ASSIGNMENT, :rule_extractor
    assert_includes LearnerTypes::HETEROGENEOUS_ASSIGNMENT, :edge_case_dropper
    assert_includes LearnerTypes::HETEROGENEOUS_ASSIGNMENT, :order_confused
    assert_includes LearnerTypes::HETEROGENEOUS_ASSIGNMENT, :passive_listener
  end

  def test_fetch_raises_on_unknown_type
    assert_raises(ArgumentError) { LearnerTypes.fetch(:nonexistent) }
  end

  def test_fetch_works_with_string_key
    type = LearnerTypes.fetch('rule_extractor')
    assert_equal 150, type[:memory_budget_words]
  end
end

class TestShouldAskQuestion < Minitest::Test
  def test_passive_listener_never_asks
    100.times { refute LearnerTypes.should_ask_question?(:passive_listener) }
  end

  def test_help_seeker_almost_always_asks
    results = 100.times.map { LearnerTypes.should_ask_question?(:help_seeker) }
    assert results.count(true) >= 80, "help_seeker should ask >=80% (prob=0.9), got #{results.count(true)}"
  end

  def test_answer_first_rarely_asks
    results = 100.times.map { LearnerTypes.should_ask_question?(:answer_first) }
    assert results.count(true) <= 30, "answer_first should ask <=30% (prob=0.1), got #{results.count(true)}"
  end
end

class TestApplyConstraints < Minitest::Test
  def base_memory
    {
      'rules'                    => %w[rule1 rule2 rule3 rule4 rule5],
      'examples'                 => ['example1 long text here', 'example2 another one'],
      'edge_cases'               => ['edge1 boundary', 'edge2 exception', 'edge3 special'],
      'strategy'                 => ['step A first', 'step B second'],
      'corrected_misconceptions' => [],
      'remaining_misconceptions' => [],
      'uncertain_rules'          => []
    }
  end

  def test_edge_case_dropper_drops_most_edge_cases
    srand(42)
    result = LearnerTypes.apply_constraints(base_memory, :edge_case_dropper)
    assert result['edge_cases'].size < 3, "edge_case_dropper should drop most edge cases, kept #{result['edge_cases'].size}"
  end

  def test_rule_extractor_keeps_most_edge_cases
    srand(42)
    result = LearnerTypes.apply_constraints(base_memory, :rule_extractor)
    assert result['edge_cases'].size >= 2, "rule_extractor should keep most edge cases, kept #{result['edge_cases'].size}"
  end

  def test_apply_constraints_does_not_mutate_original
    original           = base_memory
    original_edge_copy = original['edge_cases'].dup
    LearnerTypes.apply_constraints(original, :edge_case_dropper)
    assert_equal original_edge_copy, original['edge_cases'], "apply_constraints must not mutate original"
  end

  def test_trim_to_budget_respects_word_limit
    big_memory = {
      'rules'                    => Array.new(20, 'a very long rule about tokens and positions here'),
      'examples'                 => Array.new(10, 'worked example with many steps involved'),
      'edge_cases'               => Array.new(10, 'tricky edge condition to remember carefully'),
      'strategy'                 => Array.new(5, 'step to follow exactly'),
      'corrected_misconceptions' => [],
      'remaining_misconceptions' => [],
      'uncertain_rules'          => []
    }
    result = LearnerTypes.trim_to_budget(big_memory, 80)
    assert LearnerTypes.word_count(result) <= 80, "Expected <=80 words, got #{LearnerTypes.word_count(result)}"
  end

  def test_passive_listener_budget_is_80
    type = LearnerTypes.fetch(:passive_listener)
    assert_equal 80, type[:memory_budget_words]
  end

  def test_to_prompt_context_includes_type_name
    text = LearnerTypes.to_prompt_context(:edge_case_dropper)
    assert_includes text, 'edge_case_dropper'
  end
end
```

- [ ] **Step 1.2: Run tests to confirm they fail**

```bash
cd /Users/masumi/tmp/Agent-Based-Theory-Testing-2-Sigma-Problem
eval "$(mise activate bash)"
bundle exec ruby experiments/bloom_1n_vs_1on1/tests/test_learner_types.rb 2>&1 | head -5
```

Expected: `LoadError: cannot load such file -- learner_types`

- [ ] **Step 1.3: Create `lib/learner_types.rb`**

```ruby
# ABOUTME: Defines 7 theory-driven learner types with behavioral constraint attributes
# ABOUTME: Constraints applied post-LLM to memory to operationalize cognitive differences

module LearnerTypes
  TYPES = {
    rule_extractor: {
      memory_budget_words:         150,
      edge_case_retention:         0.9,
      rule_order_retention:        0.9,
      question_asking_probability: 0.3,
      likely_misconceptions:       []
    },
    example_memorizer: {
      memory_budget_words:         120,
      edge_case_retention:         0.4,
      rule_order_retention:        0.5,
      question_asking_probability: 0.2,
      likely_misconceptions:       ['forgets_edge_cases']
    },
    edge_case_dropper: {
      memory_budget_words:         120,
      edge_case_retention:         0.1,
      rule_order_retention:        0.7,
      question_asking_probability: 0.2,
      likely_misconceptions:       ['forgets_edge_cases']
    },
    order_confused: {
      memory_budget_words:         100,
      edge_case_retention:         0.6,
      rule_order_retention:        0.2,
      question_asking_probability: 0.4,
      likely_misconceptions:       ['applies_modifiers_before_activation']
    },
    answer_first: {
      memory_budget_words:         100,
      edge_case_retention:         0.3,
      rule_order_retention:        0.5,
      question_asking_probability: 0.1,
      likely_misconceptions:       ['thinks_blue_always_active']
    },
    help_seeker: {
      memory_budget_words:         130,
      edge_case_retention:         0.7,
      rule_order_retention:        0.8,
      question_asking_probability: 0.9,
      likely_misconceptions:       []
    },
    passive_listener: {
      memory_budget_words:         80,
      edge_case_retention:         0.2,
      rule_order_retention:        0.4,
      question_asking_probability: 0.0,
      likely_misconceptions:       ['forgets_edge_cases']
    }
  }.freeze

  REQUIRED_KEYS = %i[memory_budget_words edge_case_retention rule_order_retention
                     question_asking_probability likely_misconceptions].freeze

  HOMOGENEOUS_ASSIGNMENT  = Array.new(4, :edge_case_dropper).freeze
  HETEROGENEOUS_ASSIGNMENT = %i[rule_extractor edge_case_dropper order_confused passive_listener].freeze

  DESCRIPTIONS = {
    rule_extractor:    'extract explicit rules from instruction; strong at recall, weaker on application',
    example_memorizer: 'remember specific worked examples; struggles to generalize to new cases',
    edge_case_dropper: 'grasp main rules but forget edge cases and boundary conditions',
    order_confused:    'apply rules in wrong sequence; often reverses modifier/activation order',
    answer_first:      'jump to answers before checking all conditions; overconfident',
    help_seeker:       'ask for clarification proactively; learns well with feedback',
    passive_listener:  'listen without engaging; retain partial information only'
  }.freeze

  def self.fetch(type_key)
    TYPES.fetch(type_key.to_sym) { raise ArgumentError, "Unknown learner type: #{type_key}" }
  end

  def self.should_ask_question?(type_key)
    prob = fetch(type_key)[:question_asking_probability]
    rand < prob
  end

  # Apply type-specific constraints to an LLM-generated memory hash.
  # Returns a new hash — does not mutate the input.
  def self.apply_constraints(memory, type_key)
    type   = fetch(type_key)
    result = memory.transform_values { |v| v.is_a?(Array) ? v.dup : v }

    if result['edge_cases'].is_a?(Array)
      result['edge_cases'] = result['edge_cases'].select { rand < type[:edge_case_retention] }
    end

    if result['rules'].is_a?(Array) && rand >= type[:rule_order_retention]
      result['rules'] = result['rules'].shuffle
    end

    trim_to_budget(result, type[:memory_budget_words])
  end

  # Trim memory to max_words by removing from lowest-priority arrays first.
  # Priority (highest = keep longest): rules > strategy > edge_cases > examples >
  #   corrected_misconceptions > uncertain_rules > remaining_misconceptions
  def self.trim_to_budget(memory, max_words)
    return memory if word_count(memory) <= max_words

    result     = memory.transform_values { |v| v.is_a?(Array) ? v.dup : v }
    trim_order = %w[remaining_misconceptions uncertain_rules examples
                    edge_cases corrected_misconceptions strategy rules]
    loop do
      break if word_count(result) <= max_words

      trimmed = false
      trim_order.each do |key|
        if result[key].is_a?(Array) && result[key].size > 0
          result[key] = result[key][0..-2]
          trimmed = true
          break
        end
      end
      break unless trimmed
    end
    result
  end

  def self.word_count(memory)
    memory.values.flatten.join(' ').split.size
  end

  def self.to_prompt_context(type_key)
    type = fetch(type_key)
    desc = DESCRIPTIONS.fetch(type_key.to_sym, 'unknown type')
    misc = type[:likely_misconceptions].empty? ? 'none' : type[:likely_misconceptions].join(', ')
    <<~CONTEXT
      LEARNER TYPE: #{type_key}
      - Tendency: #{desc}
      - Common misconceptions: #{misc}
      - Memory budget: #{type[:memory_budget_words]} words (compact memory expected)
    CONTEXT
  end
end
```

- [ ] **Step 1.4: Run tests to confirm they pass**

```bash
cd /Users/masumi/tmp/Agent-Based-Theory-Testing-2-Sigma-Problem
eval "$(mise activate bash)"
bundle exec ruby experiments/bloom_1n_vs_1on1/tests/test_learner_types.rb 2>&1
```

Expected: All tests pass.

- [ ] **Step 1.5: Add test_learner_types.rb to run_tests.sh**

In `experiments/bloom_1n_vs_1on1/tests/run_tests.sh`, add before the final `echo "All tests passed."` line:

```bash
bundle exec ruby "$EXPERIMENT_DIR/tests/test_learner_types.rb"
```

- [ ] **Step 1.6: Run full test suite**

```bash
cd /Users/masumi/tmp/Agent-Based-Theory-Testing-2-Sigma-Problem
eval "$(mise activate bash)"
bash experiments/bloom_1n_vs_1on1/tests/run_tests.sh 2>&1
```

Expected: `All tests passed.`

- [ ] **Step 1.7: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/lib/learner_types.rb \
        experiments/bloom_1n_vs_1on1/tests/test_learner_types.rb \
        experiments/bloom_1n_vs_1on1/tests/run_tests.sh
git commit -m "feat: add LearnerTypes module with 7 theory-driven types and constraint helpers"
```

---

### Task 2: Update config.yml and all 3 prompts for v6

**Files:**
- Modify: `experiments/bloom_1n_vs_1on1/config.yml`
- Modify: `experiments/bloom_1n_vs_1on1/prompts/memory_summarizer.md`
- Modify: `experiments/bloom_1n_vs_1on1/prompts/problem_solver.md`
- Modify: `experiments/bloom_1n_vs_1on1/prompts/one_on_one_tutor.md`

- [ ] **Step 2.1: Update config.yml**

Replace the full content of `experiments/bloom_1n_vs_1on1/config.yml`:

```yaml
experiment:
  name: "bloom_learner_types_v6"
  domain: "zarn_tokens"
  n_homogeneous_classroom: 4
  n_heterogeneous_classroom: 4
  n_tutoring: 4
  n_no_education: 3
  tutoring_turns: 4
  eval_tasks_file: "eval_tasks_v4.json"
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

- [ ] **Step 2.2: Update prompts/memory_summarizer.md to 7-field schema**

Replace the full content of `experiments/bloom_1n_vs_1on1/prompts/memory_summarizer.md`:

```
You are a learning memory compressor.

Analyze the educational session transcript and extract a compact structured memory for the learner.

Output ONLY valid JSON. No prose before or after. Total output must be under 150 words.

Schema:
{
  "rules": ["explicit rules learned — max 12 words each"],
  "examples": ["specific worked examples remembered — max 15 words each"],
  "edge_cases": ["boundary conditions and exceptions — max 12 words each"],
  "strategy": ["step-by-step problem approach — max 12 words each"],
  "corrected_misconceptions": ["mistakes the session explicitly corrected — max 12 words each"],
  "remaining_misconceptions": ["things still uncertain or possibly wrong — max 12 words each"],
  "uncertain_rules": ["rule names or topics not fully understood"]
}

Constraints:
- Maximum 10 items total across all arrays
- No long sequences or examples
- No repetition across fields
- corrected_misconceptions: only if the session explicitly corrected a mistake
- remaining_misconceptions: only if the learner expressed uncertainty or showed incomplete understanding
- If the session was a no-education baseline, all arrays should be empty
```

- [ ] **Step 2.3: Update prompts/problem_solver.md to add confidence and abstention fields**

Replace the full content of `experiments/bloom_1n_vs_1on1/prompts/problem_solver.md`:

```
You are a learner solving a problem using your learning memory.

Your memory contains the rules you learned. Apply them carefully to the problem.

IMPORTANT: Respond ONLY with valid JSON in exactly this format — no text outside the JSON:

{
  "answer": "<your numeric answer, or true/false for claim tasks>",
  "active_tokens": ["<token names that are active in the final sequence>"],
  "mistakes_found": ["<for debugging tasks: describe each mistake you found>"],
  "confidence": <0.0 to 1.0 — how confident you are in this answer>,
  "used_memory": ["<key rules or facts from your memory you relied on>"],
  "uncertain_rules": ["<rule names you are not sure about>"],
  "abstain": <true if you are too uncertain to answer reliably, false otherwise>,
  "reason": "<your reasoning in under 40 words>"
}

Guidelines:
- Set confidence=1.0 only if you are certain. Set confidence<0.5 if you are guessing.
- Set abstain=true if you cannot determine the answer from your memory. In that case, set answer="" and active_tokens=[].
- List in used_memory the specific rules from your memory that you applied.
- List in uncertain_rules any rules you applied but are not confident about.
- Do not include any text, explanation, or prose outside this JSON object.
```

- [ ] **Step 2.4: Update prompts/one_on_one_tutor.md to describe diagnostic loop**

Replace the full content of `experiments/bloom_1n_vs_1on1/prompts/one_on_one_tutor.md`:

```
You are a one-on-one tutor working with a single learner agent.

Your role:
- Engage in dialogue with this learner specifically
- Ask diagnostic questions to check their understanding
- Identify the learner's specific misconception and correct it with a targeted example
- Retest the learner on the corrected misconception to confirm the correction stuck
- Stay within a fixed turn budget — be efficient

Session structure:
1. Open: introduce the most important concept with a concrete example
2. Diagnose: ask one diagnostic question targeting the learner's known misconception
3. Correct: explicitly identify the misconception and provide a corrective worked example
4. Retest: ask a NEW question that tests specifically whether the correction worked

Tone: supportive, curious, direct. Focus on whether the correction actually changed the learner's understanding.
```

- [ ] **Step 2.5: Verify YAML parses cleanly**

```bash
cd /Users/masumi/tmp/Agent-Based-Theory-Testing-2-Sigma-Problem
eval "$(mise activate bash)"
ruby -e "require 'yaml'; puts YAML.load_file('experiments/bloom_1n_vs_1on1/config.yml').inspect"
```

Expected: Hash printed without errors.

- [ ] **Step 2.6: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/config.yml \
        experiments/bloom_1n_vs_1on1/prompts/memory_summarizer.md \
        experiments/bloom_1n_vs_1on1/prompts/problem_solver.md \
        experiments/bloom_1n_vs_1on1/prompts/one_on_one_tutor.md
git commit -m "feat: v6 config and prompts — 7-field memory, confidence/abstention solver, diagnostic tutor"
```

---

### Task 3: Update `lib/phases/memory.rb` to 7-field schema with type constraints

**Files:**
- Modify: `experiments/bloom_1n_vs_1on1/lib/phases/memory.rb`

- [ ] **Step 3.1: Replace the full content of `lib/phases/memory.rb`**

```ruby
# ABOUTME: Generates compact structured learning memory from each learner's session transcript
# ABOUTME: 7-field schema; applies LearnerTypes constraints post-LLM to enforce cognitive differences

require_relative '../llm'
require_relative '../helpers'
require_relative '../learner_types'

module Phases
  module Memory
    MAX_WORDS = 120
    DEFAULT_MEMORY = {
      'rules'                    => [],
      'examples'                 => [],
      'edge_cases'               => [],
      'strategy'                 => [],
      'corrected_misconceptions' => [],
      'remaining_misconceptions' => [],
      'uncertain_rules'          => []
    }.freeze

    def self.generate(learner_id:, transcript:, summarizer_prompt:, config:, tracker: nil, learner_type_key: nil)
      model     = config.dig('models', 'memory_summarizer') || 'claude-sonnet-4-6'
      max_words = config.dig('experiment', 'max_memory_words') || MAX_WORDS

      if learner_type_key
        type_def  = LearnerTypes.fetch(learner_type_key)
        max_words = type_def[:memory_budget_words]
      end

      transcript_text = Helpers.format_turns_for_prompt(transcript['turns'])

      prompt = Helpers.build_prompt(
        system: summarizer_prompt,
        context: "EDUCATIONAL SESSION TRANSCRIPT FOR #{learner_id}:\n\n#{transcript_text}",
        instruction: "Generate a compact learning memory JSON for #{learner_id}. Return ONLY valid JSON. No prose."
      )

      raw    = LLM.call(prompt, model: model, tracker: tracker, phase: 'memory')
      memory = Helpers.extract_json(raw)

      if memory.nil?
        $stderr.puts "[memory:#{learner_id}] WARNING: Could not parse memory JSON, using default"
        return DEFAULT_MEMORY.transform_values(&:dup)
      end

      DEFAULT_MEMORY.each_key { |k| memory[k] ||= [] }

      if learner_type_key
        memory = LearnerTypes.apply_constraints(memory, learner_type_key)
        $stderr.puts "[memory:#{learner_id}] Applied #{learner_type_key} constraints (#{LearnerTypes.word_count(memory)} words)"
      else
        memory = LearnerTypes.trim_to_budget(memory, max_words)
        $stderr.puts "[memory:#{learner_id}] Memory generated (#{LearnerTypes.word_count(memory)} words)"
      end

      memory
    end
  end
end
```

- [ ] **Step 3.2: Run full test suite**

```bash
cd /Users/masumi/tmp/Agent-Based-Theory-Testing-2-Sigma-Problem
eval "$(mise activate bash)"
bash experiments/bloom_1n_vs_1on1/tests/run_tests.sh 2>&1
```

Expected: `All tests passed.`

- [ ] **Step 3.3: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/lib/phases/memory.rb
git commit -m "feat: memory phase — 7-field schema, learner_type_key constraint injection"
```

---

### Task 4: Update `lib/phases/tutoring.rb` — diagnostic-correct-retest loop

**Files:**
- Modify: `experiments/bloom_1n_vs_1on1/lib/phases/tutoring.rb`

Exchange 3 changes from "feedback + reflection" to "diagnose misconception + corrective application."
Exchange 4 changes from "harder Q2 + answer" to "retest Q + retest answer."
`learner_profile:` parameter replaced by `learner_type_key:`.

- [ ] **Step 4.1: Replace the full content of `lib/phases/tutoring.rb`**

```ruby
# ABOUTME: Orchestrates individual 1on1 tutoring sessions with diagnostic-correct-retest loop
# ABOUTME: Exchange 3 diagnoses and corrects the learner's misconception; exchange 4 retests it

require_relative '../llm'
require_relative '../helpers'
require_relative '../learner_types'

module Phases
  module Tutoring
    def self.run_session(tutor_id:, learner_id:, tutor_prompt:, learner_prompt:, lesson:,
                         config:, tracker: nil, learner_type_key: nil)
      tutor_model   = config.dig('models', 'tutor')   || 'claude-sonnet-4-6'
      learner_model = config.dig('models', 'learner') || 'claude-sonnet-4-6'

      type_context    = learner_type_key ? "\n\n#{LearnerTypes.to_prompt_context(learner_type_key)}" : ''
      learner_context = learner_type_key ? "\n\nYOUR LEARNER TYPE: #{learner_type_key} — respond authentically." : ''

      turns = []

      # Exchange 1, Turn 1: Tutor opens session
      opener_prompt = Helpers.build_prompt(
        system: tutor_prompt,
        context: "DOMAIN LESSON MATERIAL:\n#{lesson}#{type_context}",
        instruction: "Begin a tutoring session with #{learner_id}. Teach the most important concept with a concrete example adapted to the learner's type. Be concise — under 150 words."
      )
      opener = LLM.call(opener_prompt, model: tutor_model, tracker: tracker, phase: 'education_tutoring')
      turns << { 'speaker' => 'tutor', 'type' => 'opener', 'content' => opener }
      $stderr.puts "[tutoring:#{learner_id}] Tutor opened session"

      # Exchange 1, Turn 2: Learner responds
      response_prompt = Helpers.build_prompt(
        system: learner_prompt,
        context: "TUTOR SAID:\n#{opener}#{learner_context}",
        instruction: "Respond to your tutor. State what you understood, or ask a question if something is unclear. 1-2 sentences."
      )
      response = LLM.call(response_prompt, model: learner_model, tracker: tracker, phase: 'education_tutoring')
      turns << { 'speaker' => 'learner', 'type' => 'response', 'content' => response }
      $stderr.puts "[tutoring:#{learner_id}] Learner responded"

      # Exchange 2, Turn 3: Tutor asks diagnostic question targeting known misconception
      history = Helpers.format_turns_for_prompt(turns)
      diag1_prompt = Helpers.build_prompt(
        system: tutor_prompt,
        context: "DOMAIN LESSON:\n#{lesson}#{type_context}\n\nSESSION SO FAR:\n#{history}",
        instruction: "Ask ONE diagnostic question that will reveal whether the learner has the misconception listed in their type profile. Under 60 words. Do not give the answer."
      )
      diag1 = LLM.call(diag1_prompt, model: tutor_model, tracker: tracker, phase: 'education_tutoring')
      turns << { 'speaker' => 'tutor', 'type' => 'diagnostic_q1', 'content' => diag1 }
      $stderr.puts "[tutoring:#{learner_id}] Tutor asked diagnostic Q1"

      # Exchange 2, Turn 4: Learner answers Q1 (may reveal misconception)
      history = Helpers.format_turns_for_prompt(turns)
      answer1_prompt = Helpers.build_prompt(
        system: learner_prompt,
        context: "SESSION SO FAR:\n#{history}#{learner_context}",
        instruction: "Answer the tutor's question. Show your step-by-step reasoning. If unsure, say so."
      )
      answer1 = LLM.call(answer1_prompt, model: learner_model, tracker: tracker, phase: 'education_tutoring')
      turns << { 'speaker' => 'learner', 'type' => 'answer1', 'content' => answer1 }
      $stderr.puts "[tutoring:#{learner_id}] Learner answered Q1"

      # Exchange 3, Turn 5: Tutor identifies misconception and gives corrective example
      history = Helpers.format_turns_for_prompt(turns)
      correct_prompt = Helpers.build_prompt(
        system: tutor_prompt,
        context: "DOMAIN LESSON:\n#{lesson}#{type_context}\n\nSESSION SO FAR:\n#{history}",
        instruction: "Identify the specific error or misconception in the learner's answer. State the correct rule explicitly. Give a SHORT corrective worked example (2-3 steps) that makes the correct rule concrete. Under 120 words."
      )
      correction = LLM.call(correct_prompt, model: tutor_model, tracker: tracker, phase: 'education_tutoring')
      turns << { 'speaker' => 'tutor', 'type' => 'correction', 'content' => correction }
      $stderr.puts "[tutoring:#{learner_id}] Tutor gave correction"

      # Exchange 3, Turn 6: Learner applies the corrective example
      history = Helpers.format_turns_for_prompt(turns)
      apply_prompt = Helpers.build_prompt(
        system: learner_prompt,
        context: "SESSION SO FAR:\n#{history}#{learner_context}",
        instruction: "State the corrected rule in your own words. Work through the example the tutor gave you step by step. Express your confidence: low, medium, or high."
      )
      application = LLM.call(apply_prompt, model: learner_model, tracker: tracker, phase: 'education_tutoring')
      turns << { 'speaker' => 'learner', 'type' => 'correction_application', 'content' => application }
      $stderr.puts "[tutoring:#{learner_id}] Learner applied correction"

      # Exchange 4, Turn 7: Tutor asks RETEST question on same misconception
      history = Helpers.format_turns_for_prompt(turns)
      retest_q_prompt = Helpers.build_prompt(
        system: tutor_prompt,
        context: "DOMAIN LESSON:\n#{lesson}#{type_context}\n\nSESSION SO FAR:\n#{history}",
        instruction: "Ask a NEW question that retests the SAME misconception you just corrected. It must be a different scenario but test the same rule. Under 80 words. Do not give the answer."
      )
      retest_q = LLM.call(retest_q_prompt, model: tutor_model, tracker: tracker, phase: 'education_tutoring')
      turns << { 'speaker' => 'tutor', 'type' => 'retest_q', 'content' => retest_q }
      $stderr.puts "[tutoring:#{learner_id}] Tutor asked retest Q"

      # Exchange 4, Turn 8: Learner answers retest
      history = Helpers.format_turns_for_prompt(turns)
      retest_a_prompt = Helpers.build_prompt(
        system: learner_prompt,
        context: "SESSION SO FAR:\n#{history}#{learner_context}",
        instruction: "Answer the retest question. Apply the corrected rule you just learned. Show your reasoning. Note any remaining uncertainty."
      )
      retest_a = LLM.call(retest_a_prompt, model: learner_model, tracker: tracker, phase: 'education_tutoring')
      turns << { 'speaker' => 'learner', 'type' => 'retest_answer', 'content' => retest_a }
      $stderr.puts "[tutoring:#{learner_id}] Learner answered retest"

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

- [ ] **Step 4.2: Run full test suite**

```bash
cd /Users/masumi/tmp/Agent-Based-Theory-Testing-2-Sigma-Problem
eval "$(mise activate bash)"
bash experiments/bloom_1n_vs_1on1/tests/run_tests.sh 2>&1
```

Expected: `All tests passed.`

- [ ] **Step 4.3: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/lib/phases/tutoring.rb
git commit -m "feat: tutoring phase — diagnostic-correct-retest loop, learner_type_key replaces learner_profile"
```

---

### Task 5: Update `lib/phases/classroom.rb` — gate questions on learner type

**Files:**
- Modify: `experiments/bloom_1n_vs_1on1/lib/phases/classroom.rb`

- [ ] **Step 5.1: Replace the full content of `lib/phases/classroom.rb`**

```ruby
# ABOUTME: Orchestrates 1:N classroom education for any classroom condition
# ABOUTME: Gates question-asking on learner type's question_asking_probability when type keys provided

require_relative '../llm'
require_relative '../helpers'
require_relative '../learner_types'

module Phases
  module Classroom
    def self.run(teacher_id:, learner_ids:, teacher_prompt:, learner_prompt:, lesson:,
                 config:, tracker: nil, class_context: nil, condition: 'classroom',
                 learner_type_keys: {})
      model         = config.dig('models', 'teacher') || 'claude-sonnet-4-6'
      learner_model = config.dig('models', 'learner') || 'claude-sonnet-4-6'

      turns = []

      context_suffix = class_context ? "\n\n#{class_context}" : ''

      # Step 1: Teacher delivers lecture
      lecture_prompt = Helpers.build_prompt(
        system: teacher_prompt,
        context: "DOMAIN LESSON:\n#{lesson}#{context_suffix}",
        instruction: "Deliver a clear, structured lesson to all learners. Cover all rules with examples. End with: \"Are there any questions?\""
      )
      lecture = LLM.call(lecture_prompt, model: model, tracker: tracker, phase: "education_#{condition}")
      turns << { 'speaker' => 'teacher', 'type' => 'lecture', 'content' => lecture }
      $stderr.puts "[#{condition}] Teacher delivered lecture (#{lecture.length} chars)"

      # Step 2: Each learner asks a question only if their type permits it
      questions = learner_ids.map do |learner_id|
        type_key = learner_type_keys[learner_id]
        asking   = type_key ? LearnerTypes.should_ask_question?(type_key) : true

        unless asking
          turns << { 'speaker' => learner_id, 'type' => 'question', 'content' => 'No questions.' }
          $stderr.puts "[#{condition}] #{learner_id} (#{type_key}) skipped question"
          next { learner_id: learner_id, question: 'No questions.' }
        end

        question_prompt = Helpers.build_prompt(
          system: learner_prompt,
          context: "CLASS LECTURE:\n#{lecture}",
          instruction: "You are #{learner_id}. Ask ONE question about something you want to clarify. If you understood everything, write exactly: No questions."
        )
        question = LLM.call(question_prompt, model: learner_model, tracker: tracker, phase: "education_#{condition}")
        turns << { 'speaker' => learner_id, 'type' => 'question', 'content' => question }
        $stderr.puts "[#{condition}] #{learner_id} asked question"
        { learner_id: learner_id, question: question }
      end

      real_questions = questions.reject { |q| q[:question].strip.downcase.start_with?('no questions') }

      # Step 3: Teacher answers all real questions in one response
      if real_questions.any?
        questions_text = real_questions.map { |q| "#{q[:learner_id]}: #{q[:question]}" }.join("\n\n")
        answer_prompt = Helpers.build_prompt(
          system: teacher_prompt,
          context: "DOMAIN LESSON:\n#{lesson}#{context_suffix}\n\nLECTURE DELIVERED:\n#{lecture}",
          instruction: "Answer these student questions publicly. Address each question clearly.\n\n#{questions_text}"
        )
        answers = LLM.call(answer_prompt, model: model, tracker: tracker, phase: "education_#{condition}")
        turns << { 'speaker' => 'teacher', 'type' => 'answers', 'content' => answers }
        $stderr.puts "[#{condition}] Teacher answered questions"
      end

      {
        'condition'   => condition,
        'teacher_id'  => teacher_id,
        'learner_ids' => learner_ids,
        'turns'       => turns
      }
    end
  end
end
```

- [ ] **Step 5.2: Run full test suite**

```bash
cd /Users/masumi/tmp/Agent-Based-Theory-Testing-2-Sigma-Problem
eval "$(mise activate bash)"
bash experiments/bloom_1n_vs_1on1/tests/run_tests.sh 2>&1
```

Expected: `All tests passed.`

- [ ] **Step 5.3: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/lib/phases/classroom.rb
git commit -m "feat: classroom phase — gate questions on LearnerTypes.should_ask_question?"
```

---

### Task 6: Update `lib/scorer.rb` — calibrated confidence and abstention fields

**Files:**
- Modify: `experiments/bloom_1n_vs_1on1/lib/scorer.rb`
- Modify: `experiments/bloom_1n_vs_1on1/tests/test_scorer.rb`

`total` score (0-12) is preserved unchanged for v5 comparability. New fields are additive.

- [ ] **Step 6.1: Add tests to `tests/test_scorer.rb`**

Append the following class at the end of the existing file:

```ruby
class TestCalibratedConfidence < Minitest::Test
  def make_task
    {
      'expected_answer'        => '3',
      'expected_active_tokens' => ['yellow'],
      'expected_mistakes'      => [],
      'acceptable_aliases'     => {}
    }
  end

  def test_high_confidence_correct_gives_positive_calibration
    parsed = { 'answer' => '3', 'active_tokens' => ['yellow'],
               'mistakes_found' => [], 'confidence' => 0.9, 'abstain' => false }
    score = Scorer.score_attempt(parsed, make_task)
    assert_equal 2, score['calibrated_confidence']
    refute score['high_confidence_wrong']
  end

  def test_high_confidence_wrong_gives_negative_calibration
    parsed = { 'answer' => '5', 'active_tokens' => ['yellow'],
               'mistakes_found' => [], 'confidence' => 0.8, 'abstain' => false }
    score = Scorer.score_attempt(parsed, make_task)
    assert_equal(-2, score['calibrated_confidence'])
    assert score['high_confidence_wrong']
  end

  def test_low_confidence_wrong_gives_zero_calibration
    parsed = { 'answer' => '5', 'active_tokens' => ['yellow'],
               'mistakes_found' => [], 'confidence' => 0.4, 'abstain' => false }
    score = Scorer.score_attempt(parsed, make_task)
    assert_equal 0, score['calibrated_confidence']
    refute score['high_confidence_wrong']
  end

  def test_abstained_response_marked_wrong_with_abstain_flag
    parsed = { 'answer' => '', 'active_tokens' => [],
               'mistakes_found' => [], 'confidence' => 0.2, 'abstain' => true }
    score = Scorer.score_attempt(parsed, make_task)
    refute score['answer_correct']
    assert score['abstained']
    assert_equal 1, score['abstention_quality']
  end

  def test_missing_confidence_defaults_to_zero
    parsed = { 'answer' => '3', 'active_tokens' => ['yellow'], 'mistakes_found' => [] }
    score = Scorer.score_attempt(parsed, make_task)
    assert_equal 0.0, score['confidence']
  end
end
```

- [ ] **Step 6.2: Run tests to confirm new tests fail**

```bash
cd /Users/masumi/tmp/Agent-Based-Theory-Testing-2-Sigma-Problem
eval "$(mise activate bash)"
bundle exec ruby experiments/bloom_1n_vs_1on1/tests/test_scorer.rb 2>&1 | grep -E "Failure|Error" | head -5
```

Expected: Failures because new score fields are absent.

- [ ] **Step 6.3: Replace the full content of `lib/scorer.rb`**

```ruby
# ABOUTME: Auto-scores eval task attempts using machine-checkable expected values
# ABOUTME: Adds calibrated_confidence, high_confidence_wrong, abstained, abstention_quality fields

module Scorer
  HIGH_CONFIDENCE_THRESHOLD = 0.7

  def self.score_attempt(parsed_response, task)
    return nil_score('Could not parse learner response as JSON') unless parsed_response.is_a?(Hash) && !parsed_response.empty?

    expected_answer   = task['expected_answer'].to_s.strip.downcase
    expected_tokens   = (task['expected_active_tokens'] || []).map { |t| t.to_s.downcase.strip }.sort
    expected_mistakes = task['expected_mistakes'] || []
    aliases           = task['acceptable_aliases'] || {}

    given_answer   = parsed_response['answer'].to_s.strip.downcase
    given_tokens   = (parsed_response['active_tokens'] || []).map { |t| t.to_s.downcase.strip }.sort
    given_mistakes = parsed_response['mistakes_found'] || []
    confidence     = parsed_response['confidence'].to_f
    abstained      = parsed_response['abstain'] == true

    answer_correct = given_answer == expected_answer
    unless answer_correct
      aliases.each do |_key, vals|
        answer_correct = true if Array(vals).map { |v| v.to_s.downcase }.include?(given_answer)
      end
    end
    answer_correct = false if abstained

    tokens_correct = given_tokens == expected_tokens

    mistakes_ratio = if expected_mistakes.empty?
      1.0
    else
      matched = expected_mistakes.count { |em|
        keywords = em.downcase.split(/\W+/).select { |w| w.length > 3 }
        given_mistakes.any? { |gm| keywords.any? { |kw| gm.to_s.downcase.include?(kw) } }
      }
      matched.to_f / expected_mistakes.size
    end

    correctness = answer_correct ? 4 : 0
    rule_app    = tokens_correct ? 4 : 0
    error_check = case mistakes_ratio
                  when 1.0       then 4
                  when 0.5..0.99 then 2
                  else                0
                  end

    high_conf_wrong    = !answer_correct && confidence >= HIGH_CONFIDENCE_THRESHOLD
    calibrated_conf    = if answer_correct && confidence >= HIGH_CONFIDENCE_THRESHOLD then  2
                         elsif !answer_correct && confidence >= HIGH_CONFIDENCE_THRESHOLD then -2
                         else 0
                         end
    abstention_quality = abstained ? 1 : 0

    {
      'answer_correct'        => answer_correct,
      'active_tokens_correct' => tokens_correct,
      'mistakes_found_ratio'  => mistakes_ratio.round(2),
      'correctness'           => correctness,
      'reasoning_quality'     => 0,
      'rule_application'      => rule_app,
      'error_checking'        => error_check,
      'autonomy'              => 0,
      'total'                 => correctness + rule_app + error_check,
      'auto_scored'           => true,
      'comments'              => build_comment(answer_correct, tokens_correct, mistakes_ratio),
      'confidence'            => confidence,
      'abstained'             => abstained,
      'high_confidence_wrong' => high_conf_wrong,
      'calibrated_confidence' => calibrated_conf,
      'abstention_quality'    => abstention_quality
    }
  end

  def self.nil_score(reason = 'Scoring failed')
    {
      'answer_correct' => false, 'active_tokens_correct' => false,
      'mistakes_found_ratio' => 0.0, 'correctness' => 0,
      'reasoning_quality' => 0, 'rule_application' => 0,
      'error_checking' => 0, 'autonomy' => 0, 'total' => 0,
      'auto_scored' => true, 'comments' => "Auto: #{reason}",
      'confidence' => 0.0, 'abstained' => false,
      'high_confidence_wrong' => false, 'calibrated_confidence' => 0,
      'abstention_quality' => 0
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

- [ ] **Step 6.4: Run full test suite**

```bash
cd /Users/masumi/tmp/Agent-Based-Theory-Testing-2-Sigma-Problem
eval "$(mise activate bash)"
bash experiments/bloom_1n_vs_1on1/tests/run_tests.sh 2>&1
```

Expected: `All tests passed.`

- [ ] **Step 6.5: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/lib/scorer.rb \
        experiments/bloom_1n_vs_1on1/tests/test_scorer.rb
git commit -m "feat: scorer — calibrated_confidence, high_confidence_wrong, abstained, abstention_quality"
```

---

### Task 7: Add `DB.all_memories_by_condition`

**Files:**
- Modify: `experiments/bloom_1n_vs_1on1/lib/db.rb`
- Modify: `experiments/bloom_1n_vs_1on1/tests/test_db.rb`

- [ ] **Step 7.1: Add tests to `tests/test_db.rb`**

Append the following class at the end of the existing file:

```ruby
class TestAllMemoriesByCondition < Minitest::Test
  def setup
    @db     = DB.setup(':memory:')
    @run_id = 'run-mem-test'
    DB.save_run(@db, @run_id, 'test_run', {})
  end

  def test_returns_memories_grouped_by_condition
    agent_a = DB.save_agent(@db, run_id: @run_id, role: 'learner',
                            condition: 'homogeneous_classroom', model: 'test',
                            profile: { 'type_key' => 'edge_case_dropper' })
    agent_b = DB.save_agent(@db, run_id: @run_id, role: 'learner',
                            condition: '1on1', model: 'test',
                            profile: { 'type_key' => 'rule_extractor' })

    DB.save_learner_memory(@db, run_id: @run_id, learner_id: agent_a,
                           condition: 'homogeneous_classroom',
                           memory: { 'rules' => ['rule A'], 'edge_cases' => [] })
    DB.save_learner_memory(@db, run_id: @run_id, learner_id: agent_b,
                           condition: '1on1',
                           memory: { 'rules' => ['rule B'], 'edge_cases' => ['edge1'] })

    result = DB.all_memories_by_condition(@db, @run_id)

    assert result.key?('homogeneous_classroom')
    assert result.key?('1on1')
    assert_equal 1, result['homogeneous_classroom'].size
    assert_equal ['rule A'], result['homogeneous_classroom'].first['memory']['rules']
    assert_equal 1, result['1on1'].size
    assert_equal 'rule_extractor', result['1on1'].first['type_key']
  end

  def test_returns_empty_hash_when_no_memories
    result = DB.all_memories_by_condition(@db, 'nonexistent-run')
    assert_equal({}, result)
  end
end
```

- [ ] **Step 7.2: Run tests to confirm new test fails**

```bash
cd /Users/masumi/tmp/Agent-Based-Theory-Testing-2-Sigma-Problem
eval "$(mise activate bash)"
bundle exec ruby experiments/bloom_1n_vs_1on1/tests/test_db.rb 2>&1 | grep -E "NoMethodError|Error" | head -5
```

Expected: `NoMethodError: undefined method 'all_memories_by_condition'`

- [ ] **Step 7.3: Add `all_memories_by_condition` to `lib/db.rb`**

In `lib/db.rb`, add the following method before the final `end` of the `DB` module (after `get_learner_memory`):

```ruby
  def self.all_memories_by_condition(db, run_id)
    rows = db.execute(<<~SQL, [run_id])
      SELECT lm.learner_id, lm.condition, lm.memory_json, a.profile_json
      FROM learner_memories lm
      LEFT JOIN agents a ON a.id = lm.learner_id
      WHERE lm.run_id = ?
      ORDER BY lm.condition, lm.learner_id
    SQL

    rows.group_by { |r| r['condition'] }.transform_values do |cond_rows|
      cond_rows.map do |r|
        profile  = r['profile_json'] ? JSON.parse(r['profile_json']) : {}
        type_key = profile['type_key']
        {
          'learner_id' => r['learner_id'],
          'memory'     => JSON.parse(r['memory_json']),
          'type_key'   => type_key
        }
      end
    end
  end
```

- [ ] **Step 7.4: Run full test suite**

```bash
cd /Users/masumi/tmp/Agent-Based-Theory-Testing-2-Sigma-Problem
eval "$(mise activate bash)"
bash experiments/bloom_1n_vs_1on1/tests/run_tests.sh 2>&1
```

Expected: `All tests passed.`

- [ ] **Step 7.5: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/lib/db.rb \
        experiments/bloom_1n_vs_1on1/tests/test_db.rb
git commit -m "feat: DB.all_memories_by_condition for v6 report sections"
```

---

### Task 8: Fix v5 report bugs and add four new v6 sections to `lib/report.rb`

**Files:**
- Modify: `experiments/bloom_1n_vs_1on1/lib/report.rb`
- Modify: `experiments/bloom_1n_vs_1on1/tests/test_report_v5.rb`

**Bugs fixed:** `detect_ceiling` and `build_token_data` hardcoded `'classroom'`; v5/v6 use `'homogeneous_classroom'`/`'heterogeneous_classroom'`.

**New sections:** score_by_learner_type, correction_rate_by_condition, remaining_misconceptions_by_condition, confidence calibration (high_confidence_wrong_rate + abstention_rate).

- [ ] **Step 8.1: Add tests to `tests/test_report_v5.rb`**

Append the following classes at the end of the existing file:

```ruby
class TestScoreByLearnerType < Minitest::Test
  def make_row(type_key, answer_correct)
    {
      'condition'    => '1on1',
      'learner_id'   => SecureRandom.uuid,
      'task_id'      => 'l1_recall_01',
      'task_type'    => 'recall',
      'score_json'   => JSON.dump({ 'answer_correct' => answer_correct }),
      'profile_json' => JSON.dump({ 'type_key' => type_key })
    }
  end

  def test_groups_by_type_key
    rows = [make_row('rule_extractor', true), make_row('rule_extractor', true),
            make_row('edge_case_dropper', false)]
    result = Report.score_by_learner_type(rows)
    assert_in_delta 1.0, result['rule_extractor'],    0.01
    assert_in_delta 0.0, result['edge_case_dropper'], 0.01
  end

  def test_missing_type_key_grouped_as_unknown
    row = make_row(nil, true)
    row['profile_json'] = JSON.dump({})
    result = Report.score_by_learner_type([row])
    assert result.key?('unknown')
  end
end

class TestCorrectionAndMiscMetrics < Minitest::Test
  def make_memory_entry(corrected, remaining)
    {
      'learner_id' => SecureRandom.uuid,
      'type_key'   => 'edge_case_dropper',
      'memory'     => {
        'corrected_misconceptions' => corrected,
        'remaining_misconceptions' => remaining
      }
    }
  end

  def test_correction_rate_counts_non_empty
    memories = {
      '1on1' => [
        make_memory_entry(['corrected X'], []),
        make_memory_entry([], [])
      ]
    }
    result = Report.correction_rate_by_condition(memories)
    assert_in_delta 0.5, result['1on1'], 0.01
  end

  def test_remaining_misconceptions_avg
    memories = {
      '1on1' => [
        make_memory_entry([], ['still wrong A', 'still wrong B']),
        make_memory_entry([], [])
      ]
    }
    result = Report.remaining_misconceptions_by_condition(memories)
    assert_in_delta 1.0, result['1on1'], 0.01
  end
end

class TestHighConfidenceWrongAndAbstention < Minitest::Test
  def make_row(high_conf_wrong:, abstained:)
    {
      'condition'  => '1on1',
      'learner_id' => SecureRandom.uuid,
      'score_json' => JSON.dump({ 'high_confidence_wrong' => high_conf_wrong,
                                  'abstained' => abstained,
                                  'answer_correct' => false })
    }
  end

  def test_high_confidence_wrong_rate
    rows = [make_row(high_conf_wrong: true,  abstained: false),
            make_row(high_conf_wrong: false, abstained: false),
            make_row(high_conf_wrong: true,  abstained: false)]
    assert_in_delta 2.0 / 3.0, Report.high_confidence_wrong_rate(rows), 0.01
  end

  def test_abstention_rate
    rows = [make_row(high_conf_wrong: false, abstained: true),
            make_row(high_conf_wrong: false, abstained: false)]
    assert_in_delta 0.5, Report.abstention_rate(rows), 0.01
  end
end
```

- [ ] **Step 8.2: Run tests to confirm new tests fail**

```bash
cd /Users/masumi/tmp/Agent-Based-Theory-Testing-2-Sigma-Problem
eval "$(mise activate bash)"
bundle exec ruby experiments/bloom_1n_vs_1on1/tests/test_report_v5.rb 2>&1 | grep -E "NoMethod|Error" | head -10
```

Expected: Several `NoMethodError` for missing report methods.

- [ ] **Step 8.3: Fix `detect_ceiling` in `lib/report.rb`**

In `detect_ceiling` method (around line 214), change:

```ruby
      c_pct      = avg_correctness(type_rows.select { |r| r['condition'] == 'classroom' })
```

To:

```ruby
      classroom_conds = %w[classroom homogeneous_classroom heterogeneous_classroom]
      c_pct           = avg_correctness(type_rows.select { |r| classroom_conds.include?(r['condition']) })
```

- [ ] **Step 8.4: Fix `build_token_data` in `lib/report.rb`**

In `build_token_data` method (around line 244), change:

```ruby
    edu_classroom = (token_summary['education_classroom'] || {})['total_tokens'].to_i
    edu_tutoring  = (token_summary['education_tutoring']  || {})['total_tokens'].to_i
    c_pct   = avg_correctness(by_condition['classroom']    || [])
```

To:

```ruby
    edu_classroom = %w[education_classroom education_homogeneous_classroom education_heterogeneous_classroom]
                      .sum { |k| (token_summary[k] || {})['total_tokens'].to_i }
    edu_tutoring  = (token_summary['education_tutoring'] || {})['total_tokens'].to_i
    classroom_rows = (by_condition['classroom'] || []) +
                     (by_condition['homogeneous_classroom'] || []) +
                     (by_condition['heterogeneous_classroom'] || [])
    c_pct          = avg_correctness(classroom_rows)
```

- [ ] **Step 8.5: Update `generate` and `build_markdown` to pass memories_by_condition**

In `generate` method (around line 15), change:

```ruby
  def self.generate(db, run_id:, output_dir:, run_config:, token_summary: {})
    FileUtils.mkdir_p(output_dir)
    rows = DB.all_attempts_with_scores(db, run_id)
    write_csv(rows, output_dir)
    markdown = build_markdown(rows, run_id: run_id, output_dir: output_dir,
                              run_config: run_config, token_summary: token_summary)
```

To:

```ruby
  def self.generate(db, run_id:, output_dir:, run_config:, token_summary: {})
    FileUtils.mkdir_p(output_dir)
    rows                  = DB.all_attempts_with_scores(db, run_id)
    memories_by_condition = DB.all_memories_by_condition(db, run_id)
    write_csv(rows, output_dir)
    markdown = build_markdown(rows, run_id: run_id, output_dir: output_dir,
                              run_config: run_config, token_summary: token_summary,
                              memories_by_condition: memories_by_condition)
```

In `build_markdown` method signature (around line 42), change:

```ruby
  def self.build_markdown(rows, run_id:, output_dir:, run_config:, token_summary:)
```

To:

```ruby
  def self.build_markdown(rows, run_id:, output_dir:, run_config:, token_summary:, memories_by_condition: {})
```

- [ ] **Step 8.6: Add new report sections to `build_markdown`**

In `build_markdown`, add the following block just before the `# Recommended Next Steps` section (after the existing heterogeneity_interpretation block):

```ruby
    # Score by learner type
    type_scores = score_by_learner_type(rows)
    unless type_scores.empty?
      lines << "## Score by Learner Type"
      lines << ""
      lines << "| Type | Correct% |"
      lines << "|------|---------|"
      type_scores.sort.each { |type, pct| lines << "| #{type} | #{(pct * 100).round}% |" }
      lines << ""
    end

    # Misconception correction metrics
    unless memories_by_condition.empty?
      corr_rates  = correction_rate_by_condition(memories_by_condition)
      remain_avgs = remaining_misconceptions_by_condition(memories_by_condition)
      lines << "## Misconception Correction by Condition"
      lines << ""
      lines << "| Condition | Correction Rate | Avg Remaining Misconceptions |"
      lines << "|-----------|----------------|------------------------------|"
      corr_rates.sort.each do |cond, rate|
        remain = remain_avgs[cond] || 0.0
        lines << "| #{cond} | #{(rate * 100).round}% | #{remain.round(2)} |"
      end
      lines << ""
    end

    # Confidence calibration summary
    hcw_rate  = high_confidence_wrong_rate(rows)
    abst_rate = abstention_rate(rows)
    lines << "## Confidence Calibration"
    lines << ""
    lines << "| Metric | Rate |"
    lines << "|--------|------|"
    lines << "| High-confidence wrong | #{(hcw_rate * 100).round}% |"
    lines << "| Abstention | #{(abst_rate * 100).round}% |"
    lines << ""
```

- [ ] **Step 8.7: Add five new methods to `lib/report.rb` before the final `end`**

Add after `bottom_learner_correctness`:

```ruby
  def self.score_by_learner_type(rows)
    grouped = rows.group_by do |r|
      profile = r['profile_json'] ? JSON.parse(r['profile_json']) : {}
      profile['type_key'] || 'unknown'
    end
    grouped.transform_values { |rs| avg_correctness(rs) }
  end

  def self.correction_rate_by_condition(memories_by_condition)
    memories_by_condition.transform_values do |entries|
      next 0.0 if entries.empty?
      corrected = entries.count { |e| Array(e.dig('memory', 'corrected_misconceptions')).any? }
      corrected.to_f / entries.size
    end
  end

  def self.remaining_misconceptions_by_condition(memories_by_condition)
    memories_by_condition.transform_values do |entries|
      next 0.0 if entries.empty?
      total = entries.sum { |e| Array(e.dig('memory', 'remaining_misconceptions')).size }
      total.to_f / entries.size
    end
  end

  def self.high_confidence_wrong_rate(rows)
    return 0.0 if rows.empty?
    count = rows.count { |r| r['score_json'] && JSON.parse(r['score_json'])['high_confidence_wrong'] == true }
    count.to_f / rows.size
  end

  def self.abstention_rate(rows)
    return 0.0 if rows.empty?
    count = rows.count { |r| r['score_json'] && JSON.parse(r['score_json'])['abstained'] == true }
    count.to_f / rows.size
  end
```

- [ ] **Step 8.8: Run full test suite**

```bash
cd /Users/masumi/tmp/Agent-Based-Theory-Testing-2-Sigma-Problem
eval "$(mise activate bash)"
bash experiments/bloom_1n_vs_1on1/tests/run_tests.sh 2>&1
```

Expected: `All tests passed.`

- [ ] **Step 8.9: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/lib/report.rb \
        experiments/bloom_1n_vs_1on1/tests/test_report_v5.rb
git commit -m "fix+feat: report — fix v5 classroom condition bugs, add learner_type/correction/calibration sections"
```

---

### Task 9: Update `scripts/run_experiment.rb` orchestrator for v6

**Files:**
- Modify: `experiments/bloom_1n_vs_1on1/scripts/run_experiment.rb`

- [ ] **Step 9.1: Replace the full content of `scripts/run_experiment.rb`**

```ruby
# ABOUTME: Main entry point for the Bloom 2 Sigma v6 learner-types experiment
# ABOUTME: 4 conditions with theory-driven learner types; type constraints applied at memory generation

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
require 'phases/classroom'
require 'phases/tutoring'
require 'phases/memory'
require 'phases/solver'
require 'phases/evaluator'
require 'phases/no_education'
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

tasks_file = config.dig('experiment', 'eval_tasks_file') || 'eval_tasks_v4.json'
lesson     = Helpers.load_file(File.join(domain_path, 'lesson.md'))
eval_tasks = JSON.parse(Helpers.load_file(File.join(domain_path, tasks_file)))
rubric     = JSON.parse(Helpers.load_file(File.join(domain_path, 'rubric.json')))

teacher_prompt    = Helpers.load_file(File.join(prompts_path, 'classroom_teacher.md'))
tutor_prompt      = Helpers.load_file(File.join(prompts_path, 'one_on_one_tutor.md'))
learner_prompt    = Helpers.load_file(File.join(prompts_path, 'learner.md'))
summarizer_prompt = Helpers.load_file(File.join(prompts_path, 'memory_summarizer.md'))
solver_prompt     = Helpers.load_file(File.join(prompts_path, 'problem_solver.md'))
evaluator_prompt  = Helpers.load_file(File.join(prompts_path, 'blind_evaluator.md'))

db = DB.setup(db_path)
DB.save_run(db, run_id, run_name, config)
File.write(File.join(run_dir, 'config.json'), JSON.pretty_generate(config))

n_homo   = config.dig('experiment', 'n_homogeneous_classroom')  || 4
n_hetero = config.dig('experiment', 'n_heterogeneous_classroom') || 4
n_tut    = config.dig('experiment', 'n_tutoring')               || 4
n_no_ed  = config.dig('experiment', 'n_no_education')           || 3

homo_type_keys   = LearnerTypes::HOMOGENEOUS_ASSIGNMENT.first(n_homo)
hetero_type_keys = LearnerTypes::HETEROGENEOUS_ASSIGNMENT.first([n_hetero, n_tut].max)

teacher_id   = DB.save_agent(db, run_id: run_id, role: 'classroom_teacher',
                              model: config.dig('models', 'teacher'))
tutor_id     = DB.save_agent(db, run_id: run_id, role: 'tutor',
                              model: config.dig('models', 'tutor'))
evaluator_id = DB.save_agent(db, run_id: run_id, role: 'evaluator',
                              model: config.dig('models', 'evaluator'))

homo_classroom_ids = homo_type_keys.map do |type_key|
  DB.save_agent(db, run_id: run_id, role: 'learner', condition: 'homogeneous_classroom',
                model: config.dig('models', 'learner'), profile: { 'type_key' => type_key.to_s })
end

hetero_classroom_ids = hetero_type_keys.first(n_hetero).map do |type_key|
  DB.save_agent(db, run_id: run_id, role: 'learner', condition: 'heterogeneous_classroom',
                model: config.dig('models', 'learner'), profile: { 'type_key' => type_key.to_s })
end

tutoring_ids = hetero_type_keys.first(n_tut).map do |type_key|
  DB.save_agent(db, run_id: run_id, role: 'learner', condition: '1on1',
                model: config.dig('models', 'learner'), profile: { 'type_key' => type_key.to_s })
end

no_education_ids = n_no_ed.times.map do
  DB.save_agent(db, run_id: run_id, role: 'learner', condition: 'no_education',
                model: config.dig('models', 'problem_solver'))
end

all_learners =
  homo_classroom_ids.map   { |id| { id: id, condition: 'homogeneous_classroom' } } +
  hetero_classroom_ids.map { |id| { id: id, condition: 'heterogeneous_classroom' } } +
  tutoring_ids.map         { |id| { id: id, condition: '1on1' } } +
  no_education_ids.map     { |id| { id: id, condition: 'no_education' } }

homo_type_map   = homo_classroom_ids.zip(homo_type_keys).to_h
hetero_type_map = hetero_classroom_ids.zip(hetero_type_keys.first(n_hetero)).to_h
tutor_type_map  = tutoring_ids.zip(hetero_type_keys.first(n_tut)).to_h

# === PHASE 1a: Homogeneous Classroom ===
$stderr.puts "[main] Phase 1a: Homogeneous classroom (#{n_homo} learners, all edge_case_dropper)"
homo_class_context = <<~CTX
  CLASS COMPOSITION: #{n_homo} learners, all of the same type (edge_case_dropper).
  - Tendency: grasp main rules but forget edge cases and boundary conditions
  - Common misconception: forgets_edge_cases
  Teach one shared lesson. Use worked examples. Emphasize edge cases explicitly.
CTX
homo_transcript = Phases::Classroom.run(
  teacher_id: teacher_id, learner_ids: homo_classroom_ids,
  teacher_prompt: teacher_prompt, learner_prompt: learner_prompt,
  lesson: lesson, config: config, tracker: tracker,
  class_context: homo_class_context,
  condition: 'homogeneous_classroom',
  learner_type_keys: homo_type_map
)
homo_classroom_ids.each do |learner_id|
  DB.save_learning_session(db,
    run_id: run_id, condition: 'homogeneous_classroom', learner_id: learner_id,
    teacher_or_tutor_id: teacher_id, transcript: homo_transcript
  )
end
File.open(File.join(run_dir, 'transcripts.jsonl'), 'a') { |f| f.puts JSON.dump(homo_transcript) }

# === PHASE 1b: Heterogeneous Classroom ===
$stderr.puts "[main] Phase 1b: Heterogeneous classroom (#{n_hetero} learners, mixed types)"
hetero_type_lines = hetero_type_keys.first(n_hetero).each_with_index.map do |t, i|
  "  Learner #{i + 1}: #{t} — #{LearnerTypes::DESCRIPTIONS[t]}"
end.join("\n")
hetero_class_context = <<~CTX
  CLASS COMPOSITION: #{n_hetero} learners with different learning types.
  #{hetero_type_lines}
  Teach ONE shared lesson. You cannot fully personalize to each learner. Public Q&A allowed.
CTX
hetero_transcript = Phases::Classroom.run(
  teacher_id: teacher_id, learner_ids: hetero_classroom_ids,
  teacher_prompt: teacher_prompt, learner_prompt: learner_prompt,
  lesson: lesson, config: config, tracker: tracker,
  class_context: hetero_class_context,
  condition: 'heterogeneous_classroom',
  learner_type_keys: hetero_type_map
)
hetero_classroom_ids.each do |learner_id|
  DB.save_learning_session(db,
    run_id: run_id, condition: 'heterogeneous_classroom', learner_id: learner_id,
    teacher_or_tutor_id: teacher_id, transcript: hetero_transcript
  )
end
File.open(File.join(run_dir, 'transcripts.jsonl'), 'a') { |f| f.puts JSON.dump(hetero_transcript) }

# === PHASE 2: 1on1 Tutoring (type-adapted sessions) ===
$stderr.puts "[main] Phase 2: 1on1 tutoring (#{n_tut} sessions, type-adapted)"
tutoring_ids.each_with_index do |learner_id, i|
  type_key   = hetero_type_keys[i]
  transcript = Phases::Tutoring.run_session(
    tutor_id: tutor_id, learner_id: learner_id,
    tutor_prompt: tutor_prompt, learner_prompt: learner_prompt,
    lesson: lesson, config: config, tracker: tracker,
    learner_type_key: type_key
  )
  DB.save_learning_session(db,
    run_id: run_id, condition: '1on1', learner_id: learner_id,
    teacher_or_tutor_id: tutor_id, transcript: transcript
  )
  File.open(File.join(run_dir, 'transcripts.jsonl'), 'a') { |f| f.puts JSON.dump(transcript) }
end

# === PHASE 2.5: No-Education Baseline ===
$stderr.puts "[main] Phase 2.5: No-education baseline (#{n_no_ed} learners)"
no_education_ids.each do |learner_id|
  memory = Phases::NoEducation.generate_memory(learner_id: learner_id)
  DB.save_learner_memory(db, run_id: run_id, learner_id: learner_id,
                         condition: 'no_education', memory: memory)
  File.open(File.join(run_dir, 'memories.jsonl'), 'a') do |f|
    f.puts JSON.dump({ learner_id: learner_id, condition: 'no_education', memory: memory })
  end
end

# === PHASE 3: Memory Generation (classroom + tutoring) ===
educated_learners =
  homo_classroom_ids.map   { |id| { id: id, condition: 'homogeneous_classroom', type_key: homo_type_map[id] } } +
  hetero_classroom_ids.map { |id| { id: id, condition: 'heterogeneous_classroom', type_key: hetero_type_map[id] } } +
  tutoring_ids.map         { |id| { id: id, condition: '1on1', type_key: tutor_type_map[id] } }

$stderr.puts "[main] Phase 3: Memory generation (#{educated_learners.size} learners)"
educated_learners.each do |learner|
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
    f.puts JSON.dump({ learner_id: learner[:id], condition: learner[:condition],
                       type_key: learner[:type_key], memory: memory })
  end
end

# === PHASE 4+5: Problem Solving + Auto-Scoring ===
$stderr.puts "[main] Phase 4+5: Solving + scoring (#{all_learners.size} × #{eval_tasks.size} tasks)"
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

# === PHASE 6: Report ===
$stderr.puts "[main] Phase 6: Generating report"
Report.generate(db, run_id: run_id, output_dir: run_dir,
                run_config: config, token_summary: tracker.summary)

db.close
$stderr.puts "[main] Done. Results in: #{run_dir}"
puts run_dir
```

- [ ] **Step 9.2: Run full test suite**

```bash
cd /Users/masumi/tmp/Agent-Based-Theory-Testing-2-Sigma-Problem
eval "$(mise activate bash)"
bash experiments/bloom_1n_vs_1on1/tests/run_tests.sh 2>&1
```

Expected: `All tests passed.`

- [ ] **Step 9.3: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/scripts/run_experiment.rb
git commit -m "feat: v6 orchestrator — LearnerTypes replaces Profiles, type keys flow through all phases"
```

---

### Task 10: Smoke test (n=1, haiku model)

This verifies the full pipeline runs end-to-end without errors before committing to a full n=4 run.

**Files:**
- Create: `experiments/bloom_1n_vs_1on1/config_smoke.yml`

- [ ] **Step 10.1: Create smoke test config**

Create `experiments/bloom_1n_vs_1on1/config_smoke.yml`:

```yaml
experiment:
  name: "bloom_learner_types_v6_smoke"
  domain: "zarn_tokens"
  n_homogeneous_classroom: 1
  n_heterogeneous_classroom: 1
  n_tutoring: 1
  n_no_education: 1
  tutoring_turns: 4
  eval_tasks_file: "eval_tasks_v4.json"
  max_memory_words: 120
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
  db: "experiments/bloom_1n_vs_1on1/data/smoke_test.db"
```

- [ ] **Step 10.2: Delete any existing smoke test DB**

```bash
rm -f /Users/masumi/tmp/Agent-Based-Theory-Testing-2-Sigma-Problem/experiments/bloom_1n_vs_1on1/data/smoke_test.db
```

- [ ] **Step 10.3: Run the smoke test**

```bash
cd /Users/masumi/tmp/Agent-Based-Theory-Testing-2-Sigma-Problem
eval "$(mise activate bash)"
bundle exec ruby experiments/bloom_1n_vs_1on1/scripts/run_experiment.rb \
  experiments/bloom_1n_vs_1on1/config_smoke.yml 2>&1
```

Expected: No Ruby exceptions; final line is a run dir path like `experiments/bloom_1n_vs_1on1/data/runs/<uuid>`.

- [ ] **Step 10.4: Verify output artifacts**

```bash
RUN_DIR=$(ls -td /Users/masumi/tmp/Agent-Based-Theory-Testing-2-Sigma-Problem/experiments/bloom_1n_vs_1on1/data/runs/* | head -1)
echo "=== memories 7-field check ==="
grep -o '"corrected_misconceptions"' "$RUN_DIR/memories.jsonl" | wc -l
echo "=== evaluations calibration check ==="
grep -o '"calibrated_confidence"' "$RUN_DIR/evaluations.jsonl" | wc -l
echo "=== report sections ==="
grep "^## " "$RUN_DIR/report.md"
```

Expected:
- `corrected_misconceptions` count >= 3 (one per educated learner's memory)
- `calibrated_confidence` count >= 4 (one per scored attempt)
- report.md contains `## Score by Learner Type` and `## Misconception Correction by Condition` and `## Confidence Calibration`

- [ ] **Step 10.5: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/config_smoke.yml
git commit -m "test: add smoke test config for v6 (n=1, haiku model)"
```

---

## Self-Review

**Spec coverage:**
- [x] 7 learner types with numeric constraints → Task 1
- [x] Operationalize as post-LLM memory constraints (not role-play) → Tasks 1, 3
- [x] 7-field memory schema → Tasks 2, 3
- [x] Diagnostic tutoring loop (diagnose-correct-retest) → Task 4
- [x] Classroom question gating on type probability → Task 5
- [x] Solver confidence + abstention fields → Task 2 (prompts)
- [x] Scorer: calibrated_confidence, abstention_quality, high_confidence_wrong → Task 6
- [x] DB.all_memories_by_condition → Task 7
- [x] Report: score_by_learner_type, remaining_misconceptions, correction_rate, high_confidence_wrong_rate, abstention_rate → Task 8
- [x] Fix v5 report bugs (hardcoded 'classroom') → Task 8
- [x] Orchestrator using LearnerTypes → Task 9
- [x] Smoke test → Task 10

**Type consistency:**
- `LearnerTypes.fetch` accepts both string and symbol via `to_sym` ✓
- Agent profile stored as `{ 'type_key' => 'edge_case_dropper' }` (string) in `profile_json` ✓
- `all_memories_by_condition` returns `'type_key'` as string; `score_by_learner_type` reads `profile['type_key']` as string ✓
- `homo_type_map` maps `agent_id => :edge_case_dropper` (symbol); `should_ask_question?` calls `fetch(type_key.to_sym)` ✓
- `Phases::NoEducation.generate_memory` returns a hash; `all_memories_by_condition` calls `Array(e.dig(...))` which returns `[]` for nil ✓

**Known non-blocking issue:** `build_markdown` metadata section still emits `n_classroom` (old v4 field name from config). Cosmetic only — does not affect data.
