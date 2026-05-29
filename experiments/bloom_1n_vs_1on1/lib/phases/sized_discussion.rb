# ABOUTME: Unified discussion phase for pair/small/medium/large class sizes
# ABOUTME: Returns per-learner ownership_data; caller updates memories and saves to DB

require_relative '../llm'
require_relative '../helpers'
require_relative '../learner_types'

module Phases
  module SizedDiscussion
    DISCUSSION_PROBLEM = <<~PROB.freeze
      DISCUSSION PROBLEM: Calculate and explain the score for [Red, Green, Blue, Yellow].
      - Show your step-by-step reasoning.
      - Identify which tokens are active and why.
      - Note any rules that are easy to get wrong here.
    PROB

    # condition:         one of pair_discussion_size_2 / small_class_discussion_size_4 /
    #                    medium_class_discussion_size_8 / large_class_discussion_size_16
    # learner_ids:       ordered list of all learners in this condition
    # called_on_count:   nil = all contribute; integer = only first N are called on
    #
    # Returns {
    #   'condition'      => String,
    #   'turns'          => Array<Hash>,
    #   'ownership_data' => { learner_id => Hash },
    #   'called_on_ids'  => Array,
    #   'observer_ids'   => Array
    # }
    def self.run(condition:, learner_ids:, called_on_count: nil,
                 moderator_id:, moderator_prompt:, participant_prompt:,
                 lesson:, config:, tracker: nil, learner_type_keys: {})

      mod_model     = config.dig('models', 'teacher') || 'claude-sonnet-4-6'
      learner_model = config.dig('models', 'learner') || 'claude-sonnet-4-6'

      called_on_ids = called_on_count ? learner_ids.first(called_on_count) : learner_ids
      observer_ids  = learner_ids - called_on_ids

      ownership_data = init_ownership(learner_ids)
      turns = []

      # --- Moderator opens ---
      open_prompt = Helpers.build_prompt(
        system: moderator_prompt,
        context: "DOMAIN LESSON:\n#{lesson}",
        instruction: "Open the class discussion. Present the problem and invite learners to share their reasoning. Under 80 words.\n\n#{DISCUSSION_PROBLEM}"
      )
      opening = LLM.call(open_prompt, model: mod_model, tracker: tracker, phase: "education_#{condition}")
      turns << { 'speaker' => 'moderator', 'type' => 'opening', 'content' => opening }
      $stderr.puts "[#{condition}] Moderator opened (#{learner_ids.size} learners, #{called_on_ids.size} called on)"

      # --- Called-on learners contribute ---
      called_on_ids.each_with_index do |lid, idx|
        history  = Helpers.format_turns_for_prompt(turns)
        type_key = learner_type_keys[lid]
        ctx      = "DISCUSSION SO FAR:\n#{history}"
        ctx     += "\n\nYOUR LEARNER TYPE: #{type_key} — respond authentically." if type_key

        contrib_prompt = Helpers.build_prompt(
          system: participant_prompt,
          context: ctx,
          instruction: "Contribute your reasoning for the discussion problem. Show step-by-step thinking. Under 100 words."
        )
        contrib = LLM.call(contrib_prompt, model: learner_model, tracker: tracker, phase: "education_#{condition}")
        turns << { 'speaker' => lid, 'type' => 'contribution', 'content' => contrib }

        ownership_data[lid][:contribution_count]        += 1
        ownership_data[lid][:direct_participation_count] += 1
        ownership_data[lid][:attempted_answer]            = true

        # Everyone who hasn't spoken yet observes this contribution
        later_called  = called_on_ids[(idx + 1)..]
        (later_called + observer_ids).each { |oid| ownership_data[oid][:observed_peer_reasoning_count] += 1 }
        $stderr.puts "[#{condition}] #{lid} contributed"
      end

      # --- Pair-only: reply round ---
      if condition == 'pair_discussion_size_2' && called_on_ids.size == 2
        called_on_ids.each do |lid|
          history  = Helpers.format_turns_for_prompt(turns)
          type_key = learner_type_keys[lid]
          ctx      = "PAIR DISCUSSION:\n#{history}"
          ctx     += "\n\nYOUR LEARNER TYPE: #{type_key} — respond authentically." if type_key

          reply_prompt = Helpers.build_prompt(
            system: participant_prompt,
            context: ctx,
            instruction: "Respond to your partner. Agree, correct, or add a point. Under 60 words."
          )
          reply = LLM.call(reply_prompt, model: learner_model, tracker: tracker, phase: "education_#{condition}")
          turns << { 'speaker' => lid, 'type' => 'reply', 'content' => reply }
          ownership_data[lid][:contribution_count] += 1
          $stderr.puts "[#{condition}] #{lid} replied"
        end
      end

      # --- Moderator closes ---
      history = Helpers.format_turns_for_prompt(turns)
      close_prompt = Helpers.build_prompt(
        system: moderator_prompt,
        context: "DOMAIN LESSON:\n#{lesson}\n\nDISCUSSION:\n#{history}",
        instruction: "Close the discussion. Confirm the correct answer. Highlight the key rules. Correct any errors in learner contributions. Under 100 words."
      )
      closing = LLM.call(close_prompt, model: mod_model, tracker: tracker, phase: "education_#{condition}")
      turns << { 'speaker' => 'moderator', 'type' => 'closing', 'content' => closing }
      $stderr.puts "[#{condition}] Moderator closed"

      # Direct feedback: only called-on learners received targeted feedback
      called_on_ids.each do |lid|
        ownership_data[lid][:received_feedback]        = true
        ownership_data[lid][:moderator_feedback_count] += 1
      end

      # --- Pair-only: shared notes ---
      if condition == 'pair_discussion_size_2'
        history = Helpers.format_turns_for_prompt(turns)
        notes_prompt = Helpers.build_prompt(
          system: participant_prompt,
          context: "PAIR DISCUSSION:\n#{history}",
          instruction: "Write shared notes summarizing: (1) the correct answer, (2) key rules each member needs, (3) any mistakes noticed. Under 80 words. Start with 'GROUP NOTES:'"
        )
        notes = LLM.call(notes_prompt, model: learner_model, tracker: tracker, phase: "education_#{condition}")
        turns << { 'speaker' => called_on_ids.first, 'type' => 'shared_notes', 'content' => notes }
        $stderr.puts "[#{condition}] Shared notes produced"
      end

      # Exposure count = total turns in session (everyone present throughout)
      total_turns = turns.size
      learner_ids.each { |lid| ownership_data[lid][:discussion_exposure_count] = total_turns }

      # Compute ownership_score
      ownership_data.each_value do |data|
        data[:ownership_score] = compute_ownership_score(data)
      end

      {
        'condition'      => condition,
        'turns'          => turns,
        'ownership_data' => ownership_data.transform_values { |d| d.transform_keys(&:to_s) },
        'called_on_ids'  => called_on_ids,
        'observer_ids'   => observer_ids
      }
    end

    private_class_method def self.init_ownership(learner_ids)
      learner_ids.each_with_object({}) do |lid, h|
        h[lid] = {
          contribution_count:             0,
          attempted_answer:               false,
          received_feedback:              false,
          misconception_exposed:          false,
          misconception_corrected:        false,
          observed_peer_reasoning_count:  0,
          discussion_exposure_count:      0,
          direct_participation_count:     0,
          moderator_feedback_count:       0,
          ownership_score:                0
        }
      end
    end

    private_class_method def self.compute_ownership_score(data)
      score = 0
      score += 1 if data[:contribution_count] > 0
      score += 1 if data[:attempted_answer]
      score += 1 if data[:received_feedback]
      score += 1 if data[:misconception_exposed] || data[:misconception_corrected]
      score
    end
  end
end
