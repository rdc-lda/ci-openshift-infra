#!/bin/bash

# Fail the script if any command returns a non-zero value
set -e

# Slurp in some functions...
source /usr/share/misc/func.bash
source /usr/share/misc/aws-func.bash

#
# Usage function
function usage {
    echo "Usage: $0 --manifest=/path/to/infra-manifest.json"
}

for i in "$@"; do
    case $i in
        -m=*|--manifest=*)
        MANIFEST="${i#*=}"
        shift # past argument=value
        ;;
        *)
            # unknown option
        ;;
    esac
done

if [ -z "$MANIFEST" -o ! -f "$MANIFEST" ]; then
    log ERROR "You need to specify a valid path to the infra manifest JSON file."
    log WARN "$(usage)"
    log WARN "Exit process with error code 102."
    exit 102
fi

if [ -z "$AWS_ACCESS_KEY_ID" -o -z "$AWS_SECRET_ACCESS_KEY" ]; then
    log ERROR "AWS Access or Secret keys not found in environment, exit."
    log WARN "Exit process with error code 200."
    exit 200
fi

# Read and verify the manifest
log "Reading and validating infra manifest..."
MANIFEST_JSON=$(cat $MANIFEST)
verifyJSON "$MANIFEST_JSON"

#
# Get basic deployment config
echo MY_AWS_REGION=$(getAwsRegion "$MANIFEST_JSON") | tee -a $MY_AWS_SETTINGS
echo MY_AWS_ZONE=${MY_AWS_REGION}a | tee -a $MY_AWS_SETTINGS
echo MY_OC_CLUSTER=$(getDeploynmentId "$MANIFEST_JSON") | tee -a $MY_AWS_SETTINGS
echo MY_PEM_KEY_NAME=$MY_OC_CLUSTER-$MY_AWS_REGION | tee -a $MY_AWS_SETTINGS
echo MY_PEM_KEY=$INFRA_DIR/aws-keypair.pem | tee -a $MY_AWS_SETTINGS

#
# Generate deployment specific keys
log "Generating PEM keypair with name $MY_PEM_KEY_NAME..."
aws ec2 create-key-pair --key-name $MY_PEM_KEY_NAME \
   --query 'KeyMaterial' --output text > $MY_PEM_KEY && \
   chmod 400 $MY_PEM_KEY

