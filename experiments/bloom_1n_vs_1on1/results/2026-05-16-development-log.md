# 開発上の問題と解決記録

v1 から v4 に至るまでに直面した技術的・実験設計上の問題と、それぞれの解決策を記録する。

---

## 問題 1：天井効果（Ceiling Effect）— v1, v2

### 症状

v1 初回実験で全12試行が 20/20 満点。条件間の差がゼロ。

```
classroom: avg 20.00
tutoring:  avg 20.00
```

### 原因

> **【2026-09-22 セルフ査読で訂正】** 本節は当初、v1 の天井を「評価プロンプトへのルール埋め込み」に
> 帰していたが、一次資料と矛盾する。v1 の `eval_tasks.json` のタスク文にルールは無く、v1 の solver
> プロンプト(git `dbfb948`)にも無い。solver フェーズ(git `8e48630`)は memory とタスク文だけを渡す。
> **v1 の実際の機構は、メモリ語数制限が無かったこと**(`max_memory_words` は v2 で導入)により、
> 教師の講義 → トランスクリプト → 無制限メモリという経路でメモリがルールブックをほぼ逐語で
> 保持していたことである(DB の v1 `memory_json` で確認)。加えて no_education ベースラインが無かった。
> **評価プロンプトへのルール逐語埋め込みは v2 の `eval_tasks_v2.json` から**であり、下に引用する例も
> v2 の `l1_recall_01` と一致する。論文 §4.2 は 2026-07-19 に両経路を区別する形へ修正済み。
> 詳細は `results/reviews/REVIEW-v1-v3.md` 所見3。

以下は **v2** で評価プロンプトにルールをそのまま埋め込んでいた例である。

```
Rules:
- Red: modifier only (0 pts), doubles the token immediately to its right.
- Blue: active (5 pts) only if Green appears somewhere to its left; else 0.
...

Calculate the score for: [Green, Blue, Yellow]
```

これは「記憶して応用するタスク」ではなく「**読んで応用するタスク**」になっており、教育フェーズの効果が完全にマスクされていた。

### v2 での試み（不十分）

L1〜L6 の難易度ラダーを設計し、タスクを硬くした。しかしプロンプトにルールが含まれたままだったため、v2 でも Sonnet 4.6 は全タスク 100% 正答を継続した。

### v3 での根本解決

**`learner_prompt`（ルールなし）と `hidden_rules`（採点専用）を分離。**

```json
{
  "learner_prompt": "Calculate the final score for: [Green, Blue, Yellow]\nUse only your memory of the rules...",
  "hidden_rules": "Red=modifier(0pts,doubles next). Blue=active(5pts) only if Green to left...",
  "expected_answer": "14"
}
```

solver.rb もそれに合わせて変更：

```ruby
# v2 (wrong)
instruction: task['prompt']

# v3 (correct)
instruction: task['learner_prompt']
```

これにより v3 スモークテスト（n=1）で no_education が低水準、classroom/tutoring が 13〜50% という有意義な分散が初めて観測された。

> **【2026-09-22 セルフ査読で訂正】** 旧版は v3 スモークの no_education を「0%」としていたが、
> DB 実測は **13%(1/8)** である。唯一の正答は、後に無効と判明する counterexample 形式の L5 で、
> 主張の構造に対する純粋な論理的推論だけで真偽を判定でき、ドメインのルール知識を必要としなかった。
> そのため本番 run ではすべて debugging 形式の L5 に差し替えている。
> 本番 run(v4 以降)の no_education は DB 上すべて 0% である。
> 論文 §5 は 2026-07-19 に "0% in every production run (v4 onward)" へ限定済み。
> 詳細は `results/reviews/REVIEW-v1-v3.md` 所見1。

---

## 問題 2：DB JOIN がゼロ行を返す — v3

### 症状

v3 初回実行後、`scores.csv` のヘッダー行のみで中身が空。`report.md` も全 0%。

```csv
learner_id,condition,task_id,...
(データなし)
```

### 原因

`evaluation_tasks` テーブルが `task_id` を PRIMARY KEY として持ち、`INSERT OR IGNORE` を使っていた。

```sql
-- 1回目の run_id: abc で挿入
INSERT OR IGNORE INTO evaluation_tasks (id, ...) VALUES ('l1_recall_01', 'abc', ...)

-- 2回目の run_id: def では同じ task_id が PRIMARY KEY で衝突 → 無視される
INSERT OR IGNORE INTO evaluation_tasks (id, ...) VALUES ('l1_recall_01', 'def', ...)
-- → 挿入されない！ evaluation_tasks に run_id=def の行がない
```

クエリが `JOIN evaluation_tasks et ON et.id = ta.task_id AND et.run_id = ta.run_id` だったため、2回目以降の run では JOIN が常に空になった。

### 解決

JOIN 条件から `et.run_id = ta.run_id` を削除。タスク内容は run 間で不変なため問題なし。

