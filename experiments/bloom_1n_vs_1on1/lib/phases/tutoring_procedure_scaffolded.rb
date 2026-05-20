# ABOUTME: Tutoring phase with explicit 4-step procedure checklist for order_confused learners
# ABOUTME: Learner restates procedure after intro; must label steps during retest

require_relative '../llm'
require_relative '../helpers'
require_relative '../learner_types'

module Phases
  module TutoringProcedureScaffolded
    PROCEDURE = <<~PROC.freeze
      Step 1: Determine which tokens are active (check Green Token position first)
      Step 2: Apply modifiers ONLY to active tokens
      Step 3: Apply edge case rules if any apply
      Step 4: Sum the final token scores
    PROC

    def self.run_session(tutor_id:, learner_id:, tutor_prompt:, learner_prompt:, lesson:,
                         config:, tracker: nil)
      condition     = 'procedure_scaffolded_one_on_one_tutoring'
      tutor_model   = config.dig('models', 'tutor')   || 'claude-sonnet-4-6'
      learner_model = config.dig('models', 'learner') || 'claude-sonnet-4-6'
      type_context  = LearnerTypes.to_prompt_context(:order_confused)

      turns = []

      opener_prompt = Helpers.build_prompt(
        system: tutor_prompt,
        context: "DOMAIN LESSON:\n#{lesson}\n\n#{type_context}",
        instruction: "Teach this learner the exact 4-step procedure:\n#{PROCEDURE}\nPresent steps in numbered order. Emphasize that Step 1 (activation check) ALWAYS precedes Step 2 (modifiers). Under 150 words."
      )
      opener = LLM.call(opener_prompt, model: tutor_model, tracker: tracker, phase: "education_#{condition}")
      turns << { 'speaker' => tutor_id, 'type' => 'procedure_intro', 'content' => opener }
      $stderr.puts "[#{condition}:#{learner_id}] Tutor introduced procedure"

      restate_prompt = Helpers.build_prompt(
        system: learner_prompt,
        context: "TUTOR SAID:\n#{opener}",
        instruction: "Restate the 4-step procedure the tutor just taught you, in your own words, in order. Number each step."
      )
      restatement = LLM.call(restate_prompt, model: learner_model, tracker: tracker, phase: "education_#{condition}")
      turns << { 'speaker' => learner_id, 'type' => 'procedure_restatement', 'content' => restatement }
      $stderr.puts "[#{condition}:#{learner_id}] Learner restated procedure"

      history     = Helpers.format_turns_for_prompt(turns)
      diag_prompt = Helpers.build_prompt(
        system: tutor_prompt,
        context: "DOMAIN LESSON:\n#{lesson}\n\n#{type_context}\n\nSESSION SO FAR:\n#{history}",
        instruction: "Ask ONE diagnostic question that will reveal whether the learner applies modifiers before checking activation. Under 60 words. Do not give the answer."
      )
      diag = LLM.call(diag_prompt, model: tutor_model, tracker: tracker, phase: "education_#{condition}")
      turns << { 'speaker' => tutor_id, 'type' => 'diagnostic_q', 'content' => diag }
      $stderr.puts "[#{condition}:#{learner_id}] Tutor asked diagnostic Q"

      history       = Helpers.format_turns_for_prompt(turns)
      answer_prompt = Helpers.build_prompt(
        system: learner_prompt,
        context: "SESSION SO FAR:\n#{history}",
        instruction: "Answer the tutor's question. Use the 4-step procedure. Label each step you perform (e.g. 'Step 1: ...')."
      )
      answer = LLM.call(answer_prompt, model: learner_model, tracker: tracker, phase: "education_#{condition}")
      turns << { 'speaker' => learner_id, 'type' => 'diagnostic_answer', 'content' => answer }
      $stderr.puts "[#{condition}:#{learner_id}] Learner answered diagnostic"

      history     = Helpers.format_turns_for_prompt(turns)
      corr_prompt = Helpers.build_prompt(
        system: tutor_prompt,
        context: "DOMAIN LESSON:\n#{lesson}\n\n#{type_context}\n\nSESSION SO FAR:\n#{history}",
        instruction: "Check whether the learner followed the 4-step procedure in order. If they applied modifiers (Step 2) before checking activation (Step 1), correct this explicitly. Restate: Step 1 ALWAYS precedes Step 2. Under 80 words."
      )
      correction = LLM.call(corr_prompt, model: tutor_model, tracker: tracker, phase: "education_#{condition}")
      turns << { 'speaker' => tutor_id, 'type' => 'procedure_correction', 'content' => correction }
      $stderr.puts "[#{condition}:#{learner_id}] Tutor gave procedure correction"

      history    = Helpers.format_turns_for_prompt(turns)
      ack_prompt = Helpers.build_prompt(
        system: learner_prompt,
        context: "SESSION SO FAR:\n#{history}",
        instruction: "Acknowledge the correction. Restate the 4-step procedure in the correct order. 2-3 sentences."
      )
      acknowledgment = LLM.call(ack_prompt, model: learner_model, tracker: tracker, phase: "education_#{condition}")
      turns << { 'speaker' => learner_id, 'type' => 'correction_acknowledgment', 'content' => acknowledgment }
      $stderr.puts "[#{condition}:#{learner_id}] Learner acknowledged correction"

      history       = Helpers.format_turns_for_prompt(turns)
      retest_prompt = Helpers.build_prompt(
        system: tutor_prompt,
        context: "DOMAIN LESSON:\n#{lesson}\n\n#{type_context}\n\nSESSION SO FAR:\n#{history}",
        instruction: "Present a new token calculation problem to retest procedure adherence. Tell the learner to label each step (Step 1:, Step 2:, etc.) as they work. Under 80 words."
      )
      retest_q = LLM.call(retest_prompt, model: tutor_model, tracker: tracker, phase: "education_#{condition}")
      turns << { 'speaker' => tutor_id, 'type' => 'retest_q', 'content' => retest_q }
      $stderr.puts "[#{condition}:#{learner_id}] Tutor asked retest Q"

      history         = Helpers.format_turns_for_prompt(turns)
      retest_a_prompt = Helpers.build_prompt(
        system: learner_prompt,
        context: "SESSION SO FAR:\n#{history}",
        instruction: "Solve the problem. Label each step (Step 1:, Step 2:, Step 3:, Step 4:). Show your reasoning at each step."
      )
      retest_a = LLM.call(retest_a_prompt, model: learner_model, tracker: tracker, phase: "education_#{condition}")
      turns << { 'speaker' => learner_id, 'type' => 'retest_answer', 'content' => retest_a }
      $stderr.puts "[#{condition}:#{learner_id}] Learner answered retest"

      {
        'condition'  => condition,
        'tutor_id'   => tutor_id,
        'learner_id' => learner_id,
        'turns'      => turns
      }
    end
  end
end
