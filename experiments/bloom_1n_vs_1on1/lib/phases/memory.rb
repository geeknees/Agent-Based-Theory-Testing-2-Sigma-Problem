# ABOUTME: Generates structured learning memory JSON from each learner's session transcript
# ABOUTME: Memory summarizer receives the transcript and extracts key rules, strategies, examples

require_relative '../llm'
require_relative '../helpers'

module Phases
  module Memory
    DEFAULT_MEMORY = {
      'key_rules' => [],
      'strategies' => [],
      'misconceptions_corrected' => [],
      'uncertainty_areas' => [],
      'worked_examples' => []
    }.freeze

    def self.generate(learner_id:, transcript:, summarizer_prompt:, config:)
      model = config.dig('models', 'memory_summarizer') || 'claude-sonnet-4-6'

      transcript_text = Helpers.format_turns_for_prompt(transcript['turns'])

      prompt = Helpers.build_prompt(
        system: summarizer_prompt,
        context: "EDUCATIONAL SESSION TRANSCRIPT FOR #{learner_id}:\n\n#{transcript_text}",
        instruction: "Generate a structured learning memory JSON for #{learner_id} based on this transcript. Return ONLY valid JSON matching the schema. No prose."
      )

      raw = LLM.call(prompt, model: model)
      memory = Helpers.extract_json(raw)

      if memory.nil?
        $stderr.puts "[memory:#{learner_id}] WARNING: Could not parse memory JSON, using default"
        memory = DEFAULT_MEMORY.dup
      end

      $stderr.puts "[memory:#{learner_id}] Memory generated (#{memory['key_rules']&.size || 0} key rules)"
      memory
    end
  end
end
