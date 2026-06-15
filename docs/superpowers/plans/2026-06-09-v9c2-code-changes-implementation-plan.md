# v9c2 Code Changes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement code changes for checklist items A0, A3 (with A5 moderator rotation folded in), A6, and A8 — producing a `run_experiment_v9c2.rb` orchestrator and supporting library changes that correct the F3/F4/F5b/F5c/F2 methodological findings identified in the v9c addendum.

**Architecture:** A0 modifies `SizedDiscussion.run` to inject learner memory into participant context. A3 restructures the orchestrator to run `n_disc` independent discussion repetitions per condition (population-multiplication design), with one fresh `classroom_teacher` agent per repetition (achieving A5 moderator rotation for free). A6 adds a `SelfReflection` phase replacing the lecture_only zero-interaction block. A8 excludes L6 from the main score and adds an exploratory appendix section in the report. New `DB.all_learning_sessions_by_condition` and `Report.discussion_level_variance_by_condition` support the A3 unit-of-analysis correction.

**Tech Stack:** Ruby, SQLite3 (sqlite3 gem), Minitest, `claude --print` via `LLM.call`, YAML config files. No new gems — uses only existing project dependencies.

---

## Design Decisions & Cost Correction

> **A5 evaluator triplication: DROPPED.**
> `Phases::Evaluator.score` never reaches its LLM branch for v9c2's task set: all `eval_tasks_v8.json` tasks have a string `expected_answer`, so `Scorer.score_attempt` always returns before the `LLM.call` at `lib/phases/evaluator.rb:37`. Triplicating `evaluator_id` would create 3 DB agent records with zero additional LLM calls — a no-op that adds complexity without improving inter-rater reliability. Documented here as an intentional omission; revisit only if A8 later selects Option B (semantic LLM-judge scorer).
>
> Moderator/teacher triplication IS implemented — by creating one fresh `classroom_teacher` agent per repetition group in A3 (see Task 6). This addresses the F5b finding for the role that most plausibly affects discussion quality.

> **COST CORRECTION (A3 population-multiplication design).**
> The checklist estimates "+1.0M tokens for discussion phase × 5, total 1.6–1.8M." This underestimates actual cost. The chosen design creates `class_sizes[condition] × n_disc` total learners per discussion condition. Since memory-fork, readiness-check, and evaluation phases ALL scale with total learner count, every non-lecture phase multiplies by `n_disc`. For `n_disc = 5` and v9c's base token spend (≈ 632k tokens, distributed roughly 50% discussion, 30% memory+readiness, 20% evaluation), the true additional cost is approximately 4–5× the base v9c run. Estimated total: **~2.5–3.2M tokens** for a full v9c2 run. The smoke config (`n_disc = 2`, haiku models) keeps smoke-gate cost under 200k tokens.

---

## File Structure

| Action | File | Responsibility |
|--------|------|----------------|
| Modify | `lib/phases/sized_discussion.rb:29–31` | Add `learner_memories: {}` kwarg; inject into contrib/reply/notes context |
| Modify | `lib/db.rb` (after line 261) | Add `DB.all_learning_sessions_by_condition` |
| Modify | `lib/report.rb:17–28` | Add `sessions_by_condition` fetch for v9c2 in `generate` |
| Modify | `lib/report.rb:50` | Add `sessions_by_condition: {}` kwarg to `build_markdown` |
| Modify | `lib/report.rb:176–190` | Add discussion-level variance block for v9c2 after existing variance block |
| Modify | `lib/report.rb:207–223` | Add v9c2 report sections block |
| Modify | `lib/report.rb:501–505` | Add `l6_excluded_rows` helper and `core_rows` filter for A8 |
| Modify | `lib/report.rb` (after `score_variance_by_condition`) | Add `discussion_level_variance_by_condition` |
| Create | `lib/phases/self_reflection.rb` | Self-study reflection phase for lecture_only learners (A6) |
| Create | `prompts/self_reflection.md` | System prompt for self-reflection phase |
| Create | `scripts/run_experiment_v9c2.rb` | Full v9c2 orchestrator |
| Create | `../../config_v9c2.yml` | Full run config (`n_disc: 5`, all sonnet models) |
| Create | `../../config_v9c2_smoke.yml` | Smoke run config (`n_disc: 2`, haiku, 3 conditions) |
| Create | `tests/test_sized_discussion_memory_injection.rb` | LLM-stubbed test: memory injected into contrib context |
| Create | `tests/test_db_learning_sessions.rb` | Unit test for `all_learning_sessions_by_condition` |
| Create | `tests/test_report_discussion_variance.rb` | Pure-function test for discussion-level variance |
| Create | `tests/test_self_reflection.rb` | LLM-stubbed structural test for `SelfReflection.run` |
| Create | `tests/test_report_v9c2.rb` | Tests for L6 exclusion report section (A8) |
| Modify | `tests/run_tests.sh` | Register all 5 new test files |

---

## Task 1: A0 — Inject learner memory into sized_discussion participant context

**Files:**
- Modify: `lib/phases/sized_discussion.rb:29–31` (signature), `:53–74` (contributions), `:78–95` (pair replies), `:115–125` (shared notes)
- Test: `tests/test_sized_discussion_memory_injection.rb`

- [ ] **Step 1: Write the failing test**

Create `tests/test_sized_discussion_memory_injection.rb`:

```ruby
# ABOUTME: Tests that SizedDiscussion injects learner_memories into participant context
# ABOUTME: Uses LLM stub with callable to capture prompt text for assertion

$LOAD_PATH.unshift File.join(__dir__, '..', 'lib')
require 'minitest/autorun'
require 'phases/sized_discussion'

class TestSizedDiscussionMemoryInjection < Minitest::Test
  CONFIG = { 'models' => { 'teacher' => 'model', 'learner' => 'model' } }.freeze

  SAMPLE_MEMORY = {
    'rules'                    => ['Yellow is always active (7 pts)', 'Red doubles next token'],
    'examples'                 => ['[Red, Yellow] => 14'],
    'edge_cases'               => ['Green inactive at end position'],
    'strategy'                 => ['Check activation before applying modifiers'],
    'corrected_misconceptions' => [],
    'remaining_misconceptions' => [],
    'uncertain_rules'          => []
  }.freeze

  def run_with_capture(learner_memories: {})
    captured_prompts = []
    stub_val = ->(prompt, **_kwargs) { captured_prompts << prompt; 'stub response' }
    LLM.stub(:call, stub_val) do
      Phases::SizedDiscussion.run(
        condition: 'pair_discussion_size_2',
        learner_ids: %w[l1 l2],
        moderator_id: 'mod1',
        moderator_prompt: 'mod sys',
        participant_prompt: 'participant sys',
        lesson: 'lesson text',
        config: CONFIG,
        learner_memories: learner_memories
      )
    end
    captured_prompts
  end

  def test_without_memories_does_not_include_learning_memory_header
    prompts = run_with_capture(learner_memories: {})
    contrib_prompts = prompts.select { |p| p.include?('Contribute your reasoning') }
    refute_empty contrib_prompts
    contrib_prompts.each do |p|
      refute_includes p, 'YOUR LEARNING MEMORY'
    end
  end

  def test_with_memories_injects_learning_memory_into_contrib_prompt
    prompts = run_with_capture(learner_memories: { 'l1' => SAMPLE_MEMORY, 'l2' => SAMPLE_MEMORY })
    contrib_prompts = prompts.select { |p| p.include?('Contribute your reasoning') }
    refute_empty contrib_prompts
    assert contrib_prompts.any? { |p| p.include?('YOUR LEARNING MEMORY') },
           'Expected at least one contribution prompt to include YOUR LEARNING MEMORY'
  end

  def test_memory_content_appears_in_contrib_prompt
    prompts = run_with_capture(learner_memories: { 'l1' => SAMPLE_MEMORY, 'l2' => SAMPLE_MEMORY })
    contrib_prompts = prompts.select { |p| p.include?('Contribute your reasoning') }
    assert contrib_prompts.any? { |p| p.include?('Yellow is always active') },
           'Expected memory rule text to appear in contribution prompt'
  end

  def test_reply_prompt_injects_memory_when_provided
    prompts = run_with_capture(learner_memories: { 'l1' => SAMPLE_MEMORY, 'l2' => SAMPLE_MEMORY })
    reply_prompts = prompts.select { |p| p.include?('Respond to your partner') }
    refute_empty reply_prompts
    assert reply_prompts.any? { |p| p.include?('YOUR LEARNING MEMORY') },
           'Expected reply prompts to include YOUR LEARNING MEMORY'
  end
end
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd /Users/masumi/tmp/Agent-Based-Theory-Testing-2-Sigma-Problem
eval "$(mise activate zsh)"
bundle exec ruby experiments/bloom_1n_vs_1on1/tests/test_sized_discussion_memory_injection.rb
```

