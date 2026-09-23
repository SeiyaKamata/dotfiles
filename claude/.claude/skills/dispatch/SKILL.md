---
name: dispatch
description: plan.mdのタスク一覧が複数リポジトリにまたがる場合に、担当外のリポジトリへ herdr space を開いて /impl の実行を並列に依頼する。/impl が自分の担当外の大タスクに気づいたときに呼ぶ。
allowed-tools: Read, Bash(git *), Bash(mkworktree *), Bash(herdr *), SendMessage, ListAgents
argument-hint: "<feature>"
---

# 複数リポジトリ配置スキル

## 役割
`.specs/<feature>/plan.md` の `Repo:` が自分のリポジトリと異なる大タスクを、そのリポジトリの claude code セッションに `/impl <feature>` として並列に依頼する。
何を実装するかは判断せず、worktree 作成・herdr 起動・`SendMessage` 依頼という配置操作だけを行い、各セッションの実装完了は待たない。
完了は `notify_when_idle` の通知で呼び出し元のセッションへ直接届く。

## 判断が割れる点の扱い
途中でユーザーに質問も承認要求もしない。
bare repo が見つからない・herdr で開けないなど配置操作が成立しないリポジトリだけ要確認に回し、他のリポジトリの配置は続ける。

## 進め方

### Step 1: 対象リポジトリの洗い出し

- `$ARGUMENTS[0]` が無ければ「使い方: /dispatch <feature>」を表示して終了
- 自分のリポジトリ名は `git rev-parse --git-common-dir` の basename で確定する。bare repo のディレクトリ名がリポジトリ名になる
- `.specs/<feature>/plan.md` の `## タスク一覧` を読み、`Repo:` が自分と異なる大タスクをリポジトリ別にまとめる

対象が無ければ Step 3 で「配置対象なし」と報告して終了する。

### Step 2: リポジトリごとに配置

対象リポジトリごとに次を行う。

1. bare repo の特定: 自分の bare repo と同じ親ディレクトリにある `<リポジトリ名>` を採る
   - `git -C <path> rev-parse --is-bare-repository` が `true` でなければそのリポジトリは要確認に回す
2. 既存セッションの確認: `ListAgents` と `herdr agent list` の `.result.agents[].cwd` から、そのリポジトリの worktree で稼働中のセッションを探す
   - あればそのセッションを宛先にし、4 へ進む
3. worktree とセッションの作成:
   ```
   dest=$(mkworktree <bare repo のパス> <リポジトリ名>-<feature>)
   herdr workspace create --cwd "$dest" --label <リポジトリ名> --no-focus
   herdr pane run <出力の .result.root_pane.pane_id> claude
   ```
   - `herdr workspace list` の `label` が一致する space が既にあれば作らず、その `workspace_id` の pane を使う
   - `.specs` は worktree 作成時に post-checkout hook が共有先へ symlink するので、ここでは触らない
   - 宛先は `ListAgents` に新しく現れたセッション名を使う
4. 実装依頼: `SendMessage` を `notify_when_idle: true` で呼び、`/impl <feature>` の実行を依頼する
   - 依頼文には feature 名だけを渡し、実装内容の指示は書かない。担当分は `/impl` 側が `Repo:` で判別する
   - 完了は待たない

### Step 3: 出力

次のカードを、コードフェンス自体は出さずに中身だけ出力して終了する。
対象が無ければ見出しを `### 配置対象なし` にし、要確認と次の一手は省略する。

```markdown
### 配置完了
<何リポジトリへ実装を依頼したかを 1 行>
- <リポジトリ名: 依頼済み / 中断 の内訳。最大 3 行>

### 要確認
- <配置できなかったリポジトリと理由> 該当: <リポジトリ名>

### 次の一手
- 自分のリポジトリの実装を続ける。呼び出し元の `/impl` に戻る
- 他リポジトリの完了は `notify_when_idle` の通知で確認する
```

要確認は無ければブロックごと省略する。
