#!/usr/bin/env python3
import html
import json
import re
import subprocess
import sys
from pathlib import Path

COMMENTS_JS = Path(__file__).with_name("comments.js").read_text(encoding="utf-8")

CSS = """
:root {
  --bg: #ffffff; --fg: #1f2328; --muted: #656d76; --line: #d0d7de;
  --accent: #0969da; --chip: #f3f4f6; --pass: #1a7f37; --fail: #cf222e; --blocked: #9a6700;
}
@media (prefers-color-scheme: dark) {
  :root {
    --bg: #0d1117; --fg: #e6edf3; --muted: #8d96a0; --line: #30363d;
    --accent: #58a6ff; --chip: #161b22; --pass: #3fb950; --fail: #f85149; --blocked: #d29922;
  }
}
* { box-sizing: border-box; }
body { margin: 0; padding: 32px clamp(16px, 5vw, 56px) 64px; background: var(--bg); color: var(--fg);
  font: 15px/1.7 -apple-system, BlinkMacSystemFont, "Hiragino Sans", sans-serif; }
main { max-width: 1120px; margin: 0 auto; }
a { color: var(--accent); }
h1 { margin: 0 0 8px; padding-bottom: 8px; border-bottom: 2px solid var(--accent);
  color: var(--accent); font-size: 26px; }
h2 { margin: 32px 0 12px; padding: 4px 0 4px 12px; border-left: 5px solid var(--accent);
  background: var(--chip); font-size: 20px; }
.meta { color: var(--muted); font-size: 13px; }
.verdict { display: inline-block; margin: 0 8px 0 0; padding: 0 12px; border-radius: 999px;
  border: 1px solid currentColor; font-weight: 700; }
.pass { color: var(--pass); } .fail { color: var(--fail); } .blocked { color: var(--blocked); }
table { width: 100%; border-collapse: collapse; }
th, td { padding: 8px 12px; border-bottom: 1px solid var(--line); text-align: left; vertical-align: top; }
th { background: var(--chip); }
td.status { font-weight: 700; white-space: nowrap; }
.grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(480px, 1fr)); gap: 16px; }
figure { margin: 0; padding: 8px; border: 1px solid var(--line); border-radius: 8px; background: var(--chip); }
figure img { display: block; width: 100%; border-radius: 4px; }
figcaption { margin-top: 8px; font-size: 14px; }
ul, ol { padding-left: 20px; }
.badge { display: inline-block; margin-right: 8px; padding: 0 8px; border-radius: 4px;
  background: var(--chip); border: 1px solid var(--line); color: var(--muted); font-size: 12px; }
.badge.err { color: var(--fail); border-color: var(--fail); }
.question { margin: 4px 0 4px 16px; padding: 4px 12px; border-left: 4px solid var(--blocked);
  background: var(--chip); color: var(--blocked); font-size: 14px; }
h3 { margin: 24px 0 8px; padding-bottom: 2px; border-bottom: 1px dashed var(--accent); font-size: 17px; }
h4 { margin: 16px 0 4px; font-size: 15px; color: var(--accent); }
ul.lines { list-style: none; padding-left: 0; }
ul.lines li { margin: 4px 0; }
pre { padding: 12px; overflow-x: auto; background: var(--chip); border-radius: 6px; }
code { padding: 0 4px; background: var(--chip); border-radius: 4px; }
.task-meta { color: var(--muted); font-size: 14px; }
.diff { margin: 12px 0; border: 1px solid var(--line); border-radius: 6px; overflow: hidden; }
.dfile { padding: 6px 12px; background: var(--chip); cursor: pointer;
  font: 600 13px ui-monospace, SFMono-Regular, Menlo, monospace; }
.diff[open] > .dfile { border-bottom: 1px solid var(--line); }
.dh { padding: 2px 12px; background: var(--chip); color: var(--muted); font: 12px ui-monospace, SFMono-Regular, Menlo, monospace; }
.dl { display: flex; font: 12px/1.5 ui-monospace, SFMono-Regular, Menlo, monospace; tab-size: 4; }
.dl .n { flex: none; width: 44px; padding: 0 6px; text-align: right; color: var(--muted); user-select: none; }
.dl .s { flex: none; width: 14px; color: var(--muted); user-select: none; }
.dl .c { flex: 1; min-width: 0; white-space: pre-wrap; word-break: break-all; }
.dl.add { background: rgba(46, 160, 67, .15); }
.dl.del { background: rgba(248, 81, 73, .15); }
.dl.note { color: var(--muted); }
.finding { margin: 4px 12px 4px 60px; padding: 4px 12px; border-left: 4px solid var(--fail); background: var(--chip); font-size: 14px; }
.finding p { margin: 0; }
"""

