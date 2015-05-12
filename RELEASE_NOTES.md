<!---
This file is reset every time a new release is done. The contents of this file are for the currently unreleased version.

Example Note:

## Example Heading
Details about the thing that changed that needs to get included in the Release Notes in markdown.
-->

# azure-chef-extension 1206.12.3.0 release notes:
This release of azure-chef-extension adds bug fixes, feature improvements and unit testcases.

See the [CHANGELOG](https://github.com/chef-partners/azure-chef-extension/blob/master/CHANGELOG.md) for a list of all changes in this release, and review.

More information on the contribution process for Chef projects can be found in the [Chef Contributions document](https://docs.chef.io/community_contributions.html).

## Features improved in azure-chef-extension 1206.12.3.0

* Performing bootstrap asynchronously to reduce time for enable command
* [azure-chef-extension #22](https://github.com/chef-partners/azure-chef-extension/pull/22) Implemented changes to preserve runlist if first converge fails
* Added complete unit testcase coverage
* Added log_level attribute and set it to info for detailed log

## azure-chef-extension on Github
https://github.com/chef-partners/azure-chef-extension

## Issues fixed in azure-chef-extension 1206.12.3.0

* [azure-chef-extension #34](https://github.com/chef-partners/azure-chef-extension/pull/34) Fixed update extension process related issues. This includes using last version extension's settings file during update process as this settings file is not available during update because WaAgent takes some time to create it.
* [azure-chef-extension #24](https://github.com/chef-partners/azure-chef-extension/pull/24) Fixed Azure chef extension uninstall should not delete c:\chef or /etc/chef by default
* [azure-chef-extension #21](https://github.com/chef-partners/azure-chef-extension/pull/21) Fix for providing multiple runlist item