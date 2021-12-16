.DEFAULT_GOAL := help

ifeq ($(AZURE_CLOUD), government)
DEPLOY_TYPE := gov
else ifeq ($(AZURE_CLOUD), public)
DEPLOY_TYPE := production
else
$(error AZURE_CLOUD must be set to "government" or "public")
endif

DATE_OF_PUBLISHING ?= $(shell date +%Y%m%d)
PLATFORM ?= windows
VERSION ?= $(shell cat VERSION)

export azure_extension_cli ?= /usr/local/bin/azure-extensions-cli
export EXTENSION_NAMESPACE := Chef.Bootstrap.WindowsAzure
export publishsettings := .secrets/opscode-azure-msdn-premium-4-3-2013-credentials.publishsettings
export SUBSCRIPTION_CERT := .secrets/managementCertificate.pem
export SUBSCRIPTION_ID := $(shell vault kv get -field subscription-id secret/azure-chef-extension/$(AZURE_CLOUD))

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
	rm -rf .secrets
	bundle exec rake clean

setup: bundle.install
	mkdir -p .secrets
	vault kv get -field management-certificate secret/azure-chef-extension/$(AZURE_CLOUD) > $(SUBSCRIPTION_CERT)
	vault kv get -field publish-settings secret/azure-chef-extension/$(AZURE_CLOUD) > $(publishsettings)

#create.azure-environment:	@ Creates a script that can be sourced to prepare the shell for azure-extensions-cli commands or rake commands
create.azure-environment: setup
	rm -f .secrets/azure-environment
	@echo "export azure_extension_cli=$(azure_extension_cli)" >> .secrets/azure-environment
	@echo "export EXTENSION_NAMESPACE=$(EXTENSION_NAMESPACE)" >> .secrets/azure-environment
	@echo "export MANAGEMENT_URL=$(MANAGEMENT_URL)" >> .secrets/azure-environment
	@echo "export publishsettings=$(publishsettings)" >> .secrets/azure-environment
	@echo "export SUBSCRIPTION_CERT=$(SUBSCRIPTION_CERT)" >> .secrets/azure-environment
	@echo "export SUBSCRIPTION_ID=$(SUBSCRIPTION_ID)" >> .secrets/azure-environment

#list.versions:	@ Lists the internally and externally published extension
list.versions: setup
	$(azure_extension_cli) list-versions

#publish.internally:	@ Publish extension internally to public Azure cloud
publish.internally: setup
	bundle exec rake publish[deploy_to_$(DEPLOY_TYPE),$(PLATFORM),$(VERSION),$(EXTENSION_NAMESPACE),update,confirm_internal_deployment]

#publish.all-regions:	@ Publish extension to all regions in public or government Azure cloud
publish.all-regions: setup
	bundle exec rake update[deploy_to_$(DEPLOY_TYPE),$(PLATFORM),$(VERSION),$(DATE_OF_PUBLISHING),$(EXTENSION_NAMESPACE),confirm_public_deployment]

#promote.single-region:	@ Promote extension to a single region in public or government Azure cloud
promote.single-region: setup
ifndef REGION1
	$(error REGION1 is not set)
endif
	bundle exec rake promote_single_region[deploy_to_$(DEPLOY_TYPE),$(PLATFORM),$(VERSION),$(DATE_OF_PUBLISHING),$(REGION1)]

#promote.two-regions:	@ Promote extension to two regions in public or government Azure cloud
promote.two-regions: setup
ifndef REGION1
	$(error REGION1 is not set)
else ifndef REGION2
	$(error REGION2 is not set)
endif
	bundle exec rake promote_two_regions[deploy_to_$(DEPLOY_TYPE),$(PLATFORM),$(VERSION),$(DATE_OF_PUBLISHING),$(REGION1),$(REGION2)]

#unpublish:	@ Unpublish the azure chef extension from public or government Azure cloud
unpublish: setup
	bundle exec rake unpublish_version[delete_from_$(DEPLOY_TYPE),$(PLATFORM),$(VERSION)]

#delete:	@ Delete the azure chef extension from public or government Azure cloud
delete: setup
	bundle exec rake delete[delete_from_$(DEPLOY_TYPE),$(PLATFORM),$(EXTENSION_NAMESPACE),$(VERSION)]