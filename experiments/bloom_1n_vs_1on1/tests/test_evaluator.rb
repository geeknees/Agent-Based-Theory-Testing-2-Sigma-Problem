# ABOUTME: Tests for Phases::Evaluator routing — auto-score vs LLM paths
# ABOUTME: Verifies short_rule_induction (L6) bypasses exact-match and uses LLM evaluator

$LOAD_PATH.unshift File.join(__dir__, '..', 'lib')
require 'minitest/autorun'
require 'minitest/mock'
require 'json'
require 'phases/evaluator'

class TestEvaluatorRouting < Minitest::Test
  CONFIG = { 'models' => { 'evaluator' => 'model' } }.freeze

  def recall_task
    {
      'id'                     => 'l1_recall_01',
      'task_type'              => 'recall',
      'expected_answer'        => '14',
      'expected_active_tokens' => [],
      'expected_mistakes'      => [],
      'acceptable_aliases'     => {},
      'prompt'                 => 'What is the score?'
    }
  end

  def l6_task
    {
      'id'                     => 'l6_induction_02',
      'task_type'              => 'short_rule_induction',
      'expected_answer'        => 'red doubles the next token and contributes 0 points itself',
      'expected_active_tokens' => [],
      'expected_mistakes'      => [],
      'acceptable_aliases'     => {},
      'prompt'                 => 'State the rule for Red Zarn.'
    }
  end

  def test_recall_task_is_auto_scored_without_llm
    parsed = { 'answer' => '14', 'active_tokens' => [], 'mistakes_found' => [], 'confidence' => 0.9 }
    # LLM.call must NOT be invoked for recall tasks with a string expected_answer
    LLM.stub(:call, ->(*_) { raise 'LLM.call must not be called for auto-scored tasks' }) do
      score = Phases::Evaluator.score(
        attempt_id: 'a1', learner_response: '{"answer":"14"}',
        parsed_response: parsed, task: recall_task, rubric: {},
        evaluator_id: 'e1', evaluator_prompt: 'eval', config: CONFIG
      )
      assert_equal true,  score['answer_correct']
      assert_equal true,  score['auto_scored']
    end
  end

  def test_l6_task_invokes_llm_evaluator
    parsed = { 'answer' => 'red doubles things', 'active_tokens' => [], 'mistakes_found' => [] }
    llm_called = false
    llm_response = JSON.dump({
      'correctness' => 3, 'reasoning_quality' => 2, 'rule_application' => 3,
      'error_checking' => 2, 'autonomy' => 1, 'total' => 11, 'comments' => 'good'
    })
    LLM.stub(:call, ->(*_) { llm_called = true; llm_response }) do
      score = Phases::Evaluator.score(
        attempt_id: 'a2', learner_response: '{"answer":"red doubles things"}',
        parsed_response: parsed, task: l6_task, rubric: {},
        evaluator_id: 'e1', evaluator_prompt: 'eval', config: CONFIG
      )
      assert llm_called, 'LLM.call should be invoked for short_rule_induction'
      assert_equal false, score['auto_scored']
    end
  end

  def test_l6_score_is_not_forced_to_exact_match
    parsed = { 'answer' => 'completely wrong answer about red', 'active_tokens' => [], 'mistakes_found' => [] }
    llm_response = JSON.dump({
      'correctness' => 3, 'reasoning_quality' => 2, 'rule_application' => 2,
      'error_checking' => 1, 'autonomy' => 1, 'total' => 9, 'comments' => 'partial'
    })
    LLM.stub(:call, ->(*_) { llm_response }) do
      score = Phases::Evaluator.score(
        attempt_id: 'a3', learner_response: 'anything',
        parsed_response: parsed, task: l6_task, rubric: {},
        evaluator_id: 'e1', evaluator_prompt: 'eval', config: CONFIG
      )
      # LLM returned partial score (not forced to 0 by exact-match)
      assert_equal 9, score['total']
    end
  end
end
