# ABOUTME: Tests for the Profiles module — learner profile constants and prompt helpers
# ABOUTME: No LLM calls; purely deterministic structure and string generation

$LOAD_PATH.unshift File.join(__dir__, '..', 'lib')
require 'minitest/autorun'
require 'profiles'

class TestProfileConstants < Minitest::Test
  def test_homogeneous_has_4_profiles
    assert_equal 4, Profiles::HOMOGENEOUS.size
  end

  def test_heterogeneous_has_4_profiles
    assert_equal 4, Profiles::HETEROGENEOUS.size
  end

  def test_all_profiles_have_required_keys
    required = %i[ability interest misconception learning_style attention]
    (Profiles::HOMOGENEOUS + Profiles::HETEROGENEOUS).each do |p|
      required.each { |k| assert p.key?(k), "Missing key #{k} in #{p}" }
    end
  end

  def test_homogeneous_profiles_are_similar
    abilities = Profiles::HOMOGENEOUS.map { |p| p[:ability] }.uniq
    assert_equal ['medium'], abilities, "Homogeneous class should have uniform ability"
  end

  def test_heterogeneous_includes_all_ability_levels
    abilities = Profiles::HETEROGENEOUS.map { |p| p[:ability] }
    assert_includes abilities, 'high'
    assert_includes abilities, 'medium'
    assert_includes abilities, 'low'
  end

  def test_heterogeneous_includes_varied_misconceptions
    misconceptions = Profiles::HETEROGENEOUS.map { |p| p[:misconception] }.uniq
    assert misconceptions.size >= 3, "Heterogeneous class should have at least 3 distinct misconceptions"
  end
end

class TestProfilePromptHelpers < Minitest::Test
  def test_to_tutor_context_includes_ability
    profile = { ability: 'high', interest: 'abstract_rules', misconception: 'none',
                learning_style: 'rule_first', attention: 'high' }
    text = Profiles.to_tutor_context(profile)
    assert_includes text, 'high'
    assert_includes text, 'LEARNER PROFILE'
  end

  def test_to_tutor_context_includes_misconception_warning
    profile = { ability: 'low', interest: 'simple_sequences',
                misconception: 'thinks_blue_always_active',
                learning_style: 'step_by_step', attention: 'low' }
    text = Profiles.to_tutor_context(profile)
    assert_includes text.downcase, 'blue'
    assert_includes text.upcase, 'CRITICAL'
  end

  def test_to_tutor_context_none_misconception_has_no_critical
    profile = { ability: 'high', interest: 'abstract_rules', misconception: 'none',
                learning_style: 'rule_first', attention: 'high' }
    text = Profiles.to_tutor_context(profile)
    refute_includes text, 'CRITICAL'
  end

  def test_homogeneous_class_context_returns_string
    text = Profiles.homogeneous_class_context
    assert_instance_of String, text
    assert text.length > 50
    assert_includes text.downcase, 'medium'
  end

  def test_heterogeneous_class_context_includes_all_profiles
    text = Profiles.heterogeneous_class_context(Profiles::HETEROGENEOUS)
    assert_includes text, 'high'
    assert_includes text, 'low'
  end
end