APPROVAL_STATES = {"": "承認待ち", "対応する": "対応中", "対応しない": "対応なし", "保留": "保留"}
PASS = {"pass", "ok", "green"}
FAIL = {"fail", "ng", "赤"}


def esc(value):
    return html.escape(str(value), quote=True)


def strip_comments(text):
    out = []
    i = 0
    in_string = False
    while i < len(text):
        c = text[i]
        if in_string:
            out.append(c)
            if c == "\\":
                out.append(text[i + 1])
                i += 1
            elif c == '"':
                in_string = False
        elif c == '"':
            in_string = True
            out.append(c)
        elif text.startswith("//", i):
            while i < len(text) and text[i] != "\n":
                i += 1
            continue
        elif text.startswith("/*", i):
            i = text.index("*/", i) + 2
            continue
        else:
            out.append(c)
        i += 1
    return "".join(out)


def status_class(value):
    v = str(value).strip().lower()
    if v in PASS:
        return "pass"
    if v in FAIL:
        return "fail"
    return "blocked"


def header(title, data, with_verdict=True):
    chip = ""
    if with_verdict:
        verdict = data["verdict"]
        chip = f'<span class="verdict {status_class(verdict)}">{esc(verdict)}</span>'
    where = f"{data.get('branch', '')} @ {str(data.get('head', ''))[:7]}" if data.get("branch") or data.get("head") else ""
    meta = " / ".join(esc(v) for v in (where, data.get("ran_at", "")) if v)
    return [f"<h1>{esc(title)}</h1>", f'<p class="meta">{chip}{meta}</p>']


def table(columns, rows):
    head = "".join(f"<th>{esc(c)}</th>" for c in columns)
    body = "".join("<tr>" + "".join(cells) + "</tr>" for cells in rows)
    return f"<table><thead><tr>{head}</tr></thead><tbody>{body}</tbody></table>"


def join_nonempty(*values):
    return "。".join(str(v) for v in values if v)


def link(url, text):
    return f'<a href="{esc(url)}">{esc(text)}</a>' if url else esc(text)


def td(value):
    return f"<td>{esc(value)}</td>"


def td_status(value):
    return f'<td class="status {status_class(value)}">{esc(value)}</td>'


def numbered(items):
    return "<ol>" + "".join(f"<li>{esc(i)}</li>" for i in items) + "</ol>"


def bullets(items):
    return "<ul>" + "".join(f"<li>{esc(i)}</li>" for i in items) + "</ul>"


