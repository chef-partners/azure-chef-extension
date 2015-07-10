require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require 'chef/azure/commands/disable'
require 'tmpdir'
require 'ostruct'

# This testcase verify enable command creates chef configuration files properly
describe "DisableChef" do
  let (:extension_root) { "./" }
  let (:enable_args) { [] }
  let (:instance) { DisableChef.new(extension_root, enable_args) }

  before(:all) do
    @temp_directory = Dir.mktmpdir("disable_chef_logs")
  end

  after(:all) do
    # Clear the temp directory upon exit
    FileUtils::remove_dir(@temp_directory) if Dir.exists?(@temp_directory)
  end

  context "for windows" do
    it "disables chef service if it's not already stopped" do
      allow(instance).to receive(:puts)
      allow(instance).to receive(:load_env)
      allow(instance).to receive(:report_heart_beat_to_azure)
      allow(instance).to receive(:report_status_to_azure)
      allow_any_instance_of(ChefService).to receive(:puts)
      allow_any_instance_of(ChefService).to receive(:bootstrap_directory).and_return(@temp_directory)
      allow_any_instance_of(ChefService).to receive(:is_running?).and_return(true)
      allow_any_instance_of(ChefService).to receive(:windows?).and_return(true)
      expect_any_instance_of(ChefService).to receive(:shell_out).with("sc.exe stop chef-client").and_return(OpenStruct.new(:exitstatus => 0, :stdout => "", :error => nil))
      instance.run
    end

    it "does nothing if chef service is already stopped" do
      allow(instance).to receive(:puts)
      allow(instance).to receive(:load_env)
      allow(instance).to receive(:report_heart_beat_to_azure)
      allow(instance).to receive(:report_status_to_azure)
      allow_any_instance_of(ChefService).to receive(:puts)
      allow_any_instance_of(ChefService).to receive(:bootstrap_directory).and_return(@temp_directory)
      allow_any_instance_of(ChefService).to receive(:is_running?).and_return(false)
      expect_any_instance_of(ChefService).to receive(:disable).and_return([0, "success"])
      instance.run
    end
  end

  context "for linux" do
    it "disables chef service if it's not already stopped" do
      allow(instance).to receive(:puts)
      allow(instance).to receive(:load_env)
      allow(instance).to receive(:report_heart_beat_to_azure)
      allow(instance).to receive(:report_status_to_azure)
      allow_any_instance_of(ChefService).to receive(:puts)
      allow_any_instance_of(ChefService).to receive(:bootstrap_directory).and_return(@temp_directory)
      allow_any_instance_of(ChefService).to receive(:is_running?).and_return(true)
      allow_any_instance_of(ChefService).to receive(:windows?).and_return(false)
      expect_any_instance_of(ChefService).to receive(:shell_out).with("chef-apply -e \"cron  'azure_chef_extension' do\n  action :delete\nend\n\"").and_return(OpenStruct.new(:exitstatus => 0, :stdout => "", :error => nil))
      instance.run
    end
  end
end