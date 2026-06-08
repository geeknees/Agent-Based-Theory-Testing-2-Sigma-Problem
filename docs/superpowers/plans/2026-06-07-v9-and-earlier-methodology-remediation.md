# v9 系列および過去実験の方法論的バグ是正計画 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** v9c の独立分析で見つかった5つの方法論的バグ・confound（F1〜F5、下記サマリ参照）について、(1) 既存データの再実行なしで是正できるものを是正して再出力し、(2) v4〜v8 にも同じ監査を適用して是正・再出力し、(3) 再実験でしか直せない条件を一覧化して `v9c2` 設計チェックリストとして文書化する。

**Architecture:** 3つの STEP に分割する。STEP 1/2 は「既存 DB に対する診断スクリプト実行 → 該当箇所のスコア再計算 → レポートに方法論的注記セクションを追加 → addendum として再出力」というパイプラインを共通化し、v9c → v9b → v8 → v4/v5/v6/v7a/v7b の順に適用する。STEP 3 は STEP 1/2 で「直せなかった」項目を集約し、優先順位とトークンコスト見積もり付きの設計チェックリストにまとめる。

**Tech Stack:** Ruby（既存実験フレームワーク・Minitest、`lib/scorer.rb` 等を再利用）、Python3 + sqlite3（DB 診断スクリプト）、Markdown（addendum・チェックリスト文書）

---

## 前提知識：何が問題だったか（F1〜F5 サマリ）

このセッションの独立検証で、v9c の `b412cfdb-...` run について以下を確認済み：

| ID | 内容 | 影響範囲（判明分） |
|----|------|-------------------|
| F1 | `corrective_note` は静的テンプレ（LLM 生成ではない） | v9c（readiness check 専用、構造的に他バージョンには存在しない） |
| F2 | L6 (`short_rule_induction`) scorer が exact-match のみで意味的に正しい言い換えを 0 点にする | `eval_tasks_v8.json` を使う **v8 / v9b / v9c**（`l6_induction_02` の `expected_answer` が自由記述文）。v4 は L6 task が数値解答形式のため非該当、v2/v3 の自由記述 task (`l5_counterexample_01`) は alias が充実していて非該当 |
| F3 | discussion 参加者の prompt context に lesson/memory が注入されていない（"I don't have the rules" と全 session で発話） | `Phases::SizedDiscussion`（v9b, v9c）と `Phases::WholeClassDiscussion`（v8 WCD のみ）。**`Phases::Classroom`（v4-v7）と `Phases::SmallGroupDiscussion`（v8 SGD）は lesson を注入しており非該当**（後述コード根拠） |
| F4 | pseudoreplication：1 condition = 1 discussion インスタンス（learner 全員が byte-identical transcript を共有） | `Phases::Classroom.run` も `learner_ids` をまとめて1回呼ぶ構造のため、**v4〜v9c の classroom/discussion 系条件すべてに及ぶ可能性が高い**（要監査） |
| F5a | 学習者プロファイルが全員同一型 | **誤り**。v9c 本番 run は実際には 4 type（rule_extractor/passive_listener/edge_case_dropper/order_confused）混在。要 per-version 確認 |
| F5b | moderator/evaluator が単一インスタンス | v9c で確認（`evaluator` 1件、`classroom_teacher` 1件）。他バージョンも要確認 |

根拠コード（このセッションで確認済み、再確認不要）：
- `lib/phases/sized_discussion.rb:64-75` — `contrib_prompt` の `context` は `"DISCUSSION SO FAR:\n#{history}"` のみ。`lesson` は moderator の `open_prompt`/`close_prompt` にしか渡らない。
- `lib/phases/whole_class_discussion.rb:40-41` — 同型バグ（`context: "DISCUSSION SO FAR:\n#{history}#{learner_ctx}"`、lesson なし）。
- `lib/phases/small_group_discussion.rb:35-36` — `context: "#{ctx_prefix}LESSON CONTEXT:\n#{lesson}#{learner_ctx}"` で lesson を注入済み（バグなし）。
- `lib/phases/classroom.rb:59` — `context: "DOMAIN LESSON:\n#{lesson}#{context_suffix}\n\nLECTURE DELIVERED:\n#{lecture}"` で lesson を注入済み（バグなし）。
- `lib/scorer.rb:25-29` — `answer_correct = given_answer == expected_answer` + 固定 `acceptable_aliases` ハッシュのみ。

---

## File Structure

新規作成・変更するファイル：

- Create: `experiments/bloom_1n_vs_1on1/scripts/check_replication.py` — condition ごとの独立 discussion 数を transcript hash で検出
- Create: `experiments/bloom_1n_vs_1on1/scripts/check_confounds.py` — learner profile 多様性 / moderator・evaluator instance 数 / phase exposure を検出
- Create: `experiments/bloom_1n_vs_1on1/scripts/rescore_l6.rb` — `short_rule_induction` 攻撃を拡張 alias で再採点（DB は変更しない、比較表を出力するのみ）
- Modify: `experiments/bloom_1n_vs_1on1/domains/zarn_tokens/eval_tasks_v8.json` — `l6_induction_02` に `acceptable_aliases` を追加
- Test: `experiments/bloom_1n_vs_1on1/tests/test_scorer.rb` — 新 alias で実際の学習者回答が正答判定されることを確認するリグレッションテストを追加
- Create: `experiments/bloom_1n_vs_1on1/results/2026-06-0X-v9c-methodology-addendum.md`、同 v9b 版、v8 版、v4〜v7 版（各 STEP の最終出力）
- Create: `experiments/bloom_1n_vs_1on1/results/2026-06-0X-v4-v9c-replication-confound-audit-table.md`（STEP 2 の集約監査表）
- Create: `docs/superpowers/plans/2026-06-0X-v9c2-design-checklist.md`（STEP 3 の最終成果物）
- Modify: `experiments/bloom_1n_vs_1on1/results/2026-06-06-v9c-full-analysis.md` — 「F5a: 学習者プロファイルが同一型」という外部ノートの誤りを訂正する旨の追記（このノートは別の場所にあるが、プロジェクト内のレポート自体は訂正不要。ノート修正は Task 7 で対応）

