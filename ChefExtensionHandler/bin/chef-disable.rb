
# Ruby code that runs the original chef-client and updates the azure extension status

require 'chef/azure/commands/disable'
require 'chef/azure/commands/enable'
include ChefAzure::Shared
include ChefAzure::Config
include ChefAzure::Reporting

extension_root = File.expand_path(File.dirname(File.dirname(__FILE__)))
puts "extension_root --> #{extension_root}"

chef_disable_args = ARGV

#Delete .auto_update_false file if it already exists
File.delete("C:/chef/.auto_update_false") if File.exist?("C:/chef/.auto_update_false")

#Get handler settings file
@azure_heart_beat_file, @azure_status_folder, @azure_plugin_log_location, @azure_config_folder, @azure_status_file = read_config(extension_root)
files = Dir.glob("#{File.expand_path(@azure_config_folder)}/*.settings").sort
handler_settings_file = files.last if files and not files.empty?

if windows?
  total_extension_folders = Dir.entries("C:/Packages/Plugins/Chef.Bootstrap.WindowsAzure.ChefClient").select {|f| !File.directory? f}.count
end

#If total_extension_folders > 1 and disable is called from an old extension version, that means disable is called from Update
if (total_extension_folders > 1 && extension_root != find_highest_extension_version(extension_root))
  auto_update_client = value_from_json_file(handler_settings_file,'runtimeSettings','0','handlerSettings', 'publicSettings', 'autoUpdateClient')

  if(auto_update_client != "true")
    puts "Not doing extension disable as autoUpdateClient=false"
    File.write("C:/chef/.auto_update_false", "autoUpdateClient=false")
    report_heart_beat_to_azure(AzureHeartBeat::READY, 0, "chef-service is enabled. Update failed as autoUpdateClient=false")
    report_status_to_azure "chef-service enabled. Update failed as autoUpdateClient=false", "success"
    exit
  end
end

puts "Creating DisableChef object with #{chef_disable_args}..."
command = DisableChef.new(extension_root, chef_disable_args)

puts "Running Chef extension disable command..."
exit_code = command.run
exit exit_code

