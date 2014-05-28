azure-chef-extension
====================

Azure resource extension to enable Chef on Azure virtual machine instances.

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


:deploy_type = [deploy_to_preview/deploy_to_prod] default is preview

:target_type = [windows/ubuntu/centos] default is windows

:extension_version = Chef extension version, say 11.6 [pattern major.minor governed by Azure team]

:chef_deploy_namespace = "Chef.Bootstrap.WindowsAzure.Test".

:operation = [new/update]

:internal_or_public = [confirm_public_deployment/confirm_internal_deployment]

:confirmation_required = [true/false] defaults to true to generate prompt.


    rake 'publish[deploy_to_production,ubuntu,11.6,Chef.Bootstrap.WindowsAzure.Test,update,confirm_internal_deployment]'
