<!-- BEGIN:turborepo-agent-rules -->

# This is NOT the Turborepo you know

Turborepo configuration, task behavior, and CLI commands can vary between installed versions and may differ from your training data. Resolve the `turbo` package from this file's directory or relevant workspace; in monorepos, it may not be visible from the repository root. For example, run `node -p "require.resolve('turbo/package.json')"` from a workspace that depends on `turbo`.

Read `docs/README.md` inside that installed package first, then read the relevant pages from its `docs/` directory before changing Turborepo configuration or commands. Heed deprecation notices. These bundled docs match the installed package version and are available without network access.

This block is written and re-added by `turbo` before repository-scoped commands when an AI agent is detected. In the Turborepo source repository, its template is defined in `crates/turborepo-cli/src/cli/agent_guidance.rs`. Removing the managed block while updates are enabled means a later qualifying invocation will add it again. Set `"agentGuidance": false` in the root `turbo.json` or `turbo.jsonc` to opt out; this does not remove an existing block. Keep the block committed with your work to avoid an uncommitted change on the next agent invocation.
<!-- END:turborepo-agent-rules -->

# Agent Instructions

## Skills

`server`, `web`, and `mobile` each have their own `AGENTS.md` and skills in `<app>/.agents/skills/`. Follow the `AGENTS.md` of the app you're working in.

The `changelog` skill (`.agents/skills/changelog/SKILL.md`) belongs to this folder: it writes the user-facing changelog in `web/changelog/` from the history of all four repositories. `pnpm run release` runs it through `scripts/development/changelog.mjs`, so use it directly only when asked to write the changelog. It's linked as `.claude/skills/changelog` for Claude Code.

Every app skill is also linked into `.agents/skills/` here, so agents started from this folder can find them. When you add or rename a skill in an app, add or update its link here too, for example `ln -s ../../web/.agents/skills/<name> .agents/skills/<name>`. Keep skill names unique across the apps.

## Testing

When building a feature or fixing a bug, run only the tests related to what changed: `npx jest --findRelatedTests <changed files>`, or the spec files of the modules you touched. Add the type check (`npx tsc --noEmit`) and lint on the changed files. Don't run whole test suites.

`pnpm run release` runs every test, type check and lint for all the apps before it releases (`scripts/development/release-check.mjs`). It first commits any uncommitted work in `server`, `web`, `mobile` and `desktop` with an AI-written message. If a check fails, it has Claude (Codex as a fallback) fix it, commits the fix and checks again, for up to 3 rounds before it stops the release.

## Subagents

`.claude/agents/` defines subagents for Claude Code, one per workflow step, so a feature can be explored, tested and checked in parallel without filling the main conversation:

- `explorer` maps one area (`server`, `web`, `mobile` or `desktop`) before planning. Read-only. Use it only when you need the map to settle the plan; otherwise let whoever builds a part explore it, so the same files aren't read twice.
- `tester` adds missing tests and runs the tests related to the change, plus type checks and lint for each changed app, then reports the results. Whole suites run at release time.
- `reviewer` reviews the change for bugs, regressions, security problems and Orbis rules. Read-only.
- `task-checker` goes through the GitHub task card item by item and reports whether each one is built and tested. Read-only.

`explorer`, `tester` and `task-checker` run on Sonnet to keep costs down; `reviewer` uses the main model, since missed problems cost more there.

Keep them in step with the apps: when a test command, rule or skill they mention changes, update the agent too.
