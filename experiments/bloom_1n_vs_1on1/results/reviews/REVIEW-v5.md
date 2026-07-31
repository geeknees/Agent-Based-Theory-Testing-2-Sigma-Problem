# v5 人間セルフ査読記録

査読者: masumi / 日付: 2026-07-25 / 所要: 30min
プロトコル: `docs/templates/human-review-protocol.md`(重み: 軽)
位置づけ: learner heterogeneity を初導入。「異質な学習者集団なら 1on1 が効くか?」という
対抗仮説(均質性説)の検証。プロファイルは**プロンプト埋め込み**方式(v6 で post-LLM 制約に転換)。
主張の出典: `results/2026-05-17-v5-analysis.md`、論文 §5.1、日誌 05-17。

---

## エージェント準備: run マップ

| run_id(先頭8桁) | 実施日時 | 構成 | 備考 |
|---|---|---|---|
| 5c0c1e93 | 05-16 11:57 | n=1 系 | スモーク |
| **02070b48** | 05-17 00:25 | n=4/4/4/3 | **本番run**(分析ドキュメント記載の run_id と一致) |

## エージェント準備: claim→evidence トレース表

| # | 主張(出典) | DB での検証結果 | 一致? |
|---|---|---|:---:|
| 1 | homo 44%・hetero 41%・1on1 38%・no_ed 0%(分析ドキュメント §3.1) | 02070b48: homogeneous_classroom 44%、heterogeneous_classroom 41%、1on1 38%、no_education 0%(いずれも32/32/32/24試行) | ✅ |
| 2 | homo は全員同一プロファイル、hetero/1on1 は4種の異プロファイル(分析ドキュメント §2.2) | agents.profile_json: homo=4名で distinct=1、hetero=4名 distinct=4、1on1=4名 distinct=4、no_ed=profile なし | ✅ |
| 3 | hetero と 1on1 は**同一プロファイル構成**を使い教育形式のみ比較(分析ドキュメント §2.1) | 両条件のprofile_json集合が完全一致(high/none, low/applies_modifiers_before_activation, medium/forgets_edge_cases, medium/thinks_blue_always_active の4種)| ✅ |
| 4 | heterogeneity penalty(homo > hetero、-3pp)(分析ドキュメント §8) | 44% vs 41% = 3pp 差を確認。ただし n=4、1問=3.1pp なので誤差範囲(要 §3 で解釈確認) | ✅(数値)/⚠️(解釈) |
| 5 | 1on1 が variance 最大(分析ドキュメント §3.4) | **垂直貫通実施**: per-learner correct% を DB で再計算し sample std を算出 → 1on1 0.177 > homo 0.125 > hetero 0.063 > no_ed 0.000、分析ドキュメント §3.4 と**完全一致**。ただし 1on1 の 0.177 は1名(0.625)と2名(0.25)が作る値で、n=4 では単一学習者に極端に依存 | ✅(値一致)/⚠️(n=4脆弱) |

## 横展開チェック(§3)エージェント下ろし分

- **プロファイル多様性(F5a)**: hetero/1on1 は4種の異プロファイル、homo は均質——**設計どおり**。ただし
  プロファイルは**プロンプト埋め込み**であり、v5 の最大の教訓は「LLM の基礎能力は変わらないため
  プロファイルがほぼ機能しない」(日誌 05-17)。この解釈が分析ドキュメントに明記されているか §1/§4 で確認推奨
- **交絡(homo の非対称)**: homo_classroom は「全員同一誤概念」に最適化された授業を受けており、
  homo vs hetero の差(44 vs 41)は型構成と指示の差が混在(v6 分析 §6.2 で後に明示化される論点)
- **実効n(F4)**: classroom 系は pseudoreplication の影響下(監査表で既記録)

## 所見(エージェント検出分。処置の判断は masumi)

