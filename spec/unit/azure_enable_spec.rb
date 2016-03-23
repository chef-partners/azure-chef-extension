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
      expect(instance).to receive(:read_config)
      instance.send(:load_env)
    end
  end

  context "enable_chef" do
    it "configures, installs and enables chef." do
      expect(instance).to receive(:configure_chef_only_once)
      expect(instance).to receive(:install_chef_service)
      expect(instance).to receive(:enable_chef_service)
      instance.send(:enable_chef)
    end
  end

  context "install_chef_service" do
    it "installs the chef service and returns the status to azure." do
      expect(instance).to receive(:report_status_to_azure).with("chef-service installed", "success")
      allow(ChefService).to receive_message_chain(:new, :install).and_return(0)
      instance.send(:install_chef_service)
    end

    it "installs the chef service and returns the status to azure." do
      expect(instance).to receive(:report_status_to_azure).with("chef-service install failed - ", "error")
      allow(ChefService).to receive_message_chain(:new, :install).and_return(1)
      instance.send(:install_chef_service)
    end
  end

  context "enable_chef_service" do
    it "enables the chef service and returns the status to azure." do
      expect(instance).to receive(:report_status_to_azure).with("chef-service enabled", "success")
      allow(ChefService).to receive_message_chain(:new, :enable).and_return(0)
      instance.send(:enable_chef_service)
    end

    it "enables the chef service and returns the status to azure." do
      expect(instance).to receive(:report_status_to_azure).with("chef-service enable failed - ", "error")
      allow(ChefService).to receive_message_chain(:new, :enable).and_return(1)
      instance.send(:enable_chef_service)
    end
  end

  context "configure_chef_only_once" do
    it "runs the chef-client for the first time for windows" do
      allow(instance).to receive(:puts)
      allow(File).to receive(:exists?).and_return(false)
      allow(File).to receive(:open)
      allow(instance).to receive(:shell_out).and_return(OpenStruct.new(:exitstatus => 0, :stdout => ""))
      allow(instance).to receive(:bootstrap_directory).and_return(Dir.home)
      allow(instance).to receive(:handler_settings_file).and_return(mock_data("handler_settings.settings"))
      allow(instance).to receive(:get_validation_key).and_return("")
      allow(instance).to receive(:get_client_key).and_return("")
      allow(instance).to receive(:get_chef_server_ssl_cert).and_return("")
      allow(instance).to receive(:windows?).and_return(true)
      # Call to load_cloud_attributes_in_hints method has been removed for time being
      #expect(instance).to receive(:load_cloud_attributes_in_hints)
      sample_config = {:environment=>"_default", :chef_node_name=>"mynode3", :chef_extension_root=>"./", :user_client_rb=>"", :log_location=>nil, :chef_server_url=>"https://api.opscode.com/organizations/clochefacc", :validation_client_name=>"clochefacc-validator", :secret=>nil}
      sample_runlist = ["recipe[getting-started]", "recipe[apt]"]
      expect(Chef::Knife::Core::WindowsBootstrapContext).to receive(:new).with(sample_config, sample_runlist, any_args)
      allow(Erubis::Eruby).to receive(:new)
      allow(Erubis::Eruby.new).to receive(:evaluate)
      allow(FileUtils).to receive(:rm)
      allow(Process).to receive(:spawn)
      allow(Process).to receive(:detach)
      instance.send(:configure_chef_only_once)
    end

    it "runs the chef-client for the first time for linux" do
      allow(instance).to receive(:puts)
      allow(File).to receive(:exists?).and_return(false)
      allow(File).to receive(:open)
      allow(instance).to receive(:shell_out).and_return(OpenStruct.new(:exitstatus => 0, :stdout => ""))
      allow(instance).to receive(:bootstrap_directory).and_return(Dir.home)
      allow(instance).to receive(:handler_settings_file).and_return(mock_data("handler_settings.settings"))
      allow(instance).to receive(:get_validation_key).and_return("")
      allow(instance).to receive(:get_client_key).and_return("")
      allow(instance).to receive(:get_chef_server_ssl_cert).and_return("")
      allow(instance).to receive(:windows?).and_return(false)
      #expect(instance).to receive(:load_cloud_attributes_in_hints)
      sample_config = {:environment=>"_default", :chef_node_name=>"mynode3", :chef_extension_root=>"./", :user_client_rb=>"", :log_location=>nil, :chef_server_url=>"https://api.opscode.com/organizations/clochefacc", :validation_client_name=>"clochefacc-validator", :secret=>nil}
      sample_runlist = ["recipe[getting-started]", "recipe[apt]"]
      expect(Chef::Knife::Core::BootstrapContext).to receive(:new).with(sample_config, sample_runlist, any_args)
      allow(Erubis::Eruby).to receive(:new)
      allow(Erubis::Eruby.new).to receive(:evaluate)
      allow(Process).to receive(:spawn)
      allow(Process).to receive(:detach)
      instance.send(:configure_chef_only_once)
    end
  end

  context "load_settings" do
    it "loads the settings from the handler settings file." do
      expect(instance).to receive(:handler_settings_file).exactly(4).times
      expect(instance).to receive(:value_from_json_file).exactly(4).times
      expect(instance).to receive(:get_validation_key)
      allow(instance).to receive(:get_client_key).and_return("")
      allow(instance).to receive(:get_chef_server_ssl_cert).and_return("")
      instance.send(:load_settings)
    end
  end

  context "handler_settings_file" do
    it "returns the handler settings file when the settings file is present." do
      allow(Dir).to receive_message_chain(:glob, :sort).and_return ["test"]
      expect(File).to receive(:expand_path)
      instance.send(:handler_settings_file)
    end

    it "returns error message when the settings file is not present." do
      allow(Dir).to receive_message_chain(:glob, :sort).and_return []
      expect(File).to receive(:expand_path)
      allow(Chef::Log).to receive(:error)
      expect(instance).to receive(:report_status_to_azure)
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
      allow(File).to receive(:read)
      allow(File).to receive(:exists?).and_return(true)
      allow(OpenSSL::X509::Certificate).to receive(:new)
      allow(OpenSSL::PKey::RSA).to receive(:new).and_return(@object)
      allow(Base64).to receive(:decode64)
      allow(OpenSSL::PKCS7).to receive(:new).and_return(@object)
      expect(instance).to receive(:handler_settings_file)
      expect(instance).to receive(:value_from_json_file).twice.and_return('')
      expect(@object).to receive(:decrypt)
      expect(@object).to receive(:to_pem)
      instance.send(:get_validation_key, 'encrypted_text', 'format')
    end
  end

  context "get_validation_key on windows" , :if => (RUBY_PLATFORM =~ /mswin|mingw|windows/) do
    it "extracts and returns the validation_key from encrypted text." do
      allow(File).to receive(:expand_path).and_return(".")
      allow(File).to receive(:dirname)
      allow(instance).to receive(:shell_out).and_return(OpenStruct.new(:exitstatus => 0, :stdout => ""))
      expect(instance).to receive(:handler_settings_file)
      expect(instance).to receive(:value_from_json_file).twice.and_return("")
      instance.send(:get_validation_key, "encrypted_text", "format")
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
      expected_output = ["recipe[cookbook1]", "recipe[cookbook2]"]
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
      expected_output = ["recipe[recipe1]", "recipe[recipe2]"]
      escape_runlist_call = instance.send(:escape_runlist,sample_input)
      expect(escape_runlist_call).to eq(expected_output)
    end

    it "accepts format: role[rolename],recipe" do
      sample_input = "role[rolename],recipe"
      expected_output = ["role[rolename]", "recipe[recipe]"]
      escape_runlist_call = instance.send(:escape_runlist,sample_input)
      expect(escape_runlist_call).to eq(expected_output)
    end

    it "parse escape character runlist" do
      sample_input = "\"role[rolename]\",\"recipe\""
      expected_output = ["role[rolename]", "recipe[recipe]"]
      escape_runlist_call = instance.send(:escape_runlist,sample_input)
      expect(escape_runlist_call).to eq(expected_output)
    end
  end

  context "load_cloud_attributes_in_hints" do
    it 'loads cloud attributs in Chef::Config["knife"]["hints"]' do
      allow(instance).to receive(Socket.gethostname).and_return("something")
      instance.send(:load_cloud_attributes_in_hints)
    end
  end
end