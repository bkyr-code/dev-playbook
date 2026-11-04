# dev-playbook

開発プロセスの再利用可能なテンプレート集。

## プレイブック一覧

| プレイブック | 対象 |
|-------------|------|
| [Webアプリ開発](playbooks/web-app.md) | Webアプリをゼロから作るときの流れ |

## Claude Code スキル

`skills/` 配下が正本。Claude Code で使うには、ユーザー共通のスキルフォルダ（`~/.claude/skills/`）に同期する。

| スキル | 用途 |
|-------------|------|
| [issue](skills/issue/SKILL.md) | cc-sdd を使うリポジトリで、Issue の作成からマージまでを承認ゲート付きで進める |
| [spec-review](skills/spec-review/SKILL.md) | 要件・設計・タスクを確定する前に、経緯を知らない独立したレビュアーで判定する |
| [ci-setup](skills/ci-setup/SKILL.md) | GitHub Actions の CI・SAST を入れ、CI が通らないとマージできないようブランチ保護を設定する |
| [pr-write](skills/pr-write/SKILL.md) | PR のタイトルと本文を決まった形式で作る（事実だけを書く）。Squash merge のコミットメッセージもそろえる |

### 同期のしかた

スキルや `global/CLAUDE.md` を変更したら、このリポジトリで次を実行する。スキルは `~/.claude/skills/` に、`global/CLAUDE.md` は `~/.claude/CLAUDE.md` の dev-playbook の区画にだけ反映される（区画の外の内容は変更しない）。

```powershell
powershell -ExecutionPolicy Bypass -File scripts\sync-skills.ps1
```

`-DryRun` を付けると、コピーせずに対象だけを表示する。`~/.claude/skills/` 側を直接編集すると、次の同期で上書きされるので、変更は必ずこのリポジトリで行う。

## Claude Code の権限設定（全リポジトリ共通・一度だけ）

ブランチ保護では「CI が通った PR を Claude がマージすること」は止められない。push・マージ・GitHub API の操作で必ず確認が出るよう、`~/.claude/settings.json`（`C:\Users\<ユーザー名>\.claude\settings.json`）の `permissions.ask` に次を加える。ファイルが既にある場合は、`ask` の配列に追記する。

```json
{
  "permissions": {
    "ask": [
      "Bash(git push *)",
      "Bash(gh pr merge *)",
      "Bash(gh api *)",
      "Bash(gh repo edit *)"
    ]
  }
}
```

`ask` は、リポジトリ側の設定で `allow` されていても優先される。ただし書き方を変えたコマンドまでは止められないので、確実な防壁ではなく、通常の操作で必ず確認が出るようにするためのもの。

## セッション名を自動で付けるフック（PC の Claude Code・一度だけ）

Issue のブランチ（`2-...` のような名前）で Claude Code を開始・再開すると、セッション名を `#2 導入検証` の形式に自動で付ける。名前は `/issue` が `git config branch.<ブランチ名>.sessionTitle` に記録したものを使い、なければ Issue のタイトルから作る。同期スクリプトがフックを `~/.claude/hooks/dev-playbook/` にコピーするので、`~/.claude/settings.json` に次を一度だけ追記する（`hooks` が既にあれば、`SessionStart` の配列に足す）。

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "powershell -NoProfile -ExecutionPolicy Bypass -File \"C:/Users/81903/.claude/hooks/dev-playbook/session-title.ps1\""
          }
        ]
      }
    ]
  }
}
```
