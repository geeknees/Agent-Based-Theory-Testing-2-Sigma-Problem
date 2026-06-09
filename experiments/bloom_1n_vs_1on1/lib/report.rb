# ABOUTME: Generates CSV scores and Markdown experiment report from database results
# ABOUTME: Includes ceiling effect detection, token usage metrics, and difficulty breakdown

require 'csv'
require 'json'
require 'date'
require 'digest'
require 'fileutils'
require_relative 'db'
require_relative 'ownership_metrics'
require_relative 'memory_diagnostics'

module Report
  SCORE_DIMENSIONS  = %w[correctness reasoning_quality rule_application error_checking autonomy].freeze
  CEILING_THRESHOLD = 0.9
  DIFFICULTY_LEVELS = %w[L1 L2 L3 L4 L5 L6].freeze

  def self.generate(db, run_id:, output_dir:, run_config:, token_summary: {}, experiment_meta: {})
    FileUtils.mkdir_p(output_dir)
    rows                  = DB.all_attempts_with_scores(db, run_id)
    memories_by_condition = DB.all_memories_by_condition(db, run_id)
    mastery_rows          = %w[v8 v9b v9c v9c2].include?(experiment_meta[:experiment]) ?
                              DB.all_mastery_checks_by_condition(db, run_id) : []
    sessions_by_condition = experiment_meta[:experiment] == 'v9c2' ?
                              DB.all_learning_sessions_by_condition(db, run_id) : {}
    write_csv(rows, output_dir)
    markdown = build_markdown(rows, run_id: run_id, output_dir: output_dir,
                              run_config: run_config, token_summary: token_summary,
                              memories_by_condition: memories_by_condition,
                              experiment_meta: experiment_meta,
                              mastery_rows: mastery_rows,
                              sessions_by_condition: sessions_by_condition)
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

  def self.build_markdown(rows, run_id:, output_dir:, run_config:, token_summary:, memories_by_condition: {}, experiment_meta: {}, mastery_rows: [], sessions_by_condition: {})
    scored_rows   = experiment_meta[:experiment] == 'v9c2' ? core_rows(rows) : rows
    by_condition  = scored_rows.group_by { |r| r['condition'] }
    ceiling_data  = detect_ceiling(scored_rows, run_config)
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
    lines << "> Classification: too_easy (all≥90%), education_sensitive (edu>baseline+10pp), condition_sensitive (tutoring≠classroom by >10pp), too_hard (all<30%), unclear"
    lines << ""
    lines << "| Task Type | Difficulty | No-Ed Correct% | Classroom Correct% | Tutoring Correct% | Classification |"
    lines << "|-----------|-----------|----------------|-------------------|-------------------|----------------|"
    ceiling_data.each do |row|
      lines << "| #{row[:task_type]} | #{row[:difficulty]} | #{(row[:no_ed_pct] * 100).round}% | #{(row[:classroom_pct] * 100).round}% | #{(row[:tutoring_pct] * 100).round}% | #{row[:classification]} |"
    end
    lines << ""
    lines << (too_easy.any? ? "**Task types too easy:** #{too_easy.join(', ')}" : "**No ceiling effects detected.**")
    lines << ""

    # Score by condition
    lines << "## Score by Condition (answer_correct rate)"
    lines << ""
    lines << "| Condition | Learners | Attempts | Correct% |"
    lines << "|-----------|---------|---------|---------|"
    by_condition.keys.sort.each do |cond|
      cond_rows = by_condition[cond]
      pct = avg_correctness(cond_rows)
      n   = cond_rows.map { |r| r['learner_id'] }.uniq.size
      lines << "| #{cond} | #{n} | #{cond_rows.size} | #{(pct * 100).round}% |"
    end
    lines << ""

    # Score by task type
    all_conds       = scored_rows.map { |r| r['condition'] }.uniq
    classroom_conds = all_conds.select { |c| c.include?('classroom') }
    tutoring_conds  = all_conds.select { |c| c.include?('tutoring') || c == '1on1' }

    if %w[v9b v9c].include?(experiment_meta[:experiment])
      lines << score_by_task_type_v9b(scored_rows, all_conds.sort)
      lines << score_by_difficulty_v9b(scored_rows, all_conds.sort)
    else
      lines << "## Score by Task Type × Condition"
      lines << ""
      lines << "| Task Type | Difficulty | No-Ed Correct% | Classroom Correct% | Tutoring Correct% |"
      lines << "|-----------|-----------|----------------|-------------------|-------------------|"
      scored_rows.group_by { |r| r['task_type'] }.sort.each do |task_type, type_rows|
        diff   = extract_difficulty(type_rows.first['task_id'])
        no_pct = avg_correctness(type_rows.select { |r| r['condition'] == 'no_education' })
        c_pct  = avg_correctness(type_rows.select { |r| classroom_conds.include?(r['condition']) })
        t_pct  = avg_correctness(type_rows.select { |r| tutoring_conds.include?(r['condition']) })
        lines << "| #{task_type} | #{diff} | #{(no_pct * 100).round}% | #{(c_pct * 100).round}% | #{(t_pct * 100).round}% |"
      end
      lines << ""

      # Score by difficulty level
      lines << "## Score by Difficulty Level"
      lines << ""
      lines << "| Level | Task Types | No-Ed Correct% | Classroom Correct% | Tutoring Correct% |"
      lines << "|-------|-----------|----------------|-------------------|-------------------|"
      DIFFICULTY_LEVELS.each do |level|
        level_rows = scored_rows.select { |r| extract_difficulty(r['task_id']) == level }
        next if level_rows.empty?
        types  = level_rows.map { |r| r['task_type'] }.uniq.join(', ')
        no_pct = avg_correctness(level_rows.select { |r| r['condition'] == 'no_education' })
        c_pct  = avg_correctness(level_rows.select { |r| classroom_conds.include?(r['condition']) })
        t_pct  = avg_correctness(level_rows.select { |r| tutoring_conds.include?(r['condition']) })
        lines << "| #{level} | #{types} | #{(no_pct * 100).round}% | #{(c_pct * 100).round}% | #{(t_pct * 100).round}% |"
      end
      lines << ""
    end

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

    # Profile-based breakdown
    lines << "## Score by Learner Profile"
    lines << ""
    %w[ability misconception interest].each do |dim|
      by_dim = score_by_profile_dimension(scored_rows, dim)
      next if by_dim.empty?
      lines << "### By #{dim.capitalize}"
      lines << ""
      lines << "| #{dim.capitalize} | Correct% |"
      lines << "|#{'-' * (dim.length + 2)}|---------|"
      by_dim.sort.each do |val, pct|
        lines << "| #{val} | #{(pct * 100).round}% |"
      end
      lines << ""
    end

    # Variance by condition
    variance = score_variance_by_condition(scored_rows)
    lines << "## Score Variance by Condition (std dev of per-learner correct%)"
    lines << ""
    lines << "| Condition | Std Dev |"
    lines << "|-----------|--------|"
    variance.sort.each do |cond, sd|
      lines << "| #{cond} | #{sd} |"
    end
    lines << ""

    if experiment_meta[:experiment] == 'v9c2'
      disc_var = discussion_level_variance_by_condition(scored_rows, sessions_by_condition)
      lines << "## Score Variance by Condition (discussion-level unit of analysis)"
      lines << ""
      lines << "> Each SD is computed across N independent discussion instances — the correct"
      lines << "> unit of analysis for comparing discussion designs (corrects F4 pseudoreplication)."
      lines << "> Learners are nested observations within each discussion instance."
      lines << ""
      lines << "| Condition | N (independent discussions) | SD (discussion-level) |"
      lines << "|-----------|------------------------------|----------------------|"
      disc_var.sort.each do |cond, stats|
        lines << "| #{cond} | #{stats[:n]} | #{stats[:sd]} |"
      end
      lines << ""
    end

    # Token per correct answer
    tpca = token_per_correct_answer(scored_rows, token_summary)
    lines << "**Token cost per correct answer:** #{tpca} tokens"
    lines << ""

    # v8: mastery check scores and memory coverage
    if experiment_meta[:experiment] == 'v8'
      lines << mastery_check_section(mastery_rows)
      lines << memory_coverage_section(memories_by_condition)
    end

    # v9b: ownership metrics and memory delta
    if experiment_meta[:experiment] == 'v9b'
      lines << mastery_check_section(mastery_rows)
      lines << memory_coverage_section(memories_by_condition)
      lines << ownership_section(experiment_meta[:ownership_rows] || [])
      lines << memory_delta_section(experiment_meta[:ownership_rows] || [])
    end

    # v9c: readiness + ownership + fine-grained memory delta + interpretation flags
    if experiment_meta[:experiment] == 'v9c'
      lines << readiness_summary_section(mastery_rows, experiment_meta[:readiness_pass_rate] || 0.0)
      lines << mastery_check_section(mastery_rows)
      lines << memory_coverage_section(memories_by_condition)
      lines << ownership_section(experiment_meta[:ownership_rows] || [])
      lines << memory_delta_section(experiment_meta[:ownership_rows] || [])
      lines << fine_grained_memory_delta_section(
        experiment_meta[:pre_discussion_snapshots] || [],
        memories_by_condition
      )
      lines << interpretation_flags_section(
        rows, mastery_rows,
        experiment_meta[:ownership_rows] || [],
        experiment_meta[:readiness_pass_rate] || 0.0
      )
    end

    if experiment_meta[:experiment] == 'v9c2'
      lines << readiness_summary_section(mastery_rows, experiment_meta[:readiness_pass_rate] || 0.0)
      lines << mastery_check_section(mastery_rows)
      lines << memory_coverage_section(memories_by_condition)
      lines << ownership_section(experiment_meta[:ownership_rows] || [])
      lines << memory_delta_section(experiment_meta[:ownership_rows] || [])
      lines << fine_grained_memory_delta_section(
        experiment_meta[:pre_discussion_snapshots] || [],
        memories_by_condition
      )
      lines << interpretation_flags_section(
        rows, mastery_rows,
        experiment_meta[:ownership_rows] || [],
        experiment_meta[:readiness_pass_rate] || 0.0
      )
      lines << l6_rows_section(rows)
    end

    # Heterogeneity interpretation
    interpretations = heterogeneity_interpretation(scored_rows, token_summary)
    lines << "## Heterogeneity Interpretation"
    lines << ""
    if interpretations.empty?
      lines << "No strong heterogeneity signal detected."
    else
      interpretations.each { |i| lines << "- **#{i}** ✓" }
    end
    lines << ""

    # Score by learner type
    type_scores = score_by_learner_type(scored_rows)
    unless type_scores.empty?
      lines << "## Score by Learner Type"
      lines << ""
      lines << "| Type | Correct% |"
      lines << "|------|---------|"
      type_scores.sort.each { |type, pct| lines << "| #{type} | #{(pct * 100).round}% |" }
      lines << ""
    end

    # Misconception correction metrics
    unless memories_by_condition.empty?
      corr_rates  = correction_rate_by_condition(memories_by_condition)
      remain_avgs = remaining_misconceptions_by_condition(memories_by_condition)
      lines << "## Misconception Correction by Condition"
      lines << ""
      lines << "| Condition | Correction Rate | Avg Remaining Misconceptions |"
      lines << "|-----------|----------------|------------------------------|"
      corr_rates.sort.each do |cond, rate|
        remain = remain_avgs[cond] || 0.0
        lines << "| #{cond} | #{(rate * 100).round}% | #{remain.round(2)} |"
      end
      lines << ""
    end

    # Confidence calibration summary
    hcw_rate  = high_confidence_wrong_rate(scored_rows)
    abst_rate = abstention_rate(scored_rows)
    lines << "## Confidence Calibration"
    lines << ""
    lines << "| Metric | Rate |"
    lines << "|--------|------|"
    lines << "| High-confidence wrong | #{(hcw_rate * 100).round}% |"
    lines << "| Abstention | #{(abst_rate * 100).round}% |"
    lines << ""

    # Exp A: passive_listener rescue effect
    if experiment_meta[:experiment] == 'A'
      rescue_table = passive_listener_rescue_effect(scored_rows)
      unless rescue_table.empty?
        lines << "## Passive Listener Rescue Effect"
        lines << ""
        lines << rescue_table
        lines << ""
      end
    end

    # Exp B: order_confused scaffold effect + procedure order errors
    if experiment_meta[:experiment] == 'B'
      scaffold_table = order_confused_scaffold_effect(scored_rows)
      unless scaffold_table.empty?
        lines << "## Order Confused Scaffold Effect"
        lines << ""
        lines << scaffold_table
        lines << ""
      end

      proc_error_rate = procedure_order_error_rate(scored_rows)
      lines << "## Procedure Order Errors"
      lines << ""
      lines << "| Metric | Rate |"
      lines << "|--------|------|"
      lines << "| Responses with modifier-before-activation error | #{(proc_error_rate * 100).round}% |"
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
    threshold       = (run_config.dig('experiment', 'ceiling_threshold') || CEILING_THRESHOLD).to_f
    all_conds       = rows.map { |r| r['condition'] }.uniq
    classroom_conds = all_conds.select { |c| c.include?('classroom') }
    tutoring_conds  = all_conds.select { |c| c.include?('tutoring') || c == '1on1' }
    rows.group_by { |r| r['task_type'] }.map do |task_type, type_rows|
      no_ed_pct  = avg_correctness(type_rows.select { |r| r['condition'] == 'no_education' })
      c_pct      = avg_correctness(type_rows.select { |r| classroom_conds.include?(r['condition']) })
      t_pct      = avg_correctness(type_rows.select { |r| tutoring_conds.include?(r['condition']) })
      difficulty = extract_difficulty(type_rows.first['task_id'])
      ceiling    = no_ed_pct >= threshold && c_pct >= threshold && t_pct >= threshold
      {
        task_type:      task_type,
        difficulty:     difficulty,
        no_ed_pct:      no_ed_pct,
        classroom_pct:  c_pct,
        tutoring_pct:   t_pct,
        ceiling_effect: ceiling,
        classification: classify_task_type(no_ed_pct, c_pct, t_pct, threshold: threshold)
      }
    end.sort_by { |r| DIFFICULTY_LEVELS.index(r[:difficulty]) || 99 }
  end

  def self.classify_task_type(no_ed_pct, classroom_pct, tutoring_pct, threshold:)
    all_high       = no_ed_pct >= threshold && classroom_pct >= threshold && tutoring_pct >= threshold
    all_low        = no_ed_pct < 0.3 && classroom_pct < 0.3 && tutoring_pct < 0.3
    edu_helps      = classroom_pct > no_ed_pct + 0.1 || tutoring_pct > no_ed_pct + 0.1
    both_edu_help  = [classroom_pct, tutoring_pct].min > no_ed_pct + 0.2
    cond_diff      = (tutoring_pct - classroom_pct).abs > 0.1

    return 'too_easy'            if all_high
    return 'too_hard'            if all_low
    return 'condition_sensitive' if both_edu_help && cond_diff
    return 'education_sensitive' if edu_helps
    'unclear'
  end

  def self.build_token_data(token_summary, by_condition)
    edu_classroom = token_summary.select { |k, _| k.start_with?('education_') && k.include?('classroom') }
                                 .sum { |_, v| v['total_tokens'].to_i }
    edu_tutoring  = token_summary.select { |k, _| k.start_with?('education_') && (k.include?('tutoring') || k == 'education_tutoring') }
                                 .sum { |_, v| v['total_tokens'].to_i }
    classroom_rows = by_condition.select { |k, _| k.include?('classroom') }.values.flatten
    tutoring_rows  = by_condition.select { |k, _| k.include?('tutoring') || k == '1on1' }.values.flatten
    c_pct   = avg_correctness(classroom_rows)
    t_pct   = avg_correctness(tutoring_rows)
    no_pct  = avg_correctness(by_condition['no_education'] || [])
    gain    = t_pct - c_pct
    extra   = [edu_tutoring - edu_classroom, 0].max
    gain_per_1k = extra > 0 ? (gain * 100) / (extra / 1000.0) : 0.0
    { classroom_pct: c_pct, tutoring_pct: t_pct, no_ed_pct: no_pct,
      tutoring_gain: gain, tutoring_extra: extra, gain_per_1k: gain_per_1k }
  end

  def self.mastery_check_section(mastery_rows)
    return '' if mastery_rows.nil? || mastery_rows.empty?
    lines = []
    lines << "## Mastery Check Score by Check Type"
    lines << ""
    lines << "| Check Type | Total | Correct | Pass Rate |"
    lines << "|------------|-------|---------|-----------|"
    mastery_rows.group_by { |r| r['check_type'] }.sort.each do |check_type, rows|
      total   = rows.size
      correct = rows.count { |r| r['answer_correct'].to_i == 1 }
      pct     = total > 0 ? (correct.to_f / total * 100).round : 0
      lines << "| #{check_type} | #{total} | #{correct} | #{pct}% |"
    end
    lines << ""
    lines.join("\n")
  end

  def self.memory_coverage(memory)
    rules      = Array(memory['rules'])
    edge_cases = Array(memory['edge_cases'])
    strategy   = Array(memory['strategy'])
    {
      rule_count:      rules.size,
      has_edge_cases:  edge_cases.any?,
      has_procedure:   strategy.any?,
      rule_words:      rules.join(' ').split.size,
      edge_case_count: edge_cases.size,
      strategy_count:  strategy.size
    }
  end

  def self.memory_coverage_section(memories_by_condition)
    return '' if memories_by_condition.nil? || memories_by_condition.empty?
    lines = []
    lines << "## Memory Coverage by Condition"
    lines << ""
    lines << "| Condition | Avg Rules | Edge Cases (%) | Procedure (%) |"
    lines << "|-----------|-----------|----------------|---------------|"
    memories_by_condition.sort_by { |k, _| k }.each do |cond, mem_list|
      next if mem_list.empty?
      coverages = mem_list.map { |m| memory_coverage(m['memory']) }
      avg_rules = (coverages.sum { |c| c[:rule_count] }.to_f / coverages.size).round(1)
      edge_pct  = (coverages.count { |c| c[:has_edge_cases] }.to_f / coverages.size * 100).round
      proc_pct  = (coverages.count { |c| c[:has_procedure] }.to_f / coverages.size * 100).round
      lines << "| #{cond} | #{avg_rules} | #{edge_pct}% | #{proc_pct}% |"
    end
    lines << ""
    lines.join("\n")
  end

  def self.ownership_section(ownership_rows)
    return '' if ownership_rows.nil? || ownership_rows.empty?
    summary = OwnershipMetrics.summary_by_condition(ownership_rows)
    lines = []
    lines << "## Ownership Metrics by Condition"
    lines << ""
    lines << "| Condition | Avg Ownership Score | Avg Contributions | % Attempted | % Received Feedback |"
    lines << "|-----------|--------------------|--------------------|-------------|---------------------|"
    summary.sort_by { |k, _| k }.each do |cond, s|
      lines << "| #{cond} | #{s[:avg_ownership_score].round(2)} | #{s[:avg_contribution_count].round(1)} | #{(s[:pct_attempted_answer] * 100).round}% | #{(s[:pct_received_feedback] * 100).round}% |"
    end
    lines << ""
    lines.join("\n")
  end

  def self.memory_delta_section(ownership_rows)
    return '' if ownership_rows.nil? || ownership_rows.empty?
    summary = OwnershipMetrics.summary_by_condition(ownership_rows)
    lines = []
    lines << "## Memory Delta by Condition (knowledge items acquired during discussion)"
    lines << ""
    lines << "| Condition | Avg Memory Delta (items) |"
    lines << "|-----------|--------------------------|"
    summary.sort_by { |k, _| k }.each do |cond, s|
      lines << "| #{cond} | #{s[:avg_memory_delta].round(2)} |"
    end
    lines << ""
    lines.join("\n")
  end

  def self.score_by_task_type_v9b(rows, conditions)
    lines = []
    lines << "## Score by Task Type × Condition"
    lines << ""
    header = "| Task Type | Difficulty | " + conditions.map { |c| "#{c} |" }.join(' ')
    sep    = "|-----------|-----------|" + conditions.map { " ---- |" }.join
    lines << header
    lines << sep
    rows.group_by { |r| r['task_type'] }.sort.each do |task_type, type_rows|
      diff = extract_difficulty(type_rows.first['task_id'])
      cols = conditions.map { |c| "#{(avg_correctness(type_rows.select { |r| r['condition'] == c }) * 100).round}% |" }.join(' ')
      lines << "| #{task_type} | #{diff} | #{cols}"
    end
    lines << ""
    lines.join("\n")
  end

  def self.score_by_difficulty_v9b(rows, conditions)
    lines = []
    lines << "## Score by Difficulty Level × Condition"
    lines << ""
    header = "| Level | Task Types | " + conditions.map { |c| "#{c} |" }.join(' ')
    sep    = "|-------|-----------|" + conditions.map { " ---- |" }.join
    lines << header
    lines << sep
    DIFFICULTY_LEVELS.each do |level|
      level_rows = rows.select { |r| extract_difficulty(r['task_id']) == level }
      next if level_rows.empty?
      types = level_rows.map { |r| r['task_type'] }.uniq.join(', ')
      cols  = conditions.map { |c| "#{(avg_correctness(level_rows.select { |r| r['condition'] == c }) * 100).round}% |" }.join(' ')
      lines << "| #{level} | #{types} | #{cols}"
    end
    lines << ""
    lines.join("\n")
  end

  def self.extract_difficulty(task_id)
    m = task_id.to_s.match(/^(l\d)/i)
    m ? m[1].upcase : 'unknown'
  end

  def self.core_rows(rows)
    rows.reject { |r| extract_difficulty(r['task_id']) == 'L6' }
  end

  def self.l6_rows_section(rows)
    l6 = rows.select { |r| extract_difficulty(r['task_id']) == 'L6' }
    lines = []
    lines << "## L6 (short_rule_induction) — Exploratory Appendix"
    lines << ""
    lines << "> L6 is excluded from the main score. The exact-match scorer cannot reliably"
    lines << "> grade free-text rule induction (F2: scorer artifact confirmed across v8/v9b/v9c)."
    lines << "> These results are exploratory only — do not use them for condition comparisons."
    lines << ""
    if l6.empty?
      lines << "_No L6 attempts found for this run._"
      lines << ""
      return lines.join("\n")
    end
    task_ids = l6.map { |r| r['task_id'] }.uniq.sort
    lines << "**L6 task IDs in this run:** #{task_ids.join(', ')}"
    lines << ""
    by_condition = l6.group_by { |r| r['condition'] }
    lines << "| Condition | L6 Attempts | Correct (exact-match) | Note |"
    lines << "|-----------|-------------|----------------------|------|"
    by_condition.sort.each do |cond, cond_rows|
      total   = cond_rows.size
      correct = cond_rows.count { |r| r['answer_correct'] == true || r['answer_correct'] == 1 }
      lines << "| #{cond} | #{total} | #{correct} | exact-match only — likely undercount |"
    end
    lines << ""
    lines.join("\n")
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

  def self.score_by_profile_dimension(rows, dimension)
    grouped = rows.group_by do |r|
      profile = r['profile_json'] ? JSON.parse(r['profile_json']) : {}
      profile[dimension.to_s] || 'unknown'
    end
    grouped.transform_values { |rs| avg_correctness(rs) }
  end

  def self.score_variance_by_condition(rows)
    by_condition = rows.group_by { |r| r['condition'] }
    by_condition.transform_values do |cond_rows|
      by_learner = cond_rows.group_by { |r| r['learner_id'] }
      scores = by_learner.values.map { |ls| avg_correctness(ls) }
      next 0.0 if scores.size < 2
      mean     = scores.sum / scores.size
      variance = scores.sum { |s| (s - mean)**2 } / (scores.size - 1)
      Math.sqrt(variance).round(3)
    end
  end

  def self.discussion_level_variance_by_condition(rows, sessions_by_condition)
    by_condition = rows.group_by { |r| r['condition'] }
    sessions_by_condition.transform_values do |session_rows|
      cond       = session_rows.first['condition']
      cond_rows  = by_condition[cond] || []
      by_learner = cond_rows.group_by { |r| r['learner_id'] }

      groups = session_rows.group_by { |s| Digest::MD5.hexdigest(s['transcript_json']) }
      means  = groups.values.map do |group_sessions|
        learner_ids = group_sessions.map { |s| s['learner_id'] }.uniq
        scores      = learner_ids.map { |lid| avg_correctness(by_learner[lid] || []) }
        scores.empty? ? 0.0 : scores.sum / scores.size
      end

      next({ n: means.size, sd: 0.0 }) if means.size < 2
      mean     = means.sum / means.size
      variance = means.sum { |m| (m - mean)**2 } / (means.size - 1)
      { n: means.size, sd: Math.sqrt(variance).round(3) }
    end
  end

  def self.token_per_correct_answer(rows, token_summary)
    total_correct = rows.count { |r| r['score_json'] && JSON.parse(r['score_json'])['answer_correct'] == true }
    total_tokens  = token_summary.values.sum { |v| v['total_tokens'].to_i }
    return 0 if total_correct == 0
    (total_tokens.to_f / total_correct).round(0).to_i
  end

  def self.heterogeneity_interpretation(rows, token_summary)
    by_condition = rows.group_by { |r| r['condition'] }
    tutoring_pct = avg_correctness(by_condition['1on1']                    || [])
    hetero_pct   = avg_correctness(by_condition['heterogeneous_classroom'] || [])
    homo_pct     = avg_correctness(by_condition['homogeneous_classroom']   || [])

    results = []
    results << 'tutoring_advantage_under_heterogeneity' if tutoring_pct > hetero_pct
    results << 'classroom_advantage_under_homogeneity'   if homo_pct >= tutoring_pct
    results << 'heterogeneity_penalty'                   if hetero_pct < homo_pct

    low_tutoring = bottom_learner_correctness(by_condition['1on1']                    || [], 'low')
    low_hetero   = bottom_learner_correctness(by_condition['heterogeneous_classroom'] || [], 'low')
    results << 'bottom_learner_rescue' if low_tutoring > low_hetero

    results
  end

  def self.bottom_learner_correctness(cond_rows, target_ability)
    low_rows = cond_rows.select do |r|
      profile = r['profile_json'] ? JSON.parse(r['profile_json']) : {}
      profile['ability'] == target_ability
    end
    avg_correctness(low_rows)
  end

  def self.score_by_learner_type(rows)
    grouped = rows.group_by do |r|
      profile = r['profile_json'] ? JSON.parse(r['profile_json']) : {}
      profile['type_key'] || 'unknown'
    end
    grouped.transform_values { |rs| avg_correctness(rs) }
  end

  def self.correction_rate_by_condition(memories_by_condition)
    memories_by_condition.transform_values do |entries|
      next 0.0 if entries.empty?
      corrected = entries.count { |e| Array(e.dig('memory', 'corrected_misconceptions')).any? }
      corrected.to_f / entries.size
    end
  end

  def self.remaining_misconceptions_by_condition(memories_by_condition)
    memories_by_condition.transform_values do |entries|
      next 0.0 if entries.empty?
      total = entries.sum { |e| Array(e.dig('memory', 'remaining_misconceptions')).size }
      total.to_f / entries.size
    end
  end

  def self.high_confidence_wrong_rate(rows)
    return 0.0 if rows.empty?
    count = rows.count { |r| r['score_json'] && JSON.parse(r['score_json'])['high_confidence_wrong'] == true }
    count.to_f / rows.size
  end

  def self.abstention_rate(rows)
    return 0.0 if rows.empty?
    count = rows.count { |r| r['score_json'] && JSON.parse(r['score_json'])['abstained'] == true }
    count.to_f / rows.size
  end

  def self.passive_listener_rescue_effect(rows)
    pl_rows = rows.select do |r|
      profile = r['profile_json'] ? JSON.parse(r['profile_json']) : {}
      profile['type_key'] == 'passive_listener'
    end
    return '' if pl_rows.empty?

    by_cond = pl_rows.group_by { |r| r['condition'] }
    target_conds = %w[classroom_public_qa classroom_forced_checkin one_on_one_tutoring]

    table = []
    table << "| Condition | Learners | Correct% |"
    table << "|-----------|---------|---------|"
    target_conds.each do |cond|
      cond_rows = by_cond[cond] || []
      next if cond_rows.empty?
      n   = cond_rows.map { |r| r['learner_id'] }.uniq.size
      pct = avg_correctness(cond_rows)
      table << "| #{cond} | #{n} | #{(pct * 100).round}% |"
    end
    table.join("\n")
  end

  def self.order_confused_scaffold_effect(rows)
    oc_rows = rows.select do |r|
      profile = r['profile_json'] ? JSON.parse(r['profile_json']) : {}
      profile['type_key'] == 'order_confused'
    end
    return '' if oc_rows.empty?

    by_cond = oc_rows.group_by { |r| r['condition'] }
    target_conds = %w[classroom_public_qa generic_one_on_one_tutoring procedure_scaffolded_one_on_one_tutoring]

    table = []
    table << "| Condition | Learners | Correct% | Procedure Order Errors% |"
    table << "|-----------|---------|---------|------------------------|"
    target_conds.each do |cond|
      cond_rows = by_cond[cond] || []
      next if cond_rows.empty?
      n        = cond_rows.map { |r| r['learner_id'] }.uniq.size
      pct      = avg_correctness(cond_rows)
      err_rate = procedure_order_error_rate(cond_rows)
      table << "| #{cond} | #{n} | #{(pct * 100).round}% | #{(err_rate * 100).round}% |"
    end
    table.join("\n")
  end

  def self.procedure_order_error?(response_text)
    text = response_text.to_s.downcase
    mod_pos = [text.index('×'), text.index('modifier'), text.index('multiply')].compact.min
    act_pos = [text.index('active'), text.index('inactive'), text.index('activation')].compact.min
    return false unless mod_pos && act_pos
    mod_pos < act_pos
  end

  def self.procedure_order_error_rate(rows)
    return 0.0 if rows.empty?
    errors = rows.count { |r| procedure_order_error?(r['response_text'].to_s) }
    errors.to_f / rows.size
  end

  def self.readiness_summary_section(mastery_rows, readiness_pass_rate)
    return '' if mastery_rows.nil? || mastery_rows.empty?
    target_met = readiness_pass_rate >= 0.80
    lines = []
    lines << "## Readiness Summary"
    lines << ""
    lines << "| Metric | Value |"
    lines << "|--------|-------|"
    lines << "| Overall readiness pass rate | #{(readiness_pass_rate * 100).round}% |"
    lines << "| Target (80%) | #{target_met ? '✓ Readiness target met' : '✗ READINESS TARGET NOT MET'} |"
    lines << ""
    lines << "### Pass Rate by Check Type"
    lines << ""
    lines << "| Check Type | Total | Correct | Pass Rate |"
    lines << "|------------|-------|---------|-----------|"
    mastery_rows.group_by { |r| r['check_type'] }.sort.each do |check_type, type_rows|
      total   = type_rows.size
      correct = type_rows.count { |r| r['answer_correct'].to_i == 1 }
      pct     = total > 0 ? (correct.to_f / total * 100).round : 0
      lines << "| #{check_type} | #{total} | #{correct} | #{pct}% |"
    end
    lines << ""
    unless target_met
      lines << "> **WARNING:** Readiness target not met. Do not make strong claims about"
      lines << "> ownership or class-size effects from this run."
      lines << ""
    end
    lines.join("\n")
  end

  def self.fine_grained_memory_delta_section(pre_snapshots, memories_by_condition)
    return '' if pre_snapshots.nil? || pre_snapshots.empty? || memories_by_condition.empty?
    pre_by_learner = pre_snapshots.each_with_object({}) { |s, h| h[s['learner_id']] = s['diag'] }
    items = MemoryDiagnostics::ITEMS.keys
    short = items.map { |k| k.to_s.split('_').first(2).join('_') }

    lines = []
    lines << "## Fine-Grained Memory Coverage Post-Discussion (10 items)"
    lines << ""
    lines << "| Condition | " + short.map { |s| "#{s} |" }.join(' ')
    lines << "|-----------|" + items.map { " :---: |" }.join
    memories_by_condition.sort_by { |k, _| k }.each do |cond, mem_list|
      next if mem_list.empty?
      post_diags = mem_list.map { |m| MemoryDiagnostics.detect(m['memory']) }
      cols = items.map do |item|
        pct = (post_diags.count { |d| d[item] }.to_f / post_diags.size * 100).round
        "#{pct}% |"
      end
      lines << "| #{cond} | #{cols.join(' ')}"
    end
    lines << ""

    lines << "## Fine-Grained Memory Delta (pre → post discussion)"
    lines << ""
    lines << "| Condition | Avg Acquired | Avg Lost | Avg Stable |"
    lines << "|-----------|:------------:|:--------:|:----------:|"
    memories_by_condition.sort_by { |k, _| k }.each do |cond, mem_list|
      next if mem_list.empty?
      deltas = mem_list.map do |m|
        raw_diag  = pre_by_learner[m['learner_id']] || {}
        pre_diag  = raw_diag.transform_keys(&:to_sym)
        post_diag = MemoryDiagnostics.detect(m['memory'])
        {
          acquired: items.count { |k| !pre_diag[k] && post_diag[k] },
          lost:     items.count { |k|  pre_diag[k] && !post_diag[k] },
          stable:   items.count { |k|  pre_diag[k] &&  post_diag[k] }
        }
      end
      avg_acq    = (deltas.sum { |d| d[:acquired] }.to_f / deltas.size).round(1)
      avg_lost   = (deltas.sum { |d| d[:lost]     }.to_f / deltas.size).round(1)
      avg_stable = (deltas.sum { |d| d[:stable]   }.to_f / deltas.size).round(1)
      lines << "| #{cond} | #{avg_acq} | #{avg_lost} | #{avg_stable} |"
    end
    lines << ""
    lines.join("\n")
  end

  def self.interpretation_flags_section(rows, mastery_rows, ownership_rows, readiness_pass_rate)
    by_condition  = rows.group_by { |r| r['condition'] }
    score_by_cond = by_condition.transform_values { |rs| avg_correctness(rs) }
    own_summary   = OwnershipMetrics.summary_by_condition(ownership_rows)

    readiness_failed = readiness_pass_rate < 0.80

    # Ownership × score Kendall-tau concordance
    pairs = own_summary.map { |cond, s| [s[:avg_ownership_score], score_by_cond[cond] || 0] }
    n_concordant = n_discordant = 0
    pairs.combination(2).each do |(o1, s1), (o2, s2)|
      diff = (o1 - o2) * (s1 - s2)
      n_concordant += 1 if diff > 0
      n_discordant += 1 if diff < 0
    end
    ownership_effect_supported = n_concordant > n_discordant

    # Class-size effect: do larger classes score lower?
    sizes = {
      'pair_discussion_size_2'         => 2,
      'small_class_discussion_size_4'  => 4,
      'medium_class_discussion_size_8' => 8,
      'large_class_discussion_size_16' => 16
    }
    disc_scores = score_by_cond.select { |k, _| sizes.key?(k) }.sort_by { |k, _| sizes[k] }
    ordered_scores = disc_scores.map { |_, v| v }
    class_size_effect_supported = ordered_scores == ordered_scores.sort.reverse && ordered_scores.size >= 2

    # Lecture-only dominance
    lecture_score = score_by_cond['lecture_only'] || 0.0
    disc_cond_scores = score_by_cond.reject { |k, _| k == 'lecture_only' }
    lecture_only_dominant = disc_cond_scores.values.all? { |s| s <= lecture_score } && disc_cond_scores.any?

    # Discussion added value (any discussion > lecture_only + 5pp)
    discussion_added_value = disc_cond_scores.values.any? { |s| s > lecture_score + 0.05 }

    lines = []
    lines << "## Interpretation Flags"
    lines << ""
    lines << "| Flag | Value |"
    lines << "|------|-------|"
    lines << "| readiness_failed | #{readiness_failed} |"
    lines << "| ownership_effect_supported | #{ownership_effect_supported} |"
    lines << "| class_size_effect_supported | #{class_size_effect_supported} |"
    lines << "| lecture_only_dominant | #{lecture_only_dominant} |"
    lines << "| discussion_added_value | #{discussion_added_value} |"
    lines << ""
    lines << "## Interpretation"
    lines << ""
    if readiness_failed
      lines << "**WARNING: readiness_failed = true** — prerequisite readiness target (80%) not met."
      lines << "Ownership and class-size conclusions from this run are unreliable."
    else
      lines << "Readiness target met (#{(readiness_pass_rate * 100).round}%). Interpretations below are valid."
      lines << ""
      if ownership_effect_supported
        lines << "- **Ownership hypothesis supported**: higher ownership score conditions outperformed lower."
      else
        lines << "- **Ownership hypothesis NOT supported**: ownership score did not predict final score."
      end
      if class_size_effect_supported
        lines << "- **Class-size effect supported**: scores decreased as class size increased."
      else
        lines << "- **Class-size effect NOT supported**: no clear linear relationship between class size and score."
      end
      if lecture_only_dominant
        lines << "- **Lecture-only dominant**: lecture_only outperformed all discussion conditions."
        lines << "  Discussion may add little beyond prerequisite lecture + readiness correction."
      end
      if discussion_added_value
        lines << "- **Discussion added value**: at least one discussion condition outperformed lecture_only by > 5pp."
      end
    end
    lines << ""
    lines.join("\n")
  end
end
