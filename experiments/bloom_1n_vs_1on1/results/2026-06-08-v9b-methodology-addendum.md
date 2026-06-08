# v9b 方法論的注記アドエンダム（2026-06-08）

run_id: 772d2ce7-246a-467e-89ae-b63d02d39c85（本番 run, n=34, claude-sonnet-4-6）
対象レポート: 2026-06-04-v9b-full-analysis.md

> **注記:** 当初の計画ドラフトでは v9b の run_id として `9b599c12-ab43-42f8-8af4-de26551b3981`
> （`experiment_v9b_smoke.db` 内のスモークテスト run, n=14, haiku モデル）が参照されていたが、
> これは誤りであることが判明したため、本アドエンダムは本番 run（`experiment_v9b.db`,
> run_id `772d2ce7-246a-467e-89ae-b63d02d39c85`, n=34, sonnet モデル）に対して作成している。

## 1. L6 (short_rule_induction) 再採点結果

`scripts/rescore_l6.rb data/experiment_v9b.db 772d2ce7-246a-467e-89ae-b63d02d39c85` の出力：

```
condition                              total   before    after
lecture_only                               4        0        0
pair_discussion_size_2                     2        0        0
small_class_discussion_size_4              4        0        0
medium_class_discussion_size_8             8        0        0
large_class_discussion_size_16            16        0        0
TOTAL                                     34        0        0
```

v9c 用にキュレートした `acceptable_aliases`（"Red contributes 0; doubles the base value of
the next token only." 等の言い換え）を適用しても、v9b では 34 件中 1 件も `false → true`
に転じなかった（before=0, after=0）。これは v9b の学習者が Red トークンのルールを
v9c とは異なる言い回しで説明しているためであり、alias リストが v9c の特定の言い回し
パターンに依存してキュレートされたものだからである。

**解釈上の要点：**
- `before=0`（修正前の正答率 0%）は v8（n=16）・v9c（n=34）・v9b（n=34）の **3 run すべてで
  一致して観測**されている。これは「学習者が L6 を全く解けていない」という解釈よりも、
  「scorer の exact-match 判定（F2, `lib/scorer.rb:22-27`）が意味的に正しい言い換えを
  すべて 0 点にしている」という構造的バグの解釈の方が遥かに尤もらしいことを強く示す。
- 一方で、v9c で観測された 8.8%（3/34）の回復は v9b には全く汎化しなかった
  （0/34）。L6 = 0% を「scorer artifact による過小評価である」と主張すること自体は
  妥当だが、「修正後は何%まで回復するか」を v9c の結果から外挿して v9b に適用する
  ことはできない。各バージョンの言い換えパターンに合わせた alias の作り直し、または
  意味的類似度ベースの scorer への置き換えが必要であり、それなしには v9b の真の
  L6 正答率は不明のままである。

## 2. Pseudoreplication（独立反復数）

`scripts/check_replication.py data/experiment_v9b.db 772d2ce7-246a-467e-89ae-b63d02d39c85` の出力：

```
condition                            sessions   unique_discussions
large_class_discussion_size_16             16                    1
medium_class_discussion_size_8              8                    1
pair_discussion_size_2                      2                    1
small_class_discussion_size_4               4                    1
```

v9c と同様、全 discussion 条件で `unique_discussions = 1`。各条件で実施された discussion
セッションは実質 1 回のみであり、複数の learner はその単一の discussion に対する読み手と
して記録されているにすぎない。条件間のスコア分散は、discussion デザインの効果に関する
不確実性ではなく、単一の discussion に対する learner 個体差の表現である（[[v9c-methodology-addendum]]
セクション 2 と同一の論点）。

## 3. Confound チェック結果

`scripts/check_confounds.py data/experiment_v9b.db 772d2ce7-246a-467e-89ae-b63d02d39c85` の出力：

```
Learner profile distribution:
    9  {"type_key":"rule_extractor"}
    9  {"type_key":"edge_case_dropper"}
    8  {"type_key":"order_confused"}
    8  {"type_key":"passive_listener"}
  -> distinct profiles: 4

Single-instance role check:
  classroom_teacher    distinct instances: 1  <-- SINGLE INSTANCE
  evaluator            distinct instances: 1  <-- SINGLE INSTANCE

learning_sessions rows per condition (phase-exposure check):
  large_class_discussion_size_16      16
  medium_class_discussion_size_8      8
  pair_discussion_size_2              2
  small_class_discussion_size_4       4
```

v9c と**完全に同一の confound プロファイル**が確認された：

- **learner profile**: 4 種類混在（rule_extractor ×9, edge_case_dropper ×9,
  order_confused ×8, passive_listener ×8）。v9c と同じ分布であり、外部メモの
  「全員同一型」という記述は v9b にも適用されない。
- **classroom_teacher / evaluator**: ともに単一インスタンス。tutor の指導品質や
  judge の採点ぶれと、condition による効果とを統計的に分離できない。
- **lecture_only の learning_sessions 行数 = 0**：discussion 相当の学習時間・トークン
  消費が他条件と非対称（F5c）。

## 4. Discussion context injection（F3）

`lib/phases/sized_discussion.rb` のコードは v9c と同一構造であり、participant prompt に
lesson も learner memory も注入されない。Task 3 にて v9b の各 discussion 条件の最初の
learner 発話を確認した結果、**v9c と同型の「ルールを持っていない」という発話パターンが
全 4 条件で再現された**：

- pair_discussion_size_2: "I want to engage here, but I have to be honest: I don't actually know the rules for Zarn tokens. The problem asks about which tokens are 'active,' what Red does..."
- small_class_discussion_size_4: "I don't have the Zarn token rules defined anywhere in this codebase or conversation. Without knowing what rules govern scoring, active states, or Red modifiers..."
- medium_class_discussion_size_8: "I want to contribute, but I'm missing something crucial: I don't see the Zarn scoring rules defined anywhere in the context. Without knowing what each color's b[ase value is]..."
- large_class_discussion_size_16: "I'd like to help, but I'm stuck at the starting point: I don't have the Zarn token rules in front of me. Could someone recap them? Specifically, I need to know..."

コード構造が同一であることに加え、観測された発話パターンも v9c と一致したことから、
F3 が v9b にも同様に及んでいることの強い証拠が得られた。discussion 条件間で観測される
スコア差は、協働的な知識構築の質の差ではなく、「lesson も memory も持たない状態からの
回復構造の差」を反映している可能性が高い。

## 5. 結論として何を main report の解釈に反映すべきか

- L6 のスコア = 0% は、scorer の構造的バグ（F2）による artifact である可能性が高い
  （v8・v9c・v9b の 3 run すべてで before=0 が一致して観測されている）。ただし
  「修正後は何%になるか」という具体的な数値は、v9c のキュレーション結果から外挿
  できず、v9b では before=after=0（回復なし）であったことをそのまま記載する。
- 条件間の SD / CI に類する記述は、学習者個体差の表現であり、discussion デザインの
  効果に関する統計的不確実性ではないため、「条件 A は条件 B より優れている」という
  形の主張の根拠として引用しない。
- discussion 条件間比較は F3（lesson/memory 非注入、v9c と同型のパターンで確認済み）
  の影響下にあり、教育法そのものの効果として解釈できない。
- lecture_only の成績は F5c（学習セッション 0 件 = 学習予算の非対称性）の影響下にあり、
  他条件と直接比較できない。
- readiness_failed の状態については、本アドエンダムは readiness gate の評価結果を
  変更するものではない（[[v9c-methodology-addendum]] と同様、本アドエンダムは
  readiness が満たされていてもなお残る方法論的な懸念を補足するものである）。
