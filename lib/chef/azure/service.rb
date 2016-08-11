require 'chef/azure/helpers/shared'
require 'chef/azure/helpers/erb'

class ChefService
  include Chef::Mixin::ShellOut
  include ChefAzure::Shared
  AZURE_CHEF_SERVICE_PID_FILE = "azure-chef-client.pid"
  AZURE_CHEF_CRON_NAME = 'azure_chef_extension'

  # TODO - make these methods idempotent
  def install(log_location)
    log_location = log_location || bootstrap_directory # example default logs go to C:\chef\
    exit_code = 0
    message = "success"
    error_message = "Error installing chef-client service"
    begin
      if windows?
        puts "#{Time.now} Getting chef-client service status"
        status = shell_out("sc.exe query chef-client")
        if status.exitstatus == 1060 && status.stdout.include?("The specified service does not exist as an installed service.")
          puts "#{Time.now} Installing chef-client service..."
          params = " -a install -c #{bootstrap_directory}\\client.rb -L #{log_location}\\chef-client.log "
          result = shell_out("chef-service-manager #{params}")
          result.error!
          puts "#{Time.now} Installed chef-client service."
        else
          status.error!
          puts "#{Time.now} chef-client service is already installed."
        end
      end
      # Unix - only start chef-client in daemonize mode using self.enable
    rescue => e
      Chef::Log.error "#{error_message} (#{e})"
      message = "#{error_message}- #{e} - Check log file for details"
      exit_code = 1
    end
    [exit_code, message]
  end

  def chef_service_interval_changed?(new_chef_service_interval)
    puts "#{Time.now} checking if chef-service interval has been changed by the user..."
    result = shell_out("crontab -l | grep -A 1 #{AZURE_CHEF_CRON_NAME} | sed -n '2p'")
    old_chef_service_interval = result.stdout.split('/')[1].split(' ')[0].to_i

    if old_chef_service_interval != new_chef_service_interval
      true    ## yes interval has been changed by the user ##
    else
      false   ## no change in interval ##
    end
  end

  def deploy_cron(extension_root, bootstrap_directory, log_location, chef_service_interval)
    # Unix like platform
    chef_pid_file = "#{bootstrap_directory}/#{AZURE_CHEF_SERVICE_PID_FILE}"
    templates_dir = File.join(File.dirname(__FILE__), "/templates")

    chef_cron = ERBHelpers::ERBCompiler.run(
      File.read(File.join(templates_dir, "chef-client-cron-create.erb")),
        {:name => AZURE_CHEF_CRON_NAME, :extension_root => extension_root,
         :bootstrap_directory => bootstrap_directory, :log_location =>  log_location,
         :interval => chef_service_interval, :sleep_time => (chef_config[:splay] || 0), :chef_pid_file => chef_pid_file
        }
      )

    puts "Adding chef cron = \"#{chef_cron}\""
    result = shell_out("chef-apply -e \"#{chef_cron}\"")
    result.error!
  end

  def delete_cron
    templates_dir = File.join(File.dirname(__FILE__), "/templates")
    chef_cron = ERBHelpers::ERBCompiler.run(File.read(File.join(templates_dir, "chef-client-cron-delete.erb")), {:name => AZURE_CHEF_CRON_NAME})

    puts "Removing chef-cron = \"#{chef_cron}\""
    result = shell_out("chef-apply -e \"#{chef_cron}\"")
    result.error!
  end

  def enable(extension_root, bootstrap_directory, log_location, chef_service_interval = 30)
    log_location = log_location || bootstrap_directory
    exit_code = 0
    message = "success"
    error_message = "Error enabling chef-client service"
    begin
      if is_running?
        puts "#{Time.now} chef-client service is already running..."

        if chef_service_interval_changed?(chef_service_interval)
          puts "#{Time.now} yes..chef-service interval has been changed by the user..deleting and re-deploying the chef-service crontab with the new interval value of #{chef_service_interval} minutes frequency.."
          delete_cron
          deploy_cron(extension_root, bootstrap_directory, log_location, chef_service_interval)
        else
          puts "#{Time.now} no..chef-service interval has not been changed by the user..exiting.."
        end
        return [exit_code, message]
      end

      puts "#{Time.now} Starting chef-client service..."
      if windows?
        result = shell_out("sc.exe start chef-client")
        result.error!
      else
        deploy_cron(extension_root, bootstrap_directory, log_location, chef_service_interval)
      end
    rescue => e
      Chef::Log.error "#{error_message} (#{e})"
      message = "#{error_message} - #{e} - Check log file for details", "error"
      exit_code = 1
    end
    puts "#{Time.now} Started chef-client service." if exit_code == 0
    [exit_code, message]
  end

  def disable(log_location)
    log_location = log_location || bootstrap_directory
    exit_code = 0
    message = "success"
    error_message = "Error disabling chef-client service"
    if not is_running?
      puts "#{Time.now} chef-client service is already stopped..."
      return [exit_code, message]
    end

    begin
      puts "#{Time.now} Disabling chef-client service..."
      if windows?
        result = shell_out("sc.exe stop chef-client")
        result.error!
      else
        delete_cron
      end
    rescue => e
      Chef::Log.error "#{error_message} (#{e})"
      message = "#{error_message} - #{e} - Check log file for details", "error"
      exit_code = 1
    end
    puts "#{Time.now} Disabled chef-client service" if exit_code == 0
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
        result = shell_out("sc.exe query chef-client")
        if result.exitstatus == 0 and result.stdout.include?("RUNNING")
          return true
        else
          return false
        end
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
    rescue => e
      Chef::Log.error e
      message = "#{e} - Check log file for details", "error"
      raise
    end
    return false
  end
end
