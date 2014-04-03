
require 'chef/azure/helpers/shared'

class ChefService
  include ChefAzure::Shared

  def self.install(log_location)
    log_location = log_location || bootstrap_directory # example default logs go to C:\chef\
    exit_code = 0
    message = "success"
    begin
      if windows?
        params = " -a install -c #{bootstrap_directory}\\client.rb -L #{log_location}\\chef-client.log "
        result = shell_out("chef-service-manager #{params}")
        result.error!
      end
      # Unix - only start chef-client in daemonize mode using self.enable
    rescue Mixlib::ShellOut::ShellCommandFailed => e
      Chef::Log.warn "Error installing chef-client service (#{e})"
      message = "#{e} - Check log file for details", "error"
      exit_code = 1
    rescue => e
      Chef::Log.error e
      message = "#{e} - Check log file for details", "error"
      exit_code = 1
    end
    [exit_code, message]
  end

  def self.enable(log_location)
    log_location = log_location || bootstrap_directory
    exit_code = 0
    message = "success"
    begin
      if windows?
        result = shell_out("chef-service-manager -a start")
        result.error!
      else
        # Unix like platform
        params = "-c #{bootstrap_directory}/client.rb -L #{log_location}/chef-client.log --daemonize "
        result = shell_out("chef-client #{params}")
        result.error!
      end
    rescue Mixlib::ShellOut::ShellCommandFailed => e
      Chef::Log.warn "Error enabling chef-client service (#{e})"
      message = "#{e} - Check log file for details", "error"
      exit_code = 1
    rescue => e
      Chef::Log.error e
      message = "#{e} - Check log file for details", "error"
      exit_code = 1
    end
    [exit_code, message]
  end
end
