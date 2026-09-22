# v9c2 ablation (n_disc=1) 人間セルフ査読記録

査読者: masumi / 日付: 2026-09-25 / 所要: 20min
プロトコル: `docs/templates/human-review-protocol.md`(重み: **フル — 帰属の要**)
位置づけ: v9c(37pp)→ v9c2(10pp)の効果消失を、**A3(discussion の反復化)だけ v9c 相当(n_disc=1)に戻して**
切り分ける arm。他の是正(A0/A5/A6/A8)は有効のまま。
主張の出典: `results/2026-06-21-v9c2-ablation-ndisc1-analysis.md`、
`results/2026-06-21-v9c2-ablation-ndisc1-run-report.md`(**DB 紛失のため run report で代替**)、論文 §8.2・§9。

---

## エージェント準備: claim→evidence トレース表

run: `a551c74d`。**DB は保持されていない**ため、一次資料は
`2026-06-21-v9c2-ablation-ndisc1-run-report.md`(run report の verbatim コピー)。
検証は「分析ドキュメント ↔ run report」の照合と、**コード・関連 DB による間接確認**に限られる。

| # | 主張(分析ドキュメント) | run report での確認 | 一致? |
|---|---|---|:---:|
| 1 | pair 72%・small 58%・large 51%・medium 49%・lecture 47%、最大差 25pp(§2.1) | 「Score by Condition」表と一致(試行 18/36/144/72/36) | ✅ |
| 2 | readiness: edge_case 100%・recall 53%・procedure_order 47%・rule_interaction **12%**、全体 53%(§2.2) | 「Readiness Summary」と一致。`readiness_failed: true` | ✅ |
| 3 | flags: ownership true・discussion_added_value true・class_size false(§2.3) | 「Interpretation Flags」と一致 | ✅ |
| 4 | learner type 63/63/43/36%(§2.3) | 「Score by Learner Type」と一致 | ✅ |
| 5 | High-confidence wrong 15%(§2.3) | 「Confidence Calibration」と一致 | ✅ |
| 6 | discussion-level SD は全 discussion 条件で N=1 のため 0.0(§2.3) | 「Score Variance (discussion-level)」と一致(lecture のみ N=4 / SD 0.14) | ✅ |
| 7 | 総トークン 631,243(ヘッダ) | 「Token Usage by Phase」の TOTAL と一致 | ✅ |

**分析ドキュメントは run report に忠実である。** 以下の所見はすべて**一次資料である run report 側**、
または実験コード側の問題である。

## 横展開チェック(§3)エージェント下ろし分

- **一次資料の限界**: DB 紛失により、run report の集計を独立に再計算できない。
  垂直貫通の「計算 → DB」段が**原理的に実施不可能**。本世代のみ、プロトコル §2 の必須項目を満たせない
- **実効n(F4)**: n_disc=1 に戻した設計どおり、discussion 条件はすべて独立反復1本。
  **run report がこれを discussion-level SD = 0.0 として明示している**のは誠実
- **天井/床**: `peer_error_detection` 100%・`explanation_choice` 88-100% が天井
- **予算・量の非対称(F5c)**: 教育トークンは lecture 2,813 vs discussion 6,629〜8,877。
  v9c2 の 1/15 ほど極端ではないが依然として非対称
- **readiness**: 53% で不合格。**同一の固定講義・同一の readiness チェックを使いながら
  v9c(69%)・v9c2(90%)から大きく低下**しており、特に rule_interaction は 50%→85%→**12%** と振れている(所見2)

## 所見(エージェント検出分。処置の判断は masumi)

