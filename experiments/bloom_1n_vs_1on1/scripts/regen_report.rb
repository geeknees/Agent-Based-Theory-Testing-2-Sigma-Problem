# ABOUTME: Regenerates report.md for an existing run directory without re-running the experiment
# ABOUTME: Reads DB and existing report.md (for token_summary), writes fresh report.md in-place

require_relative '../lib/db'
require_relative '../lib/report'
require 'json'
require 'sqlite3'

def parse_token_summary_from_report(report_path)
  return {} unless File.exist?(report_path)
  summary = {}
  in_token_section = false
  File.readlines(report_path).each do |line|
    in_token_section = true  if line.strip.start_with?('## Token Usage by Phase')
    in_token_section = false if in_token_section && line.strip.start_with?('##') && !line.include?('Token Usage')
    next unless in_token_section
    # | phase | input | output | total |
    m = line.match(/^\|\s*([^|*]+?)\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|/)
    next unless m
    phase = m[1].strip
    next if phase == 'Phase'
    summary[phase] = {
      'input_tokens'  => m[2].to_i,
      'output_tokens' => m[3].to_i,
      'total_tokens'  => m[4].to_i
    }
  end
  summary
end

run_dir = ARGV[0]
unless run_dir && Dir.exist?(run_dir)
  $stderr.puts "Usage: ruby regen_report.rb <run_dir>"
  $stderr.puts "  e.g. ruby regen_report.rb data/runs/dd2fd888-..."
  exit 1
end

config     = JSON.parse(File.read(File.join(run_dir, 'config.json')))
run_id     = File.basename(run_dir)
repo_root  = File.expand_path('../../..', __dir__)
db_path    = File.join(repo_root, config.dig('paths', 'db'))
report_md  = File.join(run_dir, 'report.md')

$stderr.puts "[regen] run_id:  #{run_id}"
$stderr.puts "[regen] db_path: #{db_path}"

token_summary = parse_token_summary_from_report(report_md)
$stderr.puts "[regen] token phases restored: #{token_summary.keys.join(', ')}"

# Determine experiment from config name
exp_name = config.dig('experiment', 'name') || ''
exp_meta = if exp_name.include?('v7a') || exp_name.include?('passive')
             { experiment: 'A' }
           elsif exp_name.include?('v7b') || exp_name.include?('order_confused')
             { experiment: 'B' }
           else
             {}
           end
$stderr.puts "[regen] experiment_meta: #{exp_meta}"

db = SQLite3::Database.new(db_path)
db.results_as_hash = true

Report.generate(db, run_id: run_id, output_dir: run_dir,
                run_config: config, token_summary: token_summary,
                experiment_meta: exp_meta)

db.close
$stderr.puts "[regen] Done. Updated: #{report_md}"