---

## STEP 1: v9c・v9b — 再実験不要の修正 → 再出力

### Task 1: `check_replication.py` を作成し、v9c・v9b に適用する

**Files:**
- Create: `experiments/bloom_1n_vs_1on1/scripts/check_replication.py`

- [ ] **Step 1: スクリプトを作成する**

```python
#!/usr/bin/env python3
# ABOUTME: Hashes learning_sessions.transcript_json per condition to count independent discussion instances
# ABOUTME: Usage: python3 check_replication.py <db_path> <run_id>

import sqlite3
import hashlib
import sys
from collections import defaultdict


def check_replication(db_path, run_id):
    con = sqlite3.connect(db_path)
    con.row_factory = sqlite3.Row
    rows = con.execute(
        "SELECT condition, transcript_json FROM learning_sessions WHERE run_id = ?",
        (run_id,)
    ).fetchall()

    by_cond = defaultdict(lambda: {'hashes': set(), 'rows': 0})
    for r in rows:
        h = hashlib.md5(r['transcript_json'].encode()).hexdigest()
        by_cond[r['condition']]['hashes'].add(h)
        by_cond[r['condition']]['rows'] += 1

    print(f"{'condition':<35} {'sessions':>9} {'unique_discussions':>20}")
    for cond, stats in sorted(by_cond.items()):
        print(f"{cond:<35} {stats['rows']:>9} {len(stats['hashes']):>20}")
    con.close()


if __name__ == '__main__':
    if len(sys.argv) != 3:
        print("Usage: python3 check_replication.py <db_path> <run_id>", file=sys.stderr)
        sys.exit(1)
    check_replication(sys.argv[1], sys.argv[2])
```

- [ ] **Step 2: v9c に対して実行し、結果を確認する**

Run:
```bash
cd experiments/bloom_1n_vs_1on1
python3 scripts/check_replication.py data/experiment_v9c.db b412cfdb-0522-4997-a47e-1738eb414f4b
```
Expected: 4 つの discussion 条件すべてで `unique_discussions` 列が `1` になる（このセッションで MD5 比較済み — pair=1, small=1, medium=1, large=1）。

- [ ] **Step 3: v9b に対して実行し、結果をメモする**

Run:
```bash
python3 scripts/check_replication.py data/experiment_v9b.db 772d2ce7-246a-467e-89ae-b63d02d39c85
```
Expected: v9c と同じ構造（`SizedDiscussion.run` を同一シグネチャで1回ずつ呼んでいるため）なので `unique_discussions = 1` になるはず。実行して数値を記録する（v9c との一致を確認することで「3 run 一致は再現性ではなく構造的必然」という F4 の含意が補強される）。

- [ ] **Step 4: コミットする**

```bash
git add experiments/bloom_1n_vs_1on1/scripts/check_replication.py
git commit -m "test(audit): add transcript-replication checker for discussion phases"
```

---

### Task 2: `check_confounds.py` を作成し、v9c・v9b に適用する

**Files:**
- Create: `experiments/bloom_1n_vs_1on1/scripts/check_confounds.py`

- [ ] **Step 1: スクリプトを作成する**

```python
#!/usr/bin/env python3
# ABOUTME: Reports learner-profile diversity and single-instance moderator/evaluator/tutor risk for a run
# ABOUTME: Usage: python3 check_confounds.py <db_path> <run_id>

import sqlite3
import sys
from collections import Counter

ROLES_TO_CHECK = ('classroom_teacher', 'tutor', 'evaluator')


def check_confounds(db_path, run_id):
    con = sqlite3.connect(db_path)
    con.row_factory = sqlite3.Row

    profiles = Counter()
    for r in con.execute(
        "SELECT profile_json FROM agents WHERE run_id = ? AND role = 'learner'", (run_id,)
    ):
        profiles[r['profile_json'] or '(none)'] += 1
    print("Learner profile distribution:")
    for p, c in profiles.most_common():
        print(f"  {c:>3}  {p}")
    print(f"  -> distinct profiles: {len(profiles)}")
    print()

    print("Single-instance role check:")
    for role in ROLES_TO_CHECK:
        ids = [r[0] for r in con.execute(
            "SELECT DISTINCT id FROM agents WHERE run_id = ? AND role = ?", (run_id, role)
        )]
        if ids:
            flag = '  <-- SINGLE INSTANCE (tutor/judge variance ≠ condition variance)' if len(ids) == 1 else ''
            print(f"  {role:<20} distinct instances: {len(ids)}{flag}")
    print()

    print("learning_sessions rows per condition (phase-exposure check):")
    for r in con.execute(
        "SELECT condition, COUNT(*) AS n FROM learning_sessions WHERE run_id = ? GROUP BY condition",
        (run_id,)
    ):
        print(f"  {r['condition']:<35} {r['n']}")
    con.close()


if __name__ == '__main__':
    if len(sys.argv) != 3:
        print("Usage: python3 check_confounds.py <db_path> <run_id>", file=sys.stderr)
        sys.exit(1)
    check_confounds(sys.argv[1], sys.argv[2])
```

