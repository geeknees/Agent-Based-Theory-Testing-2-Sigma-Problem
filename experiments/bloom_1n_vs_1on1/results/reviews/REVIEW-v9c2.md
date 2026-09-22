# v9c2 人間セルフ査読記録

査読者: masumi / 日付: 2026-09-05 / 所要: 25min
プロトコル: `docs/templates/human-review-protocol.md`(重み: **フル — 旗艦・査読の主戦場**)
位置づけ: v9c の監査で特定された交絡のうち、再実行でしか直せない5項目(A0/A3/A5/A6/A8)をすべて
修正した再実験。**readiness ゲートを初めて通過**(90%)し、discussion を5回独立反復し、
lecture_only に self-reflection を与え、L6 を main score から除外した。
主張の出典: `results/2026-06-15-v9c2-full-analysis.md`、論文 §4・§7。

**本世代に効く持ち越し**: v7a 所見1(教材と readiness タスクの重複)、v9b/v9c 所見(F3 の修正確認)、
v8 所見3(監査表 F4 の数え方)。

---

## エージェント準備: claim→evidence トレース表

run: `dc1bdd27`(`data/experiment_v9c2.db`)

| # | 主張(出典) | DB での検証結果 | 一致? |
|---|---|---|:---:|
| 1 | L6除外後: medium 86%・lecture 83%・large 81%・pair 80%・small 76%(§3.1) | 86.1 / 83.3 / 81.1 / 80.0 / 75.6%(試行 360/36/720/90/180) | ✅ |
| 2 | readiness: edge_case 100%・recall 91%・procedure_order 85%・rule_interaction 85%、全体 90%(§2.1) | 154/154・140/154・131/154・131/154、全体 556/616 = **90.3%** | ✅ |
| 3 | **A3**: 全discussion条件で unique discussions = 5/5(§2.3) | `learning_sessions` の `COUNT(DISTINCT transcript_json)` は4条件すべて **5**。**F4 は解消** | ✅ |
| 4 | **A5**: 各反復に新規 classroom_teacher を割り当て(§1) | `agents` の `classroom_teacher` = **20体**(4条件 × 5反復)。v9c までは1体 | ✅ |
| 5 | learner type 別 96/95/77/58%(§3.4) | edge_case_dropper 96.0・rule_extractor 95.4・order_confused 76.9・passive_listener 57.6 | ✅ |
| 6 | calibration: high-confidence wrong 2%・棄権 4%(§3.5) | 1.6% / 3.7%(四捨五入で一致) | ✅ |
| 7 | L6 は全154件 0(§7) | 0/154 | ✅ |
| 8 | §2.1 の v9c 比較値「recall 79%・rule_interaction 43%・procedure_order 36%」 | **v9c 本番は 68% / 50% / 59%**。記載値は **`experiment_v9c2_smoke.db` の値と完全一致**(所見1) | ❌ |
| 9 | §5 の v9c「High-confidence wrong 15%」 | v9c 実測 **12.9%**(所見4) | ❌ |

## 横展開チェック(§3)エージェント下ろし分

- **A0(F3)の修正確認**: `run_experiment_v9c2.rb:251-261` が `learner_memories:` を
  `SizedDiscussion.run` に渡していることをコードで確認済み(v9b 査読時)。§2.2 の発話サンプルも
  「Red (pos 1): contributes 0, doubles the next token's base value…」と**ルールを前提にしている**。
  v9b/v9c の「I don't have the rules」型は消えている。**F3 は解消**
- **実効n(F4)**: 解消(トレース3)。ただし**分析単位は discussion-level n=5** であり、
  §3.2 と §6-1 が自ら「推測統計には不十分」と明記している。**条件間 10pp 差は記述統計にとどまる**
- **予算・量の非対称(F5c)**: **残存**。教育トークンは lecture_plus_self_reflection **2,716** vs
  discussion 各条件 **35k〜46k**(約1/15)。§3.3.1 と §6-2 が自認
- **条件名の不一致(プロトコル §0 の既知例)**: DB 内は `lecture_only`、文書上は
  `lecture_plus_self_reflection`。**§ヘッダで明示されており意図的**。§8 で次 run での確認が
  タスク化されている
- **天井/床**: `explanation_choice`(95-100%)と `peer_error_detection`(99-100%)が天井。
  10タスク中2タスクが条件差の情報を持たない。L6 は main score 除外
- **A5 の evaluator triplication は意図的に未実装**(§6-4)。全タスクが文字列 `expected_answer` を
  持つため `Evaluator.score` が LLM 分岐に到達せず no-op になるという理由づけは、
  `lib/phases/evaluator.rb` の実装と整合する
- **§6 の番号が飛んでいる**(1,2,3,4,**6**,7 — 5 が欠番)

## 所見(エージェント検出分。処置の判断は masumi)

