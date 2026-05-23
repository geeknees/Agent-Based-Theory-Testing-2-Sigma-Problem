# v7 Mechanism Tests Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement two targeted mechanism tests (Exp A: passive_listener rescue; Exp B: order_confused intervention) to explain the v6 result that 1on1 helped passive_listener but hurt order_confused learners.

**Architecture:** Two independent orchestrator scripts (`run_experiment_a.rb`, `run_experiment_b.rb`) share the existing lib layer. Two new phases (`ClassroomForcedCheckin`, `TutoringProcedureScaffolded`) plus two new prompts are added. The Report module gains three new section methods and dynamic condition detection. All existing tests continue passing.

**Tech Stack:** Ruby, SQLite3 (via sqlite3 gem), Minitest, `claude --print` CLI (via LLM module)

---

## File Structure

### New files
| File | Purpose |
|------|---------|
| `experiments/bloom_1n_vs_1on1/prompts/classroom_forced_checkin_teacher.md` | System prompt for forced-checkin teacher |
| `experiments/bloom_1n_vs_1on1/prompts/tutor_procedure_scaffolded.md` | System prompt for procedure-scaffolded tutor |
| `experiments/bloom_1n_vs_1on1/lib/phases/classroom_forced_checkin.rb` | New phase: shared lesson + per-learner comprehension check |
| `experiments/bloom_1n_vs_1on1/lib/phases/tutoring_procedure_scaffolded.rb` | New phase: 4-step procedure checklist with restatement + labelled retest |
| `experiments/bloom_1n_vs_1on1/scripts/run_experiment_a.rb` | Orchestrator for Exp A (passive_listener rescue) |
| `experiments/bloom_1n_vs_1on1/scripts/run_experiment_b.rb` | Orchestrator for Exp B (order_confused intervention) |
| `experiments/bloom_1n_vs_1on1/config_v7a.yml` | Exp A full config (n=4, sonnet) |
| `experiments/bloom_1n_vs_1on1/config_v7b.yml` | Exp B full config (n=4, sonnet) |
| `experiments/bloom_1n_vs_1on1/config_v7a_smoke.yml` | Exp A smoke config (n=1, haiku) |
| `experiments/bloom_1n_vs_1on1/config_v7b_smoke.yml` | Exp B smoke config (n=1, haiku) |
| `experiments/bloom_1n_vs_1on1/tests/test_classroom_forced_checkin.rb` | Tests for ClassroomForcedCheckin phase |
| `experiments/bloom_1n_vs_1on1/tests/test_tutoring_procedure_scaffolded.rb` | Tests for TutoringProcedureScaffolded phase |
| `experiments/bloom_1n_vs_1on1/tests/test_report_v7.rb` | Tests for new report sections |

### Modified files
| File | Change |
|------|--------|
| `experiments/bloom_1n_vs_1on1/lib/phases/tutoring.rb:11` | Add optional `condition: '1on1'` param; use in return hash |
| `experiments/bloom_1n_vs_1on1/lib/report.rb:44,85,250` | Dynamic condition detection; `experiment_meta:` param; 3 new section methods |
| `experiments/bloom_1n_vs_1on1/tests/run_tests.sh` | Add 3 new test files |

---

## Task 1: New Prompts

**Files:**
- Create: `experiments/bloom_1n_vs_1on1/prompts/classroom_forced_checkin_teacher.md`
- Create: `experiments/bloom_1n_vs_1on1/prompts/tutor_procedure_scaffolded.md`

No tests for prompt content — these are natural language files verified by smoke test.

- [ ] **Step 1: Create classroom_forced_checkin_teacher.md**

```
experiments/bloom_1n_vs_1on1/prompts/classroom_forced_checkin_teacher.md
```

Content:
```markdown
You are a classroom teacher delivering a lesson with individual comprehension checks.

Your role:
- Deliver one clear, structured lesson to all learners simultaneously
- After the lesson, conduct a brief individual check-in with EACH learner in turn
- Ask each learner exactly ONE short comprehension question (under 40 words)
- If a learner's answer contains a clear error, give ONE short public correction (under 30 words)
- If the answer is correct, confirm it briefly
- Keep the pace brisk — this is not a full tutoring session

Tone: professional, clear. The check-in is a brief accountability measure, not extended coaching.
```

- [ ] **Step 2: Create tutor_procedure_scaffolded.md**

```
experiments/bloom_1n_vs_1on1/prompts/tutor_procedure_scaffolded.md
```

Content:
```markdown
You are a one-on-one tutor working with a learner who tends to apply rules in the wrong order.

Your role:
- Teach an explicit numbered procedure for solving token problems
- Require the learner to restate the procedure in their own words before proceeding
- Ask a diagnostic question to reveal whether they apply modifiers before checking activation
- Correct any procedure order violations explicitly: Step 1 (activation check) ALWAYS precedes Step 2 (modifiers)
- Ask a retest question and require the learner to label each step as they work (Step 1:, Step 2:, etc.)

The 4-step procedure you must teach:
  Step 1: Determine which tokens are active (check Green Token position first)
  Step 2: Apply modifiers ONLY to active tokens
  Step 3: Apply edge case rules if any apply
  Step 4: Sum the final token scores

Tone: methodical, precise. Procedure correctness matters more than speed.
```

- [ ] **Step 3: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/prompts/classroom_forced_checkin_teacher.md \
        experiments/bloom_1n_vs_1on1/prompts/tutor_procedure_scaffolded.md
git commit -m "feat: v7 prompts — forced-checkin teacher and procedure-scaffolded tutor"
```

---

## Task 2: ClassroomForcedCheckin Phase

**Files:**
- Create: `experiments/bloom_1n_vs_1on1/lib/phases/classroom_forced_checkin.rb`
- Create: `experiments/bloom_1n_vs_1on1/tests/test_classroom_forced_checkin.rb`

The phase: shared lecture → teacher asks each learner one check-in question → learner must answer → teacher gives correction if wrong. Unlike Classroom, question-asking is not gated by `should_ask_question?`.

- [ ] **Step 1: Write failing tests**

Create `experiments/bloom_1n_vs_1on1/tests/test_classroom_forced_checkin.rb`:

```ruby
# ABOUTME: Tests for ClassroomForcedCheckin phase — verifies turn structure and forced interaction
# ABOUTME: Uses LLM stub to avoid real API calls; tests are purely structural

$LOAD_PATH.unshift File.join(__dir__, '..', 'lib')
require 'minitest/autorun'
require 'phases/classroom_forced_checkin'

class TestClassroomForcedCheckin < Minitest::Test
  def test_config
    { 'models' => { 'teacher' => 'model', 'learner' => 'model' } }
  end

  def stub_run(learner_ids)
    LLM.stub(:call, 'stub response') do
      Phases::ClassroomForcedCheckin.run(
        teacher_id: 'teacher1',
        learner_ids: learner_ids,
        teacher_prompt: 'sys',
        learner_prompt: 'sys',
        lesson: 'lesson text',
        config: test_config
      )
    end
  end

  def test_returns_correct_condition_name
    result = stub_run(['l1'])
    assert_equal 'classroom_forced_checkin', result['condition']
  end

  def test_includes_lecture_turn
    result = stub_run(['l1', 'l2'])
    types = result['turns'].map { |t| t['type'] }
    assert_includes types, 'lecture'
  end

  def test_generates_checkin_question_for_each_learner
    result = stub_run(['l1', 'l2', 'l3'])
    checkins = result['turns'].select { |t| t['type'] == 'checkin_question' }
    assert_equal 3, checkins.size
  end

  def test_generates_checkin_answer_for_each_learner
    result = stub_run(['l1', 'l2'])
    answers = result['turns'].select { |t| t['type'] == 'checkin_answer' }
    assert_equal 2, answers.size
  end

  def test_generates_correction_for_each_learner
    result = stub_run(['l1', 'l2'])
    corrections = result['turns'].select { |t| t['type'] == 'checkin_correction' }
    assert_equal 2, corrections.size
  end

  def test_turn_count_is_one_lecture_plus_three_per_learner
    learner_ids = %w[l1 l2 l3]
    result = stub_run(learner_ids)
    # 1 lecture + (1 question + 1 answer + 1 correction) × n
    assert_equal 1 + 3 * learner_ids.size, result['turns'].size
  end

  def test_checkin_question_has_target_field
    result = stub_run(['l1'])
    checkin = result['turns'].find { |t| t['type'] == 'checkin_question' }
    assert_equal 'l1', checkin['target']
  end

  def test_learner_answers_are_attributed_to_correct_learner
    result = stub_run(['l1', 'l2'])
    speakers = result['turns'].select { |t| t['type'] == 'checkin_answer' }.map { |t| t['speaker'] }
    assert_includes speakers, 'l1'
    assert_includes speakers, 'l2'
  end

  def test_stores_all_learner_ids
    result = stub_run(['l1', 'l2'])
    assert_equal ['l1', 'l2'], result['learner_ids']
  end
end
```

- [ ] **Step 2: Run to confirm failure**

```bash
eval "$(mise activate zsh)" && bundle exec ruby experiments/bloom_1n_vs_1on1/tests/test_classroom_forced_checkin.rb
```

Expected: `LoadError: cannot load such file -- phases/classroom_forced_checkin`

- [ ] **Step 3: Create the phase implementation**

Create `experiments/bloom_1n_vs_1on1/lib/phases/classroom_forced_checkin.rb`:

```ruby
# ABOUTME: Orchestrates classroom with forced individual comprehension check-ins after shared lesson
# ABOUTME: Unlike standard classroom, every learner must answer — no question_asking_probability gating

require_relative '../llm'
require_relative '../helpers'

