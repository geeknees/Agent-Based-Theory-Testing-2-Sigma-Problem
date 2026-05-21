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

teacher_prompt    = Helpers.load_file(File.join(prompts_path, 'classroom_teacher.md'))
tutor_prompt      = Helpers.load_file(File.join(prompts_path, 'one_on_one_tutor.md'))
scaffold_prompt   = Helpers.load_file(File.join(prompts_path, 'tutor_procedure_scaffolded.md'))
learner_prompt    = Helpers.load_file(File.join(prompts_path, 'learner.md'))
summarizer_prompt = Helpers.load_file(File.join(prompts_path, 'memory_summarizer.md'))
solver_prompt     = Helpers.load_file(File.join(prompts_path, 'problem_solver.md'))
evaluator_prompt  = Helpers.load_file(File.join(prompts_path, 'blind_evaluator.md'))

db = DB.setup(db_path)
DB.save_run(db, run_id, run_name, config)
File.write(File.join(run_dir, 'config.json'), JSON.pretty_generate(config))

n_public_qa  = config.dig('experiment', 'n_classroom_public_qa')                      || 4
n_generic    = config.dig('experiment', 'n_generic_one_on_one_tutoring')              || 4
n_scaffolded = config.dig('experiment', 'n_procedure_scaffolded_one_on_one_tutoring') || 4

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
  public_qa_ids.map  { |id| { id: id, condition: 'classroom_public_qa' } } +
  generic_ids.map    { |id| { id: id, condition: 'generic_one_on_one_tutoring' } } +
  scaffolded_ids.map { |id| { id: id, condition: 'procedure_scaffolded_one_on_one_tutoring' } }

class_context = <<~CTX
  CLASS COMPOSITION: All learners are order_confused type.
  - Tendency: apply rules in wrong sequence; often reverses modifier/activation order
  - Common misconception: applies_modifiers_before_activation
  Emphasize the CORRECT ORDER: check activation status FIRST, then apply modifiers.
CTX

type_map_qa = public_qa_ids.each_with_object({}) { |id, h| h[id] = type_key }

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

$stderr.puts "[exp_b] Phase 6: Generating report"
Report.generate(db, run_id: run_id, output_dir: run_dir,
                run_config: config, token_summary: tracker.summary,
                experiment_meta: { experiment: 'B' })

db.close
$stderr.puts "[exp_b] Done. Results in: #{run_dir}"
puts run_dir
