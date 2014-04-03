
# Ruby code that runs the original chef-client and updates the azure extension status

require 'chef/azure/commands/enable'

extension_root = File.expand_path(File.dirname(File.dirname(__FILE__)))
puts "extension_root --> #{extension_root}"

chef_enable_args = ARGV

puts "Creating EnableChef object with #{chef_enable_args}..."
command = EnableChef.new(extension_root, chef_enable_args)

puts "Running Chef extension enable command..."
exit_code = command.run
exit exit_code