- [ ] **Step 2: v9c に対して実行し、結果を確認する**

Run:
```bash
python3 scripts/check_confounds.py data/experiment_v9c.db b412cfdb-0522-4997-a47e-1738eb414f4b
```
Expected:
- `Learner profile distribution` に 4 種類（`rule_extractor` ×9, `passive_listener` ×8, `edge_case_dropper` ×9, `order_confused` ×8）が表示される（= F5a は v9c では成立しないことの再確認）
- `classroom_teacher` と `evaluator` がともに `distinct instances: 1` で `<-- SINGLE INSTANCE` フラグが付く（= F5b の再確認）
- `lecture_only` の `learning_sessions` 行数が `0`（discussion phase が存在しないため、F5c の「学習時間非対称」の事実確認）

- [ ] **Step 3: v9b に対して実行し、結果をメモする**

Run:
```bash
python3 scripts/check_confounds.py data/experiment_v9b.db 772d2ce7-246a-467e-89ae-b63d02d39c85
```
Expected: 結果を記録する。v9b の learner type 設定（config の `learner_types` 項目）と突き合わせて、F5a が v9b にも非該当か（= 多様なプロファイルが使われているか）を確認する。

- [ ] **Step 4: コミットする**

```bash
git add experiments/bloom_1n_vs_1on1/scripts/check_confounds.py
git commit -m "test(audit): add learner-profile and single-instance-role confound checker"
```

---

### Task 3: v9b の transcript で F3（discussion 参加者に lesson が無い）パターンを確認する

**Files:** なし（調査のみ、結果は Task 7 の addendum に記録）

- [ ] **Step 1: v9b の各 discussion 条件の最初の learner 発話を確認する**

Run:
```bash
cd experiments/bloom_1n_vs_1on1/data
python3 -c "
import sqlite3, json
con = sqlite3.connect('experiment_v9b.db')
con.row_factory = sqlite3.Row
rid = '772d2ce7-246a-467e-89ae-b63d02d39c85'
rows = con.execute(\"SELECT condition, transcript_json FROM learning_sessions WHERE run_id=?\", (rid,)).fetchall()
seen = set()
for r in rows:
    if r['condition'] in seen:
        continue
    seen.add(r['condition'])
    turns = json.loads(r['transcript_json'])['turns']
    contributions = [t for t in turns if t['type'] == 'contribution']
    if contributions:
        print(r['condition'], '| first contribution:', contributions[0]['content'][:160].replace(chr(10), ' '))
"
```
Expected: v9c と同じ "I don't have the rules" 系の発話が出るかどうかを確認する。出れば F3 が v9b にも及んでいる強い証拠になる（コード構造は同一なので、出ない場合はその差異の原因を追加調査する必要がある）。

- [ ] **Step 2: 結果をメモに残す**

このステップにはコミット対象のファイル変更はない。結果は Task 7 で addendum に転記する。

---

### Task 4: L6 (`short_rule_induction`) scorer を意味的に正しい言い換えを許容するよう修正する

**Files:**
- Modify: `experiments/bloom_1n_vs_1on1/domains/zarn_tokens/eval_tasks_v8.json`
- Test: `experiments/bloom_1n_vs_1on1/tests/test_scorer.rb`

- [ ] **Step 1: 失敗するテストを書く**

`test_scorer.rb` の末尾（既存の `class TestScorer < Minitest::Test` 内）に追加：

```ruby
  def test_l6_induction_accepts_real_learner_paraphrases
    domain_path = File.expand_path('../domains/zarn_tokens', __dir__)
    eval_tasks  = JSON.parse(File.read(File.join(domain_path, 'eval_tasks_v8.json')))
    task        = eval_tasks.find { |t| t['id'] == 'l6_induction_02' }

    # Verbatim answers pulled from v9c run b412cfdb-...; auto-scorer marked all of these
    # as incorrect (correctness: 0) despite being semantically equivalent to expected_answer.
    real_paraphrases = [
      'Red contributes 0; doubles the base value of the next token only.',
      'Red doubles the base value of the immediately next token; Red itself scores 0.',
      "Red doubles the next token's value; contributes 0 itself."
    ]

    real_paraphrases.each do |answer|
      parsed = { 'answer' => answer, 'active_tokens' => [], 'mistakes_found' => [], 'reason' => 'test' }
      score  = Scorer.score_attempt(parsed, task)
      assert score['answer_correct'],
        "Expected paraphrase to score correct: #{answer.inspect}\n" \
        "  expected_answer: #{task['expected_answer'].inspect}\n" \
        "  aliases checked: #{task['acceptable_aliases'].inspect}"
    end
  end
```

- [ ] **Step 2: テストを実行して失敗を確認する**

Run: `cd experiments/bloom_1n_vs_1on1 && ruby tests/test_scorer.rb -n test_l6_induction_accepts_real_learner_paraphrases`
Expected: FAIL — `Expected paraphrase to score correct: "Red contributes 0; doubles the base value of the next token only."`（exact-match のため）

- [ ] **Step 3: `eval_tasks_v8.json` の `l6_induction_02` に `acceptable_aliases` を追加する**

`expected_answer` は `"red doubles the next token and contributes 0 points itself"`。同タスクに以下のキーで `acceptable_aliases` を追加する（既存に無ければ新規追加、既存の構造（`{key: [alias, ...]}`）に合わせる）：

