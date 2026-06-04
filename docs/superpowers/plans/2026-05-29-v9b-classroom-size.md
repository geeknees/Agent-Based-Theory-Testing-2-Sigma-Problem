# v9b Classroom-Size / Ownership Experiment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a 5-condition classroom-size experiment that shares one lecture across all conditions, tracks per-learner ownership metrics, and measures whether direct participation predicts learning outcomes.

**Architecture:** ONE PrerequisiteLecture.run call produces a shared transcript; all learners get Memory.generate from that same transcript (memory forking). SizedDiscussion phase routes to pair/small/medium/large variants based on `called_on_count`. Ownership metrics (contribution_count, ownership_score, etc.) are computed per-learner in SizedDiscussion and saved to a new `ownership_metrics` DB table. MemoryDiagnostics module detects 6 knowledge items before/after discussion; delta stored as `memory_delta_after_discussion`.

**Tech Stack:** Ruby, SQLite3, Minitest, `claude --print` CLI, YAML config, existing lib/phases/\*, lib/report.rb, lib/db.rb

---

## File Map

| File | Action | Responsibility |
|------|--------|----------------|
| `experiments/bloom_1n_vs_1on1/lib/db.rb` | Modify | Add `ownership_metrics` table + save/get/all methods |
| `experiments/bloom_1n_vs_1on1/lib/memory_diagnostics.rb` | Create | Pure functions: detect 6 knowledge items, compute delta |
| `experiments/bloom_1n_vs_1on1/lib/ownership_metrics.rb` | Create | Pure functions: compute_score, summary_by_condition |
| `experiments/bloom_1n_vs_1on1/lib/phases/sized_discussion.rb` | Create | Single phase for pair/small/medium/large; returns ownership_data per learner |
| `experiments/bloom_1n_vs_1on1/lib/report.rb` | Modify | Add v9b sections: ownership, memory delta, score vs ownership |
| `experiments/bloom_1n_vs_1on1/scripts/run_experiment_v9b.rb` | Create | Orchestrator with shared lecture, memory forking, 5 conditions |
| `config_v9b.yml` | Create | Production config (n=34 total, sonnet) |
| `config_v9b_smoke.yml` | Create | Smoke config (n=14 total, haiku) |
| `experiments/bloom_1n_vs_1on1/tests/test_db_v9b.rb` | Create | DB: ownership_metrics save/read |
| `experiments/bloom_1n_vs_1on1/tests/test_memory_diagnostics.rb` | Create | MemoryDiagnostics: detect, delta, coverage_count |
| `experiments/bloom_1n_vs_1on1/tests/test_sized_discussion_unit.rb` | Create | SizedDiscussion: init_ownership, compute_ownership_score |
| `experiments/bloom_1n_vs_1on1/tests/test_report_v9b.rb` | Create | Report: ownership section, memory delta section |
| `experiments/bloom_1n_vs_1on1/tests/run_tests.sh` | Modify | Add 4 new test files |

---

## Task 1: DB — ownership_metrics table + methods

**Files:**
- Modify: `experiments/bloom_1n_vs_1on1/lib/db.rb`
- Create: `experiments/bloom_1n_vs_1on1/tests/test_db_v9b.rb`

- [ ] **Step 1: Write the failing test**

```ruby
# experiments/bloom_1n_vs_1on1/tests/test_db_v9b.rb
# ABOUTME: Tests DB methods for the v9b ownership_metrics table
# ABOUTME: Covers save, get, and condition-aggregation queries

$LOAD_PATH.unshift File.join(__dir__, '..', 'lib')
require 'minitest/autorun'
require 'tmpdir'
require 'db'
require 'helpers'

class TestDbOwnershipMetrics < Minitest::Test
  def setup
    @dir = Dir.mktmpdir
    @db  = DB.setup(File.join(@dir, 'test.db'))
    @run_id = 'run-test-999'
    DB.save_run(@db, @run_id, 'test_run', { 'experiment' => { 'name' => 'test' } })
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end

  def test_save_and_get_ownership_metrics
    learner_id = 'learner-001'
    DB.save_ownership_metrics(@db,
      run_id: @run_id, learner_id: learner_id,
      condition: 'pair_discussion_size_2',
      contribution_count: 2, attempted_answer: true,
      received_feedback: true, misconception_exposed: false,
      misconception_corrected: false, observed_peer_reasoning_count: 1,
      memory_delta_after_discussion: 2, ownership_score: 3,
      discussion_exposure_count: 5, direct_participation_count: 2,
      moderator_feedback_count: 1
    )
    rows = DB.get_ownership_metrics(@db, run_id: @run_id, learner_id: learner_id)
    assert_equal 1, rows.size
    row = rows.first
    assert_equal 2, row['contribution_count']
    assert_equal 1, row['attempted_answer']
    assert_equal 3, row['ownership_score']
  end

  def test_all_ownership_metrics_by_condition_groups_correctly
    %w[learner-a learner-b].each_with_index do |lid, i|
      DB.save_ownership_metrics(@db,
        run_id: @run_id, learner_id: lid,
        condition: 'small_class_discussion_size_4',
        contribution_count: i + 1, attempted_answer: true,
        received_feedback: true, misconception_exposed: false,
        misconception_corrected: false, observed_peer_reasoning_count: 0,
        memory_delta_after_discussion: i, ownership_score: 2,
        discussion_exposure_count: 4, direct_participation_count: 1,
        moderator_feedback_count: 1
      )
    end
    by_cond = DB.all_ownership_metrics_by_condition(@db, @run_id)
    assert_equal 1, by_cond.keys.size
    assert_equal 2, by_cond['small_class_discussion_size_4'].size
  end

  def test_save_ownership_metrics_boolean_fields_round_trip
    DB.save_ownership_metrics(@db,
      run_id: @run_id, learner_id: 'learner-c',
      condition: 'lecture_only',
      contribution_count: 0, attempted_answer: false,
      received_feedback: false, misconception_exposed: false,
      misconception_corrected: false, observed_peer_reasoning_count: 0,
      memory_delta_after_discussion: 0, ownership_score: 0,
      discussion_exposure_count: 0, direct_participation_count: 0,
      moderator_feedback_count: 0
    )
    rows = DB.get_ownership_metrics(@db, run_id: @run_id, learner_id: 'learner-c')
    assert_equal 0, rows.first['attempted_answer']
    assert_equal 0, rows.first['received_feedback']
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /Users/masumi/tmp/Agent-Based-Theory-Testing-2-Sigma-Problem
eval "$(mise activate zsh)"
bundle exec ruby experiments/bloom_1n_vs_1on1/tests/test_db_v9b.rb
```

Expected: FAIL with `undefined method 'save_ownership_metrics'`

- [ ] **Step 3: Add ownership_metrics table to DB::SCHEMA and add methods**

In `experiments/bloom_1n_vs_1on1/lib/db.rb`, add to SCHEMA (after `mastery_check_results`):

