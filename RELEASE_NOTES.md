<!---
This file is reset every time a new release is done. The contents of this file are for the currently unreleased version.

Example Note:

## Example Heading
Details about the thing that changed that needs to get included in the Release Notes in markdown.
-->
# Windows azure-chef-extension 1210.12.107.1001 release notes:
In this release, we have added support for `daemon` and `bootstrap_version` options for Windows 2008. Previously these options were supported only on Windows 2012 and onwards.

See the [CHANGELOG](https://github.com/chef-partners/azure-chef-extension/blob/master/CHANGELOG.md) for a list of all changes in this release, and review.

More information on the contribution process for Chef projects can be found in the [Chef Contributions document](https://docs.chef.io/community_contributions.html).

## azure-chef-extension on Github
https://github.com/chef-partners/azure-chef-extension


##Issues fixed in azure-chef-extension 1210.12.107.1001
* Parsing json on Windows 2008 [Issue 185](https://github.com/chef-partners/azure-chef-extension/pull/185)

##Known issue
* Extension fails intermittently for Windows 2008 with timeout error, usually with powershell ASM commands.