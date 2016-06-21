<!---
This file is reset every time a new release is done. The contents of this file are for the currently unreleased version.

Example Note:

## Example Heading
Details about the thing that changed that needs to get included in the Release Notes in markdown.
-->
# azure-chef-extension 1210.12.104.1000 release notes:
In this release we have added feature to allow user to pass environment variables in extensions public config. Refer [READEME](https://github.com/chef-partners/azure-chef-extension/blob/master/README.md) for usage.

See the [CHANGELOG](https://github.com/chef-partners/azure-chef-extension/blob/master/CHANGELOG.md) for a list of all changes in this release, and review.

More information on the contribution process for Chef projects can be found in the [Chef Contributions document](https://docs.chef.io/community_contributions.html).

## azure-chef-extension on Github
https://github.com/chef-partners/azure-chef-extension

##Features added in azure-chef-extension 1210.12.104.1000
* [azure-chef-extension #141](https://github.com/chef-partners/azure-chef-extension/pull/141) Added support to read environment variables from handler settings file

##Issues fixed in azure-chef-extension 1210.12.104.1000
* [azure-chef-extension #143](https://github.com/chef-partners/azure-chef-extension/pull/143) Added retry logic for chef-client download issue on Windows platform.
* [azure-chef-extension #144](https://github.com/chef-partners/azure-chef-extension/pull/144) Added check for chef-client installation and to skip installation if exists

## Known Issues
* When update is done for extension on windows and linux with autoUpdateClient=false, update doesn't happen(which is correct) but user doesn't get the actual error message. WAagent starts enable command and error logs show that enable command has failed.
