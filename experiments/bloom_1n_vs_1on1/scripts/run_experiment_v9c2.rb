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

# Derive active conditions from config so smoke/partial configs run only the
# listed class_sizes rather than silently expanding to all 5 conditions.
V9C2_CONDITIONS = (['lecture_only'] + class_sizes.keys).freeze
V9C2_DISCUSSION_CONDITIONS = class_sizes.keys.freeze

# Single evaluator — triplication is a no-op since all eval_tasks_v8 tasks use
# auto-scoring via Scorer.score_attempt (string expected_answer path).
evaluator_id = DB.save_agent(db, run_id: run_id, role: 'evaluator',
                              model: config.dig('models', 'evaluator'))

# A3: For discussion conditions, create base_size * n_disc learners so each of
# the N_disc independent repetitions gets a fresh group of base_size learners.
all_learners = V9C2_CONDITIONS.flat_map do |condition|
  base_n = condition == 'lecture_only' ? lecture_only_n : class_sizes[condition]
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

  base_size       = class_sizes[condition]
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
