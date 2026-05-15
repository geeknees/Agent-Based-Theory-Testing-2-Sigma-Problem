# ABOUTME: Thin wrapper around `claude --print` for synchronous LLM calls
# ABOUTME: Handles token-rate-limit errors by waiting for the rate limit window to reset

require 'open3'

module LLM
  MAX_RETRIES      = 5    # up to 5 retries
  RATE_LIMIT_WAIT  = 65   # wait 65s per retry (>1 min window reset)
  INTER_CALL_PAUSE = 2    # brief courtesy pause between successful calls

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
        wait = RATE_LIMIT_WAIT * attempts  # 65s, 130s, 195s, 260s
        $stderr.puts "[LLM] Token rate limit — waiting #{wait}s for reset (attempt #{attempts}/#{MAX_RETRIES - 1})"
        sleep wait
        retry
      end
      raise
    end
  end
end
