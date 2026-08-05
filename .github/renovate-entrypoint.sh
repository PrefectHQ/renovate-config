#!/bin/bash
# Container bootstrap for the self-hosted Renovate runner.
#
# Runs inside the Renovate Docker image (via the action's `docker-cmd-file`)
# BEFORE `renovate` starts, so the binaries it installs are on PATH when
# postUpgradeTasks commands execute. Renovate itself never bundles these.
#
# We install the doc generators that Renovate version bumps would otherwise
# leave stale, causing each repo's terraform-docs/helm-docs pre-commit check to
# fail in CI:
#   * terraform-docs -- regenerates module README tables on provider/version bumps
#   * helm-docs       -- regenerates chart README from values.yaml/Chart.yaml bumps
#
# Pin versions to match the repos' pre-commit hook revs so generated output is
# byte-identical to what CI expects (terraform-docs v0.20.0, helm-docs v1.11.0).
set -euo pipefail

TERRAFORM_DOCS_VERSION="0.20.0"
HELM_DOCS_VERSION="1.11.0"

# The Renovate image runs as a non-root user; install into a user-writable dir
# already on PATH inside the container.
BIN_DIR="/usr/local/bin"
if [ ! -w "$BIN_DIR" ]; then
  BIN_DIR="${HOME}/.local/bin"
  mkdir -p "$BIN_DIR"
  export PATH="${BIN_DIR}:${PATH}"
fi

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
