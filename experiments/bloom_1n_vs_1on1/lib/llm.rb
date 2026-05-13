# ABOUTME: Thin wrapper around `claude --print` for synchronous LLM calls
# ABOUTME: Raises on non-zero exit; returns stripped response text

require 'open3'

module LLM
  def self.call(prompt, model: nil)
    args = ['claude', '--print']
    args += ['--model', model] if model
    stdout, stderr, status = Open3.capture3(*args, stdin_data: prompt)
    unless status.success?
      raise "LLM call failed (exit #{status.exitstatus}): #{stderr.strip}"
    end
    stdout.strip
  end
end