def render_qa(data):
    scenarios = data.get("scenarios", [])
    for s in scenarios:
        s["result"] = str(s.get("result", "")).lower()
    passed = sum(1 for s in scenarios if s["result"] == "pass")
    failed = sum(1 for s in scenarios if s["result"] == "fail")
    parts = header(f"QA結果: {data.get('feature', '')}", data)
    parts.append(
        "<h2>サマリ</h2>"
        + bullets([f"判定: {data.get('verdict', '')}", f"シナリオ数 / pass / fail: {len(scenarios)} / {passed} / {failed}"])
    )
    parts.append(
        "<h2>シナリオ結果</h2>"
        + table(
            ["Q", "タイトル", "判定", "原因"],
            [[td(s["id"]), td(s["title"]), td_status(s["result"]), td(s.get("cause", ""))] for s in scenarios],
        )
    )
    figures = "".join(
        f'<figure><img src="{esc(s["screenshot"])}" alt="{esc(s["id"])}" loading="lazy">'
        f'<figcaption><span class="{status_class(s["result"])}">{esc(s["result"])}</span> '
        f"{esc(s['id'])}: {esc(s['title'])}</figcaption></figure>"
        for s in scenarios
        if s.get("screenshot")
    )
    if figures:
        parts.append(f'<h2>画面のスクリーンショット</h2><div class="grid">{figures}</div>')
    failures = [
        f"{s['id']} {s['title']}: {s.get('cause', '')}"
        + (f" 要件: {', '.join(map(str, s['requirements']))}" if s.get("requirements") else "")
        for s in scenarios
        if s["result"] == "fail"
    ]
    if failures:
        parts.append("<h2>失敗シナリオ</h2>" + bullets(failures))
    return f"QA結果: {data.get('feature', '')}", parts


def render_test(data):
    parts = header("テスト結果", data)
    parts.append(
        "<h2>サマリ</h2>"
        + bullets(
            [
                f"実行数: {data['total']}",
                f"成功: {data['passed']}",
                f"失敗: {data['failed']}",
            ]
        )
    )
    failures = data.get("failures", [])
    if failures:
        parts.append(
            "<h2>失敗したテスト</h2>" + table(["テスト名", "エラー内容"], [[td(f["name"]), td(f.get("error", ""))] for f in failures])
        )
    return "テスト結果", parts


HLJS = "https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0"
HIGHLIGHT = (
    f'<link rel="stylesheet" href="{HLJS}/styles/github.min.css" media="(prefers-color-scheme: light)">'
    f'<link rel="stylesheet" href="{HLJS}/styles/github-dark.min.css" media="(prefers-color-scheme: dark)">'
    f'<script src="{HLJS}/highlight.min.js"></script>'
    """<script>
addEventListener("load", () => {
  if (!window.hljs) return;
  const alias = { jsonc: "json", zsh: "bash", mjs: "javascript", cjs: "javascript" };
  for (const file of document.querySelectorAll(".diff[data-ext]")) {
    const ext = file.dataset.ext;
    const language = alias[ext] || ext;
    if (!hljs.getLanguage(language)) continue;
    for (const code of file.querySelectorAll(".dl .c")) {
      code.innerHTML = hljs.highlight(code.textContent, { language, ignoreIllegals: true }).value;
    }
  }
});
</script>"""
)

HUNK = re.compile(r"^@@ -(\d+)(?:,\d+)? \+(\d+)")


def parse_diff(text):
    files = []
    cur = None
    old = new = 0
    for raw in text.split("\n"):
        if raw.startswith("diff --git "):
            cur = {"path": raw.rsplit(" b/", 1)[-1], "hunks": [], "binary": False}
            files.append(cur)
        elif cur is None:
            continue
        elif raw.startswith("@@"):
            m = HUNK.match(raw)
            old, new = int(m[1]), int(m[2])
            cur["hunks"].append({"head": raw, "lines": []})
        elif not cur["hunks"]:
            if raw.startswith("+++ b/"):
                cur["path"] = raw[6:]
            elif raw.startswith("Binary files"):
                cur["binary"] = True
        elif raw[:1] == " ":
            cur["hunks"][-1]["lines"].append((" ", old, new, raw[1:]))
            old += 1
            new += 1
        elif raw[:1] == "+":
            cur["hunks"][-1]["lines"].append(("+", None, new, raw[1:]))
            new += 1
        elif raw[:1] == "-":
            cur["hunks"][-1]["lines"].append(("-", old, None, raw[1:]))
            old += 1
        elif raw[:1] == "\\":
            cur["hunks"][-1]["lines"].append(("\\", None, None, raw[1:].strip()))
    return files


