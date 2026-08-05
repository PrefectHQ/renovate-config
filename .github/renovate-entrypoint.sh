#!/bin/bash
# Container bootstrap for the self-hosted Renovate runner.
#
# Passed to renovatebot/github-action as `docker-cmd-file`, which REPLACES the
# container's default `renovate` command. So this script must (1) install the
# extra tooling and (2) hand off to renovate itself at the end -- otherwise the
# container exits after the install and Renovate never runs.
#
# Runs as root (docker-user: root in the workflow) so it can install into
# /usr/local/bin, then drops to the image's `ubuntu` user to run renovate.
#
# The tools it installs are the doc generators that Renovate version bumps would
# otherwise leave stale, causing each repo's terraform-docs/helm-docs pre-commit
# check to fail in CI:
#   * terraform-docs -- regenerates module README tables on provider/version bumps
#   * helm-docs       -- regenerates chart README from values.yaml/Chart.yaml bumps
#
# Versions pinned to match what CI actually runs, so generated output is
# byte-identical. The terraform repos use the `terraform-docs-system` hook,
# which ignores the pre-commit `rev:` and runs whatever terraform-docs is on
# PATH -- in CI that is the mise-pinned version (.mise.toml: 0.24.0 across
# bucket-sensor/aci-worker/ecs-worker). A newer terraform-docs pads table
# separators (`| ---- |` vs `|------|`), so a version mismatch fails CI even
# when the content is identical. helm-docs pinned to prefect-helm's hook rev.
set -euo pipefail

TERRAFORM_DOCS_VERSION="0.24.0"
HELM_DOCS_VERSION="1.11.0"
BIN_DIR="/usr/local/bin"

arch="$(uname -m)"
case "$arch" in
  x86_64|amd64) arch="amd64" ;;
  aarch64|arm64) arch="arm64" ;;
  *) echo "unsupported arch: $arch" >&2; exit 1 ;;
esac

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "Installing terraform-docs v${TERRAFORM_DOCS_VERSION} (${arch})"
curl -fsSL \
  "https://github.com/terraform-docs/terraform-docs/releases/download/v${TERRAFORM_DOCS_VERSION}/terraform-docs-v${TERRAFORM_DOCS_VERSION}-linux-${arch}.tar.gz" \
  -o "${tmp}/terraform-docs.tar.gz"
tar -xzf "${tmp}/terraform-docs.tar.gz" -C "$tmp" terraform-docs
install -m 0755 "${tmp}/terraform-docs" "${BIN_DIR}/terraform-docs"

echo "Installing helm-docs v${HELM_DOCS_VERSION} (${arch})"
# helm-docs release asset uses x86_64/arm64 in the archive name.
case "$arch" in
  amd64) hd_arch="x86_64" ;;
  arm64) hd_arch="arm64" ;;
esac
curl -fsSL \
  "https://github.com/norwoodj/helm-docs/releases/download/v${HELM_DOCS_VERSION}/helm-docs_${HELM_DOCS_VERSION}_Linux_${hd_arch}.tar.gz" \
  -o "${tmp}/helm-docs.tar.gz"
tar -xzf "${tmp}/helm-docs.tar.gz" -C "$tmp" helm-docs
install -m 0755 "${tmp}/helm-docs" "${BIN_DIR}/helm-docs"

echo "terraform-docs: $(command -v terraform-docs) -> $(terraform-docs --version)"
echo "helm-docs:      $(command -v helm-docs) -> $(helm-docs --version)"

# Hand off to Renovate as the non-root image user. `docker-cmd-file` replaces
# the default command, so this line is what actually runs Renovate.
exec runuser -u ubuntu renovate
