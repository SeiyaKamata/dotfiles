import { execFile, execFileSync } from "node:child_process";

// Hunk のセッションは起動時に渡した 1 つの diff で固定され、拡張の command context には
// セッションを別の diff へ張り替える API が無い。そのため「次のコミット」を実現するには
// 別プロセスとして `hunk session reload` を叩き、デーモン経由で live セッションの中身を
// 差し替える。この CLI 往復が唯一の手段。
//
// レビュー対象は現在のセッションから割り出す。`hunk session get --json` の title が
//   "<repo> <base>...<tip>" / "<repo> <base>..<tip>" → その範囲
//   "<repo> show <ref>"                             → base は自動判定して base..<ref>
//   "<repo> working tree"                           → base..HEAD（overview は作業ツリー）
// これで `git switch` せず `hunk diff origin/main...FETCH_HEAD` のように開いたPRでも
// そのまま歩ける。HEAD には触れない。
//
// キー:
//   ctrl+n  次のコミットへ（古い→新しい）
//   ctrl+p  前のコミットへ。先頭でさらに戻すと overview に復帰
//   ctrl+g  overview（レビュー対象の全体差分）へ復帰
//
// [extension.commit-stepper] で base とキーを上書きできる。

type Ctx = { cwd: string; notify: (message: string, type?: "info" | "warning" | "error") => void };

type Commit = { hash: string; subject: string };

