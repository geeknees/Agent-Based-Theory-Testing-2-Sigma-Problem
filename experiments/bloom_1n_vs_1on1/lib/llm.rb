# ABOUTME: Thin wrapper around `claude --print` for synchronous LLM calls
# ABOUTME: Accepts optional TokenTracker and phase name for token usage tracking

require 'open3'

module LLM
  def self.call(prompt, model: nil, tracker: nil, phase: nil)
    args = ['claude', '--print']
    args += ['--model', model] if model
    stdout, stderr, status = Open3.capture3(*args, stdin_data: prompt)
    unless status.success?
      raise "LLM call failed (exit #{status.exitstatus}): #{stderr.strip}"
    end
    text = stdout.strip
    tracker.track(phase, prompt, text) if tracker && phase
    text
  end
end
