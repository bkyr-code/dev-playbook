---
name: ci-setup
description: リポジトリ（Node/TypeScript、Java、Minecraft の Mod・プラグイン・データパックなど）に GitHub Actions の CI（型チェック・lint・テスト）と SAST（semgrep）を入れ、既定ブランチへの直接 push を禁止し CI が通らないとマージできないようブランチ保護を設定する。CI がないリポジトリで /issue から提案されたとき、または CI を整えたいときに使う。
argument-hint: [--no-protection]
---

# ci-setup：CI とブランチ保護の導入

## 目的と、防げること・防げないこと
- PR のたびに、型チェック・lint・テスト・セキュリティスキャンを自動で実行する
- ブランチ保護で、既定ブランチへの**直接 push を禁止**し、**CI が通った PR しかマージできない**ようにする

ブランチ保護で防げないこと：
- **CI が通った PR のマージ**：Claude はユーザーの認証情報で動くので、`gh pr merge` を実行できる。これを止めるのは、ユーザー単位の Claude Code の権限設定（`~/.claude/settings.json` の `permissions.ask` に `git push`・`gh pr merge`・`gh api` を入れる）。設定は dev-playbook の README を参照。このスキルを使う前に設定されているか確認し、なければユーザーに案内する
- **保護そのものの解除**：既定の `gh` のトークンには所有リポジトリの管理権限があるので、技術的には保護を外せる。Claude は保護の設定を変更・解除しない（このスキルの手順5でユーザーの確認を取って設定するときだけ例外）
- **CI の中身の書き換え**：必須チェックは名前で照合されるので、PR の中でワークフローを書き換えれば通せてしまう。`/issue` は、マージ前に `.github/workflows/` の変更をユーザーに明示する

## 方針
- チェックは「CI（型チェック・lint・テスト・ビルド）」と「SAST」の2つのワークフローに絞る。増やしすぎると、修正と push の往復が増えて個人開発では重くなる
- リポジトリに既にあるスクリプトだけを使う。CI のために新しいツールを入れない（入れたほうがよい場合は提案に留める）
- ワークフローファイルは各リポジトリの `.github/workflows/` に置く。ひな形はこのスキルの `templates/` にある
- 必須チェックにするワークフローには、`paths` / `paths-ignore` のフィルタを付けず、コミットメッセージに `[skip ci]` も使わない。起動しなかった必須チェックは「保留」のまま残り、マージが止まるため

## 実行するタイミング
- **新しく作るリポジトリ**：最初の雛形ができ、ローカルでビルド（とテスト）が通るようになった時点で実行する
  - 最初のコミットだけは、既定ブランチに直接 push する（ユーザーの確認を取ってから）。既定ブランチにコミットが1つもないと、PR も作れず、ブランチ保護も設定できないため。以降の変更はすべて PR を通す
  - ブランチ保護まで使う場合は、リポジトリを作る時点で公開／非公開を決める。GitHub の無料プランでは、非公開リポジトリにブランチ保護を設定できない（手順5）
- **既存のリポジトリ**：いつでもよい。`/issue` が CI のないリポジトリで提案する

## 手順

### 1. 現状を調べる
- リポジトリ：`gh repo view --json defaultBranchRef,visibility,owner,name`。ユーザーのプランは `gh api user --jq .plan.name`
- 既存のワークフロー：`.github/workflows/` の中身。コミットされているか（`git ls-files .github/workflows`）も確認する。未コミットのファイルは動いていない
- 技術スタック
  - Node：`package.json` の scripts（`typecheck`・`lint`・`test`・`build`）、`tsconfig.json`（`references` を持つかどうか）、Node のバージョン指定、lockfile の種類（`package-lock.json`／`pnpm-lock.yaml`／`yarn.lock`／`bun.lockb`）
  - Java：`build.gradle(.kts)`（`gradlew` の有無）、`pom.xml`（`mvnw` の有無）
  - その他：`pyproject.toml`、`go.mod` など
- Minecraft 関連かどうか：次のファイルがあれば Minecraft 向けとして扱う（下の「Minecraft の場合」を参照）
  - Mod：`fabric.mod.json`、`neoforge.mods.toml`、`mods.toml`（NeoForge の MDK では `src/main/templates/` 配下にある）、または `build.gradle` で Fabric Loom・NeoForge・ForgeGradle のプラグインを使っている
  - プラグイン：`plugin.yml`、`paper-plugin.yml`、または Gradle の plugin-yml プラグインを使っている（その場合 `plugin.yml` はビルド時に生成されるので、ファイルとしては見つからない）
  - データパック：ビルドファイルがなく `pack.mcmeta` がある
- 調べた結果を「既にあるもの／足すもの／対応していないもの」に分けて示す

