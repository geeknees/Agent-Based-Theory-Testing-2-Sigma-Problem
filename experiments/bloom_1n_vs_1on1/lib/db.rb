# ABOUTME: SQLite database setup and all data persistence operations for experiments
# ABOUTME: Each save_* function takes a db handle plus keyword args; returns the generated id

require 'sqlite3'
require 'json'
require 'fileutils'
require_relative 'helpers'

module DB
  SCHEMA = <<~SQL
    CREATE TABLE IF NOT EXISTS experiment_runs (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      config_json TEXT NOT NULL,
      created_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS agents (
      id TEXT PRIMARY KEY,
      run_id TEXT NOT NULL,
      role TEXT NOT NULL,
      condition TEXT,
      model TEXT NOT NULL,
      profile_json TEXT,
      created_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS learning_sessions (
      id TEXT PRIMARY KEY,
      run_id TEXT NOT NULL,
      condition TEXT NOT NULL,
      learner_id TEXT,
      teacher_or_tutor_id TEXT NOT NULL,
      transcript_json TEXT NOT NULL,
      created_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS learner_memories (
      id TEXT PRIMARY KEY,
      run_id TEXT NOT NULL,
      learner_id TEXT NOT NULL,
      condition TEXT NOT NULL,
      memory_json TEXT NOT NULL,
      created_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS evaluation_tasks (
      id TEXT PRIMARY KEY,
      run_id TEXT NOT NULL,
      task_type TEXT NOT NULL,
      prompt TEXT NOT NULL,
      expected_answer_json TEXT,
      rubric_json TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS task_attempts (
      id TEXT PRIMARY KEY,
      run_id TEXT NOT NULL,
      learner_id TEXT NOT NULL,
      condition TEXT NOT NULL,
      task_id TEXT NOT NULL,
      response_text TEXT NOT NULL,
      trace_json TEXT,
      created_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS evaluations (
      id TEXT PRIMARY KEY,
      run_id TEXT NOT NULL,
      attempt_id TEXT NOT NULL,
      evaluator_id TEXT NOT NULL,
      score_json TEXT NOT NULL,
      created_at TEXT NOT NULL DEFAULT (datetime('now'))
    );
  SQL

  def self.setup(db_path)
    FileUtils.mkdir_p(File.dirname(db_path))
    db = SQLite3::Database.new(db_path)
    db.execute_batch(SCHEMA)
    db.results_as_hash = true
    db
  end

  def self.save_run(db, run_id, name, config)
    db.execute(
      'INSERT INTO experiment_runs (id, name, config_json) VALUES (?, ?, ?)',
      [run_id, name, JSON.dump(config)]
    )
    run_id
  end

  def self.save_agent(db, run_id:, role:, condition: nil, model:)
    id = Helpers.generate_id
    db.execute(
      'INSERT INTO agents (id, run_id, role, condition, model) VALUES (?, ?, ?, ?, ?)',
      [id, run_id, role, condition, model]
    )
    id
  end

  def self.save_learning_session(db, run_id:, condition:, learner_id: nil, teacher_or_tutor_id:, transcript:)
    id = Helpers.generate_id
    db.execute(
      'INSERT INTO learning_sessions (id, run_id, condition, learner_id, teacher_or_tutor_id, transcript_json) VALUES (?, ?, ?, ?, ?, ?)',
      [id, run_id, condition, learner_id, teacher_or_tutor_id, JSON.dump(transcript)]
    )
    id
  end

  def self.save_learner_memory(db, run_id:, learner_id:, condition:, memory:)
    id = Helpers.generate_id
    db.execute(
      'INSERT INTO learner_memories (id, run_id, learner_id, condition, memory_json) VALUES (?, ?, ?, ?, ?)',
      [id, run_id, learner_id, condition, JSON.dump(memory)]
    )
    id
  end

  def self.save_evaluation_task(db, run_id:, task_id:, task_type:, prompt:, expected_answer:, rubric:)
    db.execute(
      'INSERT OR IGNORE INTO evaluation_tasks (id, run_id, task_type, prompt, expected_answer_json, rubric_json) VALUES (?, ?, ?, ?, ?, ?)',
      [task_id, run_id, task_type, prompt, JSON.dump(expected_answer), JSON.dump(rubric)]
    )
    task_id
  end

  def self.save_task_attempt(db, run_id:, learner_id:, condition:, task_id:, response_text:, trace: nil)
    id = Helpers.generate_id
    db.execute(
      'INSERT INTO task_attempts (id, run_id, learner_id, condition, task_id, response_text, trace_json) VALUES (?, ?, ?, ?, ?, ?, ?)',
      [id, run_id, learner_id, condition, task_id, response_text, trace ? JSON.dump(trace) : nil]
    )
    id
  end

  def self.save_evaluation(db, run_id:, attempt_id:, evaluator_id:, score:)
    id = Helpers.generate_id
    db.execute(
      'INSERT INTO evaluations (id, run_id, attempt_id, evaluator_id, score_json) VALUES (?, ?, ?, ?, ?)',
      [id, run_id, attempt_id, evaluator_id, JSON.dump(score)]
    )
    id
  end

  def self.get_learner_memory(db, run_id:, learner_id:)
    row = db.execute(
      'SELECT memory_json FROM learner_memories WHERE run_id = ? AND learner_id = ? ORDER BY rowid DESC LIMIT 1',
      [run_id, learner_id]
    ).first
    row ? JSON.parse(row['memory_json']) : nil
  end

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
      JOIN evaluation_tasks et ON et.id = ta.task_id AND et.run_id = ta.run_id
      LEFT JOIN evaluations e ON e.attempt_id = ta.id
      WHERE ta.run_id = ?
      ORDER BY ta.condition, ta.learner_id, et.task_type
    SQL
  end
end
