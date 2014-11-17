require 'chef/log'
require 'chef/azure/helpers/shared'

module AzureExtension
  class ReportHandler < Chef::Handler
    include ChefAzure::Shared
    include ChefAzure::Config
    include ChefAzure::Reporting

    def initialize(extension_root)
      @chef_extension_root = extension_root
    end
    
    def report
      if run_status.success?
        load_azure_env
        report_heart_beat_to_azure(AzureHeartBeat::READY, 0, "chef-service enabled. Chef client run was successful.")
      end
    end
  end
end
