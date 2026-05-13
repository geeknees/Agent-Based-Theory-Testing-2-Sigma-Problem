# ABOUTME: Blind evaluator scores each task attempt without knowing the learner's condition
# ABOUTME: Returns structured score JSON; falls back to zero scores on parse failure

require 'json'
require_relative '../llm'
require_relative '../helpers'

module Phases
  module Evaluator
    FALLBACK_SCORE = {
      'correctness' => 0, 'reasoning_quality' => 0, 'rule_application' => 0,
      'error_checking' => 0, 'autonomy' => 0, 'total' => 0,
      'comments' => 'Evaluator failed to produce parseable JSON'
    }.freeze

    def self.score(attempt_id:, learner_response:, task:, rubric:, evaluator_id:, evaluator_prompt:, config:)
      model = config.dig('models', 'evaluator') || 'claude-sonnet-4-6'

      rubric_text = JSON.pretty_generate(rubric)
      expected_text = JSON.pretty_generate(task['expected_answer'])

      prompt = Helpers.build_prompt(
        system: evaluator_prompt,
        context: "RUBRIC:\n#{rubric_text}\n\nTASK:\n#{task['prompt']}\n\nEXPECTED ANSWER (reference only):\n#{expected_text}\n\nLEARNER RESPONSE:\n#{learner_response}",
        instruction: "Score this response according to the rubric. Return ONLY valid JSON. No prose. total must equal the sum of the five dimension scores."
      )

      raw = LLM.call(prompt, model: model)
      score = Helpers.extract_json(raw)

      if score.nil?
        $stderr.puts "[evaluator] WARNING: Could not parse score for attempt #{attempt_id}, using fallback"
        score = FALLBACK_SCORE.dup
      else
        expected_total = %w[correctness reasoning_quality rule_application error_checking autonomy].sum { |k| score[k].to_f.round }
        score['total'] = expected_total
      end

      $stderr.puts "[evaluator] Scored attempt #{attempt_id}: #{score['total']}/20"
      score
    end
  end
end