```ruby
    CREATE TABLE IF NOT EXISTS ownership_metrics (
      id TEXT PRIMARY KEY,
      run_id TEXT NOT NULL,
      learner_id TEXT NOT NULL,
      condition TEXT NOT NULL,
      contribution_count INTEGER NOT NULL DEFAULT 0,
      attempted_answer INTEGER NOT NULL DEFAULT 0,
      received_feedback INTEGER NOT NULL DEFAULT 0,
      misconception_exposed INTEGER NOT NULL DEFAULT 0,
      misconception_corrected INTEGER NOT NULL DEFAULT 0,
      observed_peer_reasoning_count INTEGER NOT NULL DEFAULT 0,
      memory_delta_after_discussion INTEGER NOT NULL DEFAULT 0,
      ownership_score INTEGER NOT NULL DEFAULT 0,
      discussion_exposure_count INTEGER NOT NULL DEFAULT 0,
      direct_participation_count INTEGER NOT NULL DEFAULT 0,
      moderator_feedback_count INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL DEFAULT (datetime('now'))
    );
```

Add these methods at the end of `DB` module (before the closing `end`):

```ruby
  def self.save_ownership_metrics(db, run_id:, learner_id:, condition:,
                                  contribution_count:, attempted_answer:,
                                  received_feedback:, misconception_exposed:,
                                  misconception_corrected:, observed_peer_reasoning_count:,
                                  memory_delta_after_discussion:, ownership_score:,
                                  discussion_exposure_count:, direct_participation_count:,
                                  moderator_feedback_count:)
    id = Helpers.generate_id
    db.execute(
      'INSERT INTO ownership_metrics (id, run_id, learner_id, condition,
         contribution_count, attempted_answer, received_feedback,
         misconception_exposed, misconception_corrected,
         observed_peer_reasoning_count, memory_delta_after_discussion,
         ownership_score, discussion_exposure_count, direct_participation_count,
         moderator_feedback_count) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
      [id, run_id, learner_id, condition,
       contribution_count,
       attempted_answer  ? 1 : 0,
       received_feedback ? 1 : 0,
       misconception_exposed   ? 1 : 0,
       misconception_corrected ? 1 : 0,
       observed_peer_reasoning_count, memory_delta_after_discussion,
       ownership_score, discussion_exposure_count, direct_participation_count,
       moderator_feedback_count]
    )
    id
  end

  def self.get_ownership_metrics(db, run_id:, learner_id:)
    db.execute(
      'SELECT * FROM ownership_metrics WHERE run_id = ? AND learner_id = ? ORDER BY rowid',
      [run_id, learner_id]
    )
  end

  def self.all_ownership_metrics_by_condition(db, run_id)
    rows = db.execute(
      'SELECT * FROM ownership_metrics WHERE run_id = ? ORDER BY condition, learner_id',
      [run_id]
    )
    rows.group_by { |r| r['condition'] }
  end
```

- [ ] **Step 4: Run test to verify it passes**

```bash
cd /Users/masumi/tmp/Agent-Based-Theory-Testing-2-Sigma-Problem
bundle exec ruby experiments/bloom_1n_vs_1on1/tests/test_db_v9b.rb
```

Expected: 3 tests pass, 0 failures

- [ ] **Step 5: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/lib/db.rb \
        experiments/bloom_1n_vs_1on1/tests/test_db_v9b.rb
git commit -m "feat(v9b): add ownership_metrics table and DB methods"
```

---

## Task 2: MemoryDiagnostics module (pure functions)

**Files:**
- Create: `experiments/bloom_1n_vs_1on1/lib/memory_diagnostics.rb`
- Create: `experiments/bloom_1n_vs_1on1/tests/test_memory_diagnostics.rb`

- [ ] **Step 1: Write the failing test**

```ruby
# experiments/bloom_1n_vs_1on1/tests/test_memory_diagnostics.rb
# ABOUTME: Tests MemoryDiagnostics — pure functions for detecting 6 zarn-domain knowledge items
# ABOUTME: No LLM calls; verifies regex detection and delta computation

$LOAD_PATH.unshift File.join(__dir__, '..', 'lib')
require 'minitest/autorun'
require 'memory_diagnostics'

class TestMemoryDiagnostics < Minitest::Test
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

  def test_detect_blue_activation_present
    mem = empty_memory.merge('rules' => ['Blue is active if there is a Green to its left'])
    assert MemoryDiagnostics.detect(mem)[:blue_activation]
  end

  def test_detect_blue_activation_absent
    mem = empty_memory.merge('rules' => ['Yellow is always active and scores 7'])
    refute MemoryDiagnostics.detect(mem)[:blue_activation]
  end

  def test_detect_green_end_position
    mem = empty_memory.merge('edge_cases' => ['Green is inactive when it is the last token in the sequence'])
    assert MemoryDiagnostics.detect(mem)[:green_end_position]
  end

  def test_detect_red_modifier
    mem = empty_memory.merge('rules' => ['Red is a pure modifier: doubles the token to its right, itself scores 0'])
    assert MemoryDiagnostics.detect(mem)[:red_modifier]
  end

  def test_detect_yellow_always_active
    mem = empty_memory.merge('rules' => ['Yellow is always active and scores 7 in any position'])
    assert MemoryDiagnostics.detect(mem)[:yellow_always_active]
  end

  def test_detect_activation_before_modification
    mem = empty_memory.merge('strategy' => ['Check activation status before applying modifier doubling'])
    assert MemoryDiagnostics.detect(mem)[:activation_before_modification]
  end

  def test_detect_final_summing
    mem = empty_memory.merge('strategy' => ['Sum all active token values to get the final score'])
    assert MemoryDiagnostics.detect(mem)[:final_summing]
  end

  def test_coverage_count_empty_memory
    assert_equal 0, MemoryDiagnostics.coverage_count(empty_memory)
  end

  def test_coverage_count_full_memory
    mem = empty_memory.merge(
      'rules' => [
        'Blue is active if there is a Green to its left',
        'Red is a modifier: doubles the next token. Red itself scores 0.',
        'Yellow is always active and scores 7 in any position'
      ],
      'edge_cases' => ['Green is inactive when it is the last token'],
      'strategy'   => [
        'Check activation status before applying the modifier doubling',
        'Sum all active token values for the final score'
      ]
    )
    assert_equal 6, MemoryDiagnostics.coverage_count(mem)
  end

  def test_delta_counts_acquired_items
    before = empty_memory
    after  = empty_memory.merge('rules' => ['Blue is active if Green is to its left in the sequence'])
    result = MemoryDiagnostics.delta(before, after)
    assert_equal 1, result[:acquired]
    assert_equal 0, result[:lost]
    assert_equal 0, result[:stable]
  end

  def test_delta_zero_when_identical
    mem = empty_memory.merge('rules' => ['Red doubles next token, Red scores 0'])
    result = MemoryDiagnostics.delta(mem, mem)
    assert_equal 0, result[:acquired]
    assert_equal 0, result[:lost]
  end

  def test_delta_detects_lost_item
    before = empty_memory.merge('rules' => ['Yellow is always active and scores 7 in any position'])
    after  = empty_memory
    result = MemoryDiagnostics.delta(before, after)
    assert_equal 0, result[:acquired]
    assert_equal 1, result[:lost]
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /Users/masumi/tmp/Agent-Based-Theory-Testing-2-Sigma-Problem
bundle exec ruby experiments/bloom_1n_vs_1on1/tests/test_memory_diagnostics.rb
```

Expected: FAIL with `cannot load such file -- memory_diagnostics`

- [ ] **Step 3: Write minimal implementation**

```ruby
# experiments/bloom_1n_vs_1on1/lib/memory_diagnostics.rb
# ABOUTME: Detects presence of 6 key knowledge items in a learner memory hash
# ABOUTME: Pure functions — no LLM calls; used for pre/post-discussion diagnostics

