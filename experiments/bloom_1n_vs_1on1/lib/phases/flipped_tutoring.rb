# ABOUTME: Phase 3 option: tutor reviews mastery check errors; gives one corrective example per error
# ABOUTME: Shorter than full tutoring because prerequisite knowledge already exists from lecture

require_relative '../llm'
require_relative '../helpers'
require_relative '../learner_types'

module Phases
  module FlippedTutoring
    def self.run_session(tutor_id:, learner_id:, tutor_prompt:, learner_prompt:, lesson:,
                         mastery_errors:, config:, tracker: nil, learner_type_key: nil)
      tutor_model   = config.dig('models', 'tutor')   || 'claude-sonnet-4-6'
      learner_model = config.dig('models', 'learner') || 'claude-sonnet-4-6'
      condition     = 'lecture_plus_one_on_one_tutoring'

      type_context    = learner_type_key ? "\n\n#{LearnerTypes.to_prompt_context(learner_type_key)}" : ''
      learner_context = learner_type_key ? "\n\nYOUR LEARNER TYPE: #{learner_type_key} — respond authentically." : ''

      turns = []

      if mastery_errors.empty?
        review_prompt = Helpers.build_prompt(
          system: tutor_prompt,
          context: "DOMAIN LESSON:\n#{lesson}#{type_context}",
          instruction: "The learner passed all mastery checks. Give one advanced consolidation example that combines multiple rules. Under 100 words."
        )
        review = LLM.call(review_prompt, model: tutor_model, tracker: tracker, phase: "education_#{condition}")
        turns << { 'speaker' => 'tutor', 'type' => 'consolidation', 'content' => review }

        apply_prompt = Helpers.build_prompt(
          system: learner_prompt,
          context: "TUTOR SAID:\n#{review}#{learner_context}",
          instruction: "State what you understood from the example. 1-2 sentences."
        )
        apply = LLM.call(apply_prompt, model: learner_model, tracker: tracker, phase: "education_#{condition}")
        turns << { 'speaker' => 'learner', 'type' => 'response', 'content' => apply }
        $stderr.puts "[#{condition}:#{learner_id}] Consolidation session (no errors)"
      else
        mastery_errors.each do |error_task|
          note = error_task['corrective_note'] || "Review: #{error_task['id']}"

          correct_prompt = Helpers.build_prompt(
            system: tutor_prompt,
            context: "DOMAIN LESSON:\n#{lesson}#{type_context}\n\nLEARNER'S MASTERY CHECK ERROR:\n#{note}",
            instruction: "Give ONE short corrective worked example that makes the correct rule concrete. State the rule first, then work through a token sequence step by step. Under 100 words."
          )
          correction = LLM.call(correct_prompt, model: tutor_model, tracker: tracker, phase: "education_#{condition}")
          turns << { 'speaker' => 'tutor', 'type' => 'corrective_example', 'content' => correction,
                     'check_id' => error_task['id'] }
          $stderr.puts "[#{condition}:#{learner_id}] Tutor gave corrective example for #{error_task['id']}"

          restate_prompt = Helpers.build_prompt(
            system: learner_prompt,
            context: "TUTOR CORRECTION:\n#{correction}#{learner_context}",
            instruction: "Restate the corrected rule in your own words. 1-2 sentences. Express confidence: low, medium, or high."
          )
          restate = LLM.call(restate_prompt, model: learner_model, tracker: tracker, phase: "education_#{condition}")
          turns << { 'speaker' => 'learner', 'type' => 'restatement', 'content' => restate,
                     'check_id' => error_task['id'] }
          $stderr.puts "[#{condition}:#{learner_id}] Learner restated corrected rule for #{error_task['id']}"
        end
      end

      {
        'condition'        => condition,
        'tutor_id'         => tutor_id,
        'learner_id'       => learner_id,
        'turns'            => turns,
        'errors_addressed' => mastery_errors.size
      }
    end
  end
end
