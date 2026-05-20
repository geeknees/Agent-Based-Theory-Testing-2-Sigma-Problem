# ABOUTME: Orchestrates individual 1on1 tutoring sessions with diagnostic-correct-retest loop
# ABOUTME: Exchange 3 diagnoses and corrects the learner's misconception; exchange 4 retests it

require_relative '../llm'
require_relative '../helpers'
require_relative '../learner_types'

module Phases
  module Tutoring
    def self.run_session(tutor_id:, learner_id:, tutor_prompt:, learner_prompt:, lesson:,
                         config:, tracker: nil, learner_type_key: nil, condition: '1on1')
      tutor_model   = config.dig('models', 'tutor')   || 'claude-sonnet-4-6'
      learner_model = config.dig('models', 'learner') || 'claude-sonnet-4-6'

      type_context    = learner_type_key ? "\n\n#{LearnerTypes.to_prompt_context(learner_type_key)}" : ''
      learner_context = learner_type_key ? "\n\nYOUR LEARNER TYPE: #{learner_type_key} — respond authentically." : ''

      turns = []

      # Exchange 1, Turn 1: Tutor opens session
      opener_prompt = Helpers.build_prompt(
        system: tutor_prompt,
        context: "DOMAIN LESSON MATERIAL:\n#{lesson}#{type_context}",
        instruction: "Begin a tutoring session with #{learner_id}. Teach the most important concept with a concrete example adapted to the learner's type. Be concise — under 150 words."
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

      # Exchange 2, Turn 3: Tutor asks diagnostic question targeting known misconception
      history = Helpers.format_turns_for_prompt(turns)
      diag1_prompt = Helpers.build_prompt(
        system: tutor_prompt,
        context: "DOMAIN LESSON:\n#{lesson}#{type_context}\n\nSESSION SO FAR:\n#{history}",
        instruction: "Ask ONE diagnostic question that will reveal whether the learner has the misconception listed in their type profile. Under 60 words. Do not give the answer."
      )
      diag1 = LLM.call(diag1_prompt, model: tutor_model, tracker: tracker, phase: 'education_tutoring')
      turns << { 'speaker' => 'tutor', 'type' => 'diagnostic_q1', 'content' => diag1 }
      $stderr.puts "[tutoring:#{learner_id}] Tutor asked diagnostic Q1"

      # Exchange 2, Turn 4: Learner answers Q1 (may reveal misconception)
      history = Helpers.format_turns_for_prompt(turns)
      answer1_prompt = Helpers.build_prompt(
        system: learner_prompt,
        context: "SESSION SO FAR:\n#{history}#{learner_context}",
        instruction: "Answer the tutor's question. Show your step-by-step reasoning. If unsure, say so."
      )
      answer1 = LLM.call(answer1_prompt, model: learner_model, tracker: tracker, phase: 'education_tutoring')
      turns << { 'speaker' => 'learner', 'type' => 'answer1', 'content' => answer1 }
      $stderr.puts "[tutoring:#{learner_id}] Learner answered Q1"

      # Exchange 3, Turn 5: Tutor identifies misconception and gives corrective example
      history = Helpers.format_turns_for_prompt(turns)
      correct_prompt = Helpers.build_prompt(
        system: tutor_prompt,
        context: "DOMAIN LESSON:\n#{lesson}#{type_context}\n\nSESSION SO FAR:\n#{history}",
        instruction: "Identify the specific error or misconception in the learner's answer. State the correct rule explicitly. Give a SHORT corrective worked example (2-3 steps) that makes the correct rule concrete. Under 120 words."
      )
      correction = LLM.call(correct_prompt, model: tutor_model, tracker: tracker, phase: 'education_tutoring')
      turns << { 'speaker' => 'tutor', 'type' => 'correction', 'content' => correction }
      $stderr.puts "[tutoring:#{learner_id}] Tutor gave correction"

      # Exchange 3, Turn 6: Learner applies the corrective example
      history = Helpers.format_turns_for_prompt(turns)
      apply_prompt = Helpers.build_prompt(
        system: learner_prompt,
        context: "SESSION SO FAR:\n#{history}#{learner_context}",
        instruction: "State the corrected rule in your own words. Work through the example the tutor gave you step by step. Express your confidence: low, medium, or high."
      )
      application = LLM.call(apply_prompt, model: learner_model, tracker: tracker, phase: 'education_tutoring')
      turns << { 'speaker' => 'learner', 'type' => 'correction_application', 'content' => application }
      $stderr.puts "[tutoring:#{learner_id}] Learner applied correction"

      # Exchange 4, Turn 7: Tutor asks RETEST question on same misconception
      history = Helpers.format_turns_for_prompt(turns)
      retest_q_prompt = Helpers.build_prompt(
        system: tutor_prompt,
        context: "DOMAIN LESSON:\n#{lesson}#{type_context}\n\nSESSION SO FAR:\n#{history}",
        instruction: "Ask a NEW question that retests the SAME misconception you just corrected. It must be a different scenario but test the same rule. Under 80 words. Do not give the answer."
      )
      retest_q = LLM.call(retest_q_prompt, model: tutor_model, tracker: tracker, phase: 'education_tutoring')
      turns << { 'speaker' => 'tutor', 'type' => 'retest_q', 'content' => retest_q }
      $stderr.puts "[tutoring:#{learner_id}] Tutor asked retest Q"

      # Exchange 4, Turn 8: Learner answers retest
      history = Helpers.format_turns_for_prompt(turns)
      retest_a_prompt = Helpers.build_prompt(
        system: learner_prompt,
        context: "SESSION SO FAR:\n#{history}#{learner_context}",
        instruction: "Answer the retest question. Apply the corrected rule you just learned. Show your reasoning. Note any remaining uncertainty."
      )
      retest_a = LLM.call(retest_a_prompt, model: learner_model, tracker: tracker, phase: 'education_tutoring')
      turns << { 'speaker' => 'learner', 'type' => 'retest_answer', 'content' => retest_a }
      $stderr.puts "[tutoring:#{learner_id}] Learner answered retest"

      {
        'condition'  => condition,
        'tutor_id'   => tutor_id,
        'learner_id' => learner_id,
        'turns'      => turns
      }
    end
  end
end