Expected: FAIL — `test_with_memories_injects_learning_memory_into_contrib_prompt` fails because the method signature does not yet accept `learner_memories:`.

- [ ] **Step 3: Implement the change in `lib/phases/sized_discussion.rb`**

Add `require 'json'` at line 4 (after the existing requires). Change the method signature and inject memory into all three participant-facing contexts:

```ruby
# At top of file, after line 3 (require_relative '../learner_types')
require 'json'
```

Replace the `run` method signature (line 29–31):
```ruby
def self.run(condition:, learner_ids:, called_on_count: nil,
             moderator_id:, moderator_prompt:, participant_prompt:,
             lesson:, config:, tracker: nil, learner_type_keys: {}, learner_memories: {})
```

Replace the called-on contribution context block (lines 54–57):
```ruby
history  = Helpers.format_turns_for_prompt(turns)
type_key = learner_type_keys[lid]
mem      = learner_memories[lid]
ctx      = mem ? "YOUR LEARNING MEMORY:\n#{JSON.pretty_generate(mem)}\n\nDISCUSSION SO FAR:\n#{history}" \
                : "DISCUSSION SO FAR:\n#{history}"
ctx     += "\n\nYOUR LEARNER TYPE: #{type_key} — respond authentically." if type_key
```

Replace the pair reply context block (lines 80–83):
```ruby
history  = Helpers.format_turns_for_prompt(turns)
type_key = learner_type_keys[lid]
mem      = learner_memories[lid]
ctx      = mem ? "YOUR LEARNING MEMORY:\n#{JSON.pretty_generate(mem)}\n\nPAIR DISCUSSION:\n#{history}" \
                : "PAIR DISCUSSION:\n#{history}"
ctx     += "\n\nYOUR LEARNER TYPE: #{type_key} — respond authentically." if type_key
```

