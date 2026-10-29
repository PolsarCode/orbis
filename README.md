# Orbis
The monorepo of Orbis, managed with [Turborepo](https://turborepo.dev) and pnpm workspaces.

## Repositories
| Path | Repository | Description |
| --- | --- | --- |
| [server](server) | [PolsarCode/orbis.server](https://github.com/PolsarCode/orbis.server) | NestJS + Prisma (PostgreSQL) API on port `4000` |
| [web](web) | [PolsarCode/orbis.web](https://github.com/PolsarCode/orbis.web) | Next.js frontend on port `3000` |
| [mobile](mobile) | [PolsarCode/orbis.mobile](https://github.com/PolsarCode/orbis.mobile) | Expo (React Native) app |

`server`, `web`, and `mobile` are Git submodules.

## Getting Started
For step-by-step instructions for macOS, Ubuntu, and Windows, including prerequisites, see [SETUP.md](SETUP.md).

1. **Clone over SSH**:

```bash
git clone git@github.com:PolsarCode/orbis.git
cd orbis
```

2. **Run the setup**:

```bash
pnpm run setup
```

This pulls the latest changes, clones `server`, `web`, and `mobile` over SSH (the URLs in `.gitmodules`), checks them out on the same branch as this repository (or `main` if that branch doesn't exist in the submodule), installs dependencies, enables the git hooks, creates `server/.env`, `web/.env.local`, and `mobile/.env.local` from `example.env`, creates the database container, and generates the Prisma client.

3. **Fill in the environment variables**: replace the `XXXX` values in `server/.env` (see [server/DATABASE.md](server/DATABASE.md)) and set `NEXT_PUBLIC_API_URL=http://localhost:4000` in `web/.env.local`.

## Scripts
| Command | Description |
| --- | --- |
| `pnpm run setup` | Pull the latest changes, update submodules, and install dependencies (safe to rerun) |
| `pnpm run release` | Bump the version, commit the new `server`/`web`/`mobile` commits, tag, push, and deploy the apps that changed |
| `pnpm run pull` | Pull this repository and the latest `main` of `server`/`web`/`mobile`, install dependencies, reset the local database, reapply migrations, and seed |
| `pnpm run develop` | Ask whether to start web, mobile, both, or only the server, then run the matching script below (or pass the choice: `pnpm run develop web`) |
| `pnpm run develop:web` | Start the database, server, and web in development mode |
| `pnpm run develop:mobile` | Start the database, server, and the Expo dev server for the mobile app |
| `pnpm run develop:all` | Start the database, server, web, and mobile together (run this instead of the two above to work on both) |
| `pnpm run develop:server` | Start the database and server only |
| `pnpm run build` | Build the server and web (the mobile app is published with EAS Update instead) |
| `pnpm run review:start` | Check off what you're testing (web, mobile, server), then enter those PR numbers to check them out for review (or pass them: `pnpm run review:start web server`) |
| `pnpm run review:end` | Switch `web`, `server`, and `mobile` back to `main` |

## Mobile
```bash
pnpm run develop:mobile
```

This starts the database, the server, and Expo. Scan the QR code with [Expo Go](https://expo.dev/go) on a phone on the same Wi-Fi as your computer, or press `i` for the iOS simulator or `a` for the Android emulator. The app finds the server on your computer automatically; set `EXPO_PUBLIC_API_URL` in `mobile/.env.local` to use another one.

`develop:web` and `develop:mobile` each start the server, so run only one of them at a time. Use `pnpm run develop:all` to run everything together.

`pnpm run release` also publishes the mobile app with EAS Update. Before the first release, run once in `mobile`: `pnpm exec eas login`, `pnpm exec eas init`, and `pnpm exec eas update:configure`. Until then the mobile deploy is skipped with a warning.

If the app can't reach the server:
- **macOS:** allow incoming connections for `node` when the firewall asks, or in **System Settings → Network → Firewall**.
- **Windows (WSL):** your phone can't reach WSL directly. Run `pnpm --filter orbis-mobile exec expo start --tunnel` with the server running, and set `EXPO_PUBLIC_API_URL` in `mobile/.env.local` to an address your phone can reach (for example your Windows machine's IP with port `4000` forwarded to WSL).
- **Another network or device:** set `EXPO_PUBLIC_API_URL` in `mobile/.env.local`, then restart `develop:mobile`.

`mobile/expo-env.d.ts` is generated the first time Expo starts, so run `pnpm run develop:mobile` once before type-checking the mobile app on a fresh clone.

## Reviewing Pull Requests
```bash
pnpm run review:start
```

This first installs the [GitHub CLI](https://cli.github.com) (with Homebrew, apt, or winget) if it's missing and runs `gh auth login` if you're not logged in. It then shows a checklist of `Web`, `Mobile`, and `Server` (with `Server` already checked): move with ↑/↓ or `j`/`k`, check with space, and press enter. You can also skip the checklist by passing your picks, like `pnpm run review:start web server` (or `all`). It asks only for the PR numbers of what you checked (leave any empty to skip it), shows each PR's title, checks each PR out on a local `pr/<number>` branch with `gh pr checkout`, installs dependencies, regenerates the Prisma client, and tells you which `develop` script starts what you picked. Rerunning it with the same number updates the branch to the PR's latest commit. It stops without changing anything if a PR doesn't exist or a submodule you entered a number for has uncommitted changes.

When you're done:

```bash
pnpm run review:end
```

This switches `web`, `server`, and `mobile` back to `main`, installs dependencies, and regenerates the Prisma client. It stops if either submodule has uncommitted changes.

Neither script applies or reverts database migrations. If a `server` PR adds migrations, apply them with `pnpm --filter orbis-server exec prisma migrate deploy`, and run `pnpm run pull` afterwards to reset the database back to `main`.

## Releasing
Commit your changes inside `server`, `web`, and/or `mobile` first, then run from this repository (changes in this repository don't need to be committed):

```bash
pnpm run release
```

This:
1. Bumps `version` in `package.json` based on the Gitmoji of the new `server`/`web`/`mobile` commits: `💥` → major, `✨` → minor, anything else (or only changes in this repository) → patch.
2. Pushes whichever of `server`, `web`, and `mobile` have new commits.
3. Commits everything here, including the new submodule commits and any uncommitted changes in this repository, with the version as the title (for example `v0.2.0`). The description lists the new `server`/`web`/`mobile` commits and the changed files in this repository.
4. Tags that commit (for example `v0.2.0`) and pushes the commit and tag.
5. Deploys only the apps with new commits in this release: `server` (Fly), `web` (Vercel), and `mobile` (EAS Update; skipped with a warning until it's set up, see [Mobile](#mobile)). The others are skipped.

It stops without changing anything if a submodule has uncommitted changes. If nothing changed in `server`, `web`, or `mobile`, it still bumps the version, commits, tags, and pushes, and deploys nothing.

`pnpm install` enables the hooks in `.githooks`: `git push` here also pushes the submodule commits to a branch with the same name.

## Pulling Changes
After the initial setup, run:

```bash
pnpm run pull
```

This pulls this repository with a fast-forward merge, updates `server`, `web`, and `mobile` to their latest `main`, installs dependencies, starts the local database and storage, regenerates the Prisma client, resets the local database, reapplies all committed migrations, and runs the seed. It stops if any step fails.

**This replaces all local database data with the seeded test data.** It only resets the standard local Orbis database (`localhost:5434/orbis_server_db`, also allowing the loopback IP addresses). Uploaded image files are not deleted. Run `pnpm run develop:web` or `pnpm run develop:mobile` afterwards to start the app.

At the end, including after a failed update, it compares `server/.env` and `web/.env.local` against their `example.env` files and warns about missing keys, empty values, or values still set to `XXXX`. It does not print or overwrite your values.

To update without resetting the database, use `pnpm run setup` and apply migrations with:

```bash
pnpm --filter orbis-server exec prisma migrate deploy
```
