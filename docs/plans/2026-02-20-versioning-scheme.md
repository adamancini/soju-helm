# Versioning Scheme Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Pin upstream image tags to specific releases, implement semver chart versioning, and add a GitHub Action that watches Codeberg for new soju/gamja releases and opens PRs.

**Architecture:** Pin soju `v0.10.1` and gamja `v1.0.0-beta.11` across Chart.yaml files and values.yaml files. Add `check-upstream.yml` workflow that polls Codeberg API daily, compares semver, and opens PRs with appropriate chart version bumps.

**Tech Stack:** Helm 3, GitHub Actions, Codeberg Forgejo API, shell-based semver comparison

**Design doc:** `docs/plans/2026-02-20-versioning-scheme-design.md`

---

### Task 1: Pin Upstream Versions

**Files:**
- Modify: `charts/soju/Chart.yaml` (line 6: appVersion)
- Modify: `charts/soju/values.yaml` (line 20: image.tag, line 165: gamja.image.tag)
- Modify: `charts/soju/charts/gamja/Chart.yaml` (line 6: appVersion)
- Modify: `charts/soju/charts/gamja/values.yaml` (line 5: image.tag)

**Step 1: Update soju Chart.yaml appVersion**

In `charts/soju/Chart.yaml`, change line 6:

```yaml
appVersion: "0.10.1"
```

**Step 2: Update soju values.yaml image tag**

In `charts/soju/values.yaml`, change line 20:

```yaml
  tag: "v0.10.1"  # Pinned to upstream release
```

**Step 3: Update gamja image tag in parent values.yaml**

In `charts/soju/values.yaml`, change line 165:

```yaml
    tag: "v1.0.0-beta.11"
```

**Step 4: Update gamja subchart Chart.yaml appVersion**

In `charts/soju/charts/gamja/Chart.yaml`, change line 6:

```yaml
appVersion: "1.0.0-beta.11"
```

**Step 5: Update gamja subchart values.yaml image tag**

In `charts/soju/charts/gamja/values.yaml`, change line 5:

```yaml
  tag: "v1.0.0-beta.11"
```

**Step 6: Validate templates still render**

```bash
helm template soju charts/soju --set soju.domain=test.example.com > /dev/null && echo "OK"
```

Expected: `OK`

Verify image tags appear in rendered output:

```bash
helm template soju charts/soju --set soju.domain=test.example.com | grep "image:"
```

Expected: two lines showing `codeberg.org/emersion/soju:v0.10.1` and `codeberg.org/emersion/gamja:v1.0.0-beta.11`

**Step 7: Run yamllint**

```bash
yamllint -c .yamllint.yml charts/soju/values.yaml charts/soju/Chart.yaml
```

Expected: no errors

**Step 8: Commit**

```bash
git add charts/soju/Chart.yaml charts/soju/values.yaml charts/soju/charts/gamja/Chart.yaml charts/soju/charts/gamja/values.yaml
git commit -m "chore: pin soju v0.10.1 and gamja v1.0.0-beta.11"
```

---

### Task 2: Create Upstream Watch Workflow

**Files:**
- Create: `.github/workflows/check-upstream.yml`

**Step 1: Write the workflow**

The workflow:
- Runs daily at 06:00 UTC and on manual dispatch
- Fetches latest tags from Codeberg API for both soju and gamja
- Extracts current pinned versions from values.yaml
- Compares versions using shell semver logic
- If new version found: determines bump type, updates files, validates, opens PR
- Skips if a PR already exists for the same version