| # | 深刻度 | 内容 | 処置 |
|---|--------|------|------|
| 1 | medium | 分析ドキュメント §5.4 は「thinks_blue_always_active を持つ 1on1 学習者が 5/8 を達成したのは tutor が誤概念を明示修正できたから」と帰属している。しかし5点のうち2点は L1 recall (`[Green, Blue, Yellow]`=14) と L6 induction (`[Yellow, Orange, Green]`=11) で、**どちらも誤概念修正では説明できない**。L6 には Blue が一切登場せず誤概念は無関係、L1 も Green が左にあるため誤概念があっても答えは変わらない。両タスクに共通して必須なのは **Yellow=7 の基底値**であり、v5 全15名のうちこれをメモリに保持していたのはこの学習者1名のみ(classroom 系12名は全員欠落)。L1・L6 を解けたのも全条件でこの1名のみ。→ 真の機構は「誤概念修正」ではなく「**ルールカバレッジの完全性**」 | **fixed**(2026-07-25): §5.4 の見出しと本文を書き換え、§8「新たに確認できたこと」項目3 を「tutoring の得点差はルールカバレッジで決まっていた」に差し替え |
| 2 | low | 分析ドキュメント §6.3「tutoring session の coverage 不均一性」は仮説として書かれているが、**直接証拠が存在する**: `1on1/low/applies_modifiers_before_activation` のメモリ edge_cases に「黄色のルールは不明。次回のセッションで確認事項として扱う」が明記されており、4 exchange が Yellow に到達しなかったことが学習者自身の言葉で残っている。所見1と合わせて、v5 の L1/L6 床効果は「タスクが難しすぎる」のではなく「**Yellow が教えられていない**」で説明できる | **fixed**(2026-07-25): §6.3 に証拠段落を追記 |
| 3 | low | §6.2「プロファイルは演技にすぎない」の**実物証拠**: hetero_classroom の high/none と low/applies_modifiers のメモリは rules・mistakes・strategy がほぼ同一内容(文言の微差のみ)。一方 1on1 では high と low で明確な質差がある(high は「最後の緑は0点でも青を有効にする条件は満たす」まで到達、low は「緑は常に有効」という**誤り**を含み Yellow 欠落)。→ プロファイルは**学習者側の能力差としては機能せず、tutor 側の適応経路でのみ効いている**。この解釈は論文 §3(l.118)で「v6 で representation level に移して heterogeneity を real にした」として既に正しく扱われており、論文側の修正は不要 | **wont-fix**: §6.2 が既に同旨を記述しており結論に影響しない |

### 所見3 追記(2026-07-31、v6 査読中にソースで確認)

観察(メモリが似ていた)だけでなく、**実装上の直接証拠**がある。`lib/profiles.rb` のプロファイル注入は非対称:

- `to_tutor_context`(tutor 向け) — ability・interest・**misconception(`CRITICAL:` 付きで内容まで明示)**・learning_style・attention の5項目すべて
- `to_learner_context`(学習者本人向け) — **interest と attention の2項目のみ**

つまり `ability: low` の学習者も、`misconception: applies_modifiers_before_activation` の学習者も、
**その事実を自分では一度も知らされていない**。日誌 05-17 の「LLM の基礎能力は変わらないためプロファイルが
機能しない」という解釈は、半分は**実装の非対称性の結果**である。加えて tutor は誤概念の正解を
プロンプトで直接受け取っているため、v5 の tutoring は「診断」を経ずに答えを知った状態だった。

論文への波及: **なし**。論文 §5 は v5 の §5.4 帰属を引用しておらず、逆に「misconception correction は score と decoupled」(v6 証拠)を採用済み。所見1・2の影響範囲は v5 分析ドキュメント内に限定される。

## 確認したこと(masumi 記入)

- 生データ読了(2026-07-25): **hetero と 1on1 の high/low メモリ4件**を目視。
  - hetero の high と low がほぼ同一内容 → low ability プロファイルがメモリの質を落としていない(所見3)
  - 1on1 では high/low に明確な差 → 差を作っているのは学習者の ability ではなく **tutor が何をどこまで教えたか**
  - `1on1/low` に「黄色のルールは不明」が明記されている → coverage 欠落の直接証拠(所見2)
- 垂直貫通: トレース #5(variance)を DB で per-learner 再計算し §3.4 と完全一致を確認(エージェント準備)。
  加えて所見1で L1/L6 の expected_answer をタスク定義まで遡り、Yellow=7 必須を確認

## 信頼で受け入れたこと(未検証)

- トークン消費量(§3.5、tutoring が classroom の4倍)は DB 未照合
- §5.5「classroom が L4 debugging で強い(4/4 vs 1/4)」のメカニズム解釈(タスク別スコア自体は §3.3 表として存在)

## 見ないで書いた5行要約(masumi 記入)

1. 何を操作したか: 学習者の多様性を確認するためlearner heterogeneity を導入。4条件に分岐させた
2. 何を測ったか:　v4と同様の正答率
3. 何が分かったか:　異質性を入れても1on1はClassroomに勝てない。副産物として「1on1のvariance効く人に効き、効かない人に効かない」というが出た。
4. 何が言えないか:　tutorの適応度を測っており、学習者の能力差は実際履かれていない。同様のことが人で再現できるかどうかは言えない
5. 次に何をすべきか: 学習者の能力差を図れる多様性に関する条件を調整する

## チェックリストへの追記候補

- **基底値カバレッジのチェック**: 床タスク(全条件0%)を見たら「タスクが難しい」と結論する前に、
  そのタスクの expected_answer に必要な基底値(Yellow=7 など)が memory に残っているかを必ず確認する。
  v5 では L1/L6 の床が「Yellow が教えられていない」で説明でき、タスク難易度の問題ではなかった。
  → v4 の同種所見(classroom memory に Yellow=7・active Green=2 が欠落)と同じパターンであり、**世代を越えて再発している**
- **「効いた学習者」の帰属を疑う**: ある学習者が高得点を取った理由を誤概念修正などに帰属する前に、
  その学習者が解けた個別タスクが本当にその機構を要求しているかをタスク定義まで遡って確認する