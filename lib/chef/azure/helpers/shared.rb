
require 'json'
require 'chef/azure/heartbeat'
require 'chef/azure/status'
require 'chef/config'

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
        "#{ENV['SYSTEMDRIVE']}\\chef\\"
      else
        "/etc/chef/"
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
      Chef::Log.info "#{@azure_config_folder} --> #{@azure_status_folder} --> #{@azure_heart_beat_file} --> #{@azure_plugin_log_location}"

      # Get name of status file by finding the latest sequence number from runtime settings file
      sequence = 0
      settingsFiles = Dir.entries(azure_config_folder).sort
      if(settingsFiles.size) > 2
        sequence = settingsFiles[settingsFiles.size-1].split(".")[0]
      end
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
    def report_heart_beat_to_azure(status, code, message)
      # update @azure_heart_beat_file
      Chef::Log.info "Reporting heartbeat..."
      AzureHeartBeat.update(@azure_heart_beat_file, status, code, message)
    end

    def report_status_to_azure (message, status_type)
      AzureExtensionStatus.log(@azure_status_file, message, status_type)
    end
  end
end