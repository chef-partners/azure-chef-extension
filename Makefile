.DEFAULT_GOAL := help

#Fetches login credentials according to gov or public cloud.
ifeq ($(AZURE_CLOUD), government)
DEPLOY_TYPE := gov
export USERNAME := $(shell vault kv get -field username secret/azure-chef-extension/gov-publishing-credentials)
export PASSWORD := $(shell vault kv get -field password secret/azure-chef-extension/gov-publishing-credentials)
else ifeq ($(AZURE_CLOUD), public)
DEPLOY_TYPE := production
export USERNAME := $(shell vault kv get -field username secret/azure-chef-extension/public-publishing-credential)
export PASSWORD := $(shell vault kv get -field password secret/azure-chef-extension/public-publishing-credential)
else
$(error AZURE_CLOUD must be set to "government" or "public")
endif

DATE_OF_PUBLISHING ?= $(shell date +%Y%m%d)
PLATFORM ?= windows
VERSION ?= $(shell cat VERSION)

export EXTENSION_NAMESPACE := Chef.Bootstrap.WindowsAzure

ifeq ($(AZURE_CLOUD), government)
	export MANAGEMENT_URL := https://management.core.usgovcloudapi.net
else
	export MANAGEMENT_URL := https://management.core.windows.net/
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
	az cloud set --name AzureUSGovernment
	az login -u '$(USERNAME)' -p '$(PASSWORD)'
	az account set --subscription "Azure Government - Chef VM Extension Publishing Subscription"	
else
    az cloud set --name AzureCloud
	az login -u '$(USERNAME)' -p '$(PASSWORD)'
endif
	@echo "$(USERNAME) password - $(PASSWORD)"	
	az account show
	

#list.versions:	@ Lists the internally and externally published extension
list.versions: login
	bundle exec rake list_versions

#publish.internally:	@ Publish extension internally to public or government Azure cloud
publish.internally: login
	bundle exec rake publish[deploy_to_$(DEPLOY_TYPE),$(PLATFORM),$(VERSION),$(EXTENSION_NAMESPACE),update,confirm_internal_deployment,$(CONFIRMATION)]

#publish.all-regions:	@ Publish extension to all regions in public or government Azure cloud
publish.all-regions: login
	bundle exec rake publish[deploy_to_$(DEPLOY_TYPE),$(PLATFORM),$(VERSION),$(EXTENSION_NAMESPACE),update,confirm_public_deployment,$(CONFIRMATION)]

#promote.single-region:	@ Promote extension to a single region in public or government Azure cloud
promote.single-region: login
ifndef REGION1
	$(error REGION1 is not set)
endif
	bundle exec rake promote_regions[deploy_to_$(DEPLOY_TYPE),$(PLATFORM),$(VERSION),$(EXTENSION_NAMESPACE),update,$(INTERNAL_OR_PUBLIC),$(CONFIRMATION),$(REGION1)]

#promote.two-regions:	@ Promote extension to two regions in public or government Azure cloud
promote.two-regions: login
ifndef REGION1
	$(error REGION1 is not set)
else ifndef REGION2
	$(error REGION2 is not set)
endif
	bundle exec rake promote_regions[deploy_to_$(DEPLOY_TYPE),$(PLATFORM),$(VERSION),$(EXTENSION_NAMESPACE),update,$(INTERNAL_OR_PUBLIC),$(CONFIRMATION),$(REGION1),$(REGION2)]

#unpublish:	@ Unpublish the azure chef extension from public or government Azure cloud
# unpublish: login
# 	bundle exec rake unpublish_version[delete_from_$(DEPLOY_TYPE),$(PLATFORM),$(VERSION)]

# #delete:	@ Delete the azure chef extension from public or government Azure cloud
# delete: login
# 	bundle exec rake delete[delete_from_$(DEPLOY_TYPE),$(PLATFORM),$(EXTENSION_NAMESPACE),$(VERSION)]