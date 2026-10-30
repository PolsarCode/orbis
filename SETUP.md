# Local Setup

How to run Orbis on your own machine. Pick your operating system, install the prerequisites, then follow [Set Up the Project](#set-up-the-project).

When it's running:

| Service | URL |
| --- | --- |
| Web | http://localhost:3000 |
| API | http://localhost:4000 |
| PostgreSQL (Docker) | `localhost:5434` |
| Image storage (Docker) | http://localhost:9100 (console at http://localhost:9101/rustfs/console/) |
| Email inbox (Docker) | http://localhost:8025 |

## Prerequisites

| Tool | Version | Why |
| --- | --- | --- |
| Git | any recent | Cloning the repositories |
| Node.js | 22 LTS | Running the server, web, and mobile dev server |
| pnpm | 12.4.2 | Installing dependencies and running scripts |
| Docker | any recent | Running PostgreSQL, image storage, and the email inbox |
| SSH key on GitHub | | `server`, `web`, and `mobile` are cloned over SSH |
| Expo Go (phone), or Xcode / Android Studio | latest | Running the mobile app (optional; see [Mobile](README.md#mobile)) |

You also need access to the `PolsarCode/orbis`, `PolsarCode/orbis.server`, `PolsarCode/orbis.web`, and `PolsarCode/orbis.mobile` repositories on GitHub.

### macOS

1. Install [Homebrew](https://brew.sh) if you don't have it.
2. Install Git and Node.js 22:

   ```bash
   brew install git node@22
   echo "export PATH=\"$(brew --prefix node@22)/bin:\$PATH\"" >> ~/.zshrc
   source ~/.zshrc
   node -v
   ```

3. Install pnpm:

   ```bash
   npm install -g pnpm@12.4.2
   ```

4. Install [Docker Desktop for Mac](https://docs.docker.com/desktop/setup/install/mac-install/) and open it once so the Docker engine is running.

### Ubuntu

1. Install Git and build tools:

   ```bash
   sudo apt update
   sudo apt install -y git curl build-essential
   ```

2. Install Node.js 22 with [nvm](https://github.com/nvm-sh/nvm):

   ```bash
   curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
   source ~/.bashrc
   nvm install 22
   ```

3. Install pnpm:

   ```bash
   npm install -g pnpm@12.4.2
   ```

4. Install Docker Engine by following [the official Ubuntu guide](https://docs.docker.com/engine/install/ubuntu/), then let your user run Docker without `sudo`:

   ```bash
   sudo usermod -aG docker $USER
   newgrp docker
   docker run --rm hello-world
   ```

### Windows

The project's scripts (the ones in `scripts/development`, the database script, and the git hooks) are Bash scripts, so run Orbis inside **WSL 2** with Ubuntu rather than directly in PowerShell or Command Prompt.

1. In PowerShell **as Administrator**, install WSL with Ubuntu, then restart your computer:

   ```powershell
   wsl --install -d Ubuntu
   ```

2. Open **Ubuntu** from the Start menu and create your Linux username and password.
3. Install [Docker Desktop for Windows](https://docs.docker.com/desktop/setup/install/windows-install/). In **Settings → Resources → WSL Integration**, turn on integration for **Ubuntu**.
4. In the Ubuntu terminal, keep Linux line endings so the Bash scripts work:

   ```bash
   git config --global core.autocrlf input
   ```

5. Follow the [Ubuntu](#ubuntu) steps 1–3 inside the Ubuntu terminal. Skip Ubuntu step 4: Docker Desktop provides Docker.

Run every command from here on in the Ubuntu terminal, and keep the project inside your Linux home folder (for example `~/code/orbis`), not under `/mnt/c/...`. Files on the Windows drive are much slower and can break file watching.

## Connect to GitHub over SSH

Skip this if `ssh -T git@github.com` already greets you by your username.

1. Create a key (press Enter to accept the defaults):

   ```bash
   ssh-keygen -t ed25519 -C "you@example.com"
   ```

2. Copy the public key:

   ```bash
   cat ~/.ssh/id_ed25519.pub
   ```

3. Add it on GitHub under **Settings → SSH and GPG keys → New SSH key**.
4. Check the connection:

   ```bash
   ssh -T git@github.com
   ```

## Set Up the Project

1. Clone the repository:

   ```bash
   git clone git@github.com:PolsarCode/orbis.git
   cd orbis
   ```

2. Run the setup:

   ```bash
   pnpm run setup
   ```

   This clones `server`, `web`, and `mobile`, installs dependencies, enables the git hooks, creates `server/.env`, `web/.env.local`, and `mobile/.env.local`, creates the PostgreSQL, storage, and email inbox containers, and generates the Prisma client. It warns about the `XXXX` values you fill in next.

3. Fill in `server/.env`:

   ```env
   JWT_SECRET=<a long random string>
   DATABASE_URL=postgresql://postgres:YourStrongPass123@localhost:5434/orbis_server_db
   ```

   The storage values (`AWS_*`, `BUCKET_NAME`, `STORAGE_PUBLIC_URL`) already match the local storage container, and `MAILPIT_URL` already matches the local email inbox, so leave them as they are.

   Generate a `JWT_SECRET` with:

   ```bash
   openssl rand -hex 32
   ```

4. Fill in `web/.env.local`:

   ```env
   NEXT_PUBLIC_API_URL=http://localhost:4000
   ```

5. Create the database tables:

   ```bash
   pnpm --filter orbis-server exec prisma migrate deploy
   ```

6. Add the test data (optional, recommended):

   ```bash
   pnpm --filter orbis-server run prisma:seed
   ```

   | Email | Password |
   | --- | --- |
   | `bos@eriko.ph` | `boseriko` |
   | `twis@wua.ph` | `twiswua` |

   It also creates two communities, **BosEriko** and **TwisWua**, owned by `bos@eriko.ph`, with both accounts as members.

   Seeding **deletes all users and communities** in your local database before creating this data, so only run it when you want a clean slate.

7. Start everything:

   ```bash
   pnpm run develop:web
   ```

   This starts the database, the image storage, the email inbox, the API, and the web app. Open http://localhost:3000 and log in with a test account, or create your own.

## Database

PostgreSQL runs in a Docker container that `pnpm run setup` creates for you. These credentials are for local development only.

| Setting | Value |
| --- | --- |
| Container | `orbis_server_db` |
| Image | `postgres:16` |
| Host and port | `localhost:5434` (not the default 5432, to avoid clashing with a PostgreSQL already on your machine) |
| User | `postgres` |
| Password | `YourStrongPass123` |
| Database | `orbis_server_db` |

### Container

Run these from the `orbis` folder:

| Task | Command |
| --- | --- |
| Create the container (first time only) | `pnpm --filter orbis-server run db:setup` |
| Start | `pnpm --filter orbis-server run db:start` |
| Stop | `pnpm --filter orbis-server run db:stop` |
| Restart | `pnpm --filter orbis-server run db:restart` |
| Check if it's running | `pnpm --filter orbis-server run db:status` |
| Follow its logs | `pnpm --filter orbis-server run db:logs` |
| Delete the container and its data | `pnpm --filter orbis-server run db:remove` |

`pnpm run develop:web` and `pnpm run develop:mobile` restart the database for you, so you rarely need these day to day. The database can take a few seconds to accept connections after it starts.

### Migrations and Data

| Task | Command |
| --- | --- |
| Apply migrations (after cloning or pulling) | `pnpm --filter orbis-server exec prisma migrate deploy` |
| Create a migration after editing the schema in `server/prisma/schema/` | `pnpm --filter orbis-server run prisma:migrate <name>` |
| Regenerate the Prisma client | `pnpm --filter orbis-server run prisma:generate` |
| Reset to the test accounts and communities | `pnpm --filter orbis-server run prisma:seed` |
| Wipe the database, reapply every migration, and reseed (when a migration can't apply to your existing data) | `pnpm --filter orbis-server run prisma:reset` |
| Browse and edit data in the browser | `pnpm --filter orbis-server run prisma:studio` |

`prisma:migrate` creates the migration file, applies it to your database, and regenerates the client. Commit the new folder under `server/prisma/migrations` with your change.

### Start Over With an Empty Database

```bash
pnpm --filter orbis-server run db:remove
pnpm --filter orbis-server run db:setup
pnpm --filter orbis-server exec prisma migrate deploy
pnpm --filter orbis-server run prisma:seed
```

## Image Storage

Uploaded images go to S3-compatible storage. Locally that's [RustFS](https://github.com/rustfs/rustfs) in a Docker container that `pnpm run setup` creates for you, with a public bucket named `orbis`. In production it's Cloudflare R2 (see [Production Image Storage](#production-image-storage)). The server talks to both the same way; only `server/.env` changes. These credentials are for local development only.

| Setting | Value |
| --- | --- |
| Container | `orbis_server_storage` |
| Image | `rustfs/rustfs:1.0.1` |
| API | http://localhost:9100 |
| Console (browse uploaded files) | http://localhost:9101/rustfs/console/ |
| Access key | `orbis` |
| Secret key | `YourStrongPass123` |
| Bucket | `orbis` |

Run these from the `orbis` folder:

| Task | Command |
| --- | --- |
| Create the container and bucket (first time only) | `pnpm --filter orbis-server run storage:setup` |
| Start | `pnpm --filter orbis-server run storage:start` |
| Stop | `pnpm --filter orbis-server run storage:stop` |
| Restart | `pnpm --filter orbis-server run storage:restart` |
| Check if it's running | `pnpm --filter orbis-server run storage:status` |
| Follow its logs | `pnpm --filter orbis-server run storage:logs` |
| Create the bucket again (if you deleted it) | `pnpm --filter orbis-server run storage:bucket` |
| Delete the container and every uploaded file | `pnpm --filter orbis-server run storage:remove` |

`pnpm run develop:web` and `pnpm run develop:mobile` restart the storage for you, along with the database.

### Production Image Storage

Production uses a Cloudflare R2 bucket. It's free up to 10 GB, and R2 doesn't charge when people download images.

1. In the [Cloudflare dashboard](https://dash.cloudflare.com), go to **R2 Object Storage** and create a bucket (for example `orbis`).
2. In the bucket's **Settings**, under **Custom Domains**, connect a domain you manage on Cloudflare (for example `cdn.yourdomain.com`). This makes the images public and serves them through Cloudflare's CDN. For a quick test without a domain, enable the **r2.dev** public URL instead. It's rate-limited, so don't use it for real traffic.
3. Back on the R2 overview, open **Manage API tokens** and create a token with **Object Read & Write** permission, limited to that bucket. Copy the **Access Key ID**, **Secret Access Key**, and the **S3 endpoint** (`https://<account-id>.r2.cloudflarestorage.com`).
4. Set these in the production server's environment:

   ```env
   AWS_ENDPOINT_URL_S3=https://<account-id>.r2.cloudflarestorage.com
   AWS_REGION=auto
   AWS_ACCESS_KEY_ID=<access key id>
   AWS_SECRET_ACCESS_KEY=<secret access key>
   BUCKET_NAME=orbis
   STORAGE_PUBLIC_URL=https://cdn.yourdomain.com
   ```

   `STORAGE_PUBLIC_URL` is where browsers load images from, with no trailing slash. Don't run `storage:bucket` against R2; the bucket and its public access are set up in the dashboard.

## Email

Orbis sends emails, like the link to confirm an email address after signing up. Locally they go to [Mailpit](https://mailpit.axllent.org), an inbox in a Docker container that `pnpm run setup` creates for you, so nothing reaches a real inbox. Open http://localhost:8025 to read them. In production they're sent through [Resend](https://resend.com) (see [Production Email](#production-email)).

| Setting | Value |
| --- | --- |
| Container | `orbis_server_email` |
| Image | `axllent/mailpit:v1.31.6` |
| Inbox and API | http://localhost:8025 |

Run these from the `orbis` folder:

| Task | Command |
| --- | --- |
| Create the container (first time only) | `pnpm --filter orbis-server run email:setup` |
| Start | `pnpm --filter orbis-server run email:start` |
| Stop | `pnpm --filter orbis-server run email:stop` |
| Restart | `pnpm --filter orbis-server run email:restart` |
| Check if it's running | `pnpm --filter orbis-server run email:status` |
| Follow its logs | `pnpm --filter orbis-server run email:logs` |
| Delete the container and every email in it | `pnpm --filter orbis-server run email:remove` |

`pnpm run develop:web` and `pnpm run develop:mobile` restart the inbox for you, along with the database and storage, and create it first if it doesn't exist yet.

The server picks where emails go from `server/.env`: through Resend when `RESEND_API_KEY` is set, otherwise to Mailpit at `MAILPIT_URL`. With neither, it prints each email, link included, in its terminal.

### Production Email

Production sends through Resend. Its free plan covers small apps.

1. Create an account at [resend.com](https://resend.com). Under **Domains**, add your domain, add the DNS records it shows at your DNS provider, and wait until it shows **Verified**.
2. Under **API Keys**, create a key with sending access, limited to that domain.
3. Set these in the production server's environment:

   ```bash
   fly secrets set RESEND_API_KEY=<api key> EMAIL_FROM="Orbis <hello@yourdomain.com>" -a orbis-server
   ```

   `EMAIL_FROM` must use exactly the domain you verified; a subdomain counts as a different domain. The links in emails use `WEB_URL`, so it must be the site's address.
4. Check **Emails** in Resend to see whether messages were delivered.

To try Resend locally instead of Mailpit, set `RESEND_API_KEY` in `server/.env`. Until your domain is verified, Resend only delivers mail from `onboarding@resend.dev` to the address you signed up to Resend with.

## Bot Protection

Logging in and signing up with an email and password go through [Cloudflare Turnstile](https://developers.cloudflare.com/turnstile/), a free check that tells people from bots, usually without asking them to do anything. The web form gets a token from Cloudflare and the server checks it before anything else.

| Setting | File | Local value |
| --- | --- | --- |
| `NEXT_PUBLIC_TURNSTILE_SITE_KEY` | `web/.env.local` | `1x00000000000000000000AA` |
| `TURNSTILE_SECRET_KEY` | `server/.env` | `1x0000000000000000000000000000000AA` |

These are Cloudflare's test keys, so the check always passes locally. Leave both empty to turn the check off, for example while working on the mobile app, which doesn't send a token yet. Scripts that log in through the API without the web form can send `XXXX.DUMMY.TOKEN.XXXX` as `turnstileToken`.

### Production Bot Protection

1. In the Cloudflare dashboard, open **Turnstile**, add a widget for the site's domain in **Managed** mode, and copy its site key and secret key.
2. Add `NEXT_PUBLIC_TURNSTILE_SITE_KEY` with the site key to the Vercel project's Environment Variables, then deploy the web app so the form starts sending tokens.
3. Then turn on the check in the server:

   ```bash
   fly secrets set TURNSTILE_SECRET_KEY=<secret key> -a orbis-server
   ```

Until the secret is set, the server skips the check and warns about it in its logs. The mobile app doesn't send a token yet, so once the check is on, it can only log in and sign up with Discord or Twitch.

## Two-Factor Sign-In

People can protect their password login with an authenticator app (Settings › Security). The server encrypts each person's authenticator secret with `TWO_FACTOR_KEY` in `server/.env`. Generate one with:

```bash
openssl rand -hex 32
```

Without it, setting up two-factor sign-in and logging in to an account that has it on both fail with "Two-factor sign-in isn't available right now".

In production, set it before deploying the server:

```bash
fly secrets set TWO_FACTOR_KEY=<key> -a orbis-server
```

Never change it once people use two-factor sign-in: their saved secrets can only be read with the key they were saved with, so they couldn't log in with their password until an admin removes their two-factor sign-in.

## Day-to-Day

| Task | Command |
| --- | --- |
| Start developing | `pnpm run develop:web` (web) or `pnpm run develop:mobile` (mobile) |
| Pull the latest changes, install dependencies, reset/migrate/seed the local database, and check environment values | `pnpm run pull` |
| Apply new database migrations while preserving existing data | `pnpm --filter orbis-server exec prisma migrate deploy` |
| Stop the database | `pnpm --filter orbis-server run db:stop` |

See [README.md](README.md) for releasing and the other scripts, and [Database](#database) for the database commands.

## Troubleshooting

**`pnpm run setup` says Docker is not running.** Start Docker Desktop (macOS and Windows) or `sudo systemctl start docker` (Ubuntu), then run `pnpm run setup` again. It's safe to rerun.

**`Permission denied (publickey)` when cloning `server` or `web`.** Your SSH key isn't set up or doesn't have access to the `PolsarCode` repositories. Redo [Connect to GitHub over SSH](#connect-to-github-over-ssh) and check `ssh -T git@github.com`.

**`permission denied while trying to connect to the Docker daemon socket` on Ubuntu.** Your user isn't in the `docker` group yet. Run `sudo usermod -aG docker $USER`, then log out and back in.

**`Bind for 0.0.0.0:5434 failed: port is already allocated`, or port 3000/4000 is in use.** Another process is using the port. Stop it, or find it with `lsof -i :5434` (macOS/Ubuntu/WSL). The same applies to the storage ports 9100 and 9101.

**`pnpm run develop:web` fails with `No such container: orbis_server_storage`.** Your setup predates image storage. Add the storage lines (`AWS_*`, `BUCKET_NAME`, `STORAGE_PUBLIC_URL`) from `server/example.env` to `server/.env`, then run `pnpm --filter orbis-server run storage:setup`.

**`/usr/bin/env: 'bash\r': No such file or directory` on Windows.** The scripts were checked out with Windows line endings. Run `git config --global core.autocrlf input`, delete the project folder, and clone again inside WSL.

**The API can't reach the database.** Check the container is running with `pnpm --filter orbis-server run db:status`, start it with `pnpm --filter orbis-server run db:start`, and confirm `DATABASE_URL` in `server/.env` matches the value above.
