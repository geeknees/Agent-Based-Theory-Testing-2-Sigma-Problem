# ABOUTME: Generates CSV scores and Markdown experiment report from database results
# ABOUTME: Includes ceiling effect detection, token usage metrics, and difficulty breakdown

require 'csv'
require 'json'
require 'date'
require 'fileutils'
require_relative 'db'
require_relative 'ownership_metrics'

module Report
  SCORE_DIMENSIONS  = %w[correctness reasoning_quality rule_application error_checking autonomy].freeze
  CEILING_THRESHOLD = 0.9
  DIFFICULTY_LEVELS = %w[L1 L2 L3 L4 L5 L6].freeze

  def self.generate(db, run_id:, output_dir:, run_config:, token_summary: {}, experiment_meta: {})
    FileUtils.mkdir_p(output_dir)
    rows                  = DB.all_attempts_with_scores(db, run_id)
    memories_by_condition = DB.all_memories_by_condition(db, run_id)
    mastery_rows          = experiment_meta[:experiment] == 'v8' ?
                              DB.all_mastery_checks_by_condition(db, run_id) : []
    write_csv(rows, output_dir)
    markdown = build_markdown(rows, run_id: run_id, output_dir: output_dir,
                              run_config: run_config, token_summary: token_summary,
                              memories_by_condition: memories_by_condition,
                              experiment_meta: experiment_meta,
                              mastery_rows: mastery_rows)
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

  def self.build_markdown(rows, run_id:, output_dir:, run_config:, token_summary:, memories_by_condition: {}, experiment_meta: {}, mastery_rows: [])
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
    lines << "## Score by Task Type × Condition"
    lines << ""
    lines << "| Task Type | Difficulty | No-Ed Correct% | Classroom Correct% | Tutoring Correct% |"
    lines << "|-----------|-----------|----------------|-------------------|-------------------|"
    all_conds       = rows.map { |r| r['condition'] }.uniq
    classroom_conds = all_conds.select { |c| c.include?('classroom') }
    tutoring_conds  = all_conds.select { |c| c.include?('tutoring') || c == '1on1' }
    rows.group_by { |r| r['task_type'] }.sort.each do |task_type, type_rows|
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
      level_rows = rows.select { |r| extract_difficulty(r['task_id']) == level }
      next if level_rows.empty?
      types  = level_rows.map { |r| r['task_type'] }.uniq.join(', ')
      no_pct = avg_correctness(level_rows.select { |r| r['condition'] == 'no_education' })
      c_pct  = avg_correctness(level_rows.select { |r| classroom_conds.include?(r['condition']) })
      t_pct  = avg_correctness(level_rows.select { |r| tutoring_conds.include?(r['condition']) })
      lines << "| #{level} | #{types} | #{(no_pct * 100).round}% | #{(c_pct * 100).round}% | #{(t_pct * 100).round}% |"
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

    # Profile-based breakdown
    lines << "## Score by Learner Profile"
    lines << ""
    %w[ability misconception interest].each do |dim|
      by_dim = score_by_profile_dimension(rows, dim)
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
    variance = score_variance_by_condition(rows)
    lines << "## Score Variance by Condition (std dev of per-learner correct%)"
    lines << ""
    lines << "| Condition | Std Dev |"
    lines << "|-----------|--------|"
    variance.sort.each do |cond, sd|
      lines << "| #{cond} | #{sd} |"
    end
    lines << ""

    # Token per correct answer
    tpca = token_per_correct_answer(rows, token_summary)
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

    # Heterogeneity interpretation
    interpretations = heterogeneity_interpretation(rows, token_summary)
    lines << "## Heterogeneity Interpretation"
    lines << ""
    if interpretations.empty?
      lines << "No strong heterogeneity signal detected."
    else
      interpretations.each { |i| lines << "- **#{i}** ✓" }
    end
    lines << ""

    # Score by learner type
    type_scores = score_by_learner_type(rows)
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
    hcw_rate  = high_confidence_wrong_rate(rows)
    abst_rate = abstention_rate(rows)
    lines << "## Confidence Calibration"
    lines << ""
    lines << "| Metric | Rate |"
    lines << "|--------|------|"
    lines << "| High-confidence wrong | #{(hcw_rate * 100).round}% |"
    lines << "| Abstention | #{(abst_rate * 100).round}% |"
    lines << ""

    # Exp A: passive_listener rescue effect
    if experiment_meta[:experiment] == 'A'
      rescue_table = passive_listener_rescue_effect(rows)
      unless rescue_table.empty?
        lines << "## Passive Listener Rescue Effect"
        lines << ""
        lines << rescue_table
        lines << ""
      end
    end

    # Exp B: order_confused scaffold effect + procedure order errors
    if experiment_meta[:experiment] == 'B'
      scaffold_table = order_confused_scaffold_effect(rows)
      unless scaffold_table.empty?
        lines << "## Order Confused Scaffold Effect"
        lines << ""
        lines << scaffold_table
        lines << ""
      end

      proc_error_rate = procedure_order_error_rate(rows)
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
end
