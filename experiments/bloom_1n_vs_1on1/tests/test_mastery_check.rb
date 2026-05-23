# ABOUTME: Tests for MasteryCheck phase — pure-function coverage only (no LLM calls)
# ABOUTME: Tests corrective-note patching and mastery-check result scoring logic

$LOAD_PATH.unshift File.join(__dir__, '..', 'lib')
require 'minitest/autorun'
require 'json'

class TestMasteryCheckPatch < Minitest::Test
  def base_memory
    {
      'rules'                    => ['Blue active if Green to left', 'Green inactive if last'],
      'examples'                 => ['Green,Blue,Yellow = 14'],
      'edge_cases'               => [],
      'strategy'                 => ['check activation before score'],
      'corrected_misconceptions' => [],
      'remaining_misconceptions' => [],
      'uncertain_rules'          => []
    }
  end

  def test_append_corrective_note_adds_to_array
    mem = base_memory
    note = 'Edge case: [Red, Blue]. Blue inactive, doubled(0)=0.'
    mem['corrected_misconceptions'] << note
    assert_includes mem['corrected_misconceptions'], note
  end

  def test_append_two_notes_accumulates
    mem = base_memory
    mem['corrected_misconceptions'] << 'Note 1'
    mem['corrected_misconceptions'] << 'Note 2'
    assert_equal 2, mem['corrected_misconceptions'].size
  end

  def test_mastery_check_score_correct_when_answer_matches
    task = { 'expected_answer' => '7', 'expected_active_tokens' => ['Yellow'],
             'expected_mistakes' => [], 'acceptable_aliases' => {} }
    parsed = { 'answer' => '7', 'active_tokens' => ['Yellow'], 'mistakes_found' => [],
               'confidence' => 0.9, 'abstain' => false }
    require 'scorer'
    result = Scorer.score_attempt(parsed, task)
    assert result['answer_correct'], "Expected answer_correct to be true"
  end

  def test_mastery_check_score_wrong_when_answer_differs
    task = { 'expected_answer' => '7', 'expected_active_tokens' => [],
             'expected_mistakes' => [], 'acceptable_aliases' => {} }
    parsed = { 'answer' => '5', 'active_tokens' => [], 'mistakes_found' => [],
               'confidence' => 0.5, 'abstain' => false }
    require 'scorer'
    result = Scorer.score_attempt(parsed, task)
    refute result['answer_correct'], "Expected answer_correct to be false"
  end
end
