# v4–v9c2 再現性・confound 監査表（2026-06-08、2026-09-12 更新）

> **2026-09-12 セルフ査読での更新:** 初版は **v4〜v9c** のみを対象としていたため、
> **本監査の指摘を是正するために実施された v9c2 と ablation が含まれていなかった**。
> その結果「まとめ」表は F4 を全世代で該当と記録したまま終わっており、
> **是正されたことがどこにも記録されていない**状態だった。本版で v9c2・ablation を追加し、
> あわせて v8 の F4 集計・F5a の種類数・run_id 件数を修正した（変更箇所は各節に注記）。

`scripts/check_replication.py` と `scripts/check_confounds.py` を v4〜v9c2 の各 production run
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
| **v9c2** | `experiment_v9c2.db` | `dc1bdd27-6ae0-46be-be74-fc8a974bb328` |
| **ablation (n_disc=1)** | **DB 紛失**（run report で代替） | `a551c74d-aaed-498f-82cb-188b610380a8` |

> **スモーク run との取り違えに注意:** 本リポジトリには各世代のスモークテスト DB が同じ命名規則で
> 並んでいる（`experiment_v9c_smoke.db` / `experiment_v9c2_smoke.db` 等）。v9c2 分析レポート §2.1 は
> 「v9c の値」として**自身のスモーク run の値**を引用していた（v9c2 セルフ査読 所見1、修正済み）。
> **世代間比較の数値を引用する際は、上表の run_id で照合すること。**〔2026-09-12 追記〕

`experiment.db` には v4・v5・v6 を含む計 **17 種**の run_id が記録されている（共有 DB。内訳: v1 ×2、v2 ×1、v3 ×3、v4 ×8、v5 ×2、v6 ×1）。〔2026-09-12 セルフ査読で「計 10 種」から修正〕
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
| v8 | lecture_plus_one_on_one_tutoring | 8（うち Phase3 = 4） | 5（うち **Phase3 = 4**） | **反復あり**（Phase 3 は 4/4 で完全独立） |
| v8 | lecture_plus_small_group_discussion | 8（うち Phase3 = 4） | 3（うち **Phase3 = 2**） | **部分的 pseudoreplication**（Phase 3 は 2/4） |
| v8 | lecture_plus_whole_class_discussion | 8（うち Phase3 = 4） | 2（うち **Phase3 = 1**） | **pseudoreplication**（Phase 3 は 1/4。v4〜v7 の classroom と同一の深刻度） |

> **〔2026-09-12 セルフ査読で修正〕** 旧版は v8 を「8/5・8/3・8/2、3条件とも**部分的**、classroom 条件ほど
> 深刻ではない」と記録していたが、この分母 8 には **全条件に共通の Phase 1 前提講義（4 行複製）が
> 混入**している。`check_replication.py` は `learning_sessions` をフェーズ区別なく md5 でユニーク化する
> ため、全条件に一律で加わる講義の 4/1 が 3 条件の差を圧縮していた。
> 操作変数である Phase 3 だけで数えると **WCD 1/4・SGD 2/4・1on1 4/4** であり、
> **WCD は「部分的」ではなく v4〜v7 の classroom と同一**、逆に **1on1 は完全反復**である。
| v9b | （discussion 全条件） | 各2/4/8/16 | 各 1 | **pseudoreplication**（[[v9b-methodology-addendum]] 参照） |
| v9c | （discussion 全条件） | 各2/4/8/16 | 各 1 | **pseudoreplication**（[[v9c-methodology-addendum]] 参照） |
| **v9c2** | pair / small / medium / large | 10 / 20 / 40 / 80 | **各 5** | **解消**（A3 population-multiplication。`check_replication.py` 再実行で確認） |
| **v9c2** | lecture_only（= lecture_plus_self_reflection） | 4 | 4 | 該当せず（個人内省のため learner ごとに独立） |
| **ablation (n_disc=1)** | discussion 全条件 | 2/4/8/16 | 各 1 | **意図的に v9c 相当へ戻した arm**（DB 紛失のため run report より） |

**観察:** classroom 系（一斉討論）条件は v4〜v9c を通じて一貫して `unique_discussions = 1`
であり、F4（pseudoreplication）は v4 から続く構造的な特徴である。一方 1on1/tutoring 系
条件は v4〜v7b では `unique_discussions = sessions数` で完全な反復が確保されている
（learner ごとに個別セッションが生成される設計のため）。v8 では「lecture_plus_*」の
discussion 条件が、discussion 条件で
**既に WCD が 1/4**（v4〜v7 の classroom と同一）であり、1on1 系のみが完全反復を保っていた。
〔2026-09-12 修正: 旧版は「v9b/v9c ほど極端ではないものの部分的」「バージョンが進むにつれ
discussion を1回だけ生成する方向に構造が変化していった可能性がある」と記述していたが、
フェーズ分離後の実測ではその変化は v8 の時点で既に生じている。〕
**なお v9c2（A3 適用）で全 discussion 条件が unique = 5 となり、F4 は解消した。**

