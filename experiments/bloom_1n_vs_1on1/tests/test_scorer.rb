# ABOUTME: Tests for the Scorer auto-scoring module and TokenTracker
# ABOUTME: No LLM calls; all deterministic inputs and outputs

$LOAD_PATH.unshift File.join(__dir__, '..', 'lib')
require 'json'
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

class TestCalibratedConfidence < Minitest::Test
  def make_task
    {
      'expected_answer'        => '3',
      'expected_active_tokens' => ['yellow'],
      'expected_mistakes'      => [],
      'acceptable_aliases'     => {}
    }
  end

  def test_high_confidence_correct_gives_positive_calibration
    parsed = { 'answer' => '3', 'active_tokens' => ['yellow'],
               'mistakes_found' => [], 'confidence' => 0.9, 'abstain' => false }
    score = Scorer.score_attempt(parsed, make_task)
    assert_equal 2, score['calibrated_confidence']
    refute score['high_confidence_wrong']
  end

  def test_high_confidence_wrong_gives_negative_calibration
    parsed = { 'answer' => '5', 'active_tokens' => ['yellow'],
               'mistakes_found' => [], 'confidence' => 0.8, 'abstain' => false }
    score = Scorer.score_attempt(parsed, make_task)
    assert_equal(-2, score['calibrated_confidence'])
    assert score['high_confidence_wrong']
  end

  def test_low_confidence_wrong_gives_zero_calibration
    parsed = { 'answer' => '5', 'active_tokens' => ['yellow'],
               'mistakes_found' => [], 'confidence' => 0.4, 'abstain' => false }
    score = Scorer.score_attempt(parsed, make_task)
    assert_equal 0, score['calibrated_confidence']
    refute score['high_confidence_wrong']
  end

  def test_abstained_response_marked_wrong_with_abstain_flag
    parsed = { 'answer' => '', 'active_tokens' => [],
               'mistakes_found' => [], 'confidence' => 0.2, 'abstain' => true }
    score = Scorer.score_attempt(parsed, make_task)
    refute score['answer_correct']
    assert score['abstained']
    assert_equal 1, score['abstention_quality']
  end

  def test_missing_confidence_defaults_to_zero
    parsed = { 'answer' => '3', 'active_tokens' => ['yellow'], 'mistakes_found' => [] }
    score = Scorer.score_attempt(parsed, make_task)
    assert_equal 0.0, score['confidence']
  end
end

class TestScorer < Minitest::Test
  def test_l6_induction_accepts_real_learner_paraphrases
    domain_path = File.expand_path('../domains/zarn_tokens', __dir__)
    eval_tasks  = JSON.parse(File.read(File.join(domain_path, 'eval_tasks_v8.json')))
    task        = eval_tasks.find { |t| t['id'] == 'l6_induction_02' }

    # Verbatim answers pulled from v9c run b412cfdb-...; auto-scorer marked all of these
    # as incorrect (correctness: 0) despite being semantically equivalent to expected_answer.
    real_paraphrases = [
      'Red contributes 0; doubles the base value of the next token only.',
      'Red doubles the base value of the immediately next token; Red itself scores 0.',
      "Red doubles the next token's value; contributes 0 itself."
    ]

    real_paraphrases.each do |answer|
      parsed = { 'answer' => answer, 'active_tokens' => [], 'mistakes_found' => [], 'reason' => 'test' }
      score  = Scorer.score_attempt(parsed, task)
      assert score['answer_correct'],
        "Expected paraphrase to score correct: #{answer.inspect}\n" \
        "  expected_answer: #{task['expected_answer'].inspect}\n" \
        "  aliases checked: #{task['acceptable_aliases'].inspect}"
    end
  end
end
