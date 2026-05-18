# ABOUTME: Auto-scores eval task attempts using machine-checkable expected values
# ABOUTME: Adds calibrated_confidence, high_confidence_wrong, abstained, abstention_quality fields

module Scorer
  HIGH_CONFIDENCE_THRESHOLD = 0.7

  def self.score_attempt(parsed_response, task)
    return nil_score('Could not parse learner response as JSON') unless parsed_response.is_a?(Hash) && !parsed_response.empty?

    expected_answer   = task['expected_answer'].to_s.strip.downcase
    expected_tokens   = (task['expected_active_tokens'] || []).map { |t| t.to_s.downcase.strip }.sort
    expected_mistakes = task['expected_mistakes'] || []
    aliases           = task['acceptable_aliases'] || {}

    given_answer   = parsed_response['answer'].to_s.strip.downcase
    given_tokens   = (parsed_response['active_tokens'] || []).map { |t| t.to_s.downcase.strip }.sort
    given_mistakes = parsed_response['mistakes_found'] || []
    confidence     = parsed_response['confidence'].to_f
    abstained      = parsed_response['abstain'] == true

    # Check answer: exact match or alias match
    answer_correct = given_answer == expected_answer
    unless answer_correct
      aliases.each do |_key, vals|
        answer_correct = true if Array(vals).map { |v| v.to_s.downcase }.include?(given_answer)
      end
    end
    answer_correct = false if abstained

    # Check active tokens (order-independent)
    tokens_correct = given_tokens == expected_tokens

    # Check mistakes found: keyword overlap
    mistakes_ratio = if expected_mistakes.empty?
      1.0
    else
      matched = expected_mistakes.count { |em|
        keywords = em.downcase.split(/\W+/).select { |w| w.length > 3 }
        given_mistakes.any? { |gm| keywords.any? { |kw| gm.to_s.downcase.include?(kw) } }
      }
      matched.to_f / expected_mistakes.size
    end

    correctness = answer_correct ? 4 : 0
    rule_app    = tokens_correct ? 4 : 0
    error_check = case mistakes_ratio
                  when 1.0       then 4
                  when 0.5..0.99 then 2
                  else                0
                  end

    high_conf_wrong    = !answer_correct && confidence >= HIGH_CONFIDENCE_THRESHOLD
    calibrated_conf    = if answer_correct && confidence >= HIGH_CONFIDENCE_THRESHOLD then  2
                         elsif !answer_correct && confidence >= HIGH_CONFIDENCE_THRESHOLD then -2
                         else 0
                         end
    abstention_quality = abstained ? 1 : 0

    {
      'answer_correct'        => answer_correct,
      'active_tokens_correct' => tokens_correct,
      'mistakes_found_ratio'  => mistakes_ratio.round(2),
      'correctness'           => correctness,
      'reasoning_quality'     => 0,
      'rule_application'      => rule_app,
      'error_checking'        => error_check,
      'autonomy'              => 0,
      'total'                 => correctness + rule_app + error_check,
      'auto_scored'           => true,
      'comments'              => build_comment(answer_correct, tokens_correct, mistakes_ratio),
      'confidence'            => confidence,
      'abstained'             => abstained,
      'high_confidence_wrong' => high_conf_wrong,
      'calibrated_confidence' => calibrated_conf,
      'abstention_quality'    => abstention_quality
    }
  end

  def self.nil_score(reason = 'Scoring failed')
    {
      'answer_correct' => false, 'active_tokens_correct' => false,
      'mistakes_found_ratio' => 0.0, 'correctness' => 0,
      'reasoning_quality' => 0, 'rule_application' => 0,
      'error_checking' => 0, 'autonomy' => 0, 'total' => 0,
      'auto_scored' => true, 'comments' => "Auto: #{reason}",
      'confidence' => 0.0, 'abstained' => false,
      'high_confidence_wrong' => false, 'calibrated_confidence' => 0,
      'abstention_quality' => 0
    }
  end

  def self.build_comment(answer_correct, tokens_correct, mistakes_ratio)
    parts = [answer_correct ? 'answer correct' : 'answer wrong']
    parts << (tokens_correct ? 'tokens matched' : 'token mismatch')
    parts << "mistakes #{(mistakes_ratio * 100).round}%" unless mistakes_ratio == 1.0
    "Auto: #{parts.join(', ')}"
  end
end
