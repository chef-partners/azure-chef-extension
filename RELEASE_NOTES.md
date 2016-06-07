<!---
This file is reset every time a new release is done. The contents of this file are for the currently unreleased version.

Example Note:

## Example Heading
Details about the thing that changed that needs to get included in the Release Notes in markdown.
-->

# azure-chef-extension 1210.12.103.1000 release notes:
In this release we have made changes to use Chef's install script for downloading chef-client package for both linux and windows. We have also added support to read ohai_hints in extension.

See the [CHANGELOG](https://github.com/chef-partners/azure-chef-extension/blob/master/CHANGELOG.md) for a list of all changes in this release, and review.

More information on the contribution process for Chef projects can be found in the [Chef Contributions document](https://docs.chef.io/community_contributions.html).

## azure-chef-extension on Github
https://github.com/chef-partners/azure-chef-extension

##Features added in azure-chef-extension 1210.12.103.1000
* [azure-chef-extension #128](https://github.com/chef-partners/azure-chef-extension/pull/128) Use opscode chef's install for chef installation
* [azure-chef-extension #122](https://github.com/chef-partners/azure-chef-extension/pull/122) Added code to write chef_client run logs in sub_status field of 0.status file
* [azure-chef-extension #135](https://github.com/chef-partners/azure-chef-extension/pull/135) Added support to read ohai_hints in extension

##Issues fixed in azure-chef-extension 1210.12.103.1000
* [azure-chef-extension #133](https://github.com/chef-partners/azure-chef-extension/pull/133) Appending Environment path for ruby at the end
Fixes issue https://github.com/chef-partners/azure-chef-extension/issues/131
* [azure-chef-extension #136](https://github.com/chef-partners/azure-chef-extension/pull/136) Fixed bug when ohai_hints are not passed and modified RSpecs
* [azure-chef-extension #139](https://github.com/chef-partners/azure-chef-extension/pull/139) Used different way for downloading opscode install.ps1 file for windows

## Known Issues
* When update is done for extension on windows and linux with autoUpdateClient=false, update doesn't happen(which is correct) but user doesn't get the actual error message. WAagent starts enable command and error logs show that enable command has failed.
