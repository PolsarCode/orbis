#!/usr/bin/env bash

set -e

cd "$(dirname "$0")/../.."

fail() {
  echo "❌ $1" >&2
  exit 1
}

label() {
  printf '%s' "$1" | awk '{print toupper(substr($0, 1, 1)) substr($0, 2)}'
}

branch=$(git branch --show-current)
[ -n "$branch" ] || fail "This repository is not on a branch."

submodules=$(git config --file .gitmodules --get-regexp '\.path$' | awk '{print $2}')
released_file=released.json

released_commit() {
  node -e '
    const fs = require("fs");
    let commits = {};
    try { commits = JSON.parse(fs.readFileSync(process.argv[1], "utf8")); } catch {}
    console.log(commits[process.argv[2]] ?? "");
  ' "$released_file" "$1"
}

collect() {
  changed=""
  subjects=""
  body=""

  for path in $submodules; do
    last=$(released_commit "$path")
    [ -n "$last" ] || last=$(git rev-parse -q --verify "HEAD:$path" || true)
    current=$(git -C "$path" rev-parse HEAD)
    [ "$last" = "$current" ] && continue

    [ -n "$(git -C "$path" branch --show-current)" ] || fail "$path is not on a branch."
    if [ -n "$last" ]; then
      git -C "$path" merge-base --is-ancestor "$last" "$current" ||
        fail "$path is not ahead of the commit it was last released from ($last)."
      range="$last..$current"
    else
      range="$current"
    fi

    commits=$(git -C "$path" log --reverse --no-merges --format=%s "$range")
    changed="$changed $path"
    subjects="$subjects$commits"$'\n'
    body="$body$(label "$path"):"$'\n'"$(printf '%s\n' "$commits" | sed 's/^/- /')"$'\n\n'
  done

  files=$(git status --porcelain --ignore-submodules=all | cut -c4-)
  if [ -n "$files" ]; then
    body="${body}Orbis:"$'\n'"$(printf '%s\n' "$files" | sed 's/^/- /')"$'\n'
  fi
}

collect

node scripts/development/changelog.mjs || fail "The changelog step stopped the release."
collect

if printf '%s' "$subjects" | grep -qE '^(💥|:boom:)'; then
  bump=major
elif printf '%s' "$subjects" | grep -qE '^(✨|:sparkles:)'; then
  bump=minor
else
  bump=patch
fi

version=$(node -e '
  const [major, minor, patch] = require("./package.json").version.split(".").map(Number);
  const next = { major: [major + 1, 0, 0], minor: [major, minor + 1, 0], patch: [major, minor, patch + 1] };
  console.log(next[process.argv[1]].join("."));
' "$bump")
tag="v$version"

git rev-parse -q --verify "refs/tags/$tag" >/dev/null && fail "Tag $tag already exists."

echo "🔖 Releasing $tag ($bump)"
[ -n "$changed" ] || echo "ℹ️ Nothing new in server, web, or mobile, so this release only bumps the version."

for path in $changed; do
  echo "⬆️ Pushing $path..."
  git -C "$path" push -u origin HEAD
done

node -e '
  const fs = require("fs");
  const pkg = JSON.parse(fs.readFileSync("package.json", "utf8"));
  pkg.version = process.argv[1];
  fs.writeFileSync("package.json", JSON.stringify(pkg, null, 2) + "\n");
' "$version"

node -e '
  const fs = require("fs");
  const [file, ...pairs] = process.argv.slice(1);
  const commits = {};
  for (let i = 0; i < pairs.length; i += 2) commits[pairs[i]] = pairs[i + 1];
  fs.writeFileSync(file, JSON.stringify(commits, null, 2) + "\n");
' "$released_file" $(for path in $submodules; do printf '%s %s ' "$path" "$(git -C "$path" rev-parse HEAD)"; done)

message=$(printf '%s\n\n%s' "$tag" "$body")

git add -A
printf '%s\n' "$message" | git commit -q --cleanup=whitespace -F -
printf '%s\n' "$message" | git tag -a "$tag" --cleanup=whitespace -F -

echo "⬆️ Pushing $tag..."
git push -u origin HEAD
git push origin "refs/tags/$tag"

for path in server web mobile; do
  case " $changed " in
    *" $path "*)
      echo "🚀 Deploying $path..."
      (cd "$path" && pnpm run deploy)
      ;;
    *) echo "⏭️ Skipping the $path deploy: nothing new in $path." ;;
  esac
done

echo "✅ Released $tag"
