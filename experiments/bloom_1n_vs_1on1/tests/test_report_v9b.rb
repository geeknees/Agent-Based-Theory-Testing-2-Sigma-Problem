# ABOUTME: Tests report.rb v9b sections — ownership summary and memory delta
# ABOUTME: Verifies markdown output for new report blocks

$LOAD_PATH.unshift File.join(__dir__, '..', 'lib')
require 'minitest/autorun'
require 'ownership_metrics'

class TestOwnershipMetrics < Minitest::Test
  def test_summary_by_condition_averages_ownership_score
    rows = [
      { 'condition' => 'pair_discussion_size_2', 'ownership_score' => 3,
        'contribution_count' => 2, 'attempted_answer' => 1, 'received_feedback' => 1,
        'memory_delta_after_discussion' => 2 },
      { 'condition' => 'pair_discussion_size_2', 'ownership_score' => 2,
        'contribution_count' => 1, 'attempted_answer' => 1, 'received_feedback' => 0,
        'memory_delta_after_discussion' => 1 }
    ]
    result = OwnershipMetrics.summary_by_condition(rows)
    assert_in_delta 2.5, result['pair_discussion_size_2'][:avg_ownership_score], 0.01
  end

  def test_summary_by_condition_pct_attempted
    rows = [
      { 'condition' => 'lecture_only', 'ownership_score' => 0,
        'contribution_count' => 0, 'attempted_answer' => 0, 'received_feedback' => 0,
        'memory_delta_after_discussion' => 0 },
      { 'condition' => 'lecture_only', 'ownership_score' => 0,
        'contribution_count' => 0, 'attempted_answer' => 0, 'received_feedback' => 0,
        'memory_delta_after_discussion' => 0 }
    ]
    result = OwnershipMetrics.summary_by_condition(rows)
    assert_in_delta 0.0, result['lecture_only'][:pct_attempted_answer], 0.01
  end

  def test_summary_empty_returns_empty
    assert_equal({}, OwnershipMetrics.summary_by_condition([]))
  end
end

class TestReportOwnershipSection < Minitest::Test
  def ownership_rows
    [
      { 'condition' => 'pair_discussion_size_2', 'ownership_score' => 3,
        'contribution_count' => 2, 'attempted_answer' => 1, 'received_feedback' => 1,
        'memory_delta_after_discussion' => 2 },
      { 'condition' => 'large_class_discussion_size_16', 'ownership_score' => 0,
        'contribution_count' => 0, 'attempted_answer' => 0, 'received_feedback' => 0,
        'memory_delta_after_discussion' => 0 }
    ]
  end

  def test_ownership_section_contains_condition_names
    require 'report'
    section = Report.send(:ownership_section, ownership_rows)
    assert_includes section, 'pair_discussion_size_2'
    assert_includes section, 'large_class_discussion_size_16'
  end

  def test_ownership_section_contains_ownership_score
    require 'report'
    section = Report.send(:ownership_section, ownership_rows)
    assert_includes section, 'Avg Ownership Score'
  end

  def test_memory_delta_section_contains_avg_delta
    require 'report'
    section = Report.send(:memory_delta_section, ownership_rows)
    assert_includes section, 'Memory Delta'
  end
end