module Phases
  module ClassroomForcedCheckin
    def self.run(teacher_id:, learner_ids:, teacher_prompt:, learner_prompt:, lesson:,
                 config:, tracker: nil, class_context: nil)
      condition     = 'classroom_forced_checkin'
      model         = config.dig('models', 'teacher') || 'claude-sonnet-4-6'
      learner_model = config.dig('models', 'learner') || 'claude-sonnet-4-6'

      turns          = []
      context_suffix = class_context ? "\n\n#{class_context}" : ''

      # Step 1: Shared lesson (identical to standard classroom, slightly shorter budget)
      lecture_prompt = Helpers.build_prompt(
        system: teacher_prompt,
        context: "DOMAIN LESSON:\n#{lesson}#{context_suffix}",
        instruction: "Deliver a clear, structured lesson covering all rules with examples. Under 200 words."
      )
      lecture = LLM.call(lecture_prompt, model: model, tracker: tracker, phase: "education_#{condition}")
      turns << { 'speaker' => 'teacher', 'type' => 'lecture', 'content' => lecture }
      $stderr.puts "[#{condition}] Teacher delivered lecture (#{lecture.length} chars)"

      # Step 2: Individual forced check-ins — bypasses should_ask_question? entirely
      learner_ids.each do |learner_id|
        # Teacher asks one check-in question
        q_prompt = Helpers.build_prompt(
          system: teacher_prompt,
          context: "DOMAIN LESSON:\n#{lesson}\n\nLECTURE DELIVERED:\n#{lecture}",
          instruction: "Ask learner #{learner_id} ONE short comprehension check question to test their understanding. Under 40 words. Do not give the answer."
        )
        q = LLM.call(q_prompt, model: model, tracker: tracker, phase: "education_#{condition}")
        turns << { 'speaker' => 'teacher', 'type' => 'checkin_question', 'content' => q, 'target' => learner_id }
        $stderr.puts "[#{condition}] Teacher asked check-in for #{learner_id}"

        # Learner must answer (no gating)
        a_prompt = Helpers.build_prompt(
          system: learner_prompt,
          context: "CLASS LECTURE:\n#{lecture}\n\nTEACHER ASKED YOU:\n#{q}",
          instruction: "Answer the teacher's question. 1-2 sentences."
        )
        a = LLM.call(a_prompt, model: learner_model, tracker: tracker, phase: "education_#{condition}")
        turns << { 'speaker' => learner_id, 'type' => 'checkin_answer', 'content' => a }
        $stderr.puts "[#{condition}] #{learner_id} answered check-in"

        # Teacher gives brief public correction if needed
        corr_prompt = Helpers.build_prompt(
          system: teacher_prompt,
          context: "DOMAIN LESSON:\n#{lesson}\n\nCHECK-IN Q:\n#{q}\n\nLEARNER ANSWER:\n#{a}",
          instruction: "If the learner's answer contains a clear error, give ONE short public correction (under 30 words). If the answer is correct, write exactly: Correct."
        )
        corr = LLM.call(corr_prompt, model: model, tracker: tracker, phase: "education_#{condition}")
        turns << { 'speaker' => 'teacher', 'type' => 'checkin_correction', 'content' => corr, 'target' => learner_id }
        $stderr.puts "[#{condition}] Teacher correction for #{learner_id}: #{corr[0..60]}"
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

- [ ] **Step 4: Run tests to confirm passing**

```bash
eval "$(mise activate zsh)" && bundle exec ruby experiments/bloom_1n_vs_1on1/tests/test_classroom_forced_checkin.rb
```

Expected: `9 runs, 0 failures, 0 errors`

- [ ] **Step 5: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/lib/phases/classroom_forced_checkin.rb \
        experiments/bloom_1n_vs_1on1/tests/test_classroom_forced_checkin.rb
git commit -m "feat: ClassroomForcedCheckin phase — forced per-learner check-in after shared lesson"
```

---

## Task 3: TutoringProcedureScaffolded Phase

**Files:**
- Create: `experiments/bloom_1n_vs_1on1/lib/phases/tutoring_procedure_scaffolded.rb`
- Create: `experiments/bloom_1n_vs_1on1/tests/test_tutoring_procedure_scaffolded.rb`

8-turn session: procedure_intro → procedure_restatement → diagnostic_q → diagnostic_answer → procedure_correction → correction_acknowledgment → retest_q → retest_answer.

- [ ] **Step 1: Write failing tests**

Create `experiments/bloom_1n_vs_1on1/tests/test_tutoring_procedure_scaffolded.rb`:

```ruby
# ABOUTME: Tests for TutoringProcedureScaffolded phase — verifies 8-turn structure with procedure labels
# ABOUTME: Uses LLM stub; tests are purely structural — verifies turn types in order

$LOAD_PATH.unshift File.join(__dir__, '..', 'lib')
require 'minitest/autorun'
require 'phases/tutoring_procedure_scaffolded'

class TestTutoringProcedureScaffolded < Minitest::Test
  def test_config
    { 'models' => { 'tutor' => 'model', 'learner' => 'model' } }
  end

  def stub_session
    LLM.stub(:call, 'stub response') do
      Phases::TutoringProcedureScaffolded.run_session(
        tutor_id: 'tutor1',
        learner_id: 'learner1',
        tutor_prompt: 'sys',
        learner_prompt: 'sys',
        lesson: 'lesson text',
        config: test_config
      )
    end
  end

  def test_returns_correct_condition_name
    result = stub_session
    assert_equal 'procedure_scaffolded_one_on_one_tutoring', result['condition']
  end

  def test_has_exactly_eight_turns
    result = stub_session
    assert_equal 8, result['turns'].size
  end

  def test_turn_types_in_order
    result = stub_session
    expected_types = %w[
      procedure_intro
      procedure_restatement
      diagnostic_q
      diagnostic_answer
      procedure_correction
      correction_acknowledgment
      retest_q
      retest_answer
    ]
    actual_types = result['turns'].map { |t| t['type'] }
    assert_equal expected_types, actual_types
  end

  def test_tutor_speaks_on_odd_turns
    result = stub_session
    tutor_turns = result['turns'].select { |t| t['speaker'] == 'tutor1' }
    assert_equal 4, tutor_turns.size
  end

  def test_learner_speaks_on_even_turns
    result = stub_session
    learner_turns = result['turns'].select { |t| t['speaker'] == 'learner1' }
    assert_equal 4, learner_turns.size
  end

  def test_stores_tutor_and_learner_ids
    result = stub_session
    assert_equal 'tutor1',   result['tutor_id']
    assert_equal 'learner1', result['learner_id']
  end

  def test_procedure_intro_is_first_turn
    result = stub_session
    assert_equal 'procedure_intro', result['turns'].first['type']
  end

  def test_retest_answer_is_last_turn
    result = stub_session
    assert_equal 'retest_answer', result['turns'].last['type']
  end
end
```

- [ ] **Step 2: Run to confirm failure**

```bash
eval "$(mise activate zsh)" && bundle exec ruby experiments/bloom_1n_vs_1on1/tests/test_tutoring_procedure_scaffolded.rb
```

Expected: `LoadError: cannot load such file -- phases/tutoring_procedure_scaffolded`

- [ ] **Step 3: Create the phase implementation**

Create `experiments/bloom_1n_vs_1on1/lib/phases/tutoring_procedure_scaffolded.rb`:

```ruby
# ABOUTME: Tutoring phase with explicit 4-step procedure checklist for order_confused learners
# ABOUTME: Learner restates procedure after intro; must label steps during retest

require_relative '../llm'
require_relative '../helpers'
require_relative '../learner_types'

