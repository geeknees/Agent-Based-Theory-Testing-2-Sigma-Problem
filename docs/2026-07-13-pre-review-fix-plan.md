# 査読依頼前の総点検:指摘事項と修正計画

**作成日:** 2026-07-13
**目的:** 論文(md/tex)を外部研究者に査読依頼する前に、AI エージェントによる全体チェックで見つかった誤り・矛盾を修正する。
**チェック方法:** 論文本文(md 311行 / tex 928行)の全数値・主張を、`results/` の世代別分析レポート、監査表、ドメイン定義(`lesson.md`)、git 履歴、リポジトリメタデータ(CITATION.cff / .zenodo.json / README)と突合した。

---

## P1 — 査読依頼前に必須(3件)

### 1. AI 執筆の明記(未対応)

論文・メタデータのどこにも AI による執筆・実験実施の開示がない。git コミットの trailer(`Co-Authored-By: Claude Sonnet 4.6` 等)には残っているが、論文を読む査読者には見えない。

**修正:**
- [ ] 論文(md/tex 両方)に **AI involvement statement** を追加。位置は著者ブロック直下または Acknowledgements。内容の要素:①実験コード・実験実施・分析・論文本文の執筆が LLM エージェント(Claude、モデル名明記)によって行われたこと ②人間(川崎)の役割(研究の発案、方向づけ、レビュー、最終責任)③エージェント自身が被験体でもあるという本研究特有の二重性への言及(査読者が必ず気にする点)
- [ ] `CITATION.cff` / `.zenodo.json` の description にも同趣旨を1文追加
- [ ] `README.md` / `README.ja.md` のステータス注記に追記
- [ ] 依頼先ジャーナル/venue の AI ポリシー確認(多くの venue は「AI は著者になれないが、開示すれば利用可」)

### 2. 「per-run databases are released」が事実と矛盾

論文は md L8「Full code, configs, **per-run databases**, and version-by-version analyses are released」、md L257 / tex L49, L792 でも同様に主張。しかし `.gitignore` が `data/*.db` と `data/runs/` を除外しており、**DB はリポジトリに含まれていない**(README は正しく「gitignore 対象」と記載——論文と README が矛盾)。

**修正(どちらか選択):**
- [ ] **案A(推奨):** 全本番 run の DB を Zenodo デポジットに含めて公開し、論文の記述を維持。その場合、v9c2 の DB では条件名が `lecture_only` のまま記録されている(rename は run 後)ことの脚注を論文に追加
- [ ] **案B:** 論文の3箇所(md L8, L257 / tex L49, L792)を「databases available from the author」等に修正

### 3. ablation run(a551c74d)の一次資料が存在しない

論文は ablation の具体的数値(25pp spread、pair 72% vs lecture 47%、readiness 53%、631,243 tokens、n=34)を §8.2・§9・Appendix A で報告しているが:
- `results/` に ablation の分析ドキュメントがない(他の全 run にはある)
- DB は gitignore 対象で検証不能
- README の「報告された数値は results/ 内の分析ドキュメントに記載」という再現性の約束が ablation については破れている
- experiments README の Results and Analysis 索引にも ablation の行がない

**修正:**
- [ ] ablation run の DB の所在を確認し、`regen_report.rb` でレポートを再生成して数値を検証
- [ ] `results/2026-06-XX-v9c2-ablation-ndisc1-analysis.md` を作成(実施日はDBのタイムスタンプから確定)
- [ ] experiments README の Results index と Experiment Versions 表に追記
- [ ] 研究日誌(docs/journal/)にも該当日のエントリがない——実施日確定後に追記

---

## P2 — 整合性・正確性(4件)

### 4. Abstract「two of which decompose into sub-confounds」が本文と矛盾

Abstract(md L18 / tex L76)は「five families of confound (F1–F5, **two of which** decompose into sub-confounds, for seven specific threats in total)」。しかし §6(md L177 / tex L503)は「F5 decomposes into F5a/b/c」のみ。分解するのは **1 ファミリーだけ**(F1+F2+F3+F4+F5a/b/c = 7 threats)。

