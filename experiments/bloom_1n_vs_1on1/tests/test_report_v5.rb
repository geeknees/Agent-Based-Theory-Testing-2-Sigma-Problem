# ABOUTME: TDD tests for v5 report additions — profile-based grouping and heterogeneity interpretation
# ABOUTME: Tests pure functions only; no DB or LLM calls

$LOAD_PATH.unshift File.join(__dir__, '..', 'lib')
require 'minitest/autorun'
require 'json'
require 'securerandom'
require 'report'

class TestScoreByProfileDimension < Minitest::Test
  def make_row(condition, answer_correct, ability: 'medium', misconception: 'none', interest: 'worked_examples')
    profile = { 'ability' => ability, 'misconception' => misconception, 'interest' => interest }
    {
      'condition'    => condition,
      'task_type'    => 'recall',
      'task_id'      => 'l1_recall_01',
      'learner_id'   => SecureRandom.uuid,
      'score_json'   => JSON.dump({ 'answer_correct' => answer_correct, 'total' => answer_correct ? 4 : 0 }),
      'profile_json' => JSON.dump(profile)
    }
  end

  def test_groups_by_ability_correctly
    rows = [
      make_row('1on1', true,  ability: 'high'),
      make_row('1on1', false, ability: 'low'),
      make_row('1on1', true,  ability: 'high'),
    ]
    result = Report.score_by_profile_dimension(rows, 'ability')
    assert_in_delta 1.0, result['high'], 0.01
    assert_in_delta 0.0, result['low'],  0.01
  end

  def test_returns_zero_for_no_matching_rows
    rows = [make_row('1on1', true, ability: 'high')]
    result = Report.score_by_profile_dimension(rows, 'ability')
    assert_equal 0.0, result.fetch('low', 0.0)
  end

  def test_handles_nil_profile_json
    row = make_row('1on1', true)
    row['profile_json'] = nil
    result = Report.score_by_profile_dimension([row], 'ability')
    assert result.key?('unknown')
  end
end

class TestScoreVarianceByCondition < Minitest::Test
  def rows_for_learner(condition, learner_id, correct_count, total: 4)
    Array.new(total) do |i|
      {
        'condition'    => condition,
        'learner_id'   => learner_id,
        'task_id'      => "task_#{i}",
        'task_type'    => 'recall',
        'score_json'   => JSON.dump({ 'answer_correct' => i < correct_count, 'total' => i < correct_count ? 4 : 0 }),
        'profile_json' => nil
      }
    end
  end

  def test_zero_variance_when_single_learner
    rows = rows_for_learner('classroom', 'learner_a', 2)
    result = Report.score_variance_by_condition(rows)
    assert_equal 0.0, result['classroom']
  end

  def test_nonzero_variance_when_learners_differ
    rows = rows_for_learner('classroom', 'learner_a', 4) +
           rows_for_learner('classroom', 'learner_b', 0)
    result = Report.score_variance_by_condition(rows)
    assert result['classroom'] > 0.3, "Expected significant variance, got #{result['classroom']}"
  end
end

class TestHeterogeneityInterpretation < Minitest::Test
  def make_rows(condition, answer_correct_pattern, ability: 'medium')
    answer_correct_pattern.each_with_index.map do |correct, i|
      {
        'condition'    => condition,
        'learner_id'   => "#{condition}_#{i}",
        'task_id'      => 'l1_recall_01',
        'task_type'    => 'recall',
        'score_json'   => JSON.dump({ 'answer_correct' => correct }),
        'profile_json' => JSON.dump({ 'ability' => ability })
      }
    end
  end

  def test_tutoring_advantage_under_heterogeneity
    rows = make_rows('1on1',                     [true, true, true, false]) +
           make_rows('heterogeneous_classroom',   [false, false, true, false]) +
           make_rows('homogeneous_classroom',     [true, false, true, false]) +
           make_rows('no_education',              [false, false, false, false])
    result = Report.heterogeneity_interpretation(rows, {})
    assert_includes result, 'tutoring_advantage_under_heterogeneity'
  end

  def test_heterogeneity_penalty_when_mixed_class_underperforms
    rows = make_rows('homogeneous_classroom',    [true, true, true, false]) +
           make_rows('heterogeneous_classroom',  [false, false, false, true]) +
           make_rows('1on1',                    [true, false, true, false]) +
           make_rows('no_education',             [false, false, false, false])
    result = Report.heterogeneity_interpretation(rows, {})
    assert_includes result, 'heterogeneity_penalty'
  end

  def test_classroom_advantage_under_homogeneity
    rows = make_rows('homogeneous_classroom',   [true, true, true, true]) +
           make_rows('1on1',                   [true, false, false, false]) +
           make_rows('heterogeneous_classroom', [true, false, true, false]) +
           make_rows('no_education',            [false, false, false, false])
    result = Report.heterogeneity_interpretation(rows, {})
    assert_includes result, 'classroom_advantage_under_homogeneity'
  end
end

class TestTokenPerCorrectAnswer < Minitest::Test
  def make_row(answer_correct)
    {
      'condition'  => 'classroom',
      'learner_id' => SecureRandom.uuid,
      'score_json' => JSON.dump({ 'answer_correct' => answer_correct })
    }
  end

  def test_returns_tokens_divided_by_correct
    rows = [make_row(true), make_row(false), make_row(true)]
    token_summary = {
      'evaluation' => { 'total_tokens' => 1000 },
      'memory'     => { 'total_tokens' => 500 }
    }
    result = Report.token_per_correct_answer(rows, token_summary)
    assert_equal 750, result  # 1500 tokens / 2 correct
  end

  def test_returns_zero_when_no_correct
    rows = [make_row(false)]
    result = Report.token_per_correct_answer(rows, { 'eval' => { 'total_tokens' => 100 } })
    assert_equal 0, result
  end
end