module Phases
  module TutoringProcedureScaffolded
    PROCEDURE = <<~PROC.freeze
      Step 1: Determine which tokens are active (check Green Token position first)
      Step 2: Apply modifiers ONLY to active tokens
      Step 3: Apply edge case rules if any apply
      Step 4: Sum the final token scores
    PROC

    def self.run_session(tutor_id:, learner_id:, tutor_prompt:, learner_prompt:, lesson:,
                         config:, tracker: nil)
      condition     = 'procedure_scaffolded_one_on_one_tutoring'
      tutor_model   = config.dig('models', 'tutor')   || 'claude-sonnet-4-6'
      learner_model = config.dig('models', 'learner') || 'claude-sonnet-4-6'
      type_context  = LearnerTypes.to_prompt_context(:order_confused)

      turns = []

      # Exchange 1, Turn 1: Tutor teaches explicit 4-step procedure
      opener_prompt = Helpers.build_prompt(
        system: tutor_prompt,
        context: "DOMAIN LESSON:\n#{lesson}\n\n#{type_context}",
        instruction: "Teach this learner the exact 4-step procedure:\n#{PROCEDURE}\nPresent steps in numbered order. Emphasize that Step 1 (activation check) ALWAYS precedes Step 2 (modifiers). Under 150 words."
      )
      opener = LLM.call(opener_prompt, model: tutor_model, tracker: tracker, phase: "education_#{condition}")
      turns << { 'speaker' => tutor_id, 'type' => 'procedure_intro', 'content' => opener }
      $stderr.puts "[#{condition}:#{learner_id}] Tutor introduced procedure"

      # Exchange 1, Turn 2: Learner must restate the procedure
      restate_prompt = Helpers.build_prompt(
        system: learner_prompt,
        context: "TUTOR SAID:\n#{opener}",
        instruction: "Restate the 4-step procedure the tutor just taught you, in your own words, in order. Number each step."
      )
      restatement = LLM.call(restate_prompt, model: learner_model, tracker: tracker, phase: "education_#{condition}")
      turns << { 'speaker' => learner_id, 'type' => 'procedure_restatement', 'content' => restatement }
      $stderr.puts "[#{condition}:#{learner_id}] Learner restated procedure"

      # Exchange 2, Turn 3: Tutor asks diagnostic question
      history     = Helpers.format_turns_for_prompt(turns)
      diag_prompt = Helpers.build_prompt(
        system: tutor_prompt,
        context: "DOMAIN LESSON:\n#{lesson}\n\n#{type_context}\n\nSESSION SO FAR:\n#{history}",
        instruction: "Ask ONE diagnostic question that will reveal whether the learner applies modifiers before checking activation. Under 60 words. Do not give the answer."
      )
      diag = LLM.call(diag_prompt, model: tutor_model, tracker: tracker, phase: "education_#{condition}")
      turns << { 'speaker' => tutor_id, 'type' => 'diagnostic_q', 'content' => diag }
      $stderr.puts "[#{condition}:#{learner_id}] Tutor asked diagnostic Q"

      # Exchange 2, Turn 4: Learner answers (should apply procedure)
      history      = Helpers.format_turns_for_prompt(turns)
      answer_prompt = Helpers.build_prompt(
        system: learner_prompt,
        context: "SESSION SO FAR:\n#{history}",
        instruction: "Answer the tutor's question. Use the 4-step procedure. Label each step you perform (e.g. 'Step 1: ...')."
      )
      answer = LLM.call(answer_prompt, model: learner_model, tracker: tracker, phase: "education_#{condition}")
      turns << { 'speaker' => learner_id, 'type' => 'diagnostic_answer', 'content' => answer }
      $stderr.puts "[#{condition}:#{learner_id}] Learner answered diagnostic"

      # Exchange 3, Turn 5: Tutor checks procedure adherence and corrects
      history      = Helpers.format_turns_for_prompt(turns)
      corr_prompt  = Helpers.build_prompt(
        system: tutor_prompt,
        context: "DOMAIN LESSON:\n#{lesson}\n\n#{type_context}\n\nSESSION SO FAR:\n#{history}",
        instruction: "Check whether the learner followed the 4-step procedure in order. If they applied modifiers (Step 2) before checking activation (Step 1), correct this explicitly. Restate: Step 1 ALWAYS precedes Step 2. Under 80 words."
      )
      correction = LLM.call(corr_prompt, model: tutor_model, tracker: tracker, phase: "education_#{condition}")
      turns << { 'speaker' => tutor_id, 'type' => 'procedure_correction', 'content' => correction }
      $stderr.puts "[#{condition}:#{learner_id}] Tutor gave procedure correction"

      # Exchange 3, Turn 6: Learner acknowledges
      history = Helpers.format_turns_for_prompt(turns)
      ack_prompt = Helpers.build_prompt(
        system: learner_prompt,
        context: "SESSION SO FAR:\n#{history}",
        instruction: "Acknowledge the correction. Restate the 4-step procedure in the correct order. 2-3 sentences."
      )
      acknowledgment = LLM.call(ack_prompt, model: learner_model, tracker: tracker, phase: "education_#{condition}")
      turns << { 'speaker' => learner_id, 'type' => 'correction_acknowledgment', 'content' => acknowledgment }
      $stderr.puts "[#{condition}:#{learner_id}] Learner acknowledged correction"

      # Exchange 4, Turn 7: Retest — require step labels
      history       = Helpers.format_turns_for_prompt(turns)
      retest_prompt = Helpers.build_prompt(
        system: tutor_prompt,
        context: "DOMAIN LESSON:\n#{lesson}\n\n#{type_context}\n\nSESSION SO FAR:\n#{history}",
        instruction: "Present a new token calculation problem to retest procedure adherence. Tell the learner to label each step (Step 1:, Step 2:, etc.) as they work. Under 80 words."
      )
      retest_q = LLM.call(retest_prompt, model: tutor_model, tracker: tracker, phase: "education_#{condition}")
      turns << { 'speaker' => tutor_id, 'type' => 'retest_q', 'content' => retest_q }
      $stderr.puts "[#{condition}:#{learner_id}] Tutor asked retest Q"

      # Exchange 4, Turn 8: Learner answers with step labels
      history        = Helpers.format_turns_for_prompt(turns)
      retest_a_prompt = Helpers.build_prompt(
        system: learner_prompt,
        context: "SESSION SO FAR:\n#{history}",
        instruction: "Solve the problem. Label each step (Step 1:, Step 2:, Step 3:, Step 4:). Show your reasoning at each step."
      )
      retest_a = LLM.call(retest_a_prompt, model: learner_model, tracker: tracker, phase: "education_#{condition}")
      turns << { 'speaker' => learner_id, 'type' => 'retest_answer', 'content' => retest_a }
      $stderr.puts "[#{condition}:#{learner_id}] Learner answered retest"

      {
        'condition'  => condition,
        'tutor_id'   => tutor_id,
        'learner_id' => learner_id,
        'turns'      => turns
      }
    end
  end
end
```

- [ ] **Step 4: Run tests to confirm passing**

```bash
eval "$(mise activate zsh)" && bundle exec ruby experiments/bloom_1n_vs_1on1/tests/test_tutoring_procedure_scaffolded.rb
```

Expected: `8 runs, 0 failures, 0 errors`

- [ ] **Step 5: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/lib/phases/tutoring_procedure_scaffolded.rb \
        experiments/bloom_1n_vs_1on1/tests/test_tutoring_procedure_scaffolded.rb
git commit -m "feat: TutoringProcedureScaffolded phase — explicit 4-step procedure with restatement and labelled retest"
```

---

## Task 4: Tutoring Phase — Add condition param

**Files:**
- Modify: `experiments/bloom_1n_vs_1on1/lib/phases/tutoring.rb`

v7 reuses the generic tutoring phase for both `one_on_one_tutoring` (Exp A) and `generic_one_on_one_tutoring` (Exp B), distinguished by the condition name passed in.

- [ ] **Step 1: Write failing test**

Add to `experiments/bloom_1n_vs_1on1/tests/test_tutoring_procedure_scaffolded.rb` (append after the existing class):

```ruby
class TestTutoringConditionParam < Minitest::Test
  def test_config
    { 'models' => { 'tutor' => 'model', 'learner' => 'model' } }
  end

  def test_default_condition_is_1on1
    result = LLM.stub(:call, 'stub') do
      Phases::Tutoring.run_session(
        tutor_id: 't1', learner_id: 'l1',
        tutor_prompt: 'sys', learner_prompt: 'sys',
        lesson: 'lesson', config: test_config
      )
    end
    assert_equal '1on1', result['condition']
  end

  def test_custom_condition_name_propagates
    result = LLM.stub(:call, 'stub') do
      Phases::Tutoring.run_session(
        tutor_id: 't1', learner_id: 'l1',
        tutor_prompt: 'sys', learner_prompt: 'sys',
        lesson: 'lesson', config: test_config,
        condition: 'generic_one_on_one_tutoring'
      )
    end
    assert_equal 'generic_one_on_one_tutoring', result['condition']
  end
end
```

Also add `require 'phases/tutoring'` at the top of the file.

- [ ] **Step 2: Run to confirm failure**

```bash
eval "$(mise activate zsh)" && bundle exec ruby experiments/bloom_1n_vs_1on1/tests/test_tutoring_procedure_scaffolded.rb
```

Expected: `ArgumentError: unknown keyword: condition` (or similar)

- [ ] **Step 3: Modify tutoring.rb**

In `experiments/bloom_1n_vs_1on1/lib/phases/tutoring.rb`, change the method signature and return hash:

```ruby
# Line 11 — change:
def self.run_session(tutor_id:, learner_id:, tutor_prompt:, learner_prompt:, lesson:,
                     config:, tracker: nil, learner_type_key: nil)

# to:
def self.run_session(tutor_id:, learner_id:, tutor_prompt:, learner_prompt:, lesson:,
                     config:, tracker: nil, learner_type_key: nil, condition: '1on1')
```

And change the return hash at the bottom (currently `'condition' => '1on1'`):

```ruby
# Line 107 — change:
{
  'condition'  => '1on1',
  'tutor_id'   => tutor_id,
  'learner_id' => learner_id,
  'turns'      => turns
}

# to:
{
  'condition'  => condition,
  'tutor_id'   => tutor_id,
  'learner_id' => learner_id,
  'turns'      => turns
}
```

- [ ] **Step 4: Run all tests**

```bash
eval "$(mise activate zsh)" && bash experiments/bloom_1n_vs_1on1/tests/run_tests.sh
```

Expected: all existing tests pass + new tests pass

- [ ] **Step 5: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/lib/phases/tutoring.rb \
        experiments/bloom_1n_vs_1on1/tests/test_tutoring_procedure_scaffolded.rb
git commit -m "feat: tutoring phase — add optional condition param (default '1on1')"
```

---

## Task 5: Report v7 — Dynamic Conditions and New Sections

**Files:**
- Create: `experiments/bloom_1n_vs_1on1/tests/test_report_v7.rb`
- Modify: `experiments/bloom_1n_vs_1on1/lib/report.rb`

Three additions to `report.rb`:
1. Dynamic condition detection in `Score by Condition` (replaces hardcoded list)
2. `experiment_meta:` param to `generate` and `build_markdown` — selects which v7 sections to render
3. Three new methods: `passive_listener_rescue_effect`, `order_confused_scaffold_effect`, `procedure_order_error_rate`

- [ ] **Step 1: Write failing tests**

Create `experiments/bloom_1n_vs_1on1/tests/test_report_v7.rb`:

```ruby
# ABOUTME: Tests for v7 report additions — dynamic conditions, passive_listener rescue, order_confused scaffold
# ABOUTME: Pure function tests; no DB or LLM calls

