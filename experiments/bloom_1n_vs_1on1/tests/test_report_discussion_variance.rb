# ABOUTME: Tests Report.discussion_level_variance_by_condition — discussion as unit of analysis
# ABOUTME: Pure function tests using fixture rows; no DB or LLM calls

$LOAD_PATH.unshift File.join(__dir__, '..', 'lib')
require 'minitest/autorun'
require 'digest'
require 'json'
require 'report'

class TestDiscussionLevelVariance < Minitest::Test
  # Fixtures: 2 independent discussion sessions (different transcript_json) for pair condition.
  # Session A: l1 scores 1.0, l2 scores 1.0  => discussion mean = 1.0
  # Session B: l3 scores 0.0, l4 scores 0.0  => discussion mean = 0.0
  # Expected SD across two discussion means = 0.707

  def score_row(learner_id:, condition:, answer_correct:)
    {
      'learner_id'     => learner_id,
      'condition'      => condition,
      'answer_correct' => answer_correct,
      'task_id'        => 'l1_calc_01',
      'score_json'     => JSON.dump({ 'answer_correct' => answer_correct })
    }
  end

  def session_row(learner_id:, condition:, transcript_json:)
    {
      'learner_id'      => learner_id,
      'condition'       => condition,
      'transcript_json' => transcript_json
    }
  end

  def setup
    @t_a = JSON.dump({ 'turns' => [{ 'speaker' => 'mod', 'content' => 'session_a' }] })
    @t_b = JSON.dump({ 'turns' => [{ 'speaker' => 'mod', 'content' => 'session_b' }] })

    @rows = [
      score_row(learner_id: 'l1', condition: 'pair_discussion_size_2', answer_correct: true),
      score_row(learner_id: 'l2', condition: 'pair_discussion_size_2', answer_correct: true),
      score_row(learner_id: 'l3', condition: 'pair_discussion_size_2', answer_correct: false),
      score_row(learner_id: 'l4', condition: 'pair_discussion_size_2', answer_correct: false)
    ]

    # sessions_by_condition: l1+l2 share transcript A, l3+l4 share transcript B
    @sessions = {
      'pair_discussion_size_2' => [
        session_row(learner_id: 'l1', condition: 'pair_discussion_size_2', transcript_json: @t_a),
        session_row(learner_id: 'l2', condition: 'pair_discussion_size_2', transcript_json: @t_a),
        session_row(learner_id: 'l3', condition: 'pair_discussion_size_2', transcript_json: @t_b),
        session_row(learner_id: 'l4', condition: 'pair_discussion_size_2', transcript_json: @t_b)
      ]
    }
  end

  def test_returns_hash_keyed_by_condition
    result = Report.send(:discussion_level_variance_by_condition, @rows, @sessions)
    assert_includes result.keys, 'pair_discussion_size_2'
  end

  def test_detects_two_independent_discussions
    result = Report.send(:discussion_level_variance_by_condition, @rows, @sessions)
    assert_equal 2, result['pair_discussion_size_2'][:n]
  end

  def test_sd_across_two_discussion_means
    result = Report.send(:discussion_level_variance_by_condition, @rows, @sessions)
    # mean_A=1.0, mean_B=0.0; sample SD = sqrt(((1-0.5)^2 + (0-0.5)^2)/1) = 0.707
    assert_in_delta 0.707, result['pair_discussion_size_2'][:sd], 0.001
  end

  def test_returns_zero_sd_for_single_discussion
    single_sessions = {
      'pair_discussion_size_2' => [
        session_row(learner_id: 'l1', condition: 'pair_discussion_size_2', transcript_json: @t_a),
        session_row(learner_id: 'l2', condition: 'pair_discussion_size_2', transcript_json: @t_a)
      ]
    }
    single_rows = [
      score_row(learner_id: 'l1', condition: 'pair_discussion_size_2', answer_correct: true),
      score_row(learner_id: 'l2', condition: 'pair_discussion_size_2', answer_correct: false)
    ]
    result = Report.send(:discussion_level_variance_by_condition, single_rows, single_sessions)
    assert_equal 0.0, result['pair_discussion_size_2'][:sd]
    assert_equal 1,   result['pair_discussion_size_2'][:n]
  end
end
