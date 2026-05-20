# ABOUTME: Tests for ClassroomForcedCheckin phase — verifies turn structure and forced interaction
# ABOUTME: Uses LLM stub to avoid real API calls; tests are purely structural

$LOAD_PATH.unshift File.join(__dir__, '..', 'lib')
require 'minitest/autorun'
require 'phases/classroom_forced_checkin'

class TestClassroomForcedCheckin < Minitest::Test
  def test_config
    { 'models' => { 'teacher' => 'model', 'learner' => 'model' } }
  end

  def stub_run(learner_ids)
    LLM.stub(:call, 'stub response') do
      Phases::ClassroomForcedCheckin.run(
        teacher_id: 'teacher1',
        learner_ids: learner_ids,
        teacher_prompt: 'sys',
        learner_prompt: 'sys',
        lesson: 'lesson text',
        config: test_config
      )
    end
  end

  def test_returns_correct_condition_name
    result = stub_run(['l1'])
    assert_equal 'classroom_forced_checkin', result['condition']
  end

  def test_includes_lecture_turn
    result = stub_run(['l1', 'l2'])
    types = result['turns'].map { |t| t['type'] }
    assert_includes types, 'lecture'
  end

  def test_generates_checkin_question_for_each_learner
    result = stub_run(['l1', 'l2', 'l3'])
    checkins = result['turns'].select { |t| t['type'] == 'checkin_question' }
    assert_equal 3, checkins.size
  end

  def test_generates_checkin_answer_for_each_learner
    result = stub_run(['l1', 'l2'])
    answers = result['turns'].select { |t| t['type'] == 'checkin_answer' }
    assert_equal 2, answers.size
  end

  def test_generates_correction_for_each_learner
    result = stub_run(['l1', 'l2'])
    corrections = result['turns'].select { |t| t['type'] == 'checkin_correction' }
    assert_equal 2, corrections.size
  end

  def test_turn_count_is_one_lecture_plus_three_per_learner
    learner_ids = %w[l1 l2 l3]
    result = stub_run(learner_ids)
    assert_equal 1 + 3 * learner_ids.size, result['turns'].size
  end

  def test_checkin_question_has_target_field
    result = stub_run(['l1'])
    checkin = result['turns'].find { |t| t['type'] == 'checkin_question' }
    assert_equal 'l1', checkin['target']
  end

  def test_learner_answers_are_attributed_to_correct_learner
    result = stub_run(['l1', 'l2'])
    speakers = result['turns'].select { |t| t['type'] == 'checkin_answer' }.map { |t| t['speaker'] }
    assert_includes speakers, 'l1'
    assert_includes speakers, 'l2'
  end

  def test_stores_all_learner_ids
    result = stub_run(['l1', 'l2'])
    assert_equal ['l1', 'l2'], result['learner_ids']
  end
end
