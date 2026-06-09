# ABOUTME: Tests for SelfReflection phase — structural tests using LLM stub
# ABOUTME: Verifies turn structure, condition field, and memory injection into prompt

$LOAD_PATH.unshift File.join(__dir__, '..', 'lib')
require 'minitest/autorun'
require 'phases/self_reflection'

class TestSelfReflection < Minitest::Test
  CONFIG = { 'models' => { 'learner' => 'model' } }.freeze

  SAMPLE_MEMORY = {
    'rules'                    => ['Yellow is always active'],
    'examples'                 => [],
    'edge_cases'               => [],
    'strategy'                 => [],
    'corrected_misconceptions' => [],
    'remaining_misconceptions' => [],
    'uncertain_rules'          => []
  }.freeze

  def run_with_capture(memory: SAMPLE_MEMORY, learner_type_key: nil)
    captured = []
    LLM.stub(:call, ->(prompt, **_kwargs) { captured << prompt; 'stub reflection' }) do
      result = Phases::SelfReflection.run(
        learner_id: 'l-001',
        memory: memory,
        reflection_prompt: 'reflect sys',
        lesson: 'lesson text',
        config: CONFIG,
        learner_type_key: learner_type_key
      )
      [result, captured]
    end
  end

  def test_condition_is_lecture_only
    result, _ = run_with_capture
    assert_equal 'lecture_only', result['condition']
  end

  def test_has_one_reflection_note_turn
    result, _ = run_with_capture
    assert_equal 1, result['turns'].size
    assert_equal 'reflection_note', result['turns'].first['type']
  end

  def test_turn_speaker_is_learner_id
    result, _ = run_with_capture
    assert_equal 'l-001', result['turns'].first['speaker']
  end

  def test_memory_content_injected_into_prompt
    _, captured = run_with_capture(memory: SAMPLE_MEMORY)
    assert captured.any? { |p| p.include?('YOUR LEARNING MEMORY') },
           'Expected YOUR LEARNING MEMORY in prompt'
    assert captured.any? { |p| p.include?('Yellow is always active') },
           'Expected memory rule content in prompt'
  end

  def test_learner_type_injected_when_provided
    _, captured = run_with_capture(memory: SAMPLE_MEMORY, learner_type_key: 'rule_extractor')
    assert captured.any? { |p| p.include?('rule_extractor') },
           'Expected learner_type_key in prompt when provided'
  end

  def test_discussion_problem_included_in_instruction
    _, captured = run_with_capture
    assert captured.any? { |p| p.include?('Red, Green, Blue, Yellow') },
           'Expected DISCUSSION_PROBLEM in instruction'
  end
end
