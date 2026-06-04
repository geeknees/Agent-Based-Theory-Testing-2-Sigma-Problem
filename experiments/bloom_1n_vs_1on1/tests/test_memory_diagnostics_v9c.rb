# ABOUTME: Tests the 4 new MemoryDiagnostics items added for v9c (10-item schema)
# ABOUTME: Verifies detection and coverage_count for inactive_token, edge_case_checklist, debugging, mistakes

$LOAD_PATH.unshift File.join(__dir__, '..', 'lib')
require 'minitest/autorun'
require 'memory_diagnostics'

class TestMemoryDiagnosticsV9c < Minitest::Test
  def empty_memory
    {
      'rules'                    => [],
      'examples'                 => [],
      'edge_cases'               => [],
      'strategy'                 => [],
      'corrected_misconceptions' => [],
      'remaining_misconceptions' => [],
      'uncertain_rules'          => []
    }
  end

  def test_detect_inactive_token_modifier_rule_present
    mem = empty_memory.merge('edge_cases' => ['doubled inactive token is still 0'])
    assert MemoryDiagnostics.detect(mem)[:inactive_token_modifier_rule]
  end

  def test_detect_inactive_token_modifier_rule_absent
    mem = empty_memory.merge('rules' => ['Red doubles the next token'])
    refute MemoryDiagnostics.detect(mem)[:inactive_token_modifier_rule]
  end

  def test_detect_inactive_token_modifier_rule_variant_wording
    mem = empty_memory.merge('edge_cases' => ['if Blue is inactive, Red doubled(0) = 0'])
    assert MemoryDiagnostics.detect(mem)[:inactive_token_modifier_rule]
  end

  def test_detect_edge_case_checklist_present
    mem = empty_memory.merge('strategy' => ['check Green end, check Blue left, checklist complete'])
    assert MemoryDiagnostics.detect(mem)[:edge_case_checklist]
  end

  def test_detect_edge_case_checklist_absent
    mem = empty_memory.merge('rules' => ['Blue needs Green to its left'])
    refute MemoryDiagnostics.detect(mem)[:edge_case_checklist]
  end

  def test_detect_debugging_strategy_present
    mem = empty_memory.merge('strategy' => ['work left to right, token by token through the sequence'])
    assert MemoryDiagnostics.detect(mem)[:debugging_strategy]
  end

  def test_detect_debugging_strategy_variant_wording
    mem = empty_memory.merge('strategy' => ['debug by checking each position systematically'])
    assert MemoryDiagnostics.detect(mem)[:debugging_strategy]
  end

  def test_detect_debugging_strategy_absent
    mem = empty_memory.merge('strategy' => ['sum all active tokens at the end'])
    refute MemoryDiagnostics.detect(mem)[:debugging_strategy]
  end

  def test_detect_common_mistake_notes_present
    mem = empty_memory.merge('corrected_misconceptions' => ['common mistake: counting Red base value (3)'])
    assert MemoryDiagnostics.detect(mem)[:common_mistake_notes]
  end

  def test_detect_common_mistake_notes_variant
    mem = empty_memory.merge('corrected_misconceptions' => ['avoid assuming Blue is always active'])
    assert MemoryDiagnostics.detect(mem)[:common_mistake_notes]
  end

  def test_detect_common_mistake_notes_absent
    mem = empty_memory.merge('rules' => ['Blue is active only with Green to its left'])
    refute MemoryDiagnostics.detect(mem)[:common_mistake_notes]
  end

  def test_coverage_count_includes_all_10_items
    mem = empty_memory.merge(
      'rules'   => [
        'Blue is active if there is a Green to its left',
        'Red is a modifier: doubles the next token. Red itself scores 0.',
        'Yellow is always active and scores 7 in any position',
        'doubled inactive token is still 0'
      ],
      'edge_cases' => [
        'Green is inactive when it is the last token',
        'checklist: check Green end, check Blue left, check doubled inactive'
      ],
      'strategy' => [
        'Check activation status before applying the modifier doubling',
        'Sum all active token values for the final score',
        'work left to right, token by token to debug'
      ],
      'corrected_misconceptions' => [
        'common mistake: counting Red base value instead of 0'
      ]
    )
    assert_equal 10, MemoryDiagnostics.coverage_count(mem)
  end

  def test_existing_6_items_still_detected
    mem = empty_memory.merge(
      'rules'    => ['Blue is active if there is a Green to its left',
                     'Red is a modifier: doubles next token, Red scores 0',
                     'Yellow is always active and scores 7'],
      'edge_cases' => ['Green is inactive when it is the last token'],
      'strategy' => ['Check activation status before applying modifier doubling',
                     'Sum all active token values for the final score']
    )
    diag = MemoryDiagnostics.detect(mem)
    assert diag[:blue_activation]
    assert diag[:red_modifier]
    assert diag[:yellow_always_active]
    assert diag[:green_end_position]
    assert diag[:activation_before_modification]
    assert diag[:final_summing]
  end
end
