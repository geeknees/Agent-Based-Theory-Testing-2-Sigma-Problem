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
    pre_mem    = pre_discussion_memories[learner[:id]] || {}
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
