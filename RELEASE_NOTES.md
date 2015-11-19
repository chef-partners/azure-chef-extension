<!---
This file is reset every time a new release is done. The contents of this file are for the currently unreleased version.

Example Note:

## Example Heading
Details about the thing that changed that needs to get included in the Release Notes in markdown.
-->

# azure-chef-extension 1210.12.100 release notes:
In previous release, extension version was decoupled from the `chef-client` version. Now we have changed the extension version scheme. Please refer https://github.com/chef-partners/azure-chef-extension#azure-chef-extension-version-scheme for more details.

See the [CHANGELOG](https://github.com/chef-partners/azure-chef-extension/blob/master/CHANGELOG.md) for a list of all changes in this release, and review.

More information on the contribution process for Chef projects can be found in the [Chef Contributions document](https://docs.chef.io/community_contributions.html).

## azure-chef-extension on Github
https://github.com/chef-partners/azure-chef-extension

## Features added in azure-chef-extension 1210.12.100

* For ubuntu and centos, chef-client's version can be specified from `knife-azure` using `--bootstrap-version` option. This parameter can also be specified in `publicsettings` file as `bootstrap_version` json parameter.
By default chef-client's latest version gets installed.
* [azure-chef-extension #87](https://github.com/chef-partners/azure-chef-extension/pull/87) Passing --node-ssl-verify-mode option to the `azure-chef-extension`
* [azure-chef-extension #91](https://github.com/chef-partners/azure-chef-extension/pull/91) Added SSL certificate bootstrap support in chef extension for cloud-api protocol

## Issues fixed in azure-chef-extension 1210.12.100

* [azure-chef-extension #80](https://github.com/chef-partners/azure-chef-extension/pull/80) Fix uninstall for deleteChefConfig flag
* [azure-chef-extension #89](https://github.com/chef-partners/azure-chef-extension/pull/89) Moved call to function copy_settings_file after the bootstrap_directory is created
* [azure-chef-extension #90](https://github.com/chef-partners/azure-chef-extension/pull/90) Reduce time to install extension for ubuntu

## Known Issues
* When update is done for extension on windows and linux with autoUpdateClient=false, update doesn't happen(which is correct) but user doesn't get the actual error message. WAagent starts enable command and error logs show that enable command has failed.
* On disabling the extension for `ubuntu`, the azure portal shows "Installing" status.
