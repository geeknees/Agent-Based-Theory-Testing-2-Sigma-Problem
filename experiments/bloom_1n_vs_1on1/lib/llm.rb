# ABOUTME: Thin wrapper around `claude --print` for synchronous LLM calls
# ABOUTME: Accepts optional TokenTracker and phase name for token usage tracking

require 'open3'

module LLM
  MAX_RETRIES   = 3
  INTER_CALL_PAUSE = 3  # seconds between calls to avoid rate limits

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
      sleep INTER_CALL_PAUSE
      text
    rescue RuntimeError => e
      if attempts < MAX_RETRIES
        wait = attempts * 30  # 30s then 60s
        $stderr.puts "[LLM] Transient error, retrying in #{wait}s (attempt #{attempts}/#{MAX_RETRIES - 1})"
        sleep wait
        retry
      end
      raise
    end
  end
end
