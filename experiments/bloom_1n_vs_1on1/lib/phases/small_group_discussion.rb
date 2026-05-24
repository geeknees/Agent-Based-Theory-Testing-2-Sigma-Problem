# ABOUTME: Phase 3 option: learners split into pairs; each pair discusses and produces shared notes
# ABOUTME: Each learner contributes at least once; returns per-group transcripts

require_relative '../llm'
require_relative '../helpers'
require_relative '../learner_types'

module Phases
  module SmallGroupDiscussion
    GROUP_PROBLEM = <<~PROB.freeze
      GROUP PROBLEM: Calculate and explain the score for [Red, Green, Blue, Yellow].
      - Each member must contribute their reasoning.
      - Identify which tokens are active and why.
      - Agree on the correct answer and note any rules that tripped you up.
    PROB

    def self.run(learner_ids:, participant_prompt:, lesson:, config:, tracker: nil, learner_type_keys: {})
      learner_model = config.dig('models', 'learner') || 'claude-sonnet-4-6'
      condition     = 'lecture_plus_small_group_discussion'

      groups  = learner_ids.each_slice(2).to_a
      results = []

      groups.each_with_index do |group, idx|
        group_turns = []

        # Round 1: each member contributes
        group.each do |lid|
          history    = Helpers.format_turns_for_prompt(group_turns)
          ctx_prefix = history.empty? ? '' : "GROUP DISCUSSION SO FAR:\n#{history}\n\n"
          type_key   = learner_type_keys[lid]
          learner_ctx = type_key ? "\n\nYOUR LEARNER TYPE: #{type_key} — respond authentically." : ''

          contrib_prompt = Helpers.build_prompt(
            system: participant_prompt,
            context: "#{ctx_prefix}LESSON CONTEXT:\n#{lesson}#{learner_ctx}",
            instruction: "Contribute your reasoning to your group. Show step-by-step thinking for the problem. Under 80 words.\n\n#{GROUP_PROBLEM}"
          )
          contrib = LLM.call(contrib_prompt, model: learner_model, tracker: tracker, phase: "education_#{condition}")
          group_turns << { 'speaker' => lid, 'type' => 'contribution', 'content' => contrib }
          $stderr.puts "[#{condition}] group#{idx} #{lid} contributed"
        end

        # Round 2: each member responds (only meaningful for pairs)
        if group.size > 1
          group.each do |lid|
            history    = Helpers.format_turns_for_prompt(group_turns)
            type_key   = learner_type_keys[lid]
            learner_ctx = type_key ? "\n\nYOUR LEARNER TYPE: #{type_key} — respond authentically." : ''

            reply_prompt = Helpers.build_prompt(
              system: participant_prompt,
              context: "GROUP DISCUSSION:\n#{history}#{learner_ctx}",
              instruction: "Respond to what your partner said. Agree, correct, or add a point. Under 60 words."
            )
            reply = LLM.call(reply_prompt, model: learner_model, tracker: tracker, phase: "education_#{condition}")
            group_turns << { 'speaker' => lid, 'type' => 'reply', 'content' => reply }
            $stderr.puts "[#{condition}] group#{idx} #{lid} replied"
          end
        end

        # Produce shared notes
        history = Helpers.format_turns_for_prompt(group_turns)
        notes_prompt = Helpers.build_prompt(
          system: participant_prompt,
          context: "GROUP DISCUSSION:\n#{history}",
          instruction: "Write short shared notes for your group summarizing: (1) the correct answer, (2) the key rule each member needs to remember, (3) any mistakes noticed. Under 80 words. Start with 'GROUP NOTES:'"
        )
        notes = LLM.call(notes_prompt, model: learner_model, tracker: tracker, phase: "education_#{condition}")
        group_turns << { 'speaker' => group.first, 'type' => 'shared_notes', 'content' => notes }
        $stderr.puts "[#{condition}] group#{idx} produced shared notes"

        results << {
          'condition'    => condition,
          'group_index'  => idx,
          'learner_ids'  => group,
          'turns'        => group_turns,
          'shared_notes' => notes,
          'contributions' => group.size
        }
      end

      results
    end
  end
end
