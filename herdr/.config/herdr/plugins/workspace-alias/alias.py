#!/usr/bin/env python3
"""herdr workspace のラベルを、今いるプロジェクトの略称へ自動リネームする。

判定は cwd の「どのプロジェクトの中にいるか」で行う（cwd の basename ではない）:
  .../worktrees/<SLOT>/<repo>/...  → <repo> のプロジェクト。ラベル = 略称(SLOT) 例 EV2(WS1)
  .../repos/<repo>/...             → <repo> のプロジェクト。ラベル = 略称       例 EV2
  上記以外（worktrees/repos の外）  → 触らない（None）

略称表は <root>/CLAUDE.md（worktrees/repos の親）の「## プロジェクト略称」を動的に読む。
表に無いプロジェクトはディレクトリ名をそのまま使う（+ worktree なら (SLOT)）。

呼び出しモード:
  alias.py --cwd PATH   … chpwd フック用。HERDR_WORKSPACE_ID の space をその cwd 基準で更新。
  alias.py              … イベントフック用。HERDR_WORKSPACE_ID があればその space、無ければ全 space。
  alias.py --all        … 全 space を明示的にバックフィル。
"""
import json
import os
import re
import subprocess
import sys
import time

HERDR = os.environ.get("HERDR_BIN_PATH") or "herdr"


def sh(args):
    return subprocess.run(args, capture_output=True, text=True)


def snapshot():
    r = sh([HERDR, "api", "snapshot"])
    if r.returncode != 0:
        return None
    try:
        return json.loads(r.stdout)["result"]["snapshot"]
    except Exception:
        return None


def cwd_of(snap, wid):
    for coll in ("agents", "panes"):
        for p in snap.get(coll, []):
            if p.get("workspace_id") == wid:
                c = p.get("foreground_cwd") or p.get("cwd")
                if c:
                    return c
    return None


def label_of(wid):
    r = sh([HERDR, "workspace", "get", wid])
    try:
        return json.loads(r.stdout)["result"]["workspace"]["label"]
    except Exception:
        return None


def project_of(cwd):
    """cwd から (project_dir, slot, root) を求める。管理対象外なら (None, None, None)。"""
    m = re.search(r"^(.*)/worktrees/([^/]+)/([^/]+)", cwd)
    if m:
        return m.group(3), m.group(2), m.group(1)
    m = re.search(r"^(.*)/repos/([^/]+)", cwd)
    if m:
        return m.group(2), None, m.group(1)
    return None, None, None


def load_aliases(root):
    """<root>/CLAUDE.md の「## プロジェクト略称」表を dir名 -> 略称(小文字) に変換。"""
    try:
        with open(os.path.join(root, "CLAUDE.md"), encoding="utf-8") as f:
            text = f.read()
    except OSError:
        return {}
    m = re.search(r"##\s*プロジェクト略称(.*?)(?:\n##\s|\Z)", text, re.S)
    section = m.group(1) if m else text
    mapping = {}
    for line in section.splitlines():
        line = line.strip()
        if not line.startswith("|"):
            continue
        cells = [c.strip() for c in line.strip("|").split("|")]
        if len(cells) < 2:
            continue
        alias, projects = cells[0], cells[1]
        if alias in ("略称", "") or set(alias) <= set("-: "):
            continue
        for proj in projects.split(","):
            name = re.split(r"[（(]", proj)[0].replace("`", "").strip()
            if name:
                mapping[name] = alias
    return mapping


def compute_label(cwd):
    """目標ラベルを返す。管理対象外なら None（ラベルを変更しない）。"""
    proj, slot, root = project_of(cwd)
    if not proj:
        return None
    alias = load_aliases(root).get(proj)
    label = alias.upper() if alias else proj
    if slot:
        label += f"({slot})"
    return label


def apply(wid, cwd, current_label):
    want = compute_label(cwd)
    if not want or want == current_label:
        return
    sh([HERDR, "workspace", "rename", wid, want])


def main():
    args = sys.argv[1:]

    # chpwd モード: --cwd で明示された cwd を使って今の space を更新
    if "--cwd" in args:
        cwd = args[args.index("--cwd") + 1]
        wid = os.environ.get("HERDR_WORKSPACE_ID")
        if wid:
            apply(wid, cwd, label_of(wid))
        return

    # イベント / バックフィルモード
    snap = snapshot()
    if not snap:
        return
    target = None if "--all" in args else os.environ.get("HERDR_WORKSPACE_ID")
    workspaces = snap["workspaces"]
    if target:
        for _ in range(5):  # 作成直後は cwd 未確定のことがあるので軽くリトライ
            if cwd_of(snap, target):
                break
            time.sleep(0.2)
            snap = snapshot() or snap
        workspaces = snap["workspaces"]
        w = next((x for x in workspaces if x["workspace_id"] == target), None)
        if w:
            apply(target, cwd_of(snap, target) or "", w.get("label"))
    else:
        for w in workspaces:
            c = cwd_of(snap, w["workspace_id"])
            if c:
                apply(w["workspace_id"], c, w.get("label"))


if __name__ == "__main__":
    main()