Replace the shared notes context (line 119):
```ruby
context: "PAIR DISCUSSION:\n#{Helpers.format_turns_for_prompt(turns)}",
```
with (no memory injection for shared notes — the notes synthesise the full visible discussion history, which already contains the corrected facts from the moderator closing):
```ruby
context: "PAIR DISCUSSION:\n#{Helpers.format_turns_for_prompt(turns)}",
```
(shared notes context is unchanged — both learners' memories are already reflected in the visible turns, and synthesising notes from a fixed-format transcript needs no personal memory)

- [ ] **Step 4: Run the test to verify it passes**

```bash
bundle exec ruby experiments/bloom_1n_vs_1on1/tests/test_sized_discussion_memory_injection.rb
```

Expected: 4 tests, 0 failures.

- [ ] **Step 5: Run the full existing test suite to verify no regressions**

```bash
bash experiments/bloom_1n_vs_1on1/tests/run_tests.sh
```

Expected: All tests pass. (Existing `test_sized_discussion_unit.rb` tests pure-function helpers unaffected by the new kwarg, which defaults to `{}`.)

- [ ] **Step 6: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/lib/phases/sized_discussion.rb \
        experiments/bloom_1n_vs_1on1/tests/test_sized_discussion_memory_injection.rb
git commit -m "feat(A0): inject learner_memories into SizedDiscussion participant context

Adds learner_memories: {} kwarg to SizedDiscussion.run. When a learner's
memory is provided, it is prepended to the discussion context in the same
JSON.pretty_generate format used by Phases::Solver — correcting F3
(discussion context injection bug) identified in the v9c addendum."
```

---

## Task 2: DB helper for discussion-level session grouping

**Files:**
- Modify: `lib/db.rb` (after `all_memories_by_condition`, around line 261)
- Test: `tests/test_db_learning_sessions.rb`

- [ ] **Step 1: Write the failing test**

Create `tests/test_db_learning_sessions.rb`:

```ruby
# ABOUTME: Tests DB.all_learning_sessions_by_condition — used for discussion-level variance (A3)
# ABOUTME: Sets up an in-memory SQLite DB with fixture data; no LLM calls

$LOAD_PATH.unshift File.join(__dir__, '..', 'lib')
require 'minitest/autorun'
require 'db'

class TestDbLearningSessions < Minitest::Test
  def setup
    @db     = DB.setup(':memory:')
    @run_id = 'run-test-001'
    DB.save_run(@db, @run_id, 'test_run', {})
    @teacher_id = DB.save_agent(@db, run_id: @run_id, role: 'classroom_teacher', model: 'test')
    @l1 = DB.save_agent(@db, run_id: @run_id, role: 'learner', condition: 'pair_discussion_size_2', model: 'test')
    @l2 = DB.save_agent(@db, run_id: @run_id, role: 'learner', condition: 'pair_discussion_size_2', model: 'test')
    @l3 = DB.save_agent(@db, run_id: @run_id, role: 'learner', condition: 'small_class_discussion_size_4', model: 'test')
  end

  def save_session(condition:, learner_id:, transcript: [{ 'speaker' => 'moderator', 'content' => 'hi' }])
    DB.save_learning_session(@db, run_id: @run_id, condition: condition,
                             learner_id: learner_id, teacher_or_tutor_id: @teacher_id,
                             transcript: { 'condition' => condition, 'turns' => transcript })
  end

  def test_groups_sessions_by_condition
    save_session(condition: 'pair_discussion_size_2',      learner_id: @l1)
    save_session(condition: 'pair_discussion_size_2',      learner_id: @l2)
    save_session(condition: 'small_class_discussion_size_4', learner_id: @l3)

    result = DB.all_learning_sessions_by_condition(@db, @run_id)

    assert_includes result.keys, 'pair_discussion_size_2'
    assert_includes result.keys, 'small_class_discussion_size_4'
    assert_equal 2, result['pair_discussion_size_2'].size
    assert_equal 1, result['small_class_discussion_size_4'].size
  end

  def test_rows_have_string_keys
    save_session(condition: 'pair_discussion_size_2', learner_id: @l1)
    result = DB.all_learning_sessions_by_condition(@db, @run_id)
    row    = result['pair_discussion_size_2'].first
    assert row.key?('condition'),      'Expected string key condition'
    assert row.key?('learner_id'),     'Expected string key learner_id'
    assert row.key?('transcript_json'), 'Expected string key transcript_json'
  end

  def test_returns_empty_hash_when_no_sessions
    result = DB.all_learning_sessions_by_condition(@db, @run_id)
    assert_empty result
  end

  def test_filters_by_run_id
    other_run = 'run-other-999'
    DB.save_run(@db, other_run, 'other', {})
    other_teacher = DB.save_agent(@db, run_id: other_run, role: 'classroom_teacher', model: 'test')
    other_learner = DB.save_agent(@db, run_id: other_run, role: 'learner', condition: 'pair_discussion_size_2', model: 'test')
    DB.save_learning_session(@db, run_id: other_run, condition: 'pair_discussion_size_2',
                             learner_id: other_learner, teacher_or_tutor_id: other_teacher,
                             transcript: { 'turns' => [] })

    result = DB.all_learning_sessions_by_condition(@db, @run_id)
    assert_empty result
  end
end
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
bundle exec ruby experiments/bloom_1n_vs_1on1/tests/test_db_learning_sessions.rb
```

Expected: FAIL — `undefined method 'all_learning_sessions_by_condition' for DB:Module`.

- [ ] **Step 3: Implement `DB.all_learning_sessions_by_condition` in `lib/db.rb`**

Add after the closing `end` of `all_memories_by_condition` (after line 241):

```ruby
def self.all_learning_sessions_by_condition(db, run_id)
  rows = db.execute(
    'SELECT condition, learner_id, transcript_json FROM learning_sessions WHERE run_id = ? ORDER BY condition, learner_id',
    [run_id]
  )
  rows.group_by { |r| r['condition'] }
end
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
bundle exec ruby experiments/bloom_1n_vs_1on1/tests/test_db_learning_sessions.rb
```

Expected: 4 tests, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/lib/db.rb \
        experiments/bloom_1n_vs_1on1/tests/test_db_learning_sessions.rb
git commit -m "feat(A3): add DB.all_learning_sessions_by_condition for discussion-level grouping"
```

---

## Task 3: Report — discussion-level variance (A3) and v9c2 sections

**Files:**
- Modify: `lib/report.rb` — `generate`, `build_markdown`, add `discussion_level_variance_by_condition`
- Test: `tests/test_report_discussion_variance.rb`

- [ ] **Step 1: Write the failing tests**

Create `tests/test_report_discussion_variance.rb`:

```ruby
# ABOUTME: Tests Report.discussion_level_variance_by_condition — discussion as unit of analysis
# ABOUTME: Pure function tests using fixture rows; no DB or LLM calls

$LOAD_PATH.unshift File.join(__dir__, '..', 'lib')
require 'minitest/autorun'
require 'digest'
require 'json'
require 'report'

class TestDiscussionLevelVariance < Minitest::Test
  # Fixtures: 2 independent discussion sessions (different transcript_json) for pair condition.
  # Session A: l1 scores 1.0, l2 scores 1.0  => discussion mean = 1.0
  # Session B: l3 scores 0.0, l4 scores 0.0  => discussion mean = 0.0
  # Expected SD across two discussion means = 0.707

  def score_row(learner_id:, condition:, answer_correct:, transcript_json:)
    {
      'learner_id'   => learner_id,
      'condition'    => condition,
      'answer_correct' => answer_correct,
      'task_id'      => 'l1_calc_01',
      'score_json'   => JSON.dump({ 'answer_correct' => answer_correct })
    }
  end

  def session_row(learner_id:, condition:, transcript_json:)
    {
      'learner_id'    => learner_id,
      'condition'     => condition,
      'transcript_json' => transcript_json
    }
  end

  def setup
    @t_a = JSON.dump({ 'turns' => [{ 'speaker' => 'mod', 'content' => 'session_a' }] })
    @t_b = JSON.dump({ 'turns' => [{ 'speaker' => 'mod', 'content' => 'session_b' }] })

    @rows = [
      score_row(learner_id: 'l1', condition: 'pair_discussion_size_2', answer_correct: true),
      score_row(learner_id: 'l2', condition: 'pair_discussion_size_2', answer_correct: true),
      score_row(learner_id: 'l3', condition: 'pair_discussion_size_2', answer_correct: false),
      score_row(learner_id: 'l4', condition: 'pair_discussion_size_2', answer_correct: false)
    ]

    # sessions_by_condition: l1+l2 share transcript A, l3+l4 share transcript B
    @sessions = {
      'pair_discussion_size_2' => [
        session_row(learner_id: 'l1', condition: 'pair_discussion_size_2', transcript_json: @t_a),
        session_row(learner_id: 'l2', condition: 'pair_discussion_size_2', transcript_json: @t_a),
        session_row(learner_id: 'l3', condition: 'pair_discussion_size_2', transcript_json: @t_b),
        session_row(learner_id: 'l4', condition: 'pair_discussion_size_2', transcript_json: @t_b)
      ]
    }
  end

  def test_returns_hash_keyed_by_condition
    result = Report.send(:discussion_level_variance_by_condition, @rows, @sessions)
    assert_includes result.keys, 'pair_discussion_size_2'
  end

  def test_detects_two_independent_discussions
    result = Report.send(:discussion_level_variance_by_condition, @rows, @sessions)
    assert_equal 2, result['pair_discussion_size_2'][:n]
  end

  def test_sd_across_two_discussion_means
    result = Report.send(:discussion_level_variance_by_condition, @rows, @sessions)
    # mean_A=1.0, mean_B=0.0; sample SD = sqrt(((1-0.5)^2 + (0-0.5)^2)/1) = 0.707
    assert_in_delta 0.707, result['pair_discussion_size_2'][:sd], 0.001
  end

  def test_returns_zero_sd_for_single_discussion
    single_sessions = {
      'pair_discussion_size_2' => [
        session_row(learner_id: 'l1', condition: 'pair_discussion_size_2', transcript_json: @t_a),
        session_row(learner_id: 'l2', condition: 'pair_discussion_size_2', transcript_json: @t_a)
      ]
    }
    single_rows = [
      score_row(learner_id: 'l1', condition: 'pair_discussion_size_2', answer_correct: true),
      score_row(learner_id: 'l2', condition: 'pair_discussion_size_2', answer_correct: false)
    ]
    result = Report.send(:discussion_level_variance_by_condition, single_rows, single_sessions)
    assert_equal 0.0, result['pair_discussion_size_2'][:sd]
    assert_equal 1,   result['pair_discussion_size_2'][:n]
  end
end
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
bundle exec ruby experiments/bloom_1n_vs_1on1/tests/test_report_discussion_variance.rb
```

Expected: FAIL — `undefined method 'discussion_level_variance_by_condition'`.

- [ ] **Step 3: Add `require 'digest'` to `lib/report.rb`**

At the top of `lib/report.rb`, add after the existing requires (after line 7, `require 'fileutils'`):

```ruby
require 'digest'
```

- [ ] **Step 4: Add `discussion_level_variance_by_condition` to `lib/report.rb`**

Add after the closing `end` of `score_variance_by_condition` (after line 533):

```ruby
def self.discussion_level_variance_by_condition(rows, sessions_by_condition)
  by_condition = rows.group_by { |r| r['condition'] }
  sessions_by_condition.transform_values do |session_rows|
    cond       = session_rows.first['condition']
    cond_rows  = by_condition[cond] || []
    by_learner = cond_rows.group_by { |r| r['learner_id'] }

    groups = session_rows.group_by { |s| Digest::MD5.hexdigest(s['transcript_json']) }
    means  = groups.values.map do |group_sessions|
      learner_ids = group_sessions.map { |s| s['learner_id'] }.uniq
      scores      = learner_ids.map { |lid| avg_correctness(by_learner[lid] || []) }
      scores.empty? ? 0.0 : scores.sum / scores.size
    end

    next({ n: means.size, sd: 0.0 }) if means.size < 2
    mean     = means.sum / means.size
    variance = means.sum { |m| (m - mean)**2 } / (means.size - 1)
    { n: means.size, sd: Math.sqrt(variance).round(3) }
  end
end
```

- [ ] **Step 5: Update `Report.generate` to fetch `sessions_by_condition` for v9c2**

In `lib/report.rb`, in the `generate` method (around line 22), update the `mastery_rows` line and add `sessions_by_condition` fetch:

Replace:
```ruby
mastery_rows          = %w[v8 v9b v9c].include?(experiment_meta[:experiment]) ?
                          DB.all_mastery_checks_by_condition(db, run_id) : []
write_csv(rows, output_dir)
markdown = build_markdown(rows, run_id: run_id, output_dir: output_dir,
                          run_config: run_config, token_summary: token_summary,
                          memories_by_condition: memories_by_condition,
                          experiment_meta: experiment_meta,
                          mastery_rows: mastery_rows)
```

With:
```ruby
mastery_rows          = %w[v8 v9b v9c v9c2].include?(experiment_meta[:experiment]) ?
                          DB.all_mastery_checks_by_condition(db, run_id) : []
sessions_by_condition = experiment_meta[:experiment] == 'v9c2' ?
                          DB.all_learning_sessions_by_condition(db, run_id) : {}
write_csv(rows, output_dir)
markdown = build_markdown(rows, run_id: run_id, output_dir: output_dir,
                          run_config: run_config, token_summary: token_summary,
                          memories_by_condition: memories_by_condition,
                          experiment_meta: experiment_meta,
                          mastery_rows: mastery_rows,
                          sessions_by_condition: sessions_by_condition)
```

- [ ] **Step 6: Update `build_markdown` signature and add discussion-level variance block**

In `lib/report.rb`, update the `build_markdown` signature (line 50) to add `sessions_by_condition: {}`:

```ruby
def self.build_markdown(rows, run_id:, output_dir:, run_config:, token_summary:,
                        memories_by_condition: {}, experiment_meta: {}, mastery_rows: [],
                        sessions_by_condition: {})
```

After the existing "Variance by condition" block (after the `lines << ""` that closes it, around line 185), add:

```ruby
if experiment_meta[:experiment] == 'v9c2'
  disc_var = discussion_level_variance_by_condition(rows, sessions_by_condition)
  lines << "## Score Variance by Condition (discussion-level unit of analysis)"
  lines << ""
  lines << "> Each SD is computed across N independent discussion instances — the correct"
  lines << "> unit of analysis for comparing discussion designs (corrects F4 pseudoreplication)."
  lines << "> Learners are nested observations within each discussion instance."
  lines << ""
  lines << "| Condition | N (independent discussions) | SD (discussion-level) |"
  lines << "|-----------|------------------------------|----------------------|"
  disc_var.sort.each do |cond, stats|
    lines << "| #{cond} | #{stats[:n]} | #{stats[:sd]} |"
  end
  lines << ""
end
```

Also add the v9c2 report sections block after the v9c block (around line 223). After the closing `end` of the v9c block:

```ruby
if experiment_meta[:experiment] == 'v9c2'
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

- [ ] **Step 7: Run the failing test to verify it now passes**

```bash
bundle exec ruby experiments/bloom_1n_vs_1on1/tests/test_report_discussion_variance.rb
```

Expected: 4 tests, 0 failures.

- [ ] **Step 8: Run the full test suite**

```bash
bash experiments/bloom_1n_vs_1on1/tests/run_tests.sh
```

Expected: All tests pass. The existing `test_report_v9c.rb` tests should still pass since the new kwarg defaults to `{}` and the new blocks are gated on `experiment_meta[:experiment] == 'v9c2'`.

- [ ] **Step 9: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/lib/report.rb \
        experiments/bloom_1n_vs_1on1/tests/test_report_discussion_variance.rb
git commit -m "feat(A3): add discussion-level variance to report for v9c2

Adds DB.all_learning_sessions_by_condition query, Report.discussion_level_
variance_by_condition pure function, and v9c2-specific report blocks.
Corrects F4 pseudoreplication by using independent discussion instances
as the unit of analysis instead of individual learner scores."
```

---

## Task 4: A6 — Self-reflection phase for lecture_only learners

**Files:**
- Create: `lib/phases/self_reflection.rb`
- Create: `prompts/self_reflection.md`
- Test: `tests/test_self_reflection.rb`

- [ ] **Step 1: Write the failing test**

Create `tests/test_self_reflection.rb`:

```ruby
# ABOUTME: Tests for SelfReflection phase — structural tests using LLM stub
# ABOUTME: Verifies turn structure, condition field, and memory injection into prompt

$LOAD_PATH.unshift File.join(__dir__, '..', 'lib')
require 'minitest/autorun'
require 'phases/self_reflection'

class TestSelfReflection < Minitest::Test
  CONFIG = { 'models' => { 'learner' => 'model' } }.freeze

  SAMPLE_MEMORY = {
    'rules'                    => ['Yellow is always active'],
    'examples'                 => [],
    'edge_cases'               => [],
    'strategy'                 => [],
    'corrected_misconceptions' => [],
    'remaining_misconceptions' => [],
    'uncertain_rules'          => []
  }.freeze

  def run_with_capture(memory: SAMPLE_MEMORY, learner_type_key: nil)
    captured = []
    LLM.stub(:call, ->(prompt, **_kwargs) { captured << prompt; 'stub reflection' }) do
      result = Phases::SelfReflection.run(
        learner_id: 'l-001',
        memory: memory,
        reflection_prompt: 'reflect sys',
        lesson: 'lesson text',
        config: CONFIG,
        learner_type_key: learner_type_key
      )
      [result, captured]
    end
  end

  def test_condition_is_lecture_only
    result, _ = run_with_capture
    assert_equal 'lecture_only', result['condition']
  end

  def test_has_one_reflection_note_turn
    result, _ = run_with_capture
    assert_equal 1, result['turns'].size
    assert_equal 'reflection_note', result['turns'].first['type']
  end

  def test_turn_speaker_is_learner_id
    result, _ = run_with_capture
    assert_equal 'l-001', result['turns'].first['speaker']
  end

  def test_memory_content_injected_into_prompt
    _, captured = run_with_capture(memory: SAMPLE_MEMORY)
    assert captured.any? { |p| p.include?('YOUR LEARNING MEMORY') },
           'Expected YOUR LEARNING MEMORY in prompt'
    assert captured.any? { |p| p.include?('Yellow is always active') },
           'Expected memory rule content in prompt'
  end

  def test_learner_type_injected_when_provided
    _, captured = run_with_capture(memory: SAMPLE_MEMORY, learner_type_key: 'rule_extractor')
    assert captured.any? { |p| p.include?('rule_extractor') },
           'Expected learner_type_key in prompt when provided'
  end

  def test_discussion_problem_included_in_instruction
    _, captured = run_with_capture
    assert captured.any? { |p| p.include?('Red, Green, Blue, Yellow') },
           'Expected DISCUSSION_PROBLEM in instruction'
  end
end
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
bundle exec ruby experiments/bloom_1n_vs_1on1/tests/test_self_reflection.rb
```

Expected: FAIL — `cannot load such file -- phases/self_reflection`.

- [ ] **Step 3: Create `prompts/self_reflection.md`**

```markdown
You are a learner working through a problem independently, using only your learning memory.

Your role:
- Apply the rules from your memory to the problem step by step
- Show your token-by-token calculation
- Acknowledge if you are uncertain about any rule
- Write as private study notes — no audience, just your own reasoning

Tone: reflective, honest about uncertainty, brief and direct.

Do not just state the answer. Walk through each token in sequence.
```

- [ ] **Step 4: Create `lib/phases/self_reflection.rb`**

```ruby
# ABOUTME: Self-study reflection phase for lecture_only learners (A6 fix)
# ABOUTME: Mirrors token budget of discussion phase; learner works alone with their memory

require 'json'
require_relative '../llm'
require_relative '../helpers'
require_relative 'sized_discussion'

module Phases
  module SelfReflection
    def self.run(learner_id:, memory:, reflection_prompt:, lesson:, config:,
                 tracker: nil, learner_type_key: nil)
      learner_model = config.dig('models', 'learner') || 'claude-sonnet-4-6'
      memory_text   = JSON.pretty_generate(memory)

      ctx  = "YOUR LEARNING MEMORY:\n#{memory_text}"
      ctx += "\n\nYOUR LEARNER TYPE: #{learner_type_key} — respond authentically." if learner_type_key

      prompt = Helpers.build_prompt(
        system:      reflection_prompt,
        context:     ctx,
        instruction: "Write your reasoning note for the problem below. Show your step-by-step " \
                     "thinking, identify which tokens are active and why, and note any rules " \
                     "that are easy to get wrong. Under 120 words.\n\n" \
                     "#{Phases::SizedDiscussion::DISCUSSION_PROBLEM}"
      )

      note  = LLM.call(prompt, model: learner_model, tracker: tracker, phase: 'education_lecture_only')
      turns = [{ 'speaker' => learner_id, 'type' => 'reflection_note', 'content' => note }]

      $stderr.puts "[self_reflection:#{learner_id}] Reflection note produced"

      {
        'condition'  => 'lecture_only',
        'turns'      => turns,
        'learner_id' => learner_id
      }
    end
  end
end
```

- [ ] **Step 5: Run the test to verify it passes**

```bash
bundle exec ruby experiments/bloom_1n_vs_1on1/tests/test_self_reflection.rb
```

Expected: 6 tests, 0 failures.

- [ ] **Step 6: Run the full test suite**

```bash
bash experiments/bloom_1n_vs_1on1/tests/run_tests.sh
```

Expected: All tests pass.

- [ ] **Step 7: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/lib/phases/self_reflection.rb \
        experiments/bloom_1n_vs_1on1/prompts/self_reflection.md \
        experiments/bloom_1n_vs_1on1/tests/test_self_reflection.rb
git commit -m "feat(A6): add SelfReflection phase for lecture_only learners

Replaces zero-interaction lecture_only block with a memory-grounded
individual reasoning phase. Gives lecture_only learners a comparable
token budget and memory-update cycle to discussion conditions, correcting
F5c (learning time asymmetry) identified in the v9c addendum."
```

---

## Task 5: A8 — Exclude L6 from main score; add exploratory appendix

**Files:**
- Modify: `lib/report.rb` — `build_markdown`, add `l6_rows_section` private method
- Test: `tests/test_report_v9c2.rb`

- [ ] **Step 1: Write the failing test**

Create `tests/test_report_v9c2.rb`:

```ruby
# ABOUTME: Tests for v9c2-specific report sections: L6 exclusion appendix (A8)
# ABOUTME: Pure function tests — no LLM or DB calls

$LOAD_PATH.unshift File.join(__dir__, '..', 'lib')
require 'minitest/autorun'
require 'json'
require 'report'

class TestL6ExclusionSection < Minitest::Test
  def make_row(task_id:, answer_correct:, condition: 'pair_discussion_size_2')
    {
      'learner_id'     => 'l-001',
      'condition'      => condition,
      'task_id'        => task_id,
      'task_type'      => 'calculation',
      'answer_correct' => answer_correct,
      'score_json'     => JSON.dump({ 'answer_correct' => answer_correct, 'total' => answer_correct ? 1 : 0 })
    }
  end

  def all_rows
    [
      make_row(task_id: 'l1_calc_01', answer_correct: true),
      make_row(task_id: 'l3_calc_03', answer_correct: true),
      make_row(task_id: 'l6_induction_02', answer_correct: false)
    ]
  end

  def test_l6_rows_section_contains_l6_task_id
    section = Report.send(:l6_rows_section, all_rows)
    assert_includes section, 'l6_induction_02'
  end

  def test_l6_rows_section_includes_exploratory_disclaimer
    section = Report.send(:l6_rows_section, all_rows)
    assert_includes section, 'exploratory'
  end

  def test_l6_rows_section_explains_scorer_artifact
    section = Report.send(:l6_rows_section, all_rows)
    assert_includes section, 'scorer'
  end

  def test_core_rows_excludes_l6
    core = Report.send(:core_rows, all_rows)
    task_ids = core.map { |r| r['task_id'] }
    refute_includes task_ids, 'l6_induction_02'
    assert_includes task_ids, 'l1_calc_01'
    assert_includes task_ids, 'l3_calc_03'
  end

  def test_core_rows_returns_all_rows_when_no_l6
    rows = [
      make_row(task_id: 'l1_calc_01', answer_correct: true),
      make_row(task_id: 'l4_calc_04', answer_correct: false)
    ]
    assert_equal rows, Report.send(:core_rows, rows)
  end
end
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
bundle exec ruby experiments/bloom_1n_vs_1on1/tests/test_report_v9c2.rb
```

Expected: FAIL — `undefined method 'l6_rows_section'` and `undefined method 'core_rows'`.

- [ ] **Step 3: Add `core_rows` and `l6_rows_section` to `lib/report.rb`**

Add after `extract_difficulty` (after line 499):

```ruby
def self.core_rows(rows)
  rows.reject { |r| extract_difficulty(r['task_id']) == 'L6' }
end

def self.l6_rows_section(rows)
  l6 = rows.select { |r| extract_difficulty(r['task_id']) == 'L6' }
  lines = []
  lines << "## L6 (short_rule_induction) — Exploratory Appendix"
  lines << ""
  lines << "> L6 is excluded from the main score. The exact-match scorer cannot reliably"
  lines << "> grade free-text rule induction (F2: scorer artifact confirmed across v8/v9b/v9c)."
  lines << "> These results are exploratory only — do not use them for condition comparisons."
  lines << ""
  if l6.empty?
    lines << "_No L6 attempts found for this run._"
    lines << ""
    return lines.join("\n")
  end

  by_condition = l6.group_by { |r| r['condition'] }
  lines << "| Condition | L6 Attempts | Correct (exact-match) | Note |"
  lines << "|-----------|-------------|----------------------|------|"
  by_condition.sort.each do |cond, cond_rows|
    total   = cond_rows.size
    correct = cond_rows.count { |r| r['answer_correct'] == true || r['answer_correct'] == 1 }
    lines << "| #{cond} | #{total} | #{correct} | exact-match only — likely undercount |"
  end
  lines << ""
  lines.join("\n")
end
```

- [ ] **Step 4: Hook `core_rows` into `build_markdown` for v9c2 score aggregation**

In `build_markdown`, after the opening lines (after `by_condition = rows.group_by...`), add a v9c2-specific rows alias:

Find (around line 54 of `build_markdown`):
```ruby
by_condition  = rows.group_by { |r| r['condition'] }
ceiling_data  = detect_ceiling(rows, run_config)
token_data    = build_token_data(token_summary, by_condition)
```

Replace with:
```ruby
scored_rows   = experiment_meta[:experiment] == 'v9c2' ? core_rows(rows) : rows
by_condition  = scored_rows.group_by { |r| r['condition'] }
ceiling_data  = detect_ceiling(scored_rows, run_config)
token_data    = build_token_data(token_summary, by_condition)
```

And replace all subsequent uses of `rows` with `scored_rows` for scoring aggregations inside `build_markdown`, while keeping `rows` (the full set) for the L6 appendix section. Add the L6 appendix section at the end of the v9c2-specific block:

```ruby
if experiment_meta[:experiment] == 'v9c2'
  # ... (existing v9c2 sections from Task 3)
  lines << l6_rows_section(rows)
end
```

> **Note for implementer:** The substitution of `rows → scored_rows` inside `build_markdown` applies to all score-aggregation helper calls within that method (e.g., `score_variance_by_condition(scored_rows)`, `token_per_correct_answer(scored_rows, ...)`, `avg_correctness` calls). The `rows` variable (full set including L6) is only passed to `l6_rows_section`. Existing tests for v8/v9b/v9c experiments are unaffected because their `scored_rows` equals `rows` (the `core_rows` guard is gated on `v9c2`).

- [ ] **Step 5: Run the failing test to verify it passes**

```bash
bundle exec ruby experiments/bloom_1n_vs_1on1/tests/test_report_v9c2.rb
```

Expected: 5 tests, 0 failures.

- [ ] **Step 6: Run the full test suite**

```bash
bash experiments/bloom_1n_vs_1on1/tests/run_tests.sh
```

Expected: All tests pass.

- [ ] **Step 7: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/lib/report.rb \
        experiments/bloom_1n_vs_1on1/tests/test_report_v9c2.rb
git commit -m "feat(A8): exclude L6 from main score; add exploratory appendix section

Adds core_rows (L6-excluded) for main score aggregation in v9c2 and
l6_rows_section for the exploratory appendix. Corrects F2 (scorer
artifact for free-text rule induction) without altering v8/v9b/v9c
report behavior."
```

---

## Task 6: Register new test files in run_tests.sh

**Files:**
- Modify: `tests/run_tests.sh`

- [ ] **Step 1: Add new test files to `tests/run_tests.sh`**

After the existing last line (`bundle exec ruby "$EXPERIMENT_DIR/tests/test_report_v9c.rb"`), add:

```bash
bundle exec ruby "$EXPERIMENT_DIR/tests/test_sized_discussion_memory_injection.rb"
bundle exec ruby "$EXPERIMENT_DIR/tests/test_db_learning_sessions.rb"
bundle exec ruby "$EXPERIMENT_DIR/tests/test_report_discussion_variance.rb"
bundle exec ruby "$EXPERIMENT_DIR/tests/test_self_reflection.rb"
bundle exec ruby "$EXPERIMENT_DIR/tests/test_report_v9c2.rb"
```

- [ ] **Step 2: Run the full suite to verify all 5 new files are picked up**

```bash
bash experiments/bloom_1n_vs_1on1/tests/run_tests.sh
```

Expected: All tests pass, output ends with `All tests passed.`

- [ ] **Step 3: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/tests/run_tests.sh
git commit -m "test(v9c2): register v9c2 test files in test runner"
```

---

## Task 7: Create v9c2 orchestrator script

**Files:**
- Create: `scripts/run_experiment_v9c2.rb`

Note: No dedicated unit test for this script — consistent with the existing pattern (no `test_run_experiment_v9c.rb` exists). Integration-level validation is the smoke run, per the checklist's A0+A3 smoke gate.

- [ ] **Step 1: Create `scripts/run_experiment_v9c2.rb`**

```ruby
# ABOUTME: Orchestrator for v9c2 — corrects F3/F4/F5b/F5c/F2 findings from v9c addendum
# ABOUTME: Fixed lecture → readiness gate → N_disc independent discussions → reflection (lecture_only) → evaluation → report

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
require 'phases/self_reflection'
require 'phases/memory'
require 'phases/solver'
require 'phases/evaluator'
require 'report'

config_path  = ARGV[0] or abort "Usage: #{$0} <config.yml>"
PROJECT_ROOT = File.expand_path('../..', EXPERIMENT_DIR)
config       = YAML.load_file(File.join(PROJECT_ROOT, config_path))

run_id       = SecureRandom.uuid
run_name     = config.dig('experiment', 'name') || 'bloom_v9c2'
domain_path  = File.join(PROJECT_ROOT, config.dig('paths', 'domain'))
prompts_path = File.join(PROJECT_ROOT, config.dig('paths', 'prompts'))
output_base  = File.join(PROJECT_ROOT, config.dig('paths', 'output'))
db_path      = File.join(PROJECT_ROOT, config.dig('paths', 'db'))
run_dir      = File.join(output_base, 'runs', run_id)

FileUtils.mkdir_p(run_dir)
$stderr.puts "[v9c2] Starting run #{run_id}"

tracker = TokenTracker.new

fixed_lecture_file = config.dig('experiment', 'fixed_lecture_file') || 'fixed_lecture_v9c.md'
fixed_lecture_text = File.read(File.join(domain_path, fixed_lecture_file))

tasks_file         = config.dig('experiment', 'eval_tasks_file')      || 'eval_tasks_v8.json'
readiness_file     = config.dig('experiment', 'readiness_tasks_file') || 'readiness_check_tasks_v9c.json'
eval_tasks         = JSON.parse(Helpers.load_file(File.join(domain_path, tasks_file)))
readiness_tasks    = JSON.parse(Helpers.load_file(File.join(domain_path, readiness_file)))
rubric             = JSON.parse(Helpers.load_file(File.join(domain_path, 'rubric.json')))

summarizer_prompt  = Helpers.load_file(File.join(prompts_path, 'memory_summarizer.md'))
moderator_prompt   = Helpers.load_file(File.join(prompts_path, 'discussion_moderator.md'))
participant_prompt = Helpers.load_file(File.join(prompts_path, 'discussion_participant.md'))
reflection_prompt  = Helpers.load_file(File.join(prompts_path, 'self_reflection.md'))
solver_prompt      = Helpers.load_file(File.join(prompts_path, 'problem_solver.md'))
evaluator_prompt   = Helpers.load_file(File.join(prompts_path, 'blind_evaluator.md'))

db = DB.setup(db_path)
DB.save_run(db, run_id, run_name, config)
File.write(File.join(run_dir, 'config.json'), JSON.pretty_generate(config))

type_keys      = (config.dig('experiment', 'learner_types') || []).map(&:to_sym)
type_keys      = LearnerTypes::HETEROGENEOUS_ASSIGNMENT if type_keys.empty?
class_sizes    = config.dig('experiment', 'class_sizes') || {}
lecture_only_n = config.dig('experiment', 'lecture_only_n') || 4
called_on_cfg  = config.dig('experiment', 'called_on_counts') || {}
n_disc         = config.dig('experiment', 'n_disc') || 5

V9C2_CONDITIONS = %w[
  lecture_only
  pair_discussion_size_2
  small_class_discussion_size_4
  medium_class_discussion_size_8
  large_class_discussion_size_16
].freeze

V9C2_DISCUSSION_CONDITIONS = %w[
  pair_discussion_size_2
  small_class_discussion_size_4
  medium_class_discussion_size_8
  large_class_discussion_size_16
].freeze

# Single evaluator — triplication is a no-op since all eval_tasks_v8 tasks use
# auto-scoring via Scorer.score_attempt (string expected_answer path).
evaluator_id = DB.save_agent(db, run_id: run_id, role: 'evaluator',
                              model: config.dig('models', 'evaluator'))

# A3: For discussion conditions, create base_size * n_disc learners so each of
# the N_disc independent repetitions gets a fresh group of base_size learners.
all_learners = V9C2_CONDITIONS.flat_map do |condition|
  base_n = condition == 'lecture_only' ? lecture_only_n : (class_sizes[condition] || 4)
  total  = condition == 'lecture_only' ? base_n         : base_n * n_disc
  total.times.map do |i|
    type_key   = type_keys[i % type_keys.size]
    learner_id = DB.save_agent(db, run_id: run_id, role: 'learner', condition: condition,
                               model: config.dig('models', 'learner'),
                               profile: { 'type_key' => type_key.to_s })
    { id: learner_id, condition: condition, type_key: type_key }
  end
end

by_condition = all_learners.group_by { |l| l[:condition] }
$stderr.puts "[v9c2] Learner distribution: #{by_condition.transform_values(&:size)}"

# ---------------------------------------------------------------------------
# PHASE 1: Load fixed lecture
# ---------------------------------------------------------------------------
$stderr.puts "[v9c2] Phase 1: Loading fixed lecture (#{fixed_lecture_text.length} chars)"

shared_transcript = {
  'condition'   => 'prerequisite_lecture',
  'learner_ids' => all_learners.map { |l| l[:id] },
  'turns'       => [{ 'speaker' => 'teacher', 'type' => 'lecture', 'content' => fixed_lecture_text }],
  'lecture'     => fixed_lecture_text
}
File.write(File.join(run_dir, 'shared_lecture.json'), JSON.pretty_generate(shared_transcript))

# ---------------------------------------------------------------------------
# PHASE 1b: Memory fork — all learners generate memory from fixed lecture
# ---------------------------------------------------------------------------
$stderr.puts "[v9c2] Phase 1b: Memory fork (#{all_learners.size} learners)"

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
# PHASE 2: Readiness check — with corrective notes; compute pass rate
# ---------------------------------------------------------------------------
$stderr.puts "[v9c2] Phase 2: Readiness checks (#{all_learners.size} × #{readiness_tasks.size})"

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
  $stderr.puts "[v9c2] Readiness #{learner[:id]}: #{result[:errors].size}/#{readiness_tasks.size} errors"
end

readiness_pass_rate = readiness_total > 0 ? readiness_correct.to_f / readiness_total : 0.0
readiness_failed    = readiness_pass_rate < 0.80

$stderr.puts "[v9c2] Readiness pass rate: #{(readiness_pass_rate * 100).round}% — #{readiness_failed ? 'FAILED' : 'OK'}"

pre_snap_by_id = pre_discussion_snapshots.each_with_object({}) { |s, h| h[s['learner_id']] = s['memory'] }

# ---------------------------------------------------------------------------
# PHASE 3: Condition-specific interactions
# ---------------------------------------------------------------------------
$stderr.puts "[v9c2] Phase 3: Condition interactions"

all_ownership_data = {}

# A6: lecture_only — self-reflection phase (replaces zero-interaction block)
# teacher_or_tutor_id is set to learner[:id] since there is no teacher in self-reflection
# and the column is NOT NULL.
by_condition['lecture_only']&.each do |learner|
  memory = pre_snap_by_id[learner[:id]] || DB.get_learner_memory(db, run_id: run_id, learner_id: learner[:id])
  result = Phases::SelfReflection.run(
    learner_id: learner[:id], memory: memory,
    reflection_prompt: reflection_prompt, lesson: fixed_lecture_text,
    config: config, tracker: tracker, learner_type_key: learner[:type_key]
  )

  DB.save_learning_session(db, run_id: run_id, condition: 'lecture_only',
                           learner_id: learner[:id], teacher_or_tutor_id: learner[:id],
                           transcript: result)

  updated   = Phases::Memory.update(
    learner_id: learner[:id], existing_memory: memory,
    update_transcript: result['turns'],
    summarizer_prompt: summarizer_prompt, config: config, tracker: tracker,
    learner_type_key: learner[:type_key]
  )
  DB.save_learner_memory(db, run_id: run_id, learner_id: learner[:id],
                         condition: 'lecture_only', memory: updated)

  diag_delta = MemoryDiagnostics.delta(memory, updated)

  File.open(File.join(run_dir, 'memories.jsonl'), 'a') do |f|
    f.puts JSON.dump({ phase: 'post_interaction', learner_id: learner[:id],
                       condition: 'lecture_only', type_key: learner[:type_key].to_s,
                       diag_delta: diag_delta,
                       diag_post: MemoryDiagnostics.detect(updated),
                       memory: updated })
  end

  all_ownership_data[learner[:id]] = {
    'contribution_count' => 1, 'attempted_answer' => true,
    'received_feedback' => false, 'misconception_exposed' => false,
    'misconception_corrected' => false, 'observed_peer_reasoning_count' => 0,
    'discussion_exposure_count' => 1, 'direct_participation_count' => 1,
    'moderator_feedback_count' => 0, 'ownership_score' => 2,
    'memory_delta_after_discussion' => diag_delta[:acquired]
  }
end
$stderr.puts "[v9c2] Phase 3: lecture_only — self-reflection complete"

# A3+A5: discussion conditions — N_disc independent repetitions, fresh teacher per group
V9C2_DISCUSSION_CONDITIONS.each do |condition|
  learners  = by_condition[condition]
  next unless learners&.any?

  base_size       = class_sizes[condition] || 4
  called_on_count = called_on_cfg[condition]&.to_i
  groups          = learners.each_slice(base_size).to_a

  $stderr.puts "[v9c2] Phase 3: #{condition} — #{groups.size} independent repetitions of #{base_size} learners"

  groups.each_with_index do |group, rep_idx|
    ids      = group.map { |l| l[:id] }
    type_map = group.each_with_object({}) { |l, h| h[l[:id]] = l[:type_key] }

    # A5: fresh classroom_teacher agent per repetition (moderator rotation for free)
    rep_teacher_id = DB.save_agent(db, run_id: run_id, role: 'classroom_teacher',
                                   model: config.dig('models', 'teacher'),
                                   profile: { 'repetition_index' => rep_idx,
                                              'condition'        => condition })

    # A0: pass pre-discussion memories so participants have lesson context
    learner_memories = ids.each_with_object({}) { |lid, h| h[lid] = pre_snap_by_id[lid] }.compact

    $stderr.puts "[v9c2] #{condition} rep #{rep_idx + 1}/#{groups.size} (#{ids.size} learners, #{called_on_count || 'all'} called on)"

    result = Phases::SizedDiscussion.run(
      condition: condition, learner_ids: ids,
      called_on_count: called_on_count,
      moderator_id: rep_teacher_id, moderator_prompt: moderator_prompt,
      participant_prompt: participant_prompt, lesson: fixed_lecture_text,
      config: config, tracker: tracker, learner_type_keys: type_map,
      learner_memories: learner_memories
    )

    ids.each do |lid|
      DB.save_learning_session(db, run_id: run_id, condition: condition,
                               learner_id: lid, teacher_or_tutor_id: rep_teacher_id,
                               transcript: result)
    end
    File.open(File.join(run_dir, 'transcripts.jsonl'), 'a') { |f| f.puts JSON.dump(result) }

    group.each do |learner|
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
                           rep_idx: rep_idx, diag_delta: diag_delta,
                           diag_post: MemoryDiagnostics.detect(updated),
                           memory: updated })
      end

      own_data = result['ownership_data'][learner[:id]] || {}
      all_ownership_data[learner[:id]] = own_data.merge(
        'memory_delta_after_discussion' => diag_delta[:acquired]
      )
    end
  end
