
# Ruby code that runs the original chef-client and updates the azure extension status

require 'chef/azure/commands/enable'

extension_root = File.expand_path(File.dirname(File.dirname(__FILE__)))
puts "#{Time.now} extension_root --> #{extension_root}"

chef_enable_args = ARGV

if(File.exist?('/etc/chef/.auto_update_false') || File.exist?('C:/chef/.auto_update_false'))
  puts "Not doing enable since autoUpdateClient=false"
  report_status_to_azure "chef-service enabled. Update failed as autoUpdateClient=false", "success"
  report_heart_beat_to_azure(AzureHeartBeat::READY, 0, "chef-service is enabled. Update failed as autoUpdateClient=false")
  exit 1
else
  puts "#{Time.now} Creating EnableChef object with #{chef_enable_args}..."
  command = EnableChef.new(extension_root, chef_enable_args)

  puts "#{Time.now} Running Chef extension enable command..."
  exit_code = command.run
  exit exit_code
end