## Confound（teacher / tutor / evaluator の単一性、learner profile 多様性）

| Version | classroom_teacher | tutor | evaluator | learner profile 多様性 |
|---------|------------------|-------|-----------|------------------------|
| v4 | 単一インスタンス | 単一インスタンス | 単一インスタンス | 1種類（プロファイル情報なし、`profile_json` が空） |
| v5 | 単一インスタンス | 単一インスタンス | 単一インスタンス | **4種類**（ability/misconception/interest 属性ベース。medium×worked_examples×forgets_edge_cases ×6, high×abstract_rules×none ×2, low×simple_sequences×applies_modifiers_before_activation ×2, medium×worked_examples×thinks_blue_always_active ×2。別途プロファイルなし ×3 = no_education 条件） |
| v6 | 単一インスタンス | 単一インスタンス | 単一インスタンス | **4種類**（`type_key` ベース。edge_case_dropper ×6, rule_extractor ×2, order_confused ×2, passive_listener ×2。別途プロファイルなし ×3 = no_education 条件） |
| v7a | 単一インスタンス | 単一インスタンス | 単一インスタンス | 1種類（passive_listener ×12 のみ） |
| v7b | 単一インスタンス | 単一インスタンス | 単一インスタンス | 1種類（order_confused ×12 のみ） |
| v8 | 単一インスタンス | 単一インスタンス | 単一インスタンス | 4種類（rule_extractor / edge_case_dropper / order_confused / passive_listener 各 ×4） |
| v9b | 単一インスタンス | （tutor 役なし） | 単一インスタンス | 4種類（rule_extractor ×9, edge_case_dropper ×9, order_confused ×8, passive_listener ×8） |
| v9c | 単一インスタンス | （tutor 役なし） | 単一インスタンス | 4種類（v9b と同一分布） |
| **v9c2** | **20 インスタンス**（A5: 反復ごとに新規） | （tutor 役なし） | 単一インスタンス（意図的。全タスクが文字列 `expected_answer` を持つため evaluator 複数化は no-op） | 4種類（rule_extractor ×39, edge_case_dropper ×39, order_confused ×38, passive_listener ×38） |

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
- v5・v6 は 4 種類だが分布が偏っている（6/2/2/2）。
  〔2026-09-12 セルフ査読で修正: 旧版は両世代を「5種類」とし「(none) という未分類カテゴリも混在する」と
  記述していたが、`check_confounds.py` が `profile_json` の文字列でグループ化するため
  **プロファイルを持たない no_education 条件の学習者（×3）が `(none)` という1カテゴリとして
  数えられていた**。実際の種類数は 4 であり、v8 以降との差は種類数ではなく分布の偏りだけである。〕
- v8・v9b・v9c は 4 種類の learner type が均等に近い分布で混在しており、最も
  多様化が進んでいる。

## まとめ

> **本表が扱うのは F4・F5a・F5b の 3 項目のみである。**
> F1（corrective_note の静的テンプレート）・F2（scorer artifact）・F3（discussion への lesson/memory
> 非注入）・F5c（学習予算の非対称）は各世代の methodology-addendum に分散しており、本表には含まれない。
> **とくに F2 と F3 は複数世代を汚染しており、F4 と同等以上に重い。**
> 本表を「交絡状態の全体像」として読まないこと。〔2026-09-12 セルフ査読で追記〕

| 監査項目 | v4 | v5 | v6 | v7a | v7b | v8 | v9b | v9c | **v9c2** |
|---------|----|----|----|----|----|----|----|----|----|
| F4 (discussion 系 pseudoreplication) | ✓該当 | ✓該当 | ✓該当 | ✓該当 | ✓該当 | ✓該当(WCD 1/4) | ✓該当 | ✓該当 | **✅解消(各5/5)** |
| F5b (teacher/tutor/evaluator 単一性) | ✓該当 | ✓該当 | ✓該当 | ✓該当 | ✓該当 | ✓該当 | ✓該当（tutor無し） | ✓該当（tutor無し） | **△teacher 20体に是正、evaluator は意図的に単一** |
| F5a (learner profile 多様性) | 単一/無 | 多様(4,偏り) | 多様(4,偏り) | 単一(意図的) | 単一(意図的) | 多様(4,均等) | 多様(4,均等) | 多様(4,均等) | 多様(4,均等) |

凡例: ✓該当=明確に確認、△=部分的に是正、✅解消=再実験により解消、単一/無=多様化なし

〔2026-09-12 セルフ査読での変更: (1) v9c2 列を追加。旧版は v4〜v9c までしか扱っておらず、
**是正後の世代が存在しないため「全世代 F4 該当」に見えていた**。(2) v8 の F4 を「△部分的」から
「✓該当」に修正（Phase 3 のみで数えると WCD 1/4）。(3) v5・v6 の F5a を「多様(5,やや疎)」から
「多様(4,偏り)」に修正（`(none)` を種類数に数えていたため）。(4) v7a/v7b の「意図的?」の疑問符を除去
（両世代とも分析レポートで意図的な設計と確認済み）。〕
