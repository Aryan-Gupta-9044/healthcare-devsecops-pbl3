// Shared helpers loaded by all three pipelines:  common = load 'jenkins/shared/common.groovy'
// Pipeline parameters are exported to sh steps as environment variables, so scripts/*.sh see
// DEPLOY_ENV, K8S_CONTEXT, K8S_NAMESPACE, DOCKER_IMAGE, DOCKER_IMAGE_TAG ... without extra wiring.

def banner(String msg) {
    echo "=" * 70 + "\n  ${msg}\n" + "=" * 70
}

def run(String cmd) {
    sh "set -e; chmod +x scripts/*.sh; ${cmd}"
}

// DEPLOY_ENV=local: use the agent's own kubeconfig/Docker (Minikube). No credentials needed.
// DEPLOY_ENV=aws  : bind Jenkins credentials (never stored in Git):
//   kubeconfig-aws  (Secret file)                 -> KUBECONFIG
//   dockerhub-creds (Username with password)      -> DOCKERHUB_USERNAME / DOCKERHUB_TOKEN
def withTarget(Closure body) {
    if (env.DEPLOY_ENV == 'aws') {
        def creds = [file(credentialsId: 'kubeconfig-aws', variable: 'KUBECONFIG'),
                     usernamePassword(credentialsId: 'dockerhub-creds',
                                      usernameVariable: 'DOCKERHUB_USERNAME',
                                      passwordVariable: 'DOCKERHUB_TOKEN')]
        withCredentials(creds) { body() }
    } else {
        body()
    }
}

def tests() {
    run('scripts/install-deps.sh test')
    sh '. .venv/bin/activate && python -m pytest tests -v --junitxml=reports/junit.xml'
}

return this
