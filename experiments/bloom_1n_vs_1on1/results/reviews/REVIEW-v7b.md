# v7b 人間セルフ査読記録

査読者: masumi / 日付: 2026-08-09 / 所要: ____
プロトコル: `docs/templates/human-review-protocol.md`(重み: 軽)
位置づけ: v6 で order_confused が hetero_classroom(7/8)より 1on1(5/8)で低得点だった件の機構切り分け。
全学習者を order_confused に揃え、「手続きスキャフォールド」条件を新設して
public_qa / generic 1on1 / procedure_scaffolded 1on1 の3条件を比較。
**v6 査読の所見3(order_confused 型が成立していない疑い)を本ファイルで検証する。**
主張の出典: `results/2026-05-23-v7b-analysis.md`、`results/2026-06-08-v7a-v7b-methodology-addendum.md`。

---

## エージェント準備: claim→evidence トレース表

run: `32ffaa49`(`data/experiment_v7b.db`、v7b 専用DB)

| # | 主張(出典) | DB での検証結果 | 一致? |
|---|---|---|:---:|
| 1 | public_qa 69%・generic 47%・procedure_scaffolded 41%(§3.1) | 68.8% / 46.9% / 40.6%(各32試行、正答 22/15/13) | ✅ |
| 2 | 学習者別内訳12名(§3.2) | 12名すべて一致(pq 8/7/7/0、generic 7/4/3/1、ps 5/2/3/3) | ✅ |
| 3 | タスク別正答率8タスク×3条件(§3.3) | **3列すべて §3.1 と矛盾**。列合計が pq 28(実際22)・generic 16(実際15)・ps 16(実際13)。不一致は8セル(所見1) | ❌ |
| 4 | 誤解修正率 pq 50%・generic 100%・ps 25%、残存誤解 0.0/0.5/0.25(§3.4) | 4条件すべて完全一致 | ✅ |
| 5 | 全学習者 order_confused 型(§2.1) | `profile_json.type_key` は3条件12名すべて order_confused | ✅ |
| 6 | classroom 講義長 3,506 chars(§2.3) | 実測 **4,456 chars**(§2.3 は「ログより推定」と明記)。加えて**質問3件と 1,795 字の `answers` ターンが実在**し、v7a の public_qa(講義のみ・質問ゼロ)とは条件の中身が異なる | ⚠️ |

## 横展開チェック(§3)エージェント下ろし分

- **v6 所見3の検証(本ファイルの主目的)**: 下記の所見2を参照。**型は成立していなかった**
- **実効n(F4)**: `learning_sessions` は classroom で1講義を4行複製(distinct=1)。v5〜v7a と同じ構造
- **v7a との条件差**: v7a の `classroom_public_qa` は passive_listener(質問確率0.0)のため質問ゼロの
  一方向講義だったが、v7b の同名条件は order_confused(質問確率0.4)で**実際に3件の質問と回答が発生**。
  総教示量は 4,456 + 1,795 = 約6,250字で、v7a の 3,599字を大きく上回る。
  **同じ条件名でも v7a と v7b で中身が違う**ため、両実験の classroom スコアを直接比較してはならない
- **procedure order 検出器(§3.6)**: 全条件0%。§3.6 は heuristic の失敗と説明しているが、
  所見2を踏まえると「**そもそも順序エラーが発生していなかった**」という別解釈が成り立つ

## 所見(エージェント検出分。処置の判断は masumi)

