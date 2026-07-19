# 人間セルフ査読プロトコル — 世代ごとの内容確認手順

出自: conspiracy_family_transmission の human-review-protocol.md(2026-07-17)を、本リポジトリの
実態と失敗史(F1–F5 監査 `results/2026-06-08-v4-v9c-replication-confound-audit-table.md`、
開発ログ `results/2026-05-16-development-log.md`、査読前修正計画 `docs/2026-07-13-pre-review-fix-plan.md`)
に合わせて適合させたもの。
用途: 各世代(v4〜v9c2、ablation)について、**masumi 自身が**内容を読み、理解し、
書かれている内容が間違っていないことを確認するための手順書。エージェントによる監査の代替ではなく、
**他者に査読を依頼する前提として自分が中身を保証できる状態**を作るためのもの。
査読の記録は `experiments/bloom_1n_vs_1on1/results/reviews/REVIEW-<vN>.md` に残す(様式は §5)。

> **原則: 「全部読む」ではなく「主張を垂直に貫通する」**
> 全文通読は時間がかかる割に理解の保証にならない。主要な主張を3つ以内選び、
> それぞれを 主張 → 分析ドキュメント → report → 計算コード → DB の一本で貫通させる。
> 3本貫通できれば残りは横展開の確認で足りる。貫通なしの通読は「読んだ」であって「確認した」ではない。

---

## 0. 準備(5分)

- [ ] 対象世代の成果物一式の場所を確認:
      分析ドキュメント `results/2026-*-<vN>-analysis.md` /
      run report `data/runs/<run_id>/report.md`(または `scripts/regen_report.rb` で再生成)/
      DB `data/experiment_<vN>.db` / `data/runs/<run_id>/scores.csv` /
      計算コード `lib/report.rb`・`lib/scorer.rb` / 設計プラン `docs/superpowers/plans/` / 日誌 `docs/journal/`
- [ ] run_id ↔ DB の対応は監査表(`results/2026-06-08-v4-v9c-replication-confound-audit-table.md`)の
      対応表で確認する
- [ ] この世代で**途中方針転換があったか**を日誌・設計プラン・git log で確認。
      あった場合、転換前ナラティブの残骸を横展開チェック(§3-10)の必須項目に加える。
      既知の例: v7a の「Under 200 words」削除(run 後)、v9c2 の `lecture_only` →
      `lecture_plus_self_reflection` 改名(DB 内は旧名のまま)
- [ ] エージェント側の監査(F1–F5 チェック、査読前修正計画)が済んでいることを確認。人間査読はその後段

## 1. 生データを先に読む(スコアより先に。20〜30分)

scorer / evaluator の判定を見る**前に**、自分の目で判断する。順序が重要 — 先にスコアを見ると引きずられる。

- [ ] **学習者2〜3名**(条件が異なるものを選ぶ)について、教育フェーズのトランスクリプトと
      生成されたメモリ JSON を DB から読む(クエリは付録A)。
      討論条件なら「学習者は実際にルールを語っているか」を見る — F3(メモリ未注入で
      "I don't actually know the rules" と発話)はこの読み方でしか捕まらなかった
- [ ] 各学習者について、主要 DV に相当する自分の判断をメモに書く
      (例: 「このメモリで L4 debugging は解けるはずか?」「この討論でこの学習者は何かを新しく学んだか?」)
- [ ] その後 scorer のスコアと突き合わせる。**自分の判断と scorer が食い違った箇所は
      そのまま REVIEW.md の所見にする** — scorer 妥当性への最重要シグナル
- [ ] **L6(short_rule_induction)の自由記述回答を2〜3件読み、意味的に正しいか自分で判定する。**
      exact-match scorer が3世代にわたり正答を全滅させていた(F2)のは、まさにこの手順で発覚した

## 2. 垂直貫通チェック(主張3本。30〜60分)

- [ ] 分析ドキュメントから**主要な主張を3つ以内**選ぶ(条件間比較の結論、目玉の所見、null の宣言)
- 各主張について:
  - [ ] **主張 → report**: 分析ドキュメントの文が run report のどの表・どの数値に対応するか特定する
  - [ ] **report → 計算**: その数値が `lib/report.rb` / `lib/scorer.rb` のどの計算から出るか特定し、
        計算が主張の意味と一致しているか読む(条件名ハードコードで v5 と v9c2 の表が壊れた前歴がある)
  - [ ] **計算 → DB**: その数値を**パイプラインを通さず独立に再計算**する
        (sqlite3 の 5 行クエリで出し、分析ドキュメントの数値と一致するか確認。
        3本のうち最低1本は必須。ひな形は付録A)
  - [ ] 途中で「なぜこうなるか説明できない」箇所があれば、**そこが理解の穴** — 解消するまで先へ進まない

## 3. 横展開チェック — この研究でエージェントが実際に間違えた問い(15〜30分)

7世代の失敗史を「人間が自問する形」に変換したもの。分析ドキュメントと report を見ながら:

- [ ] **天井/床**: 全条件 ≥90% または ≤数% のタスクはないか。あれば「情報量ゼロ」として
      扱われているか(v1 全問満点、v3 L6 全条件 0% の教訓)〔開発ログ問題1・4〕