| # | 深刻度 | 内容 | 処置 |
|---|--------|------|------|
| 1 | **high(F2 の「修正」が別の形で失敗している)** | **L6 の semantic scorer(Option B)は動作しているが、その判定結果がスコア欄に一切書き込まれていない。**<br>`SEMANTIC_TASK_TYPES` は 2026-06-15(`748c6b7`)に導入され、本 ablation(06-16〜17 実施)では**有効だった**。しかし `answer_correct` を設定しているのは `lib/scorer.rb`(exact-match 経路)だけで、**`lib/phases/evaluator.rb` の LLM 経路は一度も設定しない**。`LLM_FALLBACK_SCORE` にもキーがない。<br>`data/experiment_v9c2_ablation_smoke.db` で実証: L6 の評価行は `auto_scored=0`(LLM 経路を通過)、**`total` は 20点満点中 11〜20点**、しかし **`answer_correct` は null**。非 L6 行は `auto_scored=1` / `answer_correct=1`。<br>→ **LLM 判定は L6 を「ほぼ正答」と採点しているのに、レポートの集計は null を不正解として数え 0 と表示する。**<br>影響: (a) run report の L6 表「全条件 0」は exact-match の artifact **ではなく** 新しいバグの産物。(b) 同表のヘッダは「Results below use LLM judge scores」、列見出しは「Correct (exact-match)」、注記は「exact-match only」と、**同一表内で3つの互いに矛盾する説明**をしている(`lib/report.rb:584-603` のハードコード文字列)。(c) 論文 §4 が L6 を「re-routed to a semantic judge」と述べる際、**その judge の結果が主要スコアに反映される経路が存在しない**。<br>これは v8/v9b/v9c の F2 とは**別のバグ**であり、F2 の修正によって新たに生じたものである | **deferred**(2026-09-05): 修正自体は `evaluator.rb` の LLM 経路に `answer_correct` を設定する数行だが、**適用には再実行が必要**で査読の範囲を超える。論文 §4 の L6 記述と一体で、監査・論文査読時に文面と対応方針を決める |
| 2 | **medium(帰属の前提)** | readiness の `rule_interaction` が **50%(v9c)→ 85%(v9c2)→ 12%(本 ablation)** と振れている。同一の固定講義・同一の readiness チェックを使っており、分析ドキュメント §2.2 はこれを「シード未固定の確率的プロセスの不安定さ」に帰している。<br>しかし n=34 で 12% と 50% は二項分布の標準誤差(p≈0.3, n=34 で約8pp)の4〜5倍離れており、**単純なサンプリング変動としては説明しにくい**。何か別の要因(コード変更・プロンプト差分・モデル側の変動)が同時に動いていた可能性を排除できていない。<br>本 ablation の結論「A3 単独の寄与量は分離できない(readiness も同時に変化したため)」は、**この振れ幅の原因が特定できていないことに依存**している。原因が「本当にランダム」なら結論はそのままだが、系統的要因なら ablation の設計自体を見直す必要がある | **fixed**(2026-09-22): 論文 §9 の「シード統制されていない」項目に**観測された変動幅を具体的に追記**(同一教材・同一チェックで rule_interaction が 50%→85%→12%)。原因の特定には再実行が必要であり、そのことも明記した |
| 3 | **medium(構造的な繰り返し)** | 25pp の両端は **pair(n=2、72%)と lecture(n=4、47%)**。v9c の 37pp(pair n=2 vs lecture_only n=4)と**まったく同じ構造**である。<br>§4 限界2 は pair n=2 を明記しているが、「25pp が v9c(37pp)と v9c2(10pp)の中間」という中心的な解釈は、**3世代とも同じ2条件が両端に来ている**という事実の上に立っている。spread の大小比較は、n=2 と n=4 の条件の振れをそのまま反映している可能性がある | **fixed**(2026-09-22): 論文査読時に DB で検算したところ、**v9c2 の両端は medium 86.1% と small 75.6%** であり pair/lecture ではなかった。pair と lecture が両端に来るのは **readiness 不合格の2世代(v9c・ablation)のみ**で、統制すると消える。所見の向きが変わったためチェックリストを訂正し、この対比を論文 §9 の readiness 変動の項目に含めた |
| 4 | low(run report の生成物) | run report に**本実験に存在しない条件を前提とした表が複数含まれている**。<br>・「Ceiling Effect Summary」が `No-Ed / Classroom / Tutoring` の3列構成で、**Tutoring 列が全タスク 0%**(本 run に tutoring 条件は無い)。この列を含めて `too_hard` / `unclear` が判定されている<br>・「Score by Learner Profile」の Ability / Misconception / Interest がすべて **`unknown` 52%**(v6 以降 `profile_json` は `type_key` のみ)<br>・「Heterogeneity Interpretation: classroom_advantage_under_homogeneity ✓」は v4 期のロジックの残骸<br>いずれも分析ドキュメントは引用していないため結論に影響しないが、**run report を一次資料として外部に示す場合は誤読の元になる** | **deferred**(2026-09-05): `lib/report.rb` の修正が必要。ablation は DB 紛失のため run report を再生成できず、**注記での対応になる見込み** |
| 5 | low | 「Misconception Correction by Condition」が **全5条件で 100% / 残存 0.0** と完全に一様。v9c2 では条件差があった。readiness の corrective note が全員に注入される設計(F1: 静的テンプレート)を考えると、この指標は本 run では条件を区別する情報を持たない | (記録のみ) |
| 6 | low(評価) | 分析ドキュメント §3 が「**決定的な帰属はできない**」「本 ablation が示すのは『是正バンドルが効いている』ことまで」と明示し、§4 で readiness 未達・pair n=2・単一 run・DB 不在をすべて限界として挙げている点は妥当。**論文 §9 にも明記されているという記述と整合**。フル査読対象の中で、自らの限界の記述はもっとも正確な部類 | (記録のみ) |

論文への波及: **所見1が論文 §4 の L6 記述(「re-routed to a semantic judge」)に直結**する。
所見3は論文 §8.2 の帰属議論に関わる。所見2・4・5 は ablation 文書と `lib/report.rb` 内に閉じる。

