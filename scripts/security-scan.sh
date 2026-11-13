#!/usr/bin/env bash
# Usage: security-scan.sh bandit|gitleaks|deps|depcheck|trivy-image|trivy-fs|policy|report|all
set -uo pipefail
# Prevent Git Bash from converting Linux paths passed to Docker
export MSYS_NO_PATHCONV=1
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
export PATH="$ROOT/.venv/bin:$PATH"
R="${REPORT_DIR:-$ROOT/reports}"
mkdir -p "$R"

BANDIT_FAIL_LEVEL="${BANDIT_FAIL_LEVEL:-HIGH}"
TRIVY_SEVERITY="${TRIVY_SEVERITY:-HIGH,CRITICAL}"
PIP_AUDIT_FAIL="${PIP_AUDIT_FAIL:-true}"
GITLEAKS_IMAGE="${GITLEAKS_IMAGE:-zricethezav/gitleaks:latest}"
TRIVY_IMAGE="${TRIVY_IMAGE:-aquasec/trivy:latest}"
DOCKER_IMAGE="${DOCKER_IMAGE:-healthcare-app}"
DOCKER_IMAGE_TAG="${DOCKER_IMAGE_TAG:-1.0.0}"

log() { printf '\n==== %s ====\n' "$*"; }
lvl() { echo "$1" | tr '[:upper:]' '[:lower:]'; }

# Copy project inputs from the Jenkins container into a stopped scanner container.
copy_project_inputs() {
  local name="$1"
  local item
  for item in app docker docs jenkins kubernetes scripts security tests; do
    [ ! -e "$item" ] || docker cp "$item" "$name:/tmp/" || return 1
  done
  for item in .dockerignore .env.example .gitattributes .gitignore .trivyignore Dockerfile Jenkinsfile Makefile README.md docker-compose.yml progress.md; do
    [ ! -f "$item" ] || docker cp "$item" "$name:/tmp/$item" || return 1
  done
}

run_bandit() {
  command -v bandit >/dev/null || {
    echo "bandit missing - run scripts/install-deps.sh security"
    return 2
  }
  log "Bandit SAST (fail level: $BANDIT_FAIL_LEVEL)"
  bandit -q -r app -f json -o "$R/bandit.json" >/dev/null 2>&1 || true
  bandit -r app --severity-level "$(lvl "$BANDIT_FAIL_LEVEL")" -f txt -o "$R/bandit.txt"
  local rc=$?
  tail -25 "$R/bandit.txt"
  return "$rc"
}

run_gitleaks() {
  log "Gitleaks secret scan"
  if command -v gitleaks >/dev/null; then
    gitleaks detect --no-git --source . --config security/gitleaks.toml --redact -f json -r "$R/gitleaks.json"
    return $?
  fi
  command -v docker >/dev/null || {
    echo "gitleaks not installed and Docker unavailable"
    return 2
  }

  local name="pbl9-gitleaks-$$"
  docker create --name "$name" "$GITLEAKS_IMAGE" detect \
    --no-git --source /tmp --config /tmp/security/gitleaks.toml \
    --redact -f json -r /tmp/gitleaks.json >/dev/null || return 2

  copy_project_inputs "$name" || {
    docker rm -f "$name" >/dev/null 2>&1
    return 2
  }

  docker start -a "$name"
  local rc=$?
  docker cp "$name:/tmp/gitleaks.json" "$R/gitleaks.json" >/dev/null 2>&1 || true
  docker rm -f "$name" >/dev/null 2>&1
  return "$rc"
}

run_deps() {
  command -v pip-audit >/dev/null || {
    echo "pip-audit missing - run scripts/install-deps.sh security"
    return 2
  }
  log "Python dependency scan (pip-audit)"
  pip-audit -r app/requirements.txt -f json -o "$R/pip-audit.json" >/dev/null 2>&1 || true
  pip-audit -r app/requirements.txt 2>&1 | tee "$R/pip-audit.txt"
  local rc=${PIPESTATUS[0]}
  [ "$PIP_AUDIT_FAIL" = true ] && return "$rc"
  return 0
}

