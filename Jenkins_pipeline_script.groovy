pipeline {
    agent any

    stages {
        stage('Checkout') {
            steps {
                git branch: 'main', url: "https://github.com/41Mo/jenkinsansiblebook.git"
            }
        }
        stage('Deploy') {
            steps {
                ansiblePlaybook become: true, colorized: true, credentialsId: 'key', disableHostKeyChecking: true, inventory: 'inventory.yaml', playbook: 'playbook.yaml', tags: 'lamp'
            }
        }
    }
}
