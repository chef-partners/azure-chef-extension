
# This implements the azure extension 'disable' command.

require 'chef'
require 'chef/azure/helpers/shared'
require 'chef/azure/service'
require 'chef/azure/task'
require 'chef/azure/helpers/parse_json'

class DisableChef
  include ChefAzure::Shared
  include ChefAzure::Config
  include ChefAzure::Reporting

  def initialize(extension_root, *disable_args)
    @chef_extension_root = extension_root
    @disable_args = disable_args
    @exit_code = 0
  end

  def run
    load_env

    report_heart_beat_to_azure(AzureHeartBeat::NOTREADY, 0, "Disabling chef-service...")

    disable_chef

    if @exit_code == 0
      report_heart_beat_to_azure(AzureHeartBeat::READY, 0, "chef-service is disabled")
    else
      report_heart_beat_to_azure(AzureHeartBeat::NOTREADY, 1, "chef-service disable failed")
    end

    return @exit_code

  end

  private
  def load_env
    @azure_heart_beat_file, @azure_status_folder, @azure_plugin_log_location, @azure_config_folder, @azure_status_file = read_config(@chef_extension_root)
  end

  def disable_chef
    # Disabling Chef involves following steps:
    # - Stop the Chef service OR
    # - Disable the Chef scheduled task
    begin
      daemon = value_from_json_file(handler_settings_file, 'runtimeSettings', '0', 'handlerSettings', 'publicSettings', 'daemon')
      if windows?
       daemon = "task" if daemon.nil? || daemon.empty?
      else
       daemon = "service" if daemon.nil? || daemon.empty?   
      end
      if(daemon == "service" || !windows?)
        @exit_code, @error_message = ChefService.new.disable(@azure_plugin_log_location)
        update_chef_status("service")
      elsif daemon == "task" && windows?
        @exit_code, @error_message = ChefTask.new.disable
        update_chef_status("sch-task")
      elsif daemon == "none"
        update_chef_status("extension")
      end
    rescue => e
      Chef::Log.error e
      report_status_to_azure "#{e} - Check log file for details", "error"
      @exit_code = 1
    ensure
      # Once process exits, we log the current process' pid
      Chef::Log.info "Process completed (pid: #{Process.pid})"
    end
    @exit_code
  end

  def update_chef_status(option_name)
    if @exit_code == 0
      report_status_to_azure "chef-#{option_name} disabled", "success"
    else
      report_status_to_azure "chef-#{option_name} disable failed - #{@error_message}", "error"
    end
  end
end

