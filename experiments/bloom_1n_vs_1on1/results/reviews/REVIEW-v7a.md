# v7a 人間セルフ査読記録

査読者: masumi / 日付: 2026-08-09 / 所要: ____
プロトコル: `docs/templates/human-review-protocol.md`(重み: 軽 — **講義長交絡の確認は必修**)
位置づけ: v6 で passive_listener が hetero_classroom(1/8)より 1on1(3/8)で高得点だった件の機構切り分け。
全学習者を passive_listener に揃え、「強制インタラクション」条件(classroom_forced_checkin)を新設して
public_qa / forced_checkin / 1on1 の3条件を比較。
主張の出典: `results/2026-05-23-v7a-analysis.md`、`results/2026-06-08-v7a-v7b-methodology-addendum.md`。

---

## エージェント準備: claim→evidence トレース表

run: `dd2fd888`(`data/experiment_v7a.db`、v7a 専用DB)

| # | 主張(出典) | DB での検証結果 | 一致? |
|---|---|---|:---:|
| 1 | public_qa 88%・forced_checkin 53%・1on1 50%(§3.1) | 87.5% / 53.1% / 50.0%(各32試行) | ✅ |
| 2 | 学習者別内訳12名(§3.2) | 12名すべて一致(public_qa 7/8/7/6、forced 5/4/5/3、1on1 5/5/4/2)。※ 分析ドキュメントは「末尾8桁」と表記しているが実際は**先頭8桁** | ✅(表記のみ要修正) |
| 3 | タスク別正答率8タスク×3条件(§3.3) | 23セル一致、**1セル不一致**: `l5_debug_03` の forced_checkin は 3/4 ではなく **2/4**。列合計も 18 になり §3.1 の 17 と矛盾する(所見2) | ⚠️ |
| 4 | 誤解修正率: public_qa 0%・forced 0%・1on1 75%(§3.4) | `corrected_misconceptions` 非空は 1on1 で 3/4 = 75%、classroom 系は 0/4 = 0% | ✅ |
| 5 | 全学習者 passive_listener 型(§2) | `agents.profile_json.type_key` は3条件12名すべて passive_listener | ✅ |
| 6 | 講義長 public_qa 3,599 chars / forced_checkin 1,022 chars(§2.1) | public_qa **3,599**(完全一致)、forced_checkin は **1,060**(38字差。数え方の違いと思われる) | ✅(実質一致) |

## 横展開チェック(§3)エージェント下ろし分

- **講義長交絡(必修項目)**: 実測で確認。public_qa 3,599 chars vs forced_checkin 1,060 chars。
  §6.1 が「対応済み(`Under 200 words` 削除)」としているのは**次回以降のラン**の話であり、
  **本ランの結果は交絡したまま**。分析ドキュメント自身がこれを明記している(§5.1・§8)
- **実効n(F4)**: `learning_sessions` は classroom 系で1講義を4行複製(distinct=1)。v5・v6 と同じ構造
- **1on1 のレート制限中断**: §6.2 記載のとおり。当該学習者 `de3fcfe6` が 2/8 で最低スコアである点は事実
- **experiment_runs.created_at は 2026-05-21**、分析ドキュメントの実施日表記は 05-23。
  レート制限待機で複数日にまたがったためと思われる(§6.2 と整合)

## 所見(エージェント検出分。処置の判断は masumi)

