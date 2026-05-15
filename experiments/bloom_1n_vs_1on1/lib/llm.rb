# ABOUTME: Thin wrapper around `claude --print` for synchronous LLM calls
# ABOUTME: Accepts optional TokenTracker and phase name for token usage tracking

require 'open3'

module LLM
  MAX_RETRIES = 3

  def self.call(prompt, model: nil, tracker: nil, phase: nil)
    args = ['claude', '--print']
    args += ['--model', model] if model
    attempts = 0
    begin
      attempts += 1
      stdout, stderr, status = Open3.capture3(*args, stdin_data: prompt)
      unless status.success?
        raise "LLM call failed (exit #{status.exitstatus}): #{stderr.strip}"
      end
      text = stdout.strip
      tracker.track(phase, prompt, text) if tracker && phase
      text
    rescue RuntimeError => e
      if attempts < MAX_RETRIES
        wait = attempts * 10
        $stderr.puts "[LLM] Transient error, retrying in #{wait}s (attempt #{attempts}/#{MAX_RETRIES - 1}): #{e.message}"
        sleep wait
        retry
      end
      raise
    end
  end
end
