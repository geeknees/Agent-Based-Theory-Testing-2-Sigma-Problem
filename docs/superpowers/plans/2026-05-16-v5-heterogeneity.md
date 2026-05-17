# v5 Learner Heterogeneity Experiment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Test whether 1on1 tutoring becomes more advantageous when learner heterogeneity is explicitly modeled — adding homogeneous_classroom vs heterogeneous_classroom comparison to isolate the heterogeneity effect.

**Architecture:** A new `Profiles` module provides two fixed learner profile sets (HOMOGENEOUS, HETEROGENEOUS). Classroom and Tutoring phases gain optional `class_context:` and `learner_profile:` parameters that inject profile-aware context into teacher/tutor prompts. The DB query gains a LEFT JOIN on agents for profile_json. Report gains profile-breakdown and heterogeneity-interpretation sections. Eval tasks are unchanged from v4.

**Tech Stack:** Ruby stdlib, sqlite3 — identical to v4.

---

## Why v4 needed this extension

v4 showed classroom (47%) > tutoring (28%), but all learners shared the same blank profile — no explicit ability differences, no misconceptions. Bloom's insight was specifically about tutoring's advantage with **heterogeneous** learners. A homogeneous classroom has no individual variation to remediate. This experiment separates those effects.

---

## File Map

```
CREATED:
  experiments/bloom_1n_vs_1on1/lib/profiles.rb
  experiments/bloom_1n_vs_1on1/tests/test_profiles.rb

MODIFIED:
  experiments/bloom_1n_vs_1on1/config.yml
  experiments/bloom_1n_vs_1on1/lib/db.rb              (add profile_json to query)
  experiments/bloom_1n_vs_1on1/lib/phases/classroom.rb (add class_context: param)
  experiments/bloom_1n_vs_1on1/lib/phases/tutoring.rb  (add learner_profile: param)
  experiments/bloom_1n_vs_1on1/lib/report.rb           (profile sections + interpretation)
  experiments/bloom_1n_vs_1on1/tests/run_tests.sh      (add test_profiles.rb)
  experiments/bloom_1n_vs_1on1/scripts/run_experiment.rb (4 conditions)
  experiments/bloom_1n_vs_1on1/README.md
```

---

## Task 1: Profiles Module (TDD)

**Files:**
- Create: `experiments/bloom_1n_vs_1on1/tests/test_profiles.rb` (write first)
- Create: `experiments/bloom_1n_vs_1on1/lib/profiles.rb`

### Step A: Write failing tests

- [ ] **Step 1: Create test_profiles.rb**

```ruby
# ABOUTME: Tests for the Profiles module — learner profile constants and prompt helpers
# ABOUTME: No LLM calls; purely deterministic structure and string generation

$LOAD_PATH.unshift File.join(__dir__, '..', 'lib')
require 'minitest/autorun'
require 'profiles'

class TestProfileConstants < Minitest::Test
  def test_homogeneous_has_4_profiles
    assert_equal 4, Profiles::HOMOGENEOUS.size
  end

  def test_heterogeneous_has_4_profiles
    assert_equal 4, Profiles::HETEROGENEOUS.size
  end

  def test_all_profiles_have_required_keys
    required = %i[ability interest misconception learning_style attention]
    (Profiles::HOMOGENEOUS + Profiles::HETEROGENEOUS).each do |p|
      required.each { |k| assert p.key?(k), "Missing key #{k} in #{p}" }
    end
  end

  def test_homogeneous_profiles_are_similar
    abilities = Profiles::HOMOGENEOUS.map { |p| p[:ability] }.uniq
    assert_equal ['medium'], abilities, "Homogeneous class should have uniform ability"
  end

  def test_heterogeneous_includes_all_ability_levels
    abilities = Profiles::HETEROGENEOUS.map { |p| p[:ability] }
    assert_includes abilities, 'high'
    assert_includes abilities, 'medium'
    assert_includes abilities, 'low'
  end

  def test_heterogeneous_includes_varied_misconceptions
    misconceptions = Profiles::HETEROGENEOUS.map { |p| p[:misconception] }.uniq
    assert misconceptions.size >= 3, "Heterogeneous class should have at least 3 distinct misconceptions"
  end
end

class TestProfilePromptHelpers < Minitest::Test
  def test_to_tutor_context_includes_ability
    profile = { ability: 'high', interest: 'abstract_rules', misconception: 'none',
                learning_style: 'rule_first', attention: 'high' }
    text = Profiles.to_tutor_context(profile)
    assert_includes text, 'high'
    assert_includes text, 'LEARNER PROFILE'
  end

  def test_to_tutor_context_includes_misconception_warning
    profile = { ability: 'low', interest: 'simple_sequences',
                misconception: 'thinks_blue_always_active',
                learning_style: 'step_by_step', attention: 'low' }
    text = Profiles.to_tutor_context(profile)
    assert_includes text.downcase, 'blue'
    assert_includes text.upcase, 'CRITICAL'
  end

  def test_to_tutor_context_none_misconception_has_no_critical
    profile = { ability: 'high', interest: 'abstract_rules', misconception: 'none',
                learning_style: 'rule_first', attention: 'high' }
    text = Profiles.to_tutor_context(profile)
    refute_includes text, 'CRITICAL'
  end

  def test_homogeneous_class_context_returns_string
    text = Profiles.homogeneous_class_context
    assert_instance_of String, text
    assert text.length > 50
    assert_includes text.downcase, 'medium'
  end

  def test_heterogeneous_class_context_includes_all_profiles
    text = Profiles.heterogeneous_class_context(Profiles::HETEROGENEOUS)
    assert_includes text, 'high'
    assert_includes text, 'low'
  end
end
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
cd /Users/masumi/tmp/Agent-Based-Theory-Testing-2-Sigma-Problem
bundle exec ruby experiments/bloom_1n_vs_1on1/tests/test_profiles.rb 2>&1 | head -5
```

Expected: `cannot load such file -- profiles`

### Step B: Implement profiles.rb

- [ ] **Step 3: Create lib/profiles.rb**

