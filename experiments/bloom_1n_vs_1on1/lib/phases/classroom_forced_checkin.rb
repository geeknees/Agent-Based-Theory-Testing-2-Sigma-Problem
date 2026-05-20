# ABOUTME: Orchestrates classroom with forced individual comprehension check-ins after shared lesson
# ABOUTME: Unlike standard classroom, every learner must answer — no question_asking_probability gating

require_relative '../llm'
require_relative '../helpers'

module Phases
  module ClassroomForcedCheckin
    def self.run(teacher_id:, learner_ids:, teacher_prompt:, learner_prompt:, lesson:,
                 config:, tracker: nil, class_context: nil)
      condition     = 'classroom_forced_checkin'
      model         = config.dig('models', 'teacher') || 'claude-sonnet-4-6'
      learner_model = config.dig('models', 'learner') || 'claude-sonnet-4-6'

      turns          = []
      context_suffix = class_context ? "\n\n#{class_context}" : ''

      lecture_prompt = Helpers.build_prompt(
        system: teacher_prompt,
        context: "DOMAIN LESSON:\n#{lesson}#{context_suffix}",
        instruction: "Deliver a clear, structured lesson covering all rules with examples. Under 200 words."
      )
      lecture = LLM.call(lecture_prompt, model: model, tracker: tracker, phase: "education_#{condition}")
      turns << { 'speaker' => 'teacher', 'type' => 'lecture', 'content' => lecture }
      $stderr.puts "[#{condition}] Teacher delivered lecture (#{lecture.length} chars)"

      learner_ids.each do |learner_id|
        q_prompt = Helpers.build_prompt(
          system: teacher_prompt,
          context: "DOMAIN LESSON:\n#{lesson}\n\nLECTURE DELIVERED:\n#{lecture}",
          instruction: "Ask learner #{learner_id} ONE short comprehension check question to test their understanding. Under 40 words. Do not give the answer."
        )
        q = LLM.call(q_prompt, model: model, tracker: tracker, phase: "education_#{condition}")
        turns << { 'speaker' => 'teacher', 'type' => 'checkin_question', 'content' => q, 'target' => learner_id }
        $stderr.puts "[#{condition}] Teacher asked check-in for #{learner_id}"

        a_prompt = Helpers.build_prompt(
          system: learner_prompt,
          context: "CLASS LECTURE:\n#{lecture}\n\nTEACHER ASKED YOU:\n#{q}",
          instruction: "Answer the teacher's question. 1-2 sentences."
        )
        a = LLM.call(a_prompt, model: learner_model, tracker: tracker, phase: "education_#{condition}")
        turns << { 'speaker' => learner_id, 'type' => 'checkin_answer', 'content' => a }
        $stderr.puts "[#{condition}] #{learner_id} answered check-in"

        corr_prompt = Helpers.build_prompt(
          system: teacher_prompt,
          context: "DOMAIN LESSON:\n#{lesson}\n\nCHECK-IN Q:\n#{q}\n\nLEARNER ANSWER:\n#{a}",
          instruction: "If the learner's answer contains a clear error, give ONE short public correction (under 30 words). If the answer is correct, write exactly: Correct."
        )
        corr = LLM.call(corr_prompt, model: model, tracker: tracker, phase: "education_#{condition}")
        turns << { 'speaker' => 'teacher', 'type' => 'checkin_correction', 'content' => corr, 'target' => learner_id }
        $stderr.puts "[#{condition}] Teacher correction for #{learner_id}: #{corr[0..60]}"
      end

      {
        'condition'   => condition,
        'teacher_id'  => teacher_id,
        'learner_ids' => learner_ids,
        'turns'       => turns
      }
    end
  end
end