module MemoryDiagnostics
  # Regex patterns for each knowledge item in the zarn-tokens domain
  ITEMS = {
    blue_activation:               /blue.*green.*left|green.*left.*blue|blue.*active.*if.*green|need.*green.*before.*blue/i,
    green_end_position:            /green.*last|green.*end.*inactive|last.*green.*inactive|green.*inactive.*last/i,
    red_modifier:                  /red.*double|red.*modifier|red.*0|red.*pure.*modifier/i,
    yellow_always_active:          /yellow.*always|yellow.*7.*any|yellow.*active.*any.*position|always.*active.*yellow/i,
    activation_before_modification: /activation.*before.*modifier|activation.*first.*modifier|check.*active.*before.*double|activation.*status.*before/i,
    final_summing:                 /sum.*active|add.*active|total.*active|sum.*all.*active/i
  }.freeze

  # Returns { item_key => bool } for all 6 items
  def self.detect(memory)
    text = memory_to_text(memory)
    ITEMS.transform_values { |pattern| text.match?(pattern) }
  end

  # Number of detected items (0–6)
  def self.coverage_count(memory)
    detect(memory).count { |_, v| v }
  end

  # Returns { acquired:, lost:, stable: } counts comparing two memory snapshots
  def self.delta(before_memory, after_memory)
    before = detect(before_memory)
    after  = detect(after_memory)
    {
      acquired: ITEMS.keys.count { |k| !before[k] && after[k] },
      lost:     ITEMS.keys.count { |k|  before[k] && !after[k] },
      stable:   ITEMS.keys.count { |k|  before[k] &&  after[k] }
    }
  end

  private_class_method def self.memory_to_text(memory)
    return '' unless memory.is_a?(Hash)
    memory.values.flatten.compact.join(' ')
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

```bash
cd /Users/masumi/tmp/Agent-Based-Theory-Testing-2-Sigma-Problem
bundle exec ruby experiments/bloom_1n_vs_1on1/tests/test_memory_diagnostics.rb
```

Expected: 11 tests pass, 0 failures

- [ ] **Step 5: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/lib/memory_diagnostics.rb \
        experiments/bloom_1n_vs_1on1/tests/test_memory_diagnostics.rb
git commit -m "feat(v9b): add MemoryDiagnostics pure-function module"
```

---

## Task 3: SizedDiscussion phase

**Files:**
- Create: `experiments/bloom_1n_vs_1on1/lib/phases/sized_discussion.rb`
- Create: `experiments/bloom_1n_vs_1on1/tests/test_sized_discussion_unit.rb`

- [ ] **Step 1: Write the failing test** (unit tests for pure-function helpers only — no LLM calls)

```ruby
# experiments/bloom_1n_vs_1on1/tests/test_sized_discussion_unit.rb
# ABOUTME: Unit tests for SizedDiscussion pure-function helpers
# ABOUTME: Covers ownership initialisation and ownership_score computation

$LOAD_PATH.unshift File.join(__dir__, '..', 'lib')
require 'minitest/autorun'
require 'phases/sized_discussion'

class TestSizedDiscussionUnit < Minitest::Test
  def test_init_ownership_creates_entry_per_learner
    ids    = %w[a b c]
    result = Phases::SizedDiscussion.send(:init_ownership, ids)
    assert_equal 3, result.keys.size
    assert_equal 0, result['a'][:contribution_count]
    assert_equal false, result['b'][:attempted_answer]
  end

  def test_compute_ownership_score_zero_for_observer
    data = { contribution_count: 0, attempted_answer: false,
             received_feedback: false, misconception_exposed: false,
             misconception_corrected: false }
    assert_equal 0, Phases::SizedDiscussion.send(:compute_ownership_score, data)
  end

  def test_compute_ownership_score_max_three_for_full_participant
    data = { contribution_count: 2, attempted_answer: true,
             received_feedback: true, misconception_exposed: false,
             misconception_corrected: false }
    # contributed(1) + attempted(1) + received_feedback(1) = 3
    assert_equal 3, Phases::SizedDiscussion.send(:compute_ownership_score, data)
  end

  def test_compute_ownership_score_four_with_misconception_corrected
    data = { contribution_count: 1, attempted_answer: true,
             received_feedback: true, misconception_exposed: false,
             misconception_corrected: true }
    # contributed(1) + attempted(1) + received_feedback(1) + corrected(1) = 4
    assert_equal 4, Phases::SizedDiscussion.send(:compute_ownership_score, data)
  end

  def test_compute_ownership_score_exposed_or_corrected_counts_once
    data = { contribution_count: 0, attempted_answer: false,
             received_feedback: false, misconception_exposed: true,
             misconception_corrected: true }
    # exposed_or_corrected = 1 (not 2)
    assert_equal 1, Phases::SizedDiscussion.send(:compute_ownership_score, data)
  end

  def test_called_on_ids_respects_called_on_count
    all_ids = %w[a b c d e f g h]
    called  = all_ids.first(4)
    obs     = all_ids - called
    assert_equal 4, called.size
    assert_equal 4, obs.size
    assert_equal %w[a b c d], called
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /Users/masumi/tmp/Agent-Based-Theory-Testing-2-Sigma-Problem
bundle exec ruby experiments/bloom_1n_vs_1on1/tests/test_sized_discussion_unit.rb
```

Expected: FAIL with `cannot load such file -- phases/sized_discussion`

- [ ] **Step 3: Write SizedDiscussion implementation**

```ruby
# experiments/bloom_1n_vs_1on1/lib/phases/sized_discussion.rb
# ABOUTME: Unified discussion phase for pair/small/medium/large class sizes
# ABOUTME: Returns per-learner ownership_data; caller updates memories and saves to DB

require_relative '../llm'
require_relative '../helpers'
require_relative '../learner_types'

