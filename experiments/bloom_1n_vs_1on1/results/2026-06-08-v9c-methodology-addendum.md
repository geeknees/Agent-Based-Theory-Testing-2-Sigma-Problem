# v9c 方法論的注記アドエンダム（2026-06-08）

run_id: b412cfdb-0522-4997-a47e-1738eb414f4b
対象レポート: 2026-06-06-v9c-full-analysis.md

## 1. L6 (short_rule_induction) 再採点結果

`scripts/rescore_l6.rb data/experiment_v9c.db b412cfdb-0522-4997-a47e-1738eb414f4b` の出力：

```
condition                              total   before    after
lecture_only                               4        0        2
pair_discussion_size_2                     2        0        0
small_class_discussion_size_4              4        0        1
medium_class_discussion_size_8             8        0        0
large_class_discussion_size_16            16        0        0
TOTAL                                     34        0        3
```

旧 scorer（`lib/scorer.rb:22-27`）は exact-match＋限定的な `acceptable_aliases` のみで判定しており、
意味的に正しい言い換えの大半を 0 点にしていた。`l6_induction_02` に実際の学習者の言い換え
（"Red contributes 0; doubles the base value of the next token only." 等）を `acceptable_aliases`
として追加したところ、34 件中 3 件（8.8%）が `false → true` に転じた：

- lecture_only: 0/4 → 2/4
- small_class_discussion_size_4: 0/4 → 1/4
- pair / medium / large: 変化なし（0/2, 0/8, 0/16）

**解釈上の注意（過大評価しないこと）：** この 3 件の回復は、v9c の実際の言い換えパターンから
事後的にキュレーションした alias リストによるものであり、汎用的な修正ではない。同じ
rescore スクリプトを v8（n=16）・v9b（n=34）に適用すると、いずれも `before=0 / after=0`
（回復ゼロ）だった——これは各バージョンの学習者が Red トークンのルールを互いに異なる言い回し
（例: v8 では "immediately to its right" 系の表現）で説明しており、v9c 用にキュレートした
alias が他バージョンには適用されないためである。

つまり：
- **「`before=0` が全 3 run で一致して観測された」こと自体が F2（scorer の構造的バグ）の
  存在を強く裏付ける** ── これは scorer artifact が pervasive であることの確証である。
- 一方で「alias 追加で L6 = 8.8% まで改善した」という数値は **v9c 固有のキュレーション結果**
  であり、「修正後の真の L6 正答率」を示すものではない。本来の修正には、各バージョンの
  言い換えパターンを網羅する大幅な alias 拡充、または意味的類似度ベースの scorer への
  置き換えが必要。
- レポート上の L6 = 0% は、学習者の帰納能力の欠如ではなく、主として scorer の構造的バグに
  よる artifact である、という解釈は維持されるべきだが、「修正後は何%になる」という形の
  断定的な数値は付与しない。

## 2. Pseudoreplication（独立反復数）

`scripts/check_replication.py data/experiment_v9c.db b412cfdb-0522-4997-a47e-1738eb414f4b` の出力：

```
condition                            sessions   unique_discussions
large_class_discussion_size_16             16                    1
medium_class_discussion_size_8              8                    1
pair_discussion_size_2                      2                    1
small_class_discussion_size_4              4                    1
```

全 discussion 条件で `unique_discussions = 1`（`transcript_json` の MD5 ハッシュが条件内で
完全に一致）。つまり各条件で実施された discussion セッションは実質 1 回のみであり、
複数の learner はその単一の discussion に対する読み手として記録されているにすぎない。

各 condition のスコア分散（レポート中の Std Dev / 95% CI に類する記述）は、
「N=1 の discussion に対する learner の反応のばらつき」であって、
「discussion デザイン（pair / small / medium / large）の効果に関する不確実性」では
ない。条件間の比較を「教育法 A は教育法 B より効果的」と読むには、各条件で複数回・
独立に discussion を生成した反復が必要である。

## 3. Confound チェック結果

`scripts/check_confounds.py data/experiment_v9c.db b412cfdb-0522-4997-a47e-1738eb414f4b` の出力：

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

