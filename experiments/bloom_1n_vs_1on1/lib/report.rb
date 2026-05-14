# ABOUTME: Generates CSV scores and Markdown experiment report from database results
# ABOUTME: Includes ceiling effect detection, token usage metrics, and difficulty breakdown

require 'csv'
require 'json'
require 'date'
require 'fileutils'
require_relative 'db'

module Report
  SCORE_DIMENSIONS  = %w[correctness reasoning_quality rule_application error_checking autonomy].freeze
  CEILING_THRESHOLD = 0.9
  DIFFICULTY_LEVELS = %w[L1 L2 L3 L4 L5 L6].freeze

  def self.generate(db, run_id:, output_dir:, run_config:, token_summary: {})
    FileUtils.mkdir_p(output_dir)
    rows = DB.all_attempts_with_scores(db, run_id)
    write_csv(rows, output_dir)
    markdown = build_markdown(rows, run_id: run_id, output_dir: output_dir,
                              run_config: run_config, token_summary: token_summary)
    File.write(File.join(output_dir, 'report.md'), markdown)
    $stderr.puts "[report] Wrote scores.csv and report.md to #{output_dir}"
  end

  def self.write_csv(rows, output_dir)
    CSV.open(File.join(output_dir, 'scores.csv'), 'w') do |csv|
      csv << %w[learner_id condition task_id task_type difficulty total correctness
                rule_application error_checking answer_correct auto_scored comments]
      rows.each do |row|
        score = row['score_json'] ? JSON.parse(row['score_json']) : {}
        csv << [
          row['learner_id'], row['condition'], row['task_id'], row['task_type'],
          extract_difficulty(row['task_id']),
          score['total'] || 0, score['correctness'] || 0, score['rule_application'] || 0,
          score['error_checking'] || 0, score['answer_correct'],
          score['auto_scored'], score['comments'] || ''
        ]
      end
    end
  end

  def self.build_markdown(rows, run_id:, output_dir:, run_config:, token_summary:)
    by_condition  = rows.group_by { |r| r['condition'] }
    ceiling_data  = detect_ceiling(rows, run_config)
    token_data    = build_token_data(token_summary, by_condition)

    lines = []
    lines << "# Experiment Report (v2)"
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
    lines << "| tutoring_turns | #{run_config.dig('experiment', 'tutoring_turns')} |"
    lines << ""

    # Ceiling effect summary
    too_easy = ceiling_data.select { |r| r[:ceiling_effect] }.map { |r| r[:task_type] }
    lines << "## Ceiling Effect Summary"
    lines << ""
    lines << "> Tasks where both conditions score >#{(CEILING_THRESHOLD * 100).round}% correct answers are flagged as too easy."
    lines << ""
    lines << "| Task Type | Difficulty | Classroom Correct% | Tutoring Correct% | Ceiling? |"
    lines << "|-----------|-----------|-------------------|-------------------|---------|"
    ceiling_data.each do |row|
      flag = row[:ceiling_effect] ? "YES ⚠️" : "no"
      lines << "| #{row[:task_type]} | #{row[:difficulty]} | #{(row[:classroom_pct] * 100).round}% | #{(row[:tutoring_pct] * 100).round}% | #{flag} |"
    end
    lines << ""
    lines << (too_easy.any? ? "**Task types too easy:** #{too_easy.join(', ')}" : "**No ceiling effects detected.**")
    lines << ""

    # Score by condition
    lines << "## Score by Condition (answer_correct rate)"
    lines << ""
    lines << "| Condition | Learners | Attempts | Correct% |"
    lines << "|-----------|---------|---------|---------|"
    %w[classroom 1on1].each do |cond|
      cond_rows = by_condition[cond] || []
      pct = avg_correctness(cond_rows)
      n   = cond_rows.map { |r| r['learner_id'] }.uniq.size
      lines << "| #{cond} | #{n} | #{cond_rows.size} | #{(pct * 100).round}% |"
    end
    lines << ""

    # Score by task type
    lines << "## Score by Task Type × Condition"
    lines << ""
    lines << "| Task Type | Difficulty | Classroom Correct% | Tutoring Correct% |"
    lines << "|-----------|-----------|-------------------|-------------------|"
    rows.group_by { |r| r['task_type'] }.sort.each do |task_type, type_rows|
      diff  = extract_difficulty(type_rows.first['task_id'])
      c_pct = avg_correctness(type_rows.select { |r| r['condition'] == 'classroom' })
      t_pct = avg_correctness(type_rows.select { |r| r['condition'] == '1on1' })
      lines << "| #{task_type} | #{diff} | #{(c_pct * 100).round}% | #{(t_pct * 100).round}% |"
    end
    lines << ""

    # Score by difficulty level
    lines << "## Score by Difficulty Level"
    lines << ""
    lines << "| Level | Task Types | Classroom Correct% | Tutoring Correct% |"
    lines << "|-------|-----------|-------------------|-------------------|"
    DIFFICULTY_LEVELS.each do |level|
      level_rows = rows.select { |r| extract_difficulty(r['task_id']) == level }
      next if level_rows.empty?
      types = level_rows.map { |r| r['task_type'] }.uniq.join(', ')
      c_pct = avg_correctness(level_rows.select { |r| r['condition'] == 'classroom' })
      t_pct = avg_correctness(level_rows.select { |r| r['condition'] == '1on1' })
      lines << "| #{level} | #{types} | #{(c_pct * 100).round}% | #{(t_pct * 100).round}% |"
    end
    lines << ""

    # Token usage
    lines << "## Token Usage by Phase (estimated)"
    lines << ""
    lines << "| Phase | Input | Output | Total |"
    lines << "|-------|-------|--------|-------|"
    token_summary.each do |phase, counts|
      lines << "| #{phase} | #{counts['input_tokens']} | #{counts['output_tokens']} | #{counts['total_tokens']} |"
    end
    grand = token_summary.values.sum { |v| v['total_tokens'].to_i }
    lines << "| **TOTAL** | | | **#{grand}** |"
    lines << ""

    if token_data[:tutoring_extra] > 0
      lines << "| Metric | Value |"
      lines << "|--------|-------|"
      lines << "| Classroom correct% | #{(token_data[:classroom_pct] * 100).round}% |"
      lines << "| Tutoring correct% | #{(token_data[:tutoring_pct] * 100).round}% |"
      lines << "| Tutoring gain | #{format('%+.1f', token_data[:tutoring_gain] * 100)}pp |"
      lines << "| Extra education tokens (tutoring vs classroom) | #{token_data[:tutoring_extra]} |"
      lines << "| Tutoring gain per 1k extra tokens | #{format('%.2f', token_data[:gain_per_1k])}pp |"
      lines << ""
    end

    # Recommendations
    lines << "## Recommended Next Steps"
    lines << ""
    if too_easy.size == ceiling_data.size && !ceiling_data.empty?
      lines << "- All task types showed ceiling effects. Replace or skip L1/L2, increase L4–L6 share."
    elsif too_easy.any?
      lines << "- Task types flagged as too easy: **#{too_easy.join(', ')}** — remove or replace with harder variants."
    else
      lines << "- No ceiling effects at current difficulty. Increase n to improve statistical power."
    end
    lines << ""
    lines << "## Limitations"
    lines << ""
    lines << "- Token counts are estimated (chars/4). Actual API token counts may differ by ±20%."
    lines << "- Auto-scoring uses keyword matching for mistake detection — may under-count partial credit."
    lines << "- LLM agents are not human learners. Learning is operationalized as condition-specific memory from transcripts."
    lines << "- Small n. Results are exploratory."
    lines << ""
    lines.join("\n") + "\n"
  end

  # ---- private helpers ----

  def self.detect_ceiling(rows, run_config)
    threshold = (run_config.dig('experiment', 'ceiling_threshold') || CEILING_THRESHOLD).to_f
    rows.group_by { |r| r['task_type'] }.map do |task_type, type_rows|
      c_pct      = avg_correctness(type_rows.select { |r| r['condition'] == 'classroom' })
      t_pct      = avg_correctness(type_rows.select { |r| r['condition'] == '1on1' })
      difficulty = extract_difficulty(type_rows.first['task_id'])
      {
        task_type: task_type, difficulty: difficulty,
        classroom_pct: c_pct, tutoring_pct: t_pct,
        ceiling_effect: c_pct >= threshold && t_pct >= threshold
      }
    end.sort_by { |r| DIFFICULTY_LEVELS.index(r[:difficulty]) || 99 }
  end

  def self.build_token_data(token_summary, by_condition)
    edu_classroom = (token_summary['education_classroom'] || {})['total_tokens'].to_i
    edu_tutoring  = (token_summary['education_tutoring']  || {})['total_tokens'].to_i
    c_pct  = avg_correctness(by_condition['classroom'] || [])
    t_pct  = avg_correctness(by_condition['1on1'] || [])
    gain   = t_pct - c_pct
    extra  = [edu_tutoring - edu_classroom, 0].max
    gain_per_1k = extra > 0 ? (gain * 100) / (extra / 1000.0) : 0.0
    { classroom_pct: c_pct, tutoring_pct: t_pct, tutoring_gain: gain,
      tutoring_extra: extra, gain_per_1k: gain_per_1k }
  end

  def self.extract_difficulty(task_id)
    m = task_id.to_s.match(/^(l\d)/i)
    m ? m[1].upcase : 'unknown'
  end

  def self.avg_correctness(rows)
    return 0.0 if rows.empty?
    correct = rows.count do |r|
      score = r['score_json'] ? JSON.parse(r['score_json']) : {}
      score['answer_correct'] == true
    end
    correct.to_f / rows.size
  end

  def self.avg_total(rows)
    return 0.0 if rows.empty?
    rows.map { |r| r['score_json'] ? JSON.parse(r['score_json'])['total'].to_f : 0.0 }.sum / rows.size
  end
end