module Phases
  module SizedDiscussion
    DISCUSSION_PROBLEM = <<~PROB.freeze
      DISCUSSION PROBLEM: Calculate and explain the score for [Red, Green, Blue, Yellow].
      - Show your step-by-step reasoning.
      - Identify which tokens are active and why.
      - Note any rules that are easy to get wrong here.
    PROB

    # condition:         one of pair_discussion_size_2 / small_class_discussion_size_4 /
    #                    medium_class_discussion_size_8 / large_class_discussion_size_16
    # learner_ids:       ordered list of all learners in this condition
    # called_on_count:   nil = all contribute; integer = only first N are called on
    #
    # Returns {
    #   'condition'      => String,
    #   'turns'          => Array<Hash>,
    #   'ownership_data' => { learner_id => Hash },
    #   'called_on_ids'  => Array,
    #   'observer_ids'   => Array
    # }
    def self.run(condition:, learner_ids:, called_on_count: nil,
                 moderator_id:, moderator_prompt:, participant_prompt:,
                 lesson:, config:, tracker: nil, learner_type_keys: {})

      mod_model     = config.dig('models', 'teacher') || 'claude-sonnet-4-6'
      learner_model = config.dig('models', 'learner') || 'claude-sonnet-4-6'

      called_on_ids = called_on_count ? learner_ids.first(called_on_count) : learner_ids
      observer_ids  = learner_ids - called_on_ids

      ownership_data = init_ownership(learner_ids)
      turns = []

      # --- Moderator opens ---
      open_prompt = Helpers.build_prompt(
        system: moderator_prompt,
        context: "DOMAIN LESSON:\n#{lesson}",
        instruction: "Open the class discussion. Present the problem and invite learners to share their reasoning. Under 80 words.\n\n#{DISCUSSION_PROBLEM}"
      )
      opening = LLM.call(open_prompt, model: mod_model, tracker: tracker, phase: "education_#{condition}")
      turns << { 'speaker' => 'moderator', 'type' => 'opening', 'content' => opening }
      $stderr.puts "[#{condition}] Moderator opened (#{learner_ids.size} learners, #{called_on_ids.size} called on)"

      # --- Called-on learners contribute ---
      called_on_ids.each_with_index do |lid, idx|
        history  = Helpers.format_turns_for_prompt(turns)
        type_key = learner_type_keys[lid]
        ctx      = "DISCUSSION SO FAR:\n#{history}"
        ctx     += "\n\nYOUR LEARNER TYPE: #{type_key} — respond authentically." if type_key

        contrib_prompt = Helpers.build_prompt(
          system: participant_prompt,
          context: ctx,
          instruction: "Contribute your reasoning for the discussion problem. Show step-by-step thinking. Under 100 words."
        )
        contrib = LLM.call(contrib_prompt, model: learner_model, tracker: tracker, phase: "education_#{condition}")
        turns << { 'speaker' => lid, 'type' => 'contribution', 'content' => contrib }

        ownership_data[lid][:contribution_count]        += 1
        ownership_data[lid][:direct_participation_count] += 1
        ownership_data[lid][:attempted_answer]            = true

        # Everyone who hasn't spoken yet observes this contribution
        later_called  = called_on_ids[(idx + 1)..]
        (later_called + observer_ids).each { |oid| ownership_data[oid][:observed_peer_reasoning_count] += 1 }
        $stderr.puts "[#{condition}] #{lid} contributed"
      end

      # --- Pair-only: reply round + shared notes ---
      if condition == 'pair_discussion_size_2' && called_on_ids.size == 2
        called_on_ids.each do |lid|
          history  = Helpers.format_turns_for_prompt(turns)
          type_key = learner_type_keys[lid]
          ctx      = "PAIR DISCUSSION:\n#{history}"
          ctx     += "\n\nYOUR LEARNER TYPE: #{type_key} — respond authentically." if type_key

          reply_prompt = Helpers.build_prompt(
            system: participant_prompt,
            context: ctx,
            instruction: "Respond to your partner. Agree, correct, or add a point. Under 60 words."
          )
          reply = LLM.call(reply_prompt, model: learner_model, tracker: tracker, phase: "education_#{condition}")
          turns << { 'speaker' => lid, 'type' => 'reply', 'content' => reply }
          ownership_data[lid][:contribution_count] += 1
          $stderr.puts "[#{condition}] #{lid} replied"
        end
      end

      # --- Moderator closes ---
      history = Helpers.format_turns_for_prompt(turns)
      close_prompt = Helpers.build_prompt(
        system: moderator_prompt,
        context: "DOMAIN LESSON:\n#{lesson}\n\nDISCUSSION:\n#{history}",
        instruction: "Close the discussion. Confirm the correct answer. Highlight the key rules. Correct any errors in learner contributions. Under 100 words."
      )
      closing = LLM.call(close_prompt, model: mod_model, tracker: tracker, phase: "education_#{condition}")
      turns << { 'speaker' => 'moderator', 'type' => 'closing', 'content' => closing }
      $stderr.puts "[#{condition}] Moderator closed"

      # Direct feedback: only called-on learners received targeted feedback
      called_on_ids.each do |lid|
        ownership_data[lid][:received_feedback]       = true
        ownership_data[lid][:moderator_feedback_count] += 1
      end

      # --- Pair-only: shared notes ---
      if condition == 'pair_discussion_size_2'
        history = Helpers.format_turns_for_prompt(turns)
        notes_prompt = Helpers.build_prompt(
          system: participant_prompt,
          context: "PAIR DISCUSSION:\n#{history}",
          instruction: "Write shared notes summarizing: (1) the correct answer, (2) key rules each member needs, (3) any mistakes noticed. Under 80 words. Start with 'GROUP NOTES:'"
        )
        notes = LLM.call(notes_prompt, model: learner_model, tracker: tracker, phase: "education_#{condition}")
        turns << { 'speaker' => called_on_ids.first, 'type' => 'shared_notes', 'content' => notes }
        $stderr.puts "[#{condition}] Shared notes produced"
      end

      # Exposure count = total turns in session (everyone present throughout)
      total_turns = turns.size
      learner_ids.each { |lid| ownership_data[lid][:discussion_exposure_count] = total_turns }

      # Compute ownership_score
      ownership_data.each_value do |data|
        data[:ownership_score] = compute_ownership_score(data)
      end

      {
        'condition'      => condition,
        'turns'          => turns,
        'ownership_data' => ownership_data.transform_values { |d| d.transform_keys(&:to_s) },
        'called_on_ids'  => called_on_ids,
        'observer_ids'   => observer_ids
      }
    end

    private_class_method def self.init_ownership(learner_ids)
      learner_ids.each_with_object({}) do |lid, h|
        h[lid] = {
          contribution_count:             0,
          attempted_answer:               false,
          received_feedback:              false,
          misconception_exposed:          false,
          misconception_corrected:        false,
          observed_peer_reasoning_count:  0,
          discussion_exposure_count:      0,
          direct_participation_count:     0,
          moderator_feedback_count:       0,
          ownership_score:                0
        }
      end
    end

    private_class_method def self.compute_ownership_score(data)
      score = 0
      score += 1 if data[:contribution_count] > 0
      score += 1 if data[:attempted_answer]
      score += 1 if data[:received_feedback]
      score += 1 if data[:misconception_exposed] || data[:misconception_corrected]
      score
    end
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

```bash
cd /Users/masumi/tmp/Agent-Based-Theory-Testing-2-Sigma-Problem
bundle exec ruby experiments/bloom_1n_vs_1on1/tests/test_sized_discussion_unit.rb
```

Expected: 6 tests pass, 0 failures

- [ ] **Step 5: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/lib/phases/sized_discussion.rb \
        experiments/bloom_1n_vs_1on1/tests/test_sized_discussion_unit.rb
