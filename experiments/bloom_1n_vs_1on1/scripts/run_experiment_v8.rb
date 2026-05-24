# ABOUTME: Orchestrator for v8 flipped-learning experiment — 4 conditions, 4 phases
# ABOUTME: Conditions: lecture_only, lecture_plus_whole_class_discussion,
# ABOUTME:   lecture_plus_small_group_discussion, lecture_plus_one_on_one_tutoring

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
require 'phases/prerequisite_lecture'
require 'phases/mastery_check'
require 'phases/whole_class_discussion'
require 'phases/small_group_discussion'
require 'phases/flipped_tutoring'
require 'phases/memory'
require 'phases/solver'
require 'phases/evaluator'
require 'report'

config_path  = ARGV[0] or abort "Usage: #{$0} <config.yml>"
PROJECT_ROOT = File.expand_path('../..', EXPERIMENT_DIR)
config       = YAML.load_file(File.join(PROJECT_ROOT, config_path))

run_id      = SecureRandom.uuid
run_name    = config.dig('experiment', 'name') || 'bloom_v8'
domain_path = File.join(PROJECT_ROOT, config.dig('paths', 'domain'))
prompts_path = File.join(PROJECT_ROOT, config.dig('paths', 'prompts'))
output_base  = File.join(PROJECT_ROOT, config.dig('paths', 'output'))
db_path      = File.join(PROJECT_ROOT, config.dig('paths', 'db'))
run_dir      = File.join(output_base, 'runs', run_id)

FileUtils.mkdir_p(run_dir)
$stderr.puts "[v8] Starting run #{run_id}"

tracker = TokenTracker.new

lesson       = Helpers.load_file(File.join(domain_path, 'lesson.md'))
tasks_file   = config.dig('experiment', 'eval_tasks_file') || 'eval_tasks_v8.json'
eval_tasks   = JSON.parse(Helpers.load_file(File.join(domain_path, tasks_file)))
check_tasks  = JSON.parse(Helpers.load_file(File.join(domain_path, 'mastery_check_tasks.json')))
rubric       = JSON.parse(Helpers.load_file(File.join(domain_path, 'rubric.json')))

teacher_prompt     = Helpers.load_file(File.join(prompts_path, 'classroom_teacher.md'))
moderator_prompt   = Helpers.load_file(File.join(prompts_path, 'discussion_moderator.md'))
participant_prompt = Helpers.load_file(File.join(prompts_path, 'discussion_participant.md'))
tutor_prompt       = Helpers.load_file(File.join(prompts_path, 'flipped_tutor.md'))
learner_prompt     = Helpers.load_file(File.join(prompts_path, 'learner.md'))
summarizer_prompt  = Helpers.load_file(File.join(prompts_path, 'memory_summarizer.md'))
solver_prompt      = Helpers.load_file(File.join(prompts_path, 'problem_solver.md'))
evaluator_prompt   = Helpers.load_file(File.join(prompts_path, 'blind_evaluator.md'))

db = DB.setup(db_path)
DB.save_run(db, run_id, run_name, config)
File.write(File.join(run_dir, 'config.json'), JSON.pretty_generate(config))

n_per_condition = config.dig('experiment', 'n_per_condition') || 4
type_keys = (config.dig('experiment', 'learner_types') || []).map(&:to_sym)
type_keys = LearnerTypes::HETEROGENEOUS_ASSIGNMENT if type_keys.empty?

CONDITIONS = %w[
  lecture_only
  lecture_plus_whole_class_discussion
  lecture_plus_small_group_discussion
  lecture_plus_one_on_one_tutoring
].freeze

teacher_id   = DB.save_agent(db, run_id: run_id, role: 'classroom_teacher',
                              model: config.dig('models', 'teacher'))
tutor_id     = DB.save_agent(db, run_id: run_id, role: 'tutor',
                              model: config.dig('models', 'tutor'))
evaluator_id = DB.save_agent(db, run_id: run_id, role: 'evaluator',
                              model: config.dig('models', 'evaluator'))

all_learners = CONDITIONS.flat_map do |condition|
  n_per_condition.times.map do |i|
    type_key   = type_keys[i % type_keys.size]
    learner_id = DB.save_agent(db, run_id: run_id, role: 'learner', condition: condition,
                               model: config.dig('models', 'learner'),
                               profile: { 'type_key' => type_key.to_s })
    { id: learner_id, condition: condition, type_key: type_key }
  end
end

by_condition = all_learners.group_by { |l| l[:condition] }

# ---------------------------------------------------------------------------
# PHASE 1: Prerequisite lecture (one shared lecture per condition)
# ---------------------------------------------------------------------------
$stderr.puts "[v8] Phase 1: Prerequisite lecture (#{CONDITIONS.size} conditions)"

