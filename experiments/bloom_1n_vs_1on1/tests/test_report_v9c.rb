# ABOUTME: Tests for v9c-specific report sections: readiness summary, fine-grained delta, flags
# ABOUTME: All helpers are pure functions using pre-built fixture data — no LLM calls

$LOAD_PATH.unshift File.join(__dir__, '..', 'lib')
require 'minitest/autorun'
require 'report'
require 'memory_diagnostics'

class TestReadinessSummarySection < Minitest::Test
  def mastery_rows_all_pass
    [
      { 'check_type' => 'recall',           'answer_correct' => 1, 'condition' => 'lecture_only' },
      { 'check_type' => 'edge_case',        'answer_correct' => 1, 'condition' => 'lecture_only' },
      { 'check_type' => 'rule_interaction', 'answer_correct' => 1, 'condition' => 'lecture_only' },
      { 'check_type' => 'procedure_order',  'answer_correct' => 1, 'condition' => 'lecture_only' }
    ]
  end

  def mastery_rows_partial
    [
      { 'check_type' => 'recall',           'answer_correct' => 1, 'condition' => 'pair_discussion_size_2' },
      { 'check_type' => 'edge_case',        'answer_correct' => 1, 'condition' => 'pair_discussion_size_2' },
      { 'check_type' => 'rule_interaction', 'answer_correct' => 0, 'condition' => 'pair_discussion_size_2' },
      { 'check_type' => 'procedure_order',  'answer_correct' => 0, 'condition' => 'pair_discussion_size_2' }
    ]
  end

  def test_readiness_summary_shows_procedure_order_check_type
    section = Report.send(:readiness_summary_section, mastery_rows_all_pass, 1.0)
    assert_includes section, 'procedure_order'
  end

  def test_readiness_summary_shows_pass_rate
    section = Report.send(:readiness_summary_section, mastery_rows_all_pass, 1.0)
    assert_includes section, '100%'
  end

  def test_readiness_summary_flags_failure_when_below_80
    section = Report.send(:readiness_summary_section, mastery_rows_partial, 0.50)
    assert_includes section, 'READINESS TARGET NOT MET'
  end

  def test_readiness_summary_confirms_target_when_met
    section = Report.send(:readiness_summary_section, mastery_rows_all_pass, 1.0)
    assert_includes section, 'Readiness target met'
  end
end

class TestFineGrainedMemoryDeltaSection < Minitest::Test
  def pre_snapshots
    [
      {
        'learner_id' => 'l-001',
        'condition'  => 'pair_discussion_size_2',
        'diag'       => { blue_activation: true, green_end_position: false,
                          red_modifier: true, yellow_always_active: true,
                          activation_before_modification: false, final_summing: true,
                          inactive_token_modifier_rule: false, edge_case_checklist: false,
                          debugging_strategy: false, common_mistake_notes: false }
      }
    ]
  end

  def memories_by_condition
    {
      'pair_discussion_size_2' => [
        {
          'learner_id' => 'l-001',
          'memory'     => {
            'rules'       => ['Blue is active if there is a Green to its left',
                              'Red is a modifier: doubles next token, Red scores 0',
                              'Yellow is always active and scores 7',
                              'doubled inactive token is still 0'],
            'edge_cases'  => ['Green is inactive when it is the last token',
                              'checklist: check Green end, check Blue left'],
            'strategy'    => ['Check activation status before applying modifier doubling',
                              'Sum all active token values for the final score',
                              'work left to right, token by token to debug'],
            'corrected_misconceptions' => ['common mistake: counting Red base value'],
            'examples'                 => [],
            'remaining_misconceptions' => [],
            'uncertain_rules'          => []
          },
          'type_key' => 'rule_extractor'
        }
      ]
    }
  end

  def test_section_contains_condition_name
    section = Report.send(:fine_grained_memory_delta_section, pre_snapshots, memories_by_condition)
    assert_includes section, 'pair_discussion_size_2'
  end

  def test_section_contains_delta_header
    section = Report.send(:fine_grained_memory_delta_section, pre_snapshots, memories_by_condition)
    assert_includes section, 'Memory Delta'
  end

  def test_section_shows_acquired_items
    section = Report.send(:fine_grained_memory_delta_section, pre_snapshots, memories_by_condition)
    assert_includes section, 'Acquired'
  end
end

class TestInterpretationFlagsSection < Minitest::Test
  def rows_lecture_only_dominates
    conds = %w[lecture_only pair_discussion_size_2 large_class_discussion_size_16]
    conds.flat_map do |cond|
      score = cond == 'lecture_only' ? 1 : 0
      3.times.map do
        { 'condition' => cond, 'learner_id' => "l-#{rand}",
          'score_json' => JSON.dump('answer_correct' => score == 1),
          'profile_json' => nil }
      end
    end
  end

  def ownership_rows_lecture_only
    [
      { 'condition' => 'lecture_only', 'ownership_score' => 0,
        'contribution_count' => 0, 'attempted_answer' => 0, 'received_feedback' => 0,
        'memory_delta_after_discussion' => 0 },
      { 'condition' => 'pair_discussion_size_2', 'ownership_score' => 3,
        'contribution_count' => 2, 'attempted_answer' => 1, 'received_feedback' => 1,
        'memory_delta_after_discussion' => 0 }
    ]
  end

  def test_flags_section_shows_readiness_failed_true_when_below_target
    section = Report.send(:interpretation_flags_section,
                          rows_lecture_only_dominates, [], ownership_rows_lecture_only, 0.50)
    assert_includes section, 'readiness_failed'
    assert_includes section, 'true'
  end

  def test_flags_section_shows_lecture_only_dominant_true
    section = Report.send(:interpretation_flags_section,
                          rows_lecture_only_dominates, [], ownership_rows_lecture_only, 0.90)
    assert_includes section, 'lecture_only_dominant'
    assert_includes section, 'true'
  end
end
