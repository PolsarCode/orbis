#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")/../.."

apps=(web mobile server)
labels=(Web Mobile "Server (always on)")
checked=(0 0 1)
locked=2

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
  echo "🚀 What do you want to start? (↑/↓ or j/k to move, space to check, enter to start)"
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
      ' ')
        if [ "$cursor" -eq "$locked" ]; then
          status="The server and database always start."
        else
          checked[cursor]=$((1 - checked[cursor]))
        fi
        ;;
      '')
        for ((i = 0; i < count; i++)); do
          [ "${checked[i]}" -eq 1 ] && selected="$selected ${apps[i]}"
        done
        break
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
      all) selected="$selected web mobile" ;;
      *)
        echo "❌ Unknown choice \"$arg\". Use web, mobile, server, or all." >&2
        exit 1
        ;;
    esac
  done
elif [ -t 0 ]; then
  pick_apps
else
  echo "❌ Choose what to start: pnpm run develop web mobile server (any of them, or all), or pnpm run develop:web, develop:mobile, develop:all, or develop:server." >&2
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

exec pnpm run "$script"
