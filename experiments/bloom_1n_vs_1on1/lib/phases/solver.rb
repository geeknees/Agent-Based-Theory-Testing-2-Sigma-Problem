# ABOUTME: Runs each learner through evaluation tasks; parses JSON response with one retry on failure
# ABOUTME: Returns raw response text, parsed JSON hash, and trace for downstream auto-scoring

require 'json'
require_relative '../llm'
require_relative '../helpers'

module Phases
  module Solver
    PARSE_FAILED = { 'answer' => '', 'active_tokens' => [], 'mistakes_found' => [], 'reason' => 'parse failed' }.freeze

    def self.solve(learner_id:, memory:, task:, solver_prompt:, config:, tracker: nil)
      model = config.dig('models', 'problem_solver') || 'claude-sonnet-4-6'

      memory_text = JSON.pretty_generate(memory)
      prompt = Helpers.build_prompt(
        system: solver_prompt,
        context: "YOUR LEARNING MEMORY:\n#{memory_text}",
        instruction: task['prompt']
      )

      response = LLM.call(prompt, model: model, tracker: tracker, phase: 'evaluation')
      parsed   = Helpers.extract_json(response)

      if parsed.nil?
        $stderr.puts "[solver:#{learner_id}] WARNING: non-JSON response, retrying once"
        retry_prompt = Helpers.build_prompt(
          system: solver_prompt,
          context: "YOUR LEARNING MEMORY:\n#{memory_text}",
          instruction: task['prompt'] + "\n\nIMPORTANT: Respond ONLY with the JSON object. No other text."
        )
        response = LLM.call(retry_prompt, model: model, tracker: tracker, phase: 'evaluation')
        parsed   = Helpers.extract_json(response)
      end

      parsed ||= PARSE_FAILED.dup

      $stderr.puts "[solver:#{learner_id}] Solved task #{task['id']} (#{response.length} chars)"
      { 'response' => response, 'parsed' => parsed, 'trace' => { 'memory_size' => memory.to_s.length } }
    end
  end
end