git commit -m "feat(v9b): add SizedDiscussion phase with ownership tracking"
```

---

## Task 4: OwnershipMetrics module + report.rb v9b sections

**Files:**
- Create: `experiments/bloom_1n_vs_1on1/lib/ownership_metrics.rb`
- Modify: `experiments/bloom_1n_vs_1on1/lib/report.rb`
- Create: `experiments/bloom_1n_vs_1on1/tests/test_report_v9b.rb`

- [ ] **Step 1: Write the failing test**

```ruby
# experiments/bloom_1n_vs_1on1/tests/test_report_v9b.rb
# ABOUTME: Tests report.rb v9b sections — ownership summary and memory delta
# ABOUTME: Verifies markdown output for new report blocks

$LOAD_PATH.unshift File.join(__dir__, '..', 'lib')
require 'minitest/autorun'
require 'ownership_metrics'
require 'memory_diagnostics'

class TestOwnershipMetrics < Minitest::Test
  def test_summary_by_condition_averages_ownership_score
    rows = [
      { 'condition' => 'pair_discussion_size_2', 'ownership_score' => 3,
        'contribution_count' => 2, 'attempted_answer' => 1, 'received_feedback' => 1 },
      { 'condition' => 'pair_discussion_size_2', 'ownership_score' => 2,
        'contribution_count' => 1, 'attempted_answer' => 1, 'received_feedback' => 0 }
    ]
    result = OwnershipMetrics.summary_by_condition(rows)
    assert_in_delta 2.5, result['pair_discussion_size_2'][:avg_ownership_score], 0.01
  end

  def test_summary_by_condition_pct_attempted
    rows = [
      { 'condition' => 'lecture_only', 'ownership_score' => 0,
        'contribution_count' => 0, 'attempted_answer' => 0, 'received_feedback' => 0 },
      { 'condition' => 'lecture_only', 'ownership_score' => 0,
        'contribution_count' => 0, 'attempted_answer' => 0, 'received_feedback' => 0 }
    ]
    result = OwnershipMetrics.summary_by_condition(rows)
    assert_in_delta 0.0, result['lecture_only'][:pct_attempted_answer], 0.01
  end

  def test_summary_empty_returns_empty
    assert_equal({}, OwnershipMetrics.summary_by_condition([]))
  end
end

class TestReportOwnershipSection < Minitest::Test
  def ownership_rows
    [
      { 'condition' => 'pair_discussion_size_2', 'ownership_score' => 3,
        'contribution_count' => 2, 'attempted_answer' => 1, 'received_feedback' => 1,
        'memory_delta_after_discussion' => 2 },
      { 'condition' => 'large_class_discussion_size_16', 'ownership_score' => 0,
        'contribution_count' => 0, 'attempted_answer' => 0, 'received_feedback' => 0,
        'memory_delta_after_discussion' => 0 }
    ]
  end

  def test_ownership_section_contains_condition_names
    require 'report'
    section = Report.send(:ownership_section, ownership_rows)
    assert_includes section, 'pair_discussion_size_2'
    assert_includes section, 'large_class_discussion_size_16'
  end

  def test_ownership_section_contains_ownership_score
    require 'report'
    section = Report.send(:ownership_section, ownership_rows)
    assert_includes section, 'Avg Ownership Score'
  end

  def test_memory_delta_section_contains_avg_delta
    require 'report'
    section = Report.send(:memory_delta_section, ownership_rows)
    assert_includes section, 'Memory Delta'
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /Users/masumi/tmp/Agent-Based-Theory-Testing-2-Sigma-Problem
bundle exec ruby experiments/bloom_1n_vs_1on1/tests/test_report_v9b.rb
```

Expected: FAIL with `cannot load such file -- ownership_metrics`

- [ ] **Step 3: Create lib/ownership_metrics.rb**

```ruby
# experiments/bloom_1n_vs_1on1/lib/ownership_metrics.rb
# ABOUTME: Pure functions for computing ownership summaries from DB ownership_metrics rows
# ABOUTME: Used by report.rb v9b sections; no LLM calls

module OwnershipMetrics
  # Summarizes ownership rows (from DB) grouped by condition
  # Returns { condition => { avg_ownership_score:, avg_contribution_count:,
  #                          pct_attempted_answer:, pct_received_feedback:,
  #                          avg_memory_delta: } }
  def self.summary_by_condition(rows)
    return {} if rows.nil? || rows.empty?
    rows.group_by { |r| r['condition'] }.transform_values do |crows|
      n = crows.size.to_f
      {
        avg_ownership_score:   crows.sum { |r| r['ownership_score'].to_f } / n,
        avg_contribution_count: crows.sum { |r| r['contribution_count'].to_f } / n,
        pct_attempted_answer:  crows.count { |r| r['attempted_answer'].to_i == 1 } / n,
        pct_received_feedback: crows.count { |r| r['received_feedback'].to_i == 1 } / n,
        avg_memory_delta:      crows.sum { |r| r['memory_delta_after_discussion'].to_f } / n
      }
    end
  end
end
```

- [ ] **Step 4: Add v9b sections to lib/report.rb**

In `report.rb`, find the block:
```ruby
    # v8: mastery check scores and memory coverage
    if experiment_meta[:experiment] == 'v8'
      lines << mastery_check_section(mastery_rows)
      lines << memory_coverage_section(memories_by_condition)
    end
```

Replace with:
```ruby
    # v8: mastery check scores and memory coverage
    if experiment_meta[:experiment] == 'v8'
      lines << mastery_check_section(mastery_rows)
      lines << memory_coverage_section(memories_by_condition)
    end

    # v9b: ownership metrics and memory delta
    if experiment_meta[:experiment] == 'v9b'
      lines << mastery_check_section(mastery_rows)
      lines << memory_coverage_section(memories_by_condition)
      lines << ownership_section(experiment_meta[:ownership_rows] || [])
      lines << memory_delta_section(experiment_meta[:ownership_rows] || [])
    end
```

Add these two methods to `report.rb` alongside the existing `mastery_check_section` and `memory_coverage_section`:

```ruby
  def self.ownership_section(ownership_rows)
    return '' if ownership_rows.nil? || ownership_rows.empty?
    require_relative 'ownership_metrics'
    summary = OwnershipMetrics.summary_by_condition(ownership_rows)
    lines = []
    lines << "## Ownership Metrics by Condition"
    lines << ""
    lines << "| Condition | Avg Ownership Score | Avg Contributions | % Attempted | % Received Feedback |"
    lines << "|-----------|--------------------|--------------------|-------------|---------------------|"
    summary.sort_by { |k, _| k }.each do |cond, s|
      lines << "| #{cond} | #{s[:avg_ownership_score].round(2)} | #{s[:avg_contribution_count].round(1)} | #{(s[:pct_attempted_answer] * 100).round}% | #{(s[:pct_received_feedback] * 100).round}% |"
    end
    lines << ""
    lines.join("\n")
  end

  def self.memory_delta_section(ownership_rows)
    return '' if ownership_rows.nil? || ownership_rows.empty?
    require_relative 'ownership_metrics'
    summary = OwnershipMetrics.summary_by_condition(ownership_rows)
    lines = []
    lines << "## Memory Delta by Condition (knowledge items acquired during discussion)"
    lines << ""
    lines << "| Condition | Avg Memory Delta (items) |"
    lines << "|-----------|--------------------------|"
    summary.sort_by { |k, _| k }.each do |cond, s|
      lines << "| #{cond} | #{s[:avg_memory_delta].round(2)} |"
    end
    lines << ""
    lines.join("\n")
  end