def git_diff(base):
    result = subprocess.run(
        ["git", "-c", "core.quotepath=false", "diff", "--no-color", "--no-ext-diff", f"{base}...HEAD"],
        capture_output=True, text=True, encoding="utf-8", errors="replace",
    )
    if result.returncode != 0:
        print(f"差分を取得できませんでした: {result.stderr.strip()}", file=sys.stderr)
        return []
    return parse_diff(result.stdout)


def finding_block(c):
    return (
        '<div class="finding"><p>'
        f'<span class="badge err">{esc(c.get("severity", ""))}</span>{esc(c["text"])}'
        f'<br><span class="meta">検証: {esc(c.get("verification", ""))}</span></p></div>'
    )


def render_diff(files, placed):
    out = []
    for f in files:
        ext = f["path"].rsplit(".", 1)[-1].lower() if "." in f["path"].rsplit("/", 1)[-1] else ""
        out.append(f'<details class="diff" open data-ext="{esc(ext)}"><summary class="dfile">{esc(f["path"])}</summary>')
        if f["binary"]:
            out.append('<div class="dh">バイナリファイル</div>')
        for h in f["hunks"]:
            out.append(f'<div class="dh">{esc(h["head"])}</div>')
            for sign, old, new, body in h["lines"]:
                if sign == "\\":
                    out.append(f'<div class="dl note"><span class="n"></span><span class="n"></span><span class="s"></span><span class="c">{esc(body)}</span></div>')
                    continue
                key = f'{f["path"]}:{"-" + str(old) if sign == "-" else new}'
                kind = {"+": "add", "-": "del", " ": ""}[sign]
                out.append(
                    f'<div class="dl {kind}" data-quote="{esc(key)}">'
                    f'<span class="n">{old or ""}</span><span class="n">{new or ""}</span>'
                    f'<span class="s">{esc(sign.strip())}</span><span class="c">{esc(body)}</span></div>'
                )
                if sign != "-":
                    out.extend(finding_block(c) for c in placed.get((f["path"], new), []))
        out.append("</details>")
    return "".join(out)


def render_review(data):
    parts = header("レビュー結果", data)
    spec = data.get("spec_findings", [])
    if spec:
        parts.append("<h2>仕様整合性</h2>" + bullets(spec))
    files = git_diff(data["base"]) if data.get("base") else []
    on_new_side = {(f["path"], new) for f in files for h in f["hunks"] for sign, _, new, _ in h["lines"] if sign != "-" and new}
    placed = {}
    loose = []
    for c in data.get("code_findings", []):
        key = (c.get("file"), c.get("line"))
        if key in on_new_side:
            placed.setdefault(key, []).append(c)
        else:
            if c.get("file") and c.get("line"):
                print(f"差分に無い行への指摘です: {c['file']}:{c['line']}", file=sys.stderr)
            loose.append(c)
    if loose:
        parts.append(
            "<h2>AI コードレビューの指摘</h2>"
            + table(
                ["指摘と該当箇所", "重大度", "検証結果"],
                [[td(c["text"]), td(c.get("severity", "")), td(c.get("verification", ""))] for c in loose],
            )
        )
    recs = data.get("recommendations", [])
    if recs:
        parts.append("<h2>推奨対応</h2>" + bullets(recs))
    if files:
        parts.append(f"<h2>差分、{len(files)} ファイル。指摘 {sum(len(v) for v in placed.values())} 件は該当行の直下</h2>" + render_diff(files, placed) + HIGHLIGHT)
    return "レビュー結果", parts


