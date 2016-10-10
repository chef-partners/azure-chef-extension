$:.unshift File.expand_path('../../lib', __FILE__)

require 'chef/azure/heartbeat'
require 'chef/azure/status'


def mock_data(file_name)
    file =  File.expand_path(File.dirname("spec/assets/*"))+"/#{file_name}"
    File.read(file)
end

def chef_11?
  Chef::VERSION.split('.').first.to_i == 11
end

def chef_12?
  Chef::VERSION.split('.').first.to_i == 12
end

def is_windows?
  (/cygwin|mswin|mingw|bccwin|wince|emx/ =~ RUBY_PLATFORM) != nil
end

RSpec.configure do |config|
  config.filter_run_excluding :chef_12_only => true if :chef_12?
  config.filter_run_excluding :windows_only => true unless is_windows?
  config.filter_run_excluding :linux_only => true if is_windows?
end
