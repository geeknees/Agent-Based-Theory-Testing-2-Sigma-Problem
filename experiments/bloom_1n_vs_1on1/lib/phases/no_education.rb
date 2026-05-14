# ABOUTME: Baseline condition — no lesson, no tutor, empty memory
# ABOUTME: Zero LLM calls; used to measure base model performance without education

module Phases
  module NoEducation
    EMPTY_MEMORY = {
      'rules'      => [],
      'mistakes'   => [],
      'strategy'   => [],
      'edge_cases' => []
    }.freeze

    def self.generate_memory(learner_id:)
      $stderr.puts "[no_education:#{learner_id}] Empty memory generated (baseline condition)"
      EMPTY_MEMORY.transform_values(&:dup)
    end
  end
end
