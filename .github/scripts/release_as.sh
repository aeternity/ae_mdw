#!/usr/bin/env bash
# Prints `release-as=X.Y.0` when the unreleased commits have a perf change but no feature,
# breaking change or Release-As footer, as release-please only bumps the minor version for feat.
set -euo pipefail

current=$(jq -r '."."' .release-please-manifest.json)
tag="v${current}"

git rev-parse -q --verify "refs/tags/${tag}" >/dev/null || exit 0

subjects=$(git log --format=%s "${tag}..HEAD")
bodies=$(git log --format=%b "${tag}..HEAD")

grep -qE '^[a-z]+(\([^)]*\))?!:' <<<"$subjects" && exit 0
grep -qE '^feat(ure)?(\([^)]*\))?:' <<<"$subjects" && exit 0
grep -qE '^BREAKING[ -]CHANGE:' <<<"$bodies" && exit 0
grep -qiE '^release-as:' <<<"$bodies" && exit 0
grep -qE '^perf(\([^)]*\))?:' <<<"$subjects" || exit 0

IFS=. read -r major minor _patch <<<"$current"
echo "release-as=${major}.$((minor + 1)).0"
