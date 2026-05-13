# ABOUTME: Orchestrates the 1:N classroom education phase for the A-group learners
# ABOUTME: Teacher gives one lecture; learners ask questions; teacher answers publicly; learners write notes

require_relative '../llm'
require_relative '../helpers'

module Phases
  module Classroom
    def self.run(teacher_id:, learner_ids:, teacher_prompt:, learner_prompt:, lesson:, config:)
      model = config.dig('models', 'teacher') || 'claude-sonnet-4-6'
      learner_model = config.dig('models', 'learner') || 'claude-sonnet-4-6'

      turns = []

      # Step 1: Teacher delivers lecture
      lecture_prompt = Helpers.build_prompt(
        system: teacher_prompt,
        context: "DOMAIN LESSON:\n#{lesson}",
        instruction: "Deliver a clear, structured lesson to all learners. Cover all rules with examples. End with: \"Are there any questions?\""
      )
      lecture = LLM.call(lecture_prompt, model: model)
      turns << { 'speaker' => 'teacher', 'type' => 'lecture', 'content' => lecture }
      $stderr.puts "[classroom] Teacher delivered lecture (#{lecture.length} chars)"

      # Step 2: Each learner asks one question
      questions = learner_ids.map do |learner_id|
        question_prompt = Helpers.build_prompt(
          system: learner_prompt,
          context: "CLASS LECTURE:\n#{lecture}",
          instruction: "You are #{learner_id}. You have just attended this lecture. Ask ONE question about something you want to clarify. If you understood everything, write exactly: No questions."
        )
        question = LLM.call(question_prompt, model: learner_model)
        turns << { 'speaker' => learner_id, 'type' => 'question', 'content' => question }
        $stderr.puts "[classroom] #{learner_id} asked question"
        { learner_id: learner_id, question: question }
      end

      real_questions = questions.reject { |q| q[:question].strip.downcase.start_with?('no questions') }

      # Step 3: Teacher answers all questions at once
      if real_questions.any?
        questions_text = real_questions.map { |q| "#{q[:learner_id]}: #{q[:question]}" }.join("\n\n")
        answer_prompt = Helpers.build_prompt(
          system: teacher_prompt,
          context: "DOMAIN LESSON:\n#{lesson}\n\nLECTURE DELIVERED:\n#{lecture}",
          instruction: "Answer these student questions publicly. Address each question clearly.\n\n#{questions_text}"
        )
        answers = LLM.call(answer_prompt, model: model)
        turns << { 'speaker' => 'teacher', 'type' => 'answers', 'content' => answers }
        $stderr.puts "[classroom] Teacher answered questions"
      end

      # Step 4: Each learner writes final notes
      transcript_so_far = Helpers.format_turns_for_prompt(turns)
      learner_ids.each do |learner_id|
        notes_prompt = Helpers.build_prompt(
          system: learner_prompt,
          context: "FULL CLASS TRANSCRIPT:\n#{transcript_so_far}",
          instruction: "You are #{learner_id}. Write your personal learning notes from this class. List the key rules, examples, and anything you want to remember."
        )
        notes = LLM.call(notes_prompt, model: learner_model)
        turns << { 'speaker' => learner_id, 'type' => 'notes', 'content' => notes }
        $stderr.puts "[classroom] #{learner_id} wrote notes"
      end

      {
        'condition' => 'classroom',
        'teacher_id' => teacher_id,
        'learner_ids' => learner_ids,
        'turns' => turns
      }
    end
  end
end