def render_ci(data):
    parts = header("CI結果", data)
    pr = data.get("pr", {})
    parts.append(
        "<h2>サマリ</h2><ul>"
        f'<li>PR: {link(pr.get("url", ""), "#" + str(pr.get("number", "")))}</li>'
        f"<li>判定: {esc(data.get('verdict', ''))}</li></ul>"
    )
    jobs = data.get("failed_jobs", [])
    if jobs:
        rows = [
            [td(j["name"]), td(j.get("step", "")), td(j.get("error", "")), f'<td>{link(j.get("link", ""), "ログ") if j.get("link") else ""}</td>']
            for j in jobs
        ]
        parts.append("<h2>失敗ジョブ</h2>" + table(["ジョブ", "失敗ステップ", "エラー", "リンク"], rows))
    return "CI結果", parts


def render_comments(data):
    comments = data.get("comments", [])
    open_count = sum(1 for c in comments if not c.get("done"))
    waiting = sum(1 for c in comments if not c.get("done") and not (c.get("approval") or ""))
    pr = data.get("pr", "")
    title = f"コメント対応レポート: PR #{pr}"
    parts = header(title, data, with_verdict=False)
    parts.append(
        "<h2>サマリ</h2>"
        + bullets([f"未対応: {open_count} 件", f"承認待ち: {waiting} 件", f"全件: {len(comments)} 件"])
    )
    rows = []
    for c in comments:
        approval = c.get("approval") or ""
        state = "済" if c.get("done") else APPROVAL_STATES.get(approval, "承認値が不正")
        rows.append(
            [
                f'<td class="status {"pass" if c.get("done") else "blocked"}">{esc(state)}</td>',
                td(((c.get("path") or "") + (f":{c['line']}" if c.get("line") else "")) or "会話"),
                td(c.get("author", "")),
                td(c["body"]),
                td(join_nonempty(c.get("requirement_class"), c.get("requirement_basis"))),
                td(c.get("verification", "")),
                td(join_nonempty(c.get("proposal"), c.get("reason"))),
                td(c.get("approval", "")),
            ]
        )
    parts.append(
        "<h2>コメント</h2>"
        + table(["状態", "場所", "投稿者", "コメント", "要件照合", "裏取り", "提案", "承認"], rows)
    )
    return title, parts


def render_bug(data):
    title = f"バグ報告: {data.get('feature', '')}"
    parts = header(title, data, with_verdict=False)
    parts.append(
        "<h2>サマリ</h2>"
        + bullets(
            [
                f"症状: {data['symptom']}",
                f"再現可否: {data['reproducible']}",
                f"期待する挙動: {data.get('expected', '')}",
                f"実際の挙動: {data.get('actual', '')}",
            ]
        )
    )
    if data.get("steps"):
        parts.append("<h2>再現手順</h2>" + numbered(data["steps"]))
    if data.get("suspects"):
        parts.append(
            "<h2>疑わしい箇所</h2>"
            + table(["場所", "なぜ疑わしいか"], [[td(x["location"]), td(x.get("reason", ""))] for x in data["suspects"]])
        )
    if data.get("fix_scope"):
        parts.append("<h2>想定する修正範囲</h2>" + bullets(data["fix_scope"]))
    if data.get("regression_checks"):
        parts.append("<h2>回帰テストの観点</h2>" + bullets(data["regression_checks"]))
    return title, parts


EARS_TYPES = [("【異常】", "異常", True), ("とき →", "イベント", False), ("あいだ →", "状態", False), ("場合 →", "オプション", False)]


def ears_badge(text):
    for marker, label, err in EARS_TYPES:
        if marker in text:
            return f'<span class="badge{" err" if err else ""}">{label}</span>'
    return '<span class="badge">常時</span>'


def question_block(text):
    return f'<div class="question">要確認: {esc(text)}</div>' if text else ""


