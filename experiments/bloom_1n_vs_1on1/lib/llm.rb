# ABOUTME: Thin wrapper around `claude --print` for synchronous LLM calls
# ABOUTME: Handles token-rate-limit errors by waiting for the rate limit window to reset

require 'open3'

module LLM
  # Token rate limit (TPM) resets in approximately 5 hours.
  # MAX_RETRIES is large so the experiment auto-resumes after each rate limit hit.
  MAX_RETRIES      = 20     # enough retries for multi-day runs
  RATE_LIMIT_WAIT  = 19800  # 5.5 hours per retry
  INTER_CALL_PAUSE = 2      # brief courtesy pause between successful calls

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
        reset_at = Time.now + RATE_LIMIT_WAIT
        $stderr.puts "[LLM] Token rate limit hit. Waiting #{RATE_LIMIT_WAIT / 3600.0}h for reset (resumes ~#{reset_at.strftime('%H:%M')})"
        sleep RATE_LIMIT_WAIT
        retry
      end
      raise
    end
  end
end
