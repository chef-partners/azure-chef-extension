require 'chef/log'
require 'chef/azure/helpers/shared'

module AzureExtension
  class StartHandler < Chef::Handler
    include ChefAzure::Shared
    include ChefAzure::Config
    include ChefAzure::Reporting

    def initialize(extension_root)
      #Get the latest version extension root. Required in case of extension update
      highest_version_file = ""
      if windows?
      else
	root_path = extension_root.split("-")
	version = root_path.last.gsub(".","").to_i

	Dir.glob(root_path.first + "*").each do |d|
  		if d.split("-").size > 1
    		d_version = d.split("-").last.gsub(".","").to_i    
    		if d_version >= version
      			version = d_version
      			highest_version_file = d
    		end
  		end
        end
      end

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