### 2. CI ワークフローを作る
共通：ジョブ名は `ci` にする。matrix は使わない（チェック名が `ci (21)` のように変わり、必須チェックの指定がずれるため）。

- **Node/TypeScript**：`templates/node-ci.yml` をもとに作る
  - パッケージマネージャー：lockfile から判定する。ひな形は npm 用。pnpm・yarn・bun の場合は、インストールのコマンドとキャッシュの指定をそれに合わせて書き換える
  - Node のバージョン：`.nvmrc`／`.node-version` があれば `node-version-file` で指定する。`package.json` の `engines` があればそれを使う。どれもなければ `lts/*`
  - 型チェック：`typecheck` スクリプトがあればそれを使う。なければ、`tsconfig.json` が `references` を持つ場合は `npx tsc -b`、持たない場合は `npx tsc --noEmit`。Vite などのひな形では、ルートの tsconfig が `"files": []` と `references` だけを持つので、`tsc --noEmit` では何も検査されない
  - lint・テスト：スクリプトがある場合だけ入れる。テストがウォッチモードで起動するスクリプト（`vitest` 単体など）なら、`vitest run` のように一度で終わる形にする
  - ビルド：`build` スクリプトがあれば入れる。Web アプリでは、これが最も手軽な総合チェックになる
- **Java（Gradle）**：`templates/gradle-ci.yml` をもとに作る。`./gradlew build` でコンパイル（型チェック）・テスト・jar の作成までまとめて行われる
  - `gradlew` と `gradle/wrapper/` 一式がコミットされている必要がある。なければ、ローカルで `gradle wrapper` を実行してコミットするよう案内する
  - Windows で作った場合の注意：`.gitattributes` に `gradlew text eol=lf` があるか確認し、なければ足す（CRLF のままだと CI で `/usr/bin/env: 'sh\r'` で失敗する）。実行権限は `git update-index --chmod=+x gradlew` でリポジトリ側に記録する。ひな形の `chmod +x` は保険として残す
  - Java のバージョン：`build.gradle(.kts)` の `JavaLanguageVersion.of(...)`、`options.release`、`sourceCompatibility` の順に探す
  - lint：Checkstyle や Spotless が設定済みなら `build` に含まれるか確認し、含まれなければステップを足す。設定がなければ入れない
- **Java（Maven）**：`templates/maven-ci.yml` をもとに作る。`verify` でコンパイル・テスト・jar の作成まで行われる。`mvnw` があれば `./mvnw`、なければ `mvn` を使う。Java のバージョンは `pom.xml` の `maven.compiler.release` などから取る
- **それ以外のスタック**：ひな形はない。同じ考え方（型チェック・lint・テスト・ビルドのうち既にあるもの）で作り、作った内容を明示する
- **既に CI がある場合**：作り直さない。足りないチェックがあれば差分だけを提案する。ジョブ名が `ci` でなくてもよい（手順5で実際のチェック名を使う）

### 3. SAST ワークフローを作る
- `templates/semgrep.yml` をもとに、`.github/workflows/semgrep.yml` を作る。ジョブ名は `semgrep` にする
- ルールセットは技術スタックに合わせて、ひな形の `__RULESETS__` を置き換える。共通で `p/secrets` と `p/owasp-top-ten` を入れ、TypeScript なら `p/typescript`、React なら `p/react`、Java なら `p/java`、Python なら `p/python` を足す
- `--metrics=off` を付ける（付けないと、レジストリからルールを取得するたびに利用状況が Semgrep に送られる）。`--config auto` は使わない（利用状況の送信が前提のため）
- 失敗の基準は `--severity ERROR`（重大な指摘だけで失敗させる）。全重大度で失敗させると、コードを変えていない PR がルールの更新だけで落ち、マージが止まりやすくなるため
- 旧来の `semgrep/semgrep-action` を使っているファイルがあれば、置き換える。このアクションは非推奨になっている

### Minecraft の場合
- **Mod（Fabric / NeoForge / Forge）**：Gradle のひな形を使う
  - Java のバージョンは、ビルドファイル（Loom や MDK のひな形が生成したもの）の指定を正とする。目安：26.1 以降は Java 25、1.20.5〜1.21.x は Java 21、1.18〜1.20.4 は Java 17。目安と食い違っていても書き換えず、気づいた点として伝えるだけにする
  - 初回のビルドでは Minecraft 本体などのダウンロードが走るので、数分かかる。`setup-gradle` のキャッシュで2回目以降は短くなる
  - `runClient` / `runServer` は CI では実行しない（ゲームの起動が必要なため）。CI で確認するのは「ビルドが通ること」と、ゲームに依存しないロジックの単体テスト