```ruby
# ABOUTME: Defines fixed learner profile sets for the heterogeneity experiment
# ABOUTME: Provides prompt-context helpers used by classroom and tutoring phases

module Profiles
  HOMOGENEOUS = [
    { ability: 'medium', interest: 'worked_examples', misconception: 'forgets_edge_cases',
      learning_style: 'example_first', attention: 'medium' },
    { ability: 'medium', interest: 'worked_examples', misconception: 'forgets_edge_cases',
      learning_style: 'example_first', attention: 'medium' },
    { ability: 'medium', interest: 'worked_examples', misconception: 'forgets_edge_cases',
      learning_style: 'example_first', attention: 'medium' },
    { ability: 'medium', interest: 'worked_examples', misconception: 'forgets_edge_cases',
      learning_style: 'example_first', attention: 'medium' },
  ].map(&:freeze).freeze

  HETEROGENEOUS = [
    { ability: 'high',   interest: 'abstract_rules',   misconception: 'none',
      learning_style: 'rule_first',    attention: 'high'   },
    { ability: 'medium', interest: 'worked_examples',  misconception: 'forgets_edge_cases',
      learning_style: 'example_first', attention: 'medium' },
    { ability: 'low',    interest: 'simple_sequences', misconception: 'applies_modifiers_before_activation',
      learning_style: 'step_by_step',  attention: 'low'    },
    { ability: 'medium', interest: 'worked_examples',  misconception: 'thinks_blue_always_active',
      learning_style: 'example_first', attention: 'medium' },
  ].map(&:freeze).freeze

  MISCONCEPTION_NOTES = {
    'none' =>
      'The learner has no known systematic misconception.',
    'forgets_edge_cases' =>
      'CRITICAL: This learner forgets edge cases — e.g., that Green at the last position is inactive, or that doubling an inactive token gives 0.',
    'applies_modifiers_before_activation' =>
      'CRITICAL: This learner incorrectly applies modifier rules (like Red doubling) before checking whether the target token is active.',
    'thinks_blue_always_active' =>
      'CRITICAL: This learner incorrectly believes Blue tokens are always active, regardless of whether Green appears to their left.',
  }.freeze

  INTEREST_NOTES = {
    'abstract_rules'   => 'Prefers clear, explicit rule statements over examples.',
    'worked_examples'  => 'Learns best through concrete worked examples.',
    'simple_sequences' => 'Needs short, simple sequences before tackling complex ones.',
  }.freeze

  def self.to_tutor_context(profile)
    <<~CONTEXT
      LEARNER PROFILE:
      - Ability: #{profile[:ability]}
      - Interest: #{INTEREST_NOTES.fetch(profile[:interest].to_s, profile[:interest])}
      - Misconception: #{MISCONCEPTION_NOTES.fetch(profile[:misconception].to_s, 'Unknown')}
      - Learning style: #{profile[:learning_style]}
      - Attention: #{profile[:attention]}

      Adapt your tutoring: match examples to their interest, explicitly diagnose and correct their misconception, keep explanations proportional to their attention level. Ensure the learner's memory includes: rules, edge cases, common mistake, personal strategy.
    CONTEXT
  end

  def self.to_learner_context(profile)
    <<~CONTEXT
      YOUR LEARNING PROFILE (respond authentically to this):
      - You engage best with: #{profile[:interest].to_s.gsub('_', ' ')}
      - Your attention level is: #{profile[:attention]}
    CONTEXT
  end

  def self.homogeneous_class_context
    <<~CONTEXT
      CLASS COMPOSITION: All 4 learners have similar profiles.
      - Ability: medium (all similar)
      - Interest: worked examples
      - Common misconception: forgets edge cases (e.g., Green at last position, doubling inactive tokens)
      - Learning style: example-first
      Teach one shared lesson. Use worked examples. Watch for edge case errors in Q&A.
    CONTEXT
  end

  def self.heterogeneous_class_context(profiles)
    lines = profiles.each_with_index.map do |p, i|
      "  Learner #{i + 1}: ability=#{p[:ability]}, interest=#{p[:interest].to_s.gsub('_', ' ')}, " \
      "misconception=#{p[:misconception].to_s.gsub('_', ' ')}"
    end.join("\n")
    <<~CONTEXT
      CLASS COMPOSITION: 4 learners with mixed profiles.
      #{lines}
      Teach ONE shared lesson. You cannot fully personalize to each learner. Public Q&A is allowed but keep answers useful to the whole class. Limited time prevents individual remediation of each learner's misconception.
    CONTEXT
  end
end
```

- [ ] **Step 4: Run tests — they must all pass**

```bash
bundle exec ruby experiments/bloom_1n_vs_1on1/tests/test_profiles.rb
```

Expected: `0 failures, 0 errors, 0 skips`

- [ ] **Step 5: Add to run_tests.sh and run full suite**

In `experiments/bloom_1n_vs_1on1/tests/run_tests.sh`, add before the final echo:
```bash
bundle exec ruby "$EXPERIMENT_DIR/tests/test_profiles.rb"
```

```bash
bash experiments/bloom_1n_vs_1on1/tests/run_tests.sh
```

Expected: `All tests passed.`

- [ ] **Step 6: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/lib/profiles.rb \
        experiments/bloom_1n_vs_1on1/tests/test_profiles.rb \
        experiments/bloom_1n_vs_1on1/tests/run_tests.sh
git commit -m "feat: add Profiles module (TDD) — HOMOGENEOUS and HETEROGENEOUS learner profile sets"
```

---

## Task 2: Update Config

**Files:**
- Modify: `experiments/bloom_1n_vs_1on1/config.yml`

- [ ] **Step 1: Replace config.yml entirely**

```yaml
experiment:
  name: "bloom_heterogeneity_v5"
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
  # learner_diagnostic: "claude-haiku-4-5-20251001"
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
git commit -m "feat: update config for v5 — 4 conditions with heterogeneity"
```

---

## Task 3: Update Classroom Phase

**Files:**
- Modify: `experiments/bloom_1n_vs_1on1/lib/phases/classroom.rb`

Add `class_context: nil` and `condition: 'classroom'` parameters. Inject `class_context` into teacher's lesson context when provided. Return value includes the condition.

- [ ] **Step 1: Read current classroom.rb to find the exact lecture_prompt block**

Read `experiments/bloom_1n_vs_1on1/lib/phases/classroom.rb`.

- [ ] **Step 2: Replace entire classroom.rb**

```ruby
# ABOUTME: Orchestrates 1:N classroom education for any classroom condition
# ABOUTME: Accepts class_context to make teacher aware of learner composition