$LOAD_PATH.unshift File.join(__dir__, '..', 'lib')
require 'minitest/autorun'
require 'json'
require 'securerandom'
require 'report'

class TestProcedureOrderErrorRate < Minitest::Test
  def make_row(response_text, condition: '1on1', answer_correct: false)
    {
      'condition'     => condition,
      'learner_id'    => SecureRandom.uuid,
      'task_id'       => 'l3_rule_interaction_01',
      'task_type'     => 'rule_interaction',
      'response_text' => response_text,
      'score_json'    => JSON.dump({ 'answer_correct' => answer_correct, 'total' => 0 }),
      'profile_json'  => JSON.dump({ 'type_key' => 'order_confused' })
    }
  end

  def test_detects_modifier_before_activation
    # Typical order_confused error: multiplies before checking active
    row = make_row("First I multiply: 3 × 2 = 6, then check if blue token is active")
    assert Report.procedure_order_error?(row['response_text']),
           "Should detect modifier applied before activation check"
  end

  def test_no_error_when_activation_checked_first
    row = make_row("Step 1: check activation — blue token is active. Step 2: apply modifier 3 × 2 = 6")
    refute Report.procedure_order_error?(row['response_text']),
           "Should not flag when activation checked before modifier"
  end

  def test_rate_is_zero_for_empty_rows
    assert_equal 0.0, Report.procedure_order_error_rate([])
  end

  def test_rate_calculation
    rows = [
      make_row("multiply first: 3 × 2, then check active"),
      make_row("check active first, then multiply"),
      make_row("Step 1: active check. Step 2: × modifier")
    ]
    rate = Report.procedure_order_error_rate(rows)
    assert_in_delta (1.0 / 3.0), rate, 0.01
  end
end

class TestPassiveListenerRescueEffect < Minitest::Test
  def make_row(condition, answer_correct, type_key: 'passive_listener')
    {
      'condition'     => condition,
      'learner_id'    => SecureRandom.uuid,
      'task_id'       => 'l1_recall_01',
      'task_type'     => 'recall',
      'response_text' => 'answer',
      'score_json'    => JSON.dump({ 'answer_correct' => answer_correct, 'total' => answer_correct ? 12 : 0 }),
      'profile_json'  => JSON.dump({ 'type_key' => type_key })
    }
  end

  def test_returns_table_with_three_conditions
    rows = [
      make_row('classroom_public_qa', false),
      make_row('classroom_forced_checkin', true),
      make_row('one_on_one_tutoring', true),
    ]
    table = Report.passive_listener_rescue_effect(rows)
    assert_includes table, 'classroom_public_qa'
    assert_includes table, 'classroom_forced_checkin'
    assert_includes table, 'one_on_one_tutoring'
  end

  def test_shows_correct_percentages
    rows = [
      make_row('classroom_public_qa', false),
      make_row('classroom_public_qa', false),
      make_row('classroom_forced_checkin', true),
      make_row('classroom_forced_checkin', false),
      make_row('one_on_one_tutoring', true),
    ]
    table = Report.passive_listener_rescue_effect(rows)
    assert_includes table, '0%'   # classroom_public_qa: 0/2
    assert_includes table, '50%'  # classroom_forced_checkin: 1/2
    assert_includes table, '100%' # one_on_one_tutoring: 1/1
  end

  def test_returns_empty_string_when_no_passive_listener_data
    rows = []
    assert_equal '', Report.passive_listener_rescue_effect(rows)
  end
end

class TestOrderConfusedScaffoldEffect < Minitest::Test
  def make_row(condition, answer_correct, response_text: 'no multiplier', type_key: 'order_confused')
    {
      'condition'     => condition,
      'learner_id'    => SecureRandom.uuid,
      'task_id'       => 'l3_rule_interaction_01',
      'task_type'     => 'rule_interaction',
      'response_text' => response_text,
      'score_json'    => JSON.dump({ 'answer_correct' => answer_correct, 'total' => answer_correct ? 12 : 0 }),
      'profile_json'  => JSON.dump({ 'type_key' => type_key })
    }
  end

  def test_returns_table_with_three_conditions
    rows = [
      make_row('classroom_public_qa', true),
      make_row('generic_one_on_one_tutoring', false),
      make_row('procedure_scaffolded_one_on_one_tutoring', true),
    ]
    table = Report.order_confused_scaffold_effect(rows)
    assert_includes table, 'classroom_public_qa'
    assert_includes table, 'generic_one_on_one_tutoring'
    assert_includes table, 'procedure_scaffolded_one_on_one_tutoring'
  end

  def test_returns_empty_string_when_no_order_confused_data
    assert_equal '', Report.order_confused_scaffold_effect([])
  end
end

class TestDynamicConditionList < Minitest::Test
  def make_row(condition, answer_correct)
    {
      'condition'     => condition,
      'learner_id'    => SecureRandom.uuid,
      'task_id'       => 'l1_recall_01',
      'task_type'     => 'recall',
      'response_text' => 'answer',
      'score_json'    => JSON.dump({ 'answer_correct' => answer_correct }),
      'profile_json'  => nil
    }
  end

  def test_build_markdown_includes_v7_condition_names
    rows = [
      make_row('classroom_public_qa', true),
      make_row('classroom_forced_checkin', false),
      make_row('one_on_one_tutoring', true),
    ]
    config = { 'experiment' => { 'domain' => 'test', 'ceiling_threshold' => 0.9 },
               'models' => { 'teacher' => 'haiku' } }
    md = Report.build_markdown(rows, run_id: 'r1', output_dir: '/tmp', run_config: config,
                               token_summary: {}, experiment_meta: { experiment: 'A' })
    assert_includes md, 'classroom_public_qa'
    assert_includes md, 'classroom_forced_checkin'
    assert_includes md, 'one_on_one_tutoring'
  end

  def test_build_markdown_renders_passive_listener_rescue_for_exp_a
    rows = [
      make_row('classroom_public_qa', false),
      make_row('classroom_forced_checkin', true),
      make_row('one_on_one_tutoring', true),
    ]
    # Give them passive_listener type_key
    rows.each { |r| r['profile_json'] = JSON.dump({ 'type_key' => 'passive_listener' }) }
    config = { 'experiment' => { 'domain' => 'test', 'ceiling_threshold' => 0.9 },
               'models' => { 'teacher' => 'haiku' } }
    md = Report.build_markdown(rows, run_id: 'r1', output_dir: '/tmp', run_config: config,
                               token_summary: {}, experiment_meta: { experiment: 'A' })
    assert_includes md, 'Passive Listener Rescue Effect'
  end

  def test_build_markdown_renders_order_confused_scaffold_for_exp_b
    rows = [
      make_row('classroom_public_qa', true),
      make_row('generic_one_on_one_tutoring', false),
      make_row('procedure_scaffolded_one_on_one_tutoring', true),
    ]
    rows.each { |r| r['profile_json'] = JSON.dump({ 'type_key' => 'order_confused' }) }
    config = { 'experiment' => { 'domain' => 'test', 'ceiling_threshold' => 0.9 },
               'models' => { 'teacher' => 'haiku' } }
    md = Report.build_markdown(rows, run_id: 'r1', output_dir: '/tmp', run_config: config,
                               token_summary: {}, experiment_meta: { experiment: 'B' })
    assert_includes md, 'Order Confused Scaffold Effect'
  end
end
```

- [ ] **Step 2: Run to confirm failure**

```bash
eval "$(mise activate zsh)" && bundle exec ruby experiments/bloom_1n_vs_1on1/tests/test_report_v7.rb
```

Expected: `NoMethodError: undefined method 'procedure_order_error?'` (or similar)

- [ ] **Step 3: Modify report.rb**

Make the following changes to `experiments/bloom_1n_vs_1on1/lib/report.rb`:

**3a. Add `experiment_meta:` param to `generate` (line 15):**

```ruby
# Change:
def self.generate(db, run_id:, output_dir:, run_config:, token_summary: {})

# To:
def self.generate(db, run_id:, output_dir:, run_config:, token_summary: {}, experiment_meta: {})
```

**3b. Pass `experiment_meta` through (line 20-22):**

```ruby
# Change:
markdown = build_markdown(rows, run_id: run_id, output_dir: output_dir,
                          run_config: run_config, token_summary: token_summary,
                          memories_by_condition: memories_by_condition)

# To:
markdown = build_markdown(rows, run_id: run_id, output_dir: output_dir,
                          run_config: run_config, token_summary: token_summary,
                          memories_by_condition: memories_by_condition,
                          experiment_meta: experiment_meta)
```

**3c. Add `experiment_meta:` param to `build_markdown` (line 44):**

```ruby
# Change:
def self.build_markdown(rows, run_id:, output_dir:, run_config:, token_summary:, memories_by_condition: {})

# To:
def self.build_markdown(rows, run_id:, output_dir:, run_config:, token_summary:, memories_by_condition: {}, experiment_meta: {})
```

**3d. Replace hardcoded condition list in Score by Condition section (lines 85-91):**

```ruby
# Change:
%w[no_education homogeneous_classroom heterogeneous_classroom 1on1].each do |cond|
  cond_rows = by_condition[cond] || []
  pct = avg_correctness(cond_rows)
  n   = cond_rows.map { |r| r['learner_id'] }.uniq.size
  lines << "| #{cond} | #{n} | #{cond_rows.size} | #{(pct * 100).round}% |"
end

# To:
by_condition.keys.sort.each do |cond|
  cond_rows = by_condition[cond]
  pct = avg_correctness(cond_rows)
  n   = cond_rows.map { |r| r['learner_id'] }.uniq.size
  lines << "| #{cond} | #{n} | #{cond_rows.size} | #{(pct * 100).round}% |"
