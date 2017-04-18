
# Ruby code that runs the original chef-client and updates the azure extension status
if RUBY_PLATFORM =~ /mswin|mingw|windows/
  sleep(30)
end

require 'chef/azure/commands/enable'

extension_root = File.expand_path(File.dirname(File.dirname(__FILE__)))
puts "#{Time.now} extension_root --> #{extension_root}"

chef_enable_args = ARGV

puts "#{Time.now} Creating EnableChef object with #{chef_enable_args}..."
command = EnableChef.new(extension_root, chef_enable_args)

puts "#{Time.now} Running Chef extension enable command..."
exit_code = command.run
exit exit_code
