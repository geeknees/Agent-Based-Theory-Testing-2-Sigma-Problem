# ABOUTME: Unit tests for Helpers module pure functions
# ABOUTME: No LLM or database calls; all deterministic

$LOAD_PATH.unshift File.join(__dir__, '..', 'lib')
require 'minitest/autorun'
require 'helpers'

class TestExtractJson < Minitest::Test
  def test_extracts_json_from_plain_object
    text = '{"correctness": 3, "total": 3}'
    result = Helpers.extract_json(text)
    assert_equal 3, result['correctness']
  end

  def test_extracts_json_surrounded_by_prose
    text = "Here is my score:\n{\"correctness\": 4, \"total\": 4}\nThank you."
    result = Helpers.extract_json(text)
    assert_equal 4, result['correctness']
  end

  def test_returns_nil_for_no_json
    result = Helpers.extract_json("There is no JSON here.")
    assert_nil result
  end

  def test_returns_nil_for_invalid_json
    result = Helpers.extract_json("{not valid json}")
    assert_nil result
  end
end

class TestFormatTurns < Minitest::Test
  def test_formats_turns_as_speaker_content
    turns = [
      { 'speaker' => 'teacher', 'content' => 'Hello class.' },
      { 'speaker' => 'learner_1', 'content' => 'Hello teacher.' }
    ]
    result = Helpers.format_turns_for_prompt(turns)
    assert_includes result, '[teacher] Hello class.'
    assert_includes result, '[learner_1] Hello teacher.'
  end

  def test_empty_turns_returns_empty_string
    result = Helpers.format_turns_for_prompt([])
    assert_equal '', result
  end
end

class TestBuildPrompt < Minitest::Test
  def test_includes_all_sections
    result = Helpers.build_prompt(
      system: 'You are a teacher.',
      context: 'The lesson is about Zarn.',
      instruction: 'Deliver the lecture.'
    )
    assert_includes result, 'SYSTEM:'
    assert_includes result, 'CONTEXT:'
    assert_includes result, 'INSTRUCTION:'
  end

  def test_omits_nil_system
    result = Helpers.build_prompt(
      system: nil,
      context: 'context',
      instruction: 'do it'
    )
    refute_includes result, 'SYSTEM:'
    assert_includes result, 'INSTRUCTION:'
  end
end

class TestGenerateId < Minitest::Test
  def test_returns_string
    assert_instance_of String, Helpers.generate_id
  end

  def test_unique_ids
    ids = Array.new(10) { Helpers.generate_id }
    assert_equal 10, ids.uniq.size
  end
end