end
```

**3e. Add v7-specific sections just before the "Recommended Next Steps" section (before line 228):**

```ruby
# After the Confidence Calibration section, add:

# Exp A: passive_listener rescue effect
if experiment_meta[:experiment] == 'A'
  rescue_table = passive_listener_rescue_effect(rows)
  unless rescue_table.empty?
    lines << "## Passive Listener Rescue Effect"
    lines << ""
    lines << rescue_table
    lines << ""
  end
end

# Exp B: order_confused scaffold effect + procedure order errors
if experiment_meta[:experiment] == 'B'
  scaffold_table = order_confused_scaffold_effect(rows)
  unless scaffold_table.empty?
    lines << "## Order Confused Scaffold Effect"
    lines << ""
    lines << scaffold_table
    lines << ""
  end

  proc_error_rate = procedure_order_error_rate(rows)
  lines << "## Procedure Order Errors"
  lines << ""
  lines << "| Metric | Rate |"
  lines << "|--------|------|"
  lines << "| Responses with modifier-before-activation error | #{(proc_error_rate * 100).round}% |"
  lines << ""
end
```

**3f. Add three new methods at the end of the `Report` module (before final `end`):**

```ruby
def self.passive_listener_rescue_effect(rows)
  pl_rows = rows.select do |r|
    profile = r['profile_json'] ? JSON.parse(r['profile_json']) : {}
    profile['type_key'] == 'passive_listener'
  end
  return '' if pl_rows.empty?

  by_cond = pl_rows.group_by { |r| r['condition'] }
  target_conds = %w[classroom_public_qa classroom_forced_checkin one_on_one_tutoring]

  table = []
  table << "| Condition | Learners | Correct% |"
  table << "|-----------|---------|---------|"
  target_conds.each do |cond|
    cond_rows = by_cond[cond] || []
    next if cond_rows.empty?
    n   = cond_rows.map { |r| r['learner_id'] }.uniq.size
    pct = avg_correctness(cond_rows)
    table << "| #{cond} | #{n} | #{(pct * 100).round}% |"
  end

  table.join("\n")
end

def self.order_confused_scaffold_effect(rows)
  oc_rows = rows.select do |r|
    profile = r['profile_json'] ? JSON.parse(r['profile_json']) : {}
    profile['type_key'] == 'order_confused'
  end
  return '' if oc_rows.empty?

  by_cond = oc_rows.group_by { |r| r['condition'] }
  target_conds = %w[classroom_public_qa generic_one_on_one_tutoring procedure_scaffolded_one_on_one_tutoring]

  table = []
  table << "| Condition | Learners | Correct% | Procedure Order Errors% |"
  table << "|-----------|---------|---------|------------------------|"
  target_conds.each do |cond|
    cond_rows = by_cond[cond] || []
    next if cond_rows.empty?
    n         = cond_rows.map { |r| r['learner_id'] }.uniq.size
    pct       = avg_correctness(cond_rows)
    err_rate  = procedure_order_error_rate(cond_rows)
    table << "| #{cond} | #{n} | #{(pct * 100).round}% | #{(err_rate * 100).round}% |"
  end

  table.join("\n")
end

def self.procedure_order_error?(response_text)
  text = response_text.to_s.downcase
  mod_pos = [text.index('×'), text.index('modifier'), text.index('multiply')].compact.min
  act_pos = [text.index('active'), text.index('inactive'), text.index('activation')].compact.min
  return false unless mod_pos && act_pos
  mod_pos < act_pos
end

def self.procedure_order_error_rate(rows)
  return 0.0 if rows.empty?
  errors = rows.count { |r| procedure_order_error?(r['response_text'].to_s) }
  errors.to_f / rows.size
end
```

- [ ] **Step 4: Run all tests**

```bash
eval "$(mise activate zsh)" && bundle exec ruby experiments/bloom_1n_vs_1on1/tests/test_report_v7.rb
```

Expected: `14 runs, 0 failures, 0 errors`

- [ ] **Step 5: Run full test suite to confirm no regressions**

```bash
eval "$(mise activate zsh)" && bash experiments/bloom_1n_vs_1on1/tests/run_tests.sh
```

Expected: all tests pass including pre-existing ones.

- [ ] **Step 6: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/lib/report.rb \
        experiments/bloom_1n_vs_1on1/tests/test_report_v7.rb
git commit -m "feat: report v7 — dynamic conditions, passive_listener rescue, order_confused scaffold sections"
```

---

## Task 6: Config Files

**Files:**
- Create: `experiments/bloom_1n_vs_1on1/config_v7a.yml`
- Create: `experiments/bloom_1n_vs_1on1/config_v7b.yml`
- Create: `experiments/bloom_1n_vs_1on1/config_v7a_smoke.yml`
- Create: `experiments/bloom_1n_vs_1on1/config_v7b_smoke.yml`

No tests; verified by smoke runs in Task 9.

- [ ] **Step 1: Create config_v7a.yml** (Exp A: passive_listener rescue, n=4)

```yaml
experiment:
  name: "bloom_v7a_passive_listener_rescue"
  domain: "zarn_tokens"
  n_classroom_public_qa: 4
  n_classroom_forced_checkin: 4
  n_one_on_one_tutoring: 4
  tutoring_turns: 4
  eval_tasks_file: "eval_tasks_v4.json"
  max_memory_words: 80
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
  db: "experiments/bloom_1n_vs_1on1/data/experiment_v7a.db"
```

- [ ] **Step 2: Create config_v7b.yml** (Exp B: order_confused intervention, n=4)

```yaml
experiment:
  name: "bloom_v7b_order_confused_intervention"
  domain: "zarn_tokens"
  n_classroom_public_qa: 4
  n_generic_one_on_one_tutoring: 4
  n_procedure_scaffolded_one_on_one_tutoring: 4
  tutoring_turns: 4
  eval_tasks_file: "eval_tasks_v4.json"
  max_memory_words: 100
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
  db: "experiments/bloom_1n_vs_1on1/data/experiment_v7b.db"
```

- [ ] **Step 3: Create config_v7a_smoke.yml** (n=1, haiku)

```yaml
experiment:
  name: "bloom_v7a_smoke"
  domain: "zarn_tokens"
  n_classroom_public_qa: 1
  n_classroom_forced_checkin: 1
  n_one_on_one_tutoring: 1
  tutoring_turns: 4
  eval_tasks_file: "eval_tasks_v4.json"
  max_memory_words: 80
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
  db: "experiments/bloom_1n_vs_1on1/data/smoke_v7a.db"
```

- [ ] **Step 4: Create config_v7b_smoke.yml** (n=1, haiku)

```yaml
experiment:
  name: "bloom_v7b_smoke"
  domain: "zarn_tokens"
  n_classroom_public_qa: 1
  n_generic_one_on_one_tutoring: 1
  n_procedure_scaffolded_one_on_one_tutoring: 1
  tutoring_turns: 4
  eval_tasks_file: "eval_tasks_v4.json"
  max_memory_words: 100
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
  db: "experiments/bloom_1n_vs_1on1/data/smoke_v7b.db"
```

- [ ] **Step 5: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/config_v7a.yml \
        experiments/bloom_1n_vs_1on1/config_v7b.yml \
        experiments/bloom_1n_vs_1on1/config_v7a_smoke.yml \
        experiments/bloom_1n_vs_1on1/config_v7b_smoke.yml
git commit -m "feat: v7 config files — Exp A passive_listener rescue, Exp B order_confused intervention"
```

---

## Task 7: Orchestrator A — Experiment A (passive_listener rescue)

**Files:**
- Create: `experiments/bloom_1n_vs_1on1/scripts/run_experiment_a.rb`

Three conditions: classroom_public_qa (generic classroom), classroom_forced_checkin, one_on_one_tutoring. All learners are passive_listener type.

- [ ] **Step 1: Create run_experiment_a.rb**

Create `experiments/bloom_1n_vs_1on1/scripts/run_experiment_a.rb`:

```ruby
# ABOUTME: Orchestrator for v7 Experiment A — passive_listener rescue mechanism test
# ABOUTME: 3 conditions: classroom_public_qa, classroom_forced_checkin, one_on_one_tutoring

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
require 'phases/classroom_forced_checkin'
require 'phases/tutoring'
require 'phases/memory'
require 'phases/solver'
require 'phases/evaluator'
require 'report'

config_path  = ARGV[0] or abort "Usage: #{$0} <config.yml>"
PROJECT_ROOT = File.expand_path('../..', EXPERIMENT_DIR)
config       = YAML.load_file(File.join(PROJECT_ROOT, config_path))

run_id       = SecureRandom.uuid
run_name     = config.dig('experiment', 'name') || 'bloom_v7a'
domain_path  = File.join(PROJECT_ROOT, config.dig('paths', 'domain'))
prompts_path = File.join(PROJECT_ROOT, config.dig('paths', 'prompts'))
output_base  = File.join(PROJECT_ROOT, config.dig('paths', 'output'))
db_path      = File.join(PROJECT_ROOT, config.dig('paths', 'db'))
run_dir      = File.join(output_base, 'runs', run_id)

FileUtils.mkdir_p(run_dir)
$stderr.puts "[exp_a] Starting run #{run_id}"

tracker = TokenTracker.new

lesson     = Helpers.load_file(File.join(domain_path, 'lesson.md'))
tasks_file = config.dig('experiment', 'eval_tasks_file') || 'eval_tasks_v4.json'
eval_tasks = JSON.parse(Helpers.load_file(File.join(domain_path, tasks_file)))
rubric     = JSON.parse(Helpers.load_file(File.join(domain_path, 'rubric.json')))

