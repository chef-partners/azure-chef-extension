require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require 'chef/azure/commands/enable'
require 'ostruct'

describe EnableChef do
  let (:extension_root) { "./" }
  let (:enable_args) { [] }
  let (:instance) { EnableChef.new(extension_root, enable_args) }

  it { expect {instance}.to_not raise_error }

  context "run" do
    it "enables chef" do
      instance.should_receive(:load_env)
      instance.should_receive(:report_heart_beat_to_azure).twice
      instance.should_receive(:enable_chef)
      instance.run
    end
  end

  context "load_env" do
    it "loads azure specific environment configurations from config file." do
      instance.should_receive(:read_config)
      instance.send(:load_env)
    end
  end

  context "enable_chef" do
    it "configures, installs and enables chef." do
      instance.should_receive(:configure_chef_only_once)
      instance.should_receive(:install_chef_service)
      instance.should_receive(:enable_chef_service)
      instance.send(:enable_chef)
    end
  end

  context "install_chef_service" do
    it "installs the chef service and returns the status to azure." do
      instance.should_receive(:report_status_to_azure).with("chef-service installed", "success")
      ChefService.stub_chain(:new, :install).and_return(0)
      instance.send(:install_chef_service)
    end

    it "installs the chef service and returns the status to azure." do
      instance.should_receive(:report_status_to_azure).with("chef-service install failed - ", "error")
      ChefService.stub_chain(:new, :install).and_return(1)
      instance.send(:install_chef_service)
    end
  end

  context "enable_chef_service" do
    it "enables the chef service and returns the status to azure." do
      instance.should_receive(:report_status_to_azure).with("chef-service enabled", "success")
      ChefService.stub_chain(:new, :enable).and_return(0)
      instance.send(:enable_chef_service)
    end

    it "enables the chef service and returns the status to azure." do
      instance.should_receive(:report_status_to_azure).with("chef-service enable failed - ", "error")
      ChefService.stub_chain(:new, :enable).and_return(1)
      instance.send(:enable_chef_service)
    end
  end

  context "configure_chef_only_once" do
    it "runs the chef-client for the first time" do
      instance.stub(:puts)
      instance.stub(:shell_out).and_return(OpenStruct.new(:exitstatus => 0, :stdout => ""))
      File.stub_chain(:open, :write).and_return(true)
      instance.stub(:load_settings)
      Process.stub(:spawn)
      Process.stub(:detach)
      instance.send(:configure_chef_only_once)
    end
  end

  context "load_settings" do
    it "loads the settings from the handler settings file." do
      instance.should_receive(:handler_settings_file).exactly(3).times
      instance.should_receive(:value_from_json_file).exactly(3).times
      instance.should_receive(:get_validation_key)
      instance.send(:load_settings)
    end
  end

  context "handler_settings_file" do
    it "returns the handler settings file when the settings file is present." do
      Dir.stub_chain(:glob, :sort).and_return ["test"]
      File.should_receive(:expand_path)
      instance.send(:handler_settings_file)
    end

    it "returns error message when the settings file is not present." do
      Dir.stub_chain(:glob, :sort).and_return []
      File.should_receive(:expand_path)
      Chef::Log.stub(:error)
      instance.should_receive(:report_status_to_azure)
      expect {instance.send(:handler_settings_file)}.to raise_error
    end
  end
  
  context "escape_runlist" do
    it "escapes and formats the runlist." do
      instance.send(:escape_runlist, "test")
    end
  end

  context "get_validation_key on linux" , :unless => (RUBY_PLATFORM =~ /mswin|mingw|windows/) do
    it "extracts and returns the validation_key from encrypted text." do
      @object = Object.new
      File.stub(:read)
      OpenSSL::X509::Certificate.stub(:new)
      OpenSSL::PKey::RSA.stub(:new)
      Base64.stub(:decode64)
      OpenSSL::PKCS7.stub(:new).and_return(@object)
      @object.should_receive(:decrypt)
      instance.should_receive(:value_from_json_file).once
      instance.send(:get_validation_key, "encrypted_text")
    end
  end

  context "get_validation_key on windows" , :if => (RUBY_PLATFORM =~ /mswin|mingw|windows/) do
    it "extracts and returns the validation_key from encrypted text." do
      File.stub(:expand_path).and_return(".")
      File.stub(:dirname)
      instance.stub(:shell_out).and_return(OpenStruct.new(:exitstatus => 0, :stdout => ""))
      instance.should_receive(:handler_settings_file)
      instance.should_receive(:value_from_json_file).twice
      instance.send(:get_validation_key, "encrypted_text")
    end
  end
end