| # | 深刻度 | 内容 | 処置 |
|---|--------|------|------|
| 1 | **medium(数値の誤り)** | §3.3 タスク別正答率表が**3列とも §3.1 と整合しない**。列合計は public_qa 28(実際は22)、generic 16(15)、procedure_scaffolded 16(13)。不一致セルは8つ: pq の `l1_recall_01` 4→**3**、`l2_edge_case_02` 4→**3**、`l3_rule_interaction_01` 2→**1**、`l4_debug_01` 4→**3**、`l4_debug_02` 4→**3**、`l5_debug_03` 4→**3**、generic の `l6_induction_02` 2→**1**、ps の `l2_edge_case_02` 2→**1**・`l4_debug_01` 3→**2**・`l6_induction_02` 3→**2**。<br>特に public_qa 列は「4/4 = 100%」が5箇所あるが、同条件には**0/8 の学習者(`177c0b13`)が存在する**ため、どのタスクも 4/4 にはなりえない。表の生成時にこの学習者が脱落したと思われる。<br>ただし §5 の考察が名指しする3セル(ps の l3 = 0/4、l5 = 0/4、l4_debug_02 = 4/4)は**いずれも DB と一致**しており、結論そのものは崩れない | **fixed**(2026-08-09): §3.3 の8セルを DB 値に修正し、脱落学習者について注記を追加 |
| 2 | **high(実験の前提が成立していない・v6 所見3の確定)** | **order_confused 型の中核操作は、本実験でも一切機能していなかった。**<br>この型の定義は `rule_order_retention: 0.2`(80% の確率で発動)だが、実装は `rules` 配列を `shuffle` するだけで、**実際の適用手順が書かれた `strategy` フィールドは対象外**(`learner_types.rb`)。<br>DB を全数確認した結果、**12名全員の `strategy` に正しい順序が保持されていた**: 「check activation first, then apply modifiers」(generic 7d27368c)、「Determine activation status first, then apply modifiers」(46acf1e1)、「Resolve all activation before touching any modifier」(ps 47296ffc)、「Step 1 activate, Step 2 modify active only…」(72c469d7)など、例外は1件もない。classroom の学習者に至っては `rules` 配列の中に「**Activation status checked first; modifier applied second, always**」という順序ルールそのものを保持している。<br>→ v7b は「手続き的順序の欠損に対して、どの介入が効くか」を問う実験だが、**その欠損が学習者側に存在しない**。§8 の結論「procedure_scaffolded < generic なので手続きスキャフォールドは逆効果」は、直すべき対象がない相手に手順教示を与えて exchange を浪費した結果を見ている可能性が高い(実際 §3.4 で ps の誤解修正率は 25% と最低)。<br>§3.6 の「順序エラー検出率 0%」は heuristic の失敗ではなく**実態を正しく反映していた**可能性がある | **deferred**(2026-08-09): 論文3箇所(l.118・l.149・l.232)の書き換えが必要。ただし v9c 以降の `rc_procedure_order_01` で手続き知識が別途測られている可能性があるため、**文面確定は v8・v9b・v9c の査読後**。v7b 分析ドキュメント §8 には注記済み |
| 3 | low(5世代連続の再発) | classroom の bimodal 分布(3名が 88〜100%、1名が **0/8**)は「学習者のばらつき」ではなく**ルールカバレッジの欠損**。0/8 の `177c0b13` のメモリは `rules` が3本しかなく、その**全部が Red に関する記述**(「Red contributes 0; doubles only the single token immediately to its right」「Each Red is strictly local」「Activation status checked first」)で、**Green・Blue・Yellow の基底点も発火条件も一切ない**。得点計算が原理的に不可能な状態。他の3名は5本の rules に Yellow=7・Green=2・Blue の条件を保持している。<br>→ §3.2 が std dev 0.462 の原因として挙げる bimodal 性は、v4・v5・v6・v7a に続く**5世代目の同一機構**である | (記録のみ) |

論文への波及(調査済み): 所見2は**論文3箇所**に及ぶ。

| 行 | 記述 | 状態 |
|---|---|---|
| l.118 | shuffle が「(**degrading procedural knowledge**)」と説明されている | **実装の説明として不正確**。手順は `strategy` にあり shuffle の対象外 |
| l.149 | finding (iii) の理由づけ「does nothing for a **procedural deficit (shuffled rule order)**」 | 現象(修正率と得点の乖離)は事実だが、**機構の説明が根拠を失う** |
| l.232 | 「correcting a stated misconception leaves **procedural deficits** untouched」 | 同上 |

**観測は生き残り、説明が崩れる**という切り分けが重要。v6 の数値(93.8/59.4/59.4/0.0、type別ペア、
variance)は DB 照合済みで正しく、v7b の 69/47/41 も正しい。誤っているのは
「order_confused = 手続き的に混乱した学習者」というラベルと、それに依拠した機構の物語である。
所見1は v7b 分析ドキュメント内に閉じ、修正済み。

