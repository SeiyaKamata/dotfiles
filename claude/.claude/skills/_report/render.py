#!/usr/bin/env python3
import html
import json
import sys
from pathlib import Path

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
body { margin: 0; padding: 32px 16px 64px; background: var(--bg); color: var(--fg);
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
ul { padding-left: 20px; }
"""

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


def header(title, data):
    verdict = data["verdict"]
    return [
        f"<h1>{esc(title)}</h1>",
        '<p class="meta">'
        f'<span class="verdict {status_class(verdict)}">{esc(verdict)}</span>'
        f"{esc(data.get('branch', ''))} @ {esc(str(data.get('head', ''))[:7])} / {esc(data.get('ran_at', ''))}</p>",
    ]


def table(columns, rows):
    head = "".join(f"<th>{esc(c)}</th>" for c in columns)
    body = "".join("<tr>" + "".join(cells) + "</tr>" for cells in rows)
    return f"<table><thead><tr>{head}</tr></thead><tbody>{body}</tbody></table>"


def td(value):
    return f"<td>{esc(value)}</td>"


def td_status(value):
    return f'<td class="status {status_class(value)}">{esc(value)}</td>'


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


KINDS = {
    "qa-report": render_qa,
    "test-report": render_test,
}


def main():
    if len(sys.argv) != 2:
        sys.exit("使い方: render.py <qa-report|test-report>.jsonc")
    src = Path(sys.argv[1])
    if src.stem not in KINDS:
        sys.exit(f"未対応のレポートです: {src.name}")
    try:
        data = json.loads(strip_comments(src.read_text(encoding="utf-8")))
    except (IndexError, ValueError) as e:
        sys.exit(f"{src.name} を JSON として読めません: {e}")
    try:
        title, parts = KINDS[src.stem](data)
    except (KeyError, TypeError, AttributeError) as e:
        sys.exit(f"{src.name} の項目が足りないか形が違います: {e!r}")
    page = (
        '<!doctype html>\n<html lang="ja">\n<head>\n<meta charset="utf-8">\n'
        '<meta name="viewport" content="width=device-width, initial-scale=1">\n'
        f"<title>{esc(title)}</title>\n<style>{CSS}</style>\n</head>\n"
        f"<body>\n<main>\n{''.join(parts)}\n</main>\n</body>\n</html>\n"
    )
    out = src.with_suffix(".html")
    out.write_text(page, encoding="utf-8")
    print(out)


main()
