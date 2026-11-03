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

### 同期のしかた

スキルを変更したら、このリポジトリで次を実行する。

```powershell
powershell -ExecutionPolicy Bypass -File scripts\sync-skills.ps1
```

`-DryRun` を付けると、コピーせずに対象だけを表示する。`~/.claude/skills/` 側を直接編集すると、次の同期で上書きされるので、変更は必ずこのリポジトリで行う。
