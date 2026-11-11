# Jenkins setup (local)

## Recommended topology
Jenkins on the **same machine** as Docker and Minikube (Ubuntu, or Windows with WSL2 + Docker Desktop WSL integration).
Tools needed on the agent: `docker`, `kubectl`, `minikube`, `python3` + `python3-venv`, `curl`, `git`. Optional: `trivy`, `gitleaks` (Docker fallback is used otherwise).

```bash
# Ubuntu example: start Minikube with a NetworkPolicy-capable CNI and low resources
minikube start --cpus=2 --memory=2048 --cni=calico
# simplest reliable way to run Jenkins for a lab: as YOUR user so it can reach docker + ~/.kube + ~/.minikube
java -jar jenkins.war --httpPort=8080
```
If Jenkins runs as the `jenkins` service user instead: `sudo usermod -aG docker jenkins`, then give it a self-contained kubeconfig:
`sudo mkdir -p /var/lib/jenkins/.kube && kubectl config view --flatten --minify | sudo tee /var/lib/jenkins/.kube/config >/dev/null && sudo chown -R jenkins: /var/lib/jenkins/.kube`
(`minikube image load` also needs access to the Minikube profile - running Jenkins as your own user avoids this.)
Jenkins-in-Docker is possible (mount `/var/run/docker.sock`, install kubectl/minikube) but needs extra network wiring to Minikube; not recommended for the demo.

## Plugins
Pipeline, Git, Credentials Binding, Timestamper, JUnit (all standard in "Install suggested plugins").

## Create the three pipeline jobs (Dashboard)
For each row: **New Item -> name -> Pipeline -> OK**, then under *Pipeline*: Definition = **Pipeline script from SCM**, SCM = **Git**,
Repository URL = `GITHUB_REPO_URL`, Credentials = none (public) or `github-creds`, Branch = `*/main`, **Script Path** as below, Save.
| Job name | Script Path |
|---|---|
| `PBL3-VLE7-CICD` | `jenkins/Jenkinsfile-vle7` |
| `PBL3-VLE8-BLUE-GREEN` | `jenkins/Jenkinsfile-vle8` |
| `PBL3-VLE9-DEVSECOPS` | `jenkins/Jenkinsfile-vle9` |
| *(optional)* `PBL3-SANITY` | `Jenkinsfile` |

The first build of each job only registers its parameters (you may see defaults used); use **Build with Parameters** afterwards.

## Credentials (only for DEPLOY_ENV=aws)
Manage Jenkins -> Credentials -> Global -> Add: `dockerhub-creds` (Username with password), `kubeconfig-aws` (Secret file). Details: `ENVIRONMENT_VARIABLES.md`.