**監査査読の入口で参照すべき持ち越し一覧**:
- v7a/v9c/v9c2 所見 — 教材と readiness/評価タスクの系列重複(2世代連続の signature)
- v7b 所見2 — order_confused 型が未成立(論文 l.118/l.149/l.232)
- v8 所見3 — 監査表 F4 の分母に共通講義が混入
- v9b 所見1 — F3 の修正境界(v9c2 で解消を確認済み)
- v9c 所見2 — interpretation flags が閾値テストであること
- v9c2 所見1 — スモーク run と本番 run の取り違え
- **ablation 所見1 — semantic scorer の結果が `answer_correct` に書かれない(F2 の修正が別の失敗に化けている)**


## 確認したこと(masumi 記入)

- **生データ読了(2026-09-05)**: 一次資料である run report を通読し、分析ドキュメントの
  7項目すべてと一致することを確認。加えて `experiment_v9c2_ablation_smoke.db` の L6 評価行
  (`auto_scored=0` / `answer_correct=null` / `total=11〜20`)を目視し、所見1 を確認
- 垂直貫通: **本世代のみ完全な貫通は不可能**(DB 紛失により「計算 → DB」段が実施できない)。
  代替として 所見1 について 分析ドキュメント → run report → `lib/report.rb:584-603`(表の生成コード)
  → `lib/phases/evaluator.rb`(LLM 経路に `answer_correct` の設定が無い)
  → `git log -S"SEMANTIC_TASK_TYPES"`(導入日 2026-06-15 < 実施日 06-16)
  → ablation スモーク DB の実データ、という別ルートで貫通した

## 信頼で受け入れたこと(未検証)

- **run report の集計値そのもの**。DB が無いため独立に再計算できない。
  本世代の数値はすべて run report を信頼して受け入れている(トレース表は
  「分析ドキュメントが run report を正しく引用しているか」だけを確認したものであり、
  run report の集計が正しいかは検証していない)
- トークン 631,243 は chars/4 の推定値
- §2.3 の Memory Coverage / Memory Delta / Ownership の各集計
- readiness 53% を生んだ原因(所見2)。ランダム変動か系統的要因かは判別していない
- ablation スモーク DB(`experiment_v9c2_ablation_smoke.db`)が本番 run と同一のコード状態で
  実行されたかは未確認。所見1 の実証はこのスモーク DB に依拠している

## 見ないで書いた5行要約(masumi 記入)

> 2026-09-05 記入。v9c2 の査読中に本 ablation の分析ドキュメントを読んで書いたもの。
> トレース表の作成前に書かれているため、**エージェントの所見を見る前の理解**として保存する。

1. 何を操作したか:　ディスカッションの反復数を1にした
2. 何を測ったか:　クイズの正答率
3. 何が分かったか:　25ポイントまで差が広がったので、反復数がスコアに影響がある
4. 何が言えないか:　反復数のみが原因とは言えない、事前準備のスコアに差があったため
5. 次に何をすべきか:　事前準備のスコアを揃える

## チェックリストへの追記候補

- **バグ修正の「効いたこと」を、修正後の出力フィールドまで追って確認する**: F2(exact-match が
  自由記述を全滅させる)の修正として semantic scorer を導入したが、**その判定結果を書き込む
  フィールドが実装されていなかった**ため、症状(L6 = 0%)は修正前と区別がつかないまま残った。
  → **修正後も同じ数字が出ている場合、「修正が効かなかった」ではなく
  「修正の結果が届いていない」を先に疑う**
- **レポート生成コードのハードコード文字列を信用しない**: `lib/report.rb:584-603` は
  「LLM judge scores を使用」というヘッダと「exact-match only」という注記を、
  実際の採点経路と無関係に**両方とも常に出力する**。
  → **レポートの説明文は、生成コードを読んで実態と一致するか確認する**
- **run report に、その run に存在しない条件の表が残っていないか確認する**:
  ablation の run report は tutoring 列(全 0%)・learner profile の `unknown` 行・
  v4 期の heterogeneity 判定を含んでいた。**外部に一次資料として示す前に確認する**
- **DB を失った run は、垂直貫通が原理的に不可能であることを明記する**:
  本世代は「分析ドキュメント ↔ run report」の照合までしかできない。
  → **査読記録に「どこまで確認しどこからが信頼か」を必ず線引きして書く**
- **同じ2条件が毎回 spread の両端に来ていないか確認する**:
  〔2026-09-22 訂正〕初版は「v9c・ablation・v9c2 のいずれも pair と lecture が両端」と書いたが、
  **v9c2 は誤り**。DB 実測では v9c2 の両端は **medium 86.1% と small 75.6%** であり、
  pair(80.0)と lecture(83.3)はその内側にある。
  pair(n=2)と lecture(n=4)が両端に来るのは **v9c(65.0 / 27.5)と ablation(72 / 47)の2世代だけ**で、
  **どちらも readiness 不合格の run である**。統制された v9c2 ではこの構造が消える。
  → 訂正後の観察はむしろ論文の主張を**支持する**。教訓としては
  **spread を比較するときは両端がどの条件かを毎回確認する**(最小 n の条件が両端を占めていれば、
  比べているのは教育効果ではなくその条件の振れかもしれない)
