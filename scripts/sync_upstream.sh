#!/usr/bin/env bash

# Detects the latest stable upstream AltTab release and opens a draft PR merging its tag into main.
# On merge conflict, aborts and opens an issue instead. Never resolves conflicts automatically.
# Idempotent: exits without side effects when the tag is already integrated or a PR/issue already exists.
# Requires: git, gh (authenticated), jq. Run from the repository root.

set -eu

upstreamRepo="lwouis/alt-tab-macos"
baseBranch="main"
notify="vingt-douze"

release="$(gh api "repos/$upstreamRepo/releases/latest")"
tag="$(jq -r .tag_name <<<"$release")"
releaseUrl="$(jq -r .html_url <<<"$release")"
echo "Latest upstream stable release: $tag"

git fetch --quiet origin "$baseBranch"
git fetch --quiet "https://github.com/$upstreamRepo.git" "refs/tags/$tag:refs/tags/$tag"

if git merge-base --is-ancestor "$tag" "origin/$baseBranch"; then
    echo "$tag is already integrated in $baseBranch. Nothing to do."
    exit 0
fi

branch="sync/upstream-$tag"
prTitle="chore: sync upstream AltTab $tag"
issueTitle="Upstream AltTab $tag requires manual merge"

if [[ -n "$(gh pr list --state open --head "$branch" --json number -q '.[].number')" ]]; then
    echo "An open PR for $branch already exists. Nothing to do."
    exit 0
fi
if [[ -n "$(gh issue list --state open --search "\"$issueTitle\" in:title" --json number -q '.[].number')" ]]; then
    echo "An open issue for $tag already exists. Nothing to do."
    exit 0
fi

git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git checkout --quiet -B "$branch" "origin/$baseBranch"

body="$(mktemp)"
if git merge --no-ff --no-edit -m "chore: merge upstream AltTab $tag" "$tag"; then
    {
        echo "Upstream release: $releaseUrl"
        echo
        echo "## Release notes"
        echo
        jq -r '.body // "(none)"' <<<"$release"
    } >"$body"
    git push --quiet origin "$branch"
    gh pr create --draft --base "$baseBranch" --head "$branch" --title "$prTitle" --body-file "$body" \
        --reviewer "$notify" --assignee "$notify"
    echo "Opened draft PR for $tag."
else
    conflicts="$(git diff --name-only --diff-filter=U)"
    git merge --abort
    {
        echo "Upstream release: $releaseUrl"
        echo
        echo "Merging tag \`$tag\` into \`$baseBranch\` conflicts in:"
        echo
        sed 's/^/- `/; s/$/`/' <<<"$conflicts"
        echo
        echo "Resolve manually, keeping Alt²Tab specifics (\`ALT2TAB_FORCE_PRO\`, branding, disabled upstream services)."
    } >"$body"
    gh issue create --title "$issueTitle" --body-file "$body" --assignee "$notify"
    echo "Merge conflict: opened issue for $tag."
fi
