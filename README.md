# PrefectHQ Renovate config

Shared [Renovate](https://docs.renovatebot.com/) config presets for the org, plus the single central runner that applies them. Your repo extends the baseline plus an archetype or two, and Renovate opens grouped dependency-update PRs — no per-repo Renovate workflow to copy around.

Want to get your repo onto it? Jump to [Onboard a repo](#onboard-a-repo).

## How it works

```
PrefectHQ/renovate-config (this repo)
├── default.json + archetype presets   ← the shared config every repo extends
└── .github/workflows/renovate.yaml    ← the ONE runner for the whole org
          │
          │  weekly cron (Mon 15:00 UTC) + manual dispatch
          ▼
   autodiscovers across the Renovate App's install list
          │
          ▼
   for each installed repo that has a renovate.json:
     open grouped dependency-update PRs
```

A repo is picked up when two things are true: it has a `renovate.json`, and it's on the App's install list. Both are covered in [Onboard a repo](#onboard-a-repo).

## Onboard a repo

Two small PRs, both self-serve.

### 1. Add `renovate.json` to your repo

At the repo root, extend the baseline plus the archetype(s) that match your ecosystem:

```jsonc
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": [
    "github>PrefectHQ/renovate-config",
    "github>PrefectHQ/renovate-config:python"
  ]
}
```

| Archetype | For |
|---|---|
| `:python` | uv / pip-tools / pip repos |
| `:go` | Go module repos |
| `:node` | Node / Vue / TS repos |
| `:helm` | repos with Helm subcharts |
| `:terraform` | HCL repos |
| `:flux` | Flux/Kubernetes GitOps repos |

Compose freely — a uv repo that also ships a Helm chart extends `[baseline, :python, :helm]`. Managers are auto-detected, so **don't** add an `enabledManagers` allow-list. Only add repo-specific `customManagers` / `packageRules` for something the auto-detected managers miss (e.g. an image tag pinned inline in a YAML file) or to hold a version constraint.

### 2. Add your repo to the runner's install list

The runner only touches repos the Renovate GitHub App is installed on, and that list is managed in Terraform in the `platform` repo. Add your repo there in a one-line PR (the list is alphabetical). Once it merges and applies, the App picks your repo up. Not sure where that lives? Ask in `#eng-team` and someone will point you at it — or just open a PR for step 1 and we'll wire up the install.

### 3. Retire the old tooling

Renovate replaces the previous per-repo update mechanisms. Remove what it now covers:

- **Dependabot version updates** — delete `.github/dependabot.yml` (check parity first: every ecosystem it watched should have a Renovate manager). Dependabot **security alerts** are a separate repo-level setting — leave them on; deleting the config file doesn't disable them.
- **updatecli** — if `.github/updatecli/` manifests + workflows are now covered by Renovate, remove them. Where updatecli did something Renovate doesn't (e.g. bumping a version constant in source), add a `customManager` first, then remove updatecli.
- **mise-tool update workflow** — if a workflow only bumps `.mise.toml` (e.g. `update-mise-tools.yaml`), delete it; Renovate's `mise` manager handles it.
- **Dangling notify references** — if a `notify-on-failure.yaml` watches a workflow you just removed (a `- <Workflow Name>` entry under `workflow_run`), strip that entry too.

### 4. Verify

Trigger a run against just your repo instead of waiting for the weekly cron:

```sh
gh workflow run renovate.yaml --repo PrefectHQ/renovate-config -f repository=<repo-name>
```

Bare name or `owner/name`; leave the input blank for a full run. The first run creates the **Dependency Dashboard** issue and opens the initial batch of update PRs.

## Presets

| Preset | Extends string | For |
|--------|----------------|-----|
| baseline | `github>PrefectHQ/renovate-config` | every repo (labels, commit prefix, per-ecosystem minor/patch groups, major split, github-actions + mise groups, dependency dashboard, 7-day `minimumReleaseAge` on npm/PyPI/Actions) |
| `:flux` | `github>PrefectHQ/renovate-config:flux` | GitOps repos: flux/kubernetes scoping, otel group, kubernetes-api noise off |
| `:python` | `github>PrefectHQ/renovate-config:python` | uv / pip-tools / pip repos |
| `:terraform` | `github>PrefectHQ/renovate-config:terraform` | HCL repos |
| `:go` | `github>PrefectHQ/renovate-config:go` | Go repos |
| `:node` | `github>PrefectHQ/renovate-config:node` | Node/Vue/TS repos |
| `:helm` | `github>PrefectHQ/renovate-config:helm` | repos with Helm subcharts |

Presets float (no `#vX.Y.Z` ref), so changes here propagate to all repos on their next run.

### How PRs are grouped

Minor/patch bumps are grouped **per ecosystem** — one PR each for npm, gomod, python, docker, terraform, helm — plus separate groups for GitHub Actions and mise tools. **Major** bumps are always their own PR, labeled `major-update`. Archetypes layer finer sub-groups on top (e.g. `:python` splits dev tooling out).

### Supply-chain cooldown

The baseline waits **7 days** (`minimumReleaseAge`) before opening PRs for npm, PyPI, and GitHub Actions bumps — a package must be published for a week first, to avoid day-0 supply-chain attacks. CVE **alerting** is still handled by Dependabot's (separate) security alerts, so this cooldown doesn't delay awareness of vulnerabilities.

## Design notes

- **Managers are auto-detected.** The baseline sets no `enabledManagers` allow-list, because `enabledManagers` is last-wins (not additive) and would break composition. Renovate discovers `uv.lock`, `.mise.toml`, `go.mod`, workflows, charts, etc. per repo. Archetypes only add grouping/scoping.
- **Repo-specific `customManagers` go in the consuming repo's `renovate.json`**, not here. This repo holds only cross-repo policy.
- **Auth:** this repo is public, so any Renovate runner resolves the presets without an install token.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| No PRs and no dashboard on a repo | It has no `renovate.json`, or it's not on the install list. Both are required — see [Onboard a repo](#onboard-a-repo). |
| `GET /repos/*/dependabot/alerts` → 403 in the run log | Expected and harmless. The App deliberately lacks "Dependabot alerts" access (that preserves the 7-day cooldown). |
| `integration-unauthorized` abort on a repo | The App token can't reach something — often a github-actions dep that points at a repo the App isn't installed on. Disable that dep with a `packageRule`. |
| A run touched a repo you didn't expect | Autodiscover runs the whole install list. Drop the repo from the install list to stop it. |
| A preset change didn't take effect | Presets float, so changes apply on a repo's next run. Trigger a manual run (step 4 above) to apply immediately. |

Need a hand, or not sure which archetype fits? Ask in `#eng-team`.
