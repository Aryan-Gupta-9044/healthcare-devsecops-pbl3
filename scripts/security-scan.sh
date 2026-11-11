#!/usr/bin/env bash
# Usage: security-scan.sh bandit|gitleaks|deps|depcheck|trivy-image|trivy-fs|policy|report|all
# Independent of DEPLOY_ENV. Tools run from PATH/.venv, or via Docker if not installed.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; cd "$ROOT"
export PATH="$ROOT/.venv/bin:$PATH"
R="${REPORT_DIR:-$ROOT/reports}"; mkdir -p "$R"
BANDIT_FAIL_LEVEL="${BANDIT_FAIL_LEVEL:-HIGH}"
TRIVY_SEVERITY="${TRIVY_SEVERITY:-HIGH,CRITICAL}"
PIP_AUDIT_FAIL="${PIP_AUDIT_FAIL:-true}"
GITLEAKS_IMAGE="${GITLEAKS_IMAGE:-zricethezav/gitleaks:latest}"   # pin a version for reproducibility
TRIVY_IMAGE="${TRIVY_IMAGE:-aquasec/trivy:latest}"                # pin a version for reproducibility
DOCKER_IMAGE="${DOCKER_IMAGE:-healthcare-app}"; DOCKER_IMAGE_TAG="${DOCKER_IMAGE_TAG:-1.0.0}"
log() { printf '\n==== %s ====\n' "$*"; }
lvl() { echo "$1" | tr '[:upper:]' '[:lower:]'; }

run_bandit() {
  command -v bandit >/dev/null || { echo "bandit missing - run scripts/install-deps.sh security"; return 2; }
  log "Bandit SAST (fail level: $BANDIT_FAIL_LEVEL)"
  bandit -q -r app -f json -o "$R/bandit.json" >/dev/null 2>&1 || true      # full report for the summary
  bandit -r app --severity-level "$(lvl "$BANDIT_FAIL_LEVEL")" -f txt -o "$R/bandit.txt"; rc=$?
  cat "$R/bandit.txt" | tail -25; return $rc
}
run_gitleaks() {
  log "Gitleaks secret scan"
  if command -v gitleaks >/dev/null; then
    gitleaks detect --no-git --source . --config security/gitleaks.toml --redact -f json -r "$R/gitleaks.json"
  elif command -v docker >/dev/null; then
    docker run --rm -v "$ROOT:/repo" "$GITLEAKS_IMAGE" detect --no-git --source /repo --config /repo/security/gitleaks.toml --redact -f json -r /repo/reports/gitleaks.json
  else echo "gitleaks not installed and Docker unavailable"; return 2; fi
}
run_deps() {
  command -v pip-audit >/dev/null || { echo "pip-audit missing - run scripts/install-deps.sh security"; return 2; }
  log "Python dependency scan (pip-audit)"
  pip-audit -r app/requirements.txt -f json -o "$R/pip-audit.json" >/dev/null 2>&1 || true
  pip-audit -r app/requirements.txt 2>&1 | tee "$R/pip-audit.txt"; rc=${PIPESTATUS[0]}
  [ "$PIP_AUDIT_FAIL" = true ] && return $rc || return 0
}
run_depcheck() { # optional, heavy: downloads the NVD database (use NVD_API_KEY to speed up)
  command -v docker >/dev/null || { echo "Docker required for OWASP Dependency-Check"; return 2; }
  log "OWASP Dependency-Check (optional)"
  docker run --rm -v "$ROOT:/src:ro" -v "$R:/report" -v depcheck-data:/usr/share/dependency-check/data \
    owasp/dependency-check:latest --scan /src/app --format HTML --format JSON --out /report --failOnCVSS 7 ${NVD_API_KEY:+--nvdApiKey "$NVD_API_KEY"}
}
trivy_run() { # args after "trivy"
  if command -v trivy >/dev/null; then trivy "$@"
  else docker run --rm -v "$ROOT:/repo:ro" -v "$R:/reports" -v trivy-cache:/root/.cache/trivy "$TRIVY_IMAGE" "$@"; fi
}
run_trivy_image() {
  command -v trivy >/dev/null || command -v docker >/dev/null || { echo "trivy/docker unavailable"; return 2; }
  local img="$DOCKER_IMAGE:$DOCKER_IMAGE_TAG"; log "Trivy image scan: $img (severity $TRIVY_SEVERITY)"
  local src cfg="security/trivy.yaml" out="$R" tar=""
  if command -v trivy >/dev/null; then
    trivy image --config "$cfg" --ignorefile .trivyignore --severity "$TRIVY_SEVERITY" --format json -o "$R/trivy-image.json" --exit-code 0 "$img" >/dev/null 2>&1
    trivy image --config "$cfg" --ignorefile .trivyignore --severity "$TRIVY_SEVERITY" --format table -o "$R/trivy-image.txt" "$img"; rc=$?
  else
    docker save "$img" -o "$R/image.tar"
    docker run --rm -v "$ROOT:/repo:ro" -v "$R:/reports" -v trivy-cache:/root/.cache/trivy "$TRIVY_IMAGE" image --config /repo/security/trivy.yaml --ignorefile /repo/.trivyignore --severity "$TRIVY_SEVERITY" --format json -o /reports/trivy-image.json --exit-code 0 --input /reports/image.tar >/dev/null 2>&1
    docker run --rm -v "$ROOT:/repo:ro" -v "$R:/reports" -v trivy-cache:/root/.cache/trivy "$TRIVY_IMAGE" image --config /repo/security/trivy.yaml --ignorefile /repo/.trivyignore --severity "$TRIVY_SEVERITY" --format table -o /reports/trivy-image.txt --input /reports/image.tar; rc=$?
    rm -f "$R/image.tar"
  fi
  tail -30 "$R/trivy-image.txt" 2>/dev/null; return $rc
}
run_trivy_fs() {
  log "Trivy filesystem scan"
  if command -v trivy >/dev/null; then trivy fs --config security/trivy.yaml --severity "$TRIVY_SEVERITY" --skip-dirs .venv --skip-dirs reports -o "$R/trivy-fs.txt" .
  else trivy_run fs --config /repo/security/trivy.yaml --severity "$TRIVY_SEVERITY" --skip-dirs reports -o /reports/trivy-fs.txt /repo; fi
}
run_policy() { log "Security policy validation"; python3 security/validate_policy.py; }
run_report() { python3 security/generate_report.py; }

case "${1:-all}" in
  bandit) run_bandit;; gitleaks) run_gitleaks;; deps) run_deps;; depcheck) run_depcheck;;
  trivy-image) run_trivy_image;; trivy-fs) run_trivy_fs;; policy) run_policy;; report) run_report;;
  all) fail=0; for s in bandit gitleaks deps policy; do "run_$s" || { echo "GATE FAILED: $s"; fail=1; }; done
       run_trivy_image || { echo "GATE FAILED: trivy-image"; fail=1; }; run_report; exit $fail;;
  *) echo "usage: $0 bandit|gitleaks|deps|depcheck|trivy-image|trivy-fs|policy|report|all"; exit 2;;
esac
