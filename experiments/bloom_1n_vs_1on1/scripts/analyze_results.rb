# ABOUTME: Standalone post-hoc analysis script for experiment results
# ABOUTME: Reads a run directory scores.csv and prints summary statistics to stdout

require 'csv'
require 'json'

run_dir = ARGV[0] or abort "Usage: #{$0} <run_dir>"
abort "Directory not found: #{run_dir}" unless Dir.exist?(run_dir)

scores_path = File.join(run_dir, 'scores.csv')
abort "scores.csv not found in #{run_dir}" unless File.exist?(scores_path)

rows = CSV.read(scores_path, headers: true)

puts "=== Analysis: #{File.basename(run_dir)} ==="
puts "Total attempts: #{rows.size}"
puts ""

by_condition = rows.group_by { |r| r['condition'] }
puts "--- By Condition ---"
by_condition.each do |condition, cond_rows|
  totals = cond_rows.map { |r| r['total'].to_f }
  avg = totals.sum / totals.size
  puts "#{condition}: n=#{cond_rows.size}, avg_total=#{format('%.2f', avg)}, min=#{totals.min.to_i}, max=#{totals.max.to_i}"
end
puts ""

by_task_type = rows.group_by { |r| r['task_type'] }
puts "--- By Task Type × Condition ---"
%w[recall near_transfer far_transfer].each do |task_type|
  task_rows = by_task_type[task_type] || []
  %w[classroom 1on1].each do |cond|
    cond_rows = task_rows.select { |r| r['condition'] == cond }
    next if cond_rows.empty?
    totals = cond_rows.map { |r| r['total'].to_f }
    avg = totals.sum / totals.size
    puts "  #{task_type} / #{cond}: n=#{cond_rows.size}, avg=#{format('%.2f', avg)}"
  end
end
