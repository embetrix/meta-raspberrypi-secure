pipeline {
    agent { dockerfile true }

    parameters {
        gitParameter branchFilter: 'origin/(.*)', defaultValue: 'scarthgap', selectedValue: 'DEFAULT', name: 'BRANCH', type: 'PT_BRANCH', description: 'branch to build'
        choice choices: ['raspberrypi5', 'raspberrypi4-64' ], description: 'select machine', name: 'MACHINE'
        choice choices: ['core-image-minimal'], description: 'select image', name: 'IMAGE'
        choice choices: ['no', 'yes'], description: 'clean workspace', name: 'CLEAN'
    }

    stages {

        stage('Setup') {
            steps {
                sh "git describe --tags --always --dirty"
            }
        }

        stage('Clean') {
            when {
                expression { params.CLEAN == 'yes' }
            }
            steps {
               sh "git clean -fdx"
            }
        }

        stage('Build-Image') {
            steps {
                sh "KAS_MACHINE=${params.MACHINE} KAS_TARGET=${params.IMAGE} kas build --force-checkout --update kas-rpi-secure.yml"
                archiveArtifacts artifacts: "build/tmp/deploy/images/${params.MACHINE}/${params.IMAGE}-*.wic*" ,
                                             followSymlinks: true,
                                             fingerprint: true,
                                             onlyIfSuccessful: true
            }
        }

    }
}