def render_requirements(data):
    title = f"要件定義: {data['feature']}"
    parts = header(title, data, with_verdict=False)
    parts.append("<h2>概要</h2>" + f"<p>{esc(data.get('overview', ''))}</p>")
    for q in data.get("open_questions", []):
        parts.append(question_block(q))

    scope = data.get("out_of_scope", [])
    if scope:
        items = "".join(
            f"<li>{esc(x['item'])}"
            + (f"<br><span class=\"meta\">理由: {esc(x['reason'])}</span>" if x.get("reason") else "")
            + question_block(x.get("question", ""))
            + "</li>"
            for x in scope
        )
        parts.append(f"<h2>スコープ外</h2><ul>{items}</ul>")

    parts.append("<h2>要件</h2>")
    for subject in data.get("subjects", []):
        parts.append(f"<h3>{esc(subject['name'])}</h3>")
        for r in subject.get("requirements", []):
            lines = "".join(
                f"<li>{ears_badge(line['text'])}{esc(line['text'])}{question_block(line.get('question', ''))}</li>"
                for line in r.get("lines", [])
            )
            parts.append(f"<h4>Requirement {esc(r['id'])}: {esc(r['title'])}</h4><ul class=\"lines\">{lines}</ul>")

    for t in data.get("appendix", []):
        rows = [[td(c) for c in row] for row in t.get("rows", [])]
        parts.append(f"<h2>付録: {esc(t['title'])}</h2>" + table(t.get("columns", []), rows))
    return title, parts


def decision_list(items):
    out = ""
    for x in items:
        reasons = "".join(f"<li>{esc(r)}</li>" for r in x.get("reasons", []))
        confirm = f"<li>確認: {esc(x['confirm'])}</li>" if x.get("confirm") else ""
        out += f"<li><strong>{esc(x['decision'])}</strong><ul>{reasons}{confirm}</ul></li>"
    return f"<ul>{out}</ul>"


def touch_list(items):
    out = ""
    for t in items:
        note = f" {esc(t['note'])}" if t.get("note") else ""
        symbols = "".join(
            f'<li><span class="badge">{esc(sym["kind"])}</span><code>{esc(sym["name"])}</code> {esc(sym.get("note", ""))}</li>'
            for sym in t.get("symbols", [])
        )
        nested = f"<ul>{symbols}</ul>" if symbols else ""
        out += f'<li><span class="badge">{esc(t["kind"])}</span><code>{esc(t["path"])}</code>{note}{nested}</li>'
    return f"<ul>{out}</ul>"


def render_plan(data):
    title = f"実装計画: {data['feature']}"
    tasks = data.get("tasks", [])
    setup = data.get("setup", [])
    parts = header(title, data, with_verdict=False)
    parts.append(
        "<h2>方針</h2>"
        f"<p>{esc(data.get('summary', ''))}</p>"
        + bullets(
            [
                f"タスク: {sum(1 for t in tasks if t.get('done'))} / {len(tasks)} 完了",
                f"事前セットアップ: {sum(1 for x in setup if x.get('done'))} / {len(setup)} 完了",
            ]
        )
    )
    if data.get("decisions"):
        parts.append("<h3>判断</h3>" + decision_list(data["decisions"]))
    if data.get("deviations"):
        parts.append("<h3>ずれ</h3>" + decision_list(data["deviations"]))
    if setup:
        rows = [
            [
                f'<td class="status {"pass" if x.get("done") else "blocked"}">{"済" if x.get("done") else "未"}</td>',
                td(x["id"]),
                td(x["title"]),
                td(x.get("to", "")),
                td(x.get("reason", "")),
            ]
            for x in setup
        ]
        parts.append("<h2>事前セットアップ</h2>" + table(["状態", "ID", "内容", "依頼先", "理由"], rows))
    parts.append("<h2>タスク一覧</h2>")
    for t in tasks:
        mark = "☑" if t.get("done") else "☐"
        meta = []
        if t.get("req"):
            meta.append(esc("Req: " + ", ".join(map(str, t["req"]))))
        if t.get("depends"):
            meta.append(esc("Depends: " + ", ".join(map(str, t["depends"]))))
        if t.get("follows"):
            meta.append(f"Follows: <code>{esc(t['follows'])}</code>")
        meta_html = f'<p class="task-meta">{" / ".join(meta)}</p>' if meta else ""
        parts.append(f"<h3>{mark} Task {esc(t['id'])}: {esc(t['title'])}</h3>{meta_html}")
        if t.get("touch"):
            parts.append("<h4>Touch</h4>" + touch_list(t["touch"]))
        if t.get("goal"):
            parts.append(f"<p>{esc(t['goal'])}</p>")
        if t.get("details"):
            parts.append(bullets(t["details"]))
    for a in data.get("appendix", []):
        parts.append(f"<h2>付録: {esc(a['title'])}</h2><pre>{esc(chr(10).join(a.get('lines', [])))}</pre>")
    return title, parts


