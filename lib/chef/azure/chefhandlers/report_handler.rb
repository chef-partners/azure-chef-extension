require 'chef/log'
require 'chef/azure/helpers/shared'

module AzureExtension
  class ReportHandler < Chef::Handler
    include ChefAzure::Shared
    include ChefAzure::Config
    include ChefAzure::Reporting

    def initialize(extension_root)
      highest_version_extension = find_highest_extension_version(extension_root)
      @chef_extension_root = highest_version_extension.empty? ? extension_root : highest_version_extension
    end

    def report
      if run_status.success?
        load_azure_env
        report_heart_beat_to_azure(AzureHeartBeat::READY, 0, "chef-service enabled. Chef client run was successful.")

        if not File.exists?("#{bootstrap_directory}/node-registered")
          puts "#{Time.now} Node registered successfully"
          File.open("#{bootstrap_directory}/node-registered", "w") do |file|
            file.write("Node registered.")
          end
        end
      end
    end
  end
end
