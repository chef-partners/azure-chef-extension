<!---
This file is reset every time a new release is done. The contents of this file are for the currently unreleased version.

Example Note:

## Example Heading
Details about the thing that changed that needs to get included in the Release Notes in markdown.
-->

# azure-chef-extension 1210.12.4.1000 release notes:
This release of azure-chef-extension fixes the issue of extension 1210.12.4.1 not available in all locations for ARM commands. Extension 1210.12.4.1 has been deleted.

See the [CHANGELOG](https://github.com/chef-partners/azure-chef-extension/blob/master/CHANGELOG.md) for a list of all changes in this release, and review.

More information on the contribution process for Chef projects can be found in the [Chef Contributions document](https://docs.chef.io/community_contributions.html).

## azure-chef-extension on Github
https://github.com/chef-partners/azure-chef-extension

## Issues fixed in azure-chef-extension 1210.12.4.1000

* Extension not visible in all locations for ARM commands.
* [azure-chef-extension #53](https://github.com/chef-partners/azure-chef-extension/pull/53) Fix for bootstrap_options Chef environment name setting
* [azure-chef-extension #52](https://github.com/chef-partners/azure-chef-extension/pull/52) Extension update happens for Linux even if AutoUpdateClient=false

## Known Issues
* When update is done for extension on windows and linux with autoUpdateClient=false, update doesn't happen(which is correct) but user doesn't get the actual error message. WAagent starts enable command and error logs show that enable command has failed.
