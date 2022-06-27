#!/bin/bash

# This fetches the data that was filled out in the previous block
# step and outputs the values.

RELEASE_VERSION=$(buildkite-agent meta-data get release-version)
RELEASE_PLATFORM=$(buildkite-agent meta-data get azure-platform)
AZURE_CLOUD=$(buildkite-agent meta-data get azure-cloud)
CONFIRMATION=$(buildkite-agent meta-data get azure-confirmation)
confirm_status=$(buildkite-agent meta-data exists azure-confirmation)
REGION1=$(buildkite-agent meta-data get deploy-region1 --default "fail")
REGION2=$(buildkite-agent meta-data get deploy-region2 --default "fail")

echo "Parameters passed are AZURE_CLOUD=${AZURE_CLOUD}, PLATFORM=${RELEASE_PLATFORM}, VERSION=${RELEASE_VERSION}"  

cd /workdir
if [[ ${REGION1} != "fail" && ${REGION2} != "fail" ]]; then
  CONFIRM_DEPLOYMENT_TYPE=$(buildkite-agent meta-data get deployment-type)
  make promote.two-regions AZURE_CLOUD=${AZURE_CLOUD} PLATFORM=${RELEASE_PLATFORM} VERSION=${RELEASE_VERSION} INTERNAL_OR_PUBLIC=${CONFIRM_DEPLOYMENT_TYPE} CONFIRMATION=${CONFIRMATION} REGION1="${REGION1}" REGION2="${REGION2}" 
elif [[ ${REGION1} != "fail" ]] ; then
  CONFIRM_DEPLOYMENT_TYPE=$(buildkite-agent meta-data get deployment-type)
  make promote.single-region AZURE_CLOUD=${AZURE_CLOUD} PLATFORM=${RELEASE_PLATFORM} VERSION=${RELEASE_VERSION} INTERNAL_OR_PUBLIC=${CONFIRM_DEPLOYMENT_TYPE} CONFIRMATION=${CONFIRMATION} REGION1="${REGION1}"
  else
    echo "Publishing internally..."
    make publish.internally AZURE_CLOUD=${AZURE_CLOUD} PLATFORM=${RELEASE_PLATFORM} VERSION=${RELEASE_VERSION} CONFIRMATION=${CONFIRMATION}
fi

