# ABOUTME: Orchestrates individual 1on1 tutoring sessions for each B-group learner
# ABOUTME: Accepts learner_profile to adapt tutor and learner prompts to individual characteristics

require_relative '../llm'
require_relative '../helpers'

module Phases
  module Tutoring
    def self.run_session(tutor_id:, learner_id:, tutor_prompt:, learner_prompt:, lesson:,
                         config:, tracker: nil, learner_profile: nil)
      tutor_model   = config.dig('models', 'tutor')   || 'claude-sonnet-4-6'
      learner_model = config.dig('models', 'learner') || 'claude-sonnet-4-6'

      profile_context = learner_profile ? "\n\n#{Profiles.to_tutor_context(learner_profile)}" : ''
      learner_context = learner_profile ? "\n\n#{Profiles.to_learner_context(learner_profile)}" : ''

      turns = []

      # Exchange 1, Turn 1: Tutor opens session
      opener_prompt = Helpers.build_prompt(
        system: tutor_prompt,
        context: "DOMAIN LESSON MATERIAL:\n#{lesson}#{profile_context}",
        instruction: "Begin a tutoring session with #{learner_id}. Teach the most important concept with a concrete example adapted to the learner's profile. Be concise — under 150 words."
      )
      opener = LLM.call(opener_prompt, model: tutor_model, tracker: tracker, phase: 'education_tutoring')
      turns << { 'speaker' => 'tutor', 'type' => 'opener', 'content' => opener }
      $stderr.puts "[tutoring:#{learner_id}] Tutor opened session"

      # Exchange 1, Turn 2: Learner responds
      response_prompt = Helpers.build_prompt(
        system: learner_prompt,
        context: "TUTOR SAID:\n#{opener}#{learner_context}",
        instruction: "Respond to your tutor. State what you understood, or ask a question if something is unclear. 1-2 sentences."
      )
      response = LLM.call(response_prompt, model: learner_model, tracker: tracker, phase: 'education_tutoring')
      turns << { 'speaker' => 'learner', 'type' => 'response', 'content' => response }
      $stderr.puts "[tutoring:#{learner_id}] Learner responded"

      # Exchange 2, Turn 3: Tutor asks first diagnostic question
      history = Helpers.format_turns_for_prompt(turns)
      diag1_prompt = Helpers.build_prompt(
        system: tutor_prompt,
        context: "DOMAIN LESSON:\n#{lesson}#{profile_context}\n\nSESSION SO FAR:\n#{history}",
        instruction: "Ask ONE diagnostic question requiring the learner to apply a rule. Target the learner's known misconception if any. Under 60 words. Do not give the answer."
      )
      diag1 = LLM.call(diag1_prompt, model: tutor_model, tracker: tracker, phase: 'education_tutoring')
      turns << { 'speaker' => 'tutor', 'type' => 'diagnostic_q1', 'content' => diag1 }
      $stderr.puts "[tutoring:#{learner_id}] Tutor asked diagnostic Q1"

      # Exchange 2, Turn 4: Learner answers Q1
      history = Helpers.format_turns_for_prompt(turns)
      answer1_prompt = Helpers.build_prompt(
        system: learner_prompt,
        context: "SESSION SO FAR:\n#{history}#{learner_context}",
        instruction: "Answer the tutor's question. Show your step-by-step reasoning. If unsure, say so."
      )
      answer1 = LLM.call(answer1_prompt, model: learner_model, tracker: tracker, phase: 'education_tutoring')
      turns << { 'speaker' => 'learner', 'type' => 'answer1', 'content' => answer1 }
      $stderr.puts "[tutoring:#{learner_id}] Learner answered Q1"

      # Exchange 3, Turn 5: Tutor gives targeted feedback
      history = Helpers.format_turns_for_prompt(turns)
      feedback_prompt = Helpers.build_prompt(
        system: tutor_prompt,
        context: "DOMAIN LESSON:\n#{lesson}#{profile_context}\n\nSESSION SO FAR:\n#{history}",
        instruction: "Give targeted feedback. If the learner made an error related to their known misconception, correct it explicitly. If correct, confirm and mention one edge case. Under 100 words."
      )
      feedback = LLM.call(feedback_prompt, model: tutor_model, tracker: tracker, phase: 'education_tutoring')
      turns << { 'speaker' => 'tutor', 'type' => 'feedback', 'content' => feedback }
      $stderr.puts "[tutoring:#{learner_id}] Tutor gave feedback"

      # Exchange 3, Turn 6: Learner reflects
      history = Helpers.format_turns_for_prompt(turns)
      reflect_prompt = Helpers.build_prompt(
        system: learner_prompt,
        context: "SESSION SO FAR:\n#{history}#{learner_context}",
        instruction: "Acknowledge the tutor's feedback. State what you got wrong (if anything) and what the correct rule is. 1-3 sentences."
      )
      reflect = LLM.call(reflect_prompt, model: learner_model, tracker: tracker, phase: 'education_tutoring')
      turns << { 'speaker' => 'learner', 'type' => 'reflection', 'content' => reflect }
      $stderr.puts "[tutoring:#{learner_id}] Learner reflected"

      # Exchange 4, Turn 7: Tutor asks harder second diagnostic
      history = Helpers.format_turns_for_prompt(turns)
      diag2_prompt = Helpers.build_prompt(
        system: tutor_prompt,
        context: "DOMAIN LESSON:\n#{lesson}#{profile_context}\n\nSESSION SO FAR:\n#{history}",
        instruction: "Ask a second, harder diagnostic question testing a DIFFERENT rule or rule interaction. Under 80 words. Do not give the answer."
      )
      diag2 = LLM.call(diag2_prompt, model: tutor_model, tracker: tracker, phase: 'education_tutoring')
      turns << { 'speaker' => 'tutor', 'type' => 'diagnostic_q2', 'content' => diag2 }
      $stderr.puts "[tutoring:#{learner_id}] Tutor asked diagnostic Q2"

      # Exchange 4, Turn 8: Learner answers Q2
      history = Helpers.format_turns_for_prompt(turns)
      answer2_prompt = Helpers.build_prompt(
        system: learner_prompt,
        context: "SESSION SO FAR:\n#{history}#{learner_context}",
        instruction: "Answer the tutor's second question. Apply what you corrected in this session. Show your reasoning."
      )
      answer2 = LLM.call(answer2_prompt, model: learner_model, tracker: tracker, phase: 'education_tutoring')
      turns << { 'speaker' => 'learner', 'type' => 'answer2', 'content' => answer2 }
      $stderr.puts "[tutoring:#{learner_id}] Learner answered Q2"

      {
        'condition'  => '1on1',
        'tutor_id'   => tutor_id,
        'learner_id' => learner_id,
        'turns'      => turns
      }
    end
  end
end
