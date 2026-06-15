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

class TestDetectCeilingV9c2Conditions < Minitest::Test
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

  def v9c2_rows(answer_correct)
    make_rows('lecture_plus_self_reflection', 'recall', 'l1_recall_01', answer_correct) +
    make_rows('pair_discussion_size_2',       'recall', 'l1_recall_01', answer_correct) +
    make_rows('medium_class_discussion_size_8','recall', 'l1_recall_01', answer_correct)
  end

  def test_v9c2_baseline_is_lecture_plus_self_reflection
    rows   = v9c2_rows(true)
    config = { 'experiment' => { 'ceiling_threshold' => 0.9 } }
    result = Report.detect_ceiling(rows, config)
    assert_in_delta 1.0, result.first[:no_ed_pct], 0.01,
      'lecture_plus_self_reflection should map to no_ed_pct'
  end

  def test_v9c2_discussion_conditions_map_to_classroom_pct
    rows   = v9c2_rows(true)
    config = { 'experiment' => { 'ceiling_threshold' => 0.9 } }
    result = Report.detect_ceiling(rows, config)
    assert_in_delta 1.0, result.first[:classroom_pct], 0.01,
      '_discussion_size_ conditions should map to classroom_pct'
  end

  def test_v9c2_nonzero_pct_not_too_hard
    rows   = v9c2_rows(true)
    config = { 'experiment' => { 'ceiling_threshold' => 0.9 } }
    result = Report.detect_ceiling(rows, config)
    refute_equal 'too_hard', result.first[:classification]
  end

  def test_lecture_only_as_no_ed_fallback
    rows = make_rows('lecture_only',            'recall', 'l1_recall_01', true) +
           make_rows('pair_discussion_size_2',  'recall', 'l1_recall_01', true)
    config = { 'experiment' => { 'ceiling_threshold' => 0.9 } }
    result = Report.detect_ceiling(rows, config)
    assert_in_delta 1.0, result.first[:no_ed_pct], 0.01,
      'lecture_only should map to no_ed_pct when no_education is absent'
  end
end
