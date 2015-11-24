
# Ruby code that runs the original chef-client and updates the azure extension status

require 'chef/azure/commands/disable'

extension_root = File.expand_path(File.dirname(File.dirname(__FILE__)))
puts "extension_root --> #{extension_root}"

chef_disable_args = ARGV

if(File.exist?('/etc/chef/.auto_update_false') || File.exist?('C:/chef/.auto_update_false'))
  puts "Not doing disable since autoUpdateClient=false"
  report_status_to_azure "chef-service enabled. Update failed as autoUpdateClient=false", "success"
  report_heart_beat_to_azure(AzureHeartBeat::READY, 0, "chef-service is enabled. Update failed as autoUpdateClient=false")
  exit 1
else
  puts "Creating DisableChef object with #{chef_disable_args}..."
  command = DisableChef.new(extension_root, chef_disable_args)

  puts "Running Chef extension disable command..."
  exit_code = command.run
  exit exit_code
end
