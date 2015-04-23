require 'chef'
require 'json'
require 'chef/azure/heartbeat'
require 'chef/azure/status'
require 'chef/config'
require 'ohai'

module ChefAzure
  module Shared
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
    include ChefAzure::Shared

    def delete_node
      Chef::Log.info "Inside delete node call"
      begin
        Chef::Config.from_file("#{bootstrap_directory}/client.rb")

        unless Chef::Config[:node_name]
          ohai = Ohai::System.new
          ohai.all_plugins
          Chef::Config[:node_name] = ohai[:fqdn] || ohai[:machinename] || ohai[:hostname]
        end

        exit_code = 0
        message = "success"
        error_message = "Error while deleting node from chef server.."

        node = Chef::Node.load(Chef::Config[:node_name])
        node.destroy

        client = Chef::ApiClient.load(Chef::Config[:node_name])
        client.destroy
      rescue => e
        Chef::Log.error "#{error_message} (#{e})"
        message = "#{error_message} - #{e} - Check log file for details", "error"
        exit_code = 1
      end
      return exit_code
    end
  end
end