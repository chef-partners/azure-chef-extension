
require 'chef/azure/helpers/shared'
require 'chef/azure/helpers/erb'

class ChefService
  include Chef::Mixin::ShellOut
  include ChefAzure::Shared
  AZURE_CHEF_SERVICE_PID_FILE = "azure-chef-daemon.pid"
  AZURE_CHEF_CRON_NAME = 'azure_chef_extension'

  # TODO - make these methods idempotent
  def install(log_location)
    log_location = log_location || bootstrap_directory # example default logs go to C:\chef\
    exit_code = 0
    message = "success"
    error_message = "Error installing chef-client service"
    begin
      puts "Installing chef-client service..."
      if windows?
        params = " -a install -c #{bootstrap_directory}\\client.rb -L #{log_location}\\chef-client.log "
        result = shell_out("chef-service-manager #{params}")
        result.error!
      end
      # Unix - only start chef-client in daemonize mode using self.enable
    rescue Mixlib::ShellOut::ShellCommandFailed => e
      Chef::Log.error "#{error_message} (#{e})"
      message = "#{error_message} - #{e} - Check log file for details"
      exit_code = 1
    rescue => e
      Chef::Log.error "#{error_message} (#{e})"
      message = "#{error_message}- #{e} - Check log file for details"
      exit_code = 1
    end
    puts "Installed chef-client service" if exit_code == 0
    [exit_code, message]
  end

  def enable(extension_root, bootstrap_directory, log_location, interval, splay)
    log_location = log_location || bootstrap_directory
    exit_code = 0
    message = "success"
    error_message = "Error enabling chef-client service"
    if is_running?
      puts "chef-client service is already running..."
      return [exit_code, message]
    end

    begin
      puts "Starting chef-client service..."
      if windows?
        result = shell_out("chef-service-manager -a start")
        result.error!
      else
        # Unix like platform
        chef_pid_file = "#{bootstrap_directory}/#{AZURE_CHEF_SERVICE_PID_FILE}"
        templates_dir = File.join(File.dirname(__FILE__), "/templates")

        chef_cron = ERBHelpers::ERBCompiler.run(
          File.read(File.join(templates_dir, "chef-client-cron-create.erb")),
           {:name => AZURE_CHEF_CRON_NAME, :extension_root => extension_root, 
            :bootstrap_directory => bootstrap_directory, :log_location =>  log_location,
            :interval => interval/60, :sleep_time => splay, :chef_pid_file => chef_pid_file
          })

        puts "Adding chef cron = \"#{chef_cron}\""
        result = shell_out("chef-apply -e \"#{chef_cron}\"")
        result.error!
      end
    rescue Mixlib::ShellOut::ShellCommandFailed => e
      Chef::Log.error "#{error_message} (#{e})"
      message = "#{error_message} - #{e} - Check log file for details", "error"
      exit_code = 1
    rescue => e
      Chef::Log.error "#{error_message} (#{e})"
      message = "#{error_message} - #{e} - Check log file for details", "error"
      exit_code = 1
    end
    puts "Started chef-client service." if exit_code == 0
    [exit_code, message]
  end

  def disable(log_location)
    log_location = log_location || bootstrap_directory
    exit_code = 0
    message = "success"
    error_message = "Error disabling chef-client service"
    if not is_running?
      puts "chef-client service is already stopped..."
      return [exit_code, message]
    end

    begin
      puts "Disabling chef-client service..."
      if windows?
        result = shell_out("chef-service-manager -a stop")
        result.error!
      else
        templates_dir = File.join(File.dirname(__FILE__), "/templates")

        chef_cron = ERBHelpers::ERBCompiler.run(File.read(File.join(templates_dir, "chef-client-cron-delete.erb")), {:name => AZURE_CHEF_CRON_NAME})

        puts "Removing chef-cron = \"#{chef_cron}\""
        result = shell_out("chef-apply -e \"#{chef_cron}\"")
      end
    rescue Mixlib::ShellOut::ShellCommandFailed => e
      Chef::Log.error "#{error_message} (#{e})"
      message = "#{error_message} - #{e} - Check log file for details", "error"
      exit_code = 1
    rescue => e
      Chef::Log.error "#{error_message} (#{e})"
      message = "#{error_message} - #{e} - Check log file for details", "error"
      exit_code = 1
    end
    puts "Disabled chef-client service" if exit_code == 0
    [exit_code, message]
  end

  def get_chef_pid
    chef_pid_file = "#{bootstrap_directory}/#{AZURE_CHEF_SERVICE_PID_FILE}"

    if File.exists?(chef_pid_file)
      chef_pid = File.read(chef_pid_file)
      return chef_pid.to_i
    end
    -1
  end

  def get_chef_pid!
    chef_pid = get_chef_pid
    if chef_pid > 0
      chef_pid
    else
      raise "Invalid chef-client pid file. [#{chef_pid_file}]"
    end
  end

  def is_running?
    begin
      if windows?
        result = shell_out("chef-service-manager -a status")
        # TODO grep output for status
        result.error!
      else
        result = shell_out("crontab -l")
        result.stdout.each_line do | line |
          case line
          when /#{AZURE_CHEF_CRON_NAME}/
            return true
          end
        end
        return false
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
