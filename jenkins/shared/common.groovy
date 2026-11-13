// Shared helpers loaded by all three pipelines.

def banner(String msg) {
    echo "=" * 70 + "\n  ${msg}\n" + "=" * 70
}

def run(String cmd) {
    sh "set -e; chmod +x scripts/*.sh; ${cmd}"
}

def withTarget(Closure body) {
    if (env.DEPLOY_ENV == 'aws') {
        def creds = [
            file(credentialsId: 'kubeconfig-aws', variable: 'KUBECONFIG'),
            usernamePassword(
                credentialsId: 'dockerhub-creds',
                usernameVariable: 'DOCKERHUB_USERNAME',
                passwordVariable: 'DOCKERHUB_TOKEN'
            )
        ]
        withCredentials(creds) { body() }
    } else {
        withEnv(['KUBECONFIG=/var/jenkins_home/.kube/config']) {
            body()
        }
    }
}

def tests() {
    run('scripts/install-deps.sh test')
    sh '. .venv/bin/activate && python -m pytest tests -v --junitxml=reports/junit.xml'
}

return this
