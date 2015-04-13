$:.unshift File.expand_path('../../lib', __FILE__)

require 'chef/azure/heartbeat'
require 'chef/azure/status'


def mock_data(file_name)
    file =  File.expand_path(File.dirname("spec/assets/*"))+"/#{file_name}"
    File.read(file)
end
