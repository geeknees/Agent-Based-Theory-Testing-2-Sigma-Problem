# v6 人間セルフ査読記録

査読者: masumi / 日付: 2026-07-30 / 所要: 30min
プロトコル: `docs/templates/human-review-protocol.md`(重み: 軽)
位置づけ: v5 の反省を受け、learner heterogeneity を**プロンプト上のロールプレイから post-LLM
メモリ制約(ハード)に転換**。7種の learner type を導入し、tutoring を「診断→修正→再テスト」に変更。
主張の出典: `results/2026-05-21-v6-analysis.md`、論文 §3・§5.1、日誌 05-21。

---

## エージェント準備: claim→evidence トレース表

run: `cd5d2f0e`(`data/experiment.db`、v1–v6 共有DB)

| # | 主張(出典) | DB での検証結果 | 一致? |
|---|---|---|:---:|
| 1 | homo 94%・hetero 59%・1on1 59%・no_ed 0%(分析ドキュメント §3.1) | 93.8% / 59.4% / 59.4% / 0.0%(32/32/32/24試行) | ✅ |
| 2 | homo は全員 edge_case_dropper、hetero/1on1 は同一4type構成(§2.1) | `profile_json.type_key`: homo=edge_case_dropper×4、hetero/1on1=rule_extractor・edge_case_dropper・order_confused・passive_listener 各1名 | ✅ |
| 3 | type別ペア比較: rule_extractor 5/8=5/8、edge_case_dropper 6/8=6/8、order_confused 7/8→5/8(−25pp)、passive_listener 1/8→3/8(+25pp)(§3.2) | 4組すべて DB と完全一致 | ✅ |
| 4 | variance: hetero 0.329 > 1on1 0.157 > homo 0.072 > no_ed 0.000(§3.4) | **垂直貫通実施**: per-learner 正答率から sample std を再計算し4条件すべて完全一致(hetero=[0.625,0.125,0.875,0.75]、1on1=[0.625,0.75,0.375,0.625]) | ✅ |
| 5 | 1on1 の誤解修正率 75%、classroom 0%(§3.5) | 1on1 4名のうち3名が `corrected_misconceptions` 非空(passive_listener のみ空)=75%。classroom はフィールド自体は存在し全員空=0% → **スキーマ欠落による見かけの0%ではない** | ✅ |
| 6 | メモリ語数の実測値12名分(§2.3) | 12名すべて一致(homo 80/79/87/73、hetero 116/88/89/71、1on1 98/118/89/74) | ✅ |

補足(トレース5の含意): 1on1 で **+25pp 改善した passive_listener は、誤解修正が1件も行われていない
唯一の学習者**。逆に修正が行われた order_confused は −25pp 悪化している。§5.6「誤解修正とスコアの乖離」は
この対応関係として読むとさらに強い。

## 横展開チェック(§3)エージェント下ろし分

- **実効n(F4)の実物確認**: `learning_sessions` は classroom 条件で **1つの講義を学習者ごとに4行複製**して
  保存している(v5・v6 とも `distinct_lectures=1`)。`unique_discussions = 1` の実体がこれ。
  トークン報告値(homo 1,651)も1講義分として整合する。トランスクリプトを行数で数えると4倍に
  過大計上されるため、集計時は注意が必要
- **交絡(§6.2 で自認済み)**: homo(94%)は「edge_case_dropper に最適化された授業」を受けており、
  homo vs hetero の 94 vs 59 は type構成・教師指示・の2変数が同時に動いている。論文 §5 は
  この点を「an efficiency artifact of asymmetric design, not a clean format comparison」として明記済み
- **天井(§3-1)**: homo 93.8% は天井に接近(8/8 が2名)。ただし v6 の主要比較は hetero vs 1on1(59% vs 59%)
  であり天井の影響外
- **type あたりの n**: 各 type は**条件あたり1名**。±25pp は「1名 vs 1名、8問」で2問分の差(所見1)

## 所見(エージェント検出分。処置の判断は masumi)

| # | 深刻度 | 内容 | 処置 |
|---|--------|------|------|
| 1 | **medium(論文の事実誤り)** | 論文は ±25pp のヘッジとして「the ±25-point figure itself is a v6 **n=4-per-type** result」と書いている(`2026-06-16-paper-draft.md` l.149 / `.tex` l.431)。しかし DB では各 type は**条件あたり1名**(hetero 4名 = 4 type 各1名、1on1 も同じ)。n=4 は「条件あたりの学習者数」であって type あたりではない。したがって ±25pp は 1名 vs 1名・8問での2問分の差であり、ヘッジ節が実際より信頼性を高く見せている。査読者がここを検算すると数値が合わない。修正案: 「an n=1-learner-per-type result (8 tasks each; ±25 points = 2 items)」 | **fixed**(2026-07-31): md l.149 / tex l.431 の両方を「rests on a single learner per type per condition — 8 tasks each, so ±25 points is a 2-item difference」に差し替え |
| 3 | **medium(操作の妥当性)** | `order_confused` の中核操作 `rule_order_retention: 0.2` は、実装上「`rules` 配列を 80% の確率で `shuffle` する」だけ(`learner_types.rb`)。しかし (a) LLM が JSON 配列の並び順を「適用手順」として読む保証はなく、(b) 実際の手順が書かれた **`strategy` フィールドはシャッフル対象外**である。v6 の 1on1/order_confused のメモリでも strategy に「check its activation condition first, then modifiers」と正しい順序がそのまま残っていた。→ order_confused 型は**操作が実質空振りしていた可能性**があり、同型が hetero で 7/8(全 type 中最高)を取ったことと整合する。v7b はこの型の 1on1 悪化を「介入のミスマッチ」で説明しているが、その前に型が成立していたかを疑う必要がある | (masumi 判断 / v7b 査読へ持ち越し) |
| 2 | low | v6 の classroom では**質問が1件も出ておらず、`answers` ターンが生成されていない**(homo/hetero 両方)。v5 では両条件で `answers` ターンが生成されている。つまり v6 の classroom education は「講義のみ」で Q&A を含まない。確率的には homo 0.8⁴ × hetero (0.7×0.8×0.6) ≈ 14% で偶然の範囲であり、質問ゲート(`LearnerTypes.should_ask_question?` = `rand < prob`)にバグはない。ただし分析ドキュメント §5.2 が order_confused の −25pp を「共有講義では全員に対して体系的にルールが提示された」と説明する際、その講義が Q&A なしの一方向講義だった事実は記載がない。また v5→v6 のスコア上昇(hetero 41%→59%)を「classroom 側の教育量」では説明できない(むしろ減っている)ことの根拠にもなる | (masumi 判断) |

