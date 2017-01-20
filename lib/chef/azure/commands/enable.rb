# This implements the azure extension 'enable' command.

require 'chef'
require 'chef/azure/helpers/shared'
require 'chef/azure/service'
require 'chef/azure/task'
require 'chef/azure/helpers/parse_json'
require 'openssl'
require 'base64'
require 'tempfile'
require 'chef/azure/core/windows_bootstrap_context'
require 'erubis'
require 'chef/knife'

class EnableChef
  include Chef::Mixin::ShellOut
  include ChefAzure::Shared
  include ChefAzure::Config
  include ChefAzure::Reporting

  LINUX_CERT_PATH = "/var/lib/waagent"

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
      if @chef_client_error
        report_heart_beat_to_azure(AzureHeartBeat::READY, 0, "chef-service is enabled. Chef client run failed with error- #{@chef_client_error}")
      else
        report_heart_beat_to_azure(AzureHeartBeat::READY, 0, "chef-service is enabled.")
      end
    else
      if @chef_client_error
        report_heart_beat_to_azure(AzureHeartBeat::NOTREADY, 0, "chef-service enable failed. Chef client run failed with error- #{@chef_client_error}")
      else
        report_heart_beat_to_azure(AzureHeartBeat::NOTREADY, 0, "chef-service enable failed.")
      end
    end

    if @extended_logs == 'true' && !@child_pid.nil?
      fetch_chef_client_logs
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

      if @exit_code == 0
        report_status_to_azure("chef-extension enabled", "success")
        daemon = value_from_json_file(handler_settings_file, 'runtimeSettings', '0', 'handlerSettings', 'publicSettings', 'daemon')
        daemon = "service" if (daemon.nil? || daemon.empty?)
        if(daemon == "service" || !windows?)
          enable_chef_service
        elsif daemon == "task" && windows?
          enable_chef_sch_task
        end
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

  def load_chef_service_interval
    value_from_json_file(handler_settings_file, 'runtimeSettings', '0', 'handlerSettings', 'publicSettings', 'chef_service_interval')
  end

  def update_chef_status(option_name, disable_flag)
    if @exit_code == 0
      disable_flag ?
        report_status_to_azure("chef-#{option_name} disabled", "success") :
        report_status_to_azure("chef-#{option_name} enabled", "success")
    else
      disable_flag ?
        report_status_to_azure("chef-#{option_name} disable failed - #{error_message}", "error") :
        report_status_to_azure("chef-#{option_name} enable failed - #{error_message}", "error")
    end
  end

  def enable_chef_service
    chef_service = ChefService.new
    chef_service_interval = load_chef_service_interval
    disable_flag = false

    ## enable chef-service with default value for interval as user has not provided the value ##
    if chef_service_interval.empty?
      @exit_code, error_message = chef_service.enable(
        @chef_extension_root,
        bootstrap_directory,
        @azure_plugin_log_location
      )
    else
      ## disable chef-service as per the user's choice ##
      if chef_service_interval.to_i == 0
        @exit_code, error_message = chef_service.disable(
          @azure_plugin_log_location,
          bootstrap_directory,
          chef_service_interval.to_i
        )
        disable_flag = true
      else
        ## enable chef-service with user provided value for interval ##
        raise 'Invalid value for chef_service_interval option.' if chef_service_interval.to_i < 0

        @exit_code, error_message = chef_service.enable(
          @chef_extension_root,
          bootstrap_directory,
          @azure_plugin_log_location,
          chef_service_interval.to_i
        )
      end
    end

    update_chef_status("service", disable_flag)
    @exit_code
  end

  def enable_chef_sch_task
    chef_task = ChefTask.new
    chef_service_interval = load_chef_service_interval
    disable_flag = false

    ## enable chef-sch-task with default value for interval as user has not provided the value ##
    if chef_service_interval.empty?
      @exit_code, error_message = chef_task.enable(
        bootstrap_directory,
        @azure_plugin_log_location
      )
    else
      ## disable chef-sch-task as per the user's choice ##
      if chef_service_interval.to_i == 0
        @exit_code, error_message = chef_task.disable
        disable_flag = true
      else
        ## enable chef-sch-task with user provided value for interval ##
        raise 'Invalid value for chef_service_interval option.' if chef_service_interval.to_i < 0

        @exit_code, error_message = chef_task.enable(
          bootstrap_directory,
          @azure_plugin_log_location,
          chef_service_interval.to_i
        )
      end
    end

    update_chef_status("sch-task", disable_flag)
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

      puts "#{Time.now} Creating chef configuration files"

      copy_settings_file

      load_settings

      begin
        require 'chef/azure/core/bootstrap_context'
        config = {}
        bootstrap_options = value_from_json_file(handler_settings_file,'runtimeSettings','0','handlerSettings', 'publicSettings', 'bootstrap_options')
        bootstrap_options = eval(bootstrap_options) ? eval(bootstrap_options) : {}

        config[:environment] = bootstrap_options['environment'] || "_default"
        config[:chef_node_name] = bootstrap_options['chef_node_name'] if bootstrap_options['chef_node_name']
        config[:chef_extension_root] = @chef_extension_root
        config[:user_client_rb] = @client_rb
        config[:log_location] = @azure_plugin_log_location
        Chef::Config[:validation_key_content] = @validation_key
        Chef::Config[:client_key_content] = @client_key
        Chef::Config[:chef_server_ssl_cert_content] = @chef_server_ssl_cert
        config[:chef_server_url] = bootstrap_options['chef_server_url'] if bootstrap_options['chef_server_url']
        config[:validation_client_name] =  bootstrap_options['validation_client_name'] if bootstrap_options['validation_client_name']
        template_file = File.expand_path(File.dirname(File.dirname(__FILE__)))
        config[:secret] =  @secret
        config[:node_verify_api_cert] =  bootstrap_options['node_verify_api_cert'] if bootstrap_options['node_verify_api_cert']
        config[:node_ssl_verify_mode] =  bootstrap_options['node_ssl_verify_mode'] if bootstrap_options['node_ssl_verify_mode']
        runlist = @run_list.empty? ? [] : escape_runlist(@run_list)
        load_cloud_attributes_in_hints if ! @ohai_hints.empty?
        config[:first_boot_attributes] = @first_boot_attributes

        if windows?
          context = Chef::Knife::Core::WindowsBootstrapContext.new(config, runlist, Chef::Config, config[:secret])
          template_file += "\\bootstrap\\windows-chef-client-msi.erb"
          bootstrap_bat_file ||= "#{ENV['TMP']}/bootstrap.bat"
          template = IO.read(template_file).chomp
          bash_template = Erubis::Eruby.new(template).evaluate(context)
          File.open(bootstrap_bat_file, 'w') {|f| f.write(bash_template)}
          bootstrap_command = "cmd.exe /C #{bootstrap_bat_file}"

          result = shell_out(bootstrap_command)
          result.error!
          puts "#{Time.now} Created chef configuration files"
          # remove the temp bootstrap file
          FileUtils.rm(bootstrap_bat_file)
        else
          context = Chef::Knife::Core::BootstrapContext.new(config, runlist, Chef::Config, config[:secret])
          template_file += '/bootstrap/chef-full.erb'
          template = IO.read(template_file).chomp
          bootstrap_command = Erubis::Eruby.new(template).evaluate(context)
          result = shell_out(bootstrap_command)
          result.error!
          puts "#{Time.now} Created chef configuration files"
        end
      rescue Mixlib::ShellOut::ShellCommandFailed => e
        Chef::Log.warn "chef-client configuration files creation failed (#{e})"
        @chef_client_error = "chef-client configuration files creation failed (#{e})"
        return
      rescue => e
        Chef::Log.error e
        @chef_client_error = "chef-client configuration files creation failed (#{e})"
        return
      end
      # Now the run chef-client with runlist in background, as we done want enable command to wait, else long running chef-client with runlist will timeout azure.
      puts "#{Time.now} Launching chef-client to register node with the runlist"
      params = "-c #{bootstrap_directory}/client.rb -j #{bootstrap_directory}/first-boot.json -E #{config[:environment]} -L #{@azure_plugin_log_location}/chef-client.log --once "
      if @extended_logs == 'true'
        if windows?
          @chef_client_success_file = "c:\\chef_client_success"
        else
          @chef_client_success_file = "/tmp/chef_client_success"
        end
        @child_pid = Process.spawn "chef-client #{params} && touch #{@chef_client_success_file}"
        @chef_client_run_start_time = Time.now
      else
        @child_pid = Process.spawn "chef-client #{params}"
      end
      Process.detach @child_pid
      puts "#{Time.now} Successfully launched chef-client process with PID [#{@child_pid}]"
    end
  end

  def chef_client_log_path
    chef_config
    @chef_config[:log_location] ? @chef_config[:log_location] : "#{@azure_plugin_log_location}/chef-client.log"
  end

  def fetch_chef_client_logs
    ## set path for the script which waits for the first chef-client run to complete
    ## or till maximum wait timeout of 30 minutes and then later reads logs from
    ## chef-client.log and writes into 0.status file. These chef-client logs from
    ## 0.status file are queried & displayed by knife-azure plugin during server
    ## create to give end-user the detailed overview of the chef-client run happened
    ## after Chef Extension installation.
    logs_script_path = File.join(@chef_extension_root, "/bin/chef_client_logs.rb")

    logs_script_pid = Process.spawn("ruby #{logs_script_path} #{@child_pid} \"#{@chef_client_run_start_time}\" #{chef_client_log_path} #{@azure_status_file} #{bootstrap_directory} #{@chef_client_success_file}")

    Process.detach(logs_script_pid)
    puts "#{Time.now} Successfully launched chef_client_run logs collection script process with PID [#{logs_script_pid}]"
  end

  def load_cloud_attributes_in_hints
    cloud_attributes = {}
    hints = eval(@ohai_hints)
    hints.each do |key, value|
      cloud_attributes[key] = value
    end
    Chef::Config[:knife][:hints] ||= {}
    Chef::Config[:knife][:hints]["azure"] ||= cloud_attributes
  end

  def load_settings
    encrypted_protected_settings = value_from_json_file(handler_settings_file,'runtimeSettings','0','handlerSettings', 'protectedSettings')
    decrypted_protected_settings = get_decrypted_key(encrypted_protected_settings)
    validation_key_format = value_from_json_file(handler_settings_file,'runtimeSettings','0','handlerSettings', 'publicSettings', 'validation_key_format')
    @validation_key = get_validation_key(decrypted_protected_settings, validation_key_format)
    @client_key = get_client_key(decrypted_protected_settings)
    @chef_server_ssl_cert = get_chef_server_ssl_cert(decrypted_protected_settings)
    @secret = secret_key(decrypted_protected_settings)
    @client_rb = value_from_json_file(handler_settings_file, 'runtimeSettings', '0', 'handlerSettings', 'publicSettings', 'client_rb')
    @run_list = value_from_json_file(handler_settings_file, 'runtimeSettings', '0', 'handlerSettings', 'publicSettings', 'runlist')
    @extended_logs = value_from_json_file(handler_settings_file, 'runtimeSettings', '0', 'handlerSettings', 'publicSettings', 'extendedLogs')
    @ohai_hints = value_from_json_file(handler_settings_file, 'runtimeSettings', '0', 'handlerSettings', 'publicSettings', 'hints')
    @first_boot_attributes = JSON.parse(value_from_json_file(handler_settings_file, 'runtimeSettings', '0', 'handlerSettings', 'publicSettings', 'custom_json_attr').gsub("=>", ":")) rescue nil || {}
  end

  def handler_settings_file
    @handler_settings_file ||=
    begin
      files = Dir.glob("#{File.expand_path(@azure_config_folder)}/*.settings").sort
      if files and not files.empty?
        files.last
      else
        error_message = "Configuration error. Azure chef extension Settings file missing."
        Chef::Log.error error_message
        report_status_to_azure error_message, "error"
        @exit_code = 1
        raise error_message
      end
    end
  end

  def escape_runlist(run_list)
    parsedRunlist = []
    run_list.split(/,\s*|\s/).reject(&:empty?).each do |item|
      if(item.match(/\s*"?recipe\[\S*\]"?\s*/))
        run_list_item = item.split(/\s*"?'?recipe\["?'?|"?'?\]"?'?/)[1]
        parsedRunlist << "recipe[#{run_list_item}]"
      elsif(item.match(/\s*"?role\[\S*\]"?\s*/))
        run_list_item = item.split(/\s*"?'?role\["?'?|"?'?\]"?'?/)[1]
        parsedRunlist << "role[#{run_list_item}]"
      else
        item = item.match(/\s*"?'?\[?"?'?(?<itm>\S*[^\p{Punct}])"?'?\]?"?'?\s*/)[:itm]
        parsedRunlist << "recipe[#{item}]"
      end
    end
    parsedRunlist
  end

  def get_validation_key(decrypted_text, validation_key_format)
    #extract validation_key from decrypted hash
    validation_key = value_from_json_file(decrypted_text, "validation_key")
    begin
      validation_key = Base64.decode64(validation_key) if(validation_key_format == "base64encoded")
      validation_key = OpenSSL::PKey::RSA.new(validation_key.squeeze("\n")).to_pem
    rescue OpenSSL::PKey::RSAError => e
      Chef::Log.error "Chef validation key parsing error. #{e.inspect}"
    end
    validation_key.delete("\x00")
  end

  def get_client_key(decrypted_text)
    #extract client_key from decrypted hash
    client_key = value_from_json_file(decrypted_text, "client_pem")
    begin
      client_key = OpenSSL::PKey::RSA.new(client_key.squeeze("\n")).to_pem
    rescue OpenSSL::PKey::RSAError => e
      Chef::Log.error "Chef client key parsing error. #{e.inspect}"
    end
    client_key
  end

  def get_chef_server_ssl_cert(decrypted_text)
    #extract chef_server_ssl_cert from decrypted hash
    chef_server_ssl_cert = value_from_json_file(decrypted_text, "chef_server_crt")
    begin
      chef_server_ssl_cert = OpenSSL::X509::Certificate.new(chef_server_ssl_cert.squeeze("\n")).to_pem
    rescue OpenSSL::X509::CertificateError => e
      Chef::Log.error "Chef Server SSL certificate parsing error. #{e.inspect}"
    end
    chef_server_ssl_cert
  end

  def secret_key(decrypted_text)
    #extract secret from decrypted hash
    secret = value_from_json_file(decrypted_text, "secret").empty? ?
      value_from_json_file(decrypted_text, "encrypted_data_bag_secret") :
      value_from_json_file(decrypted_text, "secret")
    if secret.empty?
      nil
    else
      begin
        secret = OpenSSL::PKey::RSA.new(secret.squeeze("\n")).to_pem
      rescue OpenSSL::PKey::RSAError => e
        Chef::Log.error "Secret key parsing error. #{e.inspect}"
      end
      secret
    end
  end

  def get_decrypted_key(encrypted_text)
    thumbprint = value_from_json_file(handler_settings_file,'runtimeSettings','0','handlerSettings', 'protectedSettingsCertThumbprint')
    if windows?
      decrypt_content_file_path = File.expand_path(File.dirname(File.dirname(__FILE__)))
      decrypt_content_file_path += "\\helpers\\powershell\\decrypt_content_on_windows.ps1"
      shell_out!('mode con:cols=300 lines=600')
      result= shell_out("powershell.exe -nologo -noprofile -executionpolicy \"unrestricted\" -file #{decrypt_content_file_path} #{thumbprint} #{encrypted_text}")
      decrypted_text = result.stdout
      result.error!
    else
      cert_path = "#{LINUX_CERT_PATH}/#{thumbprint}.crt"
      private_key_path = "#{LINUX_CERT_PATH}/#{thumbprint}.prv"

      # read cert & get key from the certificate
      if File.exists?(cert_path) && File.exists?(private_key_path)
        certificate = OpenSSL::X509::Certificate.new File.read(cert_path)
        private_key = OpenSSL::PKey::RSA.new File.read(private_key_path)
        # decrypt text
        encrypted_text = Base64.decode64(encrypted_text)
        encrypted_text = OpenSSL::PKCS7.new(encrypted_text)
        decrypted_text = encrypted_text.decrypt(private_key, certificate)
      end
    end
    decrypted_text
  end

  def copy_settings_file
    settings_file = handler_settings_file
    Chef::Log.info "Settigs file ...#{settings_file}"
    if File.exists?(handler_settings_file)
      Chef::Log.info "Copying setting file to #{bootstrap_directory}"
      FileUtils.cp(settings_file, bootstrap_directory)
    end
  end
end
