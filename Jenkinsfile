// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright 2026 Embetrix Embedded Systems Solutions <ayoub.zaki@embetrix.com>
// Jenkinsfile for building Raspberry Pi secure images with KAS and Yocto
pipeline {
    agent { dockerfile true }

    parameters {
        gitParameter branchFilter: 'origin/(.*)', defaultValue: 'scarthgap', selectedValue: 'DEFAULT', name: 'BRANCH', type: 'PT_BRANCH', description: 'branch to build'
        choice choices: ['raspberrypi5', 'raspberrypi4-64' ], description: 'select machine', name: 'MACHINE'
        choice choices: ['rpi-secure-image-base'], description: 'select image', name: 'IMAGE'
        choice choices: ['dev', 'prod'], description: 'select security profile', name: 'SECURITY_PROFILE'
        choice choices: ['no', 'yes'], description: 'clean workspace', name: 'CLEAN'
    }
    environment {
        SECURITY_PROFILE = "${params.SECURITY_PROFILE}"
    }

    stages {

        stage('Setup') {
            steps {
                script {
                    def keyDir = "${env.WORKSPACE}/rpi-secure-keys"
                    def kasFragment = "kas-signing-keys.yml"
                    withCredentials([file(credentialsId: 'fd6cfa4d-679d-4d04-9e6a-74073de43385', variable: 'KEYS_TARBALL')]) {
                        sh "tar xzf \$KEYS_TARBALL -C ${env.WORKSPACE}"
                    }
                    sh "scripts/genkey-helper.sh ${keyDir} ${kasFragment}"
                }
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
                script {
                    def kasConfig = "kas-rpi-secure.yml:kas-signing-keys.yml"

                    sh "KAS_MACHINE=${params.MACHINE} KAS_TARGET=${params.IMAGE} SECURITY_PROFILE=${params.SECURITY_PROFILE} kas build --force-checkout --update ${kasConfig}"
                }
                archiveArtifacts artifacts: "build/tmp/deploy/images/${params.MACHINE}/${params.IMAGE}-*," +
                                             "build/tmp/deploy/images/${params.MACHINE}/boot.img," +
                                             "build/tmp/deploy/images/${params.MACHINE}/boot.sig",
                                             excludes: "**/*.ext3,**/*.ext4,**/*.rootfs.wic",
                                             followSymlinks: false,
                                             fingerprint: true,
                                             onlyIfSuccessful: true
            }
        }

    }
}
