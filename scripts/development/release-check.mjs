#!/usr/bin/env node
import { execFileSync, spawnSync } from "node:child_process";
import { mkdirSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const repos = ["server", "web", "mobile", "desktop"];
const MAX_ROUNDS = 3;
const AGENT_TIMEOUT_MS = 20 * 60 * 1000;
const CHECK_TIMEOUT_MS = 30 * 60 * 1000;
const MESSAGE_LIMIT = 72;
const START = "<<<COMMIT_MESSAGE>>>";
const END = "<<<END_COMMIT_MESSAGE>>>";
const logsDir = path.join(tmpdir(), "orbis-release-checks", String(Date.now()));

const checks = {
  server: [
    ["tests", "npx", ["jest"]],
    ["types", "npx", ["tsc", "--noEmit", "-p", "tsconfig.json"]],
    ["lint", "npx", ["eslint", "{src,apps,libs,test}/**/*.ts"]],
  ],
  web: [
    ["types", "npx", ["tsc", "--noEmit"]],
    ["lint", "npx", ["eslint"]],
  ],
  mobile: [
    ["tests", "npx", ["jest"]],
    ["types", "npx", ["tsc", "--noEmit"]],
    ["lint", "npx", ["expo", "lint"]],
  ],
  desktop: [],
};

const args = process.argv.slice(2);
const dryRun = args.includes("--dry-run");
const reportFile = args.includes("--report") ? args[args.indexOf("--report") + 1] : null;
const madeCommits = [];
const fixRounds = [];

function log(message) {
  console.log(message);
}

function stop(message) {
  console.error(`❌ ${message}`);
  process.exit(1);
}

function git(repo, gitArgs) {
  return execFileSync("git", ["-C", path.join(root, repo), ...gitArgs], { encoding: "utf8" });
}

function uncommitted(repo) {
  return git(repo, ["status", "--porcelain", "--untracked-files=all"]).trim();
}

function failure(run) {
  if (run.error) {
    if (run.error.code === "ENOENT") return "isn't installed";
    if (run.error.code === "ETIMEDOUT") return "took too long";
    return run.error.message;
  }
  return run.status === 0 ? null : `stopped with exit code ${run.status}`;
}

function commitPrompt() {
  return `Use the git-commit skill to write a commit message for the currently uncommitted changes in this repository (staged and unstaged). Do not run git add or git commit. The commit message must be a single line only, with no body, bullet points, or explanation: just the Gitmoji and an imperative summary, at most ${MESSAGE_LIMIT} characters. Output the commit message wrapped exactly between the markers ${START} and ${END}, each on their own line, with nothing else before, after, or between those markers besides the message itself.`;
}

function messageFrom(output) {
  const start = output.lastIndexOf(START);
  const end = output.indexOf(END, start);
  if (start === -1 || end === -1) return null;
  const line = output
    .slice(start + START.length, end)
    .split("\n")
    .map((text) => text.trim())
    .find(Boolean);
  return line ? line.slice(0, MESSAGE_LIMIT) : null;
}

function writeMessage(repo) {
  const cwd = path.join(root, repo);
  const prompt = commitPrompt();
  const agents = [
    {
      name: "Claude",
      bin: process.env.CLAUDE_BIN || "claude",
      args: [
        "-p",
        prompt,
        "--permission-mode",
        "dontAsk",
        "--allowedTools",
        "Bash(git status:*)",
        "Bash(git diff:*)",
        "Bash(git log:*)",
      ],
    },
    {
      name: "Codex",
      bin: process.env.CODEX_BIN || "codex",
      args: ["exec", "--sandbox", "read-only", "--cd", cwd, "--ephemeral", prompt],
    },
  ];

  for (const agent of agents) {
    const run = spawnSync(agent.bin, agent.args, {
      cwd,
      encoding: "utf8",
      stdio: ["ignore", "pipe", "pipe"],
      timeout: AGENT_TIMEOUT_MS,
    });
    const failed = failure(run);
    const message = failed ? null : messageFrom(run.stdout ?? "");
    if (message) return message;
    log(`⚠️ ${agent.name} couldn’t write a commit message for ${repo}${failed ? ` (${failed})` : ""}.`);
  }
  return null;
}

function commitAll() {
  let committed = false;
  for (const repo of repos) {
    if (!uncommitted(repo)) continue;
    if (dryRun) {
      log(`📦 ${repo} has uncommitted changes (dry run, not committing).`);
      continue;
    }
    log(`📦 Committing ${repo}...`);
    const message = writeMessage(repo);
    if (!message) stop(`Couldn’t write a commit message for ${repo}, so the release stopped.`);
    git(repo, ["add", "-A"]);
    git(repo, ["commit", "-q", "-m", message]);
    madeCommits.push({ repo, commit: git(repo, ["rev-parse", "HEAD"]).trim(), message });
    log(`   ${message}`);
    committed = true;
  }
  return committed;
}

function testSummary(output) {
  const line = output.match(/^Tests:\s+(.+)$/m);
  return line ? line[1].trim() : null;
}

function runChecks(round) {
  const roundDir = path.join(logsDir, String(round));
  mkdirSync(roundDir, { recursive: true });
  const failed = [];
  const results = Object.fromEntries(repos.map((repo) => [repo, []]));

  for (const repo of repos) {
    if (checks[repo].length === 0) {
      log(`⏭️ ${repo}: no tests`);
      continue;
    }
    for (const [name, bin, args] of checks[repo]) {
      const run = spawnSync(bin, args, {
        cwd: path.join(root, repo),
        encoding: "utf8",
        stdio: ["ignore", "pipe", "pipe"],
        timeout: CHECK_TIMEOUT_MS,
        maxBuffer: 64 * 1024 * 1024,
      });
      const problem = failure(run);
      const summary = testSummary(`${run.stdout ?? ""}\n${run.stderr ?? ""}`);
      const command = [bin, ...args].join(" ");
      results[repo].push({ name, command, passed: !problem, ...(summary && { summary }) });
      if (!problem) {
        log(`✅ ${repo} ${name}${summary ? ` (${summary})` : ""}`);
        continue;
      }
      const file = path.join(roundDir, `${repo}-${name}.log`);
      writeFileSync(
        file,
        `$ ${[bin, ...args].join(" ")}\n(in ${repo}, ${problem})\n\n${run.stdout ?? ""}\n${run.stderr ?? ""}`,
      );
      log(`❌ ${repo} ${name} (${file})`);
      failed.push({ repo, name, command, file });
    }
  }
  return { failed, results };
}

function saveReport(results) {
  if (!reportFile) return;
  const apps = Object.fromEntries(
    repos.map((repo) => [repo, { commit: git(repo, ["rev-parse", "HEAD"]).trim(), checks: results[repo] }]),
  );
  writeFileSync(
    reportFile,
    JSON.stringify({ checkedAt: new Date().toISOString(), apps, commits: madeCommits, fixRounds }, null, 2) + "\n",
  );
}

function snapshot() {
  const state = new Map();
  const statusArgs = ["status", "--porcelain", "--untracked-files=all", "--ignore-submodules=all"];
  for (const line of git(".", statusArgs).split("\n").filter(Boolean)) {
    state.set(line.slice(3).split(" -> ").pop(), line.slice(0, 2));
  }
  for (const repo of repos) {
    for (const line of git(repo, ["status", "--porcelain", "--untracked-files=all"]).split("\n").filter(Boolean)) {
      state.set(path.join(repo, line.slice(3).split(" -> ").pop()), line.slice(0, 2));
    }
  }
  return state;
}

function changedSince(before) {
  const after = snapshot();
  const paths = new Set([...before.keys(), ...after.keys()]);
  return [...paths].filter((file) => before.get(file) !== after.get(file));
}

function notAllowed(file) {
  const inApp = repos.some((repo) => file.startsWith(repo + path.sep));
  return !inApp || /(^|\/)\.env[^/]*$/.test(file);
}

function fixPrompt(failed) {
  return [
    "Some checks failed before an Orbis release. Fix them.",
    "Failing checks (each log has the full output):",
    ...failed.map(({ repo, name, command, file }) => `- ${repo} ${name}: \`${command}\` in ${repo}/, log: ${file}`),
    "",
    "Rules:",
    "- Fix the underlying code. Only change a test when the test itself is wrong.",
    "- Follow the AGENTS.md of the app you're changing.",
    "- Only edit files inside server/, web/, mobile/ or desktop/, and never .env files.",
    "- Don't commit, push, deploy, run the database seed, or run prisma migrate reset.",
    "- Rerun each failing check to confirm it passes before you finish.",
  ].join("\n");
}

function fix(failed) {
  const prompt = fixPrompt(failed);
  const agents = [
    {
      name: "Claude",
      bin: process.env.CLAUDE_BIN || "claude",
      args: [
        "-p",
        prompt,
        "--permission-mode",
        "dontAsk",
        "--allowedTools",
        "Read",
        "Glob",
        "Grep",
        "Edit",
        "Write",
        "Bash(npx jest:*)",
        "Bash(npx tsc:*)",
        "Bash(npx eslint:*)",
        "Bash(npx expo lint:*)",
        "Bash(git status:*)",
        "Bash(git diff:*)",
      ],
    },
    {
      name: "Codex",
      bin: process.env.CODEX_BIN || "codex",
      args: ["exec", "--sandbox", "workspace-write", "--cd", root, "--ephemeral", prompt],
    },
  ];

  for (const agent of agents) {
    const before = snapshot();
    log(`🤖 Asking ${agent.name} to fix the failing checks...`);
    const run = spawnSync(agent.bin, agent.args, {
      cwd: root,
      stdio: ["ignore", "inherit", "inherit"],
      timeout: AGENT_TIMEOUT_MS,
    });
    const outside = changedSince(before).filter(notAllowed);
    if (outside.length > 0) {
      stop(
        `${agent.name} changed files it shouldn’t have, so the release stopped. Check these and undo them:\n${outside
          .map((file) => `   - ${file}`)
          .join("\n")}`,
      );
    }
    const failedRun = failure(run);
    if (!failedRun) return agent.name;
    log(`⚠️ ${agent.name} ${failedRun}.`);
  }
  stop("Neither Claude nor Codex could fix the failing checks, so the release stopped.");
}

log("🧪 Checking every app before the release...");

let fixes = 0;
let leftovers = false;

for (let round = 0; ; round++) {
  commitAll();
  const { failed, results } = runChecks(round);

  if (failed.length === 0) {
    if (dryRun) {
      saveReport(results);
      log("✅ Every check passes (dry run, nothing was committed).");
      process.exit(0);
    }
    const left = repos.filter(uncommitted);
    if (left.length === 0) {
      saveReport(results);
      log("✅ Everything is committed and every check passes.");
      process.exit(0);
    }
    if (leftovers) {
      stop(`The checks keep changing files in ${left.join(", ")}. Add them to .gitignore or commit them, then release again.`);
    }
    leftovers = true;
    continue;
  }

  if (dryRun) stop("Some checks failed (dry run, nothing was fixed or committed).");
  if (fixes >= MAX_ROUNDS) {
    stop(
      `Checks still fail after ${MAX_ROUNDS} fix rounds, so the release stopped:\n${failed
        .map(({ repo, name, file }) => `   - ${repo} ${name}: ${file}`)
        .join("\n")}`,
    );
  }

  fixes += 1;
  log(`🔧 Fix round ${fixes} of ${MAX_ROUNDS}`);
  const agent = fix(failed);
  fixRounds.push({
    round: fixes,
    agent,
    failed: failed.map(({ repo, name }) => `${repo} ${name}`),
  });
}
