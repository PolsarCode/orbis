#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")/../.."

trap 'pull_status=$?; node ./scripts/check-env.mjs; exit "$pull_status"' EXIT

echo "⬇️ Pulling the latest Orbis changes..."
git pull --ff-only
git submodule sync --recursive
git submodule update --init --recursive
git submodule foreach 'git checkout -q main && git pull --ff-only'

echo "📦 Installing dependencies..."
pnpm install

pnpm --filter orbis-server exec node -r dotenv/config -e '
  let database;
  try { database = new URL(process.env.DATABASE_URL); } catch {}
  if (!database || !["postgres:", "postgresql:"].includes(database.protocol) ||
      !["localhost", "127.0.0.1", "[::1]"].includes(database.hostname) ||
      database.port !== "5434" || database.pathname !== "/orbis_server_db") {
    console.error("Refusing to reset a database outside the local Orbis setup. Check DATABASE_URL in server/.env.");
    process.exit(1);
  }
'

if ! docker info >/dev/null 2>&1; then
  echo "❌ Docker is not running. Start Docker, then rerun pnpm run pull." >&2
  exit 1
fi
for container in orbis_server_db orbis_server_storage; do
  if ! docker container inspect "$container" >/dev/null 2>&1; then
    echo "❌ $container is missing. Run pnpm run setup first." >&2
    exit 1
  fi
done

echo "▶️ Starting the local database and storage..."
pnpm --filter orbis-server run db:start
pnpm --filter orbis-server run storage:start
docker exec orbis_server_db pg_isready -U postgres >/dev/null

echo "⚙️ Generating the Prisma client..."
pnpm --filter orbis-server run prisma:generate

echo "🧱 Resetting the local database and reapplying migrations..."
(cd server && npx prisma migrate reset --force)

echo "🔍 Checking that every schema change has a migration..."
drift=0
(cd server && npx prisma migrate diff --from-config-datasource --to-schema prisma/schema --exit-code >/dev/null) || drift=$?
if [ "$drift" -eq 2 ]; then
  echo "❌ The Prisma schema has changes that no migration covers." >&2
  echo "   Whoever changed server/prisma/schema needs to run pnpm --filter orbis-server run prisma:migrate <name> and commit the migration." >&2
  exit 1
elif [ "$drift" -ne 0 ]; then
  echo "❌ Couldn't compare the Prisma schema with the local database." >&2
  exit 1
fi

echo "🌱 Seeding the local database..."
pnpm --filter orbis-server run prisma:seed

echo "🎉 Updated and reseeded. Run pnpm run develop:web, pnpm run develop:mobile, or pnpm run develop:desktop to start working."
echo ""
echo "🔑 Local development accounts — http://localhost:3000/login"
echo "   Admin:       admin@user.com (or admin) / 123456"
echo "   Normal user: user@user.com (or user) / 123456"
