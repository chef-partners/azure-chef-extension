require 'chef/log'
require 'chef/azure/helpers/shared'

module AzureExtension
  class ReportHandler < Chef::Handler
    include ChefAzure::Shared
    include ChefAzure::Config
    include ChefAzure::Reporting

    def report
      if run_status.success?
        load_azure_env
        report_status_to_azure "chef-client run was completed successfully at #{end_time}", "success"
      end
    end
  end
end