- **learner profile**: 4 種類（rule_extractor ×9, edge_case_dropper ×9, order_confused ×8,
  passive_listener ×8）が混在していることを確認した。これはレポートの「Score by Learner
  Type」表とも一致する（→ Task 7 で訂正する外部メモの「34/34 全員 rule_extractor」という
  記述は誤りであることが判明）。
- **classroom_teacher / evaluator**: ともに単一インスタンス。tutor の指導品質や judge の
  採点ぶれと、condition（クラスサイズ）による効果とを統計的に分離できない。
- **lecture_only の learning_sessions 行数 = 0**：discussion 相当の学習セッション（および
  そこで消費される学習時間・トークン量）が与えられておらず、他の条件と「同じ学習予算での
  比較」になっていない（F5c）。lecture_only の成績の高低は、これら confound の影響を
  受けている可能性がある。

## 4. Discussion context injection（F3）

`lib/phases/sized_discussion.rb` の participant prompt には lesson テキストも learner の
事前 memory も注入されておらず、moderator にのみ渡る構造になっている。実際の transcript
を確認したところ、called_on された学習者の最初の発話は全 discussion 条件で一貫して
「ルールを手元に持っていない」という内容になっていた：

- pair_discussion_size_2: "I want to engage here, but I have to be honest: I don't actually know the rules for Zarn tokens..."
- small_class_discussion_size_4: "I don't have the Zarn token rules defined anywhere in this codebase or conversation..."
- medium_class_discussion_size_8: "I want to contribute, but I'm missing something crucial: I don't see the Zarn scoring rules defined anywhere..."
- large_class_discussion_size_16: "I'd like to help, but I'm stuck at the starting point: I don't have the Zarn token rules in front of me..."

discussion 条件間で観測される差は、「協働的な知識構築の質の差」ではなく、
「lesson も memory も持たない状態からどう回復するか、という構造の差」を測っている
可能性が高い。pair が large より高スコアになる傾向があるとしても、それは
「少人数の方が協働学習として優れている」のではなく、「忘却状態からの回復が
小規模な対話構造でより容易だった」だけかもしれない。

## 5. 結論として何を main report の解釈に反映すべきか

- L6 のスコア = 0% は、主として scorer の構造的バグ（F2）による artifact である。ただし
  「修正後は何%になる」という断定的な数値（例: 8.8%）は、v9c 固有のキュレーションに
  依存した楽観的な下限値にすぎず、外部に引用すべきではない。
- 条件間の SD / CI に類する記述は、学習者個体差の表現であり、discussion デザインの
  効果に関する統計的不確実性ではないため、「条件 A は条件 B より優れている」という
  形の主張の根拠として引用しない。
- discussion 条件間比較（pair > medium 等）は F3（lesson/memory 非注入）の影響下にあり、
  教育法そのものの効果として解釈できない。
- lecture_only の成績は F5c（学習セッション 0 件 = 学習予算の非対称性）の影響下にあり、
  他条件と直接比較できない。
- readiness_failed = true はそのまま有効。本アドエンダムは readiness gate の評価結果を
  変更するものではなく、readiness が満たされていてもなお残る方法論的な懸念を補足する
  ものである。

## 外部ノートへの訂正依頼

上記セクション 3 で確認した learner profile の多様性（4 種類混在）は、外部メモ
（masusanou ノート）の「致命的発見 5a」節の記述と矛盾する。Task 7 で作成した訂正文
（本リポジトリの Git 管理外、Obsidian vault 上のノートに反映されるべき内容）を以下に
転記する：

> ### 致命的発見 5a（訂正版）: 学習者プロファイルは実際には4種類混在している
>
> [訂正前の記述: 「34/34 全員が rule_extractor のみ」は誤り]
>
> v9c 本番 run（b412cfdb-...）の `agents` テーブルを再集計した結果：
> edge_case_dropper ×9, order_confused ×8, passive_listener ×8, rule_extractor ×9
> の4種類が混在しており、レポートの「Score by Learner Type」表とも一致する。
> おそらく config_v9c_smoke.yml（learner_types を2種類のみ設定）の DB を
> 本番 run と取り違えて集計したことによる誤りと推測される。
>
> → F5a は「学習者プロファイルの多様性」を巡る confound としては成立しない。
> A4（learner profile 多様化）は v9c では既に実施済みであり、優先度を下げてよい。

ユーザーには、このノートの該当節を上記の訂正版に差し替えていただくよう依頼する。
