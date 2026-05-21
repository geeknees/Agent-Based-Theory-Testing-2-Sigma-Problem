# ABOUTME: Tests for v7 report additions — dynamic conditions, passive_listener rescue, order_confused scaffold
# ABOUTME: Pure function tests; no DB or LLM calls

$LOAD_PATH.unshift File.join(__dir__, '..', 'lib')
require 'minitest/autorun'
require 'json'
require 'securerandom'
require 'report'

class TestProcedureOrderErrorRate < Minitest::Test
  def make_row(response_text, condition: '1on1', answer_correct: false)
    {
      'condition'     => condition,
      'learner_id'    => SecureRandom.uuid,
      'task_id'       => 'l3_rule_interaction_01',
      'task_type'     => 'rule_interaction',
      'response_text' => response_text,
      'score_json'    => JSON.dump({ 'answer_correct' => answer_correct, 'total' => 0 }),
      'profile_json'  => JSON.dump({ 'type_key' => 'order_confused' })
    }
  end

  def test_detects_modifier_before_activation
    row = make_row("First I multiply: 3 × 2 = 6, then check if blue token is active")
    assert Report.procedure_order_error?(row['response_text']),
           "Should detect modifier applied before activation check"
  end

  def test_no_error_when_activation_checked_first
    row = make_row("Step 1: check activation — blue token is active. Step 2: apply modifier 3 × 2 = 6")
    refute Report.procedure_order_error?(row['response_text']),
           "Should not flag when activation checked before modifier"
  end

  def test_rate_is_zero_for_empty_rows
    assert_equal 0.0, Report.procedure_order_error_rate([])
  end

  def test_rate_calculation
    rows = [
      make_row("multiply first: 3 × 2, then check active"),
      make_row("check active first, then multiply"),
      make_row("Step 1: active check. Step 2: × modifier")
    ]
    rate = Report.procedure_order_error_rate(rows)
    assert_in_delta (1.0 / 3.0), rate, 0.01
  end
end

class TestPassiveListenerRescueEffect < Minitest::Test
  def make_row(condition, answer_correct, type_key: 'passive_listener')
    {
      'condition'     => condition,
      'learner_id'    => SecureRandom.uuid,
      'task_id'       => 'l1_recall_01',
      'task_type'     => 'recall',
      'response_text' => 'answer',
      'score_json'    => JSON.dump({ 'answer_correct' => answer_correct, 'total' => answer_correct ? 12 : 0 }),
      'profile_json'  => JSON.dump({ 'type_key' => type_key })
    }
  end

  def test_returns_table_with_three_conditions
    rows = [
      make_row('classroom_public_qa', false),
      make_row('classroom_forced_checkin', true),
      make_row('one_on_one_tutoring', true),
    ]
    table = Report.passive_listener_rescue_effect(rows)
    assert_includes table, 'classroom_public_qa'
    assert_includes table, 'classroom_forced_checkin'
    assert_includes table, 'one_on_one_tutoring'
  end

  def test_shows_correct_percentages
    rows = [
      make_row('classroom_public_qa', false),
      make_row('classroom_public_qa', false),
      make_row('classroom_forced_checkin', true),
      make_row('classroom_forced_checkin', false),
      make_row('one_on_one_tutoring', true),
    ]
    table = Report.passive_listener_rescue_effect(rows)
    assert_includes table, '0%'
    assert_includes table, '50%'
    assert_includes table, '100%'
  end

  def test_returns_empty_string_when_no_passive_listener_data
    assert_equal '', Report.passive_listener_rescue_effect([])
  end
end

class TestOrderConfusedScaffoldEffect < Minitest::Test
  def make_row(condition, answer_correct, response_text: 'no multiplier', type_key: 'order_confused')
    {
      'condition'     => condition,
      'learner_id'    => SecureRandom.uuid,
      'task_id'       => 'l3_rule_interaction_01',
      'task_type'     => 'rule_interaction',
      'response_text' => response_text,
      'score_json'    => JSON.dump({ 'answer_correct' => answer_correct, 'total' => answer_correct ? 12 : 0 }),
      'profile_json'  => JSON.dump({ 'type_key' => type_key })
    }
  end

  def test_returns_table_with_three_conditions
    rows = [
      make_row('classroom_public_qa', true),
      make_row('generic_one_on_one_tutoring', false),
      make_row('procedure_scaffolded_one_on_one_tutoring', true),
    ]
    table = Report.order_confused_scaffold_effect(rows)
    assert_includes table, 'classroom_public_qa'
    assert_includes table, 'generic_one_on_one_tutoring'
    assert_includes table, 'procedure_scaffolded_one_on_one_tutoring'
  end

  def test_returns_empty_string_when_no_order_confused_data
    assert_equal '', Report.order_confused_scaffold_effect([])
  end
end

class TestDynamicConditionList < Minitest::Test
  def make_row(condition, answer_correct)
    {
      'condition'     => condition,
      'learner_id'    => SecureRandom.uuid,
      'task_id'       => 'l1_recall_01',
      'task_type'     => 'recall',
      'response_text' => 'answer',
      'score_json'    => JSON.dump({ 'answer_correct' => answer_correct }),
      'profile_json'  => nil
    }
  end

  def test_build_markdown_includes_v7_condition_names
    rows = [
      make_row('classroom_public_qa', true),
      make_row('classroom_forced_checkin', false),
      make_row('one_on_one_tutoring', true),
    ]
    config = { 'experiment' => { 'domain' => 'test', 'ceiling_threshold' => 0.9 },
               'models' => { 'teacher' => 'haiku' } }
    md = Report.build_markdown(rows, run_id: 'r1', output_dir: '/tmp', run_config: config,
                               token_summary: {}, experiment_meta: { experiment: 'A' })
    assert_includes md, 'classroom_public_qa'
    assert_includes md, 'classroom_forced_checkin'
    assert_includes md, 'one_on_one_tutoring'
  end

  def test_build_markdown_renders_passive_listener_rescue_for_exp_a
    rows = [
      make_row('classroom_public_qa', false),
      make_row('classroom_forced_checkin', true),
      make_row('one_on_one_tutoring', true),
    ]
    rows.each { |r| r['profile_json'] = JSON.dump({ 'type_key' => 'passive_listener' }) }
    config = { 'experiment' => { 'domain' => 'test', 'ceiling_threshold' => 0.9 },
               'models' => { 'teacher' => 'haiku' } }
    md = Report.build_markdown(rows, run_id: 'r1', output_dir: '/tmp', run_config: config,
                               token_summary: {}, experiment_meta: { experiment: 'A' })
    assert_includes md, 'Passive Listener Rescue Effect'
  end

  def test_build_markdown_renders_order_confused_scaffold_for_exp_b
    rows = [
      make_row('classroom_public_qa', true),
      make_row('generic_one_on_one_tutoring', false),
      make_row('procedure_scaffolded_one_on_one_tutoring', true),
    ]
    rows.each { |r| r['profile_json'] = JSON.dump({ 'type_key' => 'order_confused' }) }
    config = { 'experiment' => { 'domain' => 'test', 'ceiling_threshold' => 0.9 },
               'models' => { 'teacher' => 'haiku' } }
    md = Report.build_markdown(rows, run_id: 'r1', output_dir: '/tmp', run_config: config,
                               token_summary: {}, experiment_meta: { experiment: 'B' })
    assert_includes md, 'Order Confused Scaffold Effect'
  end
end
