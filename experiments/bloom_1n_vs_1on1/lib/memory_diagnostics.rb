# ABOUTME: Detects presence of 10 key knowledge items in a learner memory hash
# ABOUTME: Pure functions — no LLM calls; used for pre/post-discussion diagnostics

module MemoryDiagnostics
  # Regex patterns for each knowledge item in the zarn-tokens domain
  ITEMS = {
    blue_activation:               /blue.*green.*left|green.*left.*blue|blue.*active.*if.*green|need.*green.*before.*blue/i,
    green_end_position:            /green.*last|green.*end.*inactive|last.*green.*inactive|green.*inactive.*last/i,
    red_modifier:                  /red.*double|red.*modifier|red.*pure.*modifier|red.*scores.*0|red.*itself.*0/i,
    yellow_always_active:          /yellow.*always|yellow.*7.*any|yellow.*active.*any.*position|always.*active.*yellow/i,
    activation_before_modification: /activation.*before.*modifier|activation.*first.*modifier|check.*active.*before.*double|activation.*status.*before/i,
    final_summing:                 /sum.*active|add.*active|total.*active|sum.*all.*active/i,
    inactive_token_modifier_rule:  /doubled.*inactive|inactive.*doubled|doubled.*zero|0.*doubled|inactive.*still.*0/i,
    edge_case_checklist:           /checklist|check.*green.*end|check.*blue.*left|green.*end.*check|blue.*activation.*check/i,
    debugging_strategy:            /left.*to.*right|token.*by.*token|position.*by.*position|debug.*each|systematic.*token/i,
    common_mistake_notes:          /common.*mistake|avoid.*assuming|avoid.*red|never.*count.*red|mistake.*counting/i
  }.freeze

  # Returns { item_key => bool } for all 10 items
  def self.detect(memory)
    text = memory_to_text(memory)
    ITEMS.transform_values { |pattern| text.match?(pattern) }
  end

  # Number of detected items (0–10)
  def self.coverage_count(memory)
    detect(memory).count { |_, v| v }
  end

  # Returns { acquired:, lost:, stable: } counts comparing two memory snapshots
  def self.delta(before_memory, after_memory)
    before = detect(before_memory)
    after  = detect(after_memory)
    {
      acquired: ITEMS.keys.count { |k| !before[k] && after[k] },
      lost:     ITEMS.keys.count { |k|  before[k] && !after[k] },
      stable:   ITEMS.keys.count { |k|  before[k] &&  after[k] }
    }
  end

  private_class_method def self.memory_to_text(memory)
    return '' unless memory.is_a?(Hash)
    memory.values.flatten.compact.join(' ')
  end
end
