
# This implements the azure extension 'enable' command.

require 'chef'
require 'chef/azure/helpers/shared'
require 'chef/azure/service'

class EnableChef
  include Chef::Mixin::ShellOut
  include ChefAzure::Shared
  include ChefAzure::Config
  include ChefAzure::Reporting

  def initialize(extension_root, *enable_args)
    @chef_extension_root = extension_root
    @enable_args = enable_args
    @exit_code = 0
  end

  def run
    load_env

    report_heart_beat_to_azure(AzureHeartBeat::NOTREADY, 0, "Enabling chef-service...")

    enable_chef

    if @exit_code == 0
      report_heart_beat_to_azure(AzureHeartBeat::READY, 0, "chef-service is enabled")
    else
      report_heart_beat_to_azure(AzureHeartBeat::NOTREADY, 0, "chef-service enable failed")
    end

    return @exit_code

  end

  private
  def load_env
    @azure_heart_beat_file, @azure_status_folder, @azure_plugin_log_location, @azure_config_folder, @azure_status_file = read_config(@chef_extension_root)
  end

  def enable_chef
    # Enabling Chef involves following steps:
    # - Configure chef only on first run
    # - Install the Chef service
    # - Start the Chef service   
    begin
      configure_chef_only_once

      install_chef_service if @exit_code == 0

      enable_chef_service if @exit_code == 0

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

  def install_chef_service
    @exit_code, error_message = ChefService.new.install(@azure_plugin_log_location)
    if @exit_code == 0
      report_status_to_azure "chef-service installed", "success"
    else
      report_status_to_azure "chef-service install failed - #{error_message}", "error"
    end
    @exit_code
  end

  def enable_chef_service
    @exit_code, error_message = ChefService.new.enable(@azure_plugin_log_location)
    if @exit_code == 0
      report_status_to_azure "chef-service enabled", "success"
    else
      report_status_to_azure "chef-service enable failed - #{error_message}", "error"
    end
    @exit_code
  end

  # Configuring chef involves
  #   => create bootstrap folder with client.rb, validation.pem, first_boot.json
  #   => Perform node registration executing first chef run
  #   => run the user supplied runlist from first_boot.json in async manner
  def configure_chef_only_once

    # "node-registered" file also indicates that enabled was called once and 
    # configs are already generated.
    if not File.exists?("#{bootstrap_directory}/node-registered")
      if File.directory?("#{bootstrap_directory}")
        puts "Bootstrap directory [#{bootstrap_directory}] already exists, skipping creation..."
      else
        puts "Bootstrap directory [#{bootstrap_directory}] does not exist, creating..."
        FileUtils.mkdir_p("#{bootstrap_directory}")
      end
    
      # Write validation key

      # Write client.rb

      # write the first_boot.json

      # run chef-client for first time with no runlist to register the node
      puts "Running chef client for first time with no runlist..."

      begin
        params = " -c #{bootstrap_directory}/client.rb -E _default -L #{@azure_plugin_log_location}/chef-client.log "
        result = shell_out("chef-client #{params}")
        result.error!
      rescue Mixlib::ShellOut::ShellCommandFailed => e
        Chef::Log.warn "chef-client run - node registration failed (#{e})"
        report_status_to_azure "#{e} - Check log file for details", "error"
        @exit_code = 1
        return
      rescue => e
        Chef::Log.error e
        report_status_to_azure "#{e} - Check log file for details", "error"
        @exit_code = 1
        return
      end

      puts "Node registered successfully"
      File.open("#{bootstrap_directory}/node-registered", "w") do |file|
        file.write("Node registered.")
      end

      # Now the run chef-client with runlist in background, as we done want enable command to wait, else long running chef-client with runlist will timeout azure.
      puts "Launching chef-client again to set the runlist"
      params = "-c #{bootstrap_directory}/client.rb -j #{bootstrap_directory}/first-boot.json -E _default -L #{@azure_plugin_log_location}/chef-client.log "
      child_pid = Process.spawn "chef-client #{params}"
      Process.detach child_pid
      puts "Successfully launched chef-client process with PID [#{child_pid}]"

    end
  end

end