type Target = {
  base: string | null;
  tip: string;
  commits: Commit[];
  overview: string[];
};

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

  const hunkBin = process.execPath && /hunk$/.test(process.execPath) ? process.execPath : "hunk";

  let ctx: Ctx = { cwd: process.cwd(), notify: () => {} };
  let target: Target | null = null;
  let pos = OVERVIEW;
  let lastReloadSpec = ""; // 直近に自分が張った diff spec。live と一致する間はレビュー継続とみなす。

  const git = (cwd: string, args: string[]): string =>
    execFileSync("git", args, { cwd, encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] }).trim();

  const tryGit = (cwd: string, args: string[]): string | null => {
    try {
      return git(cwd, args);
    } catch {
      return null;
    }
  };

  const repoRoot = (cwd: string): string | null => tryGit(cwd, ["rev-parse", "--show-toplevel"]);

  const resolveCommit = (cwd: string, ref: string): string | null =>
    tryGit(cwd, ["rev-parse", "--verify", "--quiet", `${ref}^{commit}`]);

  // base 候補。設定 > upstream > origin/HEAD の順で、tip の祖先かつ tip 自身でない最初のもの。
  const resolveBase = (cwd: string, tip: string): string | null => {
    const candidates: string[] = [];
    if (cfg.base) candidates.push(cfg.base);
    const upstream = tryGit(cwd, ["rev-parse", "--abbrev-ref", "--symbolic-full-name", `${tip}@{upstream}`]);
    if (upstream) candidates.push(upstream);
    const originHead = tryGit(cwd, ["symbolic-ref", "--short", "refs/remotes/origin/HEAD"]);
    if (originHead) candidates.push(originHead);

    const tipSha = resolveCommit(cwd, tip);
    for (const ref of candidates) {
      const sha = resolveCommit(cwd, ref);
      if (!sha || sha === tipSha) continue;
      if (tryGit(cwd, ["merge-base", "--is-ancestor", ref, tip]) !== null) return ref;
    }
    return null;
  };

  const listCommits = (cwd: string, base: string | null, tip: string): Commit[] => {
    const range = base ? `${base}..${tip}` : tip;
    const args = ["log", "--reverse", "--no-merges", "--format=%H%x1f%s"];
    if (base) args.push(range);
    else args.push(`-n${maxCommits}`, tip);
    const out = tryGit(cwd, args);
    if (!out) return [];
    return out.split("\n").map((line) => {
      const [hash, subject] = line.split("\x1f");
      return { hash, subject };
    });
  };

  const liveSpec = (cwd: string, root: string): { spec: string; kind: string } | null => {
    const json = execFileSyncSafe(hunkBin, ["session", "get", "--repo", root, "--json"]);
    if (!json) return null;
    try {
      const parsed = JSON.parse(json);
      const s = parsed.session ?? parsed;
      const title: string = s.title ?? "";
      const label = root.split("/").filter(Boolean).pop() ?? "";
      const spec = label && title.startsWith(`${label} `) ? title.slice(label.length + 1) : title;
      return { spec: spec.trim(), kind: s.inputKind ?? "" };
    } catch {
      return null;
    }
  };

  function execFileSyncSafe(bin: string, args: string[]): string | null {
    try {
      return execFileSync(bin, args, { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] });
    } catch {
      return null;
    }
  }

  const detectTarget = (cwd: string, root: string): Target => {
    const live = liveSpec(cwd, root);
    const spec = live?.spec ?? "";

    // "<base><..|...><tip>"
    const range = spec.match(/^(\S.*?)(\.\.\.?)(\S.*)$/);
    if (range) {
      const [, base, dots, tipRef] = range;
      const tip = resolveCommit(cwd, tipRef) ?? "HEAD";
      return { base, tip, commits: listCommits(cwd, base, tip), overview: ["diff", `${base}${dots}${tipRef}`] };
    }

    if (live?.kind === "show" && spec.startsWith("show ")) {
      const ref = spec.slice(5).trim();
      const tip = resolveCommit(cwd, ref) ?? "HEAD";
      const base = resolveBase(cwd, tip);
      return {
        base,
        tip,
        commits: listCommits(cwd, base, tip),
        overview: base ? ["diff", `${base}...${tip}`] : ["show", ref],
      };
    }

    // working tree / 不明 → base..HEAD、overview は作業ツリー
    const base = resolveBase(cwd, "HEAD");
    return { base, tip: "HEAD", commits: listCommits(cwd, base, "HEAD"), overview: ["diff"] };
  };

  const reload = (root: string, tail: string[], label: string) => {
    lastReloadSpec = tail.join(" ");
    execFile(hunkBin, ["session", "reload", "--repo", root, "--", ...tail], (err) => {
      if (err) ctx.notify(`commit-stepper: reload 失敗 — ${firstLine(err.message)}`, "warning");
      else ctx.notify(`commit-stepper: ${label}`);
    });
  };

  const firstLine = (s: string) => s.split("\n").map((l) => l.trim()).find(Boolean) ?? s;

  const ensureTarget = (cwd: string, root: string) => {
    const live = liveSpec(cwd, root);
    const stillOurs = target && live && live.spec === lastReloadSpec;
    if (!stillOurs) {
      target = detectTarget(cwd, root);
      pos = OVERVIEW;
    }
  };

  const step = (direction: "next" | "prev" | "overview") => (handlerCtx: Ctx) => {
    ctx = handlerCtx;
    const cwd = handlerCtx.cwd;
    const root = repoRoot(cwd);
    if (!root) {
      handlerCtx.notify("commit-stepper: git リポジトリではありません", "warning");
      return;
    }

    ensureTarget(cwd, root);
    const t = target!;

    if (direction === "overview") {
      pos = OVERVIEW;
      reload(root, t.overview, `overview (${t.overview.slice(1).join(" ") || "working tree"})`);
      return;
    }

    if (t.commits.length === 0) {
      handlerCtx.notify("commit-stepper: 対象コミットがありません", "warning");
      return;
    }

    if (direction === "next") {
      pos = pos === OVERVIEW ? 0 : Math.min(pos + 1, t.commits.length - 1);
    } else {
      if (pos <= 0) {
        pos = OVERVIEW;
        reload(root, t.overview, `overview (${t.overview.slice(1).join(" ") || "working tree"})`);
        return;
      }
      pos -= 1;
    }

    const c = t.commits[pos];
    reload(root, ["show", c.hash], `[${pos + 1}/${t.commits.length}] ${c.hash.slice(0, 9)} ${c.subject}`);
  };

  hunk.registerCommand({ id: "commit-stepper.next", title: "Commit stepper: next commit", key: keys.next }, step("next"));
  hunk.registerCommand({ id: "commit-stepper.prev", title: "Commit stepper: previous commit", key: keys.prev }, step("prev"));
  hunk.registerCommand(
    { id: "commit-stepper.overview", title: "Commit stepper: back to overview", key: keys.overview },
    step("overview"),
  );
}
