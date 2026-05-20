# ABOUTME: Tests for TutoringProcedureScaffolded phase — verifies 8-turn structure with procedure labels
# ABOUTME: Uses LLM stub; tests are purely structural — verifies turn types in order

$LOAD_PATH.unshift File.join(__dir__, '..', 'lib')
require 'minitest/autorun'
require 'phases/tutoring_procedure_scaffolded'

class TestTutoringProcedureScaffolded < Minitest::Test
  def test_config
    { 'models' => { 'tutor' => 'model', 'learner' => 'model' } }
  end

  def stub_session
    LLM.stub(:call, 'stub response') do
      Phases::TutoringProcedureScaffolded.run_session(
        tutor_id: 'tutor1',
        learner_id: 'learner1',
        tutor_prompt: 'sys',
        learner_prompt: 'sys',
        lesson: 'lesson text',
        config: test_config
      )
    end
  end

  def test_returns_correct_condition_name
    result = stub_session
    assert_equal 'procedure_scaffolded_one_on_one_tutoring', result['condition']
  end

  def test_has_exactly_eight_turns
    result = stub_session
    assert_equal 8, result['turns'].size
  end

  def test_turn_types_in_order
    result = stub_session
    expected_types = %w[
      procedure_intro
      procedure_restatement
      diagnostic_q
      diagnostic_answer
      procedure_correction
      correction_acknowledgment
      retest_q
      retest_answer
    ]
    actual_types = result['turns'].map { |t| t['type'] }
    assert_equal expected_types, actual_types
  end

  def test_tutor_speaks_on_odd_turns
    result = stub_session
    tutor_turns = result['turns'].select { |t| t['speaker'] == 'tutor1' }
    assert_equal 4, tutor_turns.size
  end

  def test_learner_speaks_on_even_turns
    result = stub_session
    learner_turns = result['turns'].select { |t| t['speaker'] == 'learner1' }
    assert_equal 4, learner_turns.size
  end

  def test_stores_tutor_and_learner_ids
    result = stub_session
    assert_equal 'tutor1',   result['tutor_id']
    assert_equal 'learner1', result['learner_id']
  end

  def test_procedure_intro_is_first_turn
    result = stub_session
    assert_equal 'procedure_intro', result['turns'].first['type']
  end

  def test_retest_answer_is_last_turn
    result = stub_session
    assert_equal 'retest_answer', result['turns'].last['type']
  end
end

require 'phases/tutoring'

class TestTutoringConditionParam < Minitest::Test
  def test_config
    { 'models' => { 'tutor' => 'model', 'learner' => 'model' } }
  end

  def test_default_condition_is_1on1
    result = LLM.stub(:call, 'stub') do
      Phases::Tutoring.run_session(
        tutor_id: 't1', learner_id: 'l1',
        tutor_prompt: 'sys', learner_prompt: 'sys',
        lesson: 'lesson', config: test_config
      )
    end
    assert_equal '1on1', result['condition']
  end

  def test_custom_condition_name_propagates
    result = LLM.stub(:call, 'stub') do
      Phases::Tutoring.run_session(
        tutor_id: 't1', learner_id: 'l1',
        tutor_prompt: 'sys', learner_prompt: 'sys',
        lesson: 'lesson', config: test_config,
        condition: 'generic_one_on_one_tutoring'
      )
    end
    assert_equal 'generic_one_on_one_tutoring', result['condition']
  end
end
