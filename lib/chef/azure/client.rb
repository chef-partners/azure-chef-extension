
require 'json'
require 'chef'

require 'chef/azure/heartbeat'
require 'chef/azure/status'

class AzureChefClient
  include Chef::Mixin::ShellOut
  CHEF_BINS_PATH = "C:\\opscode\\chef\\bin;C:\\opscode\\chef\\embedded\\bin"

  def initialize(extension_root, *chef_client_args)
    @chef_extension_root = extension_root
    @chef_client_args = chef_client_args
  end

  def run
    load_handler_env

    report_heart_beat_to_azure

    run_chef_client

    report_status_to_azure

    @last_run_result  # make sure we return result to wrapper
  end

  private
  def load_handler_env
    puts "Loading Handler environment..."
    # Load environment from @chef_extension_root/HandlerEnvironment.json
    handler_env = JSON.parse(File.read("#{@chef_extension_root}\\HandlerEnvironment.json"))
    @azure_heart_beat_file = handler_env[0]["handlerEnvironment"]["heartbeatFile"]
    @azure_status_folder = handler_env[0]["handlerEnvironment"]["statusFolder"]
    @azure_plugin_log_location = handler_env[0]["handlerEnvironment"]["logFolder"]
    @azure_config_folder = handler_env[0]["handlerEnvironment"]["configFolder"]
    puts "#{@azure_config_folder} --> #{@azure_status_folder} --> #{@azure_heart_beat_file} --> #{@azure_plugin_log_location}"
    # Get name of status file by finding the latest sequence number from runtime settings file
    sequence = 0
    settingsFiles = Dir.entries(@chef_extension_root + "\\RuntimeSettings").sort
    if(settingsFiles.size) > 2
      sequence = settingsFiles[settingsFiles.size-1].split(".")[0]
    end
    @azure_status_file = @azure_status_folder + "\\" + sequence + ".status"
    puts "Status file name: #{@azure_status_file}"
  end

  def report_heart_beat_to_azure
    # update @azure_heart_beat_file
    puts "Reporting heartbeat..."
    AzureHeartBeat.update(@azure_heart_beat_file, AzureHeartBeat::READY, 0, "chef-service is running properly")
  end

  def run_chef_client
    # The chef client will be started in a new process. We have used shell_out to start the chef-client.
    # We need to add the --no-fork, as by default it is set to fork=true.
    begin
      # Pass config params to the new process
      config_params = @chef_client_args.join(" ") + " --no-fork"

      # set path so original chef-client is picked up
      ENV["PATH"] = "#{CHEF_BINS_PATH};#{ENV["PATH"]}"

      puts "running chef-client with:"
      puts "Args = [#{config_params}]"
      puts "Path = [#{ENV["PATH"]}]"

      # Starts a new process and waits till the process exits
      @last_run_result = shell_out("chef-client #{config_params}")
      puts "logging last_run_result from client #{@last_run_result.stderr} \n****\n #{@last_run_result.stdout}"

    rescue Mixlib::ShellOut::ShellCommandFailed => e
      Chef::Log.warn "Not able to start chef-client in new process (#{e})"
    rescue => e
      Chef::Log.error e
    ensure
      # Once process exits, we log the current process' pid
      Chef::Log.info "Child process exited (pid: #{Process.pid})"
    end
  end

  def report_status_to_azure
    # use @last_run_result to write status to @azure_status_folder/<seq number>.status
    puts "Updating the status..."
    AzureExtensionStatus.log(@azure_status_file, @last_run_result)
  end
end
