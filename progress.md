# Project progress (PBL-III healthcare-devsecops-pbl3)
Last updated: 2026-11-11

## Completed
- [x] Flask healthcare app (dashboard, registration, records, stats, /health, /api/status, version + blue/green indicator), env-driven config
- [x] 16 pytest tests; Dockerfile (non-root UID 10001, slim, healthcheck), docker-compose, .dockerignore/.gitignore/.gitattributes/.trivyignore
- [x] Kubernetes: Kustomize base (common, vle7, blue, green) + overlays local/aws (image pull policy, pull secret, ENVIRONMENT differ only)
- [x] Scripts (bash): setup, build, deploy, verify, blue-green-switch, rollback, cleanup, security-scan, security-demo, install-deps; PowerShell: setup.ps1, deploy.ps1
- [x] Jenkins: Jenkinsfile-vle7/8/9, root sanity Jenkinsfile, shared/common.groovy (local|aws, credentials only for aws)
- [x] DevSecOps: Bandit, Gitleaks, pip-audit, Trivy (image/fs), optional OWASP Dependency-Check, policy-as-code, report generator, safe failing-gate fixture
- [x] Docs: README, VLE7/8/9 guides, Jenkins/GitHub/AWS/env-vars/troubleshooting, FACULTY_DEMO_GUIDE, VIVA_QUESTIONS, LOCAL_TO_AWS_MIGRATION

## Validation actually executed (build environment)
- PASS pytest 16/16; Flask+gunicorn startup (/health, /api/status, dashboard)
- PASS Bandit clean; Gitleaks 8.21.2 clean; pip-audit clean (0 vulnerable pins); policy validation 43/43
- PASS demo fixture: Bandit exit 1 (B324, B602 HIGH) and Gitleaks exit 1; both exit 0 again after removal
- PASS kustomize v5.4.3 renders all 8 overlays (local/aws x common/vle7/blue/green); image/namespace/pull-policy substitution checked
- PASS YAML parse, `bash -n` on all scripts, bracket balance for Jenkinsfiles/PowerShell, referenced-file check, no credential patterns

## NOT executed (no Docker/kubectl/Minikube/Jenkins/pwsh available in the build environment)
- docker build, image validation, Trivy image scan, Minikube deploy, port-forward checks, real Blue-Green switch
- Jenkins execution and Groovy parsing; PowerShell execution; any AWS step
=> Run the local checklist at the end of docs/LOCAL_TO_AWS_MIGRATION.md before relying on or migrating anything.

## Next steps for you
1. `python scripts/validate_project.py` and `make test` on your machine
2. Push to GitHub (docs/GITHUB_SETUP.md), create 3 Jenkins jobs (docs/JENKINS_SETUP.md)
3. Run VLE7 -> VLE8 -> VLE9 locally; capture screenshots; only then consider AWS
