#!/usr/bin/env node
import { execFileSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

export const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../../..");
export const repos = [".", "web", "server", "mobile", "desktop"];

const DAY = /^\d{4}-\d{2}-\d{2}$/;
const RELEASE = /^v\d+\.\d+\.\d+$/;
const FILE_LIMIT = 40;

function git(repo, args) {
  return execFileSync("git", ["-C", path.join(root, repo), ...args], {
    encoding: "utf8",
    maxBuffer: 64 * 1024 * 1024,
  });
}

function refsOf(repo) {
  return ["main", "origin/main"].filter((ref) => {
    try {
      git(repo, ["rev-parse", "--verify", "-q", ref]);
      return true;
    } catch {
      return false;
    }
  });
}

export function localDay(date = new Date()) {
  const pad = (value) => String(value).padStart(2, "0");
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
}

export function addDays(day, count) {
  const date = new Date(`${day}T12:00:00`);
  date.setDate(date.getDate() + count);
  return localDay(date);
}

export function daysBetween(from, to) {
  const days = [];
  for (let day = from; day <= to; day = addDays(day, 1)) days.push(day);
  return days;
}

export function firstDay() {
  return repos
    .flatMap((repo) => {
      const refs = refsOf(repo);
      if (refs.length === 0) return [];
      const first = git(repo, ["log", ...refs, "--reverse", "--format=%cd", "--date=short"])
        .split("\n")
        .find(Boolean);
      return first ? [first] : [];
    })
    .sort()[0];
}

export function commitsOn(repo, day) {
  const refs = refsOf(repo);
  if (refs.length === 0) return [];
  const output = git(repo, [
    "log",
    ...refs,
    "--no-merges",
    `--since=${day} 00:00:00`,
    `--until=${addDays(day, 1)} 00:00:00`,
    "--name-only",
    "--date=format:%H:%M",
    "--format=%x1e%h%x1f%cd%x1f%s%x1f%b%x1d",
  ]);

  return output
    .split("\x1e")
    .filter((record) => record.trim())
    .map((record) => {
      const [header, rest = ""] = record.split("\x1d");
      const [hash, time, subject, body] = header.split("\x1f");
      return {
        hash,
        time,
        subject: subject.trim(),
        body: body.trim(),
        files: rest.split("\n").map((file) => file.trim()).filter(Boolean),
      };
    })
    .sort((a, b) => a.time.localeCompare(b.time));
}

export function changesOn(day) {
  const releases = [];
  const changes = [];
  for (const repo of repos) {
    for (const commit of commitsOn(repo, day)) {
      if (repo === "." && RELEASE.test(commit.subject)) releases.push(commit.subject);
      else changes.push({ repo: repo === "." ? "root" : repo, ...commit });
    }
  }
  return { day, releases, changes };
}

function describe({ day, releases, changes }) {
  const lines = [`## ${day}`];
  if (releases.length > 0) lines.push(`Releases: ${releases.join(", ")}`);
  if (changes.length === 0) {
    lines.push("No commits.");
    return lines.join("\n");
  }
  for (const repo of ["web", "server", "mobile", "desktop", "root"]) {
    const commits = changes.filter((change) => change.repo === repo);
    if (commits.length === 0) continue;
    lines.push("", `### ${repo} (${commits.length} ${commits.length === 1 ? "commit" : "commits"})`);
    for (const commit of commits) {
      lines.push(`- ${commit.time} ${commit.hash} ${commit.subject}`);
      if (commit.body) {
        for (const line of commit.body.split("\n")) lines.push(`    ${line}`);
      }
      const shown = commit.files.slice(0, FILE_LIMIT);
      const more = commit.files.length - shown.length;
      if (shown.length > 0) {
        lines.push(`    files: ${shown.join(", ")}${more > 0 ? `, and ${more} more` : ""}`);
      }
    }
  }
  return lines.join("\n");
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const [from, to = from] = process.argv.slice(2);
  if (!DAY.test(from ?? "") || !DAY.test(to) || from > to) {
    console.error("Usage: node collect.mjs <from YYYY-MM-DD> [to YYYY-MM-DD]");
    process.exit(1);
  }
  console.log(daysBetween(from, to).map((day) => describe(changesOn(day))).join("\n\n"));
}
