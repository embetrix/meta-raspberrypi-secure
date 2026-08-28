#!/bin/bash -ex
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 Embetrix Embedded Systems Solutions <ayoub.zaki@embetrix.com>
#
# deploy a .swu file to hawkbit server
# Usage: ./deploy-swu-hawkbit.sh <path-to-swu-file> <hawkbit-url> <hawkbit-username> <hawkbit-password>
#
SWU_FILE=$1
HAWKBIT_URL=$2
HAWKBIT_USERNAME=$3
HAWKBIT_PASSWORD=$4

if [ ! -f "$SWU_FILE" ]; then
    echo "ERROR: SWU file not found: $SWU_FILE" >&2
    exit 1
fi

VENDOR="embetrix"

PREFIX=$(basename $SWU_FILE | awk -F _ '{ print $1 }')
VERSION=$(basename $SWU_FILE | awk -F _ '{ print $2 }' | awk -F .swu '{ print $1 }')
DATE=$(date "+%Y-%m-%d-%H-%M-%S")

RESPONSE=$(curl -s -w '\n%{http_code}' "$HAWKBIT_URL/rest/v1/softwaremodules" -X POST -u "$HAWKBIT_USERNAME:$HAWKBIT_PASSWORD" \
		-H 'Content-Type: application/hal+json;charset=UTF-8' \
		-d '[ {
	            "vendor" : "'${VENDOR}'",
	            "name" : "'${PREFIX}'",
	            "description" : "'${PREFIX}'",
	            "type" : "os",
	            "version" : "'${VERSION}'"
		    }]')
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -lt 200 ] || [ "$HTTP_CODE" -ge 300 ]; then
    echo "ERROR: softwaremodules POST failed with HTTP $HTTP_CODE" >&2
    echo "$BODY" >&2
    exit 1
fi

id=$(echo "$BODY" | jq -e '.[] | .id')
if [ -z "$id" ]; then
    echo "ERROR: could not parse software module id from response:" >&2
    echo "$BODY" >&2
    exit 1
fi

curl -s "$HAWKBIT_URL/rest/v1/softwaremodules" -i -X GET -u "$HAWKBIT_USERNAME:$HAWKBIT_PASSWORD"

curl -s "$HAWKBIT_URL/rest/v1/softwaremodules/${id}/artifacts" -i -X POST -u "$HAWKBIT_USERNAME:$HAWKBIT_PASSWORD" \
		-H 'Content-Type: multipart/form-data' \
		-F 'file=@'${SWU_FILE}''

curl -s "$HAWKBIT_URL/rest/v1/distributionsets/" -i -X POST -u "$HAWKBIT_USERNAME:$HAWKBIT_PASSWORD" \
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