```json
"acceptable_aliases": {
  "red doubles the next token and contributes 0 points itself": [
    "red contributes 0; doubles the base value of the next token only",
    "red doubles the base value of the immediately next token; red itself scores 0",
    "red doubles the next token's value; contributes 0 itself",
    "red doubles the value of the token after it and scores 0 points itself",
    "red itself is worth 0 points and doubles the score of the following token",
    "red scores 0 and doubles the next token's base value",
    "red is a modifier that doubles the next token and contributes nothing itself",
    "red contributes 0 points and doubles the next token's value"
  ]
}
```

`Scorer.score_attempt` の alias チェックは `given_answer.downcase` と `vals.map(&:downcase)` を比較するため、JSON 側は小文字で揃えて構わない（`lib/scorer.rb:28` 参照）。

- [ ] **Step 4: テストを再実行して通ることを確認する**

Run: `ruby tests/test_scorer.rb -n test_l6_induction_accepts_real_learner_paraphrases`
Expected: PASS（3件とも `answer_correct: true`）

- [ ] **Step 5: 既存の scorer テストスイート全体を流して回帰がないことを確認する**

Run: `ruby tests/test_scorer.rb`
Expected: 既存のテストもすべて PASS のまま

- [ ] **Step 6: コミットする**

```bash
git add experiments/bloom_1n_vs_1on1/domains/zarn_tokens/eval_tasks_v8.json experiments/bloom_1n_vs_1on1/tests/test_scorer.rb
git commit -m "fix(scorer): accept semantically-equivalent paraphrases for L6 short_rule_induction

Auto-scorer used exact-match only, marking 34/34 v9c learner answers as
incorrect (correctness: 0) despite being semantically correct restatements
of the Red-token rule. Added acceptable_aliases covering observed phrasings."
```

---

### Task 5: `rescore_l6.rb` を作成し、v8・v9b・v9c の既存 attempts を再採点して比較表を出す

**Files:**
- Create: `experiments/bloom_1n_vs_1on1/scripts/rescore_l6.rb`

- [ ] **Step 1: スクリプトを作成する**

```ruby
# ABOUTME: Re-scores stored short_rule_induction (L6) attempts with the corrected acceptable_aliases
# ABOUTME: Does not mutate the DB — prints a before/after comparison for the methodology addendum
# Usage: ruby scripts/rescore_l6.rb <db_path> <run_id>

require 'sqlite3'
require 'json'
require_relative '../lib/scorer'

db_path, run_id = ARGV
abort 'Usage: ruby scripts/rescore_l6.rb <db_path> <run_id>' unless db_path && run_id

domain_path = File.expand_path('../domains/zarn_tokens', __dir__)
eval_tasks  = JSON.parse(File.read(File.join(domain_path, 'eval_tasks_v8.json')))
l6_task     = eval_tasks.find { |t| t['task_type'] == 'short_rule_induction' }
abort 'l6_induction_02 not found in eval_tasks_v8.json' unless l6_task

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
  parsed = begin
    JSON.parse(r['response_text'])
  rescue JSON::ParserError
    nil
  end
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
```

- [ ] **Step 2: v9c に対して実行し、結果を確認・記録する**

Run:
```bash
cd experiments/bloom_1n_vs_1on1
ruby scripts/rescore_l6.rb data/experiment_v9c.db b412cfdb-0522-4997-a47e-1738eb414f4b
```
Expected: `before` 列が全 condition で `0`（既存レポートの L6 = 0% と一致）、`after` 列で改善が見られる（新 alias がカバーする言い換えパターンの分だけ `answer_correct: true` に変わる）。`[changed]` 行が複数出力される。

- [ ] **Step 3: v8・v9b に対しても実行し、結果を記録する**

Run:
```bash
ruby scripts/rescore_l6.rb data/experiment_v8.db <v8_run_id>
ruby scripts/rescore_l6.rb data/experiment_v9b.db 772d2ce7-246a-467e-89ae-b63d02d39c85
```
（`<v8_run_id>` は `experiments/bloom_1n_vs_1on1/results/2026-05-29-v8-analysis.md` のメタデータ表に記載されている run_id を使う）
Expected: 同じ形式の比較表が出力される。v8/v9b でも `before` が低い値（exact-match artifact の影響）であることを確認し、`after` でどれだけ改善するかを記録する。

- [ ] **Step 4: コミットする**

```bash
git add experiments/bloom_1n_vs_1on1/scripts/rescore_l6.rb
git commit -m "feat(audit): add non-mutating L6 rescoring script for before/after comparison"
```

---

### Task 6: v9b・v9c の分析レポートに「方法論的注記」セクションを追記する

このタスクでは `lib/report.rb` の本体を変更しない（`experiment_meta` の再構築が複雑になりすぎるため）。代わりに、各 run ディレクトリに **addendum ファイル**を追加する方式を取る。

**Files:**
- Create: `experiments/bloom_1n_vs_1on1/results/2026-06-0X-v9c-methodology-addendum.md`
- Create: `experiments/bloom_1n_vs_1on1/results/2026-06-0X-v9b-methodology-addendum.md`

- [ ] **Step 1: v9c addendum を作成する**

以下の構成で書く（数値は Task 1, 2, 5 の実行結果で埋める。プレースホルダのまま残さない）：

