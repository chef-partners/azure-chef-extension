.DEFAULT_GOAL := help

# Load local publishing credentials for testing (git-ignored; not present in CI).
# Set AZURE_TENANT/AZURE_SUBSCRIPTION/AZURE_SERVICE_PRINCIPAL/AZURE_SERVICE_PRINCIPAL_PASSWORD
# here to skip vault and use these directly. See .env.example.
-include .env

export EXTENSION_NAMESPACE := Chef.Bootstrap.WindowsAzure

#Fetches login credentials according to gov or public cloud.
ifeq ($(AZURE_CLOUD), government)
DEPLOY_TYPE := gov
ifdef AZURE_SERVICE_PRINCIPAL
export USERNAME := $(AZURE_SERVICE_PRINCIPAL)
export AZURE_PASSWORD := $(AZURE_SERVICE_PRINCIPAL_PASSWORD)
else
export USERNAME := $(shell vault kv get -field username secret/azure-chef-extension/gov-publishing-credentials)
export AZURE_PASSWORD := $(shell vault kv get -field password secret/azure-chef-extension/gov-publishing-credentials)
endif
else ifeq ($(AZURE_CLOUD), public)
DEPLOY_TYPE := production
ifdef AZURE_SERVICE_PRINCIPAL
export USERNAME := $(AZURE_SERVICE_PRINCIPAL)
export AZURE_PASSWORD := $(AZURE_SERVICE_PRINCIPAL_PASSWORD)
export TENANT := $(AZURE_TENANT)
else
export USERNAME := $(shell vault kv get -field username secret/azure-chef-extension/public-publishing-credentials)
export AZURE_PASSWORD := $(shell vault kv get -field password secret/azure-chef-extension/public-publishing-credentials)
export TENANT := $(shell vault kv get -field tenant secret/azure-chef-extension/public-publishing-credentials)
endif
else
$(error AZURE_CLOUD must be set to "government" or "public")
endif

DATE_OF_PUBLISHING ?= $(shell date +%Y%m%d)
PLATFORM ?= windows
VERSION ?= $(shell cat VERSION)

ifeq ($(AZURE_CLOUD), government)
	export MANAGEMENT_URL := https://management.core.usgovcloudapi.net
else
	export MANAGEMENT_URL := https://management.core.windows.net/
endif

ifeq ($(CONFIRMATION), true)
CONFIRM_REQUIRED := false
else
CONFIRM_REQUIRED := true
endif

ifdef REGION1
ifdef REGION2
REGIONA = "${REGION1}"
REGIONB = "${REGION2}"
$(info Publishing to regions $(REGIONA) and $(REGIONB)...)
else
$(info Publishing to region $(REGION1)...)
REGION = "${REGION1}"
endif
endif

#help:	@ List available tasks on this project
help:
	@grep -h -E '[a-zA-Z\.\-]+:.*?@ .*$$' $(MAKEFILE_LIST) | sort | tr -d '#' | awk 'BEGIN {FS = ":.*?@ "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

bundle.install:
	bundle install

#clean: @ Clean up the local workspace
clean: bundle.install
	bundle exec rake clean

login: bundle.install
ifeq ($(AZURE_CLOUD), government)
	@az cloud set --name AzureUSGovernment
	@az login -u '$(USERNAME)' -p '$(AZURE_PASSWORD)' > /dev/null
ifdef AZURE_SUBSCRIPTION
	@az account set --subscription '$(AZURE_SUBSCRIPTION)'
else
	@az account set --subscription "Azure Government - Chef VM Extension Publishing Subscription"
endif
else
	@az cloud set --name AzureCloud
	@az login --service-principal --username '$(USERNAME)' --password '$(AZURE_PASSWORD)' --tenant '$(TENANT)' > /dev/null
ifdef AZURE_SUBSCRIPTION
	@az account set --subscription '$(AZURE_SUBSCRIPTION)'
endif
endif
	@az account show

#list.versions:	@ Lists the internally and externally published extension
list.versions: login
	bundle exec rake list_versions

#publish.internally:	@ Publish extension internally to public or government Azure cloud
publish.internally: login
	bundle exec rake publish[deploy_to_$(DEPLOY_TYPE),$(PLATFORM),$(VERSION),$(EXTENSION_NAMESPACE),update,confirm_internal_deployment,$(CONFIRM_REQUIRED)]

#publish.all-regions:	@ Publish extension to all regions in public or government Azure cloud
publish.all-regions: login
	bundle exec rake publish[deploy_to_$(DEPLOY_TYPE),$(PLATFORM),$(VERSION),$(EXTENSION_NAMESPACE),update,confirm_public_deployment,$(CONFIRM_REQUIRED)]

#promote.single-region:	@ Promote extension to a single region in public or government Azure cloud
promote.single-region: login
ifndef REGION1
	$(error REGION1 is not set)
endif
	bundle exec rake promote_regions[deploy_to_$(DEPLOY_TYPE),$(PLATFORM),$(VERSION),$(EXTENSION_NAMESPACE),update,$(INTERNAL_OR_PUBLIC),$(CONFIRM_REQUIRED),$(REGION)]

#promote.two-regions:	@ Promote extension to two regions in public or government Azure cloud
promote.two-regions: login
ifndef REGION1
	$(error REGION1 is not set)
else ifndef REGION2
	$(error REGION2 is not set)
endif
	bundle exec rake promote_regions[deploy_to_$(DEPLOY_TYPE),$(PLATFORM),$(VERSION),$(EXTENSION_NAMESPACE),update,$(INTERNAL_OR_PUBLIC),$(CONFIRM_REQUIRED),$(REGIONA),$(REGIONB)]