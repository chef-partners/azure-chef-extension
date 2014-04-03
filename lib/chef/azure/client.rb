
require 'chef'
require 'chef/azure/helpers/shared'

class AzureChefClient
  include Chef::Mixin::ShellOut
  include ChefAzure::Config
  include ChefAzure::reporting

  def initialize(extension_root, *chef_client_args)
    @chef_extension_root = extension_root
    @chef_client_args = chef_client_args
    @exit_code = 0
  end

  def run
    load_env

    report_heart_beat

    run_chef_client

    return @exit_code

  end

  private
  def load_env
    @azure_heart_beat_file, @azure_status_folder, @azure_plugin_log_location, @azure_config_folder, @azure_status_file = read_config(@chef_extension_root)
  end

  def report_heart_beat
    # update @azure_heart_beat_file
    report_heart_beat_to_azure(@azure_heart_beat_file, AzureHeartBeat::READY, 0, "chef-service is running properly")
  end

  def run_chef_client
    # The chef client will be started in a new process. We have used shell_out to start the chef-client.
    # We need to add the --no-fork, as by default it is set to fork=true.
    begin
      # Pass config params to the new process
      config_params = @chef_client_args.join(" ") + " --no-fork"

      # set path so original chef-client is picked up
      path = append_to_path(chef_bin_path)
      
      Chef::Log.info "running chef-client with: Args = [#{config_params}], Path = [#{path}]"

      # Starts chef-client from original chef and waits till the process exits
      @exit_code = 0
      last_run_result = shell_out("chef-client #{config_params}")
      last_run_result.error!
      report_status_to_azure "Chef-client run success", "success"

    rescue Mixlib::ShellOut::ShellCommandFailed => e
      Chef::Log.warn "Error running chef-client (#{e})"
      report_status_to_azure "#{e} - Check log file for details", "error"
      @exit_code = 1
    rescue => e
      Chef::Log.error e
      report_status_to_azure "#{e} - Check log file for details", "error"
      @exit_code = 1
    ensure
      # Once process exits, we log the current process' pid
      Chef::Log.info "Process completed (pid: #{Process.pid})"
    end
  end

end