論文への波及: 所見1は**論文本体を修正済み**(md・tex の両方)。所見2は v6 分析ドキュメント内に閉じる。
所見3は v7b の前提に関わるため、v7b 査読に持ち越す。

## 確認したこと(masumi 記入)

- 生データ読了(2026-07-31): **passive_listener と order_confused のメモリ4件**(hetero / 1on1 × 2type)を目視。
  - passive_listener の hetero メモリは `rules` が発火条件のみで、**Blue=5・Green=2・Yellow=7 の基底点が1つも入っていない**。
    1on1 では3つとも入っている → +25pp の機構は「対話が効いた」ではなく**基底点がメモリに残ったかどうか**
  - passive_listener の hetero メモリは `examples: []`。予算80語の `trim_to_budget` で全削除されている
  - order_confused は 1on1 で `corrected_misconceptions`・`remaining_misconceptions` が埋まった分、
    予算100語を圧迫して `examples` が3本→1本に減っている → −25pp は**採点例が押し出された**結果として読める
  - メモリ語数は 1on1 の方が多い(98 vs 89)のに得点は低い → 量ではなく**何が残ったか**
- 垂直貫通: トレース #4(variance)を per-learner 正答率から sample std で再計算し §3.4 と完全一致(エージェント準備)。
  加えて操作の実体を `learner_types.rb` の `apply_constraints` / `trim_to_budget` までソースで確認し、
  上記の生データ所見(examples が先に消え rules が最後まで残る)が削除優先順位と整合することを確認

## 信頼で受け入れたこと(未検証)

- トークン消費量(§3.5)は DB 未照合。`token_tracker.rb` は char 数からの推定値(`CHARS_PER_TOKEN = 4.0`)で
  API 実測値ではなく、フェーズ単位でしか保持されない
- タスク別スコア表(§3.3)の個別セル。集計値と type 別ペアは照合済みだが、L1〜L6 の内訳までは追っていない
- v6 で誤解修正が「正しく」行われたかの中身。`corrected_misconceptions` の**有無**は DB で数えたが、
  その記述が実際に誤概念を直しているかは評価していない

## 見ないで書いた5行要約(masumi 記入)

1. 何を操作したか: 学習者の多様性を表現するため、プロンプトの表現に加えて記憶力として、実際のLLMの出力をまとめたあとに削る、また質問するかしないかのフリ米を変える
事をした
2. 何を測ったか:　多様性の条件を変更したうえで前回と同様にスコアを測定した
3. 何が分かったか:　同一性の高いクラスルームが最高得点、多様性が高いクラスと1on1が同一スコア、学習なしはゼロ点、また1on1の場合はできる生徒とできない生徒の分散が少ない
4. 何が言えないか:　なぜこうした差が生まれたのかはわからなかった、n=1 の事例であり信頼が薄い
5. 次に何をすべきか:　違いの大きかった order_confused　と passive_listener に注目して条件を深堀りした

## チェックリストへの追記候補

- **基底値カバレッジのチェック(v5 から継続・3世代連続で再発)**: v4(classroom memory に Yellow=7・
  active Green=2 が欠落)、v5(L1/L6 の床は「Yellow が教えられていない」)、v6(passive_listener の
  hetero メモリに基底点が皆無)。**得点差を教育形式や学習者特性に帰属する前に、まず memory に
  基底値が残っているかを確認する**。3世代で同じ機構が主要因だった以上、これは最初に見るべき項目
- **操作が実体として効いているかをソースで確認する**: 「多様性を導入した」と書かれていても、
  v5 はプロンプト2行(しかも learner 側には ability も misconception も渡っていない)、
  v6 の order_confused は配列 shuffle のみで strategy は無傷、という差がある。
  **分析ドキュメントの操作名ではなく、その操作を実装しているコードまで降りて効果の実在を確認する**
- **自分が一番おもしろいと思った所見の n を数える**: v6 の「均質化効果(±25pp)」は本査読で
  最も示唆的な発見だったが、type あたり1名・8問中2問の差だった。**発見の魅力と統計的強度は逆相関しやすい**
