require 'chef/azure/helpers/shared'
require 'chef/azure/helpers/erb'

class ChefService
  include Chef::Mixin::ShellOut
  include ChefAzure::Shared
  AZURE_CHEF_SERVICE_PID_FILE = "azure-chef-client.pid"
  AZURE_CHEF_CRON_NAME = 'azure_chef_extension'
  DEFAULT_CHEF_SERVICE_INTERVAL = 30
  CLIENT_RB_INTERVAL_ATTRIBUTE_NAME = 'interval'

  def enable(extension_root, log_location, chef_service_interval = DEFAULT_CHEF_SERVICE_INTERVAL)
    log_location = log_location || bootstrap_directory
    exit_code = 0
    message = "success"
    error_message = "Error enabling chef-client service"
    begin
      puts "#{Time.now} Getting chef-client service status"
      if is_installed?
        puts "#{Time.now} chef-client service is already installed."
        if chef_service_interval_changed?(chef_service_interval, "#{bootstrap_directory}\\client.rb")
          puts "#{Time.now} yes..chef-client service interval has been changed by the user..updating the interval value to #{chef_service_interval} minutes."
          if windows?
            add_or_update_interval_in_client_rb("#{bootstrap_directory}\\client.rb", interval_in_seconds(chef_service_interval))
            enable_service('stop', bootstrap_directory, log_location) if is_running?
            enable_service('start', bootstrap_directory, log_location)
          else
            disable_cron
            enable_cron(extension_root, bootstrap_directory, log_location, chef_service_interval)
          end
        else
          puts "#{Time.now} no..chef-client service interval has not been changed by the user..exiting."
        end
      else
        if windows?
          add_or_update_interval_in_client_rb("#{bootstrap_directory}\\client.rb", interval_in_seconds(chef_service_interval))
          enable_service('install', bootstrap_directory, log_location)
          enable_service('start', bootstrap_directory, log_location) if !is_running?
        else
          enable_cron(extension_root, bootstrap_directory, log_location, chef_service_interval)
        end
      end
    rescue => e
      Chef::Log.error "#{error_message} (#{e})"
      message = "#{error_message} - #{e} - Check log file for details", "error"
      exit_code = 1
    end
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
      windows? ? disable_service : disable_cron
    rescue => e
      Chef::Log.error "#{error_message} (#{e})"
      message = "#{error_message} - #{e} - Check log file for details", "error"
      exit_code = 1
    end
    puts "#{Time.now} Disabled chef-client service" if exit_code == 0
    [exit_code, message]
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

  def add_or_update_interval_in_client_rb(client_rb, new_chef_service_interval)
    client_rb_contents = read_client_rb(client_rb)

    if interval_exist?(client_rb_contents)
      interval = interval_index(client_rb_contents)
      client_rb_contents[interval] = interval_string(new_chef_service_interval)
    else
      client_rb_contents << interval_string(new_chef_service_interval)
    end

    write_client_rb(client_rb, client_rb_contents.join)
  end

  def disable_service
    result = shell_out("sc.exe stop chef-client")
    result.error!
  end

  def disable_cron
    templates_dir = File.join(File.dirname(__FILE__), "/templates")
    chef_cron = ERBHelpers::ERBCompiler.run(File.read(File.join(templates_dir, "chef-client-cron-delete.erb")), {:name => AZURE_CHEF_CRON_NAME})

    puts "Removing chef-cron = \"#{chef_cron}\""
    result = shell_out("chef-apply -e \"#{chef_cron}\"")
    result.error!
  end

  private
  def enable_service(action, bootstrap_directory, log_location)
    puts "#{Time.now} #{action.capitalize}ing chef-client service..."
    params = " -a #{action} -c #{bootstrap_directory}\\client.rb -L #{log_location}\\chef-client.log "
    result = shell_out("chef-service-manager #{params}")
    result.error? ? result.error! : (puts "#{Time.now} #{action.capitalize}ed chef-client service.")
  end

  def enable_cron(extension_root, bootstrap_directory, log_location, chef_service_interval)
    # Unix like platform
    puts "#{Time.now} Starting chef-client service..."
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
    result.error? ? result.error! : (puts "#{Time.now} Started chef-client service...")
  end

  def is_installed?
    if windows?
      status = shell_out("sc.exe query chef-client")
      !(status.exitstatus == 1060 && status.stdout.include?("The specified service does not exist as an installed service."))
    else
      is_running?
    end
  end

  def read_client_rb(client_rb)
    File.readlines(client_rb)
  end

  def interval_exist?(client_rb_contents)
    client_rb_contents.any? { |line| line.include?(CLIENT_RB_INTERVAL_ATTRIBUTE_NAME + ' ') }
  end

  def interval_index(client_rb_contents)
    client_rb_contents.index { |line| line.include?(CLIENT_RB_INTERVAL_ATTRIBUTE_NAME + ' ') }
  end

  def interval_string(chef_service_interval)
    "#{CLIENT_RB_INTERVAL_ATTRIBUTE_NAME} #{chef_service_interval}\n"
  end

  def write_client_rb(client_rb, client_rb_contents)
    File.write(client_rb, client_rb_contents)
  end

  def interval_in_seconds(chef_service_interval)
    chef_service_interval * 60
  end

  def interval_in_minutes(chef_service_interval)
    chef_service_interval / 60
  end

  def old_client_rb_interval(old_interval_string)
    old_interval_string.split(' ')[1].strip.to_i
  end

  def chef_service_interval_changed?(new_chef_service_interval, client_rb = nil)
    puts "#{Time.now} checking if chef-client service interval has been changed by the user..."

    if windows?
      client_rb_contents = read_client_rb(client_rb)

      if interval_exist?(client_rb_contents)
        interval = interval_index(client_rb_contents)
        old_chef_service_interval = interval_in_minutes(
          old_client_rb_interval(client_rb_contents[interval])
        )
      else
        old_chef_service_interval = DEFAULT_CHEF_SERVICE_INTERVAL
      end
    else
      result = shell_out("crontab -l | grep -A 1 #{AZURE_CHEF_CRON_NAME} | sed -n '2p'")
      old_chef_service_interval = result.stdout.split('/')[1].split(' ')[0].to_i
    end

    old_chef_service_interval != new_chef_service_interval ? true : false
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
end