```markdown
# v9c 方法論的注記アドエンダム（2026-06-0X）

run_id: b412cfdb-0522-4997-a47e-1738eb414f4b
対象レポート: 2026-06-06-v9c-full-analysis.md

## 1. L6 (short_rule_induction) 再採点結果

[Task 5 Step 2 の出力結果の表をそのまま転記]

旧 scorer は exact-match のみで、意味的に正しい言い換えをすべて 0 点にしていた
（lib/scorer.rb:25-29）。修正後の acceptable_aliases 適用で [after の値] / 34 まで改善。
レポート上の L6 = 0% は学習者の帰納能力の欠如ではなく、scorer の構造的バグによる
artifact である。

## 2. Pseudoreplication（独立反復数）

[Task 1 Step 2 の出力結果の表をそのまま転記]

全 discussion 条件で unique_discussions = 1。各 condition のスコアは
「N=1 の discussion に対する learner の反応の分散」であり、「discussion
デザインの効果の不確実性」ではない。レポート中の Std Dev / 95% CI に類する
記述は、条件効果の信頼区間としては読めない。

## 3. Confound チェック結果

[Task 2 Step 2 の出力結果の表をそのまま転記]

- learner profile: 4 種類混在を確認（誤って「全員同一型」と分析されていた外部メモを訂正）
- classroom_teacher / evaluator: ともに単一インスタンス。tutor 効果・judge variance を
  condition 効果と分離できない。
- lecture_only の learning_sessions 行数 = 0：discussion 相当の学習時間/トークンが
  与えられておらず、「同じ学習予算での比較」になっていない。

## 4. Discussion context injection（F3）

`lib/phases/sized_discussion.rb` の participant prompt には lesson も learner memory も
注入されていない（moderator にのみ渡る）。実 transcript で確認した結果、called_on された
learner の初発話は全 condition で「ルールを持っていない」という内容になっている
（例: "I don't have the Zarn token rules in front of me"）。
discussion 条件間の差は「協働的な知識構築の質の差」ではなく「忘却状態からの回復構造の差」
を測っていた可能性が高い。

## 5. 結論として何を main report の解釈に反映すべきか

- L6 のスコアは [新数値] として読み替える（0% は scorer artifact）
- 条件間の SD/CI は学習者個体差であり、条件効果の不確実性ではないため外部に引用しない
- discussion 条件間比較（pair > medium 等）は F3 の影響下にあり、教育法の効果として
  解釈できない
- readiness_failed はそのまま有効（このアドエンダムは readiness gate の評価には影響しない）
```

- [ ] **Step 2: v9b addendum を同じ構成で作成する**

Task 1 Step 3、Task 2 Step 3、Task 3、Task 5 Step 3 の結果を使って、同じ5節構成で
`2026-06-0X-v9b-methodology-addendum.md` を作成する。v9b には「Discussion context
injection」の節で「コードは v9c と同一構造であり、Task 3 の transcript 確認で
[結果] が確認された」という形で記述する。

- [ ] **Step 3: コミットする**

```bash
git add experiments/bloom_1n_vs_1on1/results/2026-06-0X-v9c-methodology-addendum.md \
        experiments/bloom_1n_vs_1on1/results/2026-06-0X-v9b-methodology-addendum.md
git commit -m "docs(v9b,v9c): add methodology addendum documenting F1-F5 audit + L6 rescore"
```

---

### Task 7: 外部メモ（masusanou ノート）の F5a 記述を訂正する

**Files:** ノート本体は本リポジトリ外（Obsidian vault）にあるため、ここでは訂正内容を
addendum 経由で示し、ユーザーに反映を依頼する形にする。直接 Obsidian ファイルを編集
できる場合は該当ノートの「致命的発見 5a」節を以下のように差し替える。

- [ ] **Step 1: 訂正文を作成する**

```markdown
### 致命的発見 5a（訂正版）: 学習者プロファイルは実際には4種類混在している

[訂正前の記述: 「34/34 全員が rule_extractor のみ」は誤り]

v9c 本番 run（b412cfdb-...）の `agents` テーブルを再集計した結果：
edge_case_dropper ×9, order_confused ×8, passive_listener ×8, rule_extractor ×9
の4種類が混在しており、レポートの「Score by Learner Type」表とも一致する。
おそらく config_v9c_smoke.yml（learner_types を2種類のみ設定）の DB を
本番 run と取り違えて集計したことによる誤りと推測される。

→ F5a は「学習者プロファイルの多様性」を巡る confound としては成立しない。
A4（learner profile 多様化）は v9c では既に実施済みであり、優先度を下げてよい。
```

- [ ] **Step 2: ユーザーに訂正の反映を依頼する旨を addendum に記載し、完了とする**

このタスクはコードへのコミットを伴わない。Task 6 の v9c addendum の末尾に
「外部ノートへの訂正依頼」として上記訂正文へのリンクを追記する。

---

## STEP 2: v4〜v8 — 同じ監査を適用し、再実験不要の修正を行って再出力

### Task 8: v8 / v7b / v7a / v6 / v5 / v4 の DB に対して `check_replication.py` と `check_confounds.py` を実行し、監査表を作成する

**Files:**
- Create: `experiments/bloom_1n_vs_1on1/results/2026-06-0X-v4-v9c-replication-confound-audit-table.md`

- [ ] **Step 1: 各バージョンの run_id を分析レポートのメタデータ表から収集する**

各 `results/2026-0X-vN-analysis.md` の冒頭付近にある `run_id:` フィールドを読み、
バージョンと DB ファイル名（`experiment.db` / `experiment_v8.db` / ...）の対応表を作る。
v4/v5/v6 が同じ `experiment.db` を共有しているか、別 DB かを `ls -la data/*.db` の
タイムスタンプと各レポートの実施日を突き合わせて確認する。