| # | 深刻度 | 内容 | 処置 |
|---|--------|------|------|
| 1 | **high(比較基準の取り違え)** | §2.1 の「v9c との比較」に使われている数値が、**v9c ではなく v9c2 自身のスモーク run のもの**である。<br>記載: recall **79%** → 91%、rule_interaction **43%** → 85%、procedure_order **36%** → 85%<br>`experiment_v9c2_smoke.db`: recall **79%**、rule_interaction **43%**、procedure_order **36%** — **3項目とも完全一致**<br>`experiment_v9c.db`(本番): recall **68%**、rule_interaction **50%**、procedure_order **59%**<br>正しい比較は recall +23pp(記載+12pp)、rule_interaction +35pp(記載+42pp)、procedure_order **+26pp**(記載 **+49pp**)。<br>方向は一律ではなく、**procedure_order の改善幅がほぼ2倍に誇張**され、recall は過小評価されている。<br>さらに**同一文書内で矛盾している**: §5 の比較表は v9c の readiness pass rate を **69%**(正しい)としている。§2.1 と §5 が別々の v9c を参照している | **fixed**(2026-09-05): §2.1 の3項目を v9c 本番の実測値に修正し、誤りの出所(v9c2 スモーク run)と文書内不一致を注記 |
| 2 | **high(持ち越し v7a 所見1 の本丸)** | 論文 §4 は v9c2 の readiness 通過を「**The readiness gate passed. 90%(edge_case 100%, recall 91%, procedure_order 85%, rule_interaction 85%)— the first generation to clear the gate, so the condition contrast is, for the first time, measured over learners who genuinely held the prerequisites**」と記述している。<br>しかし **readiness 4問中2問は、答えが固定講義に worked example として載っている**:<br>`rc_recall_01` `[Yellow, Green]`→7 ↔ `fixed_lecture_v9c.md` l.62-65「Score: 7」<br>`rc_edge_case_01` `[Red, Blue]`→0 ↔ 同 l.81-84「Score: 0」<br>そして **pass rate 上位2つがこの2問**: edge_case **100%(154/154)**・recall **91%**、対して掲載なしの procedure_order・rule_interaction はともに **85%**。v9c でも同じ順序だった(100/68 vs 59/50)。<br>**2世代連続で「掲載あり」が上位を占め、edge_case は両世代とも全員正解**。<br>ただし v9c 査読と同様、評価タスク側には同じ signature が出ない点は留保として残る。<br>→ 「genuinely held the prerequisites」という論文の表現は、**少なくとも edge_case と recall については、講義に載っていた答えを再生できたことを意味しうる**。論文・分析ドキュメント・アドエンダムのいずれにも重複への言及がない | **deferred**(2026-09-05): 論文 §4 の記述に関わるため、**監査・論文査読で文面を確定する**。持ち越し一覧の最上位 |
| 3 | **medium(主結論の足場)** | §9 は「Readiness 統制下では class size・ownership・discussion 有無のいずれも明確な効果を示さなかった」を最も堅固な知見としている。方向としては妥当だが、**「効果がない」を支える n が明示されていない**。<br>・分析単位は **discussion-level n=5**。§3.2 と §6-1 が「推測統計には不十分」と自認<br>・比較の基準となる `lecture_plus_self_reflection` は **n=4**(学習者4名、反復なし)。§3.2 の discussion-level SD 0.333 は5条件中最大<br>・教育トークンは基準条件だけ **1/15**(F5c 残存)<br>つまり「差がない」という主張は、**最も小さく最も不均等な条件を基準にして立てられている**。<br>§9 の表現「大きな主効果は確認されなかった」は正しいが、**「効果がないことを示した」とは読めない**。論文がこれをどう引用しているか要確認 | **deferred**(2026-09-05): 論文 §7・§9 の null の表現と一体で判断する |
| 4 | low | §5 の比較表で v9c の High-confidence wrong が **15%** と記載されているが、DB 実測は **12.9%**。v9c2 側(2%、実測1.6%)は一致。改善幅「-13pp」は実際には -11.3pp | **fixed**(2026-09-05): §3.5 を実測値に修正 |
| 5 | low | §6 の限界リストの番号が **1,2,3,4,6,7** と飛んでおり **5 が欠番**。項目が削除された痕跡と思われる。フル査読対象の文書としては、削除されたのが何だったかを確認するか番号を振り直すべき | **fixed**(2026-09-05): §6 に欠番である旨の項目5を挿入(内容の復元は不能のため記録のみ) |
| 6 | low(評価) | **A0・A3・A5 の修正はいずれも DB で実効性を確認できた**: discussion の独立反復 5/5、classroom_teacher 20体、participant 発話がルール前提。v9c の監査で「再実験でしか直せない」とされた項目が実際に直っている。<br>また §4.2 が「v8/v9b/v9c で3 run 連続observed された『medium 最低』パターンが v9c2 で逆転(medium 最高)」を報告し、**過去のパターンが交絡由来だった可能性の実証的裏付け**としている論法は妥当。ただし §6-6 が自ら「best-of-5 の偶然かもしれない」と留保している点も含めて整合的 | (記録のみ) |

