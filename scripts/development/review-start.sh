#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")/../.."

apps=(web mobile server)
labels=(Web Mobile Server)
checked=(0 0 1)

draw_checklist() {
  local i pointer mark
  for ((i = 0; i < ${#apps[@]}; i++)); do
    pointer=" "
    mark=" "
    [ "$i" -eq "$cursor" ] && pointer="›"
    [ "${checked[i]}" -eq 1 ] && mark="✓"
    printf '\033[2K%s [%s] %s\n' "$pointer" "$mark" "${labels[i]}"
  done
  printf '\033[2K%s\n' "$status"
}

pick_apps() {
  local key rest i count=${#apps[@]}
  cursor=0
  status=""
  echo "🧪 What are you testing? (↑/↓ or j/k to move, space to check, enter to continue)"
  printf '\033[?25l'
  trap 'printf "\033[?25h"' EXIT
  draw_checklist
  while true; do
    IFS= read -rsn1 key
    if [ "$key" = $'\033' ]; then
      IFS= read -rsn2 rest
      case "$rest" in
        '[A' | 'OA') key=k ;;
        '[B' | 'OB') key=j ;;
      esac
    fi
    status=""
    case "$key" in
      k) cursor=$(((cursor - 1 + count) % count)) ;;
      j) cursor=$(((cursor + 1) % count)) ;;
      ' ') checked[cursor]=$((1 - checked[cursor])) ;;
      '')
        for ((i = 0; i < count; i++)); do
          [ "${checked[i]}" -eq 1 ] && selected="$selected ${apps[i]}"
        done
        [ -n "$selected" ] && break
        status="Check at least one."
        ;;
    esac
    printf '\033[%dA' "$((count + 1))"
    draw_checklist
  done
  printf '\033[?25h'
}

selected=""
if [ "$#" -gt 0 ]; then
  for arg in "$@"; do
    case "$arg" in
      web | mobile | server) selected="$selected $arg" ;;
      all) selected="$selected web mobile server" ;;
      *)
        echo "❌ Unknown choice \"$arg\". Use web, mobile, server, or all." >&2
        exit 1
        ;;
    esac
  done
elif [ -t 0 ]; then
  pick_apps
else
  echo "❌ Choose what to review: pnpm run review:start web mobile server (any of them, or all)." >&2
  exit 1
fi

picked() {
  case " $selected " in
    *" $1 "*) return 0 ;;
    *) return 1 ;;
  esac
}

if picked web && picked mobile; then
  script="develop:all"
elif picked web; then
  script="develop:web"
elif picked mobile; then
  script="develop:mobile"
else
  script="develop:server"
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "📦 Installing the GitHub CLI..."
  if command -v brew >/dev/null 2>&1; then
    brew install gh
  elif command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update
    sudo apt-get install -y gh
  elif command -v winget >/dev/null 2>&1; then
    winget install --id GitHub.cli -e
  fi
  if ! command -v gh >/dev/null 2>&1; then
    echo "❌ Couldn't find the GitHub CLI. Install it from https://cli.github.com (or restart your terminal if it was just installed), then rerun pnpm run review:start." >&2
    exit 1
  fi
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "🔑 Logging in to GitHub..."
  gh auth login
fi

ask_pr() {
  local number
  read -rp "$1 PR number (leave empty to skip): " number
  if [ -n "$number" ] && ! [[ $number =~ ^[0-9]+$ ]]; then
    echo "❌ \"$number\" is not a PR number." >&2
    exit 1
  fi
  echo "$number"
}

web_pr=""
server_pr=""
mobile_pr=""
picked web && web_pr=$(ask_pr "Web")
picked server && server_pr=$(ask_pr "Server")
picked mobile && mobile_pr=$(ask_pr "Mobile")

if [ -z "$web_pr" ] && [ -z "$server_pr" ] && [ -z "$mobile_pr" ]; then
  echo "Nothing to review."
  exit 0
fi

for entry in "web:$web_pr" "server:$server_pr" "mobile:$mobile_pr"; do
  path=${entry%%:*}
  number=${entry#*:}
  [ -z "$number" ] && continue
  if [ -n "$(git -C "$path" status --porcelain)" ]; then
    echo "❌ $path has uncommitted changes. Commit or stash them first." >&2
    exit 1
  fi
  if ! title=$(cd "$path" && gh pr view "$number" --json title -q .title 2>/dev/null); then
    echo "❌ $path has no PR #$number." >&2
    exit 1
  fi
  echo "🔎 $path PR #$number: $title"
done

for entry in "web:$web_pr" "server:$server_pr" "mobile:$mobile_pr"; do
  path=${entry%%:*}
  number=${entry#*:}
  [ -z "$number" ] && continue
  echo "⬇️ Checking out $path PR #$number..."
  (cd "$path" && gh pr checkout "$number" --branch "pr/$number" >/dev/null)
  echo "✅ $path is on pr/$number at $(git -C "$path" rev-parse --short HEAD)"
done

echo "📦 Installing dependencies..."
pnpm install

echo "⚙️ Generating Prisma client..."
pnpm --filter orbis-server run prisma:generate

echo "🎉 Ready to review. Run pnpm run $script to start it, and pnpm run review:end when you're done."