- [ ] **Step 2: 各 run に対して両スクリプトを実行する**

Run（バージョンの数だけ繰り返す。例として v8 を示す）:
```bash
cd experiments/bloom_1n_vs_1on1
python3 scripts/check_replication.py data/experiment_v8.db <v8_run_id>
python3 scripts/check_confounds.py   data/experiment_v8.db <v8_run_id>
```
Expected: 各バージョンで以下を記録する：
- `Phases::Classroom`/`WholeClassDiscussion`/`SmallGroupDiscussion`/`FlippedTutoring`/
  `Tutoring` の各条件で `unique_discussions` がいくつか（`Tutoring` は learner ごとに
  個別セッションのはずなので `unique_discussions = learner数` となり pseudoreplication
  は生じないはず — это が実際そうなっているかも確認する）
- `classroom_teacher`/`tutor`/`evaluator` の distinct instance 数
- learner profile の多様性（v5 は ability/misconception/interest 属性、v6 以降は
  `type_key` ベースの learner type — 形式が違うため出力をそのまま記録すればよい）

- [ ] **Step 3: 監査表を作成する**

`2026-06-0X-v4-v9c-replication-confound-audit-table.md` に、バージョンを行、
チェック項目（pseudoreplication 該当条件 / profile 多様性 / teacher 単一性 /
evaluator 単一性 / tutor 単一性）を列とした一覧表を作る。空欄を残さず、
Step 2 で得た実数を埋める。

- [ ] **Step 4: コミットする**

```bash
git add experiments/bloom_1n_vs_1on1/results/2026-06-0X-v4-v9c-replication-confound-audit-table.md
git commit -m "docs(audit): add replication/confound audit table across v4-v9c"
```

---

### Task 9: v8 の discussion フェーズにおける lesson 注入の非対称性（WCD vs SGD）を文書化する

**Files:** なし（調査と文書化のみ、Task 11 の addendum に反映）

- [ ] **Step 1: v8 の WCD と SGD の transcript を実際に確認する**

Run:
```bash
cd experiments/bloom_1n_vs_1on1/data
python3 -c "
import sqlite3, json
con = sqlite3.connect('experiment_v8.db')
con.row_factory = sqlite3.Row
rid = '<v8_run_id>'
rows = con.execute(\"SELECT condition, transcript_json FROM learning_sessions WHERE run_id=?\", (rid,)).fetchall()
seen = set()
for r in rows:
    if r['condition'] in seen:
        continue
    seen.add(r['condition'])
    turns = json.loads(r['transcript_json'])['turns']
    contributions = [t for t in turns if t.get('type') in ('contribution', 'response')]
    if contributions:
        print(r['condition'], '|', contributions[0]['content'][:160].replace(chr(10), ' '))
"
```
Expected: WCD（`whole_class_discussion` 系の条件名）の最初の発話に「ルールを知らない」
パターンが出るか、SGD（`small_group_discussion` 系）には出ないか、を確認する。コード上
の非対称（`whole_class_discussion.rb` は lesson 非注入、`small_group_discussion.rb` は
lesson 注入済み）が transcript の挙動に表れているかどうかの実証。

- [ ] **Step 2: 結果をメモに残す**

このステップにはコミット対象のファイル変更はない。WCD（v8 の最高スコア条件、83%）が
実は「lesson 非注入から moderator の reveal で回復する」構造だった場合、v8 の目玉結論
「WCD > 1on1 > only > SGD」の解釈に重大な疑問符がつくことを Task 11 の addendum に記す。

---

### Task 10: v4〜v7 の eval_tasks ファイルに F2 と同型の scorer artifact が無いか確認する

**Files:** なし（調査のみ）

- [ ] **Step 1: 各バージョンが使用した eval_tasks ファイルを特定する**

Run:
```bash
cd experiments/bloom_1n_vs_1on1
grep -n "eval_tasks_file" ../../config*.yml scripts/run_experiment*.rb
```
このセッションで判明済み: `run_experiment.rb`（v4-v6 系）、`run_experiment_a.rb`（v7a）、
`run_experiment_b.rb`（v7b）はいずれもデフォルト `eval_tasks_v4.json`。config で
override されていないか確認する。

- [ ] **Step 2: 自由記述形式（exact-match に弱い）タスクの有無を確認する**

Run:
```bash
python3 -c "
import json
for f in ['eval_tasks_v4.json']:
    d = json.load(open(f'domains/zarn_tokens/{f}'))
    for t in d:
        ans = t.get('expected_answer', '')
        if not ans.strip().lstrip('-').isdigit():
            print(f, t['id'], t['task_type'], repr(ans), t.get('acceptable_aliases'))
"
```
このセッションで確認済み: `eval_tasks_v4.json` の L6 task (`l6_induction_02`) は
`expected_answer` が数値（"11"）の計算問題形式であり、F2 の対象外。
出力が空であることを確認すれば、v4-v7 は F2 非該当と確定できる。

- [ ] **Step 3: 結果を記録する**

このステップにはコミット対象のファイル変更はない。「v4-v7 は F2 非該当（理由：L6 が
自由記述ではなく数値計算形式のため）」という結論を Task 11 の addendum に記す。

---

### Task 11: v4〜v8 の分析レポートに方法論的注記アドエンダムを追加する

**Files:**
- Create: `experiments/bloom_1n_vs_1on1/results/2026-06-0X-v4-v6-methodology-addendum.md`
- Create: `experiments/bloom_1n_vs_1on1/results/2026-06-0X-v7a-v7b-methodology-addendum.md`
- Create: `experiments/bloom_1n_vs_1on1/results/2026-06-0X-v8-methodology-addendum.md`