# Optional: this legacy mode uses Docker bind mounts. Keep disabled in Jenkins
# until a dedicated copy-based Dependency-Check workflow is configured.
run_depcheck() {
  command -v docker >/dev/null || {
    echo "Docker required for OWASP Dependency-Check"
    return 2
  }
  log "OWASP Dependency-Check (optional)"
  echo "Dependency-Check requires a host-visible workspace mount; not enabled in this Jenkins container workflow."
  return 2
}

run_trivy_docker() {
  local name="$1"
  local output="$2"
  shift 2

  docker create --name "$name" -v trivy-cache:/root/.cache \
    "$TRIVY_IMAGE" "$@" >/dev/null || return 2

  copy_project_inputs "$name" || {
    docker rm -f "$name" >/dev/null 2>&1
    return 2
  }

  docker start -a "$name"
  local rc=$?
  docker cp "$name:/tmp/$output" "$R/$output" >/dev/null 2>&1 || true
  docker rm -f "$name" >/dev/null 2>&1
  return "$rc"
}

run_trivy_image() {
  command -v docker >/dev/null || {
    echo "Docker unavailable"
    return 2
  }

  local img="$DOCKER_IMAGE:$DOCKER_IMAGE_TAG"
  log "Trivy image scan: $img (severity $TRIVY_SEVERITY)"

  if command -v trivy >/dev/null; then
    trivy image --config security/trivy.yaml --ignorefile .trivyignore \
      --severity "$TRIVY_SEVERITY" --format json \
      -o "$R/trivy-image.json" --exit-code 0 "$img" >/dev/null 2>&1 || true

    trivy image --config security/trivy.yaml --ignorefile .trivyignore \
      --severity "$TRIVY_SEVERITY" --format table \
      -o "$R/trivy-image.txt" "$img"
    local rc=$?
    tail -30 "$R/trivy-image.txt" 2>/dev/null
    return "$rc"
  fi

  local tar="$R/image.tar"
  docker save "$img" -o "$tar" || return 2

  run_trivy_docker "pbl9-trivy-json-$$" "trivy-image.json" \
    image --config /tmp/security/trivy.yaml --ignorefile /tmp/.trivyignore \
    --severity "$TRIVY_SEVERITY" --format json \
    -o /tmp/trivy-image.json --exit-code 0 --input /tmp/image.tar
  local json_rc=$?

  # The second scan enforces the configured Trivy exit-code policy.
  run_trivy_docker "pbl9-trivy-table-$$" "trivy-image.txt" \
    image --config /tmp/security/trivy.yaml --ignorefile /tmp/.trivyignore \
    --severity "$TRIVY_SEVERITY" --format table \
    -o /tmp/trivy-image.txt --input /tmp/image.tar
  local table_rc=$?

  rm -f "$tar"
  tail -30 "$R/trivy-image.txt" 2>/dev/null

  [ "$json_rc" -eq 0 ] || return "$json_rc"
  return "$table_rc"
}

run_trivy_fs() {
  log "Trivy filesystem scan"

  if command -v trivy >/dev/null; then
    trivy fs --config security/trivy.yaml --severity "$TRIVY_SEVERITY" \
      --skip-dirs .venv --skip-dirs reports \
      -o "$R/trivy-fs.txt" .
    return $?
  fi

  run_trivy_docker "pbl9-trivy-fs-$$" "trivy-fs.txt" \
    fs --config /tmp/security/trivy.yaml --severity "$TRIVY_SEVERITY" \
    --skip-dirs .venv --skip-dirs reports \
    -o /tmp/trivy-fs.txt /tmp
}

run_policy() {
  log "Security policy validation"
  python3 security/validate_policy.py
}

run_report() {
  python3 security/generate_report.py
}

case "${1:-all}" in
  bandit) run_bandit ;;
  gitleaks) run_gitleaks ;;
  deps) run_deps ;;
  depcheck) run_depcheck ;;
  trivy-image) run_trivy_image ;;
  trivy-fs) run_trivy_fs ;;
  policy) run_policy ;;
  report) run_report ;;
  all)
    fail=0
    for s in bandit gitleaks deps policy; do
      "run_$s" || {
        echo "GATE FAILED: $s"
        fail=1
      }
    done
    run_trivy_image || {
      echo "GATE FAILED: trivy-image"
      fail=1
    }
    run_report
    exit "$fail"
    ;;
  *)
    echo "usage: $0 bandit|gitleaks|deps|depcheck|trivy-image|trivy-fs|policy|report|all"
    exit 2
    ;;
esac