| # | 深刻度 | 内容 | 処置 |
|---|--------|------|------|
| 1 | **high(測定の妥当性・全世代に波及)** | **評価タスクの一部が、講義の worked example と完全に同一**。`domains/zarn_tokens/lesson.md` の Example B は `[Green, Blue, Yellow]` → 各トークンの内訳付きで **Score: 14**。これは評価タスク `l1_recall_01`(expected_answer `14`)と系列・答え・途中式まで一致する。`eval_tasks_v2/v3/v4/v8` すべてに存在するため **v2〜v8 の全世代**が該当。<br>さらに v9c 以降の固定講義 `fixed_lecture_v9c.md` では悪化しており、**評価10問中3問**(`l1_recall_01`=Example 1→14、`l2_edge_case_01`=Example 2→0、`l6_induction_02`=`[Red, Yellow]`→14)と、**readiness check 4問中2問**(`rc_recall_01`=`[Yellow, Green]`→7、`rc_edge_case_01`=`[Red, Blue]`→0)、**mastery check 3問中2問**が、答え付きの worked example として講義本文に載っている。<br>**学習者の解答がこれを自認している**: public_qa の `cfa45527` は `used_memory` に「Example [Green,Blue,Yellow]=14 **directly confirms**」と書き、reason を「Matches stored example exactly」で締めている。`4b82e49a` は「Yellow base score of 7 **inferred from example, not explicitly stated**」。つまり L1 は「ルールを適用できるか」ではなく「**worked example がメモリ圧縮を生き延びたか**」を測っている。<br>影響: (a) 条件間比較は全条件が同じ講義を受けるため**直接には無効化されない**が、(b) 絶対スコアは押し上げられており、(c) 論文 §4「readiness gate passed(90%、recall 91%、edge_case 100%)」を「prerequisites を genuinely 保持していた証拠」として読む根拠が弱まる。readiness 4問中2問が答え付きで講義に載っている。<br>現状、論文・分析ドキュメント・方法論補遺のいずれにも**この重複への言及がない** | **deferred**(2026-08-09): 影響範囲が v9c の readiness gate と監査に及ぶため、文面確定は v9c・監査・論文のフル査読と合わせて行う。**監査査読の入口で必ず本所見を参照する** |
| 2 | low | §3.3 タスク別表の `l5_debug_03` / forced_checkin が 3/4 と記載されているが DB は **2/4**。この列の合計は 18 となり、§3.1 の総正答数 17 と矛盾する。§8 の結論には影響しない | **fixed**(2026-08-09): §3.3 を 2/4 = 50% に修正。あわせて §3.2 の見出し「末尾8桁」→「先頭8桁」も修正 |
| 3 | **medium(条件の成立)** | `classroom_forced_checkin` の check-in は**実質的に何も伝えていない**。トランスクリプトの `checkin_correction` ターンは4名全員が **`"Correct."` の8文字のみ**。全員が確認問題に正答したため、教師が伝えた矯正情報はゼロ。<br>したがって本条件は「強制インタラクション」ではなく、実態は「**短い講義 + 情報量ゼロの一往復**」。§8 の結論1「forced_checkin ≈ 1on1 → パーソナライゼーションの追加価値は小さい」は、**インタラクション条件が成立していない**まま導かれている。<br>加えて、4名全員が check-in には正答したのに評価では 53% しか取れていない点は、v6 の「誤解修正とスコアの乖離」と同じパターン | **fixed**(2026-08-09): §8 結論1 に条件が成立していない旨を追記 |
| 4 | low(所見1の補強・チェックリスト項目の実証) | v6 査読で追加した「基底値カバレッジ」チェックが v7a で**4世代目の再発**として効いた。`l1_recall_01` の条件別正答は public_qa 3/4・forced_checkin **0/4**・1on1 3/4 だが、これはメモリ内の基底値と一対一で対応する: forced_checkin の4名は `rules` に Yellow の得点が**一人も入っておらず**、2名は解答で明示的に棄権し(`"Yellow has no score rule in memory"`)、1名は 19、1名は 5 と誤答。1on1 で正答した3名は全員 `rules` に「Yellow = 7」を保持、唯一失敗した `de3fcfe6` のみ欠落。public_qa で唯一失敗した `3ea352ea` は Yellow=7 を持つが **Green の基底値2を持たず**、解答で「no base score rule exists for active Green」と書いて 12 と答えている。→ **L1 の条件差は教育形式ではなく基底値カバレッジで完全に説明できる** | (記録のみ) |

