import re

ARROW = " → "
EVENT_TYPES = ("とき", "あいだ", "場合")
VAGUE = ("適切に", "必要に応じて", "適宜", "いい感じ")
PAREN = re.compile(r"[（(]([^）)]*)[）)]")
BRANCH = re.compile(r"^[a-z0-9]+/[a-z0-9]+(-[a-z0-9]+)*$")
TOP_STRINGS = ("overview",)


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
    for key in ("repo", "title", "branch_name", "pr_title"):
        if blank(feature.get(key)):
            errors.append(f"{key}: 空か文字列でない")
    if not isinstance(feature.get("notion_url"), str):
        errors.append("notion_url: 文字列でない、または無い")
    pr_title = feature.get("pr_title")
    if isinstance(pr_title, str) and pr_title and not pr_title.startswith("【鎌田QA】"):
        errors.append("pr_title: `【鎌田QA】` で始まっていない")
    branch = feature.get("branch_name")
    if isinstance(branch, str) and branch and not BRANCH.match(branch):
        errors.append(f"branch_name: `<type>/<英小文字・数字・ハイフン>` の形でない: {branch}")
    return errors


def check_requirements(data):
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


def check_strings(where, value, errors):
    if not isinstance(value, list) or any(blank(v) for v in value):
        errors.append(f"{where}: 空でない文字列の配列にする")


def check_requirement_refs(where, refs, known, errors):
    if not isinstance(refs, list) or not refs or not all(isinstance(r, int) and not isinstance(r, bool) for r in refs):
        errors.append(f"{where}: 要件番号の整数を 1 件以上並べた配列にする")
        return
    if known is not None:
        for r in refs:
            if r not in known:
                errors.append(f"{where}: requirements.jsonc に無い要件番号 {r}")


def check_flag(where, value, errors):
    if not isinstance(value, bool):
        errors.append(f"{where}: done が true か false でない")


def check_judgments(key, items, errors):
    if not isinstance(items, list):
        errors.append(f"{key}: 配列でない")
        return
    for i, d in enumerate(items, 1):
        where = f"{key}[{i}]"
        if not isinstance(d, dict):
            errors.append(f"{where}: オブジェクトでない")
            continue
        if blank(d.get("decision")):
            errors.append(f"{where}: decision が空か文字列でない")
        elif "、" in d["decision"]:
            errors.append(f"{where}: decision に読点がある。読点を使わない 1 文にする")
        check_strings(f"{where} reasons", d.get("reasons"), errors)
        check_question(f"{where} confirm", d.get("confirm"), errors)


def check_setup(setup, errors):
    ids = set()
    if not isinstance(setup, list):
        errors.append("setup: 配列でない")
        return ids
    for i, s in enumerate(setup, 1):
        where = f"setup[{i}]"
        if not isinstance(s, dict):
            errors.append(f"{where}: オブジェクトでない")
            continue
        sid = s.get("id")
        if not isinstance(sid, str) or not re.fullmatch(r"S\d+", sid):
            errors.append(f"{where}: id は `S<n>` の文字列にする")
        else:
            ids.add(sid)
        for key in ("title", "reason"):
            if blank(s.get(key)):
                errors.append(f"{where}: {key} が空か文字列でない")
        if not isinstance(s.get("to"), str):
            errors.append(f"{where}: to が文字列でない。repo 内の作業なら空文字にする")
        check_flag(where, s.get("done"), errors)
    return ids


def check_touch(where, touch, errors):
    if not isinstance(touch, list):
        errors.append(f"{where} touch: 配列でない")
        return
    for k, t in enumerate(touch, 1):
        twhere = f"{where} touch[{k}]"
        if not isinstance(t, dict):
            errors.append(f"{twhere}: オブジェクトでない")
            continue
        if t.get("kind") not in ("N", "M", "D"):
            errors.append(f"{twhere}: kind は N か M か D にする")
        if blank(t.get("path")):
            errors.append(f"{twhere}: path が空か文字列でない")
        if not isinstance(t.get("note"), str):
            errors.append(f"{twhere}: note が文字列でない")
        symbols = t.get("symbols")
        if not isinstance(symbols, list):
            errors.append(f"{twhere}: symbols が配列でない")
            continue
        for m, sym in enumerate(symbols, 1):
            if not isinstance(sym, dict) or sym.get("kind") not in ("N", "M", "D") or blank(sym.get("name")):
                errors.append(f"{twhere} symbols[{m}]: kind は N か M か D、name は空でない文字列にする")
            elif not isinstance(sym.get("note"), str):
                errors.append(f"{twhere} symbols[{m}]: note が文字列でない")