- [ ] **Step 1: v4-v6 addendum を作成する**

Task 8（監査表）と Task 10（scorer 確認）の結果を使い、以下の構成で書く：

```markdown
# v4-v6 方法論的注記アドエンダム（2026-06-0X）

対象: 2026-05-16-v4-analysis.md, 2026-05-17-v5-analysis.md, 2026-05-21-v6-analysis.md

## 1. F2 (scorer exact-match artifact): 非該当

eval_tasks_v4.json の L6 task は数値計算形式（expected_answer="11"）であり、
v8 系で確認された自由記述 exact-match の問題は生じない（Task 10 で確認）。

## 2. F4 (pseudoreplication)

[Task 8 の監査表から該当部分を転記。Phases::Classroom が学習者をまとめて1回
呼ぶ構造であるかどうか、実際の unique_discussions 数を記載]

## 3. F5 (confound)

[Task 8 の監査表から該当部分を転記。teacher/tutor/evaluator の instance 数、
learner profile の多様性]

## 4. 結論として何を main report の解釈に反映すべきか

[監査結果に応じて記述。例: 「F4 が確認された場合、v4-v6 の classroom 条件の
SD/CI も条件効果の不確実性としては読めない」等]
```

- [ ] **Step 2: v7a-v7b addendum を同じ構成で作成する**

`results/2026-05-23-v7a-analysis.md`、`2026-05-23-v7b-analysis.md` を対象に、
Task 8 の監査結果を反映して同様に作成する。

- [ ] **Step 3: v8 addendum を作成する**

Task 5 Step 3（L6 rescore 結果）、Task 8（監査表）、Task 9（WCD/SGD 非対称性）の
結果を統合して書く。特に Task 9 の結果は独立した節として明記する：

```markdown
## X. WCD/SGD の lesson 注入非対称性（v8 固有の confound）

whole_class_discussion.rb は participant prompt に lesson を注入しないが、
small_group_discussion.rb は注入する（コード上確認済み: lib/phases/whole_class_discussion.rb:40-41
vs lib/phases/small_group_discussion.rb:35-36）。transcript 確認の結果 [Task 9 の結果]。
これにより、v8 の目玉結論「WCD (83%) > 1on1 (78%) > only (70%) > SGD (68%)」のうち、
WCD と SGD の比較は「lesson へのアクセス可否が異なる条件同士の比較」になっており、
教育法そのものの比較として読めない可能性がある。
```

- [ ] **Step 4: コミットする**

```bash
git add experiments/bloom_1n_vs_1on1/results/2026-06-0X-v4-v6-methodology-addendum.md \
        experiments/bloom_1n_vs_1on1/results/2026-06-0X-v7a-v7b-methodology-addendum.md \
        experiments/bloom_1n_vs_1on1/results/2026-06-0X-v8-methodology-addendum.md
git commit -m "docs(v4-v8): add methodology addenda documenting audit findings per version"
```

---

## STEP 3: 再実験が必要な条件のリストアップ → 設計チェックリスト化

### Task 12: 「再実験でしか直せない」項目を STEP 1/2 の結果から集約する

**Files:** なし（集約のみ、Task 13 のインプット）

- [ ] **Step 1: STEP 1/2 で「addendum では救えなかった」項目を列挙する**

これまでのタスクで判明した、コード変更 + 再実行が必須な項目を以下の観点で
チェックリスト化する（各項目に「対象バージョン」「最小再現条件」を付す）：

1. **discussion participant への lesson/memory 注入**（F3 修正）
   - 対象: `Phases::SizedDiscussion`（v9b, v9c）, `Phases::WholeClassDiscussion`（v8 WCD）
   - 最小再現条件: 修正後、called_on learner の初発話が「ルールを前提とした」内容に
     変わることを 1 session の smoke で目視確認する必要がある → 再実行必須
2. **discussion の反復化**（F4 是正、N_disc ≥ 5）
   - 対象: `Phases::Classroom`/`WholeClassDiscussion`/`SmallGroupDiscussion`/
     `SizedDiscussion` を使う全バージョンの全 discussion/classroom 条件
     （Task 8 の監査表で `unique_discussions = 1` と判定された条件）
   - 最小再現条件: 同一 condition で discussion インスタンスを複数回走らせ、
     discussion-level mean を unit of analysis とする集計に変更する必要がある
     → コード変更 + 再実行必須（既存データの再集計では SE が定義できない）
3. **evaluator/moderator の triplication**（F5b 是正）
   - 対象: 全バージョン（Task 8 で単一インスタンスと判定されたもの）
   - 最小再現条件: 複数 evaluator インスタンスでの再評価が必須 → 再実行必須
4. **lecture_only の学習時間/トークン予算の公平性**（F5c 是正）
   - 対象: v9b, v9c（lecture_only に discussion 相当の self-study phase が無い）
   - 最小再現条件: self-study phase を新設するか token-cost-normalized score を
     主指標化するかの設計判断 + 再実行が必要
5. **v8 WCD/SGD の lesson 注入を統一する**（v8 固有の confound 是正）
   - 対象: v8 のみ
   - 最小再現条件: 両 discussion 形式で同じ情報アクセス構造に揃えてから再比較する
     必要がある → 再実行必須

- [ ] **Step 2: 各項目に概算トークンコストを付す**

