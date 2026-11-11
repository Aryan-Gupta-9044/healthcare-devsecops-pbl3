# VLE 9 - DevSecOps Implementation in a Healthcare System

## 1. Objective
Add automated security gates to the CI/CD lifecycle; deploy only if every gate passes; show a failing run and a remediated run.

## 2. Required software
Docker, kubectl/Minikube, Python venv. Bandit and pip-audit are installed into `.venv` by the pipeline. Gitleaks and Trivy are used if installed,
otherwise their official Docker images are used. OWASP Dependency-Check is **optional** (Docker, slow first run).

## 3. Architecture / gates
Checkout -> deps -> **Bandit (SAST)** -> **Gitleaks (secrets)** -> **pip-audit** (+optional Dependency-Check) -> Docker build -> **Trivy image** ->
**Policy validation** (`security/validate_policy.py`) -> tests -> deploy. Thresholds: `BANDIT_FAIL_LEVEL`, `TRIVY_SEVERITY`. Reports in `reports/` (archived by Jenkins), summary in `reports/security-summary.md`.
Hardening in the project: non-root UID 10001, slim base, read-only root FS, dropped capabilities, no privilege escalation, resource limits, probes, NetworkPolicy, PodSecurity `restricted`, no secrets in Git.

## 4. Implementation procedure
Job `PBL3-VLE9-DEVSECOPS` (`jenkins/Jenkinsfile-vle9`). Run 1: `DEMO_FAIL_GATE=true` (fails at Bandit/Gitleaks, nothing deployed). Run 2: `DEMO_FAIL_GATE=false` (remediated; all gates pass, deploys).
The fixture (`security/fixtures/insecure_sample.py.fixture`) holds a random fake password and weak-hash/shell-injection patterns; it is copied into `app/` only for the demo run and removed afterwards; it is never part of the deployed image.

## 5. Exact commands
```bash
./scripts/install-deps.sh all
./scripts/security-scan.sh bandit      # exit 0 clean
./scripts/security-scan.sh gitleaks
./scripts/security-scan.sh deps
./scripts/build.sh vle7 && ./scripts/security-scan.sh trivy-image
./scripts/security-scan.sh policy
./scripts/security-scan.sh report && cat reports/security-summary.md

./scripts/security-demo.sh inject && ./scripts/security-scan.sh bandit; ./scripts/security-scan.sh gitleaks   # both FAIL
./scripts/security-demo.sh remove && ./scripts/security-scan.sh bandit && ./scripts/security-scan.sh gitleaks # PASS again
```

## 6. Expected output (typical)
Clean: Bandit `No issues identified`, Gitleaks `no leaks found`, pip-audit `No known vulnerabilities found`, policy `0 failed`.
Demo: Bandit lists B324 (md5) and B602 (shell=True) as HIGH; Gitleaks reports a generic secret; stage fails, deployment stage is skipped.

## 7. Verification
Failed run has no `Secure Deployment` stage executed; passed run deploys and `verify.sh vle7-http` succeeds. Trivy report in `reports/trivy-image.txt`.

## 8. Screenshots to capture
Failed gate stage view + console; Bandit/Gitleaks report; Trivy report; green run; `security-summary.md`.

## 9. Result
Security is enforced at every stage; insecure code is blocked before build/deploy.

## 10. Common errors and fixes
Trivy/Gitleaks not installed (Docker fallback needs a running daemon); Trivy DB download blocked (retry/online); new CVE in base image (rebuild, pin newer base, or justified `.trivyignore`).