```

- [ ] **Step 5: Run test to verify it passes**

```bash
cd /Users/masumi/tmp/Agent-Based-Theory-Testing-2-Sigma-Problem
bundle exec ruby experiments/bloom_1n_vs_1on1/tests/test_report_v9b.rb
```

Expected: 6 tests pass, 0 failures

- [ ] **Step 6: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/lib/ownership_metrics.rb \
        experiments/bloom_1n_vs_1on1/lib/report.rb \
        experiments/bloom_1n_vs_1on1/tests/test_report_v9b.rb
git commit -m "feat(v9b): add OwnershipMetrics module and v9b report sections"
```

---

## Task 5: run_experiment_v9b.rb orchestrator

**Files:**
- Create: `experiments/bloom_1n_vs_1on1/scripts/run_experiment_v9b.rb`

- [ ] **Step 1: Verify prerequisites exist**

```bash
ls experiments/bloom_1n_vs_1on1/lib/phases/sized_discussion.rb
ls experiments/bloom_1n_vs_1on1/lib/memory_diagnostics.rb
```

Both files must exist from Tasks 2–3.

- [ ] **Step 2: Write the orchestrator**

```ruby
# experiments/bloom_1n_vs_1on1/scripts/run_experiment_v9b.rb
# ABOUTME: Orchestrator for v9b classroom-size / ownership experiment — 5 conditions
# ABOUTME: Shared single lecture → memory fork → sized discussion → evaluation → report

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
require 'phases/prerequisite_lecture'
require 'phases/mastery_check'
require 'phases/sized_discussion'
require 'phases/memory'
require 'phases/solver'
require 'phases/evaluator'
require 'report'

config_path  = ARGV[0] or abort "Usage: #{$0} <config.yml>"
PROJECT_ROOT = File.expand_path('../..', EXPERIMENT_DIR)
config       = YAML.load_file(File.join(PROJECT_ROOT, config_path))

run_id      = SecureRandom.uuid
run_name    = config.dig('experiment', 'name') || 'bloom_v9b'
domain_path = File.join(PROJECT_ROOT, config.dig('paths', 'domain'))
prompts_path = File.join(PROJECT_ROOT, config.dig('paths', 'prompts'))
output_base  = File.join(PROJECT_ROOT, config.dig('paths', 'output'))
db_path      = File.join(PROJECT_ROOT, config.dig('paths', 'db'))
run_dir      = File.join(output_base, 'runs', run_id)

FileUtils.mkdir_p(run_dir)
$stderr.puts "[v9b] Starting run #{run_id}"

tracker = TokenTracker.new

lesson       = Helpers.load_file(File.join(domain_path, 'lesson.md'))
tasks_file   = config.dig('experiment', 'eval_tasks_file') || 'eval_tasks_v8.json'
eval_tasks   = JSON.parse(Helpers.load_file(File.join(domain_path, tasks_file)))
check_tasks  = JSON.parse(Helpers.load_file(File.join(domain_path, 'mastery_check_tasks.json')))
rubric       = JSON.parse(Helpers.load_file(File.join(domain_path, 'rubric.json')))

teacher_prompt     = Helpers.load_file(File.join(prompts_path, 'classroom_teacher.md'))
moderator_prompt   = Helpers.load_file(File.join(prompts_path, 'discussion_moderator.md'))
participant_prompt = Helpers.load_file(File.join(prompts_path, 'discussion_participant.md'))
learner_prompt     = Helpers.load_file(File.join(prompts_path, 'learner.md'))
summarizer_prompt  = Helpers.load_file(File.join(prompts_path, 'memory_summarizer.md'))
solver_prompt      = Helpers.load_file(File.join(prompts_path, 'problem_solver.md'))
evaluator_prompt   = Helpers.load_file(File.join(prompts_path, 'blind_evaluator.md'))

db = DB.setup(db_path)
DB.save_run(db, run_id, run_name, config)
File.write(File.join(run_dir, 'config.json'), JSON.pretty_generate(config))

# Build per-condition learner lists from config
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

# Assign learners per condition based on class_sizes config
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
$stderr.puts "[v9b] Learner distribution: #{by_condition.transform_values(&:size)}"

# ---------------------------------------------------------------------------
# PHASE 1: ONE shared prerequisite lecture for ALL conditions
# ---------------------------------------------------------------------------
$stderr.puts "[v9b] Phase 1: Generating ONE shared lecture"

shared_transcript = Phases::PrerequisiteLecture.run(
  teacher_id: teacher_id, learner_ids: all_learners.map { |l| l[:id] },
  teacher_prompt: teacher_prompt, learner_prompt: learner_prompt,
  lesson: lesson, config: config, tracker: tracker, learner_type_keys: {}
)

# Save shared transcript log
File.write(File.join(run_dir, 'shared_lecture.json'), JSON.pretty_generate(shared_transcript))
$stderr.puts "[v9b] Shared lecture: #{shared_transcript['lecture'].length} chars"

# ---------------------------------------------------------------------------
# PHASE 1b: Memory fork — all learners generate memory from SAME lecture
# ---------------------------------------------------------------------------
$stderr.puts "[v9b] Phase 1b: Memory fork (#{all_learners.size} learners)"

pre_discussion_memories = {}

all_learners.each do |learner|
  memory = Phases::Memory.generate(
    learner_id: learner[:id], transcript: shared_transcript,
    summarizer_prompt: summarizer_prompt, config: config, tracker: tracker,
    learner_type_key: learner[:type_key]
  )
  DB.save_learner_memory(db, run_id: run_id, learner_id: learner[:id],
                         condition: learner[:condition], memory: memory)
  # Snapshot for memory diagnostics delta computation
  pre_discussion_memories[learner[:id]] = memory
  File.open(File.join(run_dir, 'memories.jsonl'), 'a') do |f|
    f.puts JSON.dump({ phase: 'post_lecture', learner_id: learner[:id],
                       condition: learner[:condition], type_key: learner[:type_key].to_s,
                       diag: MemoryDiagnostics.detect(memory), memory: memory })
  end
end

# ---------------------------------------------------------------------------
# PHASE 2: Mastery check (all conditions)
# ---------------------------------------------------------------------------
$stderr.puts "[v9b] Phase 2: Mastery checks (#{all_learners.size} × #{check_tasks.size})"

all_learners.each do |learner|
  memory = DB.get_learner_memory(db, run_id: run_id, learner_id: learner[:id])
  result = Phases::MasteryCheck.run(
    learner_id: learner[:id], memory: memory, check_tasks: check_tasks,
    solver_prompt: solver_prompt, config: config, db: db, run_id: run_id,
    tracker: tracker
  )
  DB.save_learner_memory(db, run_id: run_id, learner_id: learner[:id],
                         condition: learner[:condition], memory: result[:updated_memory])
  # Update pre-discussion snapshot to post-mastery state
  pre_discussion_memories[learner[:id]] = result[:updated_memory]
  File.open(File.join(run_dir, 'memories.jsonl'), 'a') do |f|
    f.puts JSON.dump({ phase: 'post_mastery', learner_id: learner[:id],
                       condition: learner[:condition], type_key: learner[:type_key].to_s,
                       checks: result[:checks], errors: result[:errors].size,
                       diag: MemoryDiagnostics.detect(result[:updated_memory]),
                       memory: result[:updated_memory] })
  end
  $stderr.puts "[v9b] Mastery #{learner[:id]}: #{result[:errors].size}/#{check_tasks.size} errors"
end

# ---------------------------------------------------------------------------
# PHASE 3: Condition-specific interaction + memory update
# ---------------------------------------------------------------------------
$stderr.puts "[v9b] Phase 3: Condition interactions"

# Ownership data collected per learner
all_ownership_data = {}

# --- lecture_only: no interaction, ownership all zeros ---
by_condition['lecture_only']&.each do |learner|
  all_ownership_data[learner[:id]] = {
    'contribution_count' => 0, 'attempted_answer' => false,
    'received_feedback' => false, 'misconception_exposed' => false,
    'misconception_corrected' => false, 'observed_peer_reasoning_count' => 0,
    'discussion_exposure_count' => 0, 'direct_participation_count' => 0,
    'moderator_feedback_count' => 0, 'ownership_score' => 0
  }
end
$stderr.puts "[v9b] Phase 3: lecture_only — no interaction"

# --- Discussion conditions ---
DISCUSSION_CONDITIONS = %w[
  pair_discussion_size_2
  small_class_discussion_size_4
  medium_class_discussion_size_8
  large_class_discussion_size_16
].freeze

DISCUSSION_CONDITIONS.each do |condition|
  learners = by_condition[condition]
  next unless learners&.any?

  ids      = learners.map { |l| l[:id] }
  type_map = learners.each_with_object({}) { |l, h| h[l[:id]] = l[:type_key] }
  called_on_count = called_on_cfg[condition]&.to_i

  $stderr.puts "[v9b] Phase 3: #{condition} (#{ids.size} learners, #{called_on_count || 'all'} called on)"

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

  # Update memories from discussion transcript
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

    # Compute memory delta (pre-discussion vs post-discussion)
    pre_mem   = pre_discussion_memories[learner[:id]] || {}
    diag_delta = MemoryDiagnostics.delta(pre_mem, updated)

    File.open(File.join(run_dir, 'memories.jsonl'), 'a') do |f|
      f.puts JSON.dump({ phase: 'post_interaction', learner_id: learner[:id],
                         condition: condition, type_key: learner[:type_key].to_s,
                         diag_delta: diag_delta,
                         diag_post: MemoryDiagnostics.detect(updated),
                         memory: updated })
    end

    # Store ownership data with memory delta
    own_data = result['ownership_data'][learner[:id]] || {}
    all_ownership_data[learner[:id]] = own_data.merge(
      'memory_delta_after_discussion' => diag_delta[:acquired]
    )
  end
end

# Save ownership metrics to DB
$stderr.puts "[v9b] Saving ownership metrics (#{all_ownership_data.size} learners)"
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
$stderr.puts "[v9b] Phase 4: Evaluation (#{all_learners.size} × #{eval_tasks.size} tasks)"

eval_tasks.each do |task|
  DB.save_evaluation_task(db, run_id: run_id, task_id: task['id'],
                          task_type: task['type'], prompt: task['prompt'],
                          expected_answer: task['expected_answer'], rubric: rubric)
end

all_learners.each do |learner|
  memory = DB.get_learner_memory(db, run_id: run_id, learner_id: learner[:id])
  eval_tasks.each do |task|
    response = Phases::Solver.run(
      learner_id: learner[:id], memory: memory, task: task,
      solver_prompt: solver_prompt, config: config, tracker: tracker
    )
    attempt_id = DB.save_task_attempt(db, run_id: run_id,
                                      learner_id: learner[:id],
                                      condition: learner[:condition],
                                      task_id: task['id'],
                                      response_text: response[:answer])
    score = Phases::Evaluator.score(
      response: response[:answer], task: task, rubric: rubric,
      evaluator_id: evaluator_id, evaluator_prompt: evaluator_prompt,
      config: config, tracker: tracker
    )
    DB.save_evaluation(db, run_id: run_id, attempt_id: attempt_id,
                       evaluator_id: evaluator_id, score: score)
  end
  $stderr.puts "[v9b] Evaluated #{learner[:id]} (#{learner[:condition]})"
end

# ---------------------------------------------------------------------------
# PHASE 5: Report
# ---------------------------------------------------------------------------
$stderr.puts "[v9b] Phase 5: Generating report"

ownership_rows = DB.all_ownership_metrics_by_condition(db, run_id).values.flatten
mastery_rows   = DB.all_mastery_checks_by_condition(db, run_id)

Report.generate(db, run_id: run_id, output_dir: run_dir,
                run_config: config,
                token_summary: tracker.by_phase,
                experiment_meta: {
                  experiment: 'v9b',
                  ownership_rows: ownership_rows
                })

$stderr.puts "[v9b] Run complete: #{run_dir}"
$stderr.puts "[v9b] Total tokens: #{tracker.total}"
```

