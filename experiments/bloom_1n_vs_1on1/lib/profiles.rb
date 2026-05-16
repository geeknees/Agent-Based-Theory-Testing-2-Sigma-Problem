# ABOUTME: Defines fixed learner profile sets for the heterogeneity experiment (HOMOGENEOUS and HETEROGENEOUS)
# ABOUTME: Provides prompt-context helpers injected into classroom and tutoring phase prompts

module Profiles
  HOMOGENEOUS = [
    { ability: 'medium', interest: 'worked_examples', misconception: 'forgets_edge_cases',
      learning_style: 'example_first', attention: 'medium' },
    { ability: 'medium', interest: 'worked_examples', misconception: 'forgets_edge_cases',
      learning_style: 'example_first', attention: 'medium' },
    { ability: 'medium', interest: 'worked_examples', misconception: 'forgets_edge_cases',
      learning_style: 'example_first', attention: 'medium' },
    { ability: 'medium', interest: 'worked_examples', misconception: 'forgets_edge_cases',
      learning_style: 'example_first', attention: 'medium' },
  ].map(&:freeze).freeze

  HETEROGENEOUS = [
    { ability: 'high',   interest: 'abstract_rules',   misconception: 'none',
      learning_style: 'rule_first',    attention: 'high'   },
    { ability: 'medium', interest: 'worked_examples',  misconception: 'forgets_edge_cases',
      learning_style: 'example_first', attention: 'medium' },
    { ability: 'low',    interest: 'simple_sequences', misconception: 'applies_modifiers_before_activation',
      learning_style: 'step_by_step',  attention: 'low'    },
    { ability: 'medium', interest: 'worked_examples',  misconception: 'thinks_blue_always_active',
      learning_style: 'example_first', attention: 'medium' },
  ].map(&:freeze).freeze

  MISCONCEPTION_NOTES = {
    'none' =>
      'The learner has no known systematic misconception.',
    'forgets_edge_cases' =>
      'CRITICAL: This learner forgets edge cases — e.g., that Green at the last position is inactive, or that doubling an inactive token gives 0.',
    'applies_modifiers_before_activation' =>
      'CRITICAL: This learner incorrectly applies modifier rules (like Red doubling) before checking whether the target token is active.',
    'thinks_blue_always_active' =>
      'CRITICAL: This learner incorrectly believes Blue tokens are always active, regardless of whether Green appears to their left.',
  }.freeze

  INTEREST_NOTES = {
    'abstract_rules'   => 'Prefers clear, explicit rule statements over examples.',
    'worked_examples'  => 'Learns best through concrete worked examples.',
    'simple_sequences' => 'Needs short, simple sequences before tackling complex ones.',
  }.freeze

  def self.to_tutor_context(profile)
    <<~CONTEXT
      LEARNER PROFILE:
      - Ability: #{profile[:ability]}
      - Interest: #{INTEREST_NOTES.fetch(profile[:interest].to_s, profile[:interest])}
      - Misconception: #{MISCONCEPTION_NOTES.fetch(profile[:misconception].to_s, 'Unknown')}
      - Learning style: #{profile[:learning_style]}
      - Attention: #{profile[:attention]}

      Adapt your tutoring: match examples to their interest, explicitly diagnose and correct their misconception, keep explanations proportional to their attention level. Ensure the learner's memory includes: rules, edge cases, common mistake, personal strategy.
    CONTEXT
  end

  def self.to_learner_context(profile)
    <<~CONTEXT
      YOUR LEARNING PROFILE (respond authentically to this):
      - You engage best with: #{profile[:interest].to_s.gsub('_', ' ')}
      - Your attention level is: #{profile[:attention]}
    CONTEXT
  end

  def self.homogeneous_class_context
    <<~CONTEXT
      CLASS COMPOSITION: All 4 learners have similar profiles.
      - Ability: medium (all similar)
      - Interest: worked examples
      - Common misconception: forgets edge cases (e.g., Green at last position, doubling inactive tokens)
      - Learning style: example-first
      Teach one shared lesson. Use worked examples. Watch for edge case errors in Q&A.
    CONTEXT
  end

  def self.heterogeneous_class_context(profiles)
    lines = profiles.each_with_index.map do |p, i|
      "  Learner #{i + 1}: ability=#{p[:ability]}, interest=#{p[:interest].to_s.gsub('_', ' ')}, " \
      "misconception=#{p[:misconception].to_s.gsub('_', ' ')}"
    end.join("\n")
    <<~CONTEXT
      CLASS COMPOSITION: 4 learners with mixed profiles.
      #{lines}
      Teach ONE shared lesson. You cannot fully personalize to each learner. Public Q&A is allowed but keep answers useful to the whole class. Limited time prevents individual remediation of each learner's misconception.
    CONTEXT
  end
end
