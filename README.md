# healthcare-devsecops-pbl3
One repository, three Jenkins pipelines for **PBL-III (21IPE333P)**: VLE 7 CI/CD on Kubernetes, VLE 8 Blue-Green deployment, VLE 9 DevSecOps - all around a lightweight
Flask **Healthcare Patient Management System** (fictional data only). Runs locally on Docker + Jenkins + Minikube; AWS is optional (`docs/LOCAL_TO_AWS_MIGRATION.md`).

## Architecture
```
GitHub -> Jenkins (3 jobs) -> scripts/*.sh -> docker build -> [local: minikube image load | aws: registry push]
                                           -> kubectl apply -k overlays/<local|aws>/<vle7|blue|green>
Service healthcare-service (selector version=blue|green) -> healthcare-blue (v1.0.0) / healthcare-green (v2.0.0)
```
Jenkinsfiles are thin; all logic lives in `scripts/` so local, Jenkins and AWS runs are identical.

## Technologies
Python Flask + gunicorn, HTML/CSS/JS, Docker, Kubernetes (Kustomize base + overlays), Jenkins, pytest, Bandit, Gitleaks, Trivy, pip-audit (+optional OWASP Dependency-Check).

## Repository structure
`app/` application - `tests/` pytest - `Dockerfile` (+`docker/`) - `kubernetes/base/{common,vle7,blue,green}` and `kubernetes/overlays/{local,aws}/...` -
`jenkins/` three Jenkinsfiles + `shared/common.groovy` - `security/` policies, configs, safe fixture, validators - `scripts/` bash + PowerShell - `docs/` guides - `screenshots/` - `progress.md`.

## Prerequisites
Docker, kubectl, Minikube, Jenkins, Python 3 (+venv), Git. Details: `docs/JENKINS_SETUP.md`.

## Initial setup and local deployment
```bash
minikube start --cpus=2 --memory=2048 --cni=calico
./scripts/setup.sh                     # checks tools, builds, loads image, deploys VLE7 app, verifies   (Windows: .\scripts\setup.ps1)
docker compose up --build              # optional: run without Kubernetes at http://localhost:8080
python scripts/validate_project.py     # static validation
```
## Jenkins
Create the three jobs as described in `docs/JENKINS_SETUP.md` (script paths `jenkins/Jenkinsfile-vle7|8|9`). Credentials/variables: `docs/ENVIRONMENT_VARIABLES.md`.

## Running each VLE
- **VLE 7:** `make vle7` or job `PBL3-VLE7-CICD` - `docs/VLE7_IMPLEMENTATION.md`
- **VLE 8:** `make blue green` then `make switch` / `make rollback`, or job `PBL3-VLE8-BLUE-GREEN` - `docs/VLE8_IMPLEMENTATION.md`
- **VLE 9:** `make security`, `make demo-fail`, or job `PBL3-VLE9-DEVSECOPS` - `docs/VLE9_IMPLEMENTATION.md`

Also: `docs/FACULTY_DEMO_GUIDE.md`, `docs/VIVA_QUESTIONS.md`, `docs/TROUBLESHOOTING.md`, `docs/GITHUB_SETUP.md`, `docs/AWS_OPTIONAL_SETUP.md`.

## Cleanup
`./scripts/cleanup.sh [--delete-namespace] [--images]` removes only resources labelled `app.kubernetes.io/part-of=healthcare-devsecops-pbl3`.
