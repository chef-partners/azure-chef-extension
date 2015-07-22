<!---
This file is reset every time a new release is done. The contents of this file are for the currently unreleased version.

Example Note:

## Example Heading
Details about the thing that changed that needs to get included in the Release Notes in markdown.
-->

# azure-chef-extension 1210.12.4.1 release notes:
This release of azure-chef-extension adds some bug fixes and reduces the time taken to enable the extension.

See the [CHANGELOG](https://github.com/chef-partners/azure-chef-extension/blob/master/CHANGELOG.md) for a list of all changes in this release, and review.

More information on the contribution process for Chef projects can be found in the [Chef Contributions document](https://docs.chef.io/community_contributions.html).

## Features improved in azure-chef-extension 1210.12.4.1

* [azure-chef-extension #42](https://github.com/chef-partners/azure-chef-extension/pull/42) Implemented node verify cert bootstrap option
* [azure-chef-extension #43](https://github.com/chef-partners/azure-chef-extension/pull/43) Added support for validator less bootstrap

## azure-chef-extension on Github
https://github.com/chef-partners/azure-chef-extension

## Issues fixed in azure-chef-extension 1210.12.4.1

* [azure-chef-extension #39](https://github.com/chef-partners/azure-chef-extension/pull/39) Azure extension handler issue
* [azure-chef-extension #40](https://github.com/chef-partners/azure-chef-extension/pull/40) Fixed issue related to preserve runlist if first chef client run fails
* [azure-chef-extension #46](https://github.com/chef-partners/azure-chef-extension/pull/46) Azure extension failing with timeout error
* [azure-chef-extension #49](https://github.com/chef-partners/azure-chef-extension/pull/49) Fixed empty client_key/validation_key issue

## Known Issues
* Update happens for linux even if autoUpdateClient is set to false.
* When update is done for extension on windows with autoUpdateClient=false, update doesn't happen(which is correct) but user doesn't get the actual error message. WAagent starts enable command and error logs show that enable command has failed.
