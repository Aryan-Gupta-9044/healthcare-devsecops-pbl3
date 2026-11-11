# VLE 7 - CI/CD Pipeline to Deploy a Dockerized Application on Kubernetes using Jenkins

## 1. Objective
Automate checkout -> test -> Docker build -> Kubernetes deploy -> verification of the Healthcare Patient Management app with Jenkins.

## 2. Required software
Docker, Minikube (or Docker Desktop Kubernetes), kubectl, Jenkins, Python 3 + venv, Git.

## 3. Architecture
GitHub -> Jenkins (`jenkins/Jenkinsfile-vle7`) -> `docker build` -> `minikube image load` -> `kubectl apply` of Kustomize overlay
`kubernetes/overlays/local/vle7` (Deployment `healthcare-cicd` x2 + NodePort Service `healthcare-cicd-service`, probes, limits, non-root).

## 4. Implementation procedure
1. Start the cluster: `minikube start --cpus=2 --memory=2048 --cni=calico`
2. Create job `PBL3-VLE7-CICD` (script path `jenkins/Jenkinsfile-vle7`, see JENKINS_SETUP.md).
3. Build with Parameters: `DEPLOY_ENV=local`, `K8S_NAMESPACE=healthcare`, `DOCKER_IMAGE=healthcare-app`, `DOCKER_IMAGE_TAG=1.0.0`.

## 5. Exact commands
Without Jenkins (same scripts the pipeline calls):
```bash
./scripts/install-deps.sh test && .venv/bin/python -m pytest tests -v
./scripts/build.sh vle7 && ./scripts/deploy.sh vle7
./scripts/verify.sh vle7-k8s && ./scripts/verify.sh vle7-http
kubectl get deployments -n healthcare
kubectl get pods -n healthcare
kubectl get services -n healthcare
minikube service healthcare-cicd-service -n healthcare
```
Windows PowerShell: `.\scripts\setup.ps1 -StartMinikube`.

## 6. Expected output (typical)
- Stages Checkout ... Application Testing all green; JUnit shows 16 tests passed.
- `kubectl get deployments -n healthcare` -> `healthcare-cicd   2/2   2   2`.
- `verify.sh vle7-http` prints `{"status":"healthy"}`, the `/api/status` JSON with `"version":"1.0.0"`, then `OK: dashboard, /health and /api/status respond`.

## 7. Verification
Dashboard shows the patient table, stats and `v1.0.0 - Standard Release`; `/health` returns 200; pods Ready 1/1; image runs as UID 10001.

## 8. Screenshots to capture
Pipeline stage view; `kubectl get deployments,pods,services`; dashboard in browser; `/health`.

## 9. Result
The Dockerized app is built, deployed to Kubernetes and verified automatically on every Jenkins run.

## 10. Common errors and fixes
See TROUBLESHOOTING.md: `ErrImageNeverPull` (load image into Minikube), `docker: permission denied`, kubeconfig access for the Jenkins user.
