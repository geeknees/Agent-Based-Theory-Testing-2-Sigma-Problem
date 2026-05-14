# ABOUTME: Main entry point for the Bloom 2 Sigma experiment orchestrator
# ABOUTME: Runs all phases with token tracking; outputs 7 files per run including ceiling-aware report

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

n_classroom    = config.dig('experiment', 'n_classroom')    || 4
n_tutoring     = config.dig('experiment', 'n_tutoring')     || 4
n_no_education = config.dig('experiment', 'n_no_education') || 4

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
no_education_learner_ids = n_no_education.times.map do
  DB.save_agent(db, run_id: run_id, role: 'learner', condition: 'no_education',
                model: config.dig('models', 'problem_solver'))
end
evaluator_id = DB.save_agent(db, run_id: run_id, role: 'evaluator',
                              model: config.dig('models', 'evaluator'))

all_learners = classroom_learner_ids.map { |id| { id: id, condition: 'classroom' } } +
               tutoring_learner_ids.map  { |id| { id: id, condition: '1on1' } } +
               no_education_learner_ids.map { |id| { id: id, condition: 'no_education' } }

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

# === PHASE 2.5: No-Education Baseline Memory ===
$stderr.puts "[main] Phase 2.5: No-education baseline (#{n_no_education} learners, zero LLM calls)"
no_education_learner_ids.each do |learner_id|
  memory = Phases::NoEducation.generate_memory(learner_id: learner_id)
  DB.save_learner_memory(db,
    run_id: run_id, learner_id: learner_id,
    condition: 'no_education', memory: memory
  )
  File.open(File.join(run_dir, 'memories.jsonl'), 'a') do |f|
    f.puts JSON.dump({ learner_id: learner_id, condition: 'no_education', memory: memory })
  end
end

# === PHASE 3: Memory Generation (classroom and tutoring only) ===
$stderr.puts "[main] Phase 3: Memory generation (#{classroom_learner_ids.size + tutoring_learner_ids.size} learners)"
(classroom_learner_ids.map { |id| { id: id, condition: 'classroom' } } +
 tutoring_learner_ids.map  { |id| { id: id, condition: '1on1' } }).each do |learner|
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
    prompt: task['learner_prompt'], expected_answer: task, rubric: rubric
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