def check_tasks(tasks, setup_ids, known, errors):
    covered = set()
    for i, t in enumerate(tasks, 1):
        where = f"tasks[{i}]"
        if not isinstance(t, dict):
            errors.append(f"{where}: オブジェクトでない")
            continue
        if t.get("id") != i:
            errors.append(f"{where}: id は 1 からの連番にする。期待値は {i}")
        for key in ("title", "goal"):
            if blank(t.get(key)):
                errors.append(f"{where}: {key} が空か文字列でない")
        check_flag(where, t.get("done"), errors)
        if "req" in t:
            check_requirement_refs(f"{where} req", t["req"], known, errors)
            if isinstance(t["req"], list):
                covered.update(r for r in t["req"] if isinstance(r, int))
        for dep in t.get("depends", []) if isinstance(t.get("depends", []), list) else [None]:
            if dep not in setup_ids:
                errors.append(f"{where}: depends は setup の `S<n>` だけを参照する: {dep}")
        if not isinstance(t.get("follows", ""), str):
            errors.append(f"{where}: follows が文字列でない")
        check_touch(where, t.get("touch", []), errors)
        if "details" in t:
            check_strings(f"{where} details", t["details"], errors)
    return covered


def check_plan(data, known=None):
    errors = []
    if blank(data.get("summary")):
        errors.append("summary: 空か文字列でない")
    check_judgments("decisions", data.get("decisions"), errors)
    check_judgments("deviations", data.get("deviations"), errors)
    setup_ids = check_setup(data.get("setup"), errors)
    tasks = data.get("tasks")
    if isinstance(tasks, list) and tasks:
        covered = check_tasks(tasks, setup_ids, known, errors)
        for rid in sorted((known or set()) - covered):
            errors.append(f"tasks: 要件 {rid} がどのタスクの req にも現れない")
    else:
        errors.append("tasks: 1 件以上の配列にする")
    appendix = data.get("appendix")
    if not isinstance(appendix, list):
        errors.append("appendix: 配列でない")
        return errors
    for i, a in enumerate(appendix, 1):
        where = f"appendix[{i}]"
        if not isinstance(a, dict) or blank(a.get("title")):
            errors.append(f"{where}: title が空か文字列でない")
            continue
        lines = a.get("lines")
        if not isinstance(lines, list) or not lines or any(not isinstance(v, str) or "\n" in v for v in lines):
            errors.append(f"{where}: lines は改行を含まない文字列の配列にする")
    return errors


def check_scenarios(data, known=None):
    errors = []
    prefixes = {"local": "Q", "deploy": "V"}
    for key, prefix in prefixes.items():
        items = data.get(key)
        if not isinstance(items, list):
            errors.append(f"{key}: 配列でない")
            continue
        for i, s in enumerate(items, 1):
            where = f"{key}[{i}]"
            if not isinstance(s, dict):
                errors.append(f"{where}: オブジェクトでない")
                continue
            if s.get("id") != f"{prefix}{i}":
                errors.append(f"{where}: id は `{prefix}<n>` の連番にする。期待値は {prefix}{i}")
            for field in ("title", "expect") + (("precondition",) if key == "local" else ()):
                if blank(s.get(field)):
                    errors.append(f"{where}: {field} が空か文字列でない")
            if not isinstance(s.get("steps"), list) or not s["steps"]:
                errors.append(f"{where}: steps が空か配列でない")
            else:
                check_strings(f"{where} steps", s["steps"], errors)
            check_flag(where, s.get("done"), errors)
            check_requirement_refs(f"{where} requirements", s.get("requirements"), known, errors)
            check_question(where, s.get("question"), errors)
    excluded = data.get("excluded")
    if not isinstance(excluded, list):
        errors.append("excluded: 配列でない")
        return errors
    for i, e in enumerate(excluded, 1):
        where = f"excluded[{i}]"
        if not isinstance(e, dict):
            errors.append(f"{where}: オブジェクトでない")
            continue
        for field in ("text", "method"):
            if blank(e.get(field)):
                errors.append(f"{where}: {field} が空か文字列でない")
        check_requirement_refs(f"{where} requirements", e.get("requirements"), known, errors)
    return errors


CHECKS = {
    "requirements": lambda data, known: check_requirements(data),
    "feature": lambda data, known: check_feature(data),
    "plan": check_plan,
    "qa": check_scenarios,
}
