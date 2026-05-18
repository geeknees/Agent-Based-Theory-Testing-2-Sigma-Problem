# ABOUTME: Generates compact structured learning memory from each learner's session transcript
# ABOUTME: 7-field schema; applies LearnerTypes constraints post-LLM to enforce cognitive differences

require_relative '../llm'
require_relative '../helpers'
require_relative '../learner_types'

module Phases
  module Memory
    MAX_WORDS = 120
    DEFAULT_MEMORY = {
      'rules'                    => [],
      'examples'                 => [],
      'edge_cases'               => [],
      'strategy'                 => [],
      'corrected_misconceptions' => [],
      'remaining_misconceptions' => [],
      'uncertain_rules'          => []
    }.freeze

    def self.generate(learner_id:, transcript:, summarizer_prompt:, config:, tracker: nil, learner_type_key: nil)
      model     = config.dig('models', 'memory_summarizer') || 'claude-sonnet-4-6'
      max_words = config.dig('experiment', 'max_memory_words') || MAX_WORDS

      if learner_type_key
        type_def  = LearnerTypes.fetch(learner_type_key)
        max_words = type_def[:memory_budget_words]
      end

      transcript_text = Helpers.format_turns_for_prompt(transcript['turns'])

      prompt = Helpers.build_prompt(
        system: summarizer_prompt,
        context: "EDUCATIONAL SESSION TRANSCRIPT FOR #{learner_id}:\n\n#{transcript_text}",
        instruction: "Generate a compact learning memory JSON for #{learner_id}. Return ONLY valid JSON. No prose."
      )

      raw    = LLM.call(prompt, model: model, tracker: tracker, phase: 'memory')
      memory = Helpers.extract_json(raw)

      if memory.nil?
        $stderr.puts "[memory:#{learner_id}] WARNING: Could not parse memory JSON, using default"
        return DEFAULT_MEMORY.transform_values(&:dup)
      end

      # Fill any missing keys so downstream code can always rely on all 7 fields
      DEFAULT_MEMORY.each_key { |k| memory[k] ||= [] }

      # Apply learner-type constraints: drop edge cases, shuffle rules, trim to budget
      if learner_type_key
        memory = LearnerTypes.apply_constraints(memory, learner_type_key)
        $stderr.puts "[memory:#{learner_id}] Applied #{learner_type_key} constraints (#{LearnerTypes.word_count(memory)} words)"
      else
        memory = LearnerTypes.trim_to_budget(memory, max_words)
        $stderr.puts "[memory:#{learner_id}] Memory generated (#{LearnerTypes.word_count(memory)} words)"
      end

      memory
    end
  end
end
