<!---
This file is reset every time a new release is done. The contents of this file are for the currently unreleased version.

Example Note:

## Example Heading
Details about the thing that changed that needs to get included in the Release Notes in markdown.
-->

# azure-chef-extension 1210.12.101.1000 for Windows and 1210.12.101.1000 for Ubuntu release notes:
In this release we have added extension support for Debian platform. We have also added an option uninstall_chef_client which determines whether to uninstall chef-client or not during Extension Update and Uninstall. Now we are installing chef from Omnitruck for Ubuntu, CentOS and Debian.

See the [CHANGELOG](https://github.com/chef-partners/azure-chef-extension/blob/master/CHANGELOG.md) for a list of all changes in this release, and review.

More information on the contribution process for Chef projects can be found in the [Chef Contributions document](https://docs.chef.io/community_contributions.html).

## azure-chef-extension on Github
https://github.com/chef-partners/azure-chef-extension

##Features added in azure-chef-extension 1210.12.101.1000 and 1210.12.101.1001
* [azure-chef-extension #103](https://github.com/chef-partners/azure-chef-extension/pull/103) Added uninstall_chef_client flag which determines whether to uninstall chef-client or not.
* [azure-chef-extension #108](https://github.com/chef-partners/azure-chef-extension/pull/108) Installing chef from Omnitruck for ubuntu and centos
* [azure-chef-extension #109](https://github.com/chef-partners/azure-chef-extension/pull/109) Debian support in azure-chef-extension installing chef from Omnitruck 

## Issues fixed in azure-chef-extension 1210.12.101.1000
[azure-chef-extension #107](https://github.com/chef-partners/azure-chef-extension/pull/107) Added code to delete node-registered file during update process as it was not allowing chef-client run during enable process after update, to update handlers path in client.eb after update

## Known Issues
* When update is done for extension on windows and linux with autoUpdateClient=false, update doesn't happen(which is correct) but user doesn't get the actual error message. WAagent starts enable command and error logs show that enable command has failed.
* On disabling the extension for `ubuntu`, the azure portal shows "Installing" status.
