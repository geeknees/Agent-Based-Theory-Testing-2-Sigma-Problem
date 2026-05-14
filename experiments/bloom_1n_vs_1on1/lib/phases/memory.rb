# ABOUTME: Generates compact structured learning memory from each learner's session transcript
# ABOUTME: Enforces 120-word limit; new 4-field schema: rules, mistakes, strategy, edge_cases

require_relative '../llm'
require_relative '../helpers'

module Phases
  module Memory
    MAX_WORDS = 120
    DEFAULT_MEMORY = { 'rules' => [], 'mistakes' => [], 'strategy' => [], 'edge_cases' => [] }.freeze

    def self.generate(learner_id:, transcript:, summarizer_prompt:, config:, tracker: nil)
      model     = config.dig('models', 'memory_summarizer') || 'claude-sonnet-4-6'
      max_words = config.dig('experiment', 'max_memory_words') || MAX_WORDS

      transcript_text = Helpers.format_turns_for_prompt(transcript['turns'])

      prompt = Helpers.build_prompt(
        system: summarizer_prompt,
        context: "EDUCATIONAL SESSION TRANSCRIPT FOR #{learner_id}:\n\n#{transcript_text}",
        instruction: "Generate a compact learning memory JSON for #{learner_id}. Return ONLY valid JSON. No prose."
      )

      raw = LLM.call(prompt, model: model, tracker: tracker, phase: 'memory')
      $stderr.puts "[memory:#{learner_id}] LLM returned raw memory (#{raw.length} chars)"

      memory = Helpers.extract_json(raw)

      if memory.nil?
        $stderr.puts "[memory:#{learner_id}] WARNING: Could not parse memory JSON, using default"
        return DEFAULT_MEMORY.transform_values(&:dup)
      end

      memory = enforce_word_limit(memory, max_words)
      $stderr.puts "[memory:#{learner_id}] Memory generated (#{word_count(memory)} words, #{memory.values.flatten.size} items)"
      memory
    end

    def self.enforce_word_limit(memory, max_words)
      return memory if word_count(memory) <= max_words

      result = memory.transform_values { |arr| arr.is_a?(Array) ? arr.dup : arr }
      while word_count(result) > max_words
        longest_key = result.select { |_, v| v.is_a?(Array) && v.size > 0 }
                            .max_by { |_, v| v.join(' ').split.size }
                            &.first
        break unless longest_key
        result[longest_key] = result[longest_key][0..-2]
      end
      result
    end

    def self.word_count(memory)
      memory.values.flatten.join(' ').split.size
    end
  end
end
