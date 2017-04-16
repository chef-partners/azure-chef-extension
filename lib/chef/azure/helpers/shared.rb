
require 'json'
require 'chef/azure/heartbeat'
require 'chef/azure/status'
require 'chef/config'

module ChefAzure
  module Shared
    def find_highest_extension_version(extension_root)
      #Get the latest version extension root. Required in case of extension update
      highest_version_extension = ""
      if windows?
        # Path format: C:\Packages\Plugins\Chef.Bootstrap.WindowsAzure.ChefClient\1205.12.2.1
        split_path = extension_root.split("/")
        version = split_path.last.gsub(".","").to_i
        root_path = extension_root.gsub(split_path.last, "")

        Dir.entries(root_path).each do |d|
          if d.split(".").size > 1
            d_version = d.gsub(".","").to_i
            if d_version >= version
                version = d_version
                highest_version_extension = root_path + d
            end
          end
        end
      else
        # Path format: /var/lib/waagent/Chef.Bootstrap.WindowsAzure.LinuxChefClient-1207.12.3.0
        root_path = extension_root.split("-")
        version = root_path.last.gsub(".","").to_i

        Dir.glob(root_path.first + "*").each do |d|
          if d.split("-").size > 1
            d_version = d.split("-").last.gsub(".","").to_i
            if d_version >= version
                version = d_version
                highest_version_extension = d
            end
          end
        end
      end
      highest_version_extension
    end

    def windows?
      if RUBY_PLATFORM =~ /mswin|mingw|windows/
        true
      else
        false
      end
    end

    def bootstrap_directory
      if windows?
        "#{ENV['SYSTEMDRIVE']}/chef"
      else
        "/etc/chef"
      end
    end

    def chef_bin_path
      if windows?
        "C:\\opscode\\chef\\bin;C:\\opscode\\chef\\embedded\\bin"
      else
        "/opt/chef/bin:/opt/chef/embedded/bin"
      end
    end

    def append_to_path(path)
      if windows?
        ENV["PATH"] = "#{path};#{ENV["PATH"]}"
      else
        ENV["PATH"] = "#{path}:#{ENV["PATH"]}"
      end
    end

    def chef_config
      @chef_config ||=
      begin
        Chef::Config.from_file("#{bootstrap_directory}/client.rb")
        Chef::Config
      end
    end

    def handler_settings_file
      @handler_settings_file ||=
      begin
        files = Dir.glob("#{File.expand_path(@azure_config_folder)}/*.settings").sort
        if files and not files.empty?
          files.last
        else
          error_message = "Configuration error. Azure chef extension Settings file missing."
          Chef::Log.error error_message
          report_status_to_azure error_message, "error"
          @exit_code = 1
          raise error_message
        end
      end
    end
  end

  module Config
    def read_config(chef_extension_root)
      Chef::Log.info "Loading Handler environment..."

      # Load environment from chef_extension_root/HandlerEnvironment.json
      handler_env = JSON.parse(File.read("#{chef_extension_root}/HandlerEnvironment.json"))
      azure_heart_beat_file = handler_env[0]["handlerEnvironment"]["heartbeatFile"]
      azure_status_folder = handler_env[0]["handlerEnvironment"]["statusFolder"]
      azure_plugin_log_location = handler_env[0]["handlerEnvironment"]["logFolder"]
      azure_config_folder = handler_env[0]["handlerEnvironment"]["configFolder"]
      Chef::Log.info "#{azure_config_folder} --> #{azure_status_folder} --> #{azure_heart_beat_file} --> #{azure_plugin_log_location}"

      # Get name of status file by finding the latest sequence number from runtime settings file
      settings_file_name = Dir.glob("#{azure_config_folder}/*.settings".gsub(/\\/,'/')).sort.last
      sequence = File.basename(settings_file_name, ".settings")
      azure_status_file = azure_status_folder + "/" + sequence + ".status"
      Chef::Log.info "Status file name: #{azure_status_file}"

      # return configs read
      [ azure_heart_beat_file, azure_status_folder,
        azure_plugin_log_location, azure_config_folder,
        azure_status_file
      ]
    end
  end

  module Reporting
    def load_azure_env
      @azure_heart_beat_file, @azure_status_folder, @azure_plugin_log_location, @azure_config_folder, @azure_status_file = read_config(@chef_extension_root)
    end

    def report_heart_beat_to_azure(status, code, message)
      # update @azure_heart_beat_file
      Chef::Log.info "Reporting heartbeat..."
      AzureHeartBeat.update(@azure_heart_beat_file, status, code, message)
    end

    def report_status_to_azure (message, status_type)
      AzureExtensionStatus.log(@azure_status_file, message, status_type)
    end
  end

  module DeleteNode
    def delete_node(extension_root)
      Chef::Log.info "Inside delete node call"
      begin
        @chef_extension_root = extension_root
        bootstrap_options = value_from_json_file(handler_settings_file,'runtimeSettings','0','handlerSettings', 'publicSettings', 'bootstrap_options')
        client_rb = value_from_json_file(handler_settings_file, 'runtimeSettings', '0', 'handlerSettings', 'publicSettings', 'client_rb')

        # TODO : Need to work on node_name to get fqdn if not set through bootstrap option
        node_name = bootstrap_options['node_name'] || client_rb['node_name']
        Chef::Config.chef_server_url = bootstrap_options['chef_server_url'] || client_rb['node_name']
        # TODO: Need to update location as per OS
        Chef::Config.client_key = "/etc/chef/client.pem"
        Chef::Config.validation_client_name = client_rb['validation_client_name']
        Chef::Config.node_name = node_name
        # TODO: Need to update location as per OS
        Chef::Config.validation_key = "/etc/chef/validation.pem"

        exit_code = 0
        message = "success"
        error_message = "Error while deleting node from chef server.."

        node = Chef::Node.load(node_name)
        node.destroy

        client = Chef::ApiClient.load(node_name)
        client.destroy
      rescue => e
        Chef::Log.error "#{error_message} (#{e})"
        message = "#{error_message} - #{e} - Check log file for details", "error"
        exit_code = 1
      end
      return exit_code
    end

    def handler_settings_file
      handler_env = JSON.parse(File.read("#{@chef_extension_root}/HandlerEnvironment.json"))
      azure_config_folder = handler_env[0]["handlerEnvironment"]["configFolder"]
      @handler_settings_file ||=
      begin
        files = Dir.glob("#{File.expand_path(azure_config_folder)}/*.settings").sort
        if files and not files.empty?
          files.last
        else
          error_message = "Configuration error. Azure chef extension Settings file missing."
          Chef::Log.error error_message
          report_status_to_azure error_message, "error"
          @exit_code = 1
          raise error_message
        end
      end
    end
  end
end