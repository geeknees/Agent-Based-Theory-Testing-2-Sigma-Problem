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
