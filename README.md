# PrefectHQ Renovate config

Shared [Renovate](https://docs.renovatebot.com/) config presets for the org. Each repo extends the org baseline plus one or more archetype presets, then adds only its own repo-specific `customManagers`.

## How to consume

Add a `renovate.json` to the repo root:

```jsonc
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": [
    "github>PrefectHQ/renovate-config",
    "github>PrefectHQ/renovate-config:python"
  ],
  "customManagers": [ /* repo-specific regex managers only */ ]
}
```

Presets float (no `#vX.Y.Z` ref), so changes here propagate to all repos on their next Renovate run.

> **Note for PrefectHQ repos:** a `renovate.json` alone is not enough — Renovate runs from a single central runner (`.github/workflows/renovate.yaml` in this repo) that only acts on repos in its App install list. To onboard a repo, add it to that install list as well. Platform-team engineers: see the internal `docs/renovate.md` runbook for both steps.

## Presets

| Preset | Extends string | For |
|--------|----------------|-----|
| baseline | `github>PrefectHQ/renovate-config` | every repo (labels, commit prefix, minor/patch batch, major split, github-actions + mise groups, dependency dashboard, 7-day `minimumReleaseAge` on npm/PyPI/Actions) |
| `:flux` | `github>PrefectHQ/renovate-config:flux` | GitOps repos: flux/kubernetes scoping, otel group, kubernetes-api noise off |
| `:python` | `github>PrefectHQ/renovate-config:python` | uv / pip-tools / pip repos |
| `:terraform` | `github>PrefectHQ/renovate-config:terraform` | HCL repos |
| `:go` | `github>PrefectHQ/renovate-config:go` | Go repos |
| `:node` | `github>PrefectHQ/renovate-config:node` | Node/Vue/TS repos |
| `:helm` | `github>PrefectHQ/renovate-config:helm` | repos with Helm subcharts |

Compose freely, e.g. a uv-based repo that also ships a Helm chart extends `[baseline, :python, :helm]`.

## Design notes

- **Managers are auto-detected.** The baseline sets no `enabledManagers` allow-list, because `enabledManagers` is last-wins (not additive) and would break composition. Renovate discovers `uv.lock`, `.mise.toml`, `go.mod`, workflows, charts, etc. per repo. Archetypes only add grouping/scoping.
- **Floating refs** during rollout for fast iteration. Revisit pinning (`#vX.Y.Z`) once the org is migrated.
- **Auth:** this repo is public, so any Renovate runner can resolve the presets without an install token.

## Adding a repo-specific custom manager

Keep it in the consuming repo's `renovate.json`, not here. This repo holds only cross-repo policy. A consuming repo's own `renovate.json` is the place for `customManagers` (e.g. images pinned inline in YAML).
