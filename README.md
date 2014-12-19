azure-chef-extension
====================

Azure resource extension to enable Chef on Azure virtual machine instances.

Azure Chef Extension Version Scheme
===================================
**Description:**

Extensions versions are specified in 4 digit format : `<MajorVersion.MinorVersion.BuildNumber.RevisionNumber>`.

Chef Extension package includes released Chef-Client package. Currently Extension version depends on Chef-Client version. So whenever new Chef Client is releases, we have to publish new Extension as well.

Chef-Client versions are specified in 4 digit format: `<MajorVersion.MinorVersion.PatchVersion-RevisionNumber>`. Example: chef-client 11.14.6-1

**Use Following Extension Version Scheme:**
* We are using Extension Major version from `100.*.*.*`
* Set Extension Minor Version = Chef-Client's Major Version
* Set Extension BuildNumber = Chef-Client's Minor Version
* Set Extension RevisionNumber = Chef-Client's PatchVersion
* Whenever Chef-Client 'Major' Or 'Minor' Versions changes, increase Extension 'Major' Version by one.

**Example**

    Consider:

    Current Chef-Client Version is 11.14.6-1

    Current Extension Version is 100.11.14.6

    # Chef-Client Minor version changed
    After new Client-Client Version 11.16.0-1 is released

    # Increase Extension Major version by +1
    New Extension Version will be 101.11.16.0

Build and Packaging
===================
You can use rake tasks to build and publish the new builds to Azure subscription.

**Note:** The arguments have fix order and recommended to specify all for readability and avoiding confusion.

Build
-------
    rake build[:target_type, :extension_version, :confirmation_required]

:target_type = [windows/ubuntu/centos] default is windows

:extension_version = Chef extension version, say 11.6 [pattern major.minor governed by Azure team]

:confirmation_required = [true/false] defaults to true to generate prompt.

    rake 'build[ubuntu,11.6]'

Publish
-----------
Rake task to generate a build and publish the generated zip package to Azure.

    rake publish[:deploy_type, :target_type, :extension_version, :chef_deploy_namespace, :operation, :internal_or_public, :confirmation_required]

The task depends on:
  * cli parameters listed below.
  * entries in Publish.json.
  * environment variable "publishsettings" set pointing to the publish setting file.
  [Environment]::SetEnvironmentVariable("publishsettings", 'C:\myaccount.publishsettings', "Process")


:deploy_type = [deploy_to_preview/deploy_to_prod] default is preview

:target_type = [windows/ubuntu/centos] default is windows

:extension_version = Chef extension version, say 11.6 [pattern major.minor governed by Azure team]

:chef_deploy_namespace = "Chef.Bootstrap.WindowsAzure.Test".

:operation = [new/update]

:internal_or_public = [confirm_public_deployment/confirm_internal_deployment]

:confirmation_required = [true/false] defaults to true to generate prompt.


    rake 'publish[deploy_to_production,ubuntu,11.6,Chef.Bootstrap.WindowsAzure.Test,update,confirm_internal_deployment]'

Delete
-----------
Rake task to delete a published package to Azure.
**Note:**
Only internal packages can be deleted.

    rake delete[:deploy_type, :target_type, :chef_deploy_namespace, :full_extension_version, :confirmation_required]

The task depends on:
  * cli parameters listed below.
  * environment variable "publishsettings" set pointing to the publish setting file.

  :deploy_type = [delete_from_preview/delete_from_prod] default is preview

  :full_extension_version = Chef extension version, say 11.12.4.1 [Version as specified during the publish call]

  :target_type, :chef_deploy_namespace and :confirmation_required = same as for publish task.

    rake 'delete[delete_from_production,ubuntu,Chef.Bootstrap.WindowsAzure.Test,11.12.4.2]'

Update
-----------
Rake task to udpate a published package to Azure. Used to switch published versions from "internal" to "public" and vice versa. You need to know the build date.

    rake update[:deploy_type, :target_type, :extension_version, :build_date_yyyymmdd, :chef_deploy_namespace, :internal_or_public, :confirmation_required]

The task depends on:
  * cli parameters listed below. All params definition as same as publish task except build date.
  * environment variable "publishsettings" set pointing to the publish setting file.

  :build_date_yyyymmdd = The build date when package was published, in format yyyymmdd

    rake 'update[deploy_to_production,windows,11.12.4.2,20140530,Chef.Bootstrap.WindowsAzure.Test,confirm_internal_deployment]'