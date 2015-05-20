require 'chef/log'
require 'chef/azure/helpers/shared'

module AzureExtension
  class StartHandler < Chef::Handler
    include ChefAzure::Shared
    include ChefAzure::Config
    include ChefAzure::Reporting

    def initialize(extension_root)
      highest_version_file = find_highest_extension_version(extension_root)
      @chef_extension_root = highest_version_file.empty? ? extension_root : highest_version_file
    end

    def report
      load_azure_env
      report_heart_beat
    end

    private
      def report_heart_beat
        # update @azure_heart_beat_file
        report_heart_beat_to_azure(AzureHeartBeat::READY, 0, "chef-service is running properly")
      end
  end
end
