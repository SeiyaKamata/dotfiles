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
// [extension.commit-stepper] で base・hunkBin・キーを上書きできる。

type Notify = (message: string, type?: "info" | "warning" | "error") => void;
type Ctx = { cwd: string; notify: Notify };

type Commit = { hash: string; subject: string };

// live セッションの title から復元した「何を見ているか」。overview の diff と歩けるコミット列は
// ここから resolve() が一意に導く。
type SessionInput =
  | { kind: "range"; base: string; dots: string; tipRef: string }
  | { kind: "show"; ref: string }
  | { kind: "working" };

type Target = {
  base: string | null;
  tip: string;
  commits: Commit[];
  overview: string[]; // overview へ戻すときの `session reload --` argv tail
};

export default function (hunk: any) {
  const cfg = (hunk.config ?? {}) as {
    base?: string;
    hunkBin?: string;
    maxCommits?: number;
    keys?: { next?: string; prev?: string; overview?: string };
  };
  const keys = {
    next: cfg.keys?.next ?? "ctrl+n",
    prev: cfg.keys?.prev ?? "ctrl+p",
    overview: cfg.keys?.overview ?? "ctrl+g",
  };
  const maxCommits =
    Number.isInteger(cfg.maxCommits) && (cfg.maxCommits as number) > 0 ? (cfg.maxCommits as number) : 40;

  const hunkBin =
    cfg.hunkBin ?? (process.execPath && /hunk$/.test(process.execPath) ? process.execPath : "hunk");

  let notify: Notify = () => {};
  let target: Target | null = null;
  let pos: number | null = null; // null = overview、それ以外は target.commits の index
  let lastSpec = ""; // 直近に自分が張った reload の反映後 spec。live と一致する間はレビュー継続とみなす。

  const run = (bin: string, args: string[], cwd?: string): string | null => {
    try {
      return execFileSync(bin, args, { cwd, encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] }).trim();
    } catch {
      return null;
    }
  };
  const git = (cwd: string, args: string[]) => run("git", args, cwd);

  const repoRoots = new Map<string, string | null>();
  const repoRoot = (cwd: string): string | null => {
    if (!repoRoots.has(cwd)) repoRoots.set(cwd, git(cwd, ["rev-parse", "--show-toplevel"]));
    return repoRoots.get(cwd)!;
  };

  const resolveCommit = (cwd: string, ref: string): string | null =>
    git(cwd, ["rev-parse", "--verify", "--quiet", `${ref}^{commit}`]);

  // base 候補。設定 > upstream > origin/HEAD の順で、tip の祖先かつ tip 自身でない最初のもの。
  // 候補は前段が外れたときだけ引くので、cfg.base が効けば git は 1 回も走らない。
  const resolveBase = (cwd: string, tip: string, tipSha: string | null): string | null => {
    const probes: Array<() => string | null | undefined> = [
      () => cfg.base,
      () => git(cwd, ["rev-parse", "--abbrev-ref", "--symbolic-full-name", `${tip}@{upstream}`]),
      () => git(cwd, ["symbolic-ref", "--short", "refs/remotes/origin/HEAD"]),
    ];
    for (const probe of probes) {
      const ref = probe();
      if (!ref) continue;
      const sha = resolveCommit(cwd, ref);
      if (!sha || sha === tipSha) continue;
      if (git(cwd, ["merge-base", "--is-ancestor", ref, tip]) !== null) return ref;
    }
    return null;
  };

  const listCommits = (cwd: string, base: string | null, tip: string): Commit[] => {
    const args = ["log", "--reverse", "--no-merges", "--format=%H%x1f%s"];
    if (base) args.push(`${base}..${tip}`);
    else args.push(`-n${maxCommits}`, tip);
    const out = git(cwd, args);
    if (!out) return [];
    return out.split("\n").map((line) => {
      const [hash, subject] = line.split("\x1f");
      return { hash, subject };
    });
  };

  // hunk セッションの title から repo ラベルを剥がした spec と inputKind を返す。
  const liveSpec = (root: string): { spec: string; kind: string } | null => {
    const json = run(hunkBin, ["session", "get", "--repo", root, "--json"]);
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

  // reload argv を、その反映後に liveSpec().spec が返すはずの文字列へ落とす。
  // これが ensureTarget の突合キー。argv 形式と title 形式を突き合わせないための正規化。
  const expectedSpec = (argv: string[]): string => {
    if (argv[0] === "diff") return argv[1] ?? "working tree";
    if (argv[0] === "show") return `show ${argv[1]}`;
    return argv.join(" ");
  };

  const parseInput = (live: { spec: string; kind: string } | null): SessionInput => {
    const spec = live?.spec ?? "";
    const range = spec.match(/^(\S.*?)(\.\.\.?)(\S.*)$/);
    if (range) return { kind: "range", base: range[1], dots: range[2], tipRef: range[3] };
    if (live?.kind === "show" && spec.startsWith("show ")) return { kind: "show", ref: spec.slice(5).trim() };
    return { kind: "working" };
  };

  const resolveTarget = (cwd: string, input: SessionInput): Target => {
    if (input.kind === "range") {
      const tip = resolveCommit(cwd, input.tipRef) ?? "HEAD";
      return {
        base: input.base,
        tip,
        commits: listCommits(cwd, input.base, tip),
        overview: ["diff", `${input.base}${input.dots}${input.tipRef}`],
      };
    }
    const tip = input.kind === "show" ? resolveCommit(cwd, input.ref) ?? "HEAD" : "HEAD";
    const base = resolveBase(cwd, tip, resolveCommit(cwd, tip));
    const overview =
      input.kind === "show" ? (base ? ["diff", `${base}...${tip}`] : ["show", input.ref]) : ["diff"];
    return { base, tip, commits: listCommits(cwd, base, tip), overview };
  };

  const firstLine = (s: string) => s.split("\n").map((l) => l.trim()).find(Boolean) ?? s;

  const reload = (root: string, argv: string[], label: string) => {
    lastSpec = expectedSpec(argv);
    execFile(hunkBin, ["session", "reload", "--repo", root, "--", ...argv], (err) => {
      if (err) notify(`commit-stepper: reload 失敗 — ${firstLine(err.message)}`, "warning");
      else notify(`commit-stepper: ${label}`);
    });
  };

  const ensureTarget = (cwd: string, root: string) => {
    const live = liveSpec(root);
    if (!(target && live && live.spec === lastSpec)) {
      target = resolveTarget(cwd, parseInput(live));
      pos = null;
    }
  };

  const step = (direction: "next" | "prev" | "overview") => (ctx: Ctx) => {
    notify = ctx.notify;
    const cwd = ctx.cwd;
    const root = repoRoot(cwd);
    if (!root) {
      ctx.notify("commit-stepper: git リポジトリではありません", "warning");
      return;
    }

    ensureTarget(cwd, root);
    const t = target!;
    const goOverview = () => {
      pos = null;
      reload(root, t.overview, `overview (${t.overview.slice(1).join(" ") || "working tree"})`);
    };

    if (direction === "overview") {
      goOverview();
      return;
    }

    if (t.commits.length === 0) {
      ctx.notify("commit-stepper: 対象コミットがありません", "warning");
      return;
    }

    if (direction === "next") {
      pos = pos === null ? 0 : Math.min(pos + 1, t.commits.length - 1);
    } else if (pos === null || pos === 0) {
      goOverview();
      return;
    } else {
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