require_relative '../llm'
require_relative '../helpers'

module Phases
  module Classroom
    def self.run(teacher_id:, learner_ids:, teacher_prompt:, learner_prompt:, lesson:,
                 config:, tracker: nil, class_context: nil, condition: 'classroom')
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

      # Step 2: Each learner asks one question
      questions = learner_ids.map do |learner_id|
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

      # Step 3: Teacher answers all questions in one response
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

- [ ] **Step 3: Verify syntax**

```bash
bundle exec ruby -c experiments/bloom_1n_vs_1on1/lib/phases/classroom.rb
```

Expected: `Syntax OK`

- [ ] **Step 4: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/lib/phases/classroom.rb
git commit -m "feat: classroom phase accepts class_context and condition params for v5"
```

---

## Task 4: Update Tutoring Phase

**Files:**
- Modify: `experiments/bloom_1n_vs_1on1/lib/phases/tutoring.rb`

Add `learner_profile: nil` parameter. When provided, inject `Profiles.to_tutor_context(profile)` into tutor prompts and `Profiles.to_learner_context(profile)` into learner prompts.

- [ ] **Step 1: Read current tutoring.rb**

Read `experiments/bloom_1n_vs_1on1/lib/phases/tutoring.rb`.

- [ ] **Step 2: Replace entire tutoring.rb**

```ruby
# ABOUTME: Orchestrates individual 1on1 tutoring sessions for each B-group learner
# ABOUTME: Accepts learner_profile to adapt tutor and learner prompts to individual characteristics

require_relative '../llm'
require_relative '../helpers'