- **プラグイン（Paper / Spigot など）**：ビルドツールに合わせて Gradle か Maven のひな形を使う。Shadow などで依存関係を同梱した jar を作る設定がある場合は、`build` でその jar も作られるか確認する
- **Mod とプラグインの共通**：ひな形の「Upload jar」ステップを残す。PR の画面から、ビルドされた jar をダウンロードして手元のサーバーやクライアントで試せる。保存期間は7日、PR のときだけ保存する（非公開リポジトリでは保存容量に上限があるため）
- **データパック**：ビルドもテストもないので、CI は JSON の構文チェックだけにする。対象は `*.json` と `pack.mcmeta`（例：`find . \( -name '*.json' -o -name 'pack.mcmeta' \) -print0 | xargs -0 -n1 python3 -m json.tool > /dev/null`）。SAST は `p/secrets` だけで足りる

### 4. 動作確認
1. ブランチを作り、ワークフローファイルをコミットして push し、PR を作る（いずれもユーザーの確認を取ってから）。`/issue` の途中なら、その Issue のブランチと PR に含めてよい
2. `gh pr checks --watch` で結果を待つ
3. 失敗した場合は、原因が「CI の設定の誤り」か「既存のコードの問題（既存の lint エラーなど）」かを分けて示す
   - 設定の誤り：直す
   - 既存のコードの問題：その場で直さず、ユーザーに選んでもらう（別 Issue にして、それまでその項目を CI から外す／この PR で直す）
   - npm の既知の原因：Windows の古い npm（11.3 未満）で作った `package-lock.json` には、Linux 用の依存が記録されず、CI で落ちることがある。その場合は、新しい npm で lockfile を作り直す
4. すべてのチェックが通ることを確認し、`gh pr checks` に表示された**実際のチェック名**を控える。手順5で必須チェックに指定するのはこの名前。一度も成功していない名前を指定すると、以降のマージがすべて止まるため

### 5. ブランチ保護を設定する（`--no-protection` のときは省略）
1. 可否の確認：GitHub Free では、ブランチ保護は**公開リポジトリでのみ**使える。非公開リポジトリには GitHub Pro 以上が必要。手順1の `visibility` とプランで判定する。使えない場合は、下の「使えない場合」に進む
2. 設定内容をユーザーに示し、AskUserQuestion で確認を取る。特に次の点を必ず伝える
   - 管理者（リポジトリの所有者）にも適用する（`enforce_admins: true`）。Claude はユーザーの認証情報で動くので、管理者を除外すると Claude も素通りできてしまうため
   - その代わり、ユーザー自身も既定ブランチに直接 push できなくなる。ドキュメントの小さな修正も PR 経由になる
3. 設定する。ファイルを作らず、標準入力で渡す（一時ファイルを誤ってコミットしないため）。`checks` の `context` は手順4で控えた名前にする

```bash
gh api -X PUT repos/<owner>/<repo>/branches/<既定ブランチ>/protection --input - <<'EOF'
{
  "required_status_checks": {
    "strict": false,
    "checks": [{ "context": "ci" }, { "context": "semgrep" }]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "required_approving_review_count": 0
  },
  "restrictions": null
}
EOF
```

   - `required_pull_request_reviews` の承認数 0：個人開発なので承認者は不要。ただし PR を通すことは必須になり、直接 push が止まる
   - `strict: false`：既定ブランチが先に進んでいても、ブランチを最新にせずにマージできる。1人で順番に PR を進める前提。PR を並行して進めることが多い場合は true を検討する（その場合、マージ前に `gh pr update-branch` が必要になることがある）
4. 確認：`gh api repos/<owner>/<repo>/branches/<既定ブランチ>/protection` で設定が入ったことを確かめる。必須チェックの `app_id` が GitHub Actions（15368）になっていることも確認する
5. リポジトリの CLAUDE.md に「既定ブランチは保護されている（直接 push 不可、必須チェック：ci・semgrep）」と1行書く案を示し、ユーザーの確認を取って追記する

### 使えない場合（非公開リポジトリで無料プランなど）
GitHub 側では強制できない。主な対策は、ユーザー単位の Claude Code の権限設定（`permissions.ask` に `git push`・`gh pr merge`）で、push とマージのたびに必ず確認が出るようにすること。設定済みか確認する。そのうえで、補助的な対策を選んでもらう。
- **pre-push フック（うっかり防止）**：既定ブランチへの push を拒否するフックを、リポジトリ内の `.githooks/pre-push` に置き、`git config core.hooksPath .githooks` を設定する。clone し直したら `core.hooksPath` の設定だけやり直す。`git push --no-verify` で素通りでき、`gh pr merge` も止められないので、うっかり防止にとどまる
- **リポジトリを公開する、またはプランを上げる**
- **権限設定だけで運用する**

## 終わったら
作ったファイル、必須チェックの名前、ブランチ保護の状態（設定済み／使えないので代替策／省略）を1〜3行で報告する。
