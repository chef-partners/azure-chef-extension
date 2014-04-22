require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require 'chef/azure/commands/disable'

describe DisableChef do
  let (:extension_root) { "./" }
  let (:enable_args) { [] }
  let (:instance) { DisableChef.new(extension_root, enable_args) }

  it { expect {instance}.to_not raise_error }

  context "run" do
    it "disables chef" do
      instance.should_receive(:load_env)
      instance.should_receive(:report_heart_beat_to_azure).twice
      instance.should_receive(:disable_chef)
      instance.run
    end
  end

  context "load_env" do
    it "loads azure specific environment configurations from config file." do
      instance.should_receive(:read_config)
      instance.send(:load_env)
    end
  end

  context "disable_chef" do
    it "disables chef service and returns the status to azure with success." do
      instance.should_receive(:report_status_to_azure).with("chef-service disabled", "success")
      ChefService.stub_chain(:new, :disable).and_return(0)
      instance.send(:disable_chef)
    end

    it "disables chef service and returns the status to azure with error." do
      instance.should_receive(:report_status_to_azure).with("chef-service disable failed - ", "error")
      ChefService.stub_chain(:new, :disable).and_return(1)
      instance.send(:disable_chef)
    end
  end
end