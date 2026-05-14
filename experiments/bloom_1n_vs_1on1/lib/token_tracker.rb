# ABOUTME: Accumulates estimated token usage per phase across an experiment run
# ABOUTME: Estimates input/output tokens from character counts (1 token ≈ 4 chars)

class TokenTracker
  CHARS_PER_TOKEN = 4.0

  def initialize
    @phase_totals = Hash.new { |h, k| h[k] = { input: 0, output: 0 } }
  end

  def track(phase, prompt, response)
    input  = (prompt.to_s.length  / CHARS_PER_TOKEN).ceil
    output = (response.to_s.length / CHARS_PER_TOKEN).ceil
    @phase_totals[phase.to_s][:input]  += input
    @phase_totals[phase.to_s][:output] += output
    input + output
  end

  def summary
    @phase_totals.transform_values do |counts|
      {
        'input_tokens'  => counts[:input],
        'output_tokens' => counts[:output],
        'total_tokens'  => counts[:input] + counts[:output]
      }
    end
  end

  def total_for_phase(phase)
    t = @phase_totals[phase.to_s]
    t[:input] + t[:output]
  end

  def grand_total
    @phase_totals.values.sum { |v| v[:input] + v[:output] }
  end
end