module Phases
  module Tutoring
    def self.run_session(tutor_id:, learner_id:, tutor_prompt:, learner_prompt:, lesson:,
                         config:, tracker: nil, learner_profile: nil)
      tutor_model   = config.dig('models', 'tutor')   || 'claude-sonnet-4-6'
      learner_model = config.dig('models', 'learner') || 'claude-sonnet-4-6'

      profile_context  = learner_profile ? "\n\n#{Profiles.to_tutor_context(learner_profile)}" : ''
      learner_context  = learner_profile ? "\n\n#{Profiles.to_learner_context(learner_profile)}" : ''

      turns = []

      # Exchange 1, Turn 1: Tutor opens session
      opener_prompt = Helpers.build_prompt(
        system: tutor_prompt,
        context: "DOMAIN LESSON MATERIAL:\n#{lesson}#{profile_context}",
        instruction: "Begin a tutoring session with #{learner_id}. Teach the most important concept with a concrete example adapted to the learner's profile. Be concise — under 150 words."
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

      # Exchange 2, Turn 3: Tutor asks first diagnostic question
      history = Helpers.format_turns_for_prompt(turns)
      diag1_prompt = Helpers.build_prompt(
        system: tutor_prompt,
        context: "DOMAIN LESSON:\n#{lesson}#{profile_context}\n\nSESSION SO FAR:\n#{history}",
        instruction: "Ask ONE diagnostic question requiring the learner to apply a rule. Target the learner's known misconception if any. Under 60 words. Do not give the answer."
      )
      diag1 = LLM.call(diag1_prompt, model: tutor_model, tracker: tracker, phase: 'education_tutoring')
      turns << { 'speaker' => 'tutor', 'type' => 'diagnostic_q1', 'content' => diag1 }
      $stderr.puts "[tutoring:#{learner_id}] Tutor asked diagnostic Q1"

      # Exchange 2, Turn 4: Learner answers Q1
      history = Helpers.format_turns_for_prompt(turns)
      answer1_prompt = Helpers.build_prompt(
        system: learner_prompt,
        context: "SESSION SO FAR:\n#{history}#{learner_context}",
        instruction: "Answer the tutor's question. Show your step-by-step reasoning. If unsure, say so."
      )
      answer1 = LLM.call(answer1_prompt, model: learner_model, tracker: tracker, phase: 'education_tutoring')
      turns << { 'speaker' => 'learner', 'type' => 'answer1', 'content' => answer1 }
      $stderr.puts "[tutoring:#{learner_id}] Learner answered Q1"

      # Exchange 3, Turn 5: Tutor gives targeted feedback
      history = Helpers.format_turns_for_prompt(turns)
      feedback_prompt = Helpers.build_prompt(
        system: tutor_prompt,
        context: "DOMAIN LESSON:\n#{lesson}#{profile_context}\n\nSESSION SO FAR:\n#{history}",
        instruction: "Give targeted feedback. If the learner made an error related to their known misconception, correct it explicitly. If correct, confirm and mention one edge case. Under 100 words."
      )
      feedback = LLM.call(feedback_prompt, model: tutor_model, tracker: tracker, phase: 'education_tutoring')
      turns << { 'speaker' => 'tutor', 'type' => 'feedback', 'content' => feedback }
      $stderr.puts "[tutoring:#{learner_id}] Tutor gave feedback"

      # Exchange 3, Turn 6: Learner reflects
      history = Helpers.format_turns_for_prompt(turns)
      reflect_prompt = Helpers.build_prompt(
        system: learner_prompt,
        context: "SESSION SO FAR:\n#{history}#{learner_context}",
        instruction: "Acknowledge the tutor's feedback. State what you got wrong (if anything) and what the correct rule is. 1-3 sentences."
      )
      reflect = LLM.call(reflect_prompt, model: learner_model, tracker: tracker, phase: 'education_tutoring')
      turns << { 'speaker' => 'learner', 'type' => 'reflection', 'content' => reflect }
      $stderr.puts "[tutoring:#{learner_id}] Learner reflected"

      # Exchange 4, Turn 7: Tutor asks harder second diagnostic
      history = Helpers.format_turns_for_prompt(turns)
      diag2_prompt = Helpers.build_prompt(
        system: tutor_prompt,
        context: "DOMAIN LESSON:\n#{lesson}#{profile_context}\n\nSESSION SO FAR:\n#{history}",
        instruction: "Ask a second, harder diagnostic question testing a DIFFERENT rule or rule interaction. Under 80 words. Do not give the answer."
      )
      diag2 = LLM.call(diag2_prompt, model: tutor_model, tracker: tracker, phase: 'education_tutoring')
      turns << { 'speaker' => 'tutor', 'type' => 'diagnostic_q2', 'content' => diag2 }
      $stderr.puts "[tutoring:#{learner_id}] Tutor asked diagnostic Q2"

      # Exchange 4, Turn 8: Learner answers Q2
      history = Helpers.format_turns_for_prompt(turns)
      answer2_prompt = Helpers.build_prompt(
        system: learner_prompt,
        context: "SESSION SO FAR:\n#{history}#{learner_context}",
        instruction: "Answer the tutor's second question. Apply what you corrected in this session. Show your reasoning."
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

- [ ] **Step 4: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/lib/phases/tutoring.rb
git commit -m "feat: tutoring phase accepts learner_profile — adapts prompts to ability/misconception/interest"
```

---

## Task 5: Update DB Query (include profile_json)

**Files:**
- Modify: `experiments/bloom_1n_vs_1on1/lib/db.rb`

Add `LEFT JOIN agents a ON a.id = ta.learner_id` to `all_attempts_with_scores` to expose `profile_json` for report grouping.

- [ ] **Step 1: Read db.rb to find the all_attempts_with_scores method**

Read `experiments/bloom_1n_vs_1on1/lib/db.rb`, specifically the `all_attempts_with_scores` method.

- [ ] **Step 2: Replace the method body**

Find this in db.rb:
```ruby
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
      JOIN evaluation_tasks et ON et.id = ta.task_id
      LEFT JOIN evaluations e ON e.attempt_id = ta.id
      WHERE ta.run_id = ?
      ORDER BY ta.condition, ta.learner_id, et.task_type
    SQL
  end
```

Replace with:
```ruby
  def self.all_attempts_with_scores(db, run_id)
    db.execute(<<~SQL, [run_id])
      SELECT
        ta.id AS attempt_id,
        ta.learner_id,
        ta.condition,
        ta.task_id,
        et.task_type,
        ta.response_text,
        e.score_json,
        a.profile_json
      FROM task_attempts ta
      JOIN evaluation_tasks et ON et.id = ta.task_id
      LEFT JOIN evaluations e ON e.attempt_id = ta.id
      LEFT JOIN agents a ON a.id = ta.learner_id
      WHERE ta.run_id = ?
      ORDER BY ta.condition, ta.learner_id, et.task_type
    SQL
  end
```

- [ ] **Step 3: Run full test suite to ensure existing tests still pass**

```bash
bash experiments/bloom_1n_vs_1on1/tests/run_tests.sh
```

Expected: `All tests passed.`

- [ ] **Step 4: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/lib/db.rb
git commit -m "feat: all_attempts_with_scores includes profile_json via LEFT JOIN agents"
```

---

## Task 6: Update Report (TDD for new sections)

**Files:**
- Create: `experiments/bloom_1n_vs_1on1/tests/test_report_v5.rb`
- Modify: `experiments/bloom_1n_vs_1on1/lib/report.rb`
- Modify: `experiments/bloom_1n_vs_1on1/tests/run_tests.sh`

### Step A: Write failing tests

- [ ] **Step 1: Create test_report_v5.rb**

```ruby
# ABOUTME: TDD tests for v5 report additions — profile-based grouping and heterogeneity interpretation
# ABOUTME: Tests pure functions only; no DB or LLM calls

$LOAD_PATH.unshift File.join(__dir__, '..', 'lib')
require 'minitest/autorun'
require 'json'
require 'report'

class TestScoreByProfileDimension < Minitest::Test
  def make_row(condition, answer_correct, ability: 'medium', misconception: 'none', interest: 'worked_examples')
    profile = { 'ability' => ability, 'misconception' => misconception, 'interest' => interest }
    {
      'condition'    => condition,
      'task_type'    => 'recall',
      'task_id'      => 'l1_recall_01',
      'learner_id'   => SecureRandom.uuid,
      'score_json'   => JSON.dump({ 'answer_correct' => answer_correct, 'total' => answer_correct ? 4 : 0 }),
      'profile_json' => JSON.dump(profile)
    }
  end

  def test_groups_by_ability_correctly
    rows = [
      make_row('1on1', true,  ability: 'high'),
      make_row('1on1', false, ability: 'low'),
      make_row('1on1', true,  ability: 'high'),
    ]
    result = Report.score_by_profile_dimension(rows, 'ability')
    assert_in_delta 1.0, result['high'], 0.01
    assert_in_delta 0.0, result['low'],  0.01
  end

  def test_returns_zero_for_no_matching_rows
    rows = [make_row('1on1', true, ability: 'high')]
    result = Report.score_by_profile_dimension(rows, 'ability')
    assert_equal 0.0, result.fetch('low', 0.0)
  end

  def test_handles_nil_profile_json
    row = make_row('1on1', true)
    row['profile_json'] = nil
    result = Report.score_by_profile_dimension([row], 'ability')
    assert result.key?('unknown')
  end
end

class TestScoreVarianceByCondition < Minitest::Test
  require 'securerandom'

  def rows_for_learner(condition, learner_id, correct_count, total: 4)
    Array.new(total) do |i|
      {
        'condition'    => condition,
        'learner_id'   => learner_id,
        'task_id'      => "task_#{i}",
        'task_type'    => 'recall',
        'score_json'   => JSON.dump({ 'answer_correct' => i < correct_count, 'total' => i < correct_count ? 4 : 0 }),
        'profile_json' => nil
      }
    end
  end

  def test_zero_variance_when_all_same
    lid = SecureRandom.uuid
    rows = rows_for_learner('classroom', lid, 2)
    result = Report.score_variance_by_condition(rows)
    # Only 1 learner — variance undefined, should return 0
    assert_equal 0.0, result['classroom']
  end

  def test_nonzero_variance_when_learners_differ
    rows = rows_for_learner('classroom', 'learner_a', 4) +
           rows_for_learner('classroom', 'learner_b', 0)
    result = Report.score_variance_by_condition(rows)
    assert result['classroom'] > 0.3, "Expected significant variance, got #{result['classroom']}"
  end
end

class TestHeterogeneityInterpretation < Minitest::Test
  require 'securerandom'

  def make_rows(condition, correct_pct, ability: 'medium', n: 4)
    n.times.flat_map do |i|
      [{
        'condition'    => condition,
        'learner_id'   => "#{condition}_#{i}",
        'task_id'      => 'l1_recall_01',
        'task_type'    => 'recall',
        'score_json'   => JSON.dump({ 'answer_correct' => (i.to_f / n) < correct_pct }),
        'profile_json' => JSON.dump({ 'ability' => ability })
      }]
    end
  end

  def test_tutoring_advantage_under_heterogeneity
    rows = make_rows('1on1',                     0.75) +
           make_rows('heterogeneous_classroom',   0.25) +
           make_rows('homogeneous_classroom',     0.5)  +
           make_rows('no_education',              0.0)
    result = Report.heterogeneity_interpretation(rows, {})
    assert_includes result, 'tutoring_advantage_under_heterogeneity'
  end

  def test_heterogeneity_penalty_when_mixed_class_underperforms
    rows = make_rows('homogeneous_classroom',    0.75) +
           make_rows('heterogeneous_classroom',  0.25) +
           make_rows('1on1',                    0.5)   +
           make_rows('no_education',             0.0)
    result = Report.heterogeneity_interpretation(rows, {})
    assert_includes result, 'heterogeneity_penalty'
  end

  def test_classroom_advantage_under_homogeneity
    rows = make_rows('homogeneous_classroom',   0.8) +
           make_rows('1on1',                   0.5) +
           make_rows('heterogeneous_classroom', 0.4) +
           make_rows('no_education',            0.0)
    result = Report.heterogeneity_interpretation(rows, {})
    assert_includes result, 'classroom_advantage_under_homogeneity'
  end
end

class TestTokenPerCorrectAnswer < Minitest::Test
  def make_row(answer_correct)
    {
      'condition'  => 'classroom',
      'learner_id' => SecureRandom.uuid,
      'score_json' => JSON.dump({ 'answer_correct' => answer_correct })
    }
  end

  def test_returns_tokens_divided_by_correct
    rows = [make_row(true), make_row(false), make_row(true)]
    token_summary = { 'evaluation' => { 'total_tokens' => 1000 },
                      'memory'     => { 'total_tokens' => 500 } }
    result = Report.token_per_correct_answer(rows, token_summary)
    assert_equal 750, result  # 1500 tokens / 2 correct
  end

  def test_returns_zero_when_no_correct
    rows = [make_row(false)]
    result = Report.token_per_correct_answer(rows, { 'eval' => { 'total_tokens' => 100 } })
    assert_equal 0, result
  end
end
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
bundle exec ruby experiments/bloom_1n_vs_1on1/tests/test_report_v5.rb 2>&1 | head -5
```

Expected: errors like `undefined method 'score_by_profile_dimension'`

### Step B: Implement new report methods

- [ ] **Step 3: Add methods to report.rb**

After the `avg_total` method (end of report.rb), add these 4 methods:

```ruby
  def self.score_by_profile_dimension(rows, dimension)
    grouped = rows.group_by do |r|
      profile = r['profile_json'] ? JSON.parse(r['profile_json']) : {}
      profile[dimension.to_s] || 'unknown'
    end
    grouped.transform_values { |rs| avg_correctness(rs) }
  end

  def self.score_variance_by_condition(rows)
    by_condition = rows.group_by { |r| r['condition'] }
    by_condition.transform_values do |cond_rows|
      by_learner = cond_rows.group_by { |r| r['learner_id'] }
      scores = by_learner.values.map { |ls| avg_correctness(ls) }
      next 0.0 if scores.size < 2
      mean     = scores.sum / scores.size
      variance = scores.sum { |s| (s - mean)**2 } / (scores.size - 1)
      Math.sqrt(variance).round(3)
    end
  end

  def self.token_per_correct_answer(rows, token_summary)
    total_correct = rows.count { |r| r['score_json'] && JSON.parse(r['score_json'])['answer_correct'] == true }
    total_tokens  = token_summary.values.sum { |v| v['total_tokens'].to_i }
    return 0 if total_correct == 0
    (total_tokens.to_f / total_correct).round(0).to_i
  end

  def self.heterogeneity_interpretation(rows, token_summary)
    by_condition = rows.group_by { |r| r['condition'] }
    tutoring_pct = avg_correctness(by_condition['1on1']                    || [])
    hetero_pct   = avg_correctness(by_condition['heterogeneous_classroom'] || [])
    homo_pct     = avg_correctness(by_condition['homogeneous_classroom']   || [])

    results = []
    results << 'tutoring_advantage_under_heterogeneity' if tutoring_pct > hetero_pct
    results << 'classroom_advantage_under_homogeneity'   if homo_pct >= tutoring_pct
    results << 'heterogeneity_penalty'                   if hetero_pct < homo_pct

    low_tutoring = bottom_learner_correctness(by_condition['1on1']                    || [], 'low')
    low_hetero   = bottom_learner_correctness(by_condition['heterogeneous_classroom'] || [], 'low')
    results << 'bottom_learner_rescue' if low_tutoring > low_hetero

    results
  end

  def self.bottom_learner_correctness(cond_rows, target_ability)
    low_rows = cond_rows.select do |r|
      profile = r['profile_json'] ? JSON.parse(r['profile_json']) : {}
      profile['ability'] == target_ability
    end
    avg_correctness(low_rows)
  end
```

- [ ] **Step 4: Update build_markdown to include v5 sections**

In `build_markdown`, after the "Token Usage" section and before "Recommended Next Steps", add:

```ruby
    # Profile-based breakdown
    lines << "## Score by Learner Profile"
    lines << ""
    %w[ability misconception interest].each do |dim|
      by_dim = score_by_profile_dimension(rows, dim)
      next if by_dim.empty?
      lines << "### By #{dim.capitalize}"
      lines << ""
      lines << "| #{dim.capitalize} | Correct% |"
      lines << "|#{'-' * (dim.length + 2)}|---------|"
      by_dim.sort.each do |val, pct|
        lines << "| #{val} | #{(pct * 100).round}% |"
      end
      lines << ""
    end

    # Variance
    variance = score_variance_by_condition(rows)
    lines << "## Score Variance by Condition (std dev of per-learner correct%)"
    lines << ""
    lines << "| Condition | Std Dev |"
    lines << "|-----------|--------|"
    variance.sort.each do |cond, sd|
      lines << "| #{cond} | #{sd} |"
    end
    lines << ""

    # Token per correct answer
    tpca = token_per_correct_answer(rows, token_summary)
    lines << "**Token cost per correct answer:** #{tpca} tokens"
    lines << ""

    # Heterogeneity interpretation
    interpretations = heterogeneity_interpretation(rows, token_summary)
    lines << "## Heterogeneity Interpretation"
    lines << ""
    if interpretations.empty?
      lines << "No strong heterogeneity signal detected."
    else
      interpretations.each do |i|
        lines << "- **#{i}** ✓"
      end
    end
    lines << ""
```

- [ ] **Step 5: Also update Score by Condition and detect_ceiling to include v5 conditions**

In `build_markdown`, update the Score by Condition loop condition list:
```ruby
    %w[no_education homogeneous_classroom heterogeneous_classroom 1on1].each do |cond|
```

In `detect_ceiling`, update the condition references for `c_pct` and `t_pct` to be generic using the by_condition hash directly. The ceiling detection can remain conceptually the same but include all conditions.

Actually, to avoid breaking detect_ceiling, just update the by_condition references in the markdown sections while keeping detect_ceiling's 3-condition logic intact. The ceiling table will naturally include all present conditions via the task_type grouping — no change needed to `detect_ceiling` itself.

- [ ] **Step 6: Verify syntax**

```bash
bundle exec ruby -c experiments/bloom_1n_vs_1on1/lib/report.rb
```

- [ ] **Step 7: Run tests — must all pass**

```bash
bundle exec ruby experiments/bloom_1n_vs_1on1/tests/test_report_v5.rb
```

Expected: `0 failures, 0 errors, 0 skips`

- [ ] **Step 8: Add to run_tests.sh and run full suite**

In `run_tests.sh`, add before final echo:
```bash
bundle exec ruby "$EXPERIMENT_DIR/tests/test_report_v5.rb"
```

```bash
bash experiments/bloom_1n_vs_1on1/tests/run_tests.sh
```

Expected: `All tests passed.`

- [ ] **Step 9: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/lib/report.rb \
        experiments/bloom_1n_vs_1on1/tests/test_report_v5.rb \
        experiments/bloom_1n_vs_1on1/tests/run_tests.sh
git commit -m "feat: add v5 report sections — profile breakdown, variance, token efficiency, heterogeneity interpretation (TDD)"
```

---

## Task 7: Update Orchestrator

**Files:**
- Modify: `experiments/bloom_1n_vs_1on1/scripts/run_experiment.rb`

Replaces 3-condition flow with 4-condition flow. Assigns profiles to agents. Passes class_context to classroom phases and learner_profile to tutoring sessions.

- [ ] **Step 1: Read current run_experiment.rb**

Read `experiments/bloom_1n_vs_1on1/scripts/run_experiment.rb`.

- [ ] **Step 2: Replace entire run_experiment.rb**

```ruby
# ABOUTME: Main entry point for the Bloom 2 Sigma v5 heterogeneity experiment
# ABOUTME: Runs 4 conditions with explicit learner profiles; outputs 7 files plus profile-aware report

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
require 'profiles'
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

n_homo    = config.dig('experiment', 'n_homogeneous_classroom')  || 4
n_hetero  = config.dig('experiment', 'n_heterogeneous_classroom') || 4
n_tutoring  = config.dig('experiment', 'n_tutoring')            || 4
n_no_ed   = config.dig('experiment', 'n_no_education')          || 3

homo_profiles   = Profiles::HOMOGENEOUS.first(n_homo)
hetero_profiles = Profiles::HETEROGENEOUS.first([n_hetero, n_tutoring].max)

teacher_id = DB.save_agent(db, run_id: run_id, role: 'classroom_teacher',
                            model: config.dig('models', 'teacher'))
tutor_id   = DB.save_agent(db, run_id: run_id, role: 'tutor',
                            model: config.dig('models', 'tutor'))

homo_classroom_ids = homo_profiles.map do |profile|
  DB.save_agent(db, run_id: run_id, role: 'learner', condition: 'homogeneous_classroom',
                model: config.dig('models', 'learner'), profile: profile)
end

hetero_classroom_ids = hetero_profiles.first(n_hetero).map do |profile|
  DB.save_agent(db, run_id: run_id, role: 'learner', condition: 'heterogeneous_classroom',
                model: config.dig('models', 'learner'), profile: profile)
end

tutoring_ids = hetero_profiles.first(n_tutoring).map do |profile|
  DB.save_agent(db, run_id: run_id, role: 'learner', condition: '1on1',
                model: config.dig('models', 'learner'), profile: profile)
end

no_education_ids = n_no_ed.times.map do
  DB.save_agent(db, run_id: run_id, role: 'learner', condition: 'no_education',
                model: config.dig('models', 'problem_solver'))
end

evaluator_id = DB.save_agent(db, run_id: run_id, role: 'evaluator',
                              model: config.dig('models', 'evaluator'))

# all_learners for eval phases
all_learners =
  homo_classroom_ids.map   { |id| { id: id, condition: 'homogeneous_classroom' } } +
  hetero_classroom_ids.map { |id| { id: id, condition: 'heterogeneous_classroom' } } +
  tutoring_ids.map         { |id| { id: id, condition: '1on1' } } +
  no_education_ids.map     { |id| { id: id, condition: 'no_education' } }

# === PHASE 1a: Homogeneous Classroom ===
$stderr.puts "[main] Phase 1a: Homogeneous classroom (#{n_homo} learners)"
homo_transcript = Phases::Classroom.run(
  teacher_id: teacher_id, learner_ids: homo_classroom_ids,
  teacher_prompt: teacher_prompt, learner_prompt: learner_prompt,
  lesson: lesson, config: config, tracker: tracker,
  class_context: Profiles.homogeneous_class_context,
  condition: 'homogeneous_classroom'
)
homo_classroom_ids.each do |learner_id|
  DB.save_learning_session(db,
    run_id: run_id, condition: 'homogeneous_classroom', learner_id: learner_id,
    teacher_or_tutor_id: teacher_id, transcript: homo_transcript
  )
end
File.open(File.join(run_dir, 'transcripts.jsonl'), 'a') { |f| f.puts JSON.dump(homo_transcript) }

# === PHASE 1b: Heterogeneous Classroom ===
$stderr.puts "[main] Phase 1b: Heterogeneous classroom (#{n_hetero} learners)"
hetero_transcript = Phases::Classroom.run(
  teacher_id: teacher_id, learner_ids: hetero_classroom_ids,
  teacher_prompt: teacher_prompt, learner_prompt: learner_prompt,
  lesson: lesson, config: config, tracker: tracker,
  class_context: Profiles.heterogeneous_class_context(hetero_profiles.first(n_hetero)),
  condition: 'heterogeneous_classroom'
)
hetero_classroom_ids.each do |learner_id|
  DB.save_learning_session(db,
    run_id: run_id, condition: 'heterogeneous_classroom', learner_id: learner_id,
    teacher_or_tutor_id: teacher_id, transcript: hetero_transcript
  )
end
File.open(File.join(run_dir, 'transcripts.jsonl'), 'a') { |f| f.puts JSON.dump(hetero_transcript) }

# === PHASE 2: 1on1 Tutoring (with profiles) ===
$stderr.puts "[main] Phase 2: 1on1 tutoring (#{n_tutoring} sessions, profile-adapted)"
tutoring_ids.each_with_index do |learner_id, i|
  profile = hetero_profiles[i]
  transcript = Phases::Tutoring.run_session(
    tutor_id: tutor_id, learner_id: learner_id,
    tutor_prompt: tutor_prompt, learner_prompt: learner_prompt,
    lesson: lesson, config: config, tracker: tracker,
    learner_profile: profile
  )
  DB.save_learning_session(db,
    run_id: run_id, condition: '1on1', learner_id: learner_id,
    teacher_or_tutor_id: tutor_id, transcript: transcript
  )
  File.open(File.join(run_dir, 'transcripts.jsonl'), 'a') { |f| f.puts JSON.dump(transcript) }
end

# === PHASE 2.5: No-Education Baseline ===
$stderr.puts "[main] Phase 2.5: No-education baseline (#{n_no_ed} learners, zero LLM calls)"
no_education_ids.each do |learner_id|
  memory = Phases::NoEducation.generate_memory(learner_id: learner_id)
  DB.save_learner_memory(db, run_id: run_id, learner_id: learner_id,
                         condition: 'no_education', memory: memory)
  File.open(File.join(run_dir, 'memories.jsonl'), 'a') do |f|
    f.puts JSON.dump({ learner_id: learner_id, condition: 'no_education', memory: memory })
  end
end

# === PHASE 3: Memory Generation (classroom + tutoring only) ===
educated_learners =
  homo_classroom_ids.map   { |id| { id: id, condition: 'homogeneous_classroom' } } +
  hetero_classroom_ids.map { |id| { id: id, condition: 'heterogeneous_classroom' } } +
  tutoring_ids.map         { |id| { id: id, condition: '1on1' } }

$stderr.puts "[main] Phase 3: Memory generation (#{educated_learners.size} learners)"
educated_learners.each do |learner|
  transcript_row = db.execute(
    'SELECT transcript_json FROM learning_sessions WHERE run_id = ? AND learner_id = ? ORDER BY rowid DESC LIMIT 1',
    [run_id, learner[:id]]
  ).first
  transcript = JSON.parse(transcript_row['transcript_json'])
  memory = Phases::Memory.generate(
    learner_id: learner[:id], transcript: transcript,
    summarizer_prompt: summarizer_prompt, config: config, tracker: tracker
  )
  DB.save_learner_memory(db, run_id: run_id, learner_id: learner[:id],
                         condition: learner[:condition], memory: memory)
  File.open(File.join(run_dir, 'memories.jsonl'), 'a') do |f|
    f.puts JSON.dump({ learner_id: learner[:id], condition: learner[:condition], memory: memory })
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

- [ ] **Step 3: Verify syntax**

```bash
bundle exec ruby -c experiments/bloom_1n_vs_1on1/scripts/run_experiment.rb
```

Expected: `Syntax OK`

- [ ] **Step 4: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/scripts/run_experiment.rb
git commit -m "feat: v5 orchestrator — 4 conditions with learner profiles and heterogeneity-aware phases"
```

---

## Task 8: Run Full Test Suite

- [ ] **Step 1: Run all tests**

```bash
bash experiments/bloom_1n_vs_1on1/tests/run_tests.sh
```

Expected: `All tests passed.` with 0 failures across all test files.

- [ ] **Step 2: Fix any failures before proceeding**

If tests fail, read the error and fix the relevant module. Do not skip.

---

## Task 9: Smoke Test (n=1 per condition)

- [ ] **Step 1: Set n=1 in config.yml**

```yaml
  n_homogeneous_classroom: 1
  n_heterogeneous_classroom: 1
  n_tutoring: 1
  n_no_education: 1
```

- [ ] **Step 2: Run experiment**

```bash
bundle exec ruby experiments/bloom_1n_vs_1on1/scripts/run_experiment.rb \
  experiments/bloom_1n_vs_1on1/config.yml 2>&1
```

Monitor stderr. Expected progression:
```
[main] Phase 1a: Homogeneous classroom (1 learners)
[homogeneous_classroom] Teacher delivered lecture
[main] Phase 1b: Heterogeneous classroom (1 learners)
[heterogeneous_classroom] Teacher delivered lecture
[main] Phase 2: 1on1 tutoring (1 sessions, profile-adapted)
[tutoring:...] Tutor opened session
...
[tutoring:...] Learner answered Q2
[main] Phase 2.5: No-education baseline (1 learners, zero LLM calls)
[main] Phase 3: Memory generation (3 learners)
[main] Phase 4+5: ...
[main] Phase 6: Generating report
[main] Done.
```

- [ ] **Step 3: Verify all 7 files exist**

```bash
RUN_DIR=<path from step 2>
ls -la "$RUN_DIR"
```

Must see: `config.json`, `transcripts.jsonl`, `memories.jsonl`, `attempts.jsonl`, `evaluations.jsonl`, `scores.csv`, `report.md`

- [ ] **Step 4: Verify 4 conditions in scores.csv**

```bash
cut -d, -f2 "$RUN_DIR/scores.csv" | sort -u
```

Expected: `condition`, `homogeneous_classroom`, `heterogeneous_classroom`, `1on1`, `no_education`

- [ ] **Step 5: Verify profile_json appears in DB**

```bash
bundle exec ruby -e "
\$LOAD_PATH.unshift 'experiments/bloom_1n_vs_1on1/lib'
require 'db'
db = DB.setup('experiments/bloom_1n_vs_1on1/data/experiment.db')
profiles = db.execute('SELECT condition, profile_json FROM agents WHERE profile_json IS NOT NULL ORDER BY condition LIMIT 6')
profiles.each { |r| puts \"#{r['condition']}: #{r['profile_json'][0..60]}...\" }
db.close
"
```

Expected: rows showing each condition's profile JSON.

- [ ] **Step 6: Verify report.md has Heterogeneity Interpretation section**

```bash
grep "Heterogeneity Interpretation\|Score by Learner Profile\|Token cost" "$RUN_DIR/report.md"
```

Expected: all 3 section headers present.

- [ ] **Step 7: Restore config to production values**

```yaml
  n_homogeneous_classroom: 4
  n_heterogeneous_classroom: 4
  n_tutoring: 4
  n_no_education: 3
```

- [ ] **Step 8: Update README with v5 note**

Add to `experiments/bloom_1n_vs_1on1/README.md` after the v4 section:

```markdown
## v5 Methodology: Learner Heterogeneity

### Core hypothesis

Tutoring advantage should increase as learner heterogeneity increases. v4 assumed homogeneous learners; v5 makes heterogeneity explicit.

### Four conditions

| Condition | Education | Learner profiles |
|-----------|-----------|-----------------|
| no_education | None | No profile |
| homogeneous_classroom | 1:N shared lesson | All medium ability, same misconception |
| heterogeneous_classroom | 1:N shared lesson | Mixed ability, different misconceptions |
| 1on1 tutoring | 1on1 adapted session | Same profiles as heterogeneous_classroom |

### Heterogeneity interpretation

| Classification | Meaning |
|---------------|---------|
| tutoring_advantage_under_heterogeneity | tutoring > heterogeneous_classroom |
| classroom_advantage_under_homogeneity | homogeneous_classroom ≥ tutoring |
| heterogeneity_penalty | heterogeneous_classroom < homogeneous_classroom |
| bottom_learner_rescue | low-ability learners do better in tutoring than in heterogeneous_classroom |
```

- [ ] **Step 9: Final commit**

```bash
git add experiments/bloom_1n_vs_1on1/config.yml experiments/bloom_1n_vs_1on1/README.md
git commit -m "chore: restore n=4/4/4/3 after v5 smoke test; update README with v5 methodology"
```

---

## Self-Review

### Spec Coverage

| Requirement | Task |
|-------------|------|
| Learner profiles (5 dimensions) | Task 1 (Profiles module) |
| Homogeneous classroom condition | Tasks 3, 7 |
| Heterogeneous classroom condition | Tasks 3, 7 |
| 1on1 tutoring with profile-adapted prompts | Tasks 4, 7 |
| Teacher knows class composition | Task 3 (class_context param) |
| Tutor uses learner profile, targets misconception | Task 4 |
| score_by_condition, score_by_ability, score_by_misconception | Task 6 |
| score_variance_by_condition, bottom_learner, token_per_correct | Task 6 |
| tutoring_advantage_under_heterogeneity | Task 6 |
| classroom_advantage_under_homogeneity | Task 6 |
| heterogeneity_penalty | Task 6 |
| bottom_learner_rescue | Task 6 |
| profile_json in DB query for grouping | Task 5 |
| 4-condition orchestrator | Task 7 |
| Eval tasks unchanged from v4 | config uses eval_tasks_v4.json ✓ |
| n: 3/4/4/4 | Task 2 (config) |
| README methodology note | Task 9 |

### Placeholder Scan

No TBD/TODO. All code blocks are complete.

### Type Consistency

- `Profiles::HOMOGENEOUS` and `HETEROGENEOUS` use symbol keys (`:ability`, etc.) — `to_tutor_context` and `to_learner_context` use `profile[:key]` — consistent ✓
- `DB.save_agent` `profile:` keyword accepts Hash — DB stores as `JSON.dump(profile)` — `DB.all_attempts_with_scores` returns `profile_json` as String — Report parses with `JSON.parse(r['profile_json'])` using **string keys** (`profile['ability']`) — but Profiles constants use **symbol keys** — this mismatch matters only in `score_by_profile_dimension` which reads from DB rows (string keys) → consistent with `profile['ability']` usage ✓
- `Phases::Classroom.run` new params `class_context:` and `condition:` both have defaults → backward compatible, existing test_db.rb indirect calls unaffected ✓
- `Phases::Tutoring.run_session` new param `learner_profile:` has default `nil` → backward compatible ✓
- `Profiles.to_tutor_context(profile)` takes a hash with symbol keys (from HETEROGENEOUS constant) → called in orchestrator with `hetero_profiles[i]` which is a frozen Hash with symbol keys ✓
