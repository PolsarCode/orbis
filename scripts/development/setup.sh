#!/usr/bin/env bash

set -e

cd "$(dirname "$0")/../.."

DEFAULT_BRANCH="main"
DB_CONTAINER="orbis_server_db"
STORAGE_CONTAINER="orbis_server_storage"
EMAIL_CONTAINER="orbis_server_email"

echo "🚀 Setting up Orbis..."

if git rev-parse --abbrev-ref --symbolic-full-name @{u} >/dev/null 2>&1; then
  echo "⬇️ Pulling latest changes..."
  git pull --ff-only
fi

echo "🔗 Syncing submodule URLs from .gitmodules..."
git submodule sync --recursive

echo "📥 Updating submodules..."
git submodule update --init --recursive

parent_branch=$(git branch --show-current)

for path in $(git config --file .gitmodules --get-regexp '\.path$' | awk '{print $2}'); do
  recorded=$(git rev-parse "HEAD:$path")
  branch=$DEFAULT_BRANCH
  if [ -n "$parent_branch" ] && git -C "$path" show-ref -q --verify "refs/remotes/origin/$parent_branch"; then
    branch=$parent_branch
  fi
  git -C "$path" checkout -q "$branch"
  if git -C "$path" merge-base --is-ancestor HEAD "$recorded"; then
    git -C "$path" merge -q --ff-only "$recorded"
    echo "✅ $path is on $branch at $(git -C "$path" rev-parse --short HEAD)"
  else
    git -C "$path" checkout -q --detach "$recorded"
    echo "✅ $path is at $(git -C "$path" rev-parse --short HEAD) ($branch is ahead, so it is detached)"
  fi
done

echo "📦 Installing dependencies..."
pnpm install

copy_env() {
  if [ ! -f "$2" ]; then
    cp "$1" "$2"
    echo "✅ Created $2 from $1"
  fi
  if grep -q "=XXXX" "$2"; then
    echo "⚠️ Replace the XXXX values in $2"
  fi
}

copy_env server/example.env server/.env
copy_env web/example.env web/.env.local
copy_env mobile/example.env mobile/.env.local

if ! command -v cargo >/dev/null 2>&1; then
  echo "⚠️ Rust isn't installed, so the desktop app can't run. Install it from https://www.rust-lang.org/tools/install if you work on it."
fi

if docker info >/dev/null 2>&1; then
  if ! docker container inspect "$DB_CONTAINER" >/dev/null 2>&1; then
    echo "🗄️ Creating database container..."
    pnpm --filter orbis-server run db:setup
  fi
  if ! docker container inspect "$STORAGE_CONTAINER" >/dev/null 2>&1; then
    echo "🪣 Creating storage container..."
    pnpm --filter orbis-server run storage:setup
  fi
  if ! docker container inspect "$EMAIL_CONTAINER" >/dev/null 2>&1; then
    echo "📬 Creating email inbox container..."
    pnpm --filter orbis-server run email:setup
  fi
else
  echo "⚠️ Docker is not running. Start it, then run: pnpm run setup"
fi

echo "⚙️ Generating Prisma client..."
pnpm --filter orbis-server run prisma:generate

echo "🎉 Setup complete. Run: pnpm run develop:web, pnpm run develop:mobile, or pnpm run develop:desktop"