## 確認したこと(masumi 記入)

- 生データ読了(2026-08-09): **12名全員の `strategy` フィールド**を目視。
  - classroom(4名)・generic(4名)・procedure_scaffolded(4名)の**すべて**に
    「activation を先、modifier を後」という正しい順序が入っている。例外なし
  - 決め手は **classroom と generic の8名**。この8名は手順教示を一度も受けていないのに正しい順序を持つ。
    → 「procedure_scaffolded が手順を教えたせいでメモリに入った」では説明できず、
    **order_confused 型そのものが成立していなかった**と結論できる
  - 0/8 の `177c0b13` ですら `strategy` は正しい。この学習者が全問落としたのは順序ではなく
    `rules` が Red の記述3本だけで Green・Blue・Yellow が皆無だったため(所見3)
- 垂直貫通: 所見2について 型定義(`learner_types.rb` の `rule_order_retention: 0.2`)→
  実装(`apply_constraints` が `rules` のみ `shuffle`、`strategy` は対象外)→
  実データ(12名の `strategy`)→ 論文の記述(l.118「degrading procedural knowledge」)まで4層を貫通

## 信頼で受け入れたこと(未検証)

- トークンコスト(§3.7)は DB 未照合。`token_tracker.rb` の char 数推定値
- §3.5 の ceiling 分類表。分類ロジック自体は追っていない
- **シャッフルが実際に発動したかどうか**は原理的に検証不能。制約適用前のメモリは保存されていないため、
  「`rules` が並べ替えられた」ことは確認できない。確認できるのは「**結果として手順知識が残った**」ことのみ
- §5 の考察のうち、タスク別の解釈(l4_debug_02 で手順ラベルが有効に働いた等)のメカニズム部分

## 見ないで書いた5行要約(masumi 記入)

1. 何を操作したか: passive_listenerとorder_confusedの数値が動いた理由の分析をするため、v7bではorder_confusedに絞って概念的な理解か、手続き的な解説が効くか分析した
2. 何を測ったか:　上記の変数を変更しタスク別正答率を測定した
3. 何が分かったか:　そもそもがorder_confusedの生徒はいなかった。public_qa 69% > generic 47% > procedure_scaffolded 41%という結果でclassroomのパフォーマンスがまた勝った。
4. 何が言えないか:　概念的な理解と手続き的なレクチャーのどちらが効くかはこの結果からは言えない
5. 次に何をすべきか:　order_confusedの検証を引き続きやるかどうかを決める

## チェックリストへの追記候補

- **構成概念と実装の等価性を、データで確認する**(v6「操作をソースで確認する」の一段深い版):
  ソースを読んで操作が存在することを確かめるだけでは足りない。
  「手続き知識の劣化」という**概念**が「配列の shuffle」という**実装**で本当に実現されるかは、
  操作の前後で何が変わったかを実データで見るまで分からない。v7b では
  「変わっていないはずのもの」(`strategy` フィールド)が全員に残っていたことで発覚した。
  → **操作対象のフィールドと、構成概念が実際に宿っているフィールドが一致しているかを確認する**
- **制約適用の前後を両方保存する**: 現在の実装は制約適用後のメモリしか保存しないため、
  操作が発動したかを事後検証できない。今後の世代では適用前スナップショットを残すか、
  適用ログ(どのフィールドから何件削除・シャッフルしたか)を記録する
- **枝分かれ実験を立てる前に、説明しようとしている差の n を数える**: v7b は v6 の −25pp を
  説明するために走ったが、その −25pp は 1名 vs 1名・8問中2問の差だった。
  **2問分の差を説明するために1実験を費やす前に、まず差の再現性を確かめる**
- **同名の条件でも中身が違うことがある**: `classroom_public_qa` は v7a では質問ゼロの一方向講義
  (3,599字)、v7b では質問3件+回答1,795字を含む(講義4,456字)。学習者型の
  `question_asking_probability` が違うため。**実験間で同名条件のスコアを直接比較しない**
