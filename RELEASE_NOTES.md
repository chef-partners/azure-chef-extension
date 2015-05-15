<!---
This file is reset every time a new release is done. The contents of this file are for the currently unreleased version.

Example Note:

## Example Heading
Details about the thing that changed that needs to get included in the Release Notes in markdown.
-->

# azure-chef-extension 1207.12.3.0 release notes:
This release of azure-chef-extension adds a major bug fix and a feature.

See the [CHANGELOG](https://github.com/chef-partners/azure-chef-extension/blob/master/CHANGELOG.md) for a list of all changes in this release, and review.

More information on the contribution process for Chef projects can be found in the [Chef Contributions document](https://docs.chef.io/community_contributions.html).

## Features improved in azure-chef-extension 1207.12.3.0

* [azure-chef-extension #31](https://github.com/chef-partners/azure-chef-extension/pull/31) Load azure attributes in hints file for ohai azure plugin

## azure-chef-extension on Github
https://github.com/chef-partners/azure-chef-extension

## Issues fixed in azure-chef-extension 1207.12.3.0

* [azure-chef-extension #36](https://github.com/chef-partners/azure-chef-extension/pull/36) Fixed escape runlist related issue that was causing Set-AzureVMChefExtension command to fail

## Known Issues
While trying to update the extension from an older version(eg. 1205.12.3.0) to the latest version(eg. 1207.12.3.0) with `deleteChefConfig` option `false` in `0.settings` file, `C:\chef\client.rb`( `\etc\chef\client.rb` in case of linux) file will have following contents at the end:

```
start_handlers << AzureExtension::StartHandler.new("C:/Packages/Plugins/Chef.Bootstrap.WindowsAzure.ChefClient/1205.12.2.1")
report_handlers << AzureExtension::ReportHandler.new("C:/Packages/Plugins/Chef.Bootstrap.WindowsAzure.ChefClient/1205.12.2.1")
exception_handlers << AzureExtension::ExceptionHandler.new("C:/Packages/Plugins/Chef.Bootstrap.WindowsAzure.ChefClient/1205.12.2.1")
```

But 1205.12.2.1 has got uninstalled during update. So, it will fail as `AzureExtension::ExceptionHandler.new("C:/Packages/Plugins/Chef.Bootstrap.WindowsAzure.ChefClient/1205.12.2.1") not exists`

## Work around for the known issue
In order to fix the above issue, user should manually update the version of chefclient in `client.rb` file to the installed version. e.g.

```
start_handlers << AzureExtension::StartHandler.new("C:/Packages/Plugins/Chef.Bootstrap.WindowsAzure.ChefClient/1207.12.3.0")
report_handlers << AzureExtension::ReportHandler.new("C:/Packages/Plugins/Chef.Bootstrap.WindowsAzure.ChefClient/1207.12.3.0")
exception_handlers << AzureExtension::ExceptionHandler.new("C:/Packages/Plugins/Chef.Bootstrap.WindowsAzure.ChefClient/1207.12.3.0")
```
