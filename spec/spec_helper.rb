$:.unshift File.expand_path('../../lib', __FILE__)

require 'chef/azure/client'
require 'chef/azure/heartbeat'
require 'chef/azure/status'