teacher_prompt    = Helpers.load_file(File.join(prompts_path, 'classroom_teacher.md'))
checkin_prompt    = Helpers.load_file(File.join(prompts_path, 'classroom_forced_checkin_teacher.md'))
tutor_prompt      = Helpers.load_file(File.join(prompts_path, 'one_on_one_tutor.md'))
learner_prompt    = Helpers.load_file(File.join(prompts_path, 'learner.md'))
summarizer_prompt = Helpers.load_file(File.join(prompts_path, 'memory_summarizer.md'))
solver_prompt     = Helpers.load_file(File.join(prompts_path, 'problem_solver.md'))
evaluator_prompt  = Helpers.load_file(File.join(prompts_path, 'blind_evaluator.md'))

db = DB.setup(db_path)
DB.save_run(db, run_id, run_name, config)
File.write(File.join(run_dir, 'config.json'), JSON.pretty_generate(config))

n_public_qa  = config.dig('experiment', 'n_classroom_public_qa')          || 4
n_forced     = config.dig('experiment', 'n_classroom_forced_checkin')      || 4
n_tutoring   = config.dig('experiment', 'n_one_on_one_tutoring')           || 4

# All learners in Exp A are passive_listener
type_key = :passive_listener

teacher_id   = DB.save_agent(db, run_id: run_id, role: 'classroom_teacher',
                              model: config.dig('models', 'teacher'))
tutor_id     = DB.save_agent(db, run_id: run_id, role: 'tutor',
                              model: config.dig('models', 'tutor'))
evaluator_id = DB.save_agent(db, run_id: run_id, role: 'evaluator',
                              model: config.dig('models', 'evaluator'))

public_qa_ids = n_public_qa.times.map do
  DB.save_agent(db, run_id: run_id, role: 'learner', condition: 'classroom_public_qa',
                model: config.dig('models', 'learner'), profile: { 'type_key' => type_key.to_s })
end

forced_ids = n_forced.times.map do
  DB.save_agent(db, run_id: run_id, role: 'learner', condition: 'classroom_forced_checkin',
                model: config.dig('models', 'learner'), profile: { 'type_key' => type_key.to_s })
end

tutoring_ids = n_tutoring.times.map do
  DB.save_agent(db, run_id: run_id, role: 'learner', condition: 'one_on_one_tutoring',
                model: config.dig('models', 'learner'), profile: { 'type_key' => type_key.to_s })
end

all_learners =
  public_qa_ids.map  { |id| { id: id, condition: 'classroom_public_qa' } } +
  forced_ids.map     { |id| { id: id, condition: 'classroom_forced_checkin' } } +
  tutoring_ids.map   { |id| { id: id, condition: 'one_on_one_tutoring' } }

# Build class context for passive_listener
class_context = <<~CTX
  CLASS COMPOSITION: All learners are passive_listener type.
  - Tendency: listen without engaging; retain partial information only
  - Common misconception: forgets_edge_cases
  Teach clearly; do not rely on learner questions to gauge understanding.
CTX

# === PHASE 1a: Classroom Public QA ===
$stderr.puts "[exp_a] Phase 1a: classroom_public_qa (#{n_public_qa} passive_listener learners)"
type_map_qa = public_qa_ids.each_with_object({}) { |id, h| h[id] = type_key }
qa_transcript = Phases::Classroom.run(
  teacher_id: teacher_id, learner_ids: public_qa_ids,
  teacher_prompt: teacher_prompt, learner_prompt: learner_prompt,
  lesson: lesson, config: config, tracker: tracker,
  class_context: class_context, condition: 'classroom_public_qa',
  learner_type_keys: type_map_qa
)
public_qa_ids.each do |lid|
  DB.save_learning_session(db, run_id: run_id, condition: 'classroom_public_qa',
                           learner_id: lid, teacher_or_tutor_id: teacher_id, transcript: qa_transcript)
end
File.open(File.join(run_dir, 'transcripts.jsonl'), 'a') { |f| f.puts JSON.dump(qa_transcript) }

# === PHASE 1b: Classroom Forced Check-in ===
$stderr.puts "[exp_a] Phase 1b: classroom_forced_checkin (#{n_forced} passive_listener learners)"
checkin_transcript = Phases::ClassroomForcedCheckin.run(
  teacher_id: teacher_id, learner_ids: forced_ids,
  teacher_prompt: checkin_prompt, learner_prompt: learner_prompt,
  lesson: lesson, config: config, tracker: tracker,
  class_context: class_context
)
forced_ids.each do |lid|
  DB.save_learning_session(db, run_id: run_id, condition: 'classroom_forced_checkin',
                           learner_id: lid, teacher_or_tutor_id: teacher_id, transcript: checkin_transcript)
end
File.open(File.join(run_dir, 'transcripts.jsonl'), 'a') { |f| f.puts JSON.dump(checkin_transcript) }

# === PHASE 2: 1on1 Tutoring ===
$stderr.puts "[exp_a] Phase 2: one_on_one_tutoring (#{n_tutoring} passive_listener learners)"
tutoring_ids.each do |lid|
  transcript = Phases::Tutoring.run_session(
    tutor_id: tutor_id, learner_id: lid,
    tutor_prompt: tutor_prompt, learner_prompt: learner_prompt,
    lesson: lesson, config: config, tracker: tracker,
    learner_type_key: type_key, condition: 'one_on_one_tutoring'
  )
  DB.save_learning_session(db, run_id: run_id, condition: 'one_on_one_tutoring',
                           learner_id: lid, teacher_or_tutor_id: tutor_id, transcript: transcript)
  File.open(File.join(run_dir, 'transcripts.jsonl'), 'a') { |f| f.puts JSON.dump(transcript) }
end

# === PHASE 3: Memory Generation ===
educated_learners = all_learners
$stderr.puts "[exp_a] Phase 3: Memory generation (#{educated_learners.size} learners)"
educated_learners.each do |learner|
  transcript_row = db.execute(
    'SELECT transcript_json FROM learning_sessions WHERE run_id = ? AND learner_id = ? ORDER BY rowid DESC LIMIT 1',
    [run_id, learner[:id]]
  ).first
  transcript = JSON.parse(transcript_row['transcript_json'])
  memory = Phases::Memory.generate(
    learner_id: learner[:id], transcript: transcript,
    summarizer_prompt: summarizer_prompt, config: config, tracker: tracker,
    learner_type_key: type_key
  )
  DB.save_learner_memory(db, run_id: run_id, learner_id: learner[:id],
                         condition: learner[:condition], memory: memory)
  File.open(File.join(run_dir, 'memories.jsonl'), 'a') do |f|
    f.puts JSON.dump({ learner_id: learner[:id], condition: learner[:condition],
                       type_key: type_key, memory: memory })
  end
end

# === PHASE 4+5: Problem Solving + Scoring ===
$stderr.puts "[exp_a] Phase 4+5: Solving + scoring (#{all_learners.size} × #{eval_tasks.size} tasks)"
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
$stderr.puts "[exp_a] Phase 6: Generating report"
Report.generate(db, run_id: run_id, output_dir: run_dir,
                run_config: config, token_summary: tracker.summary,
                experiment_meta: { experiment: 'A' })

db.close
$stderr.puts "[exp_a] Done. Results in: #{run_dir}"
puts run_dir
```

- [ ] **Step 2: Smoke-verify syntax**

```bash
eval "$(mise activate zsh)" && ruby -c experiments/bloom_1n_vs_1on1/scripts/run_experiment_a.rb
```

Expected: `Syntax OK`

- [ ] **Step 3: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/scripts/run_experiment_a.rb
git commit -m "feat: run_experiment_a — Exp A passive_listener rescue orchestrator"
```

---

## Task 8: Orchestrator B — Experiment B (order_confused intervention)

**Files:**
- Create: `experiments/bloom_1n_vs_1on1/scripts/run_experiment_b.rb`

Three conditions: classroom_public_qa, generic_one_on_one_tutoring, procedure_scaffolded_one_on_one_tutoring. All learners are order_confused type.

- [ ] **Step 1: Create run_experiment_b.rb**

Create `experiments/bloom_1n_vs_1on1/scripts/run_experiment_b.rb`:

