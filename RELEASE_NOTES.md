<!---
This file is reset every time a new release is done. The contents of this file are for the currently unreleased version.

Example Note:

## Example Heading
Details about the thing that changed that needs to get included in the Release Notes in markdown.
-->
# azure-chef-extension 1210.12.106.1000 release notes:
In this release, we have added the support for `chef_service_interval` option which will allow users to specify the frequency at which the `chef-service` runs. Also, added support for `custom_json_attr` to be set for the first run of `chef-client`. One of the enhancement made in this release is that `secret` will now be read from `protected_settings` instead of `public_settings`.

See the [CHANGELOG](https://github.com/chef-partners/azure-chef-extension/blob/master/CHANGELOG.md) for a list of all changes in this release, and review.

More information on the contribution process for Chef projects can be found in the [Chef Contributions document](https://docs.chef.io/community_contributions.html).

## azure-chef-extension on Github
https://github.com/chef-partners/azure-chef-extension


##Features added in azure-chef-extension 1210.12.106.1000
* Added code to read chef_service_interval from extension config file and process it. [Feature 161](https://github.com/chef-partners/azure-chef-extension/pull/161)
* Adding support for setting custom json attributes in first_boot.json [Feature 167](https://github.com/chef-partners/azure-chef-extension/pull/167)


##Enhancements made in azure-chef-extension 1210.12.106.1000
* Fetching secret from protectedSettings instead of publicSettings [Enhancement 169](https://github.com/chef-partners/azure-chef-extension/pull/169)


##Issues fixed in azure-chef-extension 1210.12.106.1000
* Fixed bug to not generate empty encrypted_data_bag_secret file. [Issue 172](https://github.com/chef-partners/azure-chef-extension/pull/172)