```yaml
name: Check Upstream Releases

on:
  schedule:
    # Daily at 06:00 UTC
    - cron: '0 6 * * *'
  workflow_dispatch:

permissions:
  contents: write
  pull-requests: write

jobs:
  check-soju:
    name: Check soju releases
    runs-on: ubuntu-latest
    outputs:
      new_version: ${{ steps.check.outputs.new_version }}
      current_version: ${{ steps.check.outputs.current_version }}
      bump_type: ${{ steps.check.outputs.bump_type }}
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Check for new soju release
        id: check
        run: |
          # Get latest tag from Codeberg
          LATEST=$(curl -sf https://codeberg.org/api/v1/repos/emersion/soju/tags?limit=1 | jq -r '.[0].name')
          echo "Latest soju tag: ${LATEST}"

          # Get current pinned version from values.yaml
          CURRENT=$(grep -A2 '^image:' charts/soju/values.yaml | grep 'tag:' | head -1 | sed 's/.*tag: *"\(.*\)".*/\1/')
          echo "Current pinned: ${CURRENT}"

          if [ "${LATEST}" = "${CURRENT}" ]; then
            echo "soju is up to date"
            echo "new_version=" >> "$GITHUB_OUTPUT"
            exit 0
          fi

          echo "New soju release: ${CURRENT} -> ${LATEST}"
          echo "new_version=${LATEST}" >> "$GITHUB_OUTPUT"
          echo "current_version=${CURRENT}" >> "$GITHUB_OUTPUT"

          # Determine bump type by comparing semver components
          # Strip v prefix for comparison
          OLD_VER="${CURRENT#v}"
          NEW_VER="${LATEST#v}"
          OLD_MAJOR="${OLD_VER%%.*}"
          NEW_MAJOR="${NEW_VER%%.*}"
          OLD_MINOR="${OLD_VER#*.}"; OLD_MINOR="${OLD_MINOR%%.*}"
          NEW_MINOR="${NEW_VER#*.}"; NEW_MINOR="${NEW_MINOR%%.*}"

          if [ "${NEW_MAJOR}" != "${OLD_MAJOR}" ]; then
            echo "bump_type=minor" >> "$GITHUB_OUTPUT"
          elif [ "${NEW_MINOR}" != "${OLD_MINOR}" ]; then
            echo "bump_type=minor" >> "$GITHUB_OUTPUT"
          else
            echo "bump_type=patch" >> "$GITHUB_OUTPUT"
          fi

  check-gamja:
    name: Check gamja releases
    runs-on: ubuntu-latest
    outputs:
      new_version: ${{ steps.check.outputs.new_version }}
      current_version: ${{ steps.check.outputs.current_version }}
      bump_type: ${{ steps.check.outputs.bump_type }}
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Check for new gamja release
        id: check
        run: |
          # Get latest tag from Codeberg
          LATEST=$(curl -sf https://codeberg.org/api/v1/repos/emersion/gamja/tags?limit=1 | jq -r '.[0].name')
          echo "Latest gamja tag: ${LATEST}"

          # Get current pinned version from gamja subchart values.yaml
          CURRENT=$(grep -A2 '^image:' charts/soju/charts/gamja/values.yaml | grep 'tag:' | head -1 | sed 's/.*tag: *"\(.*\)".*/\1/')
          echo "Current pinned: ${CURRENT}"

          if [ "${LATEST}" = "${CURRENT}" ]; then
            echo "gamja is up to date"
            echo "new_version=" >> "$GITHUB_OUTPUT"
            exit 0
          fi

          echo "New gamja release: ${CURRENT} -> ${LATEST}"
          echo "new_version=${LATEST}" >> "$GITHUB_OUTPUT"
          echo "current_version=${CURRENT}" >> "$GITHUB_OUTPUT"

          # Determine bump type
          # gamja uses pre-release tags (v1.0.0-beta.N), compare beta numbers
          OLD_VER="${CURRENT#v}"
          NEW_VER="${LATEST#v}"
          OLD_MAJOR="${OLD_VER%%.*}"
          NEW_MAJOR="${NEW_VER%%.*}"
          OLD_MINOR="${OLD_VER#*.}"; OLD_MINOR="${OLD_MINOR%%.*}"
          NEW_MINOR="${NEW_VER#*.}"; NEW_MINOR="${NEW_MINOR%%.*}"

          if [ "${NEW_MAJOR}" != "${OLD_MAJOR}" ]; then
            echo "bump_type=minor" >> "$GITHUB_OUTPUT"
          elif [ "${NEW_MINOR}" != "${OLD_MINOR}" ]; then
            echo "bump_type=minor" >> "$GITHUB_OUTPUT"
          else
            echo "bump_type=patch" >> "$GITHUB_OUTPUT"
          fi

  update-soju:
    name: Update soju version
    needs: check-soju
    if: needs.check-soju.outputs.new_version != ''
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Check for existing PR
        id: existing
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          NEW="${{ needs.check-soju.outputs.new_version }}"
          EXISTING=$(gh pr list --search "bump soju ${NEW}" --state open --json number --jq 'length')
          if [ "${EXISTING}" -gt 0 ]; then
            echo "PR already exists for soju ${NEW}"
            echo "skip=true" >> "$GITHUB_OUTPUT"
          else
            echo "skip=false" >> "$GITHUB_OUTPUT"
          fi

      - name: Set up Helm
        if: steps.existing.outputs.skip != 'true'
        uses: azure/setup-helm@v4
        with:
          version: v3.16.0

      - name: Update versions
        if: steps.existing.outputs.skip != 'true'
        run: |
          NEW="${{ needs.check-soju.outputs.new_version }}"
          OLD="${{ needs.check-soju.outputs.current_version }}"
          BUMP="${{ needs.check-soju.outputs.bump_type }}"
          APP_VER="${NEW#v}"

          # Update image tag in values.yaml (first image.tag occurrence)
          sed -i "s|tag: \"${OLD}\".*# Pinned to upstream release|tag: \"${NEW}\"  # Pinned to upstream release|" charts/soju/values.yaml

          # Update appVersion in Chart.yaml
          sed -i "s|appVersion: \".*\"|appVersion: \"${APP_VER}\"|" charts/soju/Chart.yaml

          # Bump chart version
          CHART_VER=$(grep '^version:' charts/soju/Chart.yaml | sed 's/version: //')
          IFS='.' read -r CMAJ CMIN CPATCH <<< "${CHART_VER}"
          if [ "${BUMP}" = "minor" ]; then
            CMIN=$((CMIN + 1))
            CPATCH=0
          else
            CPATCH=$((CPATCH + 1))
          fi
          NEW_CHART="${CMAJ}.${CMIN}.${CPATCH}"
          sed -i "s|^version: ${CHART_VER}|version: ${NEW_CHART}|" charts/soju/Chart.yaml

          echo "Updated soju ${OLD} -> ${NEW}, chart ${CHART_VER} -> ${NEW_CHART}"

      - name: Validate chart
        if: steps.existing.outputs.skip != 'true'
        run: |
          helm lint charts/soju --strict --set soju.domain=test.example.com
          helm template soju charts/soju --set soju.domain=test.example.com > /dev/null

      - name: Create PR
        if: steps.existing.outputs.skip != 'true'
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          NEW="${{ needs.check-soju.outputs.new_version }}"
          OLD="${{ needs.check-soju.outputs.current_version }}"
          BUMP="${{ needs.check-soju.outputs.bump_type }}"
          BRANCH="deps/soju-${NEW}"

          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git checkout -b "${BRANCH}"
          git add -A
          git commit -m "chore(deps): bump soju ${OLD} -> ${NEW}"
          git push -u origin "${BRANCH}"

          LABELS="automated,dependency-update"
          if echo "${NEW}" | grep -qE '^v[0-9]+\.' && [ "$(echo "${NEW#v}" | cut -d. -f1)" != "$(echo "${OLD#v}" | cut -d. -f1)" ]; then
            LABELS="${LABELS},breaking-change"
          fi

          gh pr create \
            --title "chore(deps): bump soju ${OLD} -> ${NEW}" \
            --body "$(cat <<EOF
          ## Upstream Release

          **soju** ${OLD} → ${NEW}

          - Release notes: https://codeberg.org/emersion/soju/releases/tag/${NEW}
          - Bump type: ${BUMP}

          ## Changes

          - Updated \`charts/soju/values.yaml\` image tag
          - Updated \`charts/soju/Chart.yaml\` appVersion and chart version
          - Helm lint and template validation passed
          EOF
          )" \
            --label "${LABELS}" \
            --reviewer adamancini

  update-gamja:
    name: Update gamja version
    needs: check-gamja
    if: needs.check-gamja.outputs.new_version != ''
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Check for existing PR
        id: existing
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          NEW="${{ needs.check-gamja.outputs.new_version }}"
          EXISTING=$(gh pr list --search "bump gamja ${NEW}" --state open --json number --jq 'length')
          if [ "${EXISTING}" -gt 0 ]; then
            echo "PR already exists for gamja ${NEW}"
            echo "skip=true" >> "$GITHUB_OUTPUT"
          else
            echo "skip=false" >> "$GITHUB_OUTPUT"
          fi

      - name: Set up Helm
        if: steps.existing.outputs.skip != 'true'
        uses: azure/setup-helm@v4
        with:
          version: v3.16.0

      - name: Update versions
        if: steps.existing.outputs.skip != 'true'
        run: |
          NEW="${{ needs.check-gamja.outputs.new_version }}"
          OLD="${{ needs.check-gamja.outputs.current_version }}"
          BUMP="${{ needs.check-gamja.outputs.bump_type }}"
          APP_VER="${NEW#v}"

          # Update gamja image tag in parent values.yaml
          sed -i "/^gamja:/,/^[^ ]/ s|tag: \"${OLD}\"|tag: \"${NEW}\"|" charts/soju/values.yaml

          # Update gamja subchart values.yaml
          sed -i "s|tag: \"${OLD}\"|tag: \"${NEW}\"|" charts/soju/charts/gamja/values.yaml

          # Update gamja subchart Chart.yaml appVersion
          sed -i "s|appVersion: \".*\"|appVersion: \"${APP_VER}\"|" charts/soju/charts/gamja/Chart.yaml

          # Bump chart version
          CHART_VER=$(grep '^version:' charts/soju/Chart.yaml | sed 's/version: //')
          IFS='.' read -r CMAJ CMIN CPATCH <<< "${CHART_VER}"
          if [ "${BUMP}" = "minor" ]; then
            CMIN=$((CMIN + 1))
            CPATCH=0
          else
            CPATCH=$((CPATCH + 1))
          fi
          NEW_CHART="${CMAJ}.${CMIN}.${CPATCH}"
          sed -i "s|^version: ${CHART_VER}|version: ${NEW_CHART}|" charts/soju/Chart.yaml

          echo "Updated gamja ${OLD} -> ${NEW}, chart ${CHART_VER} -> ${NEW_CHART}"

      - name: Validate chart
        if: steps.existing.outputs.skip != 'true'
        run: |
          helm lint charts/soju --strict --set soju.domain=test.example.com
          helm template soju charts/soju --set soju.domain=test.example.com > /dev/null

      - name: Create PR
        if: steps.existing.outputs.skip != 'true'
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          NEW="${{ needs.check-gamja.outputs.new_version }}"
          OLD="${{ needs.check-gamja.outputs.current_version }}"
          BUMP="${{ needs.check-gamja.outputs.bump_type }}"
          BRANCH="deps/gamja-${NEW}"

          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git checkout -b "${BRANCH}"
          git add -A
          git commit -m "chore(deps): bump gamja ${OLD} -> ${NEW}"
          git push -u origin "${BRANCH}"

          LABELS="automated,dependency-update"

          gh pr create \
            --title "chore(deps): bump gamja ${OLD} -> ${NEW}" \
            --body "$(cat <<EOF
          ## Upstream Release

          **gamja** ${OLD} → ${NEW}

          - Release notes: https://codeberg.org/emersion/gamja/releases/tag/${NEW}
          - Bump type: ${BUMP}

          ## Changes

          - Updated \`charts/soju/values.yaml\` gamja image tag
          - Updated \`charts/soju/charts/gamja/values.yaml\` image tag
          - Updated \`charts/soju/charts/gamja/Chart.yaml\` appVersion
          - Updated \`charts/soju/Chart.yaml\` chart version
          - Helm lint and template validation passed
          EOF
          )" \
            --label "${LABELS}" \
            --reviewer adamancini
```

