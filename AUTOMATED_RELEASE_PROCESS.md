
# Process to publish / release the azure-chef-extension

## Document Purpose

  

The purpose of this document is to describe the *current* publishing/releasing process
such that any member of the team can do a release. We have improved the automation around the
release process and  this documents the exact steps required to release azure-chef-extension.

We have migrated to expeditor builds to allow our teams to curtail the otherwise manual and repetitive task of publishing and release build triggering without any prerequisites.

  

## Pipeline Notes

To trigger builds in the pipeline via the Buildkite UI a block step is used to pause the execution of a build and wait on a team member to unblock it using the web.
The block step collects information pertaining to the release using the prompt and fields attributes.

  
# Buildkite Environment Variables


The buildkite environment variable chart to trigger a build.

 
| Environment Variable | Required | Value | Default Value |
| --- | --- | --- | --- |
| `AZURE_CLOUD` | Yes | `government` or `public` | `public` |
| `CONFIRMATION` | Yes | `true` or `false` | true |
| `PLATFORM` | No | `ubuntu` or `windows` | `windows` |
| `VERSION` | Yes | Extension Version | N/A |
| `DEPLOYEMENT_TYPE` | No | `confirm_internal_deployment` or `confirm_public_deployment`| N/A |

  

`REGION1` and `REGION2` environment variables are optional and are only required for the `promote.single-region` and `promote.two-regions` targets.

  

# Pipelines

 1. `publish/internal` - This pipeline publishes the extension version internally. An extension is published internally for testing purposes with Azure portal. Internally published extension works with authorised subscription only. Internally published extension version are not available for external use. This build is triggered every time there is a version bumping. 
 2. `publish/external` - This pipeline publishes the extension version externally. The pipeline has to be triggered manually from the Buildkite UI for publishing or releasing a newer version of the extension.

# Publishing Extension Internally

To test or publish an extension internally you can trigger a `publish/internal` build on your specific branch from the Buildkite UI. The execution with be paused at a block step and wait on you  to unblock the block step by clicking on it. Once unblocked,  the Buildkite web UI opens a dialog box asking you to add the values required for the extension to be published. 

	
 ## Guide to publish extension to Public or Government Cloud

 - **Platform** - Select  input type `ubuntu` or `windows`  displayed as radio buttons . Value for platform defaults to `windows`. It is a required field.
 - **Cloud** - Select input type `public` or `government`  displayed as radio buttons. Value for cloud defaults to `public` azure_cloud. It is a required field.
 - **Confirmation** - Select input type `true` or `false`  displayed as radio buttons. Value for confirmation defaults to `true` . It is a required field.
 - **Version** - Fill out the version of the extension that you wish to publish in the text field. It is a required field.
 - **Confirm deployment type** - Pre-selected to `Internal Deployment`field. No inputs required.

*Note* : You are not required to fill in the optional fields of  **Region1** and **Region2** for this publish. 

After all the inputs are filled, select *Continue* and the bottom of the dialog box to proceed with the execution of the build.

 ## Guide to promote extension to single region
  To promote the extension to a single region fill out the **Region1** field along with the above mentioned required fields. 
  Make sure you do not enclose the region value in any quotation marks. For instance, if you wish to promote the extension to West US, simply type in West US instead of "West US" or '"West US"'.
 
  ## Guide to promote extension to two regions

  Similarly, to promote the extension to a single region fill out both the **Region1** and **Region2** field along with the above mentioned required fields.


# Publishing Extension Externally

To publish an extension externally you can trigger a `publish/external` build on your specific branch from the Buildkite UI. The execution with be paused at a block step and wait on you  to unblock the block step by clicking on it. Once unblocked,  the Buildkite web UI opens a dialog box asking you to add the values required for the extension to be published. 

 ## Guide to publish extension to Public or Government Cloud

 - **Platform** - Select  input type `ubuntu` or `windows`  displayed as radio buttons . Value for platform defaults to `windows`. It is a required field.
 - **Cloud** - Select input type `public` or `government`  displayed as radio buttons. Value for cloud defaults to `public` azure_cloud. It is a required field.
 - **Confirmation** - Select input type `true` or `false`  displayed as radio buttons. Value for confirmation defaults to `true` . It is a required field.
 - **Version** - Fill out the version of the extension that you wish to publish in the text field. It is a required field.
 - **Confirm deployment type** - Pre-selected to `Public Deployment`field. No inputs required.

****Note* : You are not required to fill in the optional fields of  **Region1** and **Region2** for this publish. 

 ## Guide to promote extension to single region
  To promote the extension to a single region fill out the **Region1** field along with the above mentioned required fields. 
  Make sure you do not enclose the region value in any quotation marks. For instance, if you wish to promote the extension to West US, simply type in West US instead of "West US" or '"West US"'.
 
  ## Guide to promote extension to two regions

  Similarly, to promote the extension to a single region fill out both the **Region1** and **Region2** field along with the above mentioned required fields.