**修正:**
- [ ] md/tex 両方の Abstract を「one of which decomposes」に修正(または F1–F4 を列挙して 7 の内訳を明示)

### 5. §8.5「4–24×」のコスト倍率の導出が不明

「Tutoring and large discussions cost 4–24× the tokens of lecture/self-reflection」——この数値はどの分析ドキュメントにも存在しない。v9c2 の実測から再計算すると:条件合計では 12.9〜16.9×(35,035〜45,775 vs 2,716)、per-learner では 0.6〜6.7×。どちらの解釈でも「4–24×」にならない。

**修正:**
- [ ] 導出根拠を確認。再現できなければ実測値ベースに書き換え(例:「13–17× at the condition level」)。tutoring を含む倍率なら対象世代(v5: 35,095 vs 8,180 ≈ 4.3× など)を明示

### 6. 「population-multiplication」の用語衝突

§5.3(v9b の説明)で「v9b introduced the **population-multiplication** design (instantiating 2/4/8/16-learner classes)」とあるが、論文の他の全箇所(Abstract、§6 F4→A3、§7、結論)では同語を「n_disc 独立討論による真の反復」(v9c2 で導入)の意味で使っている。v9b にあったのはクラスサイズの個体数展開であり、A3 の反復設計ではない。査読者が「v9b で導入済みなら F4 は何だったのか」と混乱する。

**修正:**
- [ ] §5.3 の v9b の記述を「class-size instantiation」等の別語に変更(md L169 / tex 対応箇所)

### 7. 「7世代」のカウント方法が2通り混在

- タイトル・Abstract:「seven design generations (**v3–v9c2**)」= v3,v4,v5,v6,v7,v8,v9* で 7(v9b/c/c2 を1世代扱い)
- §5:「We summarize **seven production generations**」で v4,v5,v6,v7a+b,v8,v9b,v9c の表(v9b と v9c を別カウント、v3 と v9c2 は含まず)

どちらも「7」になるが数え方が異なり、注意深い査読者は必ず気づく。

**修正:**
- [ ] §5 冒頭に世代の数え方を1回定義する脚注を追加(例:「v7a/v7b は同一世代の2実験、v9b/v9c/v9c2 は v9 系の3イテレーション」)し、タイトルの "Seven-Generation" との対応を明示

---

## P3 — 軽微(4件)

### 8. v9c2 分析ドキュメントの「4項目」誤記

`results/2026-06-15-v9c2-full-analysis.md` §1:「再実行でしか解決できない**4項目**(A0/A3/A5/A6/A8)」——列挙されているのは **5項目**。

- [ ] 「5項目」に修正

### 9. A コード列挙の不一致(A4 の扱い)

- 論文 §7:「v9c2 applies **A0/A3/A4/A5/A6/A8**」(6 コード、A4=already satisfied を含む)
- experiments README:「v9c confound fixes (**A0/A3/A5/A6/A8**)」(5 コード)
- v9c2 分析ドキュメント:同上 5 コード

- [ ] どちらかに統一。推奨:実装変更は 5 コード、A4 は「既充足の確認」と明記する書き方に揃える

### 10. DOI 表記の混在(要確認)

- README バッジ:`10.5281/zenodo.21186082`(concept DOI)
- README 引用文・CITATION.cff・README.ja:`10.5281/zenodo.21186083`(version DOI)

Zenodo の標準パターン(バッジ=concept、引用=version)なら問題ないが、意図的か未確認。

- [ ] 両 DOI が resolve することを確認し、意図的なら現状維持(README に concept/version の注記を足すとより親切)

### 11. (任意)乱数シード未制御を Limitations に追記

learner type 制約(エッジケース脱落・順序シャッフル)は確率的だが RNG シードを固定していない(improvement proposals R1 で自己指摘済み)。Appendix C は「レポートは凍結 DB から再生成できる」と正確に限定しているが、run レベルの再現性について査読者に聞かれる前に §9 に1文足しておくと防御的。

- [ ] §9 に「run-level stochasticity is not seed-controlled; exact re-runs are not bit-reproducible(reports are, from frozen DBs)」相当を追加

---