**Step 2: Validate workflow YAML syntax**

```bash
yamllint -d relaxed .github/workflows/check-upstream.yml
```

Note: using relaxed mode since GH Actions YAML uses `${{ }}` expressions that yamllint may flag.

**Step 3: Commit**

```bash
git add .github/workflows/check-upstream.yml
git commit -m "feat: add upstream release watch workflow"
```

---

### Task 3: Update CI Trigger Paths

**Files:**
- Modify: `.github/workflows/lint-test.yml` (add check-upstream.yml to paths)

**Step 1: Add check-upstream.yml to lint-test paths**

The lint-test workflow should also trigger when the check-upstream workflow itself changes. Add to the `paths` list in both `pull_request` and `push` triggers:

```yaml
    paths:
      - 'charts/**'
      - '.github/workflows/lint-test.yml'
      - '.github/workflows/check-upstream.yml'
```

**Step 2: Commit**

```bash
git add .github/workflows/lint-test.yml
git commit -m "chore: add check-upstream.yml to lint-test trigger paths"
```

---

### Task 4: Validate and Push

**Step 1: Run full validation**

```bash
helm lint charts/soju --strict --set soju.domain=test.example.com
for f in charts/soju/ci/*.yaml; do
  echo "=== ${f} ==="
  helm template soju charts/soju -f "${f}" > /dev/null && echo "OK" || echo "FAIL"
done
yamllint -c .yamllint.yml charts/soju/values.yaml charts/soju/Chart.yaml charts/soju/ci/
```

Expected: all pass

**Step 2: Verify pinned images in rendered output**

```bash
helm template soju charts/soju --set soju.domain=test.example.com | grep "image:"
```

Expected:
```
        image: "codeberg.org/emersion/soju:v0.10.1"
        image: "codeberg.org/emersion/gamja:v1.0.0-beta.11"
```

**Step 3: Push**

```bash
git push origin main
```

**Step 4: Verify CI passes on GitHub**

Check GitHub Actions for the push. The lint-test workflow should run and pass with the new pinned versions.
