
# Process to publish / release the azure-chef-extension
## Document Purpose

The purpose of this Document is to describe the *current* publishing/releasing process
such that any member of the team can do a release. As we improve the automation around the
release process, the document should be updated such that it has the exact steps required to
release azure-chef-extension.

***Note*** We are using https://github.com/Azure/azure-extensions-cli/releases/download/v1.2.5/azure-extensions-cli_linux_amd64 binary on linux machine to run the commands explained below.

The latest binaries of azure-extension-cli don’t have some commands e.g. promote-single-region, promote-two-regions etc, and our rake tasks are using them. So the rake tasks will fail for the latest binaries.


## Prerequisites

* Install git: sudo apt-get install git
* git config --global core.autocrlf false

# Publishing Extension to Public Cloud

## Set Environment Variables

export PATH=$PATH:/opt/chef/embedded/bin

export publishsettings=azure-publishsettings-file-path

export SUBSCRIPTION_CERT=path-to-your-subscription-certificate-pem-file

export azure_extension_cli=path-to-your-azure-extension-cli-executable

export SUBSCRIPTION_ID=your-azure-subscription-id

export MANAGEMENT_URL=https://management.core.windows.net/

export EXTENSION_NAMESPACE=Chef.Bootstrap.WindowsAzure

***Note*** All the commands below should be executed from azure-chef-extension dir. The desired branch should be checked out which needs to be released.

# Internally Publish Extension Version

We publish extension internally to test the changes with Azure portal. Intenally published extension works with authorized subscription only. Internally published extension version are not available for external use.

# Command to publish extension internally

```
bundle exec rake publish[deploy_to_production,<platform>,<version-of-extension>,Chef.Bootstrap.WindowsAzure,update,confirm_internal_deployment]
```
Valid platform values: `ubuntu`, `windows`

***Note*** We mention `ubuntu` as platform to publish extension for all Linux OS.

Example:

```
bundle exec rake publish[deploy_to_production,windows,1210.12.100.105,Chef.Bootstrap.WindowsAzure,update,confirm_internal_deployment]
```

## Command to list all Published Extensions:

Lists the internally and externally published extension

``` $azure_extension_cli list-versions ```


Output looks like below:


|          NAMESPACE          |      TYPE       |     VERSION      | REPLICATED? | INTERNAL? | REGIONS |
------------------------------|-----------------|------------------|-------------|-----------|---------|
| Chef.Bootstrap.WindowsAzure | ChefClient      | 1210.12.110.1000 | true        | false     |         |
| Chef.Bootstrap.WindowsAzure | ChefClient      | 1210.12.110.1001 | true        | false     |         |
| Chef.Bootstrap.WindowsAzure | LinuxChefClient | 1210.12.110.1001 | true        | false     |         |


***Note*** Internally publish extension shows INTERNAL? as true. To use internally published extension we need to wait till the REPLICATED? flag sets to true after publishing.


## Command to promote extension version to single region

Promoting extension to single region will make that extension available on given region externally.

```bundle exec rake promote_single_region[deploy_to_production,<platform>,<version-of-extension>,<date-of-publishing>,<region>]```

***Note*** The date of publishing format should be `yyyymmdd`

## Command to promote extension version to two regions

***Note*** While promoting the extension to two regions, the region given in “promoting to single region”  should also be give.

```bundle exec rake promote_two_regions[deploy_to_production,<platform>,<version-of-extension>,<date-of-publishing>,<region1>,<region2>]```

## Command to publish extension externally

```
bundle exec rake update[deploy_to_production,<platform>,<version-of-extension>,<date-of-publishing>,Chef.Bootstrap.WindowsAzure,confirm_public_deployment]

```
***Example***

```
bundle exec rake update[deploy_to_production,windows,1210.12.100.105,20171102,Chef.Bootstrap.WindowsAzure,confirm_public_deployment]
```

## Command to unpublish externally published extension version

To delete externally published extension first you need to run unpublish command.

```
bundle exec rake unpublish_version[delete_from_production,ubuntu,<version-of-extesnsion>]
```

***Example***

```
bundle exec rake unpublish_version[delete_from_production,ubuntu,1210.12.100.105]
```
## Command to delete internally published extension version

```
bundle exec rake delete[delete_from_production,ubuntu,<version-of-extesnsion>]
```

***Example***

```
bundle exec rake delete[delete_from_production,ubuntu,Chef.Bootstrap.WindowsAzure,1210.12.100.105]
```