end

$stderr.puts "[v9c2] Saving ownership metrics (#{all_ownership_data.size} learners)"
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
$stderr.puts "[v9c2] Phase 4: Evaluation (#{all_learners.size} × #{eval_tasks.size} tasks)"

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
  $stderr.puts "[v9c2] Evaluated #{learner[:id]} (#{learner[:condition]})"
end

# ---------------------------------------------------------------------------
# PHASE 5: Report
# ---------------------------------------------------------------------------
$stderr.puts "[v9c2] Phase 5: Generating report"

ownership_rows = DB.all_ownership_metrics_by_condition(db, run_id).values.flatten

Report.generate(db, run_id: run_id, output_dir: run_dir,
                run_config: config,
                token_summary: tracker.summary,
                experiment_meta: {
                  experiment: 'v9c2',
                  ownership_rows: ownership_rows,
                  pre_discussion_snapshots: pre_discussion_snapshots,
                  readiness_pass_rate: readiness_pass_rate,
                  readiness_failed: readiness_failed
                })

$stderr.puts "[v9c2] Run complete: #{run_dir}"
$stderr.puts "[v9c2] Readiness pass rate: #{(readiness_pass_rate * 100).round}%"
$stderr.puts "[v9c2] Total tokens: #{tracker.grand_total}"
$stderr.puts "[v9c2] n_disc used: #{n_disc}"
```

- [ ] **Step 2: Commit**

```bash
git add experiments/bloom_1n_vs_1on1/scripts/run_experiment_v9c2.rb
git commit -m "feat(v9c2): add run_experiment_v9c2.rb orchestrator

