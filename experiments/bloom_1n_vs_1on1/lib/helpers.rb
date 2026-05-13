# ABOUTME: Pure helper functions for JSON extraction, ID generation, and prompt formatting
# ABOUTME: All functions are side-effect free and safe to test without LLM or DB

require 'json'
require 'securerandom'

module Helpers
  def self.extract_json(text)
    match = text.match(/\{.*\}/m)
    return nil unless match
    JSON.parse(match[0])
  rescue JSON::ParserError
    nil
  end

  def self.generate_id
    SecureRandom.uuid
  end

  def self.load_file(path)
    File.read(path).strip
  end

  def self.format_turns_for_prompt(turns)
    turns.map { |t| "[#{t['speaker']}] #{t['content']}" }.join("\n\n")
  end

  def self.build_prompt(system:, context:, instruction:)
    parts = []
    parts << "SYSTEM:\n#{system}" unless system.nil? || system.empty?
    parts << "CONTEXT:\n#{context}" unless context.nil? || context.empty?
    parts << "INSTRUCTION:\n#{instruction}"
    parts.join("\n\n---\n\n")
  end
end
