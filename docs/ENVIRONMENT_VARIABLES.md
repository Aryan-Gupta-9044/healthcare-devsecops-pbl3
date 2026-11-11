# Environment variables and credentials

Nothing here is stored in the repository. Pipeline parameters are exported to scripts as environment variables automatically.

## A. Mandatory local configuration (all have defaults - override only if needed)
| Variable | Purpose | Required | Example | Configured in |
|---|---|---|---|---|
| `DEPLOY_ENV` | `local` or `aws` overlay/behaviour | optional (default `local`) | `local` | Jenkins parameter / shell |
| `K8S_NAMESPACE` | Target namespace | optional (`healthcare`) | `healthcare` | Jenkins parameter / shell |
| `K8S_CONTEXT` | kubectl context (empty = current) | optional | `minikube` | Jenkins parameter / shell |
| `DOCKER_IMAGE` | Image repository | optional (`healthcare-app`) | `healthcare-app` | Jenkins parameter / shell |
| `DOCKER_IMAGE_TAG` | VLE 7/9 image tag = app version | optional (`1.0.0`) | `1.0.0` | Jenkins parameter / shell |
| `BLUE_VERSION` / `GREEN_VERSION` | VLE 8 versions (tags `X-blue`, `X-green`) | optional (`1.0.0` / `2.0.0`) | `2.0.0` | Jenkins parameter / shell |
| `GITHUB_REPO_URL` | Repo the Jenkins job pulls | required (Jenkins job config) | `https://github.com/<you>/healthcare-devsecops-pbl3.git` | Jenkins job "Repository URL" |
| `GITHUB_BRANCH` | Branch to build | required (Jenkins job config) | `*/main` | Jenkins job "Branch Specifier" |
| `JENKINS_AGENT_LABEL` | Agent that has docker/kubectl | optional (`built-in`) | `built-in` | Jenkins parameter |
| `MINIKUBE_PROFILE` | Minikube profile used for image loading | optional (`minikube`) | `minikube` | shell / agent env |
| `SERVICE_NAME` | Blue-Green Service name | optional (`healthcare-service`) | `healthcare-service` | shell |
| `FORCE_RESTART` | `true` = `rollout restart` after apply (same tag rebuilt) | optional | `true` | shell |
| `JENKINS_URL` | Used by `setup.sh` connectivity check | optional | `http://localhost:8080` | shell |
| `APPROVAL_REQUIRED` | Manual approval before switching to Green (VLE 8) | optional (`true`) | `true` | Jenkins parameter |
| `AUTO_ROLLBACK` | Restore Blue if post-switch verification fails | optional (`true`) | `true` | Jenkins parameter |
| `ENABLE_SECURITY_SCAN` | Turn VLE 9 gates on/off | optional (`true`) | `true` | Jenkins parameter |
| `DEMO_FAIL_GATE` | Inject safe fixture to show a failing gate | optional (`false`) | `true` | Jenkins parameter |
| `BANDIT_FAIL_LEVEL` | Lowest Bandit severity that fails | optional (`HIGH`) | `MEDIUM` | Jenkins parameter / shell |
| `TRIVY_SEVERITY` | Trivy severities that fail | optional (`HIGH,CRITICAL`) | `HIGH,CRITICAL` | Jenkins parameter / shell |
| `PIP_AUDIT_FAIL` | Fail on vulnerable Python dependency | optional (`true`) | `true` | shell |
| `ENABLE_DEPCHECK` | Run optional OWASP Dependency-Check | optional (`false`) | `false` | Jenkins parameter |
| `DEPLOY_AFTER_SCAN` | Deploy after gates pass (VLE 9) | optional (`true`) | `true` | Jenkins parameter |
| `GITLEAKS_IMAGE`, `TRIVY_IMAGE` | Docker fallback images when tools are not installed | optional | `aquasec/trivy:<pinned>` | shell |

### Application runtime variables (baked/injected; no code change between environments)
| Variable | Purpose | Default | Set by |
|---|---|---|---|
| `APP_VERSION` | Version shown in UI/API | `1.0.0` | Docker build arg (Dockerfile ENV) |
| `DEPLOYMENT_COLOR` | `blue` / `green` / `standard` | `standard` | Docker build arg |
| `RELEASE_LABEL` | Release label text | derived from colour | optional override |
| `ENVIRONMENT` | `local` / `aws` (display only) | `local` | ConfigMap via overlay |
| `APP_HOST`, `APP_PORT`, `APP_NAME` | Bind address/port/title | `0.0.0.0`/`8080` in image | ConfigMap / Dockerfile |
| `SECRET_KEY` | Optional app secret | empty | Kubernetes Secret `healthcare-secrets` (optional ref) or local env |

## B. Optional Docker Hub configuration (needed for `DEPLOY_ENV=aws`, not for local)
| Variable | Purpose | Required | Placeholder | Configured in |
|---|---|---|---|---|
| `DOCKERHUB_USERNAME` | Registry login | only for aws/private pushes | `<dockerhub-user>` | Jenkins credential `dockerhub-creds` (never in Git) |
| `DOCKERHUB_TOKEN` | Docker Hub access token (not your password) | only for aws/private pushes | `<access-token>` | same credential (password field) |

## C. Optional AWS configuration
This project does **not** call AWS APIs: the AWS path is a plain EC2 host running k3s, reached with SSH and a kubeconfig. So these are
**not required** by any script or pipeline:
`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_DEFAULT_REGION`, `AWS_SESSION_TOKEN` (only if your credential type supplies one).
Use them only on your own workstation if you manage EC2 with the AWS CLI (see `AWS_OPTIONAL_SETUP.md`). Never put them in the repo or Jenkinsfiles.

## D. Jenkins credential IDs
| ID | Kind | Used when | Contents |
|---|---|---|---|
| `dockerhub-creds` | Username with password | `DEPLOY_ENV=aws` | Docker Hub user + access token |
| `kubeconfig-aws` | Secret file | `DEPLOY_ENV=aws` | kubeconfig of the EC2 k3s cluster |
| `github-creds` | Username with password (PAT) | only if the GitHub repo is private | GitHub user + PAT with `repo` read |
| `nvd-api-key` | Secret text | optional, Dependency-Check | NVD API key (not wired by default; export `NVD_API_KEY` in the agent if used) |

**Local runs need no Jenkins credentials** (public GitHub repo, Minikube image loading).
