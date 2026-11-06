#!/usr/bin/env node
import { execFileSync } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const repos = ["server", "web", "mobile", "desktop"];
const [tag, reportFile, ...deployArgs] = process.argv.slice(2);

function stop(message) {
  console.error(`❌ ${message}`);
  process.exit(1);
}

function readJson(file) {
  try {
    return JSON.parse(readFileSync(file, "utf8"));
  } catch {
    return null;
  }
}

if (!tag || !reportFile) stop("Usage: release-history.mjs <tag> <check report> [app=deploy-result ...]");

const report = readJson(reportFile);
if (!report) stop(`Couldn’t read the check report at ${reportFile}.`);

const releasedFile = path.join(root, "released.json");
const released = existsSync(releasedFile) ? (readJson(releasedFile) ?? {}) : {};
const deploys = Object.fromEntries(deployArgs.map((arg) => arg.split("=")));

const apps = Object.fromEntries(
  repos.map((repo) => [
    repo,
    {
      previous: released[repo] ?? null,
      commit: execFileSync("git", ["-C", path.join(root, repo), "rev-parse", "HEAD"], { encoding: "utf8" }).trim(),
      checkedCommit: report.apps?.[repo]?.commit ?? null,
      checks: report.apps?.[repo]?.checks ?? [],
      deploy: deploys[repo] ?? "nothing-new",
    },
  ]),
);

const entry = {
  tag,
  releasedAt: new Date().toISOString(),
  checkedAt: report.checkedAt ?? null,
  apps,
  commits: report.commits ?? [],
  fixRounds: report.fixRounds ?? [],
};

const dir = path.join(root, "releases");
mkdirSync(dir, { recursive: true });
writeFileSync(path.join(dir, `${tag}.json`), JSON.stringify(entry, null, 2) + "\n");
console.log(`🗂️ Saved what was checked and deployed in releases/${tag}.json`);
