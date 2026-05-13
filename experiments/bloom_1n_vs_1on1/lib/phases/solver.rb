# ABOUTME: Runs each learner through all evaluation tasks using their stored memory
# ABOUTME: Learner sees only their own memory and the task; no condition information exposed

require 'json'
require_relative '../llm'
require_relative '../helpers'

module Phases
  module Solver
    def self.solve(learner_id:, memory:, task:, solver_prompt:, config:)
      model = config.dig('models', 'problem_solver') || 'claude-sonnet-4-6'

      memory_text = JSON.pretty_generate(memory)

      prompt = Helpers.build_prompt(
        system: solver_prompt,
        context: "YOUR LEARNING MEMORY:\n#{memory_text}",
        instruction: task['prompt']
      )

      trace = { 'memory_size' => memory.to_s.length }
      response = LLM.call(prompt, model: model)

      $stderr.puts "[solver:#{learner_id}] Solved task #{task['id']} (#{response.length} chars)"
      { 'response' => response, 'trace' => trace }
    end
  end
end
