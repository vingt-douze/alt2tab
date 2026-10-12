#!/usr/bin/env bash

# Detects the latest stable upstream AltTab release and opens a draft PR merging its tag into main.
# On merge conflict, aborts and opens an issue instead. Never resolves conflicts automatically.
# Once a replacement exists, closes the sync PRs and issues of older tags the new one already contains.
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
git fetch --quiet "https://github.com/$upstreamRepo.git" "+refs/tags/$tag:refs/tags/$tag"

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

# Collected before the new item exists, so every entry here belongs to an older tag.
staleIssues="$(gh issue list --state open --search '"requires manual merge" in:title' --json number,title \
    -q '.[] | select(.title | test("^Upstream AltTab \\S+ requires manual merge$")) | "\(.number)\t\(.title | split(" ")[2])"')"
stalePrs="$(gh pr list --state open --json number,headRefName \
    -q '.[] | select(.headRefName | startswith("sync/upstream-")) | "\(.number)\t\(.headRefName | ltrimstr("sync/upstream-"))"')"

containedInNewTag() {
    git fetch --quiet "https://github.com/$upstreamRepo.git" "+refs/tags/$1:refs/tags/$1" \
        && git merge-base --is-ancestor "$1" "$tag"
}

# The merge commit this run pushed, as recorded in the PR body when it was opened. Empty for a PR
# opened before the marker existed, and for any body that has lost it.
recordedHead() {
    gh pr view "$1" --json body -q .body \
        | sed -n 's/.*<!-- alt2tab-sync-head: \([0-9a-f]\{7,40\}\) -->.*/\1/p'
}

# Closes the sync items of older tags that $tag already contains, so only the current one is left
# to act on. A PR whose head no longer matches its recorded merge commit carries work someone added,
# so it keeps its branch and stays open; an amend keeps the bot as the author, so authorship cannot
# tell the two apart.
closeStale() {
    local newUrl="$1" number oldTag
    while IFS=$'\t' read -r number oldTag; do
        [[ -n "$number" ]] && containedInNewTag "$oldTag" || continue
        gh issue close "$number" --reason "not planned" \
            --comment "Superseded by $tag, which already contains $oldTag: $newUrl"
    done <<<"$staleIssues"
    while IFS=$'\t' read -r number oldTag; do
        [[ -n "$number" ]] && containedInNewTag "$oldTag" || continue
        if [[ "$(recordedHead "$number")" != "$(gh pr view "$number" --json headRefOid -q .headRefOid)" ]]; then
            echo "PR #$number no longer matches the merge recorded in its body. Leaving it open."
            continue
        fi
        gh pr close "$number" --delete-branch \
            --comment "Superseded by $tag, which already contains $oldTag: $newUrl"
    done <<<"$stalePrs"
}

git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git checkout --quiet -B "$branch" "origin/$baseBranch"

body="$(mktemp)"
if git merge --no-ff --no-edit -m "chore: merge upstream AltTab $tag" "$tag"; then
    mergeSha="$(git rev-parse HEAD)"
    {
        echo "Upstream release: $releaseUrl"
        echo
        echo "## Release notes"
        echo
        jq -r '.body // "(none)"' <<<"$release"
        echo
        echo "<!-- alt2tab-sync-head: $mergeSha -->"
    } >"$body"
    git push --quiet origin "$branch"
    prUrl="$(gh pr create --draft --base "$baseBranch" --head "$branch" --title "$prTitle" --body-file "$body" \
        --reviewer "$notify" --assignee "$notify")"
    echo "Opened draft PR for $tag: $prUrl"
    # Lets the caller workflow validate this merge in the same run, which avoids the approval
    # a pull_request run opened by GITHUB_TOKEN would need. The sha is what the validation checks out
    # and reports its status on; the branch only groups the runs that supersede each other.
    if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
        {
            echo "branch=$branch"
            echo "sha=$mergeSha"
        } >>"$GITHUB_OUTPUT"
    fi
    closeStale "$prUrl"
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
    issueUrl="$(gh issue create --title "$issueTitle" --body-file "$body" --assignee "$notify")"
    echo "Merge conflict: opened issue for $tag: $issueUrl"
    closeStale "$issueUrl"
fi
