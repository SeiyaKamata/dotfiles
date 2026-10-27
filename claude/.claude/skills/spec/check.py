import json
import re
import sys
from pathlib import Path

ARROW = " → "
EVENT_TYPES = ("とき", "あいだ", "場合")
VAGUE = ("適切に", "必要に応じて", "適宜", "いい感じ")
PAREN = re.compile(r"[（(]([^）)]*)[）)]")
BRANCH = re.compile(r"^[a-z0-9]+/[a-z0-9]+(-[a-z0-9]+)*$")
TOP_STRINGS = ("overview",)


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


def blank(value):
    return not isinstance(value, str) or not value.strip()


def check_text(where, text, errors):
    if blank(text):
        errors.append(f"{where}: text が空か文字列でない")
        return
    if "\n" in text:
        errors.append(f"{where}: text に改行がある")
    if text.startswith("【異常】"):
        if text.count(ARROW) != 1 or text.split(ARROW)[0] == "【異常】":
            errors.append(f"{where}: 【異常】型は「【異常】<トリガー> → <振る舞い>」の形にする: {text}")
    elif ARROW in text:
        head, _, tail = text.partition(ARROW)
        if not head.endswith(EVENT_TYPES) or not tail.strip() or ARROW in tail:
            errors.append(f"{where}: 矢印の左が「とき」「あいだ」「場合」で終わる 1 本の矢印にする: {text}")
    elif "→" in text:
        errors.append(f"{where}: 矢印の前後に半角スペースを置く: {text}")
    for word in VAGUE:
        if word in text:
            errors.append(f"{where}: 曖昧語「{word}」がある: {text}")
    for m in PAREN.finditer(text):
        if len(m.group(1)) > 6:
            errors.append(f"{where}: 括弧に文の形の補足がある: {m.group(0)}")


def check_question(where, value, errors):
    if not isinstance(value, str):
        errors.append(f"{where}: question が文字列でない")


def check_scope(scope, errors):
    for i, s in enumerate(scope, 1):
        where = f"out_of_scope[{i}]"
        if not isinstance(s, dict):
            errors.append(f"{where}: オブジェクトでない")
            continue
        for key in ("item", "reason"):
            if blank(s.get(key)):
                errors.append(f"{where}: {key} が空か文字列でない")
        check_question(where, s.get("question"), errors)
        text = f"{s.get('item', '')}{s.get('reason', '')}"
        if "【異常】" in text or ARROW in text:
            errors.append(f"{where}: スコープ外に EARS の記法を使わない")


def check_requirement(name, r, expected, errors):
    rid = r.get("id") if isinstance(r, dict) else None
    where = f"{name} Requirement {rid}"
    if rid != expected:
        errors.append(f"{where}: id は主体をまたいだ連番にする。期待値は {expected}")
    if not isinstance(r, dict):
        return expected + 1
    if blank(r.get("title")):
        errors.append(f"{where}: title が空か文字列でない")
    lines = r.get("lines")
    if not isinstance(lines, list) or not lines:
        errors.append(f"{where}: lines が空か配列でない")
        lines = []
    for j, line in enumerate(lines, 1):
        lwhere = f"{where} 行 {j}"
        if not isinstance(line, dict):
            errors.append(f"{lwhere}: オブジェクトでない")
            continue
        check_text(lwhere, line.get("text"), errors)
        check_question(lwhere, line.get("question"), errors)
    return (rid if isinstance(rid, int) else expected) + 1


def check_subjects(subjects, errors):
    expected = 1
    for subject in subjects:
        name = subject.get("name") if isinstance(subject, dict) else None
        if blank(name):
            errors.append("subjects: name が空か文字列でない")
            continue
        reqs = subject.get("requirements")
        if not isinstance(reqs, list) or not reqs:
            errors.append(f"{name}: requirements が空か配列でない")
            continue
        for r in reqs:
            expected = check_requirement(name, r, expected, errors)


def check_appendix(appendix, errors):
    for i, t in enumerate(appendix, 1):
        where = f"appendix[{i}]"
        if not isinstance(t, dict):
            errors.append(f"{where}: オブジェクトでない")
            continue
        cols, rows = t.get("columns"), t.get("rows")
        if blank(t.get("title")):
            errors.append(f"{where}: title が空か文字列でない")
        if not isinstance(cols, list) or not cols or not isinstance(rows, list):
            errors.append(f"{where}: columns と rows を配列にする")
            continue
        for k, row in enumerate(rows, 1):
            if not isinstance(row, list) or len(row) != len(cols):
                errors.append(f"{where} 行 {k}: セル数が columns の {len(cols)} と合わない")


def check_feature(feature):
    errors = []
    for key in ("repo", "title", "branch_name"):
        if blank(feature.get(key)):
            errors.append(f"feature.jsonc の {key}: 空か文字列でない")
    for key in ("notion_url", "pr_title"):
        if not isinstance(feature.get(key), str):
            errors.append(f"feature.jsonc の {key}: 文字列でない、または無い")
    branch = feature.get("branch_name")
    if isinstance(branch, str) and branch and not BRANCH.match(branch):
        errors.append(f"feature.jsonc の branch_name: `<type>/<英小文字・数字・ハイフン>` の形でない: {branch}")
    return errors


def check(data):
    errors = []
    for key in TOP_STRINGS:
        if not isinstance(data.get(key), str):
            errors.append(f"{key}: 文字列でない、または無い")
    if isinstance(data.get("overview"), str) and not data["overview"].strip():
        errors.append("overview: 空")

    oq = data.get("open_questions")
    if not isinstance(oq, list) or any(blank(q) for q in oq):
        errors.append("open_questions: 空でない文字列の配列にする")

    scope = data.get("out_of_scope")
    if isinstance(scope, list):
        check_scope(scope, errors)
    else:
        errors.append("out_of_scope: 配列でない")

    subjects = data.get("subjects")
    if isinstance(subjects, list) and subjects:
        check_subjects(subjects, errors)
    else:
        errors.append("subjects: 1 件以上の配列にする")

    appendix = data.get("appendix")
    if isinstance(appendix, list):
        check_appendix(appendix, errors)
    else:
        errors.append("appendix: 配列でない")
    return errors


def load(src):
    try:
        data = json.loads(strip_comments(src.read_text(encoding="utf-8")))
    except (OSError, IndexError, ValueError) as e:
        sys.exit(f"{src.name} を読めないか JSON として不正です: {e}")
    if not isinstance(data, dict):
        sys.exit(f"{src.name} の最上位がオブジェクトでない")
    return data


def main():
    errors = check_feature(load(Path(".specs/feature.jsonc"))) + check(load(Path(".specs/requirements.jsonc")))
    if errors:
        print("\n".join(errors))
        sys.exit(1)
    print("OK")


if __name__ == "__main__":
    main()
