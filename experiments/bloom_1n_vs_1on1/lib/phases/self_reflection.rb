# ABOUTME: Self-study reflection phase for lecture_only learners (A6 fix)
# ABOUTME: Mirrors token budget of discussion phase; learner works alone with their memory

require 'json'
require_relative '../llm'
require_relative '../helpers'
require_relative 'sized_discussion'

module Phases
  module SelfReflection
    def self.run(learner_id:, memory:, reflection_prompt:, lesson:, config:,
                 tracker: nil, learner_type_key: nil)
      learner_model = config.dig('models', 'learner') || 'claude-sonnet-4-6'
      memory_text   = JSON.pretty_generate(memory)

      ctx  = "YOUR LEARNING MEMORY:\n#{memory_text}"
      ctx += "\n\nYOUR LEARNER TYPE: #{learner_type_key} — respond authentically." if learner_type_key

      prompt = Helpers.build_prompt(
        system:      reflection_prompt,
        context:     ctx,
        instruction: "Write your reasoning note for the problem below. Show your step-by-step " \
                     "thinking, identify which tokens are active and why, and note any rules " \
                     "that are easy to get wrong. Under 120 words.\n\n" \
                     "#{Phases::SizedDiscussion::DISCUSSION_PROBLEM}"
      )

      note  = LLM.call(prompt, model: learner_model, tracker: tracker, phase: 'education_lecture_only')
      turns = [{ 'speaker' => learner_id, 'type' => 'reflection_note', 'content' => note }]

      $stderr.puts "[self_reflection:#{learner_id}] Reflection note produced"

      {
        'condition'  => 'lecture_only',
        'turns'      => turns,
        'learner_id' => learner_id
      }
    end
  end
end
