#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")/../.."

DEFAULT_BRANCH="main"

for path in web server mobile desktop; do
  if [ -n "$(git -C "$path" status --porcelain)" ]; then
    echo "❌ $path has uncommitted changes. Commit or stash them first." >&2
    exit 1
  fi
done

for path in web server mobile desktop; do
  git -C "$path" checkout -q "$DEFAULT_BRANCH"
  echo "✅ $path is on $DEFAULT_BRANCH at $(git -C "$path" rev-parse --short HEAD)"
done

echo "📦 Installing dependencies..."
pnpm install

echo "⚙️ Generating Prisma client..."
pnpm --filter orbis-server run prisma:generate

echo "🎉 Back on $DEFAULT_BRANCH."