def as_list(value):
    if isinstance(value, list):
        return value
    return [value] if value not in (None, "") else []


def scenario_cards(items):
    out = ""
    for x in items:
        mark = "☑" if x.get("done") else "☐"
        steps = "".join(f"<li>{esc(t)}</li>" for t in as_list(x.get("steps")))
        reqs = as_list(x.get("requirements"))
        meta = f'<p class="task-meta">要件: {esc(", ".join(map(str, reqs)))}</p>' if reqs else ""
        pre = f"<p>前提: {esc(x['precondition'])}</p>" if x.get("precondition") else ""
        out += (
            f"<h4>{mark} {esc(x.get('id', ''))}. {esc(x.get('title', ''))}</h4>"
            f"{meta}{pre}"
            f"<ol>{steps}</ol><p>期待: {esc(x.get('expect', ''))}</p>{question_block(x.get('question', ''))}"
        )
    return out


def render_scenarios(data):
    title = f"QAシナリオ: {data['feature']}"
    local = data.get("local", [])
    deploy = data.get("deploy", [])
    excluded = data.get("excluded", [])
    parts = header(title, data, with_verdict=False)
    parts.append(
        "<h2>サマリ</h2>"
        + bullets(
            [
                f"ローカル: {sum(1 for x in local if x.get('done'))} / {len(local)} 完了",
                f"デプロイ環境: {sum(1 for x in deploy if x.get('done'))} / {len(deploy)} 完了",
                f"自動QA対象外: {len(excluded)} 件",
            ]
        )
    )
    if local:
        parts.append("<h2>ローカルQAシナリオ</h2>" + scenario_cards(local))
    if deploy:
        parts.append("<h2>デプロイ環境QAシナリオ</h2>" + scenario_cards(deploy))
    if excluded:
        items = [
            f"{x.get('text', '')}（要件: {', '.join(map(str, as_list(x.get('requirements'))))}）検証手段: {x.get('method', '')}"
            for x in excluded
        ]
        parts.append("<h2>自動QA対象外</h2>" + bullets(items))
    return title, parts


def render_feature(data):
    title = f"feature: {data.get('title') or data.get('pr_title') or '無題'}"
    parts = header(title, data, with_verdict=False)
    meta = [
        f"リポジトリ: {data.get('repo', '')}",
        f"ブランチ: {data.get('branch_name', '')}",
        f"PR タイトル: {data.get('pr_title', '')}",
    ]
    meta = [m for m in meta if not m.endswith(": ")]
    if meta:
        parts.append("<h2>概要</h2>" + bullets(meta))
    pr = data.get("pr") or {}
    if str(pr.get("url", "")).startswith("https://"):
        parts.append(f"<p>PR: {link(pr['url'], '#' + str(pr.get('number', '')))}</p>")
    if data.get("notion_url"):
        url = data["notion_url"]
        parts.append(f"<p>Notion: {link(url, url) if url.startswith('https://') else esc(url)}</p>")
    if data.get("memo"):
        parts.append(f"<h2>メモ</h2><p>{esc(data['memo']).replace(chr(10), '<br>')}</p>")
    return title, parts


