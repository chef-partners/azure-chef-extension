# [DEPRECATED]
***Note*** Please refer to https://github.com/chef-partners/azure-chef-extension/blob/main/AUTOMATED_RELEASE_PROCESS.md for the new publish/release process.
# Process to publish / release the azure-chef-extension
## Document Purpose

The purpose of this Document is to describe the *current* publishing/releasing process
such that any member of the team can do a release. As we improve the automation around the
release process, the document should be updated such that it has the exact steps required to
release azure-chef-extension.

***Note*** We are using https://github.com/Azure/azure-extensions-cli/releases/download/v1.2.5/azure-extensions-cli_linux_amd64 binary on linux machine to run the commands explained below. This binary is included in the `chefes/releng-base` docker image used below.

The latest binaries of azure-extension-cli don’t have some commands e.g. promote-single-region, promote-two-regions etc, and our rake tasks are using them. So the rake tasks will fail for the latest binaries.


## Prerequisites

* Install git: sudo apt-get install git
* git config --global core.autocrlf false
* VPN access
* [Authenticated with vault.es.chef.co](https://chefio.atlassian.net/wiki/spaces/RELENGKB/pages/2077130986/How+to+access+Core+C+s+Hashicorp+Vault)
* [Install direnv](https://direnv.net/docs/installation.html) and run `direnv allow` from base directory of the azure-chef-extension repository

# Makefile Environment Variables

A `Makefile` is included in this repository to simplify the commands.

| Environment Variable | Required | Value | Default Value |
| --- | --- | --- | --- |
| `AZURE_CLOUD` | Yes | `government` or `public` | N/A |
| `DATE_OF_PUBLISHING` | No | Date formatted `yyyymmdd` | Current Date |
| `PLATFORM` | No | `ubuntu` or `windows` | `windows` |
| `VERSION` | No | Extension Version | Content of `VERSION` file in repo |

`REGION1` and `REGION2` environment variables are only required for the `promote.single-region` and `promote.two-regions` targets.

# Publishing Extension to Public Cloud

## Mount azure-chef-extension into a docker container and attach to the container

Run the following docker command from the base directory of the azure-chef-extension repository on your workstation.

```
docker run -it --rm -v $PWD:/azure-chef-extension -w /azure-chef-extension -e VAULT_ADDR -e VAULT_NAMESPACE -e VAULT_TOKEN chefes/releng-base
```

***Note*** All the commands below should be executed from `/azure-chef-extension` dir in the docker container. The desired branch should be checked out which needs to be released.

# Internally Publish Extension Version

We publish extension internally to test the changes with Azure portal. Intenally published extension works with authorized subscription only. Internally published extension version are not available for external use.

# Command to publish extension internally

```
AZURE_CLOUD=public make publish.internally
```

### Optional Environment Variables

* PLATFORM
* VERSION

## Command to list all Published Extensions:

Lists the internally and externally published extension

```
AZURE_CLOUD=public make list.versions
```

Output looks like below:


|          NAMESPACE          |      TYPE       |     VERSION      | REPLICATED? | INTERNAL? | REGIONS |
------------------------------|-----------------|------------------|-------------|-----------|---------|
| Chef.Bootstrap.WindowsAzure | ChefClient      | 1210.12.110.1000 | true        | false     |         |
| Chef.Bootstrap.WindowsAzure | ChefClient      | 1210.12.110.1001 | true        | false     |         |
| Chef.Bootstrap.WindowsAzure | LinuxChefClient | 1210.12.110.1001 | true        | false     |         |


***Note*** Internally publish extension shows INTERNAL? as true. To use internally published extension we need to wait till the REPLICATED? flag sets to true after publishing.


## Command to promote extension version to single region

Promoting extension to single region will make that extension available on given region externally.

```
AZURE_CLOUD=public REGION1=?????? make promote.single-region
```

### Optional Environment Variables

* DATE_OF_PUBLISHING
* PLATFORM
* REGION1
* VERSION

## Command to promote extension version to two regions

***Note*** While promoting the extension to two regions, the region given in “promoting to single region”  should also be give.

```
AZURE_CLOUD=public REGION1=?????? REGION2=?????? make promote.two-regions
```

### Optional Environment Variables

* DATE_OF_PUBLISHING
* PLATFORM
* REGION1
* REGION2
* VERSION

## Command to publish extension externally

```
AZURE_CLOUD=public make publish.all-regions
```

### Optional Environment Variables

* DATE_OF_PUBLISHING
* PLATFORM
* VERSION

## Command to unpublish externally published extension version

To delete externally published extension first you need to run unpublish command.

```
AZURE_CLOUD=public make unpublish
```

### Optional Environment Variables

* PLATFORM
* VERSION

## Command to delete internally published extension version

```
AZURE_CLOUD=public make delete
```

### Optional Environment Variables

* PLATFORM
* VERSION

## Command to create `azure-environment` file

You can create an `azure-environment` file that can be sourced in your docker container's shell session which
sets the environment variables required to run `azure-extensions-cli` and `bundle exec rake` commands. This can
be useful when you need to run commands that are not provided by the Makefile.

```
AZURE_CLOUD=public make create.azure-environment
```

Then try sourcing that file and running an `azure-extensions-cli` command.

```
. .secrets/azure-environment
azure-extensions-cli list-versions
```
