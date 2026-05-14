# ABOUTME: TDD tests for Report.classify_task_type pure function
# ABOUTME: Tests all four classification outcomes with boundary cases

$LOAD_PATH.unshift File.join(__dir__, '..', 'lib')
require 'minitest/autorun'
require 'json'
require 'report'

class TestClassifyTaskType < Minitest::Test
  def classify(no_ed, classroom, tutoring)
    Report.classify_task_type(no_ed, classroom, tutoring, threshold: 0.9)
  end

  def test_too_easy_when_all_at_or_above_threshold
    assert_equal 'too_easy', classify(1.0, 1.0, 1.0)
    assert_equal 'too_easy', classify(0.9, 0.95, 1.0)
    assert_equal 'too_easy', classify(0.9, 0.9, 0.9)
  end

  def test_too_hard_when_all_below_30_percent
    assert_equal 'too_hard', classify(0.0, 0.0, 0.0)
    assert_equal 'too_hard', classify(0.1, 0.2, 0.29)
  end

  def test_condition_sensitive_when_tutoring_diverges_from_classroom
    assert_equal 'condition_sensitive', classify(0.2, 0.5, 0.85)
  end

  def test_education_sensitive_when_edu_helps_but_conditions_similar
    assert_equal 'education_sensitive', classify(0.1, 0.75, 0.80)
  end

  def test_education_sensitive_when_only_classroom_helps
    assert_equal 'education_sensitive', classify(0.1, 0.8, 0.3)
  end

  def test_unclear_when_no_strong_signal
    assert_equal 'unclear', classify(0.5, 0.55, 0.6)
  end

  def test_condition_sensitive_requires_education_to_also_help
    assert_equal 'unclear', classify(0.8, 0.5, 0.9)
  end
end

class TestDetectCeiling3Conditions < Minitest::Test
  def make_rows(condition, task_type, task_id, answer_correct)
    Array.new(2) do
      {
        'condition' => condition,
        'task_type' => task_type,
        'task_id'   => task_id,
        'score_json' => JSON.dump({ 'answer_correct' => answer_correct, 'total' => answer_correct ? 4 : 0 })
      }
    end
  end

  def test_ceiling_flagged_when_all_three_conditions_score_high
    rows = make_rows('no_education', 'recall', 'l1_recall_01', true) +
           make_rows('classroom',    'recall', 'l1_recall_01', true) +
           make_rows('1on1',         'recall', 'l1_recall_01', true)
    config = { 'experiment' => { 'ceiling_threshold' => 0.9 } }
    result = Report.detect_ceiling(rows, config)
    assert_equal 1, result.size
    assert_equal true, result.first[:ceiling_effect]
    assert_equal 'too_easy', result.first[:classification]
  end

  def test_no_ceiling_when_no_education_scores_low
    rows = make_rows('no_education', 'debugging', 'l4_debug_01', false) +
           make_rows('classroom',    'debugging', 'l4_debug_01', true)  +
           make_rows('1on1',         'debugging', 'l4_debug_01', true)
    config = { 'experiment' => { 'ceiling_threshold' => 0.9 } }
    result = Report.detect_ceiling(rows, config)
    assert_equal false, result.first[:ceiling_effect]
    refute_equal 'too_easy', result.first[:classification]
  end
end
