# Troubleshooting
| Symptom | Cause | Fix |
|---|---|---|
| `ErrImageNeverPull` / `ImagePullBackOff` (local) | Image not inside the cluster | `minikube image load healthcare-app:1.0.0` (build.sh does this) and check `minikube image ls | grep healthcare` |
| `ImagePullBackOff` (aws) | Repo private / wrong name | Set `DOCKER_IMAGE=<user>/healthcare-app`, supply `dockerhub-creds`, push succeeded? |
| Jenkins: `docker: permission denied` | Jenkins user not in docker group | `sudo usermod -aG docker jenkins` and restart Jenkins |
| Jenkins: `kubectl ... connection refused` / cert errors | Jenkins user lacks kubeconfig/certs | flattened kubeconfig, see JENKINS_SETUP.md |
| `python3 -m venv` fails | missing package | `sudo apt install python3-venv` |
| Pod rejected by PodSecurity | Namespace enforces `restricted` | Manifests already comply; check you did not remove `securityContext` |
| NetworkPolicy has no effect | CNI does not enforce | `minikube start --cni=calico` (recreate profile) |
| Switch refused: "no ready replicas" | Green not deployed/healthy | `kubectl -n healthcare get pods`, `describe pod`, `logs` |
| Browser still shows Blue after switch | Browser tab/keep-alive | hard refresh; the page sets `Cache-Control: no-store`; check `/api/status` |
| Rebuilt same tag but pods unchanged | `apply` sees no spec change | rerun with `FORCE_RESTART=true` or bump the tag |
| Trivy/Gitleaks "not installed" | Tool missing, no Docker | install them or ensure Docker works (fallback uses images) |
| Trivy DB download fails | no internet / rate limit | retry; or `TRIVY_SEVERITY` unaffected; cache volume `trivy-cache` |
| Trivy fails on an unfixable CVE | base-image issue | `ignore-unfixed` is on; otherwise add to `.trivyignore` with justification |
| `minikube service` hangs on Docker driver (Windows/macOS) | tunnel needed | keep the terminal open, or `kubectl -n healthcare port-forward svc/healthcare-service 8081:80` |
| Port-forward check flaky | port clash | rerun; ports are random 20000-39999 |
