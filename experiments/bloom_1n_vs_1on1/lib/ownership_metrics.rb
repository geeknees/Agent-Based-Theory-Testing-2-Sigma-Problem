# ABOUTME: Pure functions for computing ownership summaries from DB ownership_metrics rows
# ABOUTME: Used by report.rb v9b sections; no LLM calls

module OwnershipMetrics
  # Summarizes ownership rows (from DB) grouped by condition
  # Returns { condition => { avg_ownership_score:, avg_contribution_count:,
  #                          pct_attempted_answer:, pct_received_feedback:,
  #                          avg_memory_delta: } }
  def self.summary_by_condition(rows)
    return {} if rows.nil? || rows.empty?
    rows.group_by { |r| r['condition'] }.transform_values do |crows|
      n = crows.size.to_f
      {
        avg_ownership_score:    crows.sum { |r| r['ownership_score'].to_f } / n,
        avg_contribution_count: crows.sum { |r| r['contribution_count'].to_f } / n,
        pct_attempted_answer:   crows.count { |r| r['attempted_answer'].to_i == 1 } / n,
        pct_received_feedback:  crows.count { |r| r['received_feedback'].to_i == 1 } / n,
        avg_memory_delta:       crows.sum { |r| r['memory_delta_after_discussion'].to_f } / n
      }
    end
  end
end
