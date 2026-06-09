# ABOUTME: Tests that SizedDiscussion injects learner_memories into participant context
# ABOUTME: Uses LLM stub with callable to capture prompt text for assertion

$LOAD_PATH.unshift File.join(__dir__, '..', 'lib')
require 'minitest/autorun'
require 'phases/sized_discussion'

class TestSizedDiscussionMemoryInjection < Minitest::Test
  CONFIG = { 'models' => { 'teacher' => 'model', 'learner' => 'model' } }.freeze

  SAMPLE_MEMORY = {
    'rules'                    => ['Yellow is always active (7 pts)', 'Red doubles next token'],
    'examples'                 => ['[Red, Yellow] => 14'],
    'edge_cases'               => ['Green inactive at end position'],
    'strategy'                 => ['Check activation before applying modifiers'],
    'corrected_misconceptions' => [],
    'remaining_misconceptions' => [],
    'uncertain_rules'          => []
  }.freeze

  def run_with_capture(learner_memories: {})
    captured_prompts = []
    stub_val = ->(prompt, **_kwargs) { captured_prompts << prompt; 'stub response' }
    LLM.stub(:call, stub_val) do
      Phases::SizedDiscussion.run(
        condition: 'pair_discussion_size_2',
        learner_ids: %w[l1 l2],
        moderator_id: 'mod1',
        moderator_prompt: 'mod sys',
        participant_prompt: 'participant sys',
        lesson: 'lesson text',
        config: CONFIG,
        learner_memories: learner_memories
      )
    end
    captured_prompts
  end

  def test_without_memories_does_not_include_learning_memory_header
    prompts = run_with_capture(learner_memories: {})
    contrib_prompts = prompts.select { |p| p.include?('Contribute your reasoning') }
    refute_empty contrib_prompts
    contrib_prompts.each do |p|
      refute_includes p, 'YOUR LEARNING MEMORY'
    end
  end

  def test_with_memories_injects_learning_memory_into_contrib_prompt
    prompts = run_with_capture(learner_memories: { 'l1' => SAMPLE_MEMORY, 'l2' => SAMPLE_MEMORY })
    contrib_prompts = prompts.select { |p| p.include?('Contribute your reasoning') }
    refute_empty contrib_prompts
    assert contrib_prompts.any? { |p| p.include?('YOUR LEARNING MEMORY') },
           'Expected at least one contribution prompt to include YOUR LEARNING MEMORY'
  end

  def test_memory_content_appears_in_contrib_prompt
    prompts = run_with_capture(learner_memories: { 'l1' => SAMPLE_MEMORY, 'l2' => SAMPLE_MEMORY })
    contrib_prompts = prompts.select { |p| p.include?('Contribute your reasoning') }
    assert contrib_prompts.any? { |p| p.include?('Yellow is always active') },
           'Expected memory rule text to appear in contribution prompt'
  end

  def test_reply_prompt_injects_memory_when_provided
    prompts = run_with_capture(learner_memories: { 'l1' => SAMPLE_MEMORY, 'l2' => SAMPLE_MEMORY })
    reply_prompts = prompts.select { |p| p.include?('Respond to your partner') }
    refute_empty reply_prompts
    assert reply_prompts.any? { |p| p.include?('YOUR LEARNING MEMORY') },
           'Expected reply prompts to include YOUR LEARNING MEMORY'
  end
end
