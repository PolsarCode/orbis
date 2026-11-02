---
name: changelog
description: Write the user-facing Orbis changelog from the git history of the whole monorepo (root, web, server, mobile, desktop). Use when asked to write or update the changelog for a range of past days. `pnpm run release` runs it automatically through scripts/development/changelog.mjs.
---

# Changelog

The changelog tells Orbis users what changed, in their words. It lives in `web/changelog/` and is shown on the site's `/changelog` page and in the "new version" note on the home feed.

## Files

- One file per day that has user-facing changes, named `web/changelog/YYYY-MM-DD.json`:

  ```json
  {
    "date": "2026-10-26",
    "versions": ["v0.54.0", "v0.56.1"],
    "entries": [
      {
        "type": "new",
        "title": "Connect your Steam account",
        "description": "Your Steam games and hours show up in your library, and you can import everything you've played in one go."
      }
    ]
  }
  ```

  - `type` is `new`, `improved`, or `fixed`.
  - `versions` lists the releases from that day, from the "Releases" line of the collected changes. Leave it out when there were none.
  - `platforms` is optional: `["web"]` or `["mobile"]`, only when a change is limited to one app.
  - `title` is at most 80 characters and `description` at most 300.
- `web/changelog/checked.json` holds `{ "checkedThrough": "YYYY-MM-DD" }`: the last day that has been looked at, whether or not it had anything to log.

## Workflow

1. Get the changes for the days you were given: `node .agents/skills/changelog/collect.mjs <from> <to>`. It lists each day's commits from all five repositories, with their messages and changed files.
2. For each day, pick out what users can see:
   - Commit emoji are the first hint: ✨ new, 🐛 fixed, 🚸 💄 📱 ⚡️ improved. 📝 ✅ ♻️ 🔧 🔨 👷 ⬆️ 🗃️ 🎨 🔥 🚚 are usually invisible to users.
   - Changed files confirm it. Web pages, components, and stores, and mobile screens are user-facing. Server changes count only when they change what people see or can do. Tests, docs, agent files (`AGENTS.md`, `CLAUDE.md`, skills), migrations, config, and dependency updates don't.
   - When a message is unclear, read the change itself with `git -C <repo> show <hash>` before deciding.
   - Leave out admin-only tools (the reports board, admin settings) and anything only developers would notice.
3. Merge the commits behind one change into a single entry, even when they span web, server, mobile, and desktop, or several commits on the same day.
4. Write each entry for users:
   - The title says what changed in a few words, in sentence case, with no full stop.
   - The description is one or two plain sentences about what people can now do or what works better. Speak to them as "you".
   - Never mention file names, components, endpoints, libraries, commit hashes, or internal names.
   - Order entries by type (new, then improved, then fixed), most noticeable first.
5. Write one file per day that has at least one entry. Skip days with nothing user-facing: they get no file. If a day's file already exists, keep its entries and add to them.
6. Set `checkedThrough` in `web/changelog/checked.json` to the last day you were given.

## Rules

- Never write a file for today or a later day. Today's changes are logged on a later day.
- Only create or edit files in `web/changelog/`, and don't commit. The release script validates and commits the result.
- Every file must be valid JSON in the format above.
