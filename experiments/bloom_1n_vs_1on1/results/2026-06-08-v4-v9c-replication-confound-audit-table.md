# v4–v9c 再現性・confound 監査表（2026-06-08）

`scripts/check_replication.py` と `scripts/check_confounds.py` を v4〜v9c の各 production run
に対して実行した結果の一覧。run_id とバージョン・DB の対応は以下の通り（各バージョンの
分析レポート冒頭の `run_id:` フィールドと `data/*.db` のテーブル内容を突き合わせて確認した）。

## run_id ↔ DB 対応表

| Version | DB ファイル | run_id |
|---------|------------|--------|
| v4 | `experiment.db`（共有） | `19b39e20-6901-4c90-8f3c-e24b352f23ae` |
| v5 | `experiment.db`（共有） | `02070b48-308f-4bf3-bac9-2cc76563ade9` |
| v6 | `experiment.db`（共有） | `cd5d2f0e-8036-41d6-b755-b6c6ba08ab3e` |
| v7a | `experiment_v7a.db` | `dd2fd888-0e7b-40a9-ad2a-abb6e9b8b6d1` |
| v7b | `experiment_v7b.db` | `32ffaa49-2d26-4edd-9cf8-ecdf1d019c78` |
| v8 | `experiment_v8.db` | `ef107ef9-bee8-420e-a94f-31aee4a56c37` |
| v9b | `experiment_v9b.db` | `772d2ce7-246a-467e-89ae-b63d02d39c85` |
| v9c | `experiment_v9c.db` | `b412cfdb-0522-4997-a47e-1738eb414f4b` |

`experiment.db` には v4・v5・v6 を含む計 10 種の run_id が記録されている（共有 DB）。
v7a 以降は専用 DB に分離されている。

## Pseudoreplication（条件別 sessions / unique_discussions）

| Version | Condition | sessions | unique_discussions | 判定 |
|---------|-----------|---------|---------------------|------|
| v4 | 1on1 | 4 | 4 | 反復あり（tutoring は learner 毎に個別セッション。期待通り） |
| v4 | classroom | 4 | 1 | **pseudoreplication**（discussion 実質1回） |
| v5 | 1on1 | 4 | 4 | 反復あり |
| v5 | heterogeneous_classroom | 4 | 1 | **pseudoreplication** |
| v5 | homogeneous_classroom | 4 | 1 | **pseudoreplication** |
| v6 | 1on1 | 4 | 4 | 反復あり |
| v6 | heterogeneous_classroom | 4 | 1 | **pseudoreplication** |
| v6 | homogeneous_classroom | 4 | 1 | **pseudoreplication** |
| v7a | classroom_forced_checkin | 4 | 1 | **pseudoreplication** |
| v7a | classroom_public_qa | 4 | 1 | **pseudoreplication** |
| v7a | one_on_one_tutoring | 4 | 4 | 反復あり |
| v7b | classroom_public_qa | 4 | 1 | **pseudoreplication** |
| v7b | generic_one_on_one_tutoring | 4 | 4 | 反復あり |
| v7b | procedure_scaffolded_one_on_one_tutoring | 4 | 4 | 反復あり |
| v8 | lecture_only | 4 | 1 | discussion 自体が無い条件（lesson のみ）。`unique_discussions=1` は固定レクチャーの再利用を反映しており、F4 の対象外 |
| v8 | lecture_plus_one_on_one_tutoring | 8 | 5 | **部分的 pseudoreplication**（8 セッション中 5 種類のユニーク transcript。完全な独立反復ではないが、classroom 条件ほど深刻ではない） |
| v8 | lecture_plus_small_group_discussion | 8 | 3 | **部分的 pseudoreplication**（8 セッション中 3 種類） |
| v8 | lecture_plus_whole_class_discussion | 8 | 2 | **部分的 pseudoreplication**（8 セッション中 2 種類） |
| v9b | （discussion 全条件） | 各2/4/8/16 | 各 1 | **pseudoreplication**（[[v9b-methodology-addendum]] 参照） |
| v9c | （discussion 全条件） | 各2/4/8/16 | 各 1 | **pseudoreplication**（[[v9c-methodology-addendum]] 参照） |

