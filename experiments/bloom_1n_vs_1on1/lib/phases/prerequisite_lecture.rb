# ABOUTME: Phase 1 of flipped-learning: delivers shared prerequisite lecture to all learners
# ABOUTME: Returns shared transcript; callers generate individual memories from it separately

require_relative '../llm'
require_relative '../helpers'
require_relative '../learner_types'

module Phases
  module PrerequisiteLecture
    LECTURE_INSTRUCTION = <<~INST.freeze
      Deliver a comprehensive prerequisite lecture covering ALL of the following:
      1. Every canonical rule (Red modifier, Blue activation, Green end rule, Yellow always active, stacking)
      2. Each edge case and boundary condition
      3. Modifier ordering (what Red doubles vs does not)
      4. At least 3 worked examples with step-by-step breakdowns
      5. The most common student mistakes and why they are wrong

      This lecture is the sole knowledge source before the quiz. Make it complete and systematic.
      Do not cut any rule. Do not summarize — explain each rule with an example.
    INST

    def self.run(teacher_id:, learner_ids:, teacher_prompt:, learner_prompt:, lesson:,
                 config:, tracker: nil, learner_type_keys: {})
      model     = config.dig('models', 'teacher') || 'claude-sonnet-4-6'
      condition = 'prerequisite_lecture'

      prompt = Helpers.build_prompt(
        system: teacher_prompt,
        context: "DOMAIN LESSON:\n#{lesson}",
        instruction: LECTURE_INSTRUCTION
      )
      lecture = LLM.call(prompt, model: model, tracker: tracker, phase: "education_#{condition}")
      $stderr.puts "[#{condition}] Teacher delivered lecture (#{lecture.length} chars)"

      turns = [{ 'speaker' => 'teacher', 'type' => 'lecture', 'content' => lecture }]

      {
        'condition'   => condition,
        'teacher_id'  => teacher_id,
        'learner_ids' => learner_ids,
        'turns'       => turns,
        'lecture'     => lecture
      }
    end
  end
end
