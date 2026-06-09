# ABOUTME: Tests for v9c2-specific report sections: L6 exclusion appendix (A8)
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

  def test_l6_rows_section_includes_exploratory_disclaimer
    section = Report.send(:l6_rows_section, all_rows)
    assert_includes section, 'exploratory'
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
