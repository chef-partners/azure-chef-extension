<!---
This file is reset every time a new release is done. The contents of this file are for the currently unreleased version.

Example Note:

## Example Heading
Details about the thing that changed that needs to get included in the Release Notes in markdown.
-->
# Windows azure-chef-extension 1210.12.107.1000 release notes:
In this release, we have moved the installation steps to Enable phase for Windows extension. This is done because `n.settings` file is not available during install phase. We need to read some values like bootstrap_version(chef-client version) and daemon from n.settings during install.

See the [CHANGELOG](https://github.com/chef-partners/azure-chef-extension/blob/master/CHANGELOG.md) for a list of all changes in this release, and review.

More information on the contribution process for Chef projects can be found in the [Chef Contributions document](https://docs.chef.io/community_contributions.html).

## azure-chef-extension on Github
https://github.com/chef-partners/azure-chef-extension


##Features added in azure-chef-extension 1210.12.107.1000
* Added -daemon option in chef-client service install. [Feature 178](https://github.com/chef-partners/azure-chef-extension/pull/178)
**Note**: This feature is supported only on Windows 2012 onwards.
* Moving install steps to enable [Feature 181](https://github.com/chef-partners/azure-chef-extension/pull/181)


##Issues fixed in azure-chef-extension 1210.12.107.1000
* Support bootstrap_version for Windows Installs. [Issue 175](https://github.com/chef-partners/azure-chef-extension/pull/175)

##Known issue
* Extension fails intermittently for Windows 2008 with timeout error.