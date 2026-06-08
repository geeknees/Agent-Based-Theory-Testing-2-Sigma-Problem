# ABOUTME: Re-scores stored short_rule_induction (L6) attempts with the corrected acceptable_aliases
# ABOUTME: Does not mutate the DB — prints a before/after comparison for the methodology addendum
# Usage: ruby scripts/rescore_l6.rb <db_path> <run_id>

require 'sqlite3'
require 'json'
require_relative '../lib/scorer'
require_relative '../lib/helpers'

db_path, run_id = ARGV
abort 'Usage: ruby scripts/rescore_l6.rb <db_path> <run_id>' unless db_path && run_id

domain_path = File.expand_path('../domains/zarn_tokens', __dir__)
eval_tasks  = JSON.parse(File.read(File.join(domain_path, 'eval_tasks_v8.json')))
l6_task     = eval_tasks.find { |t| t['task_type'] == 'short_rule_induction' }
abort "No task with task_type 'short_rule_induction' found in eval_tasks_v8.json" unless l6_task

db = SQLite3::Database.new(db_path)
db.results_as_hash = true

rows = db.execute(<<~SQL, [run_id, l6_task['id']])
  SELECT ta.id AS attempt_id, ta.condition, ta.response_text, e.score_json
  FROM task_attempts ta
  LEFT JOIN evaluations e ON e.attempt_id = ta.id
  WHERE ta.run_id = ? AND ta.task_id = ?
SQL

before_correct = 0
after_correct  = 0
by_condition   = Hash.new { |h, k| h[k] = { before: 0, after: 0, total: 0 } }

rows.each do |r|
  parsed = Helpers.extract_json(r['response_text'].to_s)
  next unless parsed

  old_score = JSON.parse(r['score_json'] || '{}')
  new_score = Scorer.score_attempt(parsed, l6_task)

  cond = r['condition']
  by_condition[cond][:total]   += 1
  by_condition[cond][:before]  += 1 if old_score['answer_correct']
  by_condition[cond][:after]   += 1 if new_score['answer_correct']
  before_correct += 1 if old_score['answer_correct']
  after_correct  += 1 if new_score['answer_correct']

  next if old_score['answer_correct'] == new_score['answer_correct']
  puts "[changed] attempt=#{r['attempt_id']} condition=#{cond}: " \
       "#{old_score['answer_correct'].inspect} -> #{new_score['answer_correct'].inspect}"
  puts "  given: #{parsed['answer']}"
end

puts
puts "=== L6 (short_rule_induction) rescore summary: #{run_id} ==="
puts format('%-35s %8s %8s %8s', 'condition', 'total', 'before', 'after')
by_condition.each do |cond, c|
  puts format('%-35s %8d %8d %8d', cond, c[:total], c[:before], c[:after])
end
puts format('%-35s %8d %8d %8d', 'TOTAL', rows.size, before_correct, after_correct)

db.close