論文への波及: **所見1は論文本体に開示が必要**な可能性がある(§3 のドメイン記述、または §6 の限界)。
所見2・3は v7a 分析ドキュメント内に閉じ、いずれも修正済み。所見1は v9c/監査/論文のフル査読に持ち越し(deferred)。

## 確認したこと(masumi 記入)

- 生データ読了(2026-08-09): **所見1の現物**を突き合わせ。
  - `fixed_lecture_v9c.md` l.112-116 `### Example 1: [Green, Blue, Yellow] → 14` ↔
    `eval_tasks_v8.json` l.3-8 `l1_recall_01` / expected_answer `"14"` — 系列・答え・途中式が一致
  - 同 l.62-65 `[Yellow, Green]` → Score: 7 ↔ `readiness_check_tasks_v9c.json` l.3-6 `rc_recall_01` / `"7"`
  - 同 l.81-84 `[Red, Blue]` → Score: 0 ↔ 同 l.13-16 `rc_edge_case_01` / `"0"`
  - 両タスクの `learner_prompt` は「Use only your memory of the rules. Do not assume rules you were
    not taught.」と指示しているが、講義に答えが載っている以上この指示は制約として機能しない
- 垂直貫通: 所見1について 講義本文 → 評価/readiness タスク定義 → 学習者の解答テキスト(`used_memory`)まで
  3層を貫通。`cfa45527` の「Example [Green,Blue,Yellow]=14 directly confirms」「Matches stored example
  exactly」が、worked example を参照して解答したことの学習者自身による記録

## 信頼で受け入れたこと(未検証)

- トークンコスト(§3.6)は DB 未照合。`token_tracker.rb` の char 数推定値
- §3.5 の ceiling 分類表(report.rb 再生成版)。分類ロジック自体は追っていない
- §5.3 のレート制限中断が `de3fcfe6`(2/8)のスコアに与えた影響。中断の事実は記録にあるが影響の有無は検証不能
- v7b の結果全般。本ファイルは v7a のみを対象とする

## 見ないで書いた5行要約(masumi 記入)

1. 何を操作したか:　passive_listenerとorder_confusedの数値が動いた理由の分析をするため、v7aではpassive_lisnterに絞って強制的なやり取りか個別対応が効くか分析した
2. 何を測ったか:　上記の変数を変更しタスク別正答率を測定した
3. 何が分かったか:　強制的な介入は効果が薄かった。一方でインタラクションない1方通行の講義が最も効果があった。
4. 何が言えないか:　1on1がClassroomを上回るとは言えない、なぜならインタラクション講義がもっと文字数が長く、インタラクションより情報量が評価されている可能性がある。
5. 次に何をすべきか:　主体的な関わりについての考察を深めることと、実験の正当性を引き続き検証すること

## チェックリストへの追記候補

- **教材と評価問題の重複を必ず突き合わせる**: 評価タスクの入力系列が、講義・lesson・固定講義の
  worked example に答え付きで載っていないかを、世代ごとに機械的に照合する。v7a では
  `lesson.md` の Example B がそのまま `l1_recall_01` であり、v9c 以降は評価10問中3問・
  readiness 4問中2問が該当した。**学習者の `used_memory` フィールドを読むと自認していることがある**
- **条件名を信用せず、その条件で実際に何が起きたかをトランスクリプトで確認する**:
  `classroom_public_qa` は全員 `question_asking_probability = 0.0` のため質問が1件も発生しておらず
  (質問ターンは4件とも `No questions.`)、実態は一方向講義のみ。
  `classroom_forced_checkin` の矯正ターンも全員 `"Correct."` の8文字で情報量ゼロだった。
  **条件名が設計意図を、トランスクリプトが実際を語る**
- **交絡の「修正済み」表記は、どのランに効くのかを確認する**: v7a §6.1 は `Under 200 words` 削除を
  「対応済み」と書いているが、これは次回以降のランの話であり本ランの結果は交絡したまま。
  修正コミットの日付と run の実施日を比べる