```ruby
# 修正前（db.rb）
JOIN evaluation_tasks et ON et.id = ta.task_id AND et.run_id = ta.run_id

# 修正後
JOIN evaluation_tasks et ON et.id = ta.task_id
```

**教訓**: PRIMARY KEY が run をまたいで共有されるリソース（今回は eval tasks）を持つ場合、JOIN 条件に `run_id` を含めるのは誤り。

---

## 問題 3：run_tests.sh の bash/zsh 非互換 — v1

### 症状

```
bash experiments/bloom_1n_vs_1on1/tests/run_tests.sh
# → 何も出力されずに exit 2
```

### 原因

シェバン `#!/usr/bin/env bash` にもかかわらず、`eval "$(mise activate zsh)"` を呼んでいた。

`mise activate zsh` は zsh 専用のコード（`typeset -ag`、`${precmd_functions:#...}` など）を出力する。bash で `set -euo pipefail` と組み合わせると、未定義変数展開でシェルが即死する。

### 解決

```bash
# 修正前
eval "$(mise activate zsh)" 2>/dev/null || true

# 修正後
eval "$(mise activate bash)" 2>/dev/null || true
```

**教訓**: シェバンとシェルアクティベーションのターゲットシェルを必ず合わせる。

---

## 問題 4：タスク設計の妥当性問題

### 問題 4-A：L5 counterexample がドメイン知識なしで解ける

**症状**: v3 スモークテストで no_education（教育なし）の学習者が L5 counterexample を 100% 正答。

**原因**: 設問が「Greenが末尾でなければ全Blueが active である」という主張の反例を求めるものだったが、これは**ルールを知らなくても**「Green の前にある Blue は Green を左に持たない」という純粋論理で解ける。

**解決**: L5 を domain-knowledge 依存の debugging タスクに置き換え。

```
[Red, Green, Blue, Green] で学生が "Score = 0 + 2 + 10 + 2 = 14" と回答。
全ての誤りを見つけ、正しいスコアを答えよ。
```

正解は 9。ミスは「Red が Green を2倍にするのに Blue を2倍と誤解」「末尾 Green を 0 でなく 2 と計上」の2点。これはルール知識なしには解けない。

### 問題 4-B：L6 が全条件 0%（too_hard）

**症状**: v3 で L6 `[Yellow, Orange, Blue, Green]` が全条件 0%。情報量ゼロ。

**原因**: 新ルール（Orange）+ Blue activation ルール + Green 末尾ルール を同時適用する必要があり、3ルール同時は memory-only 条件では難しすぎた。

**解決**: シーケンスを `[Yellow, Orange, Green]` に簡略化。Blue を除くことで Orange ルール + Green 末尾ルールの2ルールのみに。

**教訓**: too_hard なタスクは「どちらの条件も差なし = 0点」となり、実験の情報量に貢献しない。難易度は「教育あれば解ける、教育なしでは解けない」水準に調整する必要がある。

---

## 問題 5：トークンレート制限 — v4 本番実行

### 症状

n=6/6/4（合計 LLM 呼び出し約 194 回）でフル実験を実行すると、tutoring 途中で繰り返し失敗。

```
LLM call failed (exit 1):  (RuntimeError)
```

### 原因の特定過程

**第1段階**: `claude --print` が exit 1 で失敗。stderr は空。最初は一時的な API エラーと判断。

**第2段階**: リトライ間隔（10s/20s）を設けたが3回連続失敗。1分では回復しないことが判明。

**第3段階**: ユーザーから「5時間で回復する」という情報。トークン消費量（TPM）レート制限であることが確定。

**第4段階**: n を 4/4/3 に削減（194→134 呼び出し）、インターコール pause を 8s に増加。しかし依然として失敗。

**最終解決**: LLM.call を rate limit aware なリトライ機構に変更。

```ruby
MAX_RETRIES      = 20     # 複数 rate limit に対応
RATE_LIMIT_WAIT  = 19800  # 5.5時間（rate limit ウィンドウより長め）
INTER_CALL_PAUSE = 2      # 呼び出し間の基本 pause

rescue RuntimeError => e
  if attempts < MAX_RETRIES
    reset_at = Time.now + RATE_LIMIT_WAIT
    $stderr.puts "[LLM] Token rate limit hit. Waiting #{RATE_LIMIT_WAIT / 3600.0}h for reset"
    sleep RATE_LIMIT_WAIT  # 5.5時間待機して自動再開
    retry
  end
  raise
end
```

これにより実験プロセスをバックグラウンドで走らせ続け、rate limit に当たるたびに自動で 5.5h 待機→再開する「自己回復実験プロセス」が実現した。

### 追加の複雑性：macOS スリープとの相互作用

Ruby の `sleep(19800)` はシステムスリープ中にカウントが止まる。Mac がスリープしていた時間は rate limit wait に算入されない。

- rate limit sleep 開始: 07:47 JST
- 期待再開: 13:17 JST（5.5h後）
- 実際の再開: 19:00 頃（追加 5〜6h のシステムスリープ分）

