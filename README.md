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

## Presets

| Preset | Extends string | For |
|--------|----------------|-----|
| baseline | `github>PrefectHQ/renovate-config` | every repo (labels, commit prefix, minor/patch batch, major split, github-actions + mise groups, dependency dashboard) |
| `:flux` | `github>PrefectHQ/renovate-config:flux` | GitOps repos (cluster-deployment): flux/kubernetes scoping, otel group, kubernetes-api noise off |
| `:python` | `github>PrefectHQ/renovate-config:python` | uv / pip-tools / pip repos (nebula, flows, customer-managed) |
| `:terraform` | `github>PrefectHQ/renovate-config:terraform` | HCL repos (platform, terraform-provider-prefect) |
| `:go` | `github>PrefectHQ/renovate-config:go` | Go repos (prefect-operator) |
| `:node` | `github>PrefectHQ/renovate-config:node` | Node/Vue/TS repos (nebula-ui, horizon, vue-charts, eslint-config, fastmcp) |
| `:helm` | `github>PrefectHQ/renovate-config:helm` | repos with Helm subcharts (prefect-helm, prefect-operator, customer-managed) |

Compose freely, e.g. nebula = `[baseline, :python, :helm]`.

## Design notes

- **Managers are auto-detected.** The baseline sets no `enabledManagers` allow-list, because `enabledManagers` is last-wins (not additive) and would break composition. Renovate discovers `uv.lock`, `.mise.toml`, `go.mod`, workflows, charts, etc. per repo. Archetypes only add grouping/scoping.
- **Floating refs** during rollout for fast iteration. Revisit pinning (`#vX.Y.Z`) once the org is migrated.
- **Auth:** this repo is private, so the `prefect-ci-bot-internal` GitHub App must be installed on it for Renovate to resolve the presets.

## Adding a repo-specific custom manager

Keep it in the consuming repo's `renovate.json`, not here. This repo holds only cross-repo policy. See `cluster-deployment/renovate.json` for the reference set of `customManagers` (images pinned inline in YAML).
