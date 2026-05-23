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

    # Update an existing memory based on a new interaction transcript.
    # Passes old memory as context; returns updated memory with constraints re-applied.
    def self.update(learner_id:, existing_memory:, update_transcript:, summarizer_prompt:,
                    config:, tracker: nil, learner_type_key: nil)
      model     = config.dig('models', 'memory_summarizer') || 'claude-sonnet-4-6'
      max_words = config.dig('experiment', 'max_memory_words') || MAX_WORDS

      if learner_type_key
        type_def  = LearnerTypes.fetch(learner_type_key)
        max_words = type_def[:memory_budget_words]
      end

      old_memory_text = JSON.pretty_generate(existing_memory)
      transcript_text = Helpers.format_turns_for_prompt(update_transcript)

      prompt = Helpers.build_prompt(
        system: summarizer_prompt,
        context: "EXISTING MEMORY FOR #{learner_id}:\n#{old_memory_text}\n\nNEW INTERACTION TRANSCRIPT:\n#{transcript_text}",
        instruction: "Update the memory JSON for #{learner_id} by incorporating new insights from the transcript. Keep correct existing knowledge; correct or add only what the transcript changes. Return ONLY valid JSON. No prose."
      )

      raw    = LLM.call(prompt, model: model, tracker: tracker, phase: 'memory')
      memory = Helpers.extract_json(raw)

      if memory.nil?
        $stderr.puts "[memory:#{learner_id}] WARNING: Could not parse updated memory JSON, keeping existing"
        return existing_memory
      end

      DEFAULT_MEMORY.each_key { |k| memory[k] ||= [] }

      if learner_type_key
        memory = LearnerTypes.apply_constraints(memory, learner_type_key)
        $stderr.puts "[memory:#{learner_id}] Updated memory with #{learner_type_key} constraints (#{LearnerTypes.word_count(memory)} words)"
      else
        memory = LearnerTypes.trim_to_budget(memory, max_words)
        $stderr.puts "[memory:#{learner_id}] Updated memory (#{LearnerTypes.word_count(memory)} words)"
      end

      memory
    end
  end
end