- [ ] **Step 3: Verify script has no syntax errors**

```bash
cd /Users/masumi/tmp/Agent-Based-Theory-Testing-2-Sigma-Problem
eval "$(mise activate zsh)"
bundle exec ruby -c experiments/bloom_1n_vs_1on1/scripts/run_experiment_v9b.rb
```

Expected: `Syntax OK`

- [ ] **Step 4: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/scripts/run_experiment_v9b.rb
git commit -m "feat(v9b): add run_experiment_v9b.rb orchestrator with shared lecture"
```

---

## Task 6: Config files

**Files:**
- Create: `config_v9b.yml`
- Create: `config_v9b_smoke.yml`

- [ ] **Step 1: Write the failing test** (structural validation via Ruby load)

```bash
cd /Users/masumi/tmp/Agent-Based-Theory-Testing-2-Sigma-Problem
eval "$(mise activate zsh)"
# This will fail until the files exist
bundle exec ruby -e "require 'yaml'; c = YAML.load_file('config_v9b.yml'); raise unless c.dig('experiment','class_sizes'); puts 'OK'"
```

Expected: FAIL with `No such file or directory`

- [ ] **Step 2: Write config_v9b.yml**

```yaml
# config_v9b.yml
experiment:
  name: "bloom_v9b_classroom_size"
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
  db: "experiments/bloom_1n_vs_1on1/data/experiment_v9b.db"
```

- [ ] **Step 3: Write config_v9b_smoke.yml**

```yaml
# config_v9b_smoke.yml — Smoke test: small n, haiku model
experiment:
  name: "bloom_v9b_smoke"
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
  db: "experiments/bloom_1n_vs_1on1/data/experiment_v9b_smoke.db"
