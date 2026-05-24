# ABOUTME: Phase 3 option: all learners discuss one shared debugging problem with light moderation
# ABOUTME: Returns shared transcript; callers update individual memories from it

require_relative '../llm'
require_relative '../helpers'
require_relative '../learner_types'

module Phases
  module WholeClassDiscussion
    DISCUSSION_PROBLEM = <<~PROB.freeze
      DISCUSSION PROBLEM: Calculate and explain the score for [Red, Green, Blue, Yellow].
      - Show your step-by-step reasoning.
      - Identify which tokens are active and why.
      - Note any rules that are easy to get wrong here.
    PROB

    def self.run(moderator_id:, learner_ids:, moderator_prompt:, participant_prompt:, lesson:,
                 config:, tracker: nil, learner_type_keys: {})
      mod_model     = config.dig('models', 'teacher')  || 'claude-sonnet-4-6'
      learner_model = config.dig('models', 'learner')  || 'claude-sonnet-4-6'
      condition     = 'lecture_plus_whole_class_discussion'

      turns = []

      open_prompt = Helpers.build_prompt(
        system: moderator_prompt,
        context: "DOMAIN LESSON:\n#{lesson}",
        instruction: "Open the discussion. Present the problem to all learners and invite them to share their reasoning. Under 80 words.\n\n#{DISCUSSION_PROBLEM}"
      )
      opening = LLM.call(open_prompt, model: mod_model, tracker: tracker, phase: "education_#{condition}")
      turns << { 'speaker' => 'moderator', 'type' => 'opening', 'content' => opening }
      $stderr.puts "[#{condition}] Moderator opened discussion"

      learner_ids.each do |lid|
        history     = Helpers.format_turns_for_prompt(turns)
        type_key    = learner_type_keys[lid]
        learner_ctx = type_key ? "\n\nYOUR LEARNER TYPE: #{type_key} — respond authentically." : ''

        contrib_prompt = Helpers.build_prompt(
          system: participant_prompt,
          context: "DISCUSSION SO FAR:\n#{history}#{learner_ctx}",
          instruction: "Contribute your reasoning for the discussion problem. Show your step-by-step thinking. Address any point another learner raised if relevant. Under 100 words."
        )
        contrib = LLM.call(contrib_prompt, model: learner_model, tracker: tracker, phase: "education_#{condition}")
        turns << { 'speaker' => lid, 'type' => 'contribution', 'content' => contrib }
        $stderr.puts "[#{condition}] #{lid} contributed"
      end

      history = Helpers.format_turns_for_prompt(turns)
      close_prompt = Helpers.build_prompt(
        system: moderator_prompt,
        context: "DOMAIN LESSON:\n#{lesson}\n\nDISCUSSION:\n#{history}",
        instruction: "Close the discussion. Confirm the correct answer and highlight the key rules demonstrated. Correct any errors in learner contributions. Under 100 words."
      )
      closing = LLM.call(close_prompt, model: mod_model, tracker: tracker, phase: "education_#{condition}")
      turns << { 'speaker' => 'moderator', 'type' => 'closing', 'content' => closing }
      $stderr.puts "[#{condition}] Moderator closed discussion"

      {
        'condition'     => condition,
        'moderator_id'  => moderator_id,
        'learner_ids'   => learner_ids,
        'turns'         => turns,
        'contributions' => learner_ids.size
      }
    end
  end
end