- [ ] **scorer artifact**: 自由記述タスクを exact-match で採点していないか。L6 の扱い
      (main score 除外/semantic scorer)はこの run で正しく適用されているか〔F2〕
- [ ] **実効 n**: 「n=」は学習者数か討論数か。discussion-level SD の N を見て、
      条件比較が pseudoreplication に乗っていないか〔F4 — v4〜v9c を6世代汚染した最重要項目〕
- [ ] **予算・量の非対称**: 条件間で教育の「量」(講義長・ターン数・トークン)は揃っているか。
      揃っていない場合、分析はそれを明示しているか(v7a の講義長 3,599 vs 1,022 chars、
      v9c2 A6 の約1/15 トークンの教訓)〔F5c〕
- [ ] **readiness ゲート**: `readiness_failed` フラグを確認したか。failed なら条件比較の主張が
      適切に制限されているか(v9c の 37pp を「保留」できたのはこのフラグがあったから)
- [ ] **interpretation flags は閾値テストであって有意性検定ではない** — "supported" の語を
      そのまま結論に書き写していないか
- [ ] **丸めと分母**: 目についたパーセントを1つ選び、分子/分母を DB で確認する
      (v9c small の 23/40=57.5% が 57 とも 58 とも表記されうる、の類)
- [ ] **トークン数は chars/4 の推定(±20%)** — コスト比較の主張がこの精度に耐えるか
- [ ] **計算済みだが未使用のデータ**で、結論と矛盾しうるものはないか
      (report 内の使われていないセクション、`runs/` 配下の未参照ファイルを ls して確認)
- [ ] 方針転換があった場合: 転換前の指標・条件名・ナラティブへの参照が残っていないか
      (DB 内条件名と文書内条件名の不一致は v9c2 で既出 — 意図的なら明記されているか)

## 4. 理解テスト — 見ないで要約を書く(10分)

外部査読者への説明の予行演習。分析ドキュメントを**閉じて**、自分の言葉で5行:

1. 何を操作したか(独立変数と条件)
2. 何を測ったか(主要 DV と測定器 — memory-only 評価の仕組みを含めて)
3. 何が分かったか(主結果を1文で)
4. **何が言えないか**(限界を1文で)
5. 次に何をすべきか

- [ ] 書けない行があった → 該当箇所へ戻って解消してから完了とする
- [ ] 書いた要約は REVIEW.md に転記(外部依頼時の説明文の種になる)

## 5. 記録 — REVIEW.md の様式

「確認したこと」と「信頼で受け入れたこと」を分けるのが要点。外部査読を依頼するとき、
どこまで自分が保証しどこからが未検証かを開示できる。

```markdown
# <vN> 人間セルフ査読記録

査読者: masumi / 日付: YYYY-MM-DD / 所要: X時間

## 確認したこと
- 生データ読了: learner <id> ×3(条件: …)。自分の判断 vs scorer: 一致 n / 不一致 n
- L6 自由記述の目視判定: n 件(semantic に正しい/誤り の内訳)
- 垂直貫通: <主張1> / <主張2> / <主張3>(独立検算: <どの数値>を sqlite3 で再計算、一致)

## 信頼で受け入れたこと(未検証)
- 例: プロンプト全文は未読 / learner type 制約の実装詳細はテストに依拠 /
  エージェント監査(F1–F5)の網羅性に依拠

## 所見
| # | 深刻度(high/med/low) | 内容 | 処置(fixed / accepted-risk / wont-fix + 理由) |

## 見ないで書いた5行要約
(§4 の出力)

## チェックリストへの追記候補
(新しい失敗パターンを見つけた場合。本テンプレートと監査表に反映する)
```

## 6. 運用ノート

- **時間の目安: 合計 1.5〜2.5 時間/世代。** これを超えて全読しようとしているなら冒頭の原則に戻る
- **重査読の条件(強い主張ほど強い査読)**:
  - **フル査読**: v9c(37pp という見かけの強い効果)、**v9c2(旗艦・査読の主戦場)**、
    ablation(帰属の要)、F1–F5 監査文書、論文 §6〜§9
  - **標準**: v8、v9b(null 寄りの結果)
  - **軽査読(流れの理解で可)**: v4〜v7 — 論文では各1段落の扱い。ただし v7a は
    講義長交絡の「解釈上の制約」を自分の言葉で言えること
- **論文固有の2箇所**は世代査読と別枠で必ず自分の目で確認する:
  **AI involvement statement**(自分の認識と一致しているか — ここだけは AI が代弁できない)と
  **§9 Limitations**(「これで全部だと思うか」)
- **エージェントの使い方**: 査読の代行はさせない。使ってよいのは
  (a) claim→evidence トレース表の生成(読む場所への案内。判断は人間)、
  (b) 独立検算クエリの下書き(突き合わせは人間)、
  (c) 読了後に分析ドキュメントの内容について**人間へ質問させる**(理解の抜き打ちテスト役 — 口頭試問)
- **新パターンを見つけたら**このプロトコルと監査表に追記する。育たないチェックリストは同じ穴に落ちる