```

- [ ] **Step 4: Verify config loads correctly**

```bash
cd /Users/masumi/tmp/Agent-Based-Theory-Testing-2-Sigma-Problem
eval "$(mise activate zsh)"
bundle exec ruby -e "
  require 'yaml'
  c = YAML.load_file('config_v9b.yml')
  raise 'missing class_sizes' unless c.dig('experiment','class_sizes')
  raise 'missing called_on_counts' unless c.dig('experiment','called_on_counts')
  raise 'missing db path' unless c.dig('paths','db')
  sizes = c.dig('experiment','class_sizes')
  expected = { 'pair_discussion_size_2' => 2, 'small_class_discussion_size_4' => 4,
               'medium_class_discussion_size_8' => 8, 'large_class_discussion_size_16' => 16 }
  raise \"sizes mismatch: #{sizes}\" unless sizes == expected
  puts 'config_v9b.yml OK'
"
bundle exec ruby -e "
  require 'yaml'
  c = YAML.load_file('config_v9b_smoke.yml')
  raise 'missing class_sizes' unless c.dig('experiment','class_sizes')
  total_n = c.dig('experiment','lecture_only_n') +
            c.dig('experiment','class_sizes').values.sum
  puts \"config_v9b_smoke.yml OK (total learners: #{total_n})\"
"
```

Expected:
```
config_v9b.yml OK
config_v9b_smoke.yml OK (total learners: 14)
```

- [ ] **Step 5: Commit**

```bash
git add config_v9b.yml config_v9b_smoke.yml
git commit -m "feat(v9b): add config_v9b.yml and config_v9b_smoke.yml"
```

---

## Task 7: run_tests.sh update + smoke test

**Files:**
- Modify: `experiments/bloom_1n_vs_1on1/tests/run_tests.sh`

- [ ] **Step 1: Add new test files to run_tests.sh**

In `experiments/bloom_1n_vs_1on1/tests/run_tests.sh`, add before the final `echo "All tests passed."` line:

```bash
bundle exec ruby "$EXPERIMENT_DIR/tests/test_db_v9b.rb"
bundle exec ruby "$EXPERIMENT_DIR/tests/test_memory_diagnostics.rb"
bundle exec ruby "$EXPERIMENT_DIR/tests/test_sized_discussion_unit.rb"
bundle exec ruby "$EXPERIMENT_DIR/tests/test_report_v9b.rb"
```

- [ ] **Step 2: Run full test suite to confirm all pass**

```bash
cd /Users/masumi/tmp/Agent-Based-Theory-Testing-2-Sigma-Problem
eval "$(mise activate zsh)"
bash experiments/bloom_1n_vs_1on1/tests/run_tests.sh
```

Expected: All tests passed.

- [ ] **Step 3: Run smoke test**

```bash
cd /Users/masumi/tmp/Agent-Based-Theory-Testing-2-Sigma-Problem
eval "$(mise activate zsh)"
bundle exec ruby experiments/bloom_1n_vs_1on1/scripts/run_experiment_v9b.rb \
  config_v9b_smoke.yml 2>&1 | tee /tmp/v9b_smoke.log
```

- [ ] **Step 4: Verify smoke test output**

```bash
tail -20 /tmp/v9b_smoke.log
```

Must see all of:
- `[v9b] Shared lecture:` (confirms single lecture generated)
- `[v9b] Phase 1b: Memory fork (14 learners)` (confirms forking)
- `[v9b] Phase 3:` for all 4 discussion conditions
- `[v9b] Saving ownership metrics (14 learners)`
- `[v9b] Run complete:`

Must NOT see:
- `Traceback` or `Error`
- `undefined method`

Also verify the report was written:

```bash
# Find the run_id from the log
RUN_ID=$(grep "Starting run" /tmp/v9b_smoke.log | grep -o '[a-f0-9-]\{36\}')
ls experiments/bloom_1n_vs_1on1/data/runs/${RUN_ID}/
```

Expected: `config.json  memories.jsonl  report.md  scores.csv  shared_lecture.json  transcripts.jsonl`

- [ ] **Step 5: Verify report contains v9b sections**

```bash
RUN_ID=$(grep "Starting run" /tmp/v9b_smoke.log | grep -o '[a-f0-9-]\{36\}')
grep -c "Ownership Metrics by Condition" experiments/bloom_1n_vs_1on1/data/runs/${RUN_ID}/report.md
grep -c "Memory Delta by Condition" experiments/bloom_1n_vs_1on1/data/runs/${RUN_ID}/report.md
```

Expected: `1` for each.

- [ ] **Step 6: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/tests/run_tests.sh
git commit -m "test(v9b): smoke test passes — all 5 conditions complete cleanly"
```

---

## Self-Review

### Spec coverage

| Requirement | Task |
|-------------|------|
| 5 conditions (lecture_only + 4 class sizes) | Task 5, 6 |
| ONE shared lecture for all conditions | Task 5 (Phase 1) |
| Memory forking (same transcript → all learners) | Task 5 (Phase 1b) |
| pair(2): all contribute, all receive feedback, shared notes | Task 3 (pair_discussion_size_2 branch) |
| small_4: all contribute, moderator summarizes | Task 3 (called_on_count=nil) |
| medium_8: 4/8 called on, others observe | Task 3 + Task 6 config |
| large_16: 3/16 called on, others observe | Task 3 + Task 6 config |
| contribution_count, attempted_answer, received_feedback per learner | Task 3 (ownership_data) |
| misconception_exposed, misconception_corrected (reserved) | Task 3 (init to false) |
| observed_peer_reasoning_count | Task 3 |
| memory_delta_after_discussion | Task 5 (MemoryDiagnostics.delta) |
| ownership_score (+1 per: contributed/attempted/received_feedback/corrected) | Task 3 |
| discussion_exposure_count, direct_participation_count, moderator_feedback_count | Task 3 |
| DB persistence for ownership metrics | Task 1 |
| Memory diagnostics (6 items) before/after | Task 2 + Task 5 |
| Report: ownership by condition | Task 4 |
| Report: memory delta by condition | Task 4 |
| config_v9b.yml (production) + config_v9b_smoke.yml | Task 6 |
| Smoke test passes | Task 7 |

### Placeholder scan

No TBDs, no TODOs, no "implement later" — every step shows exact code.

### Type consistency

- `ownership_data` in SizedDiscussion returns string-keyed hash (`transform_keys(&:to_s)`) → orchestrator accesses via string keys (`own['contribution_count']`) ✓
- `MemoryDiagnostics.delta` returns `{ acquired:, lost:, stable: }` → orchestrator uses `diag_delta[:acquired]` ✓  
- `DB.save_ownership_metrics` booleans: passed as Ruby bools, converted to 0/1 in method ✓
- `Report.ownership_section` reads from `experiment_meta[:ownership_rows]` → orchestrator passes `ownership_rows:` in meta hash ✓
- `called_on_cfg[condition]&.to_i` handles both nil (all participate) and integer correctly ✓