def render_logs(data):
    title = f"ログ調査: {data['target']}"
    parts = header(title, data, with_verdict=False)
    cond = [
        f"プロファイル: {data.get('profile', '')}。Account: {data.get('account', '')}、Region: {data.get('region', '')}",
        f"ロググループ: {', '.join(as_list(data.get('log_groups', [])))}",
        f"期間: {data.get('period', '')}。epoch: {data.get('epoch', '')}",
        f"検索: {data.get('query', '')}",
    ]
    parts.append("<h2>調査条件</h2>" + bullets(cond))
    if data.get("findings"):
        parts.append("<h2>所見</h2>" + bullets(as_list(data["findings"])))
    if data.get("excerpt"):
        parts.append(f"<h2>該当ログ、抜粋</h2><pre>{esc(data['excerpt'])}</pre>")
    for heading, key in (("読み取れなかったこと", "unknowns"), ("次に見るべきもの", "next")):
        if data.get(key):
            parts.append(f"<h2>{heading}</h2>" + bullets(as_list(data[key])))
    return title, parts


KINDS = {
    "qa-report": render_qa,
    "test-report": render_test,
    "review": render_review,
    "ci-report": render_ci,
    "comment-report": render_comments,
    "bug-report": render_bug,
    "requirements": render_requirements,
    "plan": render_plan,
    "qa": render_scenarios,
    "feature": render_feature,
    "log-report": render_logs,
}


FEATURE_TITLED = ("requirements", "plan", "qa", "qa-report")


def feature_title(src):
    try:
        feature = json.loads(strip_comments(src.with_name("feature.jsonc").read_text(encoding="utf-8")))
    except (OSError, ValueError):
        return ""
    return str(feature.get("title", ""))


def render_file(src):
    if src.stem not in KINDS:
        return f"未対応のレポートです: {src.name}"
    out = src.with_suffix(".html")
    out.unlink(missing_ok=True)
    try:
        data = json.loads(strip_comments(src.read_text(encoding="utf-8")))
    except (IndexError, ValueError) as e:
        return f"{src.name} を JSON として読めません: {e}"
    if src.stem in FEATURE_TITLED:
        data["feature"] = feature_title(src)
    try:
        title, parts = KINDS[src.stem](data)
    except (KeyError, TypeError, AttributeError) as e:
        return f"{src.name} の項目が足りないか形が違います: {e!r}"
    page = (
        '<!doctype html>\n<html lang="ja">\n<head>\n<meta charset="utf-8">\n'
        '<meta name="viewport" content="width=device-width, initial-scale=1">\n'
        f"<title>{esc(title)}</title>\n<style>{CSS}</style>\n</head>\n"
        f"<body>\n<main>\n{''.join(parts)}\n</main>\n<script>{COMMENTS_JS}</script>\n</body>\n</html>\n"
    )
    out.write_text(page, encoding="utf-8")
    return None


def render_dir(directory):
    errors = []
    for src in sorted(directory.glob("*.jsonc")):
        if src.stem in KINDS:
            error = render_file(src)
            if error:
                errors.append(error)
    return errors


def main():
    if len(sys.argv) == 2 and sys.argv[1] == "--hook":
        try:
            path = Path(json.load(sys.stdin)["tool_input"]["file_path"])
        except (ValueError, KeyError, TypeError):
            return
        if path.suffix != ".jsonc" or path.stem not in KINDS:
            return
        errors = render_dir(path.parent)
        if errors:
            print("HTML の再生成に失敗しました。\n" + "\n".join(errors), file=sys.stderr)
            sys.exit(2)
        return
    if len(sys.argv) != 2:
        sys.exit("使い方: render.py <ディレクトリ>、または render.py --hook")
    target = Path(sys.argv[1])
    errors = render_dir(target)
    if errors:
        sys.exit("\n".join(errors))


if __name__ == "__main__":
    main()
