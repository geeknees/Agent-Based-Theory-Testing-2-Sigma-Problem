# ABOUTME: Tests for v8 DB extensions — mastery_check_results table
# ABOUTME: Uses real temporary SQLite database; no mocking

$LOAD_PATH.unshift File.join(__dir__, '..', 'lib')
require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require 'db'

class TestDBV8 < Minitest::Test
  def setup
    @tmpdir  = Dir.mktmpdir
    @db_path = File.join(@tmpdir, 'test_v8.db')
    @db      = DB.setup(@db_path)
    @run_id  = Helpers.generate_id
    DB.save_run(@db, @run_id, 'test_v8', {})
  end

  def teardown
    @db.close
    FileUtils.rm_rf(@tmpdir)
  end

  def test_mastery_check_results_table_exists
    tables = @db.execute("SELECT name FROM sqlite_master WHERE type='table'").map { |r| r['name'] }
    assert_includes tables, 'mastery_check_results'
  end

  def test_save_mastery_check_returns_id
    learner_id = Helpers.generate_id
    id = DB.save_mastery_check(@db,
      run_id: @run_id, learner_id: learner_id,
      check_id: 'mc_recall_01', check_type: 'recall',
      response_text: '{"answer":"7"}', answer_correct: true,
      corrective_note: nil)
    assert_instance_of String, id
    refute_empty id
  end

  def test_get_mastery_checks_returns_all_for_learner
    learner_id = Helpers.generate_id
    DB.save_mastery_check(@db, run_id: @run_id, learner_id: learner_id,
      check_id: 'mc_recall_01', check_type: 'recall',
      response_text: '{"answer":"7"}', answer_correct: true, corrective_note: nil)
    DB.save_mastery_check(@db, run_id: @run_id, learner_id: learner_id,
      check_id: 'mc_edge_01', check_type: 'edge_case',
      response_text: '{"answer":"5"}', answer_correct: false,
      corrective_note: 'Blue is inactive if no Green to its left.')
    results = DB.get_mastery_checks(@db, run_id: @run_id, learner_id: learner_id)
    assert_equal 2, results.size
    wrong = results.find { |r| r['check_id'] == 'mc_edge_01' }
    assert_equal false, wrong['answer_correct']
    assert_equal 'Blue is inactive if no Green to its left.', wrong['corrective_note']
  end

  def test_get_mastery_check_errors_returns_only_wrong
    learner_id = Helpers.generate_id
    DB.save_mastery_check(@db, run_id: @run_id, learner_id: learner_id,
      check_id: 'mc_recall_01', check_type: 'recall',
      response_text: '{}', answer_correct: true, corrective_note: nil)
    DB.save_mastery_check(@db, run_id: @run_id, learner_id: learner_id,
      check_id: 'mc_edge_01', check_type: 'edge_case',
      response_text: '{}', answer_correct: false, corrective_note: 'note')
    errors = DB.get_mastery_check_errors(@db, run_id: @run_id, learner_id: learner_id)
    assert_equal 1, errors.size
    assert_equal 'mc_edge_01', errors.first['check_id']
  end
end
