# ABOUTME: Orchestrates 1:N classroom education for any classroom condition
# ABOUTME: Gates question-asking on learner type's question_asking_probability when type keys provided

require_relative '../llm'
require_relative '../helpers'
require_relative '../learner_types'

module Phases
  module Classroom
    def self.run(teacher_id:, learner_ids:, teacher_prompt:, learner_prompt:, lesson:,
                 config:, tracker: nil, class_context: nil, condition: 'classroom',
                 learner_type_keys: {})
      model         = config.dig('models', 'teacher') || 'claude-sonnet-4-6'
      learner_model = config.dig('models', 'learner') || 'claude-sonnet-4-6'

      turns = []

      context_suffix = class_context ? "\n\n#{class_context}" : ''

      # Step 1: Teacher delivers lecture
      lecture_prompt = Helpers.build_prompt(
        system: teacher_prompt,
        context: "DOMAIN LESSON:\n#{lesson}#{context_suffix}",
        instruction: "Deliver a clear, structured lesson to all learners. Cover all rules with examples. End with: \"Are there any questions?\""
      )
      lecture = LLM.call(lecture_prompt, model: model, tracker: tracker, phase: "education_#{condition}")
      turns << { 'speaker' => 'teacher', 'type' => 'lecture', 'content' => lecture }
      $stderr.puts "[#{condition}] Teacher delivered lecture (#{lecture.length} chars)"

      # Step 2: Each learner asks a question only if their type permits it
      questions = learner_ids.map do |learner_id|
        type_key = learner_type_keys[learner_id]
        asking   = type_key ? LearnerTypes.should_ask_question?(type_key) : true

        unless asking
          turns << { 'speaker' => learner_id, 'type' => 'question', 'content' => 'No questions.' }
          $stderr.puts "[#{condition}] #{learner_id} (#{type_key}) skipped question"
          next { learner_id: learner_id, question: 'No questions.' }
        end

        question_prompt = Helpers.build_prompt(
          system: learner_prompt,
          context: "CLASS LECTURE:\n#{lecture}",
          instruction: "You are #{learner_id}. Ask ONE question about something you want to clarify. If you understood everything, write exactly: No questions."
        )
        question = LLM.call(question_prompt, model: learner_model, tracker: tracker, phase: "education_#{condition}")
        turns << { 'speaker' => learner_id, 'type' => 'question', 'content' => question }
        $stderr.puts "[#{condition}] #{learner_id} asked question"
        { learner_id: learner_id, question: question }
      end

      real_questions = questions.reject { |q| q[:question].strip.downcase.start_with?('no questions') }

      # Step 3: Teacher answers all real questions in one response
      if real_questions.any?
        questions_text = real_questions.map { |q| "#{q[:learner_id]}: #{q[:question]}" }.join("\n\n")
        answer_prompt = Helpers.build_prompt(
          system: teacher_prompt,
          context: "DOMAIN LESSON:\n#{lesson}#{context_suffix}\n\nLECTURE DELIVERED:\n#{lecture}",
          instruction: "Answer these student questions publicly. Address each question clearly.\n\n#{questions_text}"
        )
        answers = LLM.call(answer_prompt, model: model, tracker: tracker, phase: "education_#{condition}")
        turns << { 'speaker' => 'teacher', 'type' => 'answers', 'content' => answers }
        $stderr.puts "[#{condition}] Teacher answered questions"
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
