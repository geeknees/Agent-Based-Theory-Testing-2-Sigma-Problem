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

    CREATE TABLE IF NOT EXISTS mastery_check_results (
      id TEXT PRIMARY KEY,
      run_id TEXT NOT NULL,
      learner_id TEXT NOT NULL,
      check_id TEXT NOT NULL,
      check_type TEXT NOT NULL,
      response_text TEXT NOT NULL,
      answer_correct INTEGER NOT NULL,
      corrective_note TEXT,
      created_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

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

  def self.save_agent(db, run_id:, role:, condition: nil, model:, profile: nil)
    id = Helpers.generate_id
    db.execute(
      'INSERT INTO agents (id, run_id, role, condition, model, profile_json) VALUES (?, ?, ?, ?, ?, ?)',
      [id, run_id, role, condition, model, profile ? JSON.dump(profile) : nil]
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

  def self.save_mastery_check(db, run_id:, learner_id:, check_id:, check_type:,
                               response_text:, answer_correct:, corrective_note:)
    id = Helpers.generate_id
    db.execute(
      'INSERT INTO mastery_check_results (id, run_id, learner_id, check_id, check_type, response_text, answer_correct, corrective_note) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      [id, run_id, learner_id, check_id, check_type, response_text,
       answer_correct ? 1 : 0, corrective_note]
    )
    id
  end

  def self.get_mastery_checks(db, run_id:, learner_id:)
    rows = db.execute(
      'SELECT * FROM mastery_check_results WHERE run_id = ? AND learner_id = ? ORDER BY rowid',
      [run_id, learner_id]
    )
    rows.map { |r| r.merge('answer_correct' => r['answer_correct'] == 1) }
  end

  def self.get_mastery_check_errors(db, run_id:, learner_id:)
    get_mastery_checks(db, run_id: run_id, learner_id: learner_id)
      .select { |r| !r['answer_correct'] }
  end

  def self.all_mastery_checks_by_condition(db, run_id)
    db.execute(<<~SQL, [run_id])
      SELECT mcr.learner_id, mcr.check_id, mcr.check_type, mcr.answer_correct,
             a.condition
      FROM mastery_check_results mcr
      LEFT JOIN agents a ON a.id = mcr.learner_id
      WHERE mcr.run_id = ?
      ORDER BY a.condition, mcr.learner_id
    SQL
  end

  def self.get_learner_memory(db, run_id:, learner_id:)
    row = db.execute(
      'SELECT memory_json FROM learner_memories WHERE run_id = ? AND learner_id = ? ORDER BY rowid DESC LIMIT 1',
      [run_id, learner_id]
    ).first
    row ? JSON.parse(row['memory_json']) : nil
  end

  def self.all_memories_by_condition(db, run_id)
    rows = db.execute(<<~SQL, [run_id])
      SELECT lm.learner_id, lm.condition, lm.memory_json, a.profile_json
      FROM learner_memories lm
      LEFT JOIN agents a ON a.id = lm.learner_id
      WHERE lm.run_id = ?
      ORDER BY lm.condition, lm.learner_id
    SQL

    rows.group_by { |r| r['condition'] }.transform_values do |cond_rows|
      cond_rows.map do |r|
        profile  = r['profile_json'] ? JSON.parse(r['profile_json']) : {}
        type_key = profile['type_key']
        {
          'learner_id' => r['learner_id'],
          'memory'     => JSON.parse(r['memory_json']),
          'type_key'   => type_key
        }
      end
    end
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
        e.score_json,
        a.profile_json
      FROM task_attempts ta
      JOIN evaluation_tasks et ON et.id = ta.task_id
      LEFT JOIN evaluations e ON e.attempt_id = ta.id
      LEFT JOIN agents a ON a.id = ta.learner_id
      WHERE ta.run_id = ?
      ORDER BY ta.condition, ta.learner_id, et.task_type
    SQL
  end

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
end
