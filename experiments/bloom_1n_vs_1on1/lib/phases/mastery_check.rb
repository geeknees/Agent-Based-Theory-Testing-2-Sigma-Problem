# ABOUTME: Phase 2 of flipped-learning: 3 short mastery checks per learner, auto-scored
# ABOUTME: Appends corrective notes to memory for wrong answers; saves results to DB

require_relative '../llm'
require_relative '../helpers'
require_relative '../scorer'

module Phases
  module MasteryCheck
    # Run 3 mastery check questions for a single learner.
    # Returns { checks: [...score hashes...], errors: [...tasks where wrong...], updated_memory: hash }
    def self.run(learner_id:, memory:, check_tasks:, solver_prompt:, config:, db:, run_id:, tracker: nil)
      model  = config.dig('models', 'problem_solver') || 'claude-sonnet-4-6'
      checks = []
      errors = []

      check_tasks.each do |task|
        memory_text = JSON.pretty_generate(memory)
        prompt = Helpers.build_prompt(
          system: solver_prompt,
          context: "YOUR LEARNING MEMORY:\n#{memory_text}",
          instruction: task['learner_prompt']
        )
        response = LLM.call(prompt, model: model, tracker: tracker, phase: 'mastery_check')
        parsed   = Helpers.extract_json(response) || {}

        score   = Scorer.score_attempt(parsed, task)
        correct = score['answer_correct']

        DB.save_mastery_check(db,
          run_id: run_id, learner_id: learner_id,
          check_id: task['id'], check_type: task['check_type'],
          response_text: response, answer_correct: correct,
          corrective_note: correct ? nil : task['corrective_note'])

        $stderr.puts "[mastery_check:#{learner_id}] #{task['id']}: #{correct ? 'CORRECT' : 'WRONG'}"
        checks << score.merge('check_id' => task['id'], 'check_type' => task['check_type'])
        errors << task unless correct
      end

      updated = apply_corrections(memory, errors)
      { checks: checks, errors: errors, updated_memory: updated }
    end

    # Pure function: appends corrective notes from wrong-answer tasks to memory.
    def self.apply_corrections(memory, error_tasks)
      return memory if error_tasks.empty?
      result = memory.transform_values { |v| v.is_a?(Array) ? v.dup : v }
      error_tasks.each do |task|
        note = task['corrective_note']
        result['corrected_misconceptions'] << note if note && !note.empty?
      end
      result
    end
  end
end
