# v4 人間セルフ査読記録

査読者: masumi / 日付: 2026-07-20 / 所要: 25min
プロトコル: `docs/templates/human-review-protocol.md`(重み: 軽)
位置づけ: 最初の本番run。classroom/1on1/no_educationの3条件比較、feedback loop付きtutoring初導入。
主張の出典: `results/2026-05-16-v4-analysis.md`、開発ログ問題5〜6、論文§5.1。

---

## エージェント準備: run マップ(experiment_runs テーブルより)

| run_id(先頭8桁) | 実施日時 | 構成 | 備考 |
|---|---|---|---|
| 4e926902〜896509b5(6件) | 05-15 00:36〜07:17 | n=1/1/1 → n=6/6/4 | スモーク〜レート制限期の試行錯誤 |
| e0f24255 | 05-15 12:33 | n=4/4/3 | 直前の縮小試行 |
| **19b39e20** | 05-15 12:38 | n=4/4/3 | **本番run**(分析ドキュメント記載の run_id と一致) |

## エージェント準備: claim→evidence トレース表

| # | 主張(出典) | DB での検証結果 | 一致? |
|---|---|---|:---:|
| 1 | classroom 47%・1on1 28%・no_education 0%(分析ドキュメント §3.1) | 19b39e20: classroom 32試行47%、1on1 32試行28%、no_education 24試行0% | ✅ |
| 2 | tutoringにfeedback loopを実装(4 exchange/8ターン、開発ログ問題6) | commit `4c67b96`(05-15 09:32)のコメントで Exchange1(教授)→Exchange2(診断Q1)→Exchange3(フィードバック+修正)→Exchange4(診断Q2)の4構成を確認。19b39e20 の1on1トランスクリプトも turns配列長=8で一致 | ✅ |
| 3 | L5をdebugging形式に、L6を簡略化(開発ログ問題4) | `eval_tasks_v4.json`: l5_debug_03(task_type=debugging, difficulty=L5)、l6_induction_02(task_type=short_rule_induction, difficulty=L6)を確認。v1–v3査読で見た counterexample 形式の l5_counterexample_01 からの置き換えを確認 | ✅ |
| 4 | レート制限対応で21時間かけて完走(開発ログ問題5) | run_id 8件のcreated_atが05-15 00:36〜12:38の約12時間に分散——開発ログの「約21時間」(2回のrate limit待機×5.5h含む)との整合は created_at だけでは検証不能(DB挿入時刻であり、sleep中は新規行が生まれないため経過時間の下限しか分からない)。優先度低、要ならログファイル(あれば)で裏取り | ⚠️ 未検証(検証手段なし) |

## 横展開チェック(§3)エージェント下ろし分

- **天井/床(§3-1)**: v4本番のタスクタイプ別スコアをDBで算出し、分析ドキュメント §3.3 の per-task 表と**完全一致**を確認(classroom: recall 0/4・edge_case 4/8・rule_interaction 1/4・debugging 10/12・short_rule_induction 0/4 / 1on1: 0/4・3/8・0/4・6/12・0/4)。床タスク(L1 recall・L6 induction 全条件0%、L3 rule_interaction ほぼ0%)は分析ドキュメント §4.4「too_hard タスクの分析」で認識・解釈済み → **新規所見なし、床チェックはクリア**
- **scorer artifact(§3-2)**: L6(short_rule_induction)0/4 は既知の F2(exact-match artifact)。v4時点では未発見だが後の監査で説明済み → v4固有の対応不要
- **実効n(§3-3)**: v4は pseudoreplication(F4)の影響下(classroom は unique_discussions=1)。監査表で既記録 → v4分析ドキュメントに遡及注記があるか §4 で確認推奨

## 所見(エージェント検出分。処置の判断は masumi)

| # | 深刻度 | 内容 | 処置 |
|---|--------|------|------|
| 1 | low | 分析ドキュメント §4.4 冒頭「L1, L3, L6 が全条件 0%（too_hard）」だが、L3(rule_interaction)は classroom 1/4=25% で「全条件0%」は不正確(1on1 は 0/4)。DB・同ドキュメント §3.3 の表とも矛盾(表では classroom L3=1/4 と正しく記載)。§4.4 の要約文だけが過度に丸めている。 | **fixed**(2026-07-20): §4.4 を「L1, L6 が全条件0%、L3 がほぼ0%(classroom のみ 1/4=25%)」に修正。あわせて masumi の memory 目視確認(下記)で判明した「classroom memory に Yellow=7・active Green=2 の基底値が欠落」を L1 床効果の具体的機構として §4.4 に追記 |

## 確認したこと(masumi 記入)

- 生データ読了(2026-07-20):
  - **1on1 トランスクリプト ×1**(19b39e20, learner 1ecba40c): 8ターン・feedback loop の実物を確認。
    学習者が Exchange2/Exchange1 で **2回**「active Green が何点か分からない」と明言 → tutor が Exchange3 の
    feedback で「token table に Green=2 と載っている」と修正。**L1 床効果(memory に基底値が残らない)の生き証拠**。
    ただし tutor は毎回ルールを提示しており、tutoring 条件では tutor 側がルールを補完している構造が見える
  - **classroom memory ×1**(19b39e20): 4フィールドスキーマ(rules/mistakes/strategy/edge_cases)は整っているが、
    **rules に Yellow=7 も active Green=2 も基底値が入っていない**。→ L1 `[Green, Blue, Yellow]` が
    解けない直接原因。§4.4 の「memory 形成の不完全さ」を具体化 → 所見1の修正に反映済み
- 垂直貫通: トレース #1(メイン数値)を DB で再計算し分析ドキュメント §3.1 と一致確認済み(エージェント準備)

## 信頼で受け入れたこと(未検証)

- 特になし

## 見ないで書いた5行要約(masumi 記入)

1. 何を操作したか:　1on1とClassroomでの学習率の計測をした
2. 何を測ったか:　特定の課題に対する回答の正答率
3. 何が分かったか:classroom 47% > 1on1 28% > no_education 0% で、Bloom の予測(1on1 >> 集団)と逆の結果になった。
no_education が 0% なので memory-only 設計は機能している。
4. 何が言えないか:この逆転を「Bloom理論の反証」とは言えない。
ここの1on1は4 exchange固定で mastery criterion(正解するまで教え続けるループ)がなく、Bloomが研究した本物のmastery tutoringとは別物。
加えて n=4 で統計的にも不安定、そもそもエージェントと人間の振る舞いが異なることがわかってきている。
5. 次に何をすべきか:　結果が予想外だった事に関する要因の検証

## チェックリストへの追記候補

- (記入)