論文への波及: **所見2が本命**。論文 §4 の readiness 通過の記述に注記が要るか、監査・論文査読で判断する。
所見3は論文が v9c2 の null をどう表現しているか(§7・§9)に依存。所見1・4・5 は v9c2 分析ドキュメント内に閉じる。

**監査査読の入口で参照すべき持ち越し一覧**:
- v7a 所見1 / v9c 所見1 / **v9c2 所見2** — 教材と評価・readiness タスクの系列重複(**2世代連続で readiness 上位2項目が掲載あり**)
- v7b 所見2 — order_confused 型が未成立(論文 l.118/l.149/l.232)
- v8 所見3 — 監査表 F4 の分母に共通講義が混入
- v9b 所見1 — F3 の修正境界(**v9c2 で解消を確認済み**)
- v9c 所見2 — interpretation flags が閾値テストであること
- v9c2 所見1 — スモーク run と本番 run の取り違え(**監査表の run_id 対応表と突き合わせる**)

## 確認したこと(masumi 記入)

- **生データ読了(2026-09-05)**:
  - **A0 の効果**: `pair_discussion_size_2` の contribution ターンが「Red (pos 1): contributes 0,
    doubles the next token's base value…」とルールを前提にした計算過程になっている。
    v9b/v9c の「I don't have the rules」型の発話は消えている
  - **所見2の現物**: 固定講義 l.62-65 / l.81-84 の worked example と、
    `rc_recall_01` / `rc_edge_case_01` の expected_answer が一致することを確認。
    その2項目が readiness pass rate の上位2つ(100% / 91%)であることも確認
- L6 自由記述の目視判定: 未実施(本 run は L6 を main score から除外しており、
  v8・v9b で同じ構図を確認済みのため)
- 垂直貫通: 所見1について 分析ドキュメント §2.1 → v9c 本番 DB → **v9c2 スモーク DB** まで辿り、
  記載値が本番ではなくスモークの値と完全一致することを特定。
  あわせて A0/A3/A5 の是正が DB 上で実効していること(unique discussions 5/5、teacher 20体、
  発話内容)を確認

## 信頼で受け入れたこと(未検証)

- 総トークン 2,376,593 は DB 未照合(chars/4 推定)
- §3.2 の discussion-level SD / learner-level SD の算出ロジック。**分析単位変更の妥当性は
  本査読の核心だが、計算式そのものは未読**
- §3.3.1 Token-normalized Score の教育フェーズトークン集計
- §3.6 Fine-Grained Memory Coverage(10 items)・§3.7 Memory Delta の集計ロジック
- §2.4 Ownership スコアの算出式。特に lecture_plus_self_reflection の 2.0 が
  discussion の 3.0 と同じ尺度上にあるかは未検証(所見3 の前提に関わる)

## 見ないで書いた5行要約(masumi 記入)

1. 何を操作したか:　事前学習の精度を揃えた
2. 何を測ったか:　　同様にスコアを測定した
3. 何が分かったか:　10ポイント程度の差で思ったより差がなく、スコアに対しては事前学習の影響が高そう。学習者タイプの違いがスコアに影響を与えていそう。
4. 何が言えないか:　ディスカッションや、主体的な方が成績が良いとは言えないし、その逆も言えない
5. 次に何をすべきか:　ディスカッション数を調整する

## チェックリストへの追記候補

- **前世代との比較値は、参照先の DB を名指しで確認する**: v9c2 §2.1 は「v9c」として
  **自分自身のスモーク run** の値を引用していた。スモーク DB と本番 DB が同じ命名規則で
  並んでいるため取り違えやすい(`experiment_v9c.db` / `experiment_v9c_smoke.db` /
  `experiment_v9c2.db` / `experiment_v9c2_smoke.db`)。
  → **世代間比較の表を見たら、引用元の run_id を監査表の対応表で照合する**
- **同一文書内で同じ前世代の数値が2箇所以上に出てきたら突き合わせる**: v9c2 は §2.1 で
  スモーク、§5 で本番を参照しており、文書内で基準が食い違っていた
- **null を主張する側の n を数える**: 「効果が確認されなかった」は、**比較の基準になった条件**の
  n と予算を見て評価する。v9c2 の基準条件は n=4・反復なし・SD 最大・教育トークン 1/15 だった。
  **null の強さは、最も弱い条件の強さで決まる**
- **是正が実効したかを DB で確認する**: v9c2 の A0/A3/A5 は
  「発話内容」「`COUNT(DISTINCT transcript_json)`」「`agents` の role 別件数」で
  それぞれ確認できた。**是正項目リストは、対応する DB クエリとセットで持つ**