CONDITIONS.each do |condition|
  learners = by_condition[condition]
  ids      = learners.map { |l| l[:id] }
  type_map = learners.each_with_object({}) { |l, h| h[l[:id]] = l[:type_key] }

  transcript = Phases::PrerequisiteLecture.run(
    teacher_id: teacher_id, learner_ids: ids,
    teacher_prompt: teacher_prompt, learner_prompt: learner_prompt,
    lesson: lesson, config: config, tracker: tracker, learner_type_keys: type_map
  )

  ids.each do |lid|
    DB.save_learning_session(db, run_id: run_id, condition: condition,
                             learner_id: lid, teacher_or_tutor_id: teacher_id,
                             transcript: transcript)
  end
  File.open(File.join(run_dir, 'transcripts.jsonl'), 'a') { |f| f.puts JSON.dump(transcript) }
  $stderr.puts "[v8] Phase 1 done: #{condition} (#{ids.size} learners)"
end

# Generate initial memory for all learners
$stderr.puts "[v8] Phase 1b: Initial memory generation (#{all_learners.size} learners)"
all_learners.each do |learner|
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
    f.puts JSON.dump({ phase: 'post_lecture', learner_id: learner[:id],
                       condition: learner[:condition], type_key: learner[:type_key].to_s,
                       memory: memory })
  end
end

# ---------------------------------------------------------------------------
# PHASE 2: Mastery check (3 questions per learner, all conditions)
# ---------------------------------------------------------------------------
$stderr.puts "[v8] Phase 2: Mastery checks (#{all_learners.size} learners × #{check_tasks.size} checks)"

all_learners.each do |learner|
  memory = DB.get_learner_memory(db, run_id: run_id, learner_id: learner[:id])
  result = Phases::MasteryCheck.run(
    learner_id: learner[:id], memory: memory, check_tasks: check_tasks,
    solver_prompt: solver_prompt, config: config, db: db, run_id: run_id,
    tracker: tracker
  )

  DB.save_learner_memory(db, run_id: run_id, learner_id: learner[:id],
                         condition: learner[:condition], memory: result[:updated_memory])
  File.open(File.join(run_dir, 'memories.jsonl'), 'a') do |f|
    f.puts JSON.dump({ phase: 'post_mastery', learner_id: learner[:id],
                       condition: learner[:condition], type_key: learner[:type_key].to_s,
                       checks: result[:checks], errors: result[:errors].size,
                       memory: result[:updated_memory] })
  end
  $stderr.puts "[v8] Mastery #{learner[:id]}: #{result[:errors].size}/#{check_tasks.size} errors"
end

# ---------------------------------------------------------------------------
# PHASE 3: Condition-specific interaction
# ---------------------------------------------------------------------------
$stderr.puts "[v8] Phase 3: Condition interactions"

# --- lecture_only: no interaction ---
$stderr.puts "[v8] Phase 3: lecture_only — no interaction"

# --- whole_class_discussion ---
wcd_learners = by_condition['lecture_plus_whole_class_discussion']
wcd_ids      = wcd_learners.map { |l| l[:id] }
type_map_wcd = wcd_learners.each_with_object({}) { |l, h| h[l[:id]] = l[:type_key] }

$stderr.puts "[v8] Phase 3: whole_class_discussion (#{wcd_ids.size} learners)"
wcd_transcript = Phases::WholeClassDiscussion.run(
  moderator_id: teacher_id, learner_ids: wcd_ids,
  moderator_prompt: moderator_prompt, participant_prompt: participant_prompt,
  lesson: lesson, config: config, tracker: tracker, learner_type_keys: type_map_wcd
)
wcd_ids.each do |lid|
  DB.save_learning_session(db, run_id: run_id,
                           condition: 'lecture_plus_whole_class_discussion',
                           learner_id: lid, teacher_or_tutor_id: teacher_id,
                           transcript: wcd_transcript)
end
File.open(File.join(run_dir, 'transcripts.jsonl'), 'a') { |f| f.puts JSON.dump(wcd_transcript) }

wcd_learners.each do |learner|
  existing = DB.get_learner_memory(db, run_id: run_id, learner_id: learner[:id])
  updated  = Phases::Memory.update(
    learner_id: learner[:id], existing_memory: existing,
    update_transcript: wcd_transcript['turns'],
    summarizer_prompt: summarizer_prompt, config: config, tracker: tracker,
    learner_type_key: learner[:type_key]
  )
  DB.save_learner_memory(db, run_id: run_id, learner_id: learner[:id],
                         condition: 'lecture_plus_whole_class_discussion', memory: updated)
  File.open(File.join(run_dir, 'memories.jsonl'), 'a') do |f|
    f.puts JSON.dump({ phase: 'post_interaction', learner_id: learner[:id],
                       condition: 'lecture_plus_whole_class_discussion', memory: updated })
  end
end

# --- small_group_discussion ---
sgd_learners = by_condition['lecture_plus_small_group_discussion']
sgd_ids      = sgd_learners.map { |l| l[:id] }
type_map_sgd = sgd_learners.each_with_object({}) { |l, h| h[l[:id]] = l[:type_key] }

