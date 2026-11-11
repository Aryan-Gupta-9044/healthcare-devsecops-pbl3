// Repository sanity pipeline (optional 4th job): static validation + unit tests, no cluster needed.
pipeline {
    agent any
    options { timestamps(); timeout(time: 15, unit: 'MINUTES') }
    stages {
        stage('Checkout') { steps { checkout scm } }
        stage('Install') { steps { sh 'chmod +x scripts/*.sh && scripts/install-deps.sh all' } }
        stage('Validate project') { steps { sh '. .venv/bin/activate && python scripts/validate_project.py' } }
        stage('Unit tests') {
            steps { sh '. .venv/bin/activate && python -m pytest tests -v --junitxml=reports/junit.xml' }
            post { always { junit allowEmptyResults: true, testResults: 'reports/junit.xml' } }
        }
    }
}
