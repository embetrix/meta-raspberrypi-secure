// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright 2026 Embetrix Embedded Systems Solutions <ayoub.zaki@embetrix.com>
// Jenkinsfile for building Raspberry Pi secure images with KAS and Yocto
pipeline {
    agent { dockerfile true }

    parameters {
        gitParameter branchFilter: 'origin/(.*)', defaultValue: 'scarthgap', selectedValue: 'DEFAULT', name: 'BRANCH', type: 'PT_BRANCH', description: 'branch to build'
        choice choices: ['raspberrypi5', 'raspberrypi4-64' ], description: 'select machine', name: 'MACHINE'
        choice choices: ['rpi-secure-image'], description: 'select image', name: 'IMAGE'
        choice choices: ['dev', 'prod'], description: 'select security profile', name: 'SECURITY_PROFILE'
        choice choices: ['no', 'yes'], description: 'clean workspace', name: 'CLEAN'
    }
    environment {
        SECURITY_PROFILE = "${params.SECURITY_PROFILE}"
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
                sh "KAS_MACHINE=${params.MACHINE} KAS_TARGET=${params.IMAGE} SECURITY_PROFILE=${params.SECURITY_PROFILE} kas build --force-checkout --update kas-rpi-secure.yml"
                archiveArtifacts artifacts: "build/tmp/deploy/images/${params.MACHINE}/${params.IMAGE}-*" ,
                                             followSymlinks: false,
                                             fingerprint: true,
                                             onlyIfSuccessful: true
            }
        }

    }
}
