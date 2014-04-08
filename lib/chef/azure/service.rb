
require 'chef/azure/helpers/shared'

class ChefService
  include Chef::Mixin::ShellOut
  include ChefAzure::Shared
  AZURE_CHEF_SERVICE_PID_FILE = "azure-chef-daemon.pid"

  # TODO - make these methods idempotent
  def install(log_location)
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

  def enable(log_location)
    log_location = log_location || bootstrap_directory
    exit_code = 0
    message = "success"
    if is_running?
      puts "chef-client service is already running..."
      return [exit_code, message]
    end

    begin
      if windows?
        result = shell_out("chef-service-manager -a start")
        result.error!
      else
        # Unix like platform
        chef_pid_file = "#{bootstrap_directory}/#{AZURE_CHEF_SERVICE_PID_FILE}"
        
        params = "-c #{bootstrap_directory}/client.rb -L #{log_location}/chef-client.log --daemonize --pid #{chef_pid_file} "
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

  def is_running?
    begin
      if windows?
        result = shell_out("chef-service-manager -a status")
        # TODO grep output for status
        result.error!
      else
        chef_pid_file = "#{bootstrap_directory}/#{AZURE_CHEF_SERVICE_PID_FILE}"
        if File.exists?(chef_pid_file)
          chef_pid = File.read(chef_pid_file)
          begin
            # send signal 0 to check process
            Process::kill 0, chef_pid.to_i
          rescue Errno::ESRCH
            return false
          end
          return true
        end
      end
    rescue Mixlib::ShellOut::ShellCommandFailed => e
      Chef::Log.warn "Error checking chef-client service status (#{e})"
      message = "#{e} - Check log file for details", "error"
      raise
    rescue => e
      Chef::Log.error e
      message = "#{e} - Check log file for details", "error"
      raise
    end
    return false
  end
end
