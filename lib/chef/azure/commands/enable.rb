# This implements the azure extension 'enable' command.

require 'chef'
require 'chef/azure/helpers/shared'
require 'chef/azure/service'
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

  LINUX_CERT_PATH = "/var/lib/waagent/Certificates.pem"

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
    @exit_code, error_message = ChefService.new.enable(@chef_extension_root, bootstrap_directory, @azure_plugin_log_location)
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

      load_settings

      # run chef-client for first time with no runlist to register the node
      puts "Running chef client for first time with no runlist..."

      begin
        require 'chef/azure/core/bootstrap_context'
        config = {}
        config[:environment] = value_from_json_file(handler_settings_file,'runtimeSettings','0','handlerSettings', 'publicSettings', 'bootstrap_options','environment')
        config[:chef_node_name] = value_from_json_file(handler_settings_file,'runtimeSettings','0','handlerSettings', 'publicSettings', 'bootstrap_options','chef_node_name')
        config[:encrypted_data_bag_secret ] = value_from_json_file(handler_settings_file,'runtimeSettings','0','handlerSettings', 'publicSettings', 'bootstrap_options','encrypted_data_bag_secret')
        Chef::Config[:validation_key_content] = @validation_key
        Chef::Config[:chef_server_url] = value_from_json_file(handler_settings_file,'runtimeSettings','0','handlerSettings', 'publicSettings', 'bootstrap_options','chef_server_url')
        Chef::Config[:validation_client_name] = value_from_json_file(handler_settings_file,'runtimeSettings','0','handlerSettings', 'publicSettings', 'bootstrap_options','validation_client_name')

        if windows?
          context = Chef::Knife::Core::WindowsBootstrapContext.new(config, {}, Chef::Config)
          template_file = Gem.find_files(File.join("chef","azure","bootstrap","windows-chef-client-msi.erb")).first
          bootstrap_bat_file ||= "#{ENV['TMP']}/bootstrap.bat"
          template = IO.read(template_file).chomp
          bash_template = Erubis::Eruby.new(template).evaluate(context)
          File.open(bootstrap_bat_file, 'w') {|f| f.write(bash_template)}
          bootstrap_command = "cmd.exe /C #{bootstrap_bat_file}"
          # remove the temp bootstrap file
          FileUtils.rm(bootstrap_bat_file)
        else
          context = Chef::Knife::Core::BootstrapContext.new(config, {}, Chef::Config)
          template_file = Gem.find_files(File.join("chef","azure","bootstrap","chef-full.erb")).first
          template = IO.read(template_file).chomp
          bootstrap_command = Erubis::Eruby.new(template).evaluate(context)
        end

        result = shell_out(bootstrap_command)
        result.error!
      rescue Mixlib::ShellOut::ShellCommandFailed => e
        Chef::Log.warn "chef-client run - node registration failed (#{e})"
        @chef_client_error = "chef-client run - node registration failed (#{e})"
        return
      rescue => e
        Chef::Log.error e
        @chef_client_error = "chef-client run - node registration failed (#{e})"
        return
      end

      puts "Node registered successfully"
      File.open("#{bootstrap_directory}/node-registered", "w") do |file|
        file.write("Node registered.")
      end

      # Now the run chef-client with runlist in background, as we done want enable command to wait, else long running chef-client with runlist will timeout azure.
      puts "Launching chef-client again to set the runlist"
      params = "-c #{bootstrap_directory}/client.rb -j #{bootstrap_directory}/first-boot.json -E _default -L #{@azure_plugin_log_location}/chef-client.log --once "
      child_pid = Process.spawn "chef-client #{params}"
      Process.detach child_pid
      puts "Successfully launched chef-client process with PID [#{child_pid}]"
    end
  end

  def load_settings
    protected_settings = value_from_json_file(handler_settings_file,'runtimeSettings','0','handlerSettings', 'protectedSettings')
    @validation_key = get_validation_key(protected_settings)
    @client_rb = value_from_json_file(handler_settings_file, 'runtimeSettings', '0', 'handlerSettings', 'publicSettings', 'client_rb')
    @run_list = value_from_json_file(handler_settings_file, 'runtimeSettings', '0', 'handlerSettings', 'publicSettings', 'runlist')
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

  def override_clientrb_file(user_client_rb)
    client_rb = <<-CONFIG
client_key        '#{bootstrap_directory}/client.pem'
validation_key    '#{bootstrap_directory}/validation.pem'
log_location  '#{@azure_plugin_log_location}/chef-client.log'

# Add support to use chef Handlers for heartbeat and
# status reporting to Azure
require 'chef/azure/chefhandlers/start_handler'
require 'chef/azure/chefhandlers/report_handler'
require 'chef/azure/chefhandlers/exception_handler'

start_handlers << AzureExtension::StartHandler.new('#{@chef_extension_root}')
report_handlers << AzureExtension::ReportHandler.new('#{@chef_extension_root}')
exception_handlers << AzureExtension::ExceptionHandler.new('#{@chef_extension_root}')


CONFIG

    "#{user_client_rb}\r\n#{client_rb}"
  end

  def escape_runlist(run_list)
    parsedRunlist = []
    run_list.split(/,\s*|\s/).reject(&:empty?).each do |item|
      if(item.match(/\s*"?recipe\[\S*\]"?\s*/))
        run_list_item = item.split(/\s*"?'?recipe\["?'?|"?'?\]"?'?/)[1]
        parsedRunlist << "\"recipe[#{run_list_item}]\""
      elsif(item.match(/\s*"?role\[\S*\]"?\s*/))
        run_list_item = item.split(/\s*"?'?role\["?'?|"?'?\]"?'?/)[1]
        parsedRunlist << "\"role[#{run_list_item}]\""
      else
        item = item.match(/\s*"?'?\[?"?'?(?<itm>\S*[^\p{Punct}])"?'?\]?"?'?\s*/)[:itm]
        parsedRunlist << "\"recipe[#{item}]\""
      end
    end
    parsedRunlist.join(",")
  end

  def get_validation_key(encrypted_text)
    if windows?
      decrypt_content_file_path = File.expand_path(File.dirname(File.dirname(__FILE__)))
      decrypt_content_file_path += "\\helpers\\powershell\\decrypt_content_on_windows.ps1"
      thumb_print = value_from_json_file(handler_settings_file,'runtimeSettings','0','handlerSettings', 'protectedSettingsCertThumbprint')
      result= shell_out("powershell.exe -nologo -noprofile -executionpolicy \"unrestricted\" -file #{decrypt_content_file_path} #{thumb_print} #{encrypted_text}")
      decrypted_text = result.stdout
      result.error!
    else

      certificate_path = LINUX_CERT_PATH

      # read cert & get key from the certificate
      certificate = OpenSSL::X509::Certificate.new File.read(certificate_path)
      private_key = OpenSSL::PKey::RSA.new File.read(certificate_path)

      # decrypt text
      encrypted_text = Base64.decode64(encrypted_text)
      encrypted_text = OpenSSL::PKCS7.new(encrypted_text)
      decrypted_text = encrypted_text.decrypt(private_key, certificate)
    end

    #extract validation_key from decrypted hash
    validation_key = value_from_json_file(decrypted_text, "validation_key")
    return validation_key
  end
end
