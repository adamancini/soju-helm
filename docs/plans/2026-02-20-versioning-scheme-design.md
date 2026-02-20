# Versioning Scheme Design

## Summary

Establish a versioning scheme for soju-helm that pins upstream image tags to specific releases, follows semver for chart versioning, and automates upstream release detection via a scheduled GitHub Action that opens PRs for version bumps.

## Context

The chart currently uses `appVersion: "latest"` and unpinned image tags, making deployments non-deterministic. Both soju and gamja are hosted on Codeberg and publish container images to the Codeberg Container Registry. soju releases every 2-7 months; gamja releases irregularly (2-14 months between betas).

## Version Pinning

### Initial Versions

- **soju:** `v0.10.1` (latest as of 2026-02-20)
- **gamja:** `v1.0.0-beta.11` (latest as of 2026-02-20)

### Where Versions Live

| File | Field | Value |
|---|---|---|
| `charts/soju/Chart.yaml` | `appVersion` | `0.10.1` (no `v` prefix, Helm convention) |
| `charts/soju/Chart.yaml` | `version` | `0.1.0` (chart version) |
| `charts/soju/values.yaml` | `image.tag` | `v0.10.1` |
| `charts/soju/values.yaml` | `gamja.image.tag` | `v1.0.0-beta.11` |
| `charts/soju/charts/gamja/Chart.yaml` | `appVersion` | `1.0.0-beta.11` |
| `charts/soju/charts/gamja/values.yaml` | `image.tag` | `v1.0.0-beta.11` |

## Chart Version Bump Policy

Chart starts at `0.1.0` and follows semver:

| Upstream change | Chart bump | Example |
|---|---|---|
| soju/gamja patch release | Chart patch | `0.1.0` -> `0.1.1` |
| soju/gamja minor release | Chart minor | `0.1.x` -> `0.2.0` |
| soju major release | Chart minor (manual review) | `0.2.x` -> `0.3.0` |
| Chart-only changes | Manual at maintainer discretion | Templates, values restructuring |

## Upstream Watch Automation

### Workflow: `check-upstream.yml`

**Trigger:** Cron schedule, daily at 06:00 UTC.

**Process:**

1. Query Codeberg API for latest tags:
   - `https://codeberg.org/api/v1/repos/emersion/soju/tags?limit=1`
   - `https://codeberg.org/api/v1/repos/emersion/gamja/tags?limit=1`
2. Extract current pinned versions from `values.yaml`
3. Compare using semver logic (shell-based)
4. If new version detected:
   - Determine bump type (patch vs minor) from semver component comparison
   - Update `values.yaml` image tags
   - Update `Chart.yaml` appVersion and chart version
   - Update subchart `Chart.yaml` appVersion (for gamja)
   - Update subchart `values.yaml` image tag (for gamja)
   - Run `helm template` to validate
   - Open PR with changes

**PR format:**
- Title: `chore(deps): bump <app> <old> -> <new>`
- Body: link to upstream release notes, bump type, changed files
- Labels: `automated`, `dependency-update`
- Additional `breaking-change` label for major bumps
- Assigns maintainer (adamancini) as reviewer

**Guard rails:**
- Only opens PRs for patch and minor bumps
- Major bumps get `breaking-change` label for manual review
- Skips if PR already exists for the same target version
- Validates chart renders before opening PR
- No auto-merge; all PRs require manual merge

### Codeberg API Notes

Codeberg uses Forgejo/Gitea API. The tags endpoint returns objects with `name` field containing the tag name. No authentication required for public repos.

## Files Changed

**Modified:**
- `charts/soju/Chart.yaml` -- pin `appVersion`, keep `version` at `0.1.0`
- `charts/soju/values.yaml` -- pin `image.tag`, `gamja.image.tag`
- `charts/soju/charts/gamja/Chart.yaml` -- pin `appVersion`
- `charts/soju/charts/gamja/values.yaml` -- pin `image.tag`

**Created:**
- `.github/workflows/check-upstream.yml`

## Out of Scope

- Renovate / Dependabot configuration
- Automated PR merging
- Container image vulnerability scanning beyond existing Trivy in lint-test.yml