v9c 本番 run の実測値（合計 631,955 トークン、うち discussion phase 比率 ~40%
= 約 253k トークン）を基準に、各項目の追加コストを見積もる：
- 項目1（context 注入修正）: 既存規模のまま再実行で足りる → 約 632k トークン
- 項目2（N_disc=5 化）: discussion phase ×5 倍 → +約 1.0M トークン（253k×4）
  → 合計で約 1.6M〜1.8M トークン規模
- 項目3（evaluator triplication）: evaluation phase ×3 倍
  （v9c の evaluation phase 実測 376,442 トークン）→ +約 750k トークン
- 項目4・5: 設計判断に依存するため、設計確定後に見積もる

このステップにはコミット対象のファイル変更はない。

---

### Task 13: `v9c2-design-checklist.md` を作成する

**Files:**
- Create: `docs/superpowers/plans/2026-06-0X-v9c2-design-checklist.md`

- [ ] **Step 1: チェックリスト文書を作成する**

以下の構成で書く（Task 12 の集約結果をそのまま反映する。プレースホルダを残さない）：

```markdown
# v9c2 設計チェックリスト

## 背景

v9c（run_id: b412cfdb-...）の独立監査により、5つの方法論的バグ・confound
（F1-F5、詳細は 2026-06-07-v9-and-earlier-methodology-remediation.md 参照）が
判明した。このうち F1（corrective_note 静的）と F2（L6 scorer artifact）は
addendum による再採点で対処済み。残る項目は構造的修正 + 再実行が必須であり、
v9c2 の設計に先行して解決すべき依存関係を持つ。

## 依存グラフ

A0 (discussion context injection 修正)
  ↓
A3 (N_disc ≥ 5 反復化、discussion-level 集計への変更)
  ↓
A4 (learner profile 多様化 — v9c は既に4型混在のため対応不要、確認のみ)
A5 (evaluator triplication)
A6 (lecture_only の学習時間公平性)
  ↓
新規研究条件（Hybrid lecture / ambiguity-of-call 等）

## 優先度付きチェックリスト

### P0: A0 — discussion participant context への lesson/memory 注入

- [ ] `lib/phases/sized_discussion.rb` の `contrib_prompt` の `context` に
      最新の learner memory（rules/examples/edge_cases/corrected_misconceptions）
      を注入する
- [ ] 修正後、1 session の smoke run で called_on learner の初発話が
      「ルールを前提とした」内容に変わることを目視確認する
- [ ] 同じ修正を `lib/phases/whole_class_discussion.rb` にも適用する
      （v8 由来の同型バグ）

見積もりトークン: 既存 v9c 規模で再実行可能 → 約 632k トークン

### P0: A3 — discussion の反復化（N_disc ≥ 5）

- [ ] 各 condition で discussion を独立に N_disc 回走らせる設計に変更する
- [ ] 集計の unit of analysis を「discussion-level mean」に変更し、
      learner は nested observation として扱う
- [ ] `lib/report.rb` の Score Variance セクションを discussion-level の
      SD/CI を計算する形に変更する

見積もりトークン: discussion phase ×5 → 既存 +約 1.0M トークン
（合計で約 1.6M〜1.8M トークン規模）

### P1: A5 — evaluator の triplication

- [ ] evaluator agent を3インスタンス化し、median score と
      agreement（Krippendorff's α か簡易一致率）をレポートに含める

見積もりトークン: evaluation phase ×3 → +約 750k トークン

### P1: A6 — lecture_only の学習時間公平性

- [ ] 設計判断: (a) token-budget 統制で self-study reflection phase を
      追加する／(b) token-cost-normalized score を主指標に格上げする
      のいずれかを選択する
- [ ] 選択した設計を反映し、報告セクションを更新する

見積もりトークン: 設計確定後に見積もる

### P2: 確認のみ（追加実装不要）

- [ ] A4: learner profile 多様化 — v9c は既に4型混在を確認済み
      （Task 2 の結果）。v9c2 でも同じ config 設定を維持すればよい

## 新 run 前のゲート条件

上記 P0 の A0・A3 が解決し、smoke run で動作確認が取れるまで、
v9c2 の本番 run には着手しない。これは F0（既存データ診断の固定化）
が完了済みであることが前提となる（本計画の STEP 1/2 が該当）。
```

- [ ] **Step 2: コミットする**

```bash
git add docs/superpowers/plans/2026-06-0X-v9c2-design-checklist.md
git commit -m "docs(v9c2): add design checklist with dependency graph and token-cost estimates"
```

---

## Self-Review チェック

- **F1〜F5 のカバレッジ**: F1→Task 6（addendum で文書化）、F2→Task 4・5（修正+再採点）、
  F3→Task 3・9（transcript 確認・文書化）、F4→Task 1・8（診断スクリプト・監査表）、
  F5a→Task 2・7（再確認・外部ノート訂正）、F5b→Task 2・8（診断）、F5c→Task 6・12
  （文書化・再実験リスト化）。すべてどこかのタスクで扱われている。
- **プレースホルダ排除**: 各 addendum テンプレートの `[Task X Step Y の出力結果...]` は
  「実行結果をそのまま転記する」という具体的な指示であり、空欄のまま提出してよい
  という意味ではない（Step の説明文で明記）。コード（スクリプト・テスト・JSON 修正）は
  すべて完全な内容を記載済み。
- **型・シグネチャの一貫性**: `Scorer.score_attempt(parsed_response, task)` の呼び出し
  シグネチャは Task 4（テスト）と Task 5（rescore script）で一致させてある。
  `check_replication.py` / `check_confounds.py` の CLI 引数 `<db_path> <run_id>` も
  Task 1/2/8 で一貫している。
