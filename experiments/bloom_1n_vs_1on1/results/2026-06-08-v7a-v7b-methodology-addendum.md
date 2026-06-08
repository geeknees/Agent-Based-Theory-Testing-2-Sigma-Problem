# v7a-v7b 方法論的注記アドエンダム（2026-06-08）

対象: 2026-05-23-v7a-analysis.md, 2026-05-23-v7b-analysis.md
（[[v4-v9c-replication-confound-audit-table]] のデータに基づく）

| Version | DB | run_id |
|---------|----|--------|
| v7a | `experiment_v7a.db` | `dd2fd888-0e7b-40a9-ad2a-abb6e9b8b6d1` |
| v7b | `experiment_v7b.db` | `32ffaa49-2d26-4edd-9cf8-ecdf1d019c78` |

## 1. F2 (scorer exact-match artifact): 非該当

`run_experiment_a.rb`（v7a）・`run_experiment_b.rb`（v7b）はいずれも `eval_tasks_file` を
`eval_tasks_v4.json` に固定しており（`config_v7a*.yml` / `config_v7b*.yml` でも override
されていない）、当該ファイルの全タスクの `expected_answer` は数値文字列である
（`l6_induction_02` も `expected_answer = "11"`）。v8 系で確認された自由記述
exact-match の問題は v7a・v7b には存在しない（Task 10 で確認、[[v4-v6-methodology-addendum]]
セクション 1 と同一の結論）。

→ **F2 は v7a・v7b に非該当。**

## 2. F4 (pseudoreplication)

`scripts/check_replication.py` の出力（[[v4-v9c-replication-confound-audit-table]] より転記）：

| Version | Condition | sessions | unique_discussions | 判定 |
|---------|-----------|---------|---------------------|------|
| v7a | classroom_forced_checkin | 4 | 1 | **pseudoreplication** |
| v7a | classroom_public_qa | 4 | 1 | **pseudoreplication** |
| v7a | one_on_one_tutoring | 4 | 4 | 反復あり |
| v7b | classroom_public_qa | 4 | 1 | **pseudoreplication** |
| v7b | generic_one_on_one_tutoring | 4 | 4 | 反復あり |
| v7b | procedure_scaffolded_one_on_one_tutoring | 4 | 4 | 反復あり |

v4-v6 と同型のパターンが観測された：classroom 系条件（`classroom_forced_checkin`,
`classroom_public_qa`）は `unique_discussions = 1` で pseudoreplication が確認され、
tutoring 系条件（`one_on_one_tutoring`, `generic_one_on_one_tutoring`,
`procedure_scaffolded_one_on_one_tutoring`）は `unique_discussions = sessions数` で
完全な反復が確保されている。

→ **classroom_forced_checkin と classroom_public_qa（v7a）、classroom_public_qa（v7b）
の SD/CI は教育法デザインの効果に関する不確実性としては読めない**（[[v4-v6-methodology-addendum]]
セクション 2 と同一の論点）。tutoring 系3条件は独立反復に基づくため、この限りではない。

## 3. F5 (confound)

`scripts/check_confounds.py` の出力（[[v4-v9c-replication-confound-audit-table]] より転記）：

| Version | classroom_teacher | tutor | evaluator | learner profile 多様性 |
|---------|------------------|-------|-----------|------------------------|
| v7a | 単一 | 単一 | 単一 | 1種類のみ（passive_listener ×12） |
| v7b | 単一 | 単一 | 単一 | 1種類のみ（order_confused ×12） |

- **F5b（teacher/tutor/evaluator 単一インスタンス）は v7a・v7b にも該当**。
  v4-v6・v8・v9b・v9c と同じくフレームワーク全体の構造的特徴である
  （[[v4-v9c-replication-confound-audit-table]] まとめ表参照）。
- **learner profile**: v7a は全学習者が `passive_listener`、v7b は全学習者が
  `order_confused` という、それぞれ単一タイプに統一された集団になっている。
  これは v4 のような「プロファイル情報の欠落」とは異なり、`type_key` が明示的に
  設定された上での均質化である。各レポートの冒頭を確認したところ、これは
  **意図的な実験デザイン上の選択**であることが明記されている：
  - v7a（`実験バージョン: bloom_v7a_passive_listener_rescue`）冒頭:
    「条件: n=4/条件、全学習者 passive_listener 型」── v6 で passive_listener が
    hetero_classroom より 1on1 で高スコアだった差の要因（強制的インタラクション vs
    パーソナライゼーション）を切り分ける目的。
  - v7b（`実験バージョン: bloom_v7b_order_confused_intervention`）冒頭:
    「条件: n=4/条件、全学習者 order_confused 型」── v6 で order_confused が
    hetero_classroom より 1on1 で低スコアだった差の要因（介入の不一致仮説）を
    検証する目的。

  → これは confound ではなく、両レポートが既に明記している通りの**意図的な
  単一学習者タイプへの絞り込み**である。両レポートの結論は最初から
  「passive_listener 型に対する知見」「order_confused 型に対する知見」として
  スコープされており、学習者一般への外挿を主張していない。この点について
  追加の訂正は不要である。

## 4. 結論として何を main report の解釈に反映すべきか

- **F2 は非該当**であり、L6 を含む全タスクのスコアはそのまま信頼できる。
- F4（pseudoreplication）が classroom 系条件に確認されたため、これらの条件の
  SD/CI を条件間比較の統計的根拠として引用しない。tutoring 系条件の分散は
  独立反復に基づくため、この限りではない。
- F5b（teacher/tutor/evaluator 単一性）により、教育法効果と tutor/judge の
  個体差を分離できない。
- learner profile が単一タイプに統一されている点は **confound ではなく意図的な
  実験デザイン**であり、両レポートとも「passive_listener（v7a）/ order_confused
  （v7b）型の学習者に対する知見」として既にスコープを明記している。この点に
  ついて追加の訂正は不要である。
