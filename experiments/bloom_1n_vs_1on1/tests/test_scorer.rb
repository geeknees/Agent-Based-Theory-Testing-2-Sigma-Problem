# ABOUTME: Tests for the Scorer auto-scoring module and TokenTracker
# ABOUTME: No LLM calls; all deterministic inputs and outputs

$LOAD_PATH.unshift File.join(__dir__, '..', 'lib')
require 'minitest/autorun'
require 'token_tracker'

class TestTokenTracker < Minitest::Test
  def test_tracks_single_call
    t = TokenTracker.new
    t.track('education', 'a' * 400, 'b' * 200)
    summary = t.summary
    assert_equal 100, summary['education']['input_tokens']
    assert_equal 50,  summary['education']['output_tokens']
    assert_equal 150, summary['education']['total_tokens']
  end

  def test_accumulates_same_phase
    t = TokenTracker.new
    t.track('education', 'a' * 400, 'b' * 200)
    t.track('education', 'c' * 400, 'd' * 200)
    assert_equal 300, t.summary['education']['total_tokens']
  end

  def test_separate_phases_are_independent
    t = TokenTracker.new
    t.track('education', 'a' * 400, 'b' * 200)
    t.track('memory',    'c' * 800, 'd' * 100)
    assert_equal 150, t.total_for_phase('education')
    assert_equal 225, t.total_for_phase('memory')
  end

  def test_grand_total_sums_all_phases
    t = TokenTracker.new
    t.track('education', 'a' * 400, 'b' * 200)
    t.track('memory',    'c' * 400, 'd' * 200)
    assert_equal 300, t.grand_total
  end

  def test_unknown_phase_returns_zero
    t = TokenTracker.new
    assert_equal 0, t.total_for_phase('nonexistent')
  end
end

require 'scorer'

class TestScorerCorrectAnswer < Minitest::Test
  def recall_task
    {
      'expected_answer' => '14',
      'expected_active_tokens' => ['Green', 'Blue', 'Yellow'],
      'expected_mistakes' => [],
      'acceptable_aliases' => { '14' => ['14 points', 'score: 14'] }
    }
  end

  def test_correct_answer_scores_4
    parsed = { 'answer' => '14', 'active_tokens' => ['Green', 'Blue', 'Yellow'], 'mistakes_found' => [], 'reason' => 'ok' }
    score = Scorer.score_attempt(parsed, recall_task)
    assert_equal true,  score['answer_correct']
    assert_equal 4,     score['correctness']
    assert_equal true,  score['auto_scored']
  end

  def test_wrong_answer_scores_0
    parsed = { 'answer' => '9', 'active_tokens' => [], 'mistakes_found' => [], 'reason' => 'wrong' }
    score = Scorer.score_attempt(parsed, recall_task)
    assert_equal false, score['answer_correct']
    assert_equal 0,     score['correctness']
  end

  def test_alias_is_accepted
    parsed = { 'answer' => '14 points', 'active_tokens' => [], 'mistakes_found' => [], 'reason' => 'ok' }
    score = Scorer.score_attempt(parsed, recall_task)
    assert_equal true, score['answer_correct']
  end

  def test_case_insensitive_answer_match
    parsed = { 'answer' => 'FALSE', 'active_tokens' => [], 'mistakes_found' => [], 'reason' => 'ok' }
    task = { 'expected_answer' => 'false', 'expected_active_tokens' => [], 'expected_mistakes' => [], 'acceptable_aliases' => {} }
    score = Scorer.score_attempt(parsed, task)
    assert_equal true, score['answer_correct']
  end
end

class TestScorerActiveTokens < Minitest::Test
  def test_correct_tokens_scores_4
    parsed = { 'answer' => '14', 'active_tokens' => ['Blue', 'Green', 'Yellow'], 'mistakes_found' => [], 'reason' => 'ok' }
    task = { 'expected_answer' => '14', 'expected_active_tokens' => ['Green', 'Blue', 'Yellow'], 'expected_mistakes' => [], 'acceptable_aliases' => {} }
    score = Scorer.score_attempt(parsed, task)
    assert_equal 4,    score['rule_application']
    assert_equal true, score['active_tokens_correct']
  end

  def test_wrong_tokens_scores_0
    parsed = { 'answer' => '14', 'active_tokens' => ['Red', 'Green'], 'mistakes_found' => [], 'reason' => 'ok' }
    task = { 'expected_answer' => '14', 'expected_active_tokens' => ['Green', 'Blue', 'Yellow'], 'expected_mistakes' => [], 'acceptable_aliases' => {} }
    score = Scorer.score_attempt(parsed, task)
    assert_equal 0,     score['rule_application']
    assert_equal false, score['active_tokens_correct']
  end
end

class TestScorerMistakes < Minitest::Test
  def debug_task
    {
      'expected_answer' => '19',
      'expected_active_tokens' => ['Green', 'Blue', 'Yellow'],
      'expected_mistakes' => ['Green at last position is inactive'],
      'acceptable_aliases' => {}
    }
  end

  def test_mistake_keyword_match_scores_4
    parsed = {
      'answer' => '19',
      'active_tokens' => ['Green', 'Blue', 'Yellow'],
      'mistakes_found' => ['Green at last position is inactive and should be 0'],
      'reason' => 'ok'
    }
    score = Scorer.score_attempt(parsed, debug_task)
    assert score['mistakes_found_ratio'] >= 0.5
    assert_equal 4, score['error_checking']
  end

  def test_missing_mistake_scores_0
    parsed = { 'answer' => '19', 'active_tokens' => [], 'mistakes_found' => [], 'reason' => 'ok' }
    score = Scorer.score_attempt(parsed, debug_task)
    assert_equal 0, score['error_checking']
  end
end

class TestScorerNilInput < Minitest::Test
  def test_nil_response_returns_safe_fallback
    task = { 'expected_answer' => '14', 'expected_active_tokens' => [], 'expected_mistakes' => [], 'acceptable_aliases' => {} }
    score = Scorer.score_attempt(nil, task)
    assert_equal false, score['answer_correct']
    assert_equal 0,     score['total']
    assert_equal true,  score['auto_scored']
    assert_includes     score['comments'], 'parse'
  end

  def test_empty_hash_response_returns_safe_fallback
    task = { 'expected_answer' => '14', 'expected_active_tokens' => [], 'expected_mistakes' => [], 'acceptable_aliases' => {} }
    score = Scorer.score_attempt({}, task)
    assert_equal false, score['answer_correct']
    assert_equal true,  score['auto_scored']
  end
end
