#!/bin/bash

# Fail the script if any command returns a non-zero value
set -e

# Slurp in some functions...
source /usr/share/misc/func.bash
source /usr/share/misc/aws-func.bash

# Slurp on AWS settings
source $MY_AWS_SETTINGS

#
# Usage function
function usage {
    echo "Usage: $0 --manifest=/path/to/infra-manifest.json [--template=/path/to/openshift-cloudformation.yml.sempl]"
}

# Set defaults
TEMPLATE=/usr/share/misc/openshift-cloudformation.yml.sempl

for i in "$@"; do
    case $i in
        -m=*|--manifest=*)
        MANIFEST="${i#*=}"
        shift # past argument=value
        ;;
        -t=*|--template=*)
        TEMPLATE="${i#*=}"
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

if [ -z "$TEMPLATE" -o ! -f "$TEMPLATE" ]; then
    log ERROR "You need to specify a valid path to the Cloudformation openshift template."
    log WARN "$(usage)"
    log WARN "Exit process with error code 101."
    exit 101
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
# Get machine sizing
for machine in master infra worker; do
    declare -x ${machine}_node_count=$(getAwsInstanceCount "$MANIFEST_JSON" openshift-${machine})
    declare -x ${machine}_node_type=$(getAwsInstanceType "$MANIFEST_JSON" openshift-${machine})
    declare -x ${machine}_node_data_volume_size=$(getAwsInstanceDataVolumeSize "$MANIFEST_JSON" openshift-${machine})
    declare -x ${machine}_node_log_volume_size=$(getAwsInstanceLogVolumeSize "$MANIFEST_JSON" openshift-${machine})
done

#
# Merge into template (for number of machines)
log "Merging infra manifest settings into OpenShift Cloudformation template..."
sempl -o /usr/share/misc/openshift-cloudformation.yml.sempl > openshift-cloudformation.yml

#
# Create the OpenShift infra stack
log "Creating Cloudformation stack $MY_OC_CLUSTER-openshift in $MY_AWS_ZONE"
# aws cloudformation create-stack \
#  --region $MY_AWS_ZONE \
#  --stack-name $MY_OC_CLUSTER-openshift \
#  --template-body file://openshift-cloudformation.yml \
#  --parameters \
#    ParameterKey=AvailabilityZone,ParameterValue=${MY_AWS_ZONE} \
#    ParameterKey=KeyName,ParameterValue=$MY_PEM_KEY_NAME \
#    ParameterKey=ClusterName,ParameterValue=$MY_OC_CLUSTER  \
#    ParameterKey=OpenshiftMasterInstanceType,ParameterValue=$master_node_type \
#    ParameterKey=OpenshiftInfraInstanceType,ParameterValue=$infra_node_type \
#    ParameterKey=OpenshiftWorkerInstanceType,ParameterValue=$worker_node_type \
#    ParameterKey=OpenshiftMasterDataVolumeSize,ParameterValue=$master_node_data_volume_size \
#    ParameterKey=OpenshiftInfraDataVolumeSize,ParameterValue=$infra_node_data_volume_size \
#    ParameterKey=OpenshiftWorkerDataVolumeSize,ParameterValue=$worker_node_data_volume_size \
#    ParameterKey=OpenshiftMasterDaLogVolumeSize,ParameterValue=$master_node_log_volume_size \
#    ParameterKey=OpenshiftInfraDaLogVolumeSize,ParameterValue=$infra_node_log_volume_size \
#    ParameterKey=OpenshiftWorkerDaLogVolumeSize,ParameterValue=$worker_node_log_volume_size \
#  --capabilities CAPABILITY_IAM

# waitForStackCreate $MY_OC_CLUSTER-openshift