**観察:** classroom 系（一斉討論）条件は v4〜v9c を通じて一貫して `unique_discussions = 1`
であり、F4（pseudoreplication）は v4 から続く構造的な特徴である。一方 1on1/tutoring 系
条件は v4〜v7b では `unique_discussions = sessions数` で完全な反復が確保されている
（learner ごとに個別セッションが生成される設計のため）。v8 では「lecture_plus_*」の
discussion 条件が、v9b/v9c ほど極端ではないものの部分的な pseudoreplication を示して
おり、バージョンが進むにつれ「discussion を1回だけ生成して全 learner に共有する」
方向に構造が変化していった可能性がある。

## Confound（teacher / tutor / evaluator の単一性、learner profile 多様性）

| Version | classroom_teacher | tutor | evaluator | learner profile 多様性 |
|---------|------------------|-------|-----------|------------------------|
| v4 | 単一インスタンス | 単一インスタンス | 単一インスタンス | 1種類（プロファイル情報なし、`profile_json` が空） |
| v5 | 単一インスタンス | 単一インスタンス | 単一インスタンス | 5種類（ability/misconception/interest 属性ベース。例: medium×worked_examples×forgets_edge_cases ×6, none×3, high×abstract_rules×none ×2, low×simple_sequences×applies_modifiers_before_activation ×2, medium×worked_examples×thinks_blue_always_active ×2） |
| v6 | 単一インスタンス | 単一インスタンス | 単一インスタンス | 5種類（`type_key` ベース。edge_case_dropper ×6, (none) ×3, rule_extractor ×2, order_confused ×2, passive_listener ×2） |
| v7a | 単一インスタンス | 単一インスタンス | 単一インスタンス | 1種類（passive_listener ×12 のみ） |
| v7b | 単一インスタンス | 単一インスタンス | 単一インスタンス | 1種類（order_confused ×12 のみ） |
| v8 | 単一インスタンス | 単一インスタンス | 単一インスタンス | 4種類（rule_extractor / edge_case_dropper / order_confused / passive_listener 各 ×4） |
| v9b | 単一インスタンス | （tutor 役なし） | 単一インスタンス | 4種類（rule_extractor ×9, edge_case_dropper ×9, order_confused ×8, passive_listener ×8） |
| v9c | 単一インスタンス | （tutor 役なし） | 単一インスタンス | 4種類（v9b と同一分布） |

**観察:**
- **teacher / tutor / evaluator の単一インスタンス問題（F5b）は v4〜v9c の全 run に共通**。
  どのバージョンでも tutor の指導品質や judge の採点ぶれを condition 効果と統計的に
  分離できない。これは個別バージョンの欠陥ではなく、フレームワーク全体の構造的特徴で
  ある。
- **learner profile の多様性は v4・v7a・v7b で「単一プロファイル（または属性なし）」と
  なっている**。v4 はプロファイル情報自体が無い（`profile_json` が空）。v7a/v7b は
  「実験条件として意図的に単一の learner type に固定している」可能性が高い（v7a は
  passive_listener のみ、v7b は order_confused のみ — それぞれの実験が特定の学習者
  タイプに対する効果を見るデザインだったと推測される。これは confound ではなく
  デザイン上の選択である可能性があるため、各レポートの実験デザイン記述と突き合わせて
  判断する必要がある）。
- v5・v6 は「多様だが、各タイプの出現数が少なく、(none) という未分類カテゴリも
  混在する」という、やや中途半端な多様化状態にある。
- v8・v9b・v9c は 4 種類の learner type が均等に近い分布で混在しており、最も
  多様化が進んでいる。

## まとめ

| 監査項目 | v4 | v5 | v6 | v7a | v7b | v8 | v9b | v9c |
|---------|----|----|----|----|----|----|----|----|
| F4 (classroom 系 pseudoreplication) | ✓該当 | ✓該当 | ✓該当 | ✓該当 | ✓該当 | △部分的 | ✓該当 | ✓該当 |
| F5b (teacher/tutor/evaluator 単一性) | ✓該当 | ✓該当 | ✓該当 | ✓該当 | ✓該当 | ✓該当 | ✓該当（tutor無し） | ✓該当（tutor無し） |
| F5a (learner profile 多様性) | 単一/無 | 多様(5,やや疎) | 多様(5,やや疎) | 単一(意図的?) | 単一(意図的?) | 多様(4,均等) | 多様(4,均等) | 多様(4,均等) |

凡例: ✓該当=明確に確認、△部分的=程度が緩やかだが残存、単一/無=多様化なし
