import { execFile, execFileSync } from "node:child_process";

// Hunk のセッションは起動時に渡した 1 つの diff で固定され、拡張の command context には
// セッションを別の diff へ張り替える API が無い。そのため「次のコミット」を実現するには
// 別プロセスとして `hunk session reload` を叩き、デーモン経由で live セッションの中身を
// 差し替える。この CLI 往復が唯一の手段。
//
// キー:
//   ctrl+n  次のコミットへ（古い→新しい）
//   ctrl+p  前のコミットへ。先頭でさらに戻すと overview に復帰
//   ctrl+g  overview（base...HEAD の全体差分）へ復帰
//
// [extension.commit-stepper] で base とキーを上書きできる。

type Ctx = { cwd: string; notify: (message: string, type?: "info" | "warning" | "error") => void };

type Commit = { hash: string; subject: string };

const OVERVIEW = -1;

export default function (hunk: any) {
  const cfg = (hunk.config ?? {}) as {
    base?: string;
    maxCommits?: number;
    keys?: { next?: string; prev?: string; overview?: string };
  };
  const keys = {
    next: cfg.keys?.next ?? "ctrl+n",
    prev: cfg.keys?.prev ?? "ctrl+p",
    overview: cfg.keys?.overview ?? "ctrl+g",
  };
  const maxCommits = Number.isInteger(cfg.maxCommits) && cfg.maxCommits! > 0 ? cfg.maxCommits! : 40;

  let pos = OVERVIEW;

  const hunkBin = process.execPath && /hunk$/.test(process.execPath) ? process.execPath : "hunk";

  const git = (cwd: string, args: string[]): string =>
    execFileSync("git", args, { cwd, encoding: "utf8" }).trim();

  const repoRoot = (cwd: string): string | null => {
    try {
      return git(cwd, ["rev-parse", "--show-toplevel"]);
    } catch {
      return null;
    }
  };

  const refExists = (cwd: string, ref: string): boolean => {
    try {
      git(cwd, ["rev-parse", "--verify", "--quiet", `${ref}^{commit}`]);
      return true;
    } catch {
      return false;
    }
  };

  // base...HEAD の左辺。設定 > upstream > origin/HEAD の順で最初に使えるものを採る。
  const resolveBase = (cwd: string): string | null => {
    const candidates: string[] = [];
    if (cfg.base) candidates.push(cfg.base);
    try {
      candidates.push(git(cwd, ["rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{upstream}"]));
    } catch {
      /* upstream 未設定 */
    }
    try {
      const head = git(cwd, ["symbolic-ref", "--short", "refs/remotes/origin/HEAD"]);
      if (head) candidates.push(head);
    } catch {
      /* origin/HEAD 未設定 */
    }
    for (const ref of candidates) {
      if (!ref || !refExists(cwd, ref)) continue;
      try {
        if (git(cwd, ["rev-parse", ref]) === git(cwd, ["rev-parse", "HEAD"])) continue;
        git(cwd, ["merge-base", "--is-ancestor", ref, "HEAD"]);
        return ref;
      } catch {
        /* HEAD の祖先でない */
      }
    }
    return null;
  };

  // 古い順。base があれば base..HEAD、無ければ直近 maxCommits 件。
  const listCommits = (cwd: string, base: string | null): Commit[] => {
    const range = base ? `${base}..HEAD` : `-n${maxCommits}`;
    const out = git(cwd, [
      "log",
      "--reverse",
      "--no-merges",
      "--format=%H%x1f%s",
      ...(base ? [range] : [range, "HEAD"]),
    ]);
    if (!out) return [];
    return out.split("\n").map((line) => {
      const [hash, subject] = line.split("\x1f");
      return { hash, subject };
    });
  };

  const reload = (root: string, tail: string[], label: string) => {
    execFile(hunkBin, ["session", "reload", "--repo", root, "--", ...tail], (err) => {
      if (err) ctx.notify(`commit-stepper: reload 失敗 — ${err.message}`, "warning");
      else ctx.notify(`commit-stepper: ${label}`);
    });
  };

  let ctx: Ctx = { cwd: process.cwd(), notify: () => {} };

  const step = (direction: "next" | "prev" | "overview") => (handlerCtx: Ctx) => {
    ctx = handlerCtx;
    const cwd = handlerCtx.cwd;
    const root = repoRoot(cwd);
    if (!root) {
      handlerCtx.notify("commit-stepper: git リポジトリではありません", "warning");
      return;
    }
    const base = resolveBase(cwd);

    if (direction === "overview") {
      if (!base) {
        handlerCtx.notify("commit-stepper: base を特定できないため overview に戻れません", "warning");
        return;
      }
      pos = OVERVIEW;
      reload(root, ["diff", `${base}...HEAD`], `overview (${base}...HEAD)`);
      return;
    }

    const commits = listCommits(cwd, base);
    if (commits.length === 0) {
      handlerCtx.notify("commit-stepper: 対象コミットがありません", "warning");
      return;
    }

    if (direction === "next") {
      pos = pos === OVERVIEW ? 0 : Math.min(pos + 1, commits.length - 1);
    } else {
      if (pos <= 0) {
        if (!base) {
          handlerCtx.notify("commit-stepper: 先頭です", "info");
          return;
        }
        pos = OVERVIEW;
        reload(root, ["diff", `${base}...HEAD`], `overview (${base}...HEAD)`);
        return;
      }
      pos -= 1;
    }

    const c = commits[pos];
    const short = c.hash.slice(0, 9);
    reload(root, ["show", c.hash], `[${pos + 1}/${commits.length}] ${short} ${c.subject}`);
  };

  hunk.registerCommand({ id: "commit-stepper.next", title: "Commit stepper: next commit", key: keys.next }, step("next"));
  hunk.registerCommand({ id: "commit-stepper.prev", title: "Commit stepper: previous commit", key: keys.prev }, step("prev"));
  hunk.registerCommand(
    { id: "commit-stepper.overview", title: "Commit stepper: back to overview", key: keys.overview },
    step("overview"),
  );
}
