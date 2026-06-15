# ABOUTME: Tests for v9c2-specific report sections: L6 appendix (A8), token-normalized score, baseline detection
# ABOUTME: Pure function tests — no LLM or DB calls

$LOAD_PATH.unshift File.join(__dir__, '..', 'lib')
require 'minitest/autorun'
require 'json'
require 'report'

class TestL6ExclusionSection < Minitest::Test
  def make_row(task_id:, answer_correct:, condition: 'pair_discussion_size_2')
    {
      'learner_id'     => 'l-001',
      'condition'      => condition,
      'task_id'        => task_id,
      'task_type'      => 'calculation',
      'answer_correct' => answer_correct,
      'score_json'     => JSON.dump({ 'answer_correct' => answer_correct, 'total' => answer_correct ? 1 : 0 })
    }
  end

  def all_rows
    [
      make_row(task_id: 'l1_calc_01', answer_correct: true),
      make_row(task_id: 'l3_calc_03', answer_correct: true),
      make_row(task_id: 'l6_induction_02', answer_correct: false)
    ]
  end

  def test_l6_rows_section_contains_l6_task_id
    section = Report.send(:l6_rows_section, all_rows)
    assert_includes section, 'l6_induction_02'
  end

  def test_l6_rows_section_includes_llm_scoring_note
    section = Report.send(:l6_rows_section, all_rows)
    assert_includes section, 'LLM'
  end

  def test_l6_rows_section_explains_scorer_artifact
    section = Report.send(:l6_rows_section, all_rows)
    assert_includes section, 'scorer'
  end

  def test_core_rows_excludes_l6
    core = Report.send(:core_rows, all_rows)
    task_ids = core.map { |r| r['task_id'] }
    refute_includes task_ids, 'l6_induction_02'
    assert_includes task_ids, 'l1_calc_01'
    assert_includes task_ids, 'l3_calc_03'
  end

  def test_core_rows_returns_all_rows_when_no_l6
    rows = [
      make_row(task_id: 'l1_calc_01', answer_correct: true),
      make_row(task_id: 'l4_calc_04', answer_correct: false)
    ]
    assert_equal rows, Report.send(:core_rows, rows)
  end
end

class TestTokenNormalizedSection < Minitest::Test
  def make_row(condition:, answer_correct:)
    {
      'learner_id'  => 'l-001',
      'condition'   => condition,
      'task_id'     => 'l1_calc_01',
      'task_type'   => 'calculation',
      'score_json'  => JSON.dump({ 'answer_correct' => answer_correct, 'total' => answer_correct ? 4 : 0 })
    }
  end

  def scored_rows
    [
      make_row(condition: 'lecture_plus_self_reflection', answer_correct: true),
      make_row(condition: 'pair_discussion_size_2',       answer_correct: true),
      make_row(condition: 'pair_discussion_size_2',       answer_correct: false)
    ]
  end

  def by_condition
    scored_rows.group_by { |r| r['condition'] }
  end

  def token_summary
    {
      'education_lecture_plus_self_reflection' => { 'total_tokens' => 1000 },
      'education_pair_discussion_size_2'       => { 'total_tokens' => 4000 }
    }
  end

  def test_section_contains_condition_names
    section = Report.send(:token_normalized_section, scored_rows, token_summary, by_condition)
    assert_includes section, 'lecture_plus_self_reflection'
    assert_includes section, 'pair_discussion_size_2'
  end

  def test_section_shows_edu_tokens
    section = Report.send(:token_normalized_section, scored_rows, token_summary, by_condition)
    assert_includes section, '1000'
    assert_includes section, '4000'
  end

  def test_section_shows_correct_per_1k
    section = Report.send(:token_normalized_section, scored_rows, token_summary, by_condition)
    # lecture: 1 correct / 1000 tokens * 1000 = 1.00
    assert_includes section, '1.00'
    # pair: 1 correct / 4000 tokens * 1000 = 0.25
    assert_includes section, '0.25'
  end

  def test_section_shows_dash_for_missing_edu_tokens
    summary = {}  # no education tokens
    section = Report.send(:token_normalized_section, scored_rows, summary, by_condition)
    assert_includes section, '—'
  end
end

class TestBaselineConditionKey < Minitest::Test
  def test_finds_no_education
    score_by_cond = { 'no_education' => 0.5, 'classroom' => 0.7 }
    assert_equal 'no_education', Report.send(:baseline_condition_key, score_by_cond)
  end

  def test_finds_lecture_only
    score_by_cond = { 'lecture_only' => 0.8, 'pair_discussion_size_2' => 0.7 }
    assert_equal 'lecture_only', Report.send(:baseline_condition_key, score_by_cond)
  end

  def test_finds_lecture_plus_self_reflection
    score_by_cond = { 'lecture_plus_self_reflection' => 0.83, 'pair_discussion_size_2' => 0.80 }
    assert_equal 'lecture_plus_self_reflection', Report.send(:baseline_condition_key, score_by_cond)
  end

  def test_returns_nil_when_no_baseline_present
    score_by_cond = { 'classroom' => 0.7, '1on1' => 0.8 }
    assert_nil Report.send(:baseline_condition_key, score_by_cond)
  end
end

class TestScoreByTaskTypeV9c2 < Minitest::Test
  def make_row(condition:, task_id:, task_type:, answer_correct:)
    {
      'learner_id' => 'l-001',
      'condition'  => condition,
      'task_id'    => task_id,
      'task_type'  => task_type,
      'score_json' => JSON.dump({ 'answer_correct' => answer_correct, 'total' => answer_correct ? 4 : 0 })
    }
  end

  def v9c2_rows
    conds = %w[lecture_plus_self_reflection pair_discussion_size_2 medium_class_discussion_size_8]
    conds.flat_map do |c|
      [
        make_row(condition: c, task_id: 'l1_recall_01',       task_type: 'recall',    answer_correct: true),
        make_row(condition: c, task_id: 'l4_debug_01',        task_type: 'debugging', answer_correct: false)
      ]
    end
  end

  def test_score_by_task_type_shows_all_v9c2_conditions
    conditions = v9c2_rows.map { |r| r['condition'] }.uniq.sort
    section = Report.send(:score_by_task_type_v9b, v9c2_rows, conditions)
    assert_includes section, 'lecture_plus_self_reflection'
    assert_includes section, 'pair_discussion_size_2'
    assert_includes section, 'medium_class_discussion_size_8'
  end
end
