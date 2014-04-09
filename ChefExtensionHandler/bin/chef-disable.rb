
# Ruby code that runs the original chef-client and updates the azure extension status

require 'chef/azure/commands/disable'

extension_root = File.expand_path(File.dirname(File.dirname(__FILE__)))
puts "extension_root --> #{extension_root}"

chef_disable_args = ARGV

puts "Creating DisableChef object with #{chef_disable_args}..."
command = DisableChef.new(extension_root, chef_disable_args)

puts "Running Chef extension disable command..."
exit_code = command.run
exit exit_code
