# ABOUTME: Tests DB methods for the v9b ownership_metrics table
# ABOUTME: Covers save, get, and condition-aggregation queries

$LOAD_PATH.unshift File.join(__dir__, '..', 'lib')
require 'minitest/autorun'
require 'tmpdir'
require 'db'
require 'helpers'

class TestDbOwnershipMetrics < Minitest::Test
  def setup
    @dir = Dir.mktmpdir
    @db  = DB.setup(File.join(@dir, 'test.db'))
    @run_id = 'run-test-999'
    DB.save_run(@db, @run_id, 'test_run', { 'experiment' => { 'name' => 'test' } })
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end

  def test_save_and_get_ownership_metrics
    learner_id = 'learner-001'
    DB.save_ownership_metrics(@db,
      run_id: @run_id, learner_id: learner_id,
      condition: 'pair_discussion_size_2',
      contribution_count: 2, attempted_answer: true,
      received_feedback: true, misconception_exposed: false,
      misconception_corrected: false, observed_peer_reasoning_count: 1,
      memory_delta_after_discussion: 2, ownership_score: 3,
      discussion_exposure_count: 5, direct_participation_count: 2,
      moderator_feedback_count: 1
    )
    rows = DB.get_ownership_metrics(@db, run_id: @run_id, learner_id: learner_id)
    assert_equal 1, rows.size
    row = rows.first
    assert_equal 2, row['contribution_count']
    assert_equal 1, row['attempted_answer']
    assert_equal 3, row['ownership_score']
  end

  def test_all_ownership_metrics_by_condition_groups_correctly
    %w[learner-a learner-b].each_with_index do |lid, i|
      DB.save_ownership_metrics(@db,
        run_id: @run_id, learner_id: lid,
        condition: 'small_class_discussion_size_4',
        contribution_count: i + 1, attempted_answer: true,
        received_feedback: true, misconception_exposed: false,
        misconception_corrected: false, observed_peer_reasoning_count: 0,
        memory_delta_after_discussion: i, ownership_score: 2,
        discussion_exposure_count: 4, direct_participation_count: 1,
        moderator_feedback_count: 1
      )
    end
    by_cond = DB.all_ownership_metrics_by_condition(@db, @run_id)
    assert_equal 1, by_cond.keys.size
    assert_equal 2, by_cond['small_class_discussion_size_4'].size
  end

  def test_save_ownership_metrics_boolean_fields_round_trip
    DB.save_ownership_metrics(@db,
      run_id: @run_id, learner_id: 'learner-c',
      condition: 'lecture_only',
      contribution_count: 0, attempted_answer: false,
      received_feedback: false, misconception_exposed: false,
      misconception_corrected: false, observed_peer_reasoning_count: 0,
      memory_delta_after_discussion: 0, ownership_score: 0,
      discussion_exposure_count: 0, direct_participation_count: 0,
      moderator_feedback_count: 0
    )
    rows = DB.get_ownership_metrics(@db, run_id: @run_id, learner_id: 'learner-c')
    assert_equal 0, rows.first['attempted_answer']
    assert_equal 0, rows.first['received_feedback']
  end
end
