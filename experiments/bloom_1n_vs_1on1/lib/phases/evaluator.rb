# ABOUTME: Scores task attempts — tries Scorer auto-scoring first, falls back to LLM evaluator
# ABOUTME: All new-format tasks (expected_answer is a string) are auto-scored without LLM calls

require 'json'
require_relative '../llm'
require_relative '../helpers'
require_relative '../scorer'

module Phases
  module Evaluator
    LLM_FALLBACK_SCORE = {
      'correctness' => 0, 'reasoning_quality' => 0, 'rule_application' => 0,
      'error_checking' => 0, 'autonomy' => 0, 'total' => 0,
      'auto_scored' => false, 'comments' => 'LLM evaluator failed to produce parseable JSON'
    }.freeze

    # Task types that require LLM semantic evaluation instead of exact-match scoring.
    # short_rule_induction (L6) answers are free-text; exact-match produces near-zero
    # scores regardless of semantic correctness (F2 scorer artifact, v8/v9b/v9c).
    SEMANTIC_TASK_TYPES = %w[short_rule_induction].freeze

    def self.score(attempt_id:, learner_response:, parsed_response:, task:, rubric:,
                   evaluator_id:, evaluator_prompt:, config:, tracker: nil)
      # Auto-score if task has machine-checkable expected_answer string,
      # unless the task type requires semantic (LLM) evaluation.
      if task['expected_answer'].is_a?(String) && !SEMANTIC_TASK_TYPES.include?(task['task_type'])
        auto = Scorer.score_attempt(parsed_response, task)
        $stderr.puts "[evaluator] Auto-scored attempt #{attempt_id}: #{auto['total']} (answer_correct=#{auto['answer_correct']})"
        return auto
      end

      # LLM fallback for tasks without machine-checkable fields
      model = config.dig('models', 'evaluator') || 'claude-sonnet-4-6'
      rubric_text   = JSON.pretty_generate(rubric)
      expected_text = JSON.pretty_generate(task['expected_answer'])

      prompt = Helpers.build_prompt(
        system: evaluator_prompt,
        context: "RUBRIC:\n#{rubric_text}\n\nTASK:\n#{task['prompt']}\n\nEXPECTED ANSWER (reference only):\n#{expected_text}\n\nLEARNER RESPONSE:\n#{learner_response}",
        instruction: "Score this response according to the rubric. Return ONLY valid JSON. total must equal the sum of the five dimension scores."
      )

      raw   = LLM.call(prompt, model: model, tracker: tracker, phase: 'evaluator')
      score = Helpers.extract_json(raw)

      if score.nil?
        $stderr.puts "[evaluator] WARNING: LLM evaluator parse failed for attempt #{attempt_id}"
        return LLM_FALLBACK_SCORE.dup
      end

      score['total'] = %w[correctness reasoning_quality rule_application error_checking autonomy].sum { |k| score[k].to_f.round }
      score['auto_scored'] = false
      $stderr.puts "[evaluator] LLM-scored attempt #{attempt_id}: #{score['total']}/20"
      score
    end
  end
end