```ruby
# ABOUTME: Orchestrator for v7 Experiment B — order_confused intervention mechanism test
# ABOUTME: 3 conditions: classroom_public_qa, generic_one_on_one_tutoring, procedure_scaffolded_one_on_one_tutoring

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
require 'phases/tutoring_procedure_scaffolded'
require 'phases/memory'
require 'phases/solver'
require 'phases/evaluator'
require 'report'

config_path  = ARGV[0] or abort "Usage: #{$0} <config.yml>"
PROJECT_ROOT = File.expand_path('../..', EXPERIMENT_DIR)
config       = YAML.load_file(File.join(PROJECT_ROOT, config_path))

run_id       = SecureRandom.uuid
run_name     = config.dig('experiment', 'name') || 'bloom_v7b'
domain_path  = File.join(PROJECT_ROOT, config.dig('paths', 'domain'))
prompts_path = File.join(PROJECT_ROOT, config.dig('paths', 'prompts'))
output_base  = File.join(PROJECT_ROOT, config.dig('paths', 'output'))
db_path      = File.join(PROJECT_ROOT, config.dig('paths', 'db'))
run_dir      = File.join(output_base, 'runs', run_id)

FileUtils.mkdir_p(run_dir)
$stderr.puts "[exp_b] Starting run #{run_id}"

tracker = TokenTracker.new

lesson     = Helpers.load_file(File.join(domain_path, 'lesson.md'))
tasks_file = config.dig('experiment', 'eval_tasks_file') || 'eval_tasks_v4.json'
eval_tasks = JSON.parse(Helpers.load_file(File.join(domain_path, tasks_file)))
rubric     = JSON.parse(Helpers.load_file(File.join(domain_path, 'rubric.json')))

teacher_prompt      = Helpers.load_file(File.join(prompts_path, 'classroom_teacher.md'))
tutor_prompt        = Helpers.load_file(File.join(prompts_path, 'one_on_one_tutor.md'))
scaffold_prompt     = Helpers.load_file(File.join(prompts_path, 'tutor_procedure_scaffolded.md'))
learner_prompt      = Helpers.load_file(File.join(prompts_path, 'learner.md'))
summarizer_prompt   = Helpers.load_file(File.join(prompts_path, 'memory_summarizer.md'))
solver_prompt       = Helpers.load_file(File.join(prompts_path, 'problem_solver.md'))
evaluator_prompt    = Helpers.load_file(File.join(prompts_path, 'blind_evaluator.md'))

db = DB.setup(db_path)
DB.save_run(db, run_id, run_name, config)
File.write(File.join(run_dir, 'config.json'), JSON.pretty_generate(config))

n_public_qa  = config.dig('experiment', 'n_classroom_public_qa')                        || 4
n_generic    = config.dig('experiment', 'n_generic_one_on_one_tutoring')                || 4
n_scaffolded = config.dig('experiment', 'n_procedure_scaffolded_one_on_one_tutoring')   || 4

# All learners in Exp B are order_confused
type_key = :order_confused

teacher_id   = DB.save_agent(db, run_id: run_id, role: 'classroom_teacher',
                              model: config.dig('models', 'teacher'))
tutor_id     = DB.save_agent(db, run_id: run_id, role: 'tutor',
                              model: config.dig('models', 'tutor'))
evaluator_id = DB.save_agent(db, run_id: run_id, role: 'evaluator',
                              model: config.dig('models', 'evaluator'))

public_qa_ids = n_public_qa.times.map do
  DB.save_agent(db, run_id: run_id, role: 'learner', condition: 'classroom_public_qa',
                model: config.dig('models', 'learner'), profile: { 'type_key' => type_key.to_s })
end

generic_ids = n_generic.times.map do
  DB.save_agent(db, run_id: run_id, role: 'learner', condition: 'generic_one_on_one_tutoring',
                model: config.dig('models', 'learner'), profile: { 'type_key' => type_key.to_s })
end

scaffolded_ids = n_scaffolded.times.map do
  DB.save_agent(db, run_id: run_id, role: 'learner', condition: 'procedure_scaffolded_one_on_one_tutoring',
                model: config.dig('models', 'learner'), profile: { 'type_key' => type_key.to_s })
end

all_learners =
  public_qa_ids.map   { |id| { id: id, condition: 'classroom_public_qa' } } +
  generic_ids.map     { |id| { id: id, condition: 'generic_one_on_one_tutoring' } } +
  scaffolded_ids.map  { |id| { id: id, condition: 'procedure_scaffolded_one_on_one_tutoring' } }

# Class context for order_confused
class_context = <<~CTX
  CLASS COMPOSITION: All learners are order_confused type.
  - Tendency: apply rules in wrong sequence; often reverses modifier/activation order
  - Common misconception: applies_modifiers_before_activation
  Emphasize the CORRECT ORDER: check activation status FIRST, then apply modifiers.
CTX

type_map_qa = public_qa_ids.each_with_object({}) { |id, h| h[id] = type_key }

# === PHASE 1a: Classroom Public QA ===
$stderr.puts "[exp_b] Phase 1a: classroom_public_qa (#{n_public_qa} order_confused learners)"
qa_transcript = Phases::Classroom.run(
  teacher_id: teacher_id, learner_ids: public_qa_ids,
  teacher_prompt: teacher_prompt, learner_prompt: learner_prompt,
  lesson: lesson, config: config, tracker: tracker,
  class_context: class_context, condition: 'classroom_public_qa',
  learner_type_keys: type_map_qa
)
public_qa_ids.each do |lid|
  DB.save_learning_session(db, run_id: run_id, condition: 'classroom_public_qa',
                           learner_id: lid, teacher_or_tutor_id: teacher_id, transcript: qa_transcript)
end
File.open(File.join(run_dir, 'transcripts.jsonl'), 'a') { |f| f.puts JSON.dump(qa_transcript) }

# === PHASE 2a: Generic 1on1 Tutoring ===
$stderr.puts "[exp_b] Phase 2a: generic_one_on_one_tutoring (#{n_generic} order_confused learners)"
generic_ids.each do |lid|
  transcript = Phases::Tutoring.run_session(
    tutor_id: tutor_id, learner_id: lid,
    tutor_prompt: tutor_prompt, learner_prompt: learner_prompt,
    lesson: lesson, config: config, tracker: tracker,
    learner_type_key: type_key, condition: 'generic_one_on_one_tutoring'
  )
  DB.save_learning_session(db, run_id: run_id, condition: 'generic_one_on_one_tutoring',
                           learner_id: lid, teacher_or_tutor_id: tutor_id, transcript: transcript)
  File.open(File.join(run_dir, 'transcripts.jsonl'), 'a') { |f| f.puts JSON.dump(transcript) }
end

# === PHASE 2b: Procedure-Scaffolded 1on1 Tutoring ===
$stderr.puts "[exp_b] Phase 2b: procedure_scaffolded_one_on_one_tutoring (#{n_scaffolded} order_confused learners)"
scaffolded_ids.each do |lid|
  transcript = Phases::TutoringProcedureScaffolded.run_session(
    tutor_id: tutor_id, learner_id: lid,
    tutor_prompt: scaffold_prompt, learner_prompt: learner_prompt,
    lesson: lesson, config: config, tracker: tracker
  )
  DB.save_learning_session(db, run_id: run_id, condition: 'procedure_scaffolded_one_on_one_tutoring',
                           learner_id: lid, teacher_or_tutor_id: tutor_id, transcript: transcript)
  File.open(File.join(run_dir, 'transcripts.jsonl'), 'a') { |f| f.puts JSON.dump(transcript) }
end

# === PHASE 3: Memory Generation ===
$stderr.puts "[exp_b] Phase 3: Memory generation (#{all_learners.size} learners)"
all_learners.each do |learner|
  transcript_row = db.execute(
    'SELECT transcript_json FROM learning_sessions WHERE run_id = ? AND learner_id = ? ORDER BY rowid DESC LIMIT 1',
    [run_id, learner[:id]]
  ).first
  transcript = JSON.parse(transcript_row['transcript_json'])
  memory = Phases::Memory.generate(
    learner_id: learner[:id], transcript: transcript,
    summarizer_prompt: summarizer_prompt, config: config, tracker: tracker,
    learner_type_key: type_key
  )
  DB.save_learner_memory(db, run_id: run_id, learner_id: learner[:id],
                         condition: learner[:condition], memory: memory)
  File.open(File.join(run_dir, 'memories.jsonl'), 'a') do |f|
    f.puts JSON.dump({ learner_id: learner[:id], condition: learner[:condition],
                       type_key: type_key, memory: memory })
  end
end

# === PHASE 4+5: Problem Solving + Scoring ===
$stderr.puts "[exp_b] Phase 4+5: Solving + scoring (#{all_learners.size} × #{eval_tasks.size} tasks)"
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
$stderr.puts "[exp_b] Phase 6: Generating report"
Report.generate(db, run_id: run_id, output_dir: run_dir,
                run_config: config, token_summary: tracker.summary,
                experiment_meta: { experiment: 'B' })

db.close
$stderr.puts "[exp_b] Done. Results in: #{run_dir}"
puts run_dir
```

- [ ] **Step 2: Smoke-verify syntax**

```bash
eval "$(mise activate zsh)" && ruby -c experiments/bloom_1n_vs_1on1/scripts/run_experiment_b.rb
```

Expected: `Syntax OK`

- [ ] **Step 3: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/scripts/run_experiment_b.rb
git commit -m "feat: run_experiment_b — Exp B order_confused intervention orchestrator"
```

---

## Task 9: Wire Tests and Smoke Runs

**Files:**
- Modify: `experiments/bloom_1n_vs_1on1/tests/run_tests.sh`

- [ ] **Step 1: Add new test files to run_tests.sh**

In `experiments/bloom_1n_vs_1on1/tests/run_tests.sh`, add three lines before the final `echo "All tests passed."`:

```bash
bundle exec ruby "$EXPERIMENT_DIR/tests/test_classroom_forced_checkin.rb"
bundle exec ruby "$EXPERIMENT_DIR/tests/test_tutoring_procedure_scaffolded.rb"
bundle exec ruby "$EXPERIMENT_DIR/tests/test_report_v7.rb"
```

- [ ] **Step 2: Run full test suite**

```bash
eval "$(mise activate zsh)" && bash experiments/bloom_1n_vs_1on1/tests/run_tests.sh
```

Expected: `All tests passed.`

- [ ] **Step 3: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/tests/run_tests.sh
git commit -m "test: wire v7 test files into run_tests.sh"
```

- [ ] **Step 4: Run Experiment A smoke test**

```bash
eval "$(mise activate zsh)" && bundle exec ruby experiments/bloom_1n_vs_1on1/scripts/run_experiment_a.rb experiments/bloom_1n_vs_1on1/config_v7a_smoke.yml 2>&1 | tail -20
```

Expected: `[exp_a] Done. Results in: ...` and exit code 0. Verify report.md exists in run dir.

- [ ] **Step 5: Confirm Exp A report has rescue section**

```bash
run_dir=$(eval "$(mise activate zsh)" && bundle exec ruby experiments/bloom_1n_vs_1on1/scripts/run_experiment_a.rb experiments/bloom_1n_vs_1on1/config_v7a_smoke.yml 2>/dev/null)
grep "Passive Listener Rescue" "${run_dir}/report.md"
```

