#!/bin/sh

export EXTENSION_NAMESPACE=Chef.Bootstrap.WindowsAzure
export MANAGEMENT_URL=https://management.core.windows.net/
export azure_extension_cli=/workdir/azure-extensions-cli_linux_amd64
export SUBSCRIPTION_ID="$(vault kv get -field -value secret/azure-chef-extension/test-cloud/subscription-id)"
export SUBSCRIPTION_CERT=/workdir/managementCertificate.pem
vault kv get -field -value secret/azure-chef-extension/test-cloud/managementCertificate > "$SUBSCRIPTION_CERT"
export publishsettings=/workdir/opscode-azure-msdn-premium-4-3-2013-credentials.publishsettings
vault kv get -field -value secret/azure-chef-extension/test-cloud/publishsetting > $publishsettings

bash -i