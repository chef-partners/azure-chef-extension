<!---
This file is reset every time a new release is done. The contents of this file are for the currently unreleased version.

Example Note:

## Example Heading
Details about the thing that changed that needs to get included in the Release Notes in markdown.
-->

# azure-chef-extension 1210.13.2.2 release notes:
In this release, we have fixed some bugs as:
* [azure-chef-extension #283](https://github.com/chef-partners/azure-chef-extension/issues/283) chef-install.sh --no-ri and --no-rdoc are removed in Ruby 2.6
* [azure-chef-extension #280](https://github.com/chef-partners/azure-chef-extension/issues/280) Extension does not install on Azure's RHEL 8 image.
* [azure-chef-extension #268](https://github.com/chef-partners/azure-chef-extension/issues/268) PATH in chef-client environment missing /usr/sbin and breaking downstream cookbook.
* null-valued expression error on powershell for "Where-Object" command.

See the [CHANGELOG](https://github.com/chef-partners/azure-chef-extension/blob/master/CHANGELOG.md) for a list of all changes in this release, and review.

More information on the contribution process for Chef projects can be found in the [Chef Contributions document](https://docs.chef.io/community_contributions.html).

## azure-chef-extension on Github
https://github.com/chef-partners/azure-chef-extension