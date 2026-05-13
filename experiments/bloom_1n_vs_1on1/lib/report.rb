# ABOUTME: Generates CSV scores file and Markdown experiment report from database results
# ABOUTME: Both outputs are written to the run output directory; called at end of orchestrator

require 'csv'
require 'json'
require 'date'
require 'fileutils'
require_relative 'db'

module Report
  SCORE_DIMENSIONS = %w[correctness reasoning_quality rule_application error_checking autonomy].freeze

  def self.generate(db, run_id:, output_dir:, run_config:)
    FileUtils.mkdir_p(output_dir)

    rows = DB.all_attempts_with_scores(db, run_id)
    write_csv(rows, output_dir)
    markdown = build_markdown(rows, run_id: run_id, output_dir: output_dir, run_config: run_config)
    File.write(File.join(output_dir, 'report.md'), markdown)

    $stderr.puts "[report] Wrote scores.csv and report.md to #{output_dir}"
  end

  def self.write_csv(rows, output_dir)
    CSV.open(File.join(output_dir, 'scores.csv'), 'w') do |csv|
      csv << %w[learner_id condition task_id task_type total correctness reasoning_quality rule_application error_checking autonomy comments]
      rows.each do |row|
        score = row['score_json'] ? JSON.parse(row['score_json']) : {}
        csv << [
          row['learner_id'], row['condition'], row['task_id'], row['task_type'],
          score['total'] || 0,
          *SCORE_DIMENSIONS.map { |d| score[d] || 0 },
          score['comments'] || ''
        ]
      end
    end
  end

  def self.build_markdown(rows, run_id:, output_dir:, run_config:)
    by_condition = rows.group_by { |r| r['condition'] }
    by_task_type = rows.group_by { |r| r['task_type'] }

    classroom_avg = avg_total(by_condition['classroom'] || [])
    tutoring_avg  = avg_total(by_condition['1on1'] || [])

    lines = []
    lines << "# Experiment Report"
    lines << ""
    lines << "## Run Metadata"
    lines << ""
    lines << "| Field | Value |"
    lines << "|-------|-------|"
    lines << "| run_id | #{run_id} |"
    lines << "| date | #{Date.today} |"
    lines << "| models | #{run_config.dig('models', 'teacher')} |"
    lines << "| n_classroom | #{run_config.dig('experiment', 'n_classroom')} |"
    lines << "| n_tutoring | #{run_config.dig('experiment', 'n_tutoring')} |"
    lines << "| domain | #{run_config.dig('experiment', 'domain')} |"
    lines << ""
    lines << "## Average Scores by Condition"
    lines << ""
    lines << "| Condition | Avg Total (out of 20) |"
    lines << "|-----------|----------------------|"
    lines << "| classroom (1:N) | #{format('%.2f', classroom_avg)} |"
    lines << "| tutoring (1on1) | #{format('%.2f', tutoring_avg)} |"
    lines << ""
    lines << "## Average Scores by Task Type"
    lines << ""
    lines << "| Task Type | Condition | Avg Total |"
    lines << "|-----------|-----------|-----------|"
    %w[recall near_transfer far_transfer].each do |task_type|
      task_rows = by_task_type[task_type] || []
      %w[classroom 1on1].each do |cond|
        cond_rows = task_rows.select { |r| r['condition'] == cond }
        lines << "| #{task_type} | #{cond} | #{format('%.2f', avg_total(cond_rows))} |"
      end
    end
    lines << ""
    lines << "## Dimension Breakdown"
    lines << ""
    lines << "| Dimension | Classroom Avg | Tutoring Avg |"
    lines << "|-----------|---------------|--------------|"
    SCORE_DIMENSIONS.each do |dim|
      c_avg = avg_dimension(by_condition['classroom'] || [], dim)
      t_avg = avg_dimension(by_condition['1on1'] || [], dim)
      lines << "| #{dim} | #{format('%.2f', c_avg)} | #{format('%.2f', t_avg)} |"
    end
    lines << ""
    lines << "## Sample Evaluator Comments"
    lines << ""
    rows.first(6).each do |row|
      score = row['score_json'] ? JSON.parse(row['score_json']) : {}
      lines << "- **#{row['learner_id']}** (#{row['condition']}, #{row['task_type']}): #{score['comments']}"
    end
    lines << ""
    lines << "## Limitations"
    lines << ""
    lines << "- LLM agents are not human learners. Learning is operationalized as condition-specific memory formation from session transcripts, not model weight updates."
    lines << "- Small sample size (#{rows.map { |r| r['learner_id'] }.uniq.size} learners). Results are exploratory."
    lines << "- The evaluator is the same model as the learner, which may introduce systematic bias."
    lines << "- All scores are produced by a single blind-evaluator LLM call per attempt. No inter-rater reliability check."
    lines << "- This experiment tests whether the experimental protocol is viable, not whether Bloom's theory applies to LLMs."
    lines << ""
    lines << "## How to Inspect Results"
    lines << ""
    lines << "```bash"
    lines << "# Open SQLite DB directly"
    lines << "sqlite3 #{run_config.dig('paths', 'db')}"
    lines << ""
    lines << "# View scores CSV"
    lines << "cat #{output_dir}/scores.csv"
    lines << "```"
    lines.join("\n")
  end

  def self.avg_total(rows)
    return 0.0 if rows.empty?
    totals = rows.map { |r| r['score_json'] ? JSON.parse(r['score_json'])['total'].to_f : 0.0 }
    totals.sum / totals.size
  end

  def self.avg_dimension(rows, dimension)
    return 0.0 if rows.empty?
    vals = rows.map { |r| r['score_json'] ? JSON.parse(r['score_json'])[dimension].to_f : 0.0 }
    vals.sum / vals.size
  end
end