## 検証して問題がなかった項目(修正不要)

以下は論文と一次資料の突合で一致を確認済み:

- **メイン数値全世代:** v4(0/47/28%)、v5(0/44/41/38%)、v6(0/94/59/59%、type別 ±25pp、修正率75%)、v7a(88/53/50%、講義長 3,599/1,022 chars)、v7b(69/47/41%、修正率100%)、v8(83/78/70/68%)、v9b(60/60/48/47/45%、Δmemory≈0)、v9c(65/57/52/40/28%、readiness 69%、recall 68%・rule_interaction 50%、type差 8pp = 52% vs 44%)、v9c2(86/83/81/80/76%、readiness 90%、type差 38pp = 96% vs 58%)
- **v9c2 トークン効率表:** 2,716/45,775/42,590/41,580/35,035 tokens、11.05/1.57/3.19/7.46/16.67 per 1k——分析ドキュメントと一致、算術も検算済み
- **Appendix A の run_id・n・トークン数:** 監査表・各分析レポートと全一致(v9b smoke `9b599c12` 含む)
- **Zarn Tokens のルール記述と worked example:** `lesson.md` と一致(Red base 3・貢献0、[Green, Red, Yellow, Blue]→21、stacking→0)
- **md / tex の数値整合:** 主要数値をスポットチェックし乖離なし
- **監査スクリプトの公開:** `check_replication.py` / `check_confounds.py` は scripts/ に存在
- **6/15 のバグ修正(748c6b7)の影響:** 4件とも表示・命名・将来run向けの修正で、v9c2 の測定値自体は不変。分析ドキュメントは修正後(68c1167)に更新済み

---

## 進め方の提案

1. P1-1(AI 開示)と P1-2(DB 公開方針)は方針決定が必要——masumi の判断待ち
2. P1-3(ablation)は DB の所在確認から。見つからない場合、ablation の記述を「予備的・非公開データ」に格下げするか再実行するかの判断が必要
3. P2/P3 は機械的に修正可能(md と tex の両方を忘れずに)
4. 全修正後に md→tex の数値再突合を1回

---

## 適用結果(2026-07-13)

**方針決定:** DB は「文言修正で対応」(masumi 選択)。調査の結果、DB はリポジトリ未収載かつローカルにも現存せず(Trash・home 配下になし。6/23 のクリーンアップで削除されたと推定)。ablation run ディレクトリ(`data/runs/a551c74d`)に report.md / scores.csv / transcripts が残存しており、**論文の ablation 数値(25pp、72/47%、readiness 53%、631,243 tokens)はすべて run report と一致することを検証済み**。

| # | 項目 | 状態 |
|---|------|------|
| 1 | AI 開示 | ✅ 論文 md/tex に AI involvement statement、§9 に Reflexivity bullet、CITATION.cff(abstract)、.zenodo.json(description)、両 README(Status 直下) |
| 2 | DB 公開主張 | ✅ md/tex の計5箇所を「DB は保持していない。分析ドキュメントが記録を保持、ablation の run report は verbatim 公開」に修正。両 README も同期 |
| 3 | ablation 一次資料 | ✅ `results/2026-06-21-v9c2-ablation-ndisc1-analysis.md` 新規作成、run report を `results/2026-06-21-v9c2-ablation-ndisc1-run-report.md` に verbatim コピー、experiments README の versions 表と results index に追記、日誌 06-17 追加・06-21 更新 |
| 4 | "two of which decompose" | ✅ md/tex とも "one of which decomposes" に修正 |
| 5 | "4–24×" | ✅ 実測ベースに書き換え(v9c2: 13–17×、v5 tutoring: ~4.3×)md/tex |
| 6 | population-multiplication 用語衝突 | ✅ §5.3 の v9b 記述を class-size design に変更し §6 との区別を明記(md/tex)。experiments README の v9b 行も修正 |
| 7 | 世代カウント | ✅ §5 冒頭で counting を明示的に定義(md/tex) |
| 8 | v9c2 分析「4項目」 | ✅ 「5項目」に修正 |
| 9 | DOI 混在 | ✅ 両 README に concept DOI / version DOI の注記を追加(resolve 確認は未実施 — 要手動確認) |
| 10 | A コード列挙 | ✅ 論文 §7 を「A0/A3/A5/A6/A8(A4 は既充足を確認)」に統一 |
| 11 | シード未制御 | ✅ §9 に Stochasticity bullet を追加(md/tex) |
| 追加 | experiments README の副次修正 | ✅ 「Human-authored analysis documents」→「Analysis documents」(AI 開示と矛盾するため)、v8 行の記述修正、results index に v4/v5/v6 行を補完 |
| 追加 | §6 監査記述 | ✅ 「per-run databases」→「then-extant per-run databases」(md/tex) |