Integrates A0 (memory injection), A3 (N_disc independent repetitions),
A5 (fresh teacher per repetition), A6 (self-reflection for lecture_only),
and A8 (L6 excluded from main score via core_rows in report)."
```

---

## Task 8: Create config files

**Files:**
- Create: `../../config_v9c2.yml` (project root)
- Create: `../../config_v9c2_smoke.yml` (project root)

- [ ] **Step 1: Create `config_v9c2.yml`**

```yaml
# config_v9c2.yml
experiment:
  name: "bloom_v9c2_classroom_size"
  domain: "zarn_tokens"
  lecture_only_n: 4
  n_disc: 5
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
  db: "experiments/bloom_1n_vs_1on1/data/experiment_v9c2.db"
```

- [ ] **Step 2: Create `config_v9c2_smoke.yml`**

```yaml
# config_v9c2_smoke.yml — 3 conditions × n_disc=2 to verify A0+A3 smoke gate cheaply
experiment:
  name: "bloom_v9c2_smoke"
  domain: "zarn_tokens"
  lecture_only_n: 2
  n_disc: 2
  class_sizes:
    pair_discussion_size_2: 2
    large_class_discussion_size_16: 4
  called_on_counts:
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
  db: "experiments/bloom_1n_vs_1on1/data/experiment_v9c2_smoke.db"
