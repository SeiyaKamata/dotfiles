#!/usr/bin/env python3
import html
import re
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


def esc(value):
    return html.escape(value, quote=True)


def split_frontmatter(text):
    match = re.match(r"---\n(.*?)\n---\n", text, re.S)
    if not match:
        return {}, text
    front = {}
    for line in match.group(1).splitlines():
        key, _, value = line.partition(":")
        front[key.strip()] = value.strip()
    return front, text[match.end():]


def split_sections(body):
    title = ""
    sections = {}
    current = None
    for line in body.splitlines():
        if line.startswith("# ") and not title:
            title = line[2:].strip()
        elif line.startswith("## "):
            current = line[3:].strip()
            sections[current] = []
        elif current is not None:
            sections[current].append(line)
    return title, {name: "\n".join(lines).strip() for name, lines in sections.items()}


def parse_table(block):
    rows = []
    for line in block.splitlines():
        if not line.startswith("|"):
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if all(re.fullmatch(r":?-+:?", c) for c in cells):
            continue
        rows.append(cells)
    return rows[0], rows[1:]


def status_class(value):
    return {"pass": "pass", "fail": "fail"}.get(value.lower(), "blocked")


def render_results(block):
    header, rows = parse_table(block)
    head = "".join(f"<th>{esc(c)}</th>" for c in header[:4])
    body = ""
    for cells in rows:
        q, title, verdict, cause = (cells + [""] * 4)[:4]
        body += (
            f"<tr><td>{esc(q)}</td><td>{esc(title)}</td>"
            f'<td class="status {status_class(verdict)}">{esc(verdict)}</td><td>{esc(cause)}</td></tr>'
        )
    table = f"<table><thead><tr>{head}</tr></thead><tbody>{body}</tbody></table>"
    figures = ""
    for cells in rows:
        q, title, verdict, _ = (cells + [""] * 4)[:4]
        shot = cells[4] if len(cells) > 4 else ""
        if shot:
            figures += (
                f'<figure><img src="{esc(shot)}" alt="{esc(q)}" loading="lazy">'
                f'<figcaption><span class="{status_class(verdict)}">{esc(verdict)}</span> '
                f"{esc(q)}: {esc(title)}</figcaption></figure>"
            )
    return table, figures


def main():
    if len(sys.argv) != 2:
        sys.exit("使い方: render-report.py <qa-report.md>")
    src = Path(sys.argv[1])
    front, body = split_frontmatter(src.read_text(encoding="utf-8"))
    title, sections = split_sections(body)

    summary = sections.get("サマリ", "")
    verdict_match = re.search(r"判定:\s*(\w+)", summary)
    verdict = verdict_match.group(1) if verdict_match else ""

    parts = [
        f"<h1>{esc(title)}</h1>",
        '<p class="meta">'
        f'<span class="verdict {status_class(verdict)}">{esc(verdict)}</span>'
        f'{esc(front.get("branch", ""))} @ {esc(front.get("head", "")[:7])} / {esc(front.get("ran_at", ""))}</p>',
    ]

    if summary:
        items = "".join(f"<li>{esc(line[2:])}</li>" for line in summary.splitlines() if line.startswith("- "))
        parts.append(f"<h2>サマリ</h2><ul>{items}</ul>")

    results = sections.get("シナリオ結果")
    if results:
        table, figures = render_results(results)
        parts.append(f"<h2>シナリオ結果</h2>{table}")
        if figures:
            parts.append(f'<h2>画面のスクリーンショット</h2><div class="grid">{figures}</div>')

    failures = sections.get("失敗シナリオ")
    if failures:
        items = "".join(f"<li>{esc(line.lstrip('- ').strip())}</li>" for line in failures.splitlines() if line.strip())
        parts.append(f"<h2>失敗シナリオ</h2><ul>{items}</ul>")

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
