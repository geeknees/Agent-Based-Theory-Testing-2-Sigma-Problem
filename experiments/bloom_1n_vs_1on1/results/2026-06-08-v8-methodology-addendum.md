# v8 方法論的注記アドエンダム（2026-06-08）

run_id: ef107ef9-bee8-420e-a94f-31aee4a56c37
対象レポート: 2026-05-29-v8-analysis.md

レポートの目玉結論（Score by Condition）：

```
lecture_plus_whole_class_discussion   83% (WCD)
lecture_plus_one_on_one_tutoring      78% (1on1)
lecture_only                          70% (LO)
lecture_plus_small_group_discussion   68% (SGD)
```

## 1. L6 (short_rule_induction) 再採点結果

`scripts/rescore_l6.rb data/experiment_v8.db ef107ef9-bee8-420e-a94f-31aee4a56c37` の出力：

```
condition                              total   before    after
lecture_only                               4        0        0
lecture_plus_whole_class_discussion        4        0        0
lecture_plus_small_group_discussion        4        0        0
lecture_plus_one_on_one_tutoring           4        0        0
TOTAL                                     16        0        0
```

v9c 用にキュレートした `acceptable_aliases` を適用しても、v8 では 16 件中 1 件も
`false → true` に転じなかった（before=0, after=0）。これは v8 の学習者が Red
トークンのルールを v9c とは異なる言い回し（"immediately to its right" 系の表現等）
で説明しているためであり、v9c から外挿した alias リストが汎化しないことを示す
（[[v9c-methodology-addendum]] セクション 1、[[v9b-methodology-addendum]] セクション 1
と同一の論点）。

**解釈上の要点：** `before=0` は v8（n=16）・v9c（n=34）・v9b（n=34）の3 run すべてで
一致して観測されており、これは F2（scorer の構造的バグ）が pervasive であることを
強く示す。一方、「修正後は何%になるか」という具体的な数値は v9c の特定の言い換え
パターンに依存しており、v8 には全く汎化しない（0/16）。レポート上の L6 = 0% を
scorer artifact による過小評価と解釈すること自体は妥当だが、v8 の真の L6 正答率は
（適切な alias 拡充または意味的類似度ベースの scorer なしには）依然として不明である。

## 2. F4 (pseudoreplication)

`scripts/check_replication.py` の出力（[[v4-v9c-replication-confound-audit-table]] より転記）：

```
condition                            sessions   unique_discussions
lecture_only                                4                    1
lecture_plus_one_on_one_tutoring            8                    5
lecture_plus_small_group_discussion         8                    3
lecture_plus_whole_class_discussion         8                    2
```

- `lecture_only`: discussion 自体が無い条件（lesson のみ共有）であり、
  `unique_discussions = 1` は固定レクチャーの再利用を反映している。F4 の対象外。
- `lecture_plus_whole_class_discussion`（8 セッション中 2 種類）・
  `lecture_plus_small_group_discussion`（8 セッション中 3 種類）・
  `lecture_plus_one_on_one_tutoring`（8 セッション中 5 種類）：いずれも
  **部分的 pseudoreplication** が確認された。v9b/v9c（discussion 実質1回 ×全条件）
  ほど極端ではないが、「8 セッション = 8 回の独立した教育インタラクション」
  ではなく、より少数の discussion/tutoring セッションが複数の learner 間で
  共有されている。

→ WCD・SGD・1on1 の SD（レポート中の標準偏差列: 0.096 / 0.050 / 0.287）は、
「8 件の独立反復」ではなく「2〜5 件のユニークなセッションに対する learner の
反応の分散」であり、条件間比較における統計的信頼性は額面通りには受け取れない。
特に WCD（unique=2）と 1on1（unique=5）を「同じ精度で測定された条件」として
比較することはできない。

## 3. F5 (confound)

`scripts/check_confounds.py` の出力（[[v4-v9c-replication-confound-audit-table]] より転記）：

```
Learner profile distribution:
    4  rule_extractor / edge_case_dropper / order_confused / passive_listener （各 ×4, 計16）
  -> distinct profiles: 4

Single-instance role check:
  classroom_teacher    distinct instances: 1  <-- SINGLE INSTANCE
  tutor                distinct instances: 1  <-- SINGLE INSTANCE
  evaluator            distinct instances: 1  <-- SINGLE INSTANCE
```

- **learner profile**: 4 種類が均等（各 ×4）に分布しており、v9b/v9c と同じ
  整理された多様化状態にある。F5a（プロファイル多様性 confound）は v8 にも
  該当しない。
- **F5b（teacher/tutor/evaluator 単一インスタンス）は v8 にも該当**。
  「WCD が最高スコア」という結論についても、それが教育法そのものの効果か、
  単一の moderator/teacher・単一の evaluator の偏りによるものかを分離できない
  （[[v4-v9c-replication-confound-audit-table]] まとめ表参照——全バージョン共通の
  構造的特徴）。

## 4. WCD/SGD の lesson 注入非対称性（v8 固有の confound）

コード上、`lib/phases/whole_class_discussion.rb` と `lib/phases/small_group_discussion.rb`
の participant プロンプトには、以下の非対称な lesson アクセスが存在する：

