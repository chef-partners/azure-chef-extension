require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require 'chef/azure/commands/enable'
require 'ostruct'

describe EnableChef do
  let (:extension_root) { "./" }
  let (:enable_args) { [] }
  let (:instance) { EnableChef.new(extension_root, enable_args) }

  it { expect {instance}.to_not raise_error }

  context "run" do
    context "chef service is enabled" do
      context "chef-client run was successful" do
        it "reports chef service enabled to heartbeat" do
          expect(instance).to receive(:load_env)
          expect(instance).to receive(:report_heart_beat_to_azure).with(AzureHeartBeat::NOTREADY, 0, "Enabling chef-service...")
          expect(instance).to receive(:enable_chef)
          expect(instance).to receive(:report_heart_beat_to_azure).with(AzureHeartBeat::READY, 0, "chef-service is enabled.")

          expect(instance.run).to eq(0)
        end
      end

      context "chef-client run failed" do
        it "reports chef service enabled and chef run failed to heartbeat" do
          instance.instance_variable_set(:@chef_client_error, "Chef client failed")

          expect(instance).to receive(:load_env)
          expect(instance).to receive(:report_heart_beat_to_azure).with(AzureHeartBeat::NOTREADY, 0, "Enabling chef-service...")
          expect(instance).to receive(:enable_chef)
          expect(instance).to receive(:report_heart_beat_to_azure).with(AzureHeartBeat::READY, 0, "chef-service is enabled. Chef client run failed with error- Chef client failed")

          expect(instance.run).to eq(0)
        end
      end
    end

    context "Chef service enable failed" do
      before do
        instance.instance_variable_set(:@exit_code, 1)
      end

      context "chef-client run was successful" do
        it "reports chef service enable failure and chef run success to heartbeat" do
          expect(instance).to receive(:load_env)
          expect(instance).to receive(:report_heart_beat_to_azure).with(AzureHeartBeat::NOTREADY, 0, "Enabling chef-service...")
          expect(instance).to receive(:enable_chef)
          expect(instance).to receive(:report_heart_beat_to_azure).with(AzureHeartBeat::NOTREADY, 0, "chef-service enable failed.")

          expect(instance.run).to eq(1)
        end
      end

      context "chef-client run failed" do
        it "reports chef service enable failure and chef run failure to heartbeat" do
          instance.instance_variable_set(:@chef_client_error, "Chef client failed")

          expect(instance).to receive(:load_env)
          expect(instance).to receive(:report_heart_beat_to_azure).with(AzureHeartBeat::NOTREADY, 0, "Enabling chef-service...")
          expect(instance).to receive(:enable_chef)
          expect(instance).to receive(:report_heart_beat_to_azure).with(AzureHeartBeat::NOTREADY, 0, "chef-service enable failed. Chef client run failed with error- Chef client failed")

          expect(instance.run).to eq(1)
        end
      end
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
      instance.stub(:bootstrap_directory).and_return(Dir.home)
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
      OpenSSL::PKey::RSA.stub(:new).and_return(@object)
      Base64.stub(:decode64)
      OpenSSL::PKCS7.stub(:new).and_return(@object)
      @object.should_receive(:decrypt)
      @object.should_receive(:to_pem)
      instance.should_receive(:value_from_json_file).once.and_return("")
      instance.send(:get_validation_key, "encrypted_text")
    end
  end

  context "get_validation_key on windows" , :if => (RUBY_PLATFORM =~ /mswin|mingw|windows/) do
    it "extracts and returns the validation_key from encrypted text." do
      File.stub(:expand_path).and_return(".")
      File.stub(:dirname)
      instance.stub(:shell_out).and_return(OpenStruct.new(:exitstatus => 0, :stdout => ""))
      instance.should_receive(:handler_settings_file)
      instance.should_receive(:value_from_json_file).twice.and_return("")
      instance.send(:get_validation_key, "encrypted_text")
    end
  end

  context "runlist is in correct format when" do
    it "accepts format: recipe[cookbook]" do
      sample_input = "recipe[abc]"
      expected_output = ["recipe[abc]"]
      escape_runlist_call = instance.send(:escape_runlist,sample_input)
      expect(escape_runlist_call).to eq(expected_output)
    end

    it "accepts format: role[rolename]" do
      sample_input = "role[abc]"
      expected_output = ["role[abc]"]
      escape_runlist_call = instance.send(:escape_runlist,sample_input)
      expect(escape_runlist_call).to eq(expected_output)
    end

    it "accepts format: recipe[cookbook1],recipe[cookbook2]" do
      sample_input = "recipe[cookbook1],recipe[cookbook2]"
      expected_output = ["recipe[cookbook1]","recipe[cookbook2]"]
      escape_runlist_call = instance.send(:escape_runlist,sample_input)
      expect(escape_runlist_call).to eq(expected_output)
    end

    it "accepts format: recipe[cookbook1],role[rolename]" do
      sample_input = "recipe[cookbook1],role[rolename]"
      expected_output = ["recipe[cookbook1]","role[rolename]"]
      escape_runlist_call = instance.send(:escape_runlist,sample_input)
      expect(escape_runlist_call).to eq(expected_output)
    end

    it "accepts format: cookbook1,cookbook2" do
      sample_input = "cookbook1,cookbook2"
      expected_output = ["cookbook1","cookbook2"]
      escape_runlist_call = instance.send(:escape_runlist,sample_input)
      expect(escape_runlist_call).to eq(expected_output)
    end

    it "accepts format: recipe[cookbook::recipe]" do
      sample_input = "recipe[cookbook::recipe]"
      expected_output = ["recipe[cookbook::recipe]"]
      escape_runlist_call = instance.send(:escape_runlist,sample_input)
      expect(escape_runlist_call).to eq(expected_output)
    end

    it "accepts format: recipe[recipe1],recipe2" do
      sample_input = "recipe[recipe1],recipe2"
      expected_output = ["recipe[recipe1]","recipe2"]
      escape_runlist_call = instance.send(:escape_runlist,sample_input)
      expect(escape_runlist_call).to eq(expected_output)
    end

    it "accepts format: role[rolename],recipe" do
      sample_input = "role[rolename],recipe"
      expected_output = ["role[rolename]","recipe"]
      escape_runlist_call = instance.send(:escape_runlist,sample_input)
      expect(escape_runlist_call).to eq(expected_output)
    end
  end
end