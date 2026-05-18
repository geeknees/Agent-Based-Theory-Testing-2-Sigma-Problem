# ABOUTME: Integration tests for DB module using a real temporary SQLite database
# ABOUTME: Creates and destroys a real on-disk DB per test; no mocking

$LOAD_PATH.unshift File.join(__dir__, '..', 'lib')
require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require 'db'

class TestDB < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @db_path = File.join(@tmpdir, 'test.db')
    @db = DB.setup(@db_path)
    @run_id = Helpers.generate_id
    DB.save_run(@db, @run_id, 'test_run', { 'n_classroom' => 2 })
  end

  def teardown
    @db.close
    FileUtils.rm_rf(@tmpdir)
  end

  def test_setup_creates_all_tables
    tables = @db.execute("SELECT name FROM sqlite_master WHERE type='table'").map { |r| r['name'] }
    %w[experiment_runs agents learning_sessions learner_memories evaluation_tasks task_attempts evaluations].each do |t|
      assert_includes tables, t, "Missing table: #{t}"
    end
  end

  def test_save_and_retrieve_run
    row = @db.execute('SELECT name FROM experiment_runs WHERE id = ?', [@run_id]).first
    assert_equal 'test_run', row['name']
  end

  def test_save_agent_returns_id
    id = DB.save_agent(@db, run_id: @run_id, role: 'teacher', model: 'claude-sonnet-4-6')
    assert_instance_of String, id
    refute_empty id
  end

  def test_save_and_retrieve_learner_memory
    learner_id = Helpers.generate_id
    memory = { 'key_rules' => ['Red doubles next token'] }
    DB.save_learner_memory(@db, run_id: @run_id, learner_id: learner_id, condition: 'classroom', memory: memory)
    retrieved = DB.get_learner_memory(@db, run_id: @run_id, learner_id: learner_id)
    assert_equal ['Red doubles next token'], retrieved['key_rules']
  end

  def test_save_task_attempt_and_query_with_scores
    task_id = 'task_recall_01'
    DB.save_evaluation_task(@db,
      run_id: @run_id, task_id: task_id, task_type: 'recall',
      prompt: 'Calculate score.', expected_answer: { 'score' => 21 },
      rubric: { 'total_max' => 20 }
    )
    learner_id = Helpers.generate_id
    attempt_id = DB.save_task_attempt(@db,
      run_id: @run_id, learner_id: learner_id, condition: 'classroom',
      task_id: task_id, response_text: 'My answer is 21.'
    )
    evaluator_id = Helpers.generate_id
    DB.save_evaluation(@db,
      run_id: @run_id, attempt_id: attempt_id, evaluator_id: evaluator_id,
      score: { 'total' => 18, 'correctness' => 4 }
    )
    rows = DB.all_attempts_with_scores(@db, @run_id)
    assert_equal 1, rows.size
    score = JSON.parse(rows.first['score_json'])
    assert_equal 18, score['total']
  end
end

class TestAllMemoriesByCondition < Minitest::Test
  def setup
    @db     = DB.setup(':memory:')
    @run_id = 'run-mem-test'
    DB.save_run(@db, @run_id, 'test_run', {})
  end

  def test_returns_memories_grouped_by_condition
    agent_a = DB.save_agent(@db, run_id: @run_id, role: 'learner',
                            condition: 'homogeneous_classroom', model: 'test',
                            profile: { 'type_key' => 'edge_case_dropper' })
    agent_b = DB.save_agent(@db, run_id: @run_id, role: 'learner',
                            condition: '1on1', model: 'test',
                            profile: { 'type_key' => 'rule_extractor' })

    DB.save_learner_memory(@db, run_id: @run_id, learner_id: agent_a,
                           condition: 'homogeneous_classroom',
                           memory: { 'rules' => ['rule A'], 'edge_cases' => [] })
    DB.save_learner_memory(@db, run_id: @run_id, learner_id: agent_b,
                           condition: '1on1',
                           memory: { 'rules' => ['rule B'], 'edge_cases' => ['edge1'] })

    result = DB.all_memories_by_condition(@db, @run_id)

    assert result.key?('homogeneous_classroom')
    assert result.key?('1on1')
    assert_equal 1, result['homogeneous_classroom'].size
    assert_equal ['rule A'], result['homogeneous_classroom'].first['memory']['rules']
    assert_equal 1, result['1on1'].size
    assert_equal 'rule_extractor', result['1on1'].first['type_key']
  end

  def test_returns_empty_hash_when_no_memories
    result = DB.all_memories_by_condition(@db, 'nonexistent-run')
    assert_equal({}, result)
  end
end
