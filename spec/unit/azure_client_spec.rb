require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require 'chef/azure/client'

describe AzureChefClient do
  let (:extension_root) { "./" }
  let (:chef_client_args) { [] }
  let (:instance) { AzureChefClient.new(extension_root, chef_client_args) }

  it { expect {instance}.to_not raise_error }
end

