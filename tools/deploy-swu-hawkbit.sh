#!/bin/bash -e
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 Embetrix Embedded Systems Solutions <ayoub.zaki@embetrix.com>
#
# deploy a .swu file to hawkbit server
# Usage: ./deploy-swu-hawkbit.sh <path-to-swu-file> <hawkbit-url> <hawkbit-username> <hawkbit-password>
#
IMG_FILE=$1
HAWKBIT_URL=$2
HAWKBIT_USERNAME=$3
HAWKBIT_PASSWORD=$4

VENDOR="embetrix"

PREFIX=$(basename $IMG_FILE | awk -F _ '{ print $1 }')
VERSION=$(basename $IMG_FILE | awk -F _ '{ print $2 }' | awk -F .swu '{ print $1 }')
DATE=$(date "+%Y-%m-%d-%H-%M-%S")

id=$(curl -s "$HAWKBIT_URL/rest/v1/softwaremodules"  -X POST -u $HAWKBIT_USERNAME:$HAWKBIT_PASSWORD \
		-H 'Content-Type: application/hal+json;charset=UTF-8' \
		-d '[ {
	            "vendor" : "'${VENDOR}'",
	            "name" : "'${PREFIX}'",
	            "description" : "'${PREFIX}'",
	            "type" : "os",
	            "version" : "'${VERSION}'"
		    }]' |  jq '.[] | .id')

curl -s "$HAWKBIT_URL/rest/v1/softwaremodules" -i -X GET -u $HAWKBIT_USERNAME:$HAWKBIT_PASSWORD

curl -s "$HAWKBIT_URL/rest/v1/softwaremodules/${id}/artifacts" -i -X POST -u $HAWKBIT_USERNAME:$HAWKBIT_PASSWORD \
		-H 'Content-Type: multipart/form-data' \
		-F 'file=@'${IMG_FILE}''

curl -s "$HAWKBIT_URL/rest/v1/distributionsets/" -i -X POST -u $HAWKBIT_USERNAME:$HAWKBIT_PASSWORD \
            -H 'Content-Type: application/json;charset=UTF-8' \
            -d '[ {
                    "requiredMigrationStep" : false,
                    "name" : "'${PREFIX}'",
                    "description" : "'${PREFIX}'",
                    "type" : "os",
                    "version" : "'${VERSION}'",
                    "modules" : [ {
                    "id" : '${id}'
                    }]
                }]'

echo -n "\n\n\n\nOK\n"
