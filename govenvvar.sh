#!/bin/sh

export EXTENSION_NAMESPACE=Chef.Bootstrap.WindowsAzure
export MANAGEMENT_URL=https://management.core.usgovcloudapi.net
export azure_extension_cli=/workdir/azure-extensions-cli_linux_amd64
export SUBSCRIPTION_ID="$(vault kv get -field SUBSCRIPTION_ID secret/azure-chef-extension/government-cloud/subscription-id)"
export SUBSCRIPTION_CERT=/workdir/managementCertificate.pem
vault kv get -field management-certificate secret/azure-chef-extension/government-cloud/govManagementCertificate > "$SUBSCRIPTION_CERT"
export publishsettings=/workdir/opscode-azure-msdn-premium-4-3-2013-credentials.publishsettings
vault kv get -field gov-publishsettings secret/azure-chef-extension/government-cloud/azure-govCloud-chef-publishsettings > $publishsettings

bash -i