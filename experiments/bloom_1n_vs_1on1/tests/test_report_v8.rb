# ABOUTME: Tests for v8 report extensions — mastery check scores, memory coverage, discussion metrics
# ABOUTME: Pure function tests; no DB or LLM calls

$LOAD_PATH.unshift File.join(__dir__, '..', 'lib')
require 'minitest/autorun'
require 'json'
require 'securerandom'
require 'report'

class TestReportV8MasterySection < Minitest::Test
  def make_mastery_row(learner_id, check_type, correct)
    { 'learner_id' => learner_id, 'check_type' => check_type, 'answer_correct' => correct ? 1 : 0 }
  end

  def test_mastery_check_section_shows_pass_rate_per_type
    rows = [
      make_mastery_row('l1', 'recall', true),
      make_mastery_row('l2', 'recall', false),
      make_mastery_row('l1', 'edge_case', true),
      make_mastery_row('l2', 'edge_case', true),
    ]
    section = Report.mastery_check_section(rows)
    assert_includes section, 'recall'
    assert_includes section, 'edge_case'
    assert_includes section, '50%'   # recall: 1/2 correct
    assert_includes section, '100%'  # edge_case: 2/2 correct
  end

  def test_mastery_check_section_empty_for_no_rows
    assert_equal '', Report.mastery_check_section([])
  end
end

class TestReportV8MemoryCoverage < Minitest::Test
  def make_memory(rules: [], edge_cases: [], strategy: [])
    { 'rules' => rules, 'edge_cases' => edge_cases, 'strategy' => strategy,
      'examples' => [], 'corrected_misconceptions' => [],
      'remaining_misconceptions' => [], 'uncertain_rules' => [] }
  end

  def test_memory_coverage_counts_rules
    mem = make_memory(rules: ['rule1', 'rule2', 'rule3'])
    cov = Report.memory_coverage(mem)
    assert_equal 3, cov[:rule_count]
  end

  def test_memory_coverage_detects_edge_cases
    mem = make_memory(edge_cases: ['edge1'])
    cov = Report.memory_coverage(mem)
    assert cov[:has_edge_cases]
  end

  def test_memory_coverage_detects_procedure
    mem = make_memory(strategy: ['check activation first'])
    cov = Report.memory_coverage(mem)
    assert cov[:has_procedure]
  end

  def test_memory_coverage_empty_memory
    cov = Report.memory_coverage(make_memory)
    assert_equal 0, cov[:rule_count]
    refute cov[:has_edge_cases]
    refute cov[:has_procedure]
  end
end

class TestReportV8Build < Minitest::Test
  def make_row(condition, correct)
    { 'condition' => condition, 'learner_id' => SecureRandom.uuid,
      'task_id' => 'l1_recall_01', 'task_type' => 'recall',
      'response_text' => 'x',
      'score_json' => JSON.dump({ 'answer_correct' => correct }),
      'profile_json' => JSON.dump({ 'type_key' => 'rule_extractor' }) }
  end

  def test_build_markdown_v8_includes_condition_names
    rows = [
      make_row('lecture_only', true),
      make_row('lecture_plus_whole_class_discussion', false),
      make_row('lecture_plus_small_group_discussion', true),
      make_row('lecture_plus_one_on_one_tutoring', true),
    ]
    config = { 'experiment' => { 'domain' => 'zarn_tokens', 'ceiling_threshold' => 0.9 },
               'models' => { 'teacher' => 'haiku' } }
    md = Report.build_markdown(rows, run_id: 'r1', output_dir: '/tmp', run_config: config,
                               token_summary: {}, experiment_meta: { experiment: 'v8' })
    assert_includes md, 'lecture_only'
    assert_includes md, 'lecture_plus_whole_class_discussion'
    assert_includes md, 'lecture_plus_small_group_discussion'
    assert_includes md, 'lecture_plus_one_on_one_tutoring'
  end
end