Expected: line containing `## Passive Listener Rescue Effect`

- [ ] **Step 6: Run Experiment B smoke test**

```bash
eval "$(mise activate zsh)" && bundle exec ruby experiments/bloom_1n_vs_1on1/scripts/run_experiment_b.rb experiments/bloom_1n_vs_1on1/config_v7b_smoke.yml 2>&1 | tail -20
```

Expected: `[exp_b] Done. Results in: ...` and exit code 0.

- [ ] **Step 7: Confirm Exp B report has scaffold section**

```bash
run_dir=$(eval "$(mise activate zsh)" && bundle exec ruby experiments/bloom_1n_vs_1on1/scripts/run_experiment_b.rb experiments/bloom_1n_vs_1on1/config_v7b_smoke.yml 2>/dev/null)
grep "Order Confused Scaffold" "${run_dir}/report.md"
grep "Procedure Order Errors" "${run_dir}/report.md"
```

Expected: matching lines for both sections.

- [ ] **Step 8: Commit smoke db cleanup note**

The smoke run databases (`smoke_v7a.db`, `smoke_v7b.db`) are in `.gitignore`'d `data/` directory — no action needed.

---

---

## Task 10: Update README.md

**Files:**
- Modify: `experiments/bloom_1n_vs_1on1/README.md`

Add v6 and v7 methodology sections. Update How to Run. No tests needed.

- [ ] **Step 1: Add v6 section after v5 section**

In `experiments/bloom_1n_vs_1on1/README.md`, append the following after the v5 section (before `## How to Run`):

```markdown
## v6 Methodology: Theory-Driven Learner Types

### Core change

v5 used role-play profiles (ability/misconception/interest attributes) which did not produce meaningful agent differences because the underlying LLM capability was unchanged. v6 replaces profiles with **post-LLM memory constraints** applied after the LLM generates memory from a transcript.

### 7 learner types

| Type | Memory Budget | Edge Case Retention | Rule Order Retention | Question Prob |
|------|-------------|--------------------|--------------------|--------------|
| rule_extractor | 150 words | 90% | 90% | 30% |
| edge_case_dropper | 120 words | 10% | 70% | 20% |
| order_confused | 100 words | 60% | 20% | 40% |
| passive_listener | 80 words | 20% | 40% | 0% |
| help_seeker | 130 words | 70% | 80% | 90% |
| answer_first | 100 words | 30% | 50% | 10% |
| example_memorizer | 120 words | 40% | 50% | 20% |

### Constraints applied post-LLM

1. **edge_case_retention**: each edge_case item is independently dropped with probability `1 - retention`
2. **rule_order_retention**: if `rand >= retention`, the rules array is shuffled
3. **memory_budget_words**: memory is trimmed to budget by dropping lowest-priority fields first
4. **question_asking_probability**: in classroom, `passive_listener` (prob=0.0) never asks — the LLM call is skipped entirely

### 7-field memory schema

```json
{
  "rules": [],
  "examples": [],
  "edge_cases": [],
  "strategy": [],
  "corrected_misconceptions": [],
  "remaining_misconceptions": [],
  "uncertain_rules": []
}
```

### Tutoring: diagnostic-correct-retest loop

Exchange 3 changed from "feedback + reflection" to "correction + correction_application". Exchange 4 became a **retest** on the same misconception, confirming whether the correction stuck.

### v6 key results (run_id: cd5d2f0e)

| Condition | Correct% |
|-----------|---------|
| no_education | 0% |
| homogeneous_classroom (4× edge_case_dropper) | 94% |
| heterogeneous_classroom (mixed 4 types) | 59% |
| 1on1 (same mixed 4 types) | 59% |

Type breakdown: passive_listener=13% (hetero_classroom) vs 38% (1on1); order_confused=88% (hetero_classroom) vs 63% (1on1). These opposing effects motivated v7.

## v7 Methodology: Mechanism Tests

### Research question

v6 showed 1on1 tutoring helped passive_listener (+25pp) but hurt order_confused (−25pp) compared to heterogeneous_classroom. v7 is a targeted mechanism test to explain why.

### Experiment A — Passive Listener Rescue

**All learners: passive_listener**

| Condition | Description |
|-----------|-------------|
| classroom_public_qa | Standard shared lesson; passive_listener never asks (prob=0.0) |
| classroom_forced_checkin | Shared lesson + teacher asks each learner one check-in question (forced) |
| one_on_one_tutoring | Standard 1on1 diagnostic-correct-retest session |

**Interpretation:** If `classroom_forced_checkin ≈ one_on_one_tutoring`, the benefit is forced interaction, not personalization.

### Experiment B — Order Confused Intervention

**All learners: order_confused**

| Condition | Description |
|-----------|-------------|
| classroom_public_qa | Standard shared lesson with order-focused context hint |
| generic_one_on_one_tutoring | Standard 1on1 targeting the `applies_modifiers_before_activation` misconception |
| procedure_scaffolded_one_on_one_tutoring | 1on1 with explicit 4-step procedure: ① check activation → ② apply modifiers → ③ edge cases → ④ sum. Learner must restate procedure; must label steps during retest |

**Interpretation:** If `procedure_scaffolded > generic`, the v6 failure was intervention mismatch (generic tutoring targets propositional misconceptions, not procedural ordering). If scaffolded still fails, order_confused may require mastery loops.
```

- [ ] **Step 2: Update How to Run section**

Replace the existing `## How to Run` section with:

```markdown
## How to Run

### v6 (full heterogeneity experiment)

```bash
bundle install
bundle exec ruby experiments/bloom_1n_vs_1on1/scripts/run_experiment.rb \
  experiments/bloom_1n_vs_1on1/config.yml
```

### v7 Experiment A — Passive Listener Rescue

```bash
# Smoke test (n=1, haiku)
bundle exec ruby experiments/bloom_1n_vs_1on1/scripts/run_experiment_a.rb \
  experiments/bloom_1n_vs_1on1/config_v7a_smoke.yml

# Full run (n=4, sonnet)
bundle exec ruby experiments/bloom_1n_vs_1on1/scripts/run_experiment_a.rb \
  experiments/bloom_1n_vs_1on1/config_v7a.yml
```

### v7 Experiment B — Order Confused Intervention

```bash
# Smoke test (n=1, haiku)
bundle exec ruby experiments/bloom_1n_vs_1on1/scripts/run_experiment_b.rb \
  experiments/bloom_1n_vs_1on1/config_v7b_smoke.yml

# Full run (n=4, sonnet)
bundle exec ruby experiments/bloom_1n_vs_1on1/scripts/run_experiment_b.rb \
  experiments/bloom_1n_vs_1on1/config_v7b.yml
```

Output is written to `experiments/bloom_1n_vs_1on1/data/runs/<run_id>/`.
```

- [ ] **Step 3: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/README.md
git commit -m "docs: update README with v6 learner types and v7 mechanism test design"
```

---

## Self-Review

### Spec Coverage

| Requirement | Task |
|-------------|------|
| Exp A: classroom_public_qa condition | Task 7 (orchestrator) |
| Exp A: classroom_forced_checkin condition | Tasks 2, 7 |
| Exp A: one_on_one_tutoring condition | Tasks 4, 7 |
| Exp A: all passive_listener learners | Task 7 |
| Exp A: check-in = shared lesson + per-learner Q&A | Task 2 |
| Exp B: classroom_public_qa condition | Task 8 |
| Exp B: generic_one_on_one_tutoring condition | Tasks 4, 8 |
| Exp B: procedure_scaffolded_one_on_one_tutoring | Tasks 3, 8 |
| Exp B: all order_confused learners | Task 8 |
| Scaffold: teach explicit 4-step procedure | Task 3 (PROCEDURE const + opener turn) |
| Scaffold: learner restates procedure | Task 3 (procedure_restatement turn) |
| Scaffold: learner labels steps in retest | Task 3 (retest_q instruction) |
| Memory preserves procedure if restated | strategy field not shuffled by apply_constraints |
| score_by_condition | Report (dynamic condition list, Task 5) |
| score_by_task | Existing report section (conditions dynamic) |
| score_by_learner_type | Existing report section |
| variance_by_condition | Existing report section |
| token_cost_by_condition | Existing token table |
| high_confidence_wrong_rate | Existing confidence calibration section |
| abstention_rate | Existing confidence calibration section |
| procedure_order_errors | Task 5 (new section for Exp B) |
| passive_listener_rescue_effect | Task 5 (new section for Exp A) |
| order_confused_scaffold_effect | Task 5 (new section for Exp B) |
| Eval tasks from v6 (eval_tasks_v4.json) | Both configs reference eval_tasks_v4.json |
| No new task types | Correct — both configs use existing eval_tasks_v4.json |

### Placeholder Scan

No TBD, TODO, or incomplete steps present.

### Type Consistency

- `Phases::ClassroomForcedCheckin.run` returns hash with `'condition'`, `'teacher_id'`, `'learner_ids'`, `'turns'` — matches what orchestrators pass to `DB.save_learning_session`
- `Phases::TutoringProcedureScaffolded.run_session` returns hash with `'condition'`, `'tutor_id'`, `'learner_id'`, `'turns'` — matches orchestrator usage
- `Phases::Tutoring.run_session` gains `condition:` keyword arg defaulting to `'1on1'` — existing callers unaffected
- `Report.generate` gains `experiment_meta: {}` — existing callers unaffected (default `{}` renders neither v7 section)
- `Report.passive_listener_rescue_effect(rows)` → String — matches how it's used in build_markdown
- `Report.procedure_order_error?(response_text)` → Boolean — matches how it's used in `procedure_order_error_rate`