```

Note on smoke config: 3 conditions (`lecture_only`, `pair_discussion_size_2`, `large_class_discussion_size_16`) match the checklist's smoke gate spec. `n_disc = 2` produces 2 independent discussion instances per condition — sufficient to verify uniqueness of transcripts without reproducing the pseudoreplication (N=1) problem.

- [ ] **Step 3: Commit**

```bash
git add config_v9c2.yml config_v9c2_smoke.yml
git commit -m "feat(v9c2): add config_v9c2.yml and config_v9c2_smoke.yml

Full run: n_disc=5, all sonnet models, ~2.5-3.2M token estimate.
Smoke run: n_disc=2, 3 conditions only, haiku models, under 200k tokens."
```

---

## Self-Review

**1. Spec coverage:**

| Checklist item | Task |
|---------------|------|
| A0: `contrib_prompt` context injection of learner memory | Task 1 |
| A0: `whole_class_discussion.rb` twin bug | ⚠️ **OUT OF SCOPE** — `WholeClassDiscussion` is a v8-only phase, not used by v9c2. Modifying it would be unrelated to v9c2 and risks breaking `test_report_v8.rb`. Tracked as a future-only concern if v8 is re-run. |
| A3: N_disc ≥ 5 independent repetitions per condition | Task 7 (`run_experiment_v9c2.rb`) |
| A3: discussion-level unit of analysis in report | Task 3 (`discussion_level_variance_by_condition`) |
| A5: moderator/teacher rotation per repetition | Task 7 (fresh `classroom_teacher` agent per group) |
| A5: evaluator triplication | **DROPPED** — documented in "Design Decisions" callout at top of plan |
| A6: `lecture_only` self-reflection phase | Tasks 4 + 7 |
| A8: L6 exclusion from main score | Task 5 |
| A8: L6 exploratory appendix in report | Task 5 |
| Config files (`config_v9c2.yml`, `config_v9c2_smoke.yml`) | Task 8 |
| Test runner registration | Task 6 |

**2. Placeholder scan:** No "TBD", "TODO", "similar to Task N", or unimplemented steps found. All code blocks are complete.

**3. Type consistency check:**

- `learner_memories: {}` kwarg added in Task 1 (`sized_discussion.rb`) and passed in Task 7 orchestrator as `learner_memories: learner_memories` — ✅
- `DB.all_learning_sessions_by_condition(db, run_id)` defined in Task 2, called in Task 3 `Report.generate` — ✅ (positional args match `DB.all_memories_by_condition` pattern)
- `discussion_level_variance_by_condition(rows, sessions_by_condition)` defined in Task 3, used in `build_markdown` — both `rows` and `sessions_by_condition` are passed consistently — ✅
- `Phases::SelfReflection.run(learner_id:, memory:, reflection_prompt:, lesson:, config:, tracker:, learner_type_key:)` defined in Task 4 and called in Task 7 with all required kwargs — ✅
- `core_rows(rows)` returns same structure as `rows` (array of hashes with same keys) — `by_condition`, `detect_ceiling`, `token_data` all receive `scored_rows` with identical structure — ✅
- `l6_rows_section(rows)` receives full `rows` array (not `scored_rows`) — the `all_rows` fixture in `test_report_v9c2.rb` includes L6 rows — ✅
- `experiment_meta[:experiment]` is always a string value (`'v9c2'`) — matches pattern in v9c orchestrator — ✅

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-06-09-v9c2-code-changes-implementation-plan.md`.

**Two execution options:**

**1. Subagent-Driven (recommended)** — Fresh subagent per task, two-stage review (spec compliance then code quality) after each task, continuous execution without pausing. Use `superpowers:subagent-driven-development`.

**2. Inline Execution** — Execute tasks in this session using `superpowers:executing-plans`, batch execution with checkpoints for review.

**Which approach?**
