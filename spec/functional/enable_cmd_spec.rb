require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require 'chef/azure/commands/enable'
require 'tmpdir'
require 'ostruct'

# This testcase verify enable command creates chef configuration files properly
describe "EnableChef" do
  let (:extension_root) { "./" }
  let (:enable_args) { [] }
  let (:instance) { EnableChef.new(extension_root, enable_args) }

  before(:all) do
    @temp_directory = Dir.mktmpdir("chef")
  end

  after(:all) do
    # Clear the temp directory upon exit
    FileUtils::remove_dir(@temp_directory) if Dir.exists?(@temp_directory)
  end

  context "for windows", :windows_only do
    it "creates chef configuration files" do
      allow(instance).to receive(:puts)
      allow(instance).to receive(:load_env)
      allow(instance).to receive(:report_heart_beat_to_azure)
      allow(File).to receive(:exists?).and_return(false)
      allow(instance).to receive(:bootstrap_directory).and_return(@temp_directory)
      allow(instance).to receive(:copy_settings_file)
      allow(instance).to receive(:load_cloud_attributes_in_hints)
      allow(instance).to receive(:handler_settings_file).and_return(mock_data("handler_settings.settings"))
      allow(instance).to receive(:get_validation_key).and_return("validation_key")
      allow(instance).to receive(:get_client_key).and_return("")
      allow(instance).to receive(:get_chef_server_ssl_cert).and_return("")
      allow(instance).to receive(:secret_key).and_return("")
      allow(instance).to receive(:windows?).and_return(true)
      allow_any_instance_of(Chef::Knife::Core::WindowsBootstrapContext).to receive(:bootstrap_directory).and_return(@temp_directory)
      allow_any_instance_of(Chef::Knife::Core::WindowsBootstrapContext).to receive(:start_chef).and_return(true)
      allow(instance).to receive(:install_chef_service)
      allow(instance).to receive(:enable_chef_service)
      allow(Process).to receive(:spawn)
      allow(Process).to receive(:detach)
      instance.run

      # verifying chef configuration files
      expect(File.file? "#{@temp_directory}/client.rb").to be(true)
      expect(File.file? "#{@temp_directory}/first-boot.json").to be(true)
      expect(File.file? "#{@temp_directory}/validation.pem").to be(true)
    end
  end
end