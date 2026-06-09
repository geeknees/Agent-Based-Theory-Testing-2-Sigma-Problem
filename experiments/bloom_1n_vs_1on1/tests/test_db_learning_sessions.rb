# ABOUTME: Tests DB.all_learning_sessions_by_condition — used for discussion-level variance (A3)
# ABOUTME: Sets up an in-memory SQLite DB with fixture data; no LLM calls

$LOAD_PATH.unshift File.join(__dir__, '..', 'lib')
require 'minitest/autorun'
require 'db'

class TestDbLearningSessions < Minitest::Test
  def setup
    @db     = DB.setup(':memory:')
    @run_id = 'run-test-001'
    DB.save_run(@db, @run_id, 'test_run', {})
    @teacher_id = DB.save_agent(@db, run_id: @run_id, role: 'classroom_teacher', model: 'test')
    @l1 = DB.save_agent(@db, run_id: @run_id, role: 'learner', condition: 'pair_discussion_size_2', model: 'test')
    @l2 = DB.save_agent(@db, run_id: @run_id, role: 'learner', condition: 'pair_discussion_size_2', model: 'test')
    @l3 = DB.save_agent(@db, run_id: @run_id, role: 'learner', condition: 'small_class_discussion_size_4', model: 'test')
  end

  def save_session(condition:, learner_id:, transcript: [{ 'speaker' => 'moderator', 'content' => 'hi' }])
    DB.save_learning_session(@db, run_id: @run_id, condition: condition,
                             learner_id: learner_id, teacher_or_tutor_id: @teacher_id,
                             transcript: { 'condition' => condition, 'turns' => transcript })
  end

  def test_groups_sessions_by_condition
    save_session(condition: 'pair_discussion_size_2',        learner_id: @l1)
    save_session(condition: 'pair_discussion_size_2',        learner_id: @l2)
    save_session(condition: 'small_class_discussion_size_4', learner_id: @l3)

    result = DB.all_learning_sessions_by_condition(@db, @run_id)

    assert_includes result.keys, 'pair_discussion_size_2'
    assert_includes result.keys, 'small_class_discussion_size_4'
    assert_equal 2, result['pair_discussion_size_2'].size
    assert_equal 1, result['small_class_discussion_size_4'].size
  end

  def test_rows_have_string_keys
    save_session(condition: 'pair_discussion_size_2', learner_id: @l1)
    result = DB.all_learning_sessions_by_condition(@db, @run_id)
    row    = result['pair_discussion_size_2'].first
    assert row.key?('condition'),       'Expected string key condition'
    assert row.key?('learner_id'),      'Expected string key learner_id'
    assert row.key?('transcript_json'), 'Expected string key transcript_json'
  end

  def test_returns_empty_hash_when_no_sessions
    result = DB.all_learning_sessions_by_condition(@db, @run_id)
    assert_empty result
  end

  def test_filters_by_run_id
    other_run     = 'run-other-999'
    DB.save_run(@db, other_run, 'other', {})
    other_teacher = DB.save_agent(@db, run_id: other_run, role: 'classroom_teacher', model: 'test')
    other_learner = DB.save_agent(@db, run_id: other_run, role: 'learner',
                                  condition: 'pair_discussion_size_2', model: 'test')
    DB.save_learning_session(@db, run_id: other_run, condition: 'pair_discussion_size_2',
                             learner_id: other_learner, teacher_or_tutor_id: other_teacher,
                             transcript: { 'turns' => [] })

    result = DB.all_learning_sessions_by_condition(@db, @run_id)
    assert_empty result
  end
end
