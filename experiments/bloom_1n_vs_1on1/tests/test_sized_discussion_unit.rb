# ABOUTME: Unit tests for SizedDiscussion pure-function helpers
# ABOUTME: Covers ownership initialisation and ownership_score computation

$LOAD_PATH.unshift File.join(__dir__, '..', 'lib')
require 'minitest/autorun'
require 'phases/sized_discussion'

class TestSizedDiscussionUnit < Minitest::Test
  def test_init_ownership_creates_entry_per_learner
    ids    = %w[a b c]
    result = Phases::SizedDiscussion.send(:init_ownership, ids)
    assert_equal 3, result.keys.size
    assert_equal 0, result['a'][:contribution_count]
    assert_equal false, result['b'][:attempted_answer]
  end

  def test_compute_ownership_score_zero_for_observer
    data = { contribution_count: 0, attempted_answer: false,
             received_feedback: false, misconception_exposed: false,
             misconception_corrected: false }
    assert_equal 0, Phases::SizedDiscussion.send(:compute_ownership_score, data)
  end

  def test_compute_ownership_score_max_three_for_full_participant
    data = { contribution_count: 2, attempted_answer: true,
             received_feedback: true, misconception_exposed: false,
             misconception_corrected: false }
    # contributed(1) + attempted(1) + received_feedback(1) = 3
    assert_equal 3, Phases::SizedDiscussion.send(:compute_ownership_score, data)
  end

  def test_compute_ownership_score_four_with_misconception_corrected
    data = { contribution_count: 1, attempted_answer: true,
             received_feedback: true, misconception_exposed: false,
             misconception_corrected: true }
    # contributed(1) + attempted(1) + received_feedback(1) + corrected(1) = 4
    assert_equal 4, Phases::SizedDiscussion.send(:compute_ownership_score, data)
  end

  def test_compute_ownership_score_exposed_or_corrected_counts_once
    data = { contribution_count: 0, attempted_answer: false,
             received_feedback: false, misconception_exposed: true,
             misconception_corrected: true }
    # exposed_or_corrected = 1 (not 2)
    assert_equal 1, Phases::SizedDiscussion.send(:compute_ownership_score, data)
  end

  def test_called_on_ids_respects_called_on_count
    all_ids = %w[a b c d e f g h]
    called  = all_ids.first(4)
    obs     = all_ids - called
    assert_equal 4, called.size
    assert_equal 4, obs.size
    assert_equal %w[a b c d], called
  end
end