$stderr.puts "[v8] Phase 3: small_group_discussion (#{sgd_ids.size} learners)"
group_results = Phases::SmallGroupDiscussion.run(
  learner_ids: sgd_ids, participant_prompt: participant_prompt,
  lesson: lesson, config: config, tracker: tracker, learner_type_keys: type_map_sgd
)
group_results.each do |group|
  group['learner_ids'].each do |lid|
    DB.save_learning_session(db, run_id: run_id,
                             condition: 'lecture_plus_small_group_discussion',
                             learner_id: lid, teacher_or_tutor_id: teacher_id,
                             transcript: group)
  end
  File.open(File.join(run_dir, 'transcripts.jsonl'), 'a') { |f| f.puts JSON.dump(group) }
end

sgd_learners.each do |learner|
  group    = group_results.find { |g| g['learner_ids'].include?(learner[:id]) }
  next unless group
  existing = DB.get_learner_memory(db, run_id: run_id, learner_id: learner[:id])
  updated  = Phases::Memory.update(
    learner_id: learner[:id], existing_memory: existing,
    update_transcript: group['turns'],
    summarizer_prompt: summarizer_prompt, config: config, tracker: tracker,
    learner_type_key: learner[:type_key]
  )
  DB.save_learner_memory(db, run_id: run_id, learner_id: learner[:id],
                         condition: 'lecture_plus_small_group_discussion', memory: updated)
  File.open(File.join(run_dir, 'memories.jsonl'), 'a') do |f|
    f.puts JSON.dump({ phase: 'post_interaction', learner_id: learner[:id],
                       condition: 'lecture_plus_small_group_discussion', memory: updated })
  end
end

# --- flipped_tutoring ---
ft_learners = by_condition['lecture_plus_one_on_one_tutoring']
$stderr.puts "[v8] Phase 3: flipped_tutoring (#{ft_learners.size} learners)"

ft_learners.each do |learner|
  mastery_errors = DB.get_mastery_check_errors(db, run_id: run_id, learner_id: learner[:id])
  error_tasks = mastery_errors.map do |err|
    check_tasks.find { |t| t['id'] == err['check_id'] } || err
  end

  transcript = Phases::FlippedTutoring.run_session(
    tutor_id: tutor_id, learner_id: learner[:id],
    tutor_prompt: tutor_prompt, learner_prompt: learner_prompt,
    lesson: lesson, mastery_errors: error_tasks,
    config: config, tracker: tracker, learner_type_key: learner[:type_key]
  )
  DB.save_learning_session(db, run_id: run_id,
                           condition: 'lecture_plus_one_on_one_tutoring',
                           learner_id: learner[:id], teacher_or_tutor_id: tutor_id,
                           transcript: transcript)
  File.open(File.join(run_dir, 'transcripts.jsonl'), 'a') { |f| f.puts JSON.dump(transcript) }

  existing = DB.get_learner_memory(db, run_id: run_id, learner_id: learner[:id])
  updated  = Phases::Memory.update(
    learner_id: learner[:id], existing_memory: existing,
    update_transcript: transcript['turns'],
    summarizer_prompt: summarizer_prompt, config: config, tracker: tracker,
    learner_type_key: learner[:type_key]
  )
  DB.save_learner_memory(db, run_id: run_id, learner_id: learner[:id],
                         condition: 'lecture_plus_one_on_one_tutoring', memory: updated)
  File.open(File.join(run_dir, 'memories.jsonl'), 'a') do |f|
    f.puts JSON.dump({ phase: 'post_interaction', learner_id: learner[:id],
                       condition: 'lecture_plus_one_on_one_tutoring', memory: updated })
  end
end

# ---------------------------------------------------------------------------
# PHASE 4: Evaluation
# ---------------------------------------------------------------------------
$stderr.puts "[v8] Phase 4: Evaluation (#{all_learners.size} × #{eval_tasks.size} tasks)"

eval_tasks.each do |task|
  DB.save_evaluation_task(db, run_id: run_id, task_id: task['id'], task_type: task['task_type'],
                          prompt: task['learner_prompt'], expected_answer: task, rubric: rubric)
end

all_learners.each do |learner|
  memory = DB.get_learner_memory(db, run_id: run_id, learner_id: learner[:id])
  eval_tasks.each do |task|
    result     = Phases::Solver.solve(
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

# ---------------------------------------------------------------------------
# PHASE 5: Report
# ---------------------------------------------------------------------------
$stderr.puts "[v8] Phase 5: Report"
Report.generate(db, run_id: run_id, output_dir: run_dir,
                run_config: config, token_summary: tracker.summary,
                experiment_meta: { experiment: 'v8' })

db.close
$stderr.puts "[v8] Done. Results in: #{run_dir}"
puts run_dir
