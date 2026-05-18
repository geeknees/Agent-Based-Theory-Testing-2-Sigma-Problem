# ABOUTME: Tests for LearnerTypes module — 7 type definitions and behavioral constraint helpers
# ABOUTME: No LLM calls; purely deterministic type definitions and constraint application

$LOAD_PATH.unshift File.join(__dir__, '..', 'lib')
require 'minitest/autorun'
require 'learner_types'

class TestLearnerTypeDefinitions < Minitest::Test
  def test_all_seven_types_defined
    expected = %i[rule_extractor example_memorizer edge_case_dropper order_confused
                  answer_first help_seeker passive_listener]
    expected.each { |t| assert LearnerTypes::TYPES.key?(t), "Missing type: #{t}" }
    assert_equal 7, LearnerTypes::TYPES.size
  end

  def test_each_type_has_required_keys
    LearnerTypes::TYPES.each do |name, attrs|
      LearnerTypes::REQUIRED_KEYS.each do |key|
        assert attrs.key?(key), "Type #{name} missing key: #{key}"
      end
    end
  end

  def test_homogeneous_assignment_is_four_edge_case_droppers
    assert_equal 4, LearnerTypes::HOMOGENEOUS_ASSIGNMENT.size
    assert LearnerTypes::HOMOGENEOUS_ASSIGNMENT.all? { |t| t == :edge_case_dropper }
  end

  def test_heterogeneous_assignment_has_four_distinct_types
    assert_equal 4, LearnerTypes::HETEROGENEOUS_ASSIGNMENT.size
    assert_includes LearnerTypes::HETEROGENEOUS_ASSIGNMENT, :rule_extractor
    assert_includes LearnerTypes::HETEROGENEOUS_ASSIGNMENT, :edge_case_dropper
    assert_includes LearnerTypes::HETEROGENEOUS_ASSIGNMENT, :order_confused
    assert_includes LearnerTypes::HETEROGENEOUS_ASSIGNMENT, :passive_listener
  end

  def test_fetch_raises_on_unknown_type
    assert_raises(ArgumentError) { LearnerTypes.fetch(:nonexistent) }
  end

  def test_fetch_works_with_string_key
    type = LearnerTypes.fetch('rule_extractor')
    assert_equal 150, type[:memory_budget_words]
  end
end

class TestShouldAskQuestion < Minitest::Test
  def test_passive_listener_never_asks
    100.times { refute LearnerTypes.should_ask_question?(:passive_listener) }
  end

  def test_help_seeker_almost_always_asks
    results = 100.times.map { LearnerTypes.should_ask_question?(:help_seeker) }
    assert results.count(true) >= 80, "help_seeker should ask >=80% (prob=0.9), got #{results.count(true)}"
  end

  def test_answer_first_rarely_asks
    results = 100.times.map { LearnerTypes.should_ask_question?(:answer_first) }
    assert results.count(true) <= 30, "answer_first should ask <=30% (prob=0.1), got #{results.count(true)}"
  end
end

class TestApplyConstraints < Minitest::Test
  def base_memory
    {
      'rules'                    => %w[rule1 rule2 rule3 rule4 rule5],
      'examples'                 => ['example1 long text here', 'example2 another one'],
      'edge_cases'               => ['edge1 boundary', 'edge2 exception', 'edge3 special'],
      'strategy'                 => ['step A first', 'step B second'],
      'corrected_misconceptions' => [],
      'remaining_misconceptions' => [],
      'uncertain_rules'          => []
    }
  end

  def test_edge_case_dropper_drops_most_edge_cases
    srand(42)
    result = LearnerTypes.apply_constraints(base_memory, :edge_case_dropper)
    assert result['edge_cases'].size < 3, "edge_case_dropper should drop most edge cases, kept #{result['edge_cases'].size}"
  end

  def test_rule_extractor_keeps_most_edge_cases
    srand(42)
    result = LearnerTypes.apply_constraints(base_memory, :rule_extractor)
    assert result['edge_cases'].size >= 2, "rule_extractor should keep most edge cases, kept #{result['edge_cases'].size}"
  end

  def test_apply_constraints_does_not_mutate_original
    original           = base_memory
    original_edge_copy = original['edge_cases'].dup
    LearnerTypes.apply_constraints(original, :edge_case_dropper)
    assert_equal original_edge_copy, original['edge_cases'], "apply_constraints must not mutate original"
  end

  def test_trim_to_budget_respects_word_limit
    big_memory = {
      'rules'                    => Array.new(20, 'a very long rule about tokens and positions here'),
      'examples'                 => Array.new(10, 'worked example with many steps involved'),
      'edge_cases'               => Array.new(10, 'tricky edge condition to remember carefully'),
      'strategy'                 => Array.new(5, 'step to follow exactly'),
      'corrected_misconceptions' => [],
      'remaining_misconceptions' => [],
      'uncertain_rules'          => []
    }
    result = LearnerTypes.trim_to_budget(big_memory, 80)
    assert LearnerTypes.word_count(result) <= 80, "Expected <=80 words, got #{LearnerTypes.word_count(result)}"
  end

  def test_passive_listener_budget_is_80
    type = LearnerTypes.fetch(:passive_listener)
    assert_equal 80, type[:memory_budget_words]
  end

  def test_to_prompt_context_includes_type_name
    text = LearnerTypes.to_prompt_context(:edge_case_dropper)
    assert_includes text, 'edge_case_dropper'
  end
end