| Phase | 行 | learner への context |
|-------|----|-----|
| WCD moderator opening (`open_prompt`) | `whole_class_discussion.rb:27` | `DOMAIN LESSON:\n#{lesson}` （moderator のみ） |
| **WCD learner contribution (`contrib_prompt`)** | **`whole_class_discussion.rb:41`** | **`DISCUSSION SO FAR:\n#{history}#{learner_ctx}` — lesson 無し** |
| WCD moderator closing (`close_prompt`) | `whole_class_discussion.rb:52` | `DOMAIN LESSON:\n#{lesson}\n\nDISCUSSION:\n#{history}` （moderator のみ） |
| **SGD round 1 contribution (`contrib_prompt`)** | **`small_group_discussion.rb:36`** | **`#{ctx_prefix}LESSON CONTEXT:\n#{lesson}#{learner_ctx}` — lesson あり** |
| SGD round 2 reply (`reply_prompt`) | `small_group_discussion.rb:53` | `GROUP DISCUSSION:\n#{history}#{learner_ctx}` — lesson 無し |
| SGD shared notes | `small_group_discussion.rb:66` | `GROUP DISCUSSION:\n#{history}` — lesson 無し |

つまり WCD では学習者の発言（`contribution`）に一度も lesson が渡らないのに対し、
SGD では少なくとも round 1 の `contribution` には lesson が渡る、という非対称が
コード上確認できる（プラン記載の懸念は正しい）。

**しかし、transcript を実際に確認した結果（Task 9）、この非対称は予想された
形では現れていなかった。** プランの仮説は「WCD の最初の発話に『ルールを知らない』
パターンが出るのではないか（v9c/v9b と同型の崩壊）」というものだったが、実際の
WCD 最初の learner 発話は次のように、Red modifier のルールを一字一句に近い精度で
言い当てていた：

> "Now I can contribute as a learner. Here's my reasoning for [Red, Green, Blue, Yellow]: ... **Position 1 — Red:** Pure modifier, contributes 0. Doubles the token immediately to its right..."

これは `domains/zarn_tokens/lesson.md` の実際のルール文言
（"A Red Zarn doubles the base value of the token immediately to its right.
The Red Zarn itself contributes 0 to the score (it is a pure modifier)."）と
ほぼ一致する内容であり、単なる「もっともらしい作話」では説明しづらい精度である。
`contrib_prompt` の context には lesson もこれまでの `learner_memory` も渡されて
いない（コード上確認済み — `whole_class_discussion.rb` 内に `memory` への参照は
一切無い）にもかかわらず、である。

**これは「WCD は lesson を与えられず discussion でルールを再構築できなかった」
という単純な仮説を否定する一方、別の、より重要な疑問を提起する：** WCD の learner
は、明示的に lesson を与えられていないのに、なぜ正確なルール記述を生成できたのか？
可能性としては (a) claude-sonnet-4-6 が「ダブリングモディファイア」型のパズル
構造から自己無撞着なルール体系を高い精度で再構成できる、(b) 何らかの情報経路
（例: `claude --print` のセッション継続性、`learner_ctx` 経由の暗黙的な情報伝播等）
がコードからは見えない形で機能している、のいずれかが考えられるが、本アドエンダム
の調査範囲では特定できなかった。

いずれにせよ、**WCD と SGD の比較は「同じ情報条件下での討論形式の比較」には
なっていない**——WCD は「lesson 無しでの即興的なルール再構成 + 討論」、SGD は
「lesson 有りでの討論」という、構造的に異なる課題を学習者に課している。
WCD（83%）が SGD（68%）を上回ったという結果は、したがって「全体討論は少人数
討論より教育効果が高い」という単純な解釈はできず、**むしろ「lesson 無しでも
高精度にルールを再構成できる学習者の集団が、たまたま WCD に割り当てられた
discussion 構造の中で好成績を残した」という、教育法そのものとは別の要因
（learner の個体能力、moderator の介入の質、discussion の偶発的な質等）の方が
強く効いている可能性がある**。

## 5. 結論として何を main report の解釈に反映すべきか

- L6 のスコア = 0% は scorer の構造的バグ（F2）による artifact である可能性が
  高いが、「修正後は何%になるか」を v9c の結果から外挿することはできない
  （v8 では before=after=0、回復ゼロ）。
- WCD・SGD・1on1 の SD は、8 セッション中 2〜5 種類のユニークな transcript
  に対する反応の分散であり、条件間の精度を均質に比較できる統計量ではない
  （F4、部分的 pseudoreplication）。
- F5b（teacher/tutor/evaluator 単一性）により、「WCD が最高スコア」という
  結論が教育法の効果か単一インスタンスの偏りかを分離できない。
- **目玉結論「WCD (83%) > 1on1 (78%) > only (70%) > SGD (68%)」のうち、
  WCD と SGD の比較は特に注意が必要**：両条件は lesson アクセスの有無という
  構造的に異なる情報条件下にあり（F3 の v8 版に相当する confound）、しかも
  その非対称が「予想された形（WCD の知識崩壊）」では現れず、「予想されない形
  （WCD 学習者の高精度なルール再構成）」で現れている。この事実は、レポートの
  「WCD が最も効果的な教育法である」という解釈に再考を促す——83% という数値は
  教育法の優劣ではなく、学習者集団の能力・moderator の介入の質・discussion の
  偶発的展開など、複数の交絡要因が絡み合った結果である可能性が高い。
- レポート 4.1 節「WCD が最高スコアを示した理由の仮説」のうち、「moderator の
  closing で正解が明示される」という仮説（4.1 第3項）は、本アドエンダムで確認した
  「WCD 学習者が初発話の時点で既に正確なルールを把握していた」という事実と
  整合的ではあるが、その正確な把握がどこから来たのかは依然として未解明である
  ことに留意する必要がある。