ユーザーが「スリープ防止している」と確認後も、過去のスリープ累積分が残っていたため、実際の待機は計算より長くなった。

**結果**: 実験は約 21 時間かけて完走（うち 2 回の rate limit wait × 約 5.5h = 約 11h を rate limit 待機に費やした）。

---

## 問題 6：tutoring の feedback loop の欠如 — v3→v4

### 症状

v3 スモークテストで tutoring（2 exchange）が classroom（1:N授業）を下回る結果。

### 原因分析

v3 の tutoring は：
1. Tutor がトピック紹介（opener）
2. Learner が反応
3. Tutor が診断問題を出す
4. Learner が答える　← **セッション終了**

Tutor は Exchange 2 で学習者の誤答を観察できるが、**それを修正するチャンスがない**。Bloom が指摘した 1on1 tutoring の強みは「フィードバック → 学習者の修正 → 再確認」のループにあるが、v3 にはこのループが存在しなかった。

### v4 での解決

2 exchange（4ターン）から 4 exchange（8ターン）に拡張：

| Exchange | Tutor | Learner |
|----------|-------|---------|
| 1 | 概念説明 | 反応・質問 |
| 2 | 診断問題 Q1 | 答え |
| **3 (新規)** | **フィードバック・誤り修正** | **反省・理解確認** |
| **4 (新規)** | **2回目の診断問題 Q2** | **修正後の答え** |

これにより Bloom 型のフィードバックループが実装された。ただし最終結果では classroom > tutoring が継続しており、さらなる実装改善（mastery criterion など）が必要であることが示唆された。

---

## 問題 7：実験の再実行可能性

### 症状

rate limit で途中失敗した実験（run_id: 896509b5）は phases 1-3 が完了していたが、DB に memories が保存されているにもかかわらず、再実行すると全フェーズを最初からやり直す必要があった。

### 原因

オーケストレーター（`run_experiment.rb`）は各実行で新しい `run_id` を生成し、前の実行の途中状態を引き継ぐ機能がなかった。

### 現時点での対応

**実装しなかった理由**: resume 機能は複雑で、今回の探索的実験では完了するまで retry する方が合理的と判断。代わりに：

1. rate limit に強い LLM wrapper（5.5h 自動待機）
2. MAX_RETRIES=20 で長期実行に対応

**将来の改善案**: 
```ruby
# 将来実装するとしたら
def phase_completed?(db, run_id, phase)
  case phase
  when :education then db.execute('SELECT COUNT(*) FROM learning_sessions WHERE run_id=?', [run_id]).first.first > 0
  when :memory    then db.execute('SELECT COUNT(*) FROM learner_memories WHERE run_id=?', [run_id]).first.first > 0
  when :solving   then db.execute('SELECT COUNT(*) FROM task_attempts WHERE run_id=?', [run_id]).first.first > 0
  end
end

# 完了済みフェーズをスキップ
run_education(db, run_id, config) unless phase_completed?(db, run_id, :education)
```

---

## 問題 8：並列実験の DB 競合リスク

### 症状

rate limit で失敗した実験のプロセスが `sleep(19800)` 中に次の実験を誤って起動してしまい、2つの実験が同時に動作する状態になった。

### 原因

バックグラウンドプロセスが `sleep` 中に外部からは「止まっている」ように見えた。実際には `kill -0 PID` で生存確認できた。

### 解決

`kill -0 56669` でプロセス確認を習慣化。2つの実験が同時動作しても、それぞれ別の `run_id` で DB に書き込むため直接的な競合はなかったが、rate limit 消費が2倍になるリスクがあった。

---

## まとめ：問題カテゴリ別の教訓

### 実験設計

| 問題 | 教訓 |
|------|------|
| ルール埋め込みによる天井効果 | 評価プロンプトと採点情報を分離する。learner には memory だけを渡す |
| too_hard タスク | 全条件 0% のタスクは情報量ゼロ。「教育あれば解ける」水準に調整 |
| too_easy タスク（counterexample） | ドメイン知識なしで解ける問題は実験測定として無効 |
| tutoring の feedback loop 欠如 | Bloom の核心はフィードバックループ。実装に明示的に含める必要がある |

### データエンジニアリング

| 問題 | 教訓 |
|------|------|
| DB JOIN での run_id 混在 | 複数 run で共有される PRIMARY KEY を持つテーブルは JOIN 条件に run_id を含めない |
| 実験の再現性 | resume 機能がないと rate limit で失った作業がすべてやり直しになる |

### インフラ・実行環境

| 問題 | 教訓 |
|------|------|
| bash/zsh 非互換 | シェバンとシェルアクティベーションのターゲットを必ず合わせる |
| TPM レート制限 | n を増やすと急速にレート制限に達する。実験設計時にトークン数の見積もりが必要 |
| macOS スリープと sleep() | `sleep(n)` はシステムスリープ中にカウントが止まる。caffeinate の使用または sleep ではなく Time.now ベースのポーリングに変更すべき |

---

*記録日: 2026-05-16*  
*対象バージョン: v1〜v4*
