# ABOUTME: Tests MemoryDiagnostics — pure functions for detecting 6 zarn-domain knowledge items
# ABOUTME: No LLM calls; verifies regex detection and delta computation

$LOAD_PATH.unshift File.join(__dir__, '..', 'lib')
require 'minitest/autorun'
require 'memory_diagnostics'

class TestMemoryDiagnostics < Minitest::Test
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

  def test_detect_blue_activation_present
    mem = empty_memory.merge('rules' => ['Blue is active if there is a Green to its left'])
    assert MemoryDiagnostics.detect(mem)[:blue_activation]
  end

  def test_detect_blue_activation_absent
    mem = empty_memory.merge('rules' => ['Yellow is always active and scores 7'])
    refute MemoryDiagnostics.detect(mem)[:blue_activation]
  end

  def test_detect_green_end_position
    mem = empty_memory.merge('edge_cases' => ['Green is inactive when it is the last token in the sequence'])
    assert MemoryDiagnostics.detect(mem)[:green_end_position]
  end

  def test_detect_red_modifier
    mem = empty_memory.merge('rules' => ['Red is a pure modifier: doubles the token to its right, itself scores 0'])
    assert MemoryDiagnostics.detect(mem)[:red_modifier]
  end

  def test_detect_yellow_always_active
    mem = empty_memory.merge('rules' => ['Yellow is always active and scores 7 in any position'])
    assert MemoryDiagnostics.detect(mem)[:yellow_always_active]
  end

  def test_detect_activation_before_modification
    mem = empty_memory.merge('strategy' => ['Check activation status before applying modifier doubling'])
    assert MemoryDiagnostics.detect(mem)[:activation_before_modification]
  end

  def test_detect_final_summing
    mem = empty_memory.merge('strategy' => ['Sum all active token values to get the final score'])
    assert MemoryDiagnostics.detect(mem)[:final_summing]
  end

  def test_coverage_count_empty_memory
    assert_equal 0, MemoryDiagnostics.coverage_count(empty_memory)
  end

  def test_coverage_count_full_memory
    mem = empty_memory.merge(
      'rules' => [
        'Blue is active if there is a Green to its left',
        'Red is a modifier: doubles the next token. Red itself scores 0.',
        'Yellow is always active and scores 7 in any position'
      ],
      'edge_cases' => ['Green is inactive when it is the last token'],
      'strategy'   => [
        'Check activation status before applying the modifier doubling',
        'Sum all active token values for the final score'
      ]
    )
    assert_equal 6, MemoryDiagnostics.coverage_count(mem)
  end

  def test_delta_counts_acquired_items
    before = empty_memory
    after  = empty_memory.merge('rules' => ['Blue is active if Green is to its left in the sequence'])
    result = MemoryDiagnostics.delta(before, after)
    assert_equal 1, result[:acquired]
    assert_equal 0, result[:lost]
    assert_equal 0, result[:stable]
  end

  def test_delta_zero_when_identical
    mem = empty_memory.merge('rules' => ['Red doubles next token, Red scores 0'])
    result = MemoryDiagnostics.delta(mem, mem)
    assert_equal 0, result[:acquired]
    assert_equal 0, result[:lost]
  end

  def test_delta_detects_lost_item
    before = empty_memory.merge('rules' => ['Yellow is always active and scores 7 in any position'])
    after  = empty_memory
    result = MemoryDiagnostics.delta(before, after)
    assert_equal 0, result[:acquired]
    assert_equal 1, result[:lost]
  end
end