---

## 付録A: 独立検算・生データ読みのクエリひな形

`cd experiments/bloom_1n_vs_1on1/data` して実行。`<RUN>` は run_id 先頭8桁、DB は §0 の対応表参照。

```bash
# (1) 条件別正答率 — 分析ドキュメントのメイン表の独立再計算(v9c2 は L6 除外に注意)
sqlite3 experiment_<vN>.db "
SELECT ta.condition, COUNT(*),
       ROUND(100.0*SUM(json_extract(e.score_json,'\$.answer_correct'))/COUNT(*),1)
FROM task_attempts ta
JOIN evaluations e ON e.attempt_id=ta.id
JOIN evaluation_tasks et ON et.id=ta.task_id
WHERE ta.run_id LIKE '<RUN>%' AND et.task_type != 'short_rule_induction'
GROUP BY ta.condition ORDER BY 3 DESC;"

# (2) readiness / mastery check の pass rate
sqlite3 experiment_<vN>.db "
SELECT check_type, COUNT(*), SUM(answer_correct),
       ROUND(100.0*SUM(answer_correct)/COUNT(*))
FROM mastery_check_results WHERE run_id LIKE '<RUN>%' GROUP BY check_type;"

# (3) learner type 別スコア(v6 以降)
sqlite3 experiment_<vN>.db "
SELECT json_extract(a.profile_json,'\$.type_key'),
       ROUND(100.0*SUM(json_extract(e.score_json,'\$.answer_correct'))/COUNT(*))
FROM task_attempts ta JOIN evaluations e ON e.attempt_id=ta.id
JOIN agents a ON a.id=ta.learner_id
WHERE ta.run_id LIKE '<RUN>%' GROUP BY 1 ORDER BY 2 DESC;"

# (4) 生データ読み: 学習者のメモリ JSON(§1 用)
sqlite3 experiment_<vN>.db "
SELECT learner_id, memory_json FROM learner_memories
WHERE run_id LIKE '<RUN>%' LIMIT 3;" | head -50

# (5) 生データ読み: 討論/授業トランスクリプト(§1 用)
sqlite3 experiment_<vN>.db "
SELECT condition, substr(transcript_json,1,2000) FROM learning_sessions
WHERE run_id LIKE '<RUN>%' LIMIT 2;"

# (6) L6 自由記述回答の目視判定用(§1 用)
sqlite3 experiment_<vN>.db "
SELECT ta.condition, ta.response_text
FROM task_attempts ta JOIN evaluation_tasks et ON et.id=ta.task_id
WHERE ta.run_id LIKE '<RUN>%' AND et.task_type='short_rule_induction' LIMIT 3;"

# (7) 実効 n の確認(F4): 条件ごとのユニーク討論数
sqlite3 experiment_<vN>.db "
SELECT condition, COUNT(*), COUNT(DISTINCT transcript_json)
FROM learning_sessions WHERE run_id LIKE '<RUN>%' GROUP BY condition;"
```

注意: (5)(7) の `transcript_json` はスキーマにより列名が異なる場合がある
(`.schema learning_sessions` で確認)。ablation(a551c74d)は DB 紛失のため、
検算対象は `results/2026-06-21-v9c2-ablation-ndisc1-run-report.md`(verbatim)と
`data/runs/a551c74d…/scores.csv` になる。

## 付録B: 世代別の査読対象ファイル早見表

| 世代 | 分析ドキュメント | DB | 重み |
|------|----------------|-----|------|
| v1–v3 | (なし — 開発ログ問題1〜4 + 日誌 05-13/14) | `experiment.db`(v1: ab4061b6 / v2: 4b1ac552 / v3 smoke: 4cdac451, d0d20f77, ab268bd8) | 軽(測定装置の成立過程として) |
| v4 | `2026-05-16-v4-analysis.md` | `experiment.db`(19b39e20) | 軽 |
| v5 | `2026-05-17-v5-analysis.md` | `experiment.db`(02070b48) | 軽 |
| v6 | `2026-05-21-v6-analysis.md` | `experiment.db`(cd5d2f0e) | 軽 |
| v7a | `2026-05-23-v7a-analysis.md` | `experiment_v7a.db` | 軽(講義長交絡は必修) |
| v7b | `2026-05-23-v7b-analysis.md` | `experiment_v7b.db` | 軽 |
| v8 | `2026-05-29-v8-analysis.md` | `experiment_v8.db` | 標準 |
| v9b | `2026-06-04-v9b-full-analysis.md` | `experiment_v9b.db` | 標準 |
| v9c | `2026-06-06-v9c-full-analysis.md` | `experiment_v9c.db` | **フル** |
| 監査 | `2026-06-08-*-audit-table.md` + 各補遺 | (全DB) | **フル** |
| v9c2 | `2026-06-15-v9c2-full-analysis.md` | `experiment_v9c2.db` | **フル** |
| ablation | `2026-06-21-v9c2-ablation-ndisc1-analysis.md` | (紛失 — run report で代替) | **フル** |
| 論文 | `2026-06-16-paper-draft.md` / `.tex` | — | **フル**(特に §6〜§9) |
