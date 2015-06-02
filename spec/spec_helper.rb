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

RSpec.configure do |config|
  config.filter_run_excluding :chef_12_only => true if :chef_12?
end