**検証:** .zenodo.json(jq)・CITATION.cff(YAML)はパース確認済み。LaTeX はローカルにコンパイラがないため未コンパイル——**tex の変更箇所はコンパイル確認が必要**。

**残タスク(masumi):** ①論文全文の通読(査読依頼前の必須事項) ②DOI 2件の resolve 確認 ③tex のコンパイル確認 ④Zenodo 側 description の更新(.zenodo.json は次リリース時に反映される。既存デポジットは手動更新が必要)

---

## 追記(2026-07-14): DB 復旧・全数値の DB 突合・プライバシースキャン

**DB 復旧:** 別マシンから `data/*.db`(全世代の本番+スモーク)と `data/runs/`(38 run ディレクトリ)を復旧。**唯一 `experiment_v9c2_ablation_ndisc1.db`(ablation 本番)は紛失確定**(masumi 確認済み)——ablation の一次記録は引き続き run report(verbatim コピー済み)。

**DB 突合検証:** 全本番 run のヘッドライン数値を SQLite から直接再計算し、論文・分析ドキュメントと**全世代一致**を確認(v4: 47/28、v5: 44/41/38、v6: 94/59/59、v7a: 88/53/50、v7b: 69/47/41、v8: 83/78/70/68、v9b: 60/60/48/47/45、v9c: 65/58*/52/40/28、v9c2: 86/83/81/80/76、v9c2 readiness 100/91/85/85=90%、type 差 96 vs 58=38pp)。*唯一の差異は v9c small の 23/40=57.5%(分析ドキュメントは 57%、四捨五入なら 58%)という丸め表記のみで実質差なし。

**プライバシースキャン(DB 公開可否の判断材料):**
- DB 15 ファイルの dump 全文:ホームパス 0、メールアドレス 0、API トークン/秘密鍵 0、wordlist ヒット 0(Ruby 正規表現セマンティクスで検証。シェル grep の初回カウントは BSD grep の正規表現非互換による誤検知)
- `runs/` ディレクトリ:ホームパス 1 件のみ——`runs/ab4061b6…/report.md:66` に `cat ~/tmp/...`(絶対パス形式)という旧フォーマットのコマンド行(ユーザー名のみの露出。同じユーザー名は公開済みの docs/superpowers/plans/*.md に多数存在)
- 公開済みツリー・履歴:著者名とメールは意図的な公開情報。`~/tmp/...` 形式の絶対パスが plan docs に多数(既公開。ユーザー名=著者名のため実害は小)

**結論:** DB の中身は合成ドメイン(Zarn Tokens)のトランスクリプト・スコアのみで、プライベートデータは検出されず。公開する場合の唯一の下処理は `runs/ab4061b6` の 1 行(または当該 run ディレクトリの除外)。

**文言の再更新:** 論文(md/tex)・README(en/ja)を「DB は著者が保持、要請に応じ提供。ablation DB のみ紛失(run report で代替)。全数値は DB と突合検証済み」に更新。公開(git コミット or Zenodo 同梱)を決めた場合は「released」に戻す。

**公開決定(2026-07-14, masumi):** DB を git で公開する方針を確定。実施内容:①`runs/ab4061b6…/report.md:66` のホームパスを相対パスにサニタイズ(公開前の唯一の下処理)②`.gitignore` から `data/runs/` と `data/*.db` を削除 ③論文(md/tex)・README(en/ja)を「per-run databases and run directories are released」に更新。
