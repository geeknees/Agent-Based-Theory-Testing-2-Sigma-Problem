# ABOUTME: Defines 7 theory-driven learner types with behavioral constraint attributes
# ABOUTME: Constraints applied post-LLM to memory to operationalize cognitive differences

module LearnerTypes
  TYPES = {
    rule_extractor: {
      memory_budget_words:         150,
      edge_case_retention:         0.9,
      rule_order_retention:        0.9,
      question_asking_probability: 0.3,
      likely_misconceptions:       []
    },
    example_memorizer: {
      memory_budget_words:         120,
      edge_case_retention:         0.4,
      rule_order_retention:        0.5,
      question_asking_probability: 0.2,
      likely_misconceptions:       ['forgets_edge_cases']
    },
    edge_case_dropper: {
      memory_budget_words:         120,
      edge_case_retention:         0.1,
      rule_order_retention:        0.7,
      question_asking_probability: 0.2,
      likely_misconceptions:       ['forgets_edge_cases']
    },
    order_confused: {
      memory_budget_words:         100,
      edge_case_retention:         0.6,
      rule_order_retention:        0.2,
      question_asking_probability: 0.4,
      likely_misconceptions:       ['applies_modifiers_before_activation']
    },
    answer_first: {
      memory_budget_words:         100,
      edge_case_retention:         0.3,
      rule_order_retention:        0.5,
      question_asking_probability: 0.1,
      likely_misconceptions:       ['thinks_blue_always_active']
    },
    help_seeker: {
      memory_budget_words:         130,
      edge_case_retention:         0.7,
      rule_order_retention:        0.8,
      question_asking_probability: 0.9,
      likely_misconceptions:       []
    },
    passive_listener: {
      memory_budget_words:         80,
      edge_case_retention:         0.2,
      rule_order_retention:        0.4,
      question_asking_probability: 0.0,
      likely_misconceptions:       ['forgets_edge_cases']
    }
  }.freeze

  REQUIRED_KEYS = %i[memory_budget_words edge_case_retention rule_order_retention
                     question_asking_probability likely_misconceptions].freeze

  HOMOGENEOUS_ASSIGNMENT   = Array.new(4, :edge_case_dropper).freeze
  HETEROGENEOUS_ASSIGNMENT = %i[rule_extractor edge_case_dropper order_confused passive_listener].freeze

  DESCRIPTIONS = {
    rule_extractor:    'extract explicit rules from instruction; strong at recall, weaker on application',
    example_memorizer: 'remember specific worked examples; struggles to generalize to new cases',
    edge_case_dropper: 'grasp main rules but forget edge cases and boundary conditions',
    order_confused:    'apply rules in wrong sequence; often reverses modifier/activation order',
    answer_first:      'jump to answers before checking all conditions; overconfident',
    help_seeker:       'ask for clarification proactively; learns well with feedback',
    passive_listener:  'listen without engaging; retain partial information only'
  }.freeze

  def self.fetch(type_key)
    TYPES.fetch(type_key.to_sym) { raise ArgumentError, "Unknown learner type: #{type_key}" }
  end

  def self.should_ask_question?(type_key)
    prob = fetch(type_key)[:question_asking_probability]
    rand < prob
  end

  # Apply type-specific constraints to an LLM-generated memory hash.
  # Returns a new hash — does not mutate the input.
  def self.apply_constraints(memory, type_key)
    type   = fetch(type_key)
    result = memory.transform_values { |v| v.is_a?(Array) ? v.dup : v }

    if result['edge_cases'].is_a?(Array)
      result['edge_cases'] = result['edge_cases'].select { rand < type[:edge_case_retention] }
    end

    if result['rules'].is_a?(Array) && rand >= type[:rule_order_retention]
      result['rules'] = result['rules'].shuffle
    end

    trim_to_budget(result, type[:memory_budget_words])
  end

  # Trim memory to max_words by removing from lowest-priority arrays first.
  # Priority (highest = keep longest): rules > strategy > edge_cases > examples >
  #   corrected_misconceptions > uncertain_rules > remaining_misconceptions
  def self.trim_to_budget(memory, max_words)
    return memory if word_count(memory) <= max_words

    result     = memory.transform_values { |v| v.is_a?(Array) ? v.dup : v }
    trim_order = %w[remaining_misconceptions uncertain_rules examples
                    edge_cases corrected_misconceptions strategy rules]
    loop do
      break if word_count(result) <= max_words

      trimmed = false
      trim_order.each do |key|
        if result[key].is_a?(Array) && result[key].size > 0
          result[key] = result[key][0..-2]
          trimmed = true
          break
        end
      end
      break unless trimmed
    end
    result
  end

  def self.word_count(memory)
    memory.values.flatten.join(' ').split.size
  end

  def self.to_prompt_context(type_key)
    type = fetch(type_key)
    desc = DESCRIPTIONS.fetch(type_key.to_sym, 'unknown type')
    misc = type[:likely_misconceptions].empty? ? 'none' : type[:likely_misconceptions].join(', ')
    <<~CONTEXT
      LEARNER TYPE: #{type_key}
      - Tendency: #{desc}
      - Common misconceptions: #{misc}
      - Memory budget: #{type[:memory_budget_words]} words (compact memory expected)
    CONTEXT
  end
end
