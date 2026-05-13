# ABOUTME: Orchestrates individual 1on1 tutoring sessions for each B-group learner
# ABOUTME: Each learner gets a separate 6-turn session with dedicated back-and-forth dialogue

require_relative '../llm'
require_relative '../helpers'

module Phases
  module Tutoring
    def self.run_session(tutor_id:, learner_id:, tutor_prompt:, learner_prompt:, lesson:, config:)
      tutor_model = config.dig('models', 'tutor') || 'claude-sonnet-4-6'
      learner_model = config.dig('models', 'learner') || 'claude-sonnet-4-6'

      turns = []

      # Turn 1: Tutor opens session
      opener_prompt = Helpers.build_prompt(
        system: tutor_prompt,
        context: "DOMAIN LESSON MATERIAL:\n#{lesson}",
        instruction: "Begin a tutoring session with #{learner_id}. Introduce the topic briefly and start teaching the first key concept. Be engaging and specific."
      )
      opener = LLM.call(opener_prompt, model: tutor_model)
      turns << { 'speaker' => 'tutor', 'type' => 'opener', 'content' => opener }
      $stderr.puts "[tutoring:#{learner_id}] Tutor opened session"

      # Turn 2: Learner responds
      response_prompt = Helpers.build_prompt(
        system: learner_prompt,
        context: "TUTOR SAID:\n#{opener}",
        instruction: "Respond to your tutor. Engage with what they said. Ask a question if something is unclear, or confirm your understanding."
      )
      response = LLM.call(response_prompt, model: learner_model)
      turns << { 'speaker' => 'learner', 'type' => 'response', 'content' => response }
      $stderr.puts "[tutoring:#{learner_id}] Learner responded"

      # Turn 3: Tutor asks diagnostic question
      history = Helpers.format_turns_for_prompt(turns)
      diagnostic_prompt = Helpers.build_prompt(
        system: tutor_prompt,
        context: "DOMAIN LESSON:\n#{lesson}\n\nSESSION SO FAR:\n#{history}",
        instruction: "Ask a specific diagnostic question to check the learner's understanding of a key rule. Make it concrete and require application, not just recitation."
      )
      diagnostic = LLM.call(diagnostic_prompt, model: tutor_model)
      turns << { 'speaker' => 'tutor', 'type' => 'diagnostic_question', 'content' => diagnostic }
      $stderr.puts "[tutoring:#{learner_id}] Tutor asked diagnostic question"

      # Turn 4: Learner answers diagnostic question
      history = Helpers.format_turns_for_prompt(turns)
      answer_prompt = Helpers.build_prompt(
        system: learner_prompt,
        context: "SESSION SO FAR:\n#{history}",
        instruction: "Answer the tutor's question. Show your reasoning. If you're unsure, say so honestly."
      )
      answer = LLM.call(answer_prompt, model: learner_model)
      turns << { 'speaker' => 'learner', 'type' => 'answer', 'content' => answer }
      $stderr.puts "[tutoring:#{learner_id}] Learner answered"

      # Turn 5: Tutor gives targeted feedback
      history = Helpers.format_turns_for_prompt(turns)
      feedback_prompt = Helpers.build_prompt(
        system: tutor_prompt,
        context: "DOMAIN LESSON:\n#{lesson}\n\nSESSION SO FAR:\n#{history}",
        instruction: "Give targeted feedback on the learner's answer. Correct any errors precisely. Reinforce what was correct. Clarify any misapplication of rules."
      )
      feedback = LLM.call(feedback_prompt, model: tutor_model)
      turns << { 'speaker' => 'tutor', 'type' => 'feedback', 'content' => feedback }
      $stderr.puts "[tutoring:#{learner_id}] Tutor gave feedback"

      # Turn 6: Learner summarizes
      history = Helpers.format_turns_for_prompt(turns)
      summary_prompt = Helpers.build_prompt(
        system: learner_prompt,
        context: "SESSION SO FAR:\n#{history}",
        instruction: "Summarize what you learned in this tutoring session. List the key rules, any corrections to your thinking, and what you're still unsure about."
      )
      summary = LLM.call(summary_prompt, model: learner_model)
      turns << { 'speaker' => 'learner', 'type' => 'summary', 'content' => summary }
      $stderr.puts "[tutoring:#{learner_id}] Learner summarized"

      {
        'condition' => '1on1',
        'tutor_id' => tutor_id,
        'learner_id' => learner_id,
        'turns' => turns
      }
    end
  end
end
