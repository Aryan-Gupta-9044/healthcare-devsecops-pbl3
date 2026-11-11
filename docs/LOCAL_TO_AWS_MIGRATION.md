# Local -> AWS migration guide

> **Gate:** do not start until the local checklist at the bottom is ticked. The local run was designed and statically validated in the build
> environment (no Docker/Kubernetes available there), so you must confirm it on your machine first. The AWS steps below have NOT been executed by the author.

## 1. Design: what stays the same
Application code, Dockerfile, image naming/versioning (`<repo>:<version>[-color]`), Kubernetes base manifests, the Blue-Green logic (`blue-green-switch.sh`,
`rollback.sh`, `verify.sh`), the three Jenkinsfiles and all DevSecOps checks are identical. Nothing is hardcoded to `localhost` or a Minikube IP;
verification uses `kubectl port-forward`, so it works on any cluster.

## 2. What changes (complete list)
| Area | Local | AWS | Where |
|---|---|---|---|
| Overlay | `kubernetes/overlays/local/*` | `kubernetes/overlays/aws/*` | `DEPLOY_ENV` param |
| Image delivery | `minikube image load`, `imagePullPolicy: Never` | push to Docker Hub, `imagePullPolicy: Always`, `imagePullSecrets: regcred` | `lib.sh load_image`, overlay `_env` |
| Image name | `healthcare-app` | `<dockerhub-user>/healthcare-app` | `DOCKER_IMAGE` param |
| Cluster | Minikube | k3s on one EC2 instance | `kubeconfig-aws` credential |
| Credentials | none | `dockerhub-creds`, `kubeconfig-aws` | Jenkins |
| ConfigMap `ENVIRONMENT` | `local` | `aws` | overlay patch |

## 3. Prepare the registry
1. Docker Hub -> create repository `healthcare-app` (public is simplest; private also works via `regcred`).
2. Account settings -> Security -> New Access Token (Read & Write). Keep it secret.

## 4. Launch the EC2 host (manual, console)
Ubuntu 22.04/24.04, `t3.small`, 20 GiB gp3, security group per `AWS_OPTIONAL_SETUP.md`, key pair of your own.

## 5. Install k3s (single node)
```bash
ssh -i key.pem ubuntu@<EC2_PUBLIC_IP>
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --disable traefik --write-kubeconfig-mode 644 --tls-san <EC2_PUBLIC_IP>" sh -
sudo k3s kubectl get nodes          # Ready
sudo cat /etc/rancher/k3s/k3s.yaml  # copy to your workstation
```
On your workstation save it as `kubeconfig-aws.yaml` (outside the repo) and change `server: https://127.0.0.1:6443` to `https://<EC2_PUBLIC_IP>:6443`.
Test: `KUBECONFIG=./kubeconfig-aws.yaml kubectl get nodes`. (If the public IP changes after a stop/start, reinstall with the new `--tls-san` or use an Elastic IP and delete it afterwards.)
k3s enforces NetworkPolicy natively and supports the Pod Security labels used here.

## 6. Add Jenkins credentials
- `kubeconfig-aws`: Kind **Secret file**, upload `kubeconfig-aws.yaml`.
- `dockerhub-creds`: Kind **Username with password**: Docker Hub user + access token.

## 7. Run the same pipelines against AWS
Build with Parameters on any of the three jobs:
`DEPLOY_ENV=aws`, `DOCKER_IMAGE=<dockerhub-user>/healthcare-app`, `K8S_NAMESPACE=healthcare`, `K8S_CONTEXT=` (empty -> kubeconfig's default context), same tags/versions as local.
VLE 8 and VLE 9 behave exactly as locally (same approval, switch, rollback, gates). Equivalent CLI:
```bash
export DEPLOY_ENV=aws DOCKER_IMAGE=<dockerhub-user>/healthcare-app KUBECONFIG=./kubeconfig-aws.yaml
export DOCKERHUB_USERNAME=<user> DOCKERHUB_TOKEN=<token>      # shell only, never committed
./scripts/build.sh vle7 && ./scripts/deploy.sh vle7 && ./scripts/verify.sh vle7-http
```

## 8. View the app
`kubectl -n healthcare get svc` -> note the NodePort -> `http://<EC2_PUBLIC_IP>:<NodePort>` (open only to your IP). Or `kubectl -n healthcare port-forward svc/healthcare-service 8081:80`.

## 9. Cleanup (avoid charges)
```bash
./scripts/cleanup.sh --delete-namespace --yes     # with DEPLOY_ENV=aws and KUBECONFIG set
```
Console: terminate the EC2 instance, delete its EBS volume, release any Elastic IP, delete the security group/key pair if unused, revoke the Docker Hub token. Remove `kubeconfig-aws` credential from Jenkins.

## 10. Local verification checklist (tick before AWS)
- [ ] `python scripts/validate_project.py` passes; `pytest` passes
- [ ] VLE 7 job green locally; dashboard reachable
- [ ] VLE 8: Blue live -> approve -> Green live -> rollback to Blue
- [ ] VLE 9: failed gate run, then passing run
- [ ] `git status --ignored` shows no secrets staged
