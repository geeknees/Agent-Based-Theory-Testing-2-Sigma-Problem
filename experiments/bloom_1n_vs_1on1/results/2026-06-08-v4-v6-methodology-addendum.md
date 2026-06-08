# v4-v6 方法論的注記アドエンダム（2026-06-08）

対象: 2026-05-16-v4-analysis.md, 2026-05-17-v5-analysis.md, 2026-05-21-v6-analysis.md
（[[v4-v9c-replication-confound-audit-table]] のデータに基づく）

run_id ↔ DB 対応（v4/v5/v6 はいずれも `experiment.db` を共有）：

| Version | run_id |
|---------|--------|
| v4 | `19b39e20-6901-4c90-8f3c-e24b352f23ae` |
| v5 | `02070b48-308f-4bf3-bac9-2cc76563ade9` |
| v6 | `cd5d2f0e-8036-41d6-b755-b6c6ba08ab3e` |

## 1. F2 (scorer exact-match artifact): 非該当

`run_experiment.rb`（v4-v6 系）は `eval_tasks_file` を `eval_tasks_v4.json` に固定しており
（`config.yml` / `config_smoke.yml` でも override されていない）、`eval_tasks_v4.json`
の8タスク全ての `expected_answer` は数値文字列である（`l6_induction_02` も
`expected_answer = "11"` という計算問題形式）。v8 系（`eval_tasks_v8.json`）で
確認された「自由記述の言い換えを exact-match で 0 点にする」という F2 のパターンは、
そもそも自由記述タスクが存在しないため発生し得ない（Task 10 で確認）。

→ **F2 は v4-v6 に非該当。L6 を含む全タスクのスコアは scorer artifact の影響を受けない。**

## 2. F4 (pseudoreplication)

`scripts/check_replication.py` の出力（[[v4-v9c-replication-confound-audit-table]] より転記）：

| Version | Condition | sessions | unique_discussions | 判定 |
|---------|-----------|---------|---------------------|------|
| v4 | 1on1 | 4 | 4 | 反復あり |
| v4 | classroom | 4 | 1 | **pseudoreplication** |
| v5 | 1on1 | 4 | 4 | 反復あり |
| v5 | heterogeneous_classroom | 4 | 1 | **pseudoreplication** |
| v5 | homogeneous_classroom | 4 | 1 | **pseudoreplication** |
| v6 | 1on1 | 4 | 4 | 反復あり |
| v6 | heterogeneous_classroom | 4 | 1 | **pseudoreplication** |
| v6 | homogeneous_classroom | 4 | 1 | **pseudoreplication** |

`Phases::Classroom`（一斉討論型の条件）は、v4-v6 を通じて学習者をまとめて1回の discussion
に参加させる構造になっており、`unique_discussions = 1` が一貫して観測された。一方
`1on1`（チュータリング型）は learner ごとに個別セッションが生成されるため
`unique_discussions = sessions数` で完全な反復が確保されている（pseudoreplication
は生じない）。

→ **classroom 系条件（classroom / heterogeneous_classroom / homogeneous_classroom）の
SD・CI に類する記述は、「N=1 の discussion に対する learner 反応の分散」であり、
「教育法デザインの効果に関する不確実性」としては読めない**（[[v9c-methodology-addendum]]
セクション 2 と同型の問題）。これに対し `1on1` 条件の分散は、独立反復された
セッション間のばらつきとして読んでよい——v4-v6 における classroom と 1on1 の
比較は、この点で非対称な統計的信頼性の上に成り立っている。

## 3. F5 (confound)

`scripts/check_confounds.py` の出力（[[v4-v9c-replication-confound-audit-table]] より転記）：

| Version | classroom_teacher | tutor | evaluator | learner profile 多様性 |
|---------|------------------|-------|-----------|------------------------|
| v4 | 単一 | 単一 | 単一 | 1種類（`profile_json` が空。プロファイル情報なし） |
| v5 | 単一 | 単一 | 単一 | 5種類（ability/misconception/interest 属性。medium×worked_examples×forgets_edge_cases ×6, (none) ×3, high×abstract_rules×none ×2, low×simple_sequences×applies_modifiers_before_activation ×2, medium×worked_examples×thinks_blue_always_active ×2） |
| v6 | 単一 | 単一 | 単一 | 5種類（`type_key` ベース。edge_case_dropper ×6, (none) ×3, rule_extractor ×2, order_confused ×2, passive_listener ×2） |

- **F5b（teacher/tutor/evaluator 単一インスタンス）は v4-v6 すべてに該当**。
  tutor の指導品質ぶれや judge の採点ぶれと、condition による効果を統計的に
  分離できない。これは v9b/v9c 含む全バージョンに共通する、フレームワーク全体の
  構造的特徴である（[[v4-v9c-replication-confound-audit-table]] まとめ表参照）。
- **learner profile**: v4 はプロファイル情報が存在しない（属性なしの均質集団として
  扱われている）。v5・v6 は5種類のプロファイルが混在しているが、各タイプの出現数が
  少なく `(none)`（未分類）も3件混在しており、v8/v9b/v9c ほど整理された多様化には
  なっていない。v5 から v6 にかけて、属性ベース（ability/misconception/interest の
  組み合わせ）から `type_key` ベースの分類方式へ移行した形跡が見られる。

## 4. 結論として何を main report の解釈に反映すべきか

- **F2 は非該当**であり、L6 を含む全タスクのスコアはそのまま信頼できる
  （scorer artifact による下方バイアスは存在しない）。
- F4（pseudoreplication）が classroom 系条件に確認されたため、これらの条件の
  SD/CI を「教育法 X は教育法 Y より優れている」という主張の統計的根拠として
  引用しない。1on1 条件の分散は独立反復に基づくため、この限りではない。
- F5b（teacher/tutor/evaluator 単一性）により、教育法の効果と tutor/judge の
  個体差を分離できない。「classroom は 1on1 より効果的」あるいはその逆という
  結論は、単一の教師・単一の評価者による偏りを内包している可能性がある。
- v4 はプロファイル情報が存在しないため、学習者多様性に関する分析（学習者
  タイプ別のスコア比較等）は行えない。v5・v6 のプロファイル多様性は限定的
  （疎な分布、未分類カテゴリの混在）であるため、学習者タイプ別の知見は
  探索的なものとして扱うべきである。
