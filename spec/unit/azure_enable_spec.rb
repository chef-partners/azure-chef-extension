require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require 'chef/azure/commands/enable'
require 'ostruct'

describe EnableChef do
  let (:extension_root) { "./" }
  let (:enable_args) { [] }
  let (:instance) { EnableChef.new(extension_root, enable_args) }

  it { expect {instance}.to_not raise_error }

  context "#run" do
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

      context "extended_logs is set to false" do
        before do
          allow(instance).to receive(:load_env)
          allow(instance).to receive(:report_heart_beat_to_azure)
          allow(instance).to receive(:enable_chef)
          instance.instance_variable_set(:@extended_logs, 'false')
        end

        it "does not invoke fetch_chef_client_logs method" do
          expect(instance).to_not receive(:fetch_chef_client_logs)
          instance.run
        end
      end

      context "extended_logs is set to true" do
        context "first chef-client run" do
          before do
            allow(instance).to receive(:load_env)
            allow(instance).to receive(:report_heart_beat_to_azure)
            allow(instance).to receive(:enable_chef)
            instance.instance_variable_set(:@extended_logs, 'true')
            instance.instance_variable_set(:@child_pid, 123)
          end

          it "does not invoke fetch_chef_client_logs method" do
            expect(instance).to receive(:fetch_chef_client_logs)
            instance.run
          end
        end

        context "subsequent chef-client run" do
          before do
            allow(instance).to receive(:load_env)
            allow(instance).to receive(:report_heart_beat_to_azure)
            allow(instance).to receive(:enable_chef)
            instance.instance_variable_set(:@extended_logs, 'true')
            instance.instance_variable_set(:@child_pid, nil)
          end

          it "does not invoke fetch_chef_client_logs method" do
            expect(instance).to_not receive(:fetch_chef_client_logs)
            instance.run
          end
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

  context "#load_env" do
    it "loads azure specific environment configurations from config file." do
      expect(instance).to receive(:read_config)
      instance.send(:load_env)
    end
  end

  describe '#enable_chef' do
    context "when daemon is not provided" do
      before do
        allow(instance).to receive(:value_from_json_file)
        allow(instance).to receive(:handler_settings_file)
      end

      context '@exit_code is 0' do
        it 'calls configure_chef_only_once and enable_chef_service methods' do
          expect(instance).to receive(:configure_chef_only_once)
          expect(instance).to receive(:enable_chef_service)
          expect(Chef::Log).to_not receive(:error)
          expect(instance).to receive(:report_status_to_azure)
          expect(Chef::Log).to receive(:info)
          response = instance.send(:enable_chef)
          expect(response).to be == 0
        end
      end

      context '@exit_code is 1' do
        before do
          instance.instance_variable_set(:@exit_code, 1)
        end

        it 'calls configure_chef_only_once method but not enable_chef_service method' do
          expect(instance).to receive(:configure_chef_only_once)
          expect(instance).to_not receive(:enable_chef_service)
          expect(Chef::Log).to_not receive(:error)
          expect(instance).to_not receive(:report_status_to_azure)
          expect(Chef::Log).to receive(:info)
          response = instance.send(:enable_chef)
          expect(response).to be == 1
        end
      end
    end

    context "when daemon=service" do
      before do
        allow(instance).to receive(:value_from_json_file).and_return("service")
        allow(instance).to receive(:handler_settings_file)
      end

      context '@exit_code is 0' do
        it 'calls configure_chef_only_once and enable_chef_service methods' do
          expect(instance).to receive(:configure_chef_only_once)
          expect(instance).to receive(:enable_chef_service)
          expect(Chef::Log).to_not receive(:error)
          expect(instance).to receive(:report_status_to_azure)
          expect(Chef::Log).to receive(:info)
          response = instance.send(:enable_chef)
          expect(response).to be == 0
        end
      end

      context '@exit_code is 1' do
        before do
          instance.instance_variable_set(:@exit_code, 1)
        end

        it 'calls configure_chef_only_once method but not enable_chef_service method' do
          expect(instance).to receive(:configure_chef_only_once)
          expect(instance).to_not receive(:enable_chef_service)
          expect(Chef::Log).to_not receive(:error)
          expect(instance).to_not receive(:report_status_to_azure)
          expect(Chef::Log).to receive(:info)
          response = instance.send(:enable_chef)
          expect(response).to be == 1
        end
      end
    end

    context "when daemon=task" do
      before do
        allow(instance).to receive(:windows?).and_return(true)
        allow(instance).to receive(:value_from_json_file).and_return("task")
        allow(instance).to receive(:handler_settings_file)
      end

      context '@exit_code is 0' do
        it 'calls configure_chef_only_once and enable_chef_service methods' do
          expect(instance).to receive(:configure_chef_only_once)
          expect(instance).to receive(:enable_chef_sch_task)
          expect(Chef::Log).to_not receive(:error)
          expect(instance).to receive(:report_status_to_azure)
          expect(Chef::Log).to receive(:info)
          response = instance.send(:enable_chef)
          expect(response).to be == 0
        end
      end

      context '@exit_code is 1' do
        before do
          instance.instance_variable_set(:@exit_code, 1)
        end

        it 'calls configure_chef_only_once method but not enable_chef_service method' do
          expect(instance).to receive(:configure_chef_only_once)
          expect(instance).to_not receive(:enable_chef_sch_task)
          expect(Chef::Log).to_not receive(:error)
          expect(instance).to_not receive(:report_status_to_azure)
          expect(Chef::Log).to receive(:info)
          response = instance.send(:enable_chef)
          expect(response).to be == 1
        end
      end
    end

    context 'some unknown exception occurs in configure_chef_only_once method' do
      let(:error_msg) { RuntimeError.new('Some exception has occurred while configuring Chef') }

      before do
        allow(instance).to receive(:configure_chef_only_once).and_raise(error_msg)
      end

      it 'raises error' do
        expect(instance).to_not receive(:enable_chef_service)
        expect(Chef::Log).to receive(:error).with(error_msg)
        expect(instance).to receive(:report_status_to_azure).with(
          "#{error_msg} - Check log file for details", 'error'
        )
        expect(Chef::Log).to receive(:info)
        response = instance.send(:enable_chef)
        expect(response).to be == 1
      end
    end

    context 'some unknown exception occurs in enable_chef_service method' do
      let(:error_msg) { RuntimeError.new('Some exception has occurred while enabling Chef') }

      before do
        allow(instance).to receive(:handler_settings_file)
        allow(instance).to receive(:value_from_json_file).and_return("service")
        allow(instance).to receive(:enable_chef_service).and_raise(error_msg)
      end

      it 'raises error' do
        expect(instance).to receive(:configure_chef_only_once)
        expect(Chef::Log).to receive(:error).with(error_msg)
        expect(instance).to receive(:report_status_to_azure).twice
        expect(Chef::Log).to receive(:info)
        response = instance.send(:enable_chef)
        expect(response).to be == 1
      end
    end
  end

  describe '#load_chef_daemon_interval' do
    it 'invokes value_from_json_file and other methods' do
      expect(instance).to receive(:handler_settings_file)
      expect(instance).to receive(:value_from_json_file)
      instance.send(:load_chef_daemon_interval)
    end

    context 'example-1' do
      before do
        allow(instance).to receive(:handler_settings_file).and_return(
          mock_data("handler_settings.settings"))
      end

      it 'fetches chef_daemon_interval value from the given json file' do
        response = instance.send(:load_chef_daemon_interval)
        expect(response).to be == '13'
      end
    end

    context 'example-2' do
      before do
        allow(instance).to receive(:handler_settings_file).and_return(
          mock_data("handler_settings_1.settings"))
      end

      it 'fetches chef_daemon_interval value from the given json file' do
        response = instance.send(:load_chef_daemon_interval)
        expect(response).to be == '0'
      end
    end
  end

  describe '#enable_chef_service' do
    let (:chef_service_instance) { ChefService.new }

    before(:each) do
      allow(ChefService).to receive(:new).and_return(chef_service_instance)
      instance.instance_variable_set(:@chef_extension_root, '/chef_extension_root')
      allow(instance).to receive(:bootstrap_directory).and_return('/bootstrap_directory')
      instance.instance_variable_set(:@azure_plugin_log_location, '/azure_plugin_log_location')
    end

    context 'chef_daemon_interval option is not given by user, means it is empty' do
      before(:each) do
        allow(instance).to receive(:load_chef_daemon_interval).and_return('')
        expect(chef_service_instance).to_not receive(:disable)
      end

      context 'chef-service enable is successful' do
        it 'calls enable method with no chef_daemon_interval option and then reports success message to azure' do
          expect(chef_service_instance).to receive(:enable).with(
            '/chef_extension_root',
            '/bootstrap_directory',
            '/azure_plugin_log_location').and_return([0, nil])
          expect(instance).to receive(:report_status_to_azure).with(
            "chef-service enabled", "success"
          )
          response = instance.send(:enable_chef_service)
          expect(response).to be == 0
        end
      end

      context 'chef-service enable is un-successful' do
        it 'calls enable method with no chef_daemon_interval option and then reports failure message to azure' do
          expect(chef_service_instance).to receive(:enable).with(
            '/chef_extension_root',
            '/bootstrap_directory',
            '/azure_plugin_log_location').and_return([1, 'Some exception occurred'])
          expect(instance).to receive(:report_status_to_azure).with(
            "chef-service enable failed - Some exception occurred", "error"
          )
          response = instance.send(:enable_chef_service)
          expect(response).to be == 1
        end
      end
    end

    context 'chef_daemon_interval option given by user is 0' do
      before(:each) do
        allow(instance).to receive(:load_chef_daemon_interval).and_return('0')
        expect(chef_service_instance).to_not receive(:enable)
      end

      context 'chef-service disable is successful' do
        it 'calls disable method and then reports success message to azure' do
          expect(chef_service_instance).to receive(:disable).with(
            '/azure_plugin_log_location',
            '/bootstrap_directory',
            0).and_return([0, nil])
          expect(instance).to receive(:report_status_to_azure).with(
            "chef-service disabled", "success"
          )
          response = instance.send(:enable_chef_service)
          expect(response).to be == 0
        end
      end

      context 'chef-service disable is un-successful' do
        it 'calls disable method and then reports failure message to azure' do
          expect(chef_service_instance).to receive(:disable).with(
            '/azure_plugin_log_location',
            '/bootstrap_directory',
            0).and_return([1, 'Some exception occurred'])
          expect(instance).to receive(:report_status_to_azure).with(
            "chef-service disable failed - Some exception occurred", "error"
          )
          response = instance.send(:enable_chef_service)
          expect(response).to be == 1
        end
      end
    end

    context 'chef_daemon_interval option given by user is non-empty, non-zero and valid' do
      before(:each) do
        allow(instance).to receive(:load_chef_daemon_interval).and_return('13')
        expect(chef_service_instance).to_not receive(:disable)
      end

      context 'chef-service enable is successful' do
        it 'calls enable method with chef_daemon_interval option and then reports success message to azure' do
          expect(chef_service_instance).to receive(:enable).with(
            '/chef_extension_root',
            '/bootstrap_directory',
            '/azure_plugin_log_location',
            13).and_return([0, nil])
          expect(instance).to receive(:report_status_to_azure).with(
            "chef-service enabled", "success"
          )
          response = instance.send(:enable_chef_service)
          expect(response).to be == 0
        end
      end

      context 'chef-service enable is un-successful' do
        it 'calls enable method with chef_daemon_interval option and then reports failure message to azure' do
          expect(chef_service_instance).to receive(:enable).with(
            '/chef_extension_root',
            '/bootstrap_directory',
            '/azure_plugin_log_location',
            13).and_return([1, 'Some exception occurred'])
          expect(instance).to receive(:report_status_to_azure).with(
            "chef-service enable failed - Some exception occurred", "error"
          )
          response = instance.send(:enable_chef_service)
          expect(response).to be == 1
        end
      end
    end

    context 'chef_daemon_interval option given by user is non-empty, non-zero and invalid' do
      before do
        allow(instance).to receive(:load_chef_daemon_interval).and_return('-8')
        expect(chef_service_instance).to_not receive(:disable)
        expect(chef_service_instance).to_not receive(:enable)
      end

      it 'raises error' do
        expect { instance.send(:enable_chef_service) }.to raise_error(
          'Invalid value for chef_daemon_interval option.'
        )
      end
    end
  end

  describe "#configure_chef_only_once" do
    context "first chef-client run" do
      context "extended_logs set to false and ohai_hints not passed" do
        before do
          allow(File).to receive(:exists?).and_return(false)
          allow(instance).to receive(:puts)
          allow(File).to receive(:open)
          @bootstrap_directory = Dir.home
          allow(instance).to receive(
            :bootstrap_directory).and_return(@bootstrap_directory)
          allow(instance).to receive(:handler_settings_file).and_return(
            mock_data("handler_settings.settings"))
          allow(instance).to receive(:get_validation_key).and_return("")
          allow(instance).to receive(:get_client_key).and_return("")
          allow(instance).to receive(:get_chef_server_ssl_cert).and_return("")
          allow(IO).to receive_message_chain(
            :read, :chomp).and_return("template")
          allow(Process).to receive(:detach)
          @sample_config = {:environment=>"_default", :chef_node_name=>"mynode3", :chef_extension_root=>"./", :user_client_rb=>"", :log_location=>nil, :chef_server_url=>"https://api.opscode.com/organizations/clochefacc", :validation_client_name=>"clochefacc-validator", :secret=>nil, :first_boot_attributes => {}}
          @sample_runlist = ["recipe[getting-started]", "recipe[apt]"]
        end

        it "runs chef-client for the first time on windows" do
          allow(instance).to receive(:windows?).and_return(true)
          expect(Chef::Knife::Core::WindowsBootstrapContext).to receive(
            :new).with(@sample_config, @sample_runlist, any_args)
          allow(Erubis::Eruby).to receive(:new).and_return("template")
          expect(Erubis::Eruby.new).to receive(:evaluate)
          expect(instance).to receive(:shell_out).and_return(
            OpenStruct.new(:exitstatus => 0, :stdout => "")).thrice
          expect(instance).to_not receive(:load_cloud_attributes_in_hints)
          expect(instance).to receive(:secret_key)
          expect(FileUtils).to receive(:rm)
          expect(Process).to receive(:spawn).with("chef-client -c #{@bootstrap_directory}/client.rb -j #{@bootstrap_directory}/first-boot.json -E #{@sample_config[:environment]} -L #{@sample_config[:log_location]}/chef-client.log --once ").and_return(123)
          instance.send(:configure_chef_only_once)
          expect(instance.instance_variable_get(:@child_pid)).to be == 123
          expect(instance.instance_variable_get(:@chef_client_success_file)).to be nil
          expect(instance.instance_variable_get(:@chef_client_run_start_time)).to be nil
        end

        it "runs chef-client for the first time on linux" do
          allow(instance).to receive(:windows?).and_return(false)
          expect(instance).to_not receive(:load_cloud_attributes_in_hints)
          expect(instance).to receive(:secret_key)
          expect(Chef::Knife::Core::BootstrapContext).to receive(
            :new).with(@sample_config, @sample_runlist, any_args)
          allow(Erubis::Eruby).to receive(:new).and_return("template")
          expect(Erubis::Eruby.new).to receive(:evaluate)
          expect(instance).to receive(:shell_out).and_return(
            OpenStruct.new(:exitstatus => 0, :stdout => ""))
          expect(Process).to receive(:spawn).with("chef-client -c #{@bootstrap_directory}/client.rb -j #{@bootstrap_directory}/first-boot.json -E #{@sample_config[:environment]} -L #{@sample_config[:log_location]}/chef-client.log --once ").and_return(456)
          instance.send(:configure_chef_only_once)
          expect(instance.instance_variable_get(:@child_pid)).to be == 456
          expect(instance.instance_variable_get(:@chef_client_success_file)).to be nil
          expect(instance.instance_variable_get(:@chef_client_run_start_time)).to be nil
        end
      end

      context "extended_logs set to true and ohai_hints passed and first boot json attr passed" do
        before do
          allow(File).to receive(:exists?).and_return(false)
          allow(instance).to receive(:puts)
          allow(File).to receive(:open)
          @bootstrap_directory = Dir.home
          allow(instance).to receive(
            :bootstrap_directory).and_return(@bootstrap_directory)
          allow(instance).to receive(:handler_settings_file).and_return(
            mock_data("handler_settings_1.settings"))
          allow(instance).to receive(:get_validation_key).and_return("")
          allow(instance).to receive(:get_client_key).and_return("")
          allow(instance).to receive(:get_chef_server_ssl_cert).and_return("")
          allow(IO).to receive_message_chain(
            :read, :chomp).and_return("template")
          allow(Process).to receive(:detach)
          @sample_config = {:environment=>"_default", :chef_node_name=>"mynode3", :chef_extension_root=>"./", :user_client_rb=>"", :log_location=>nil, :chef_server_url=>"https://api.opscode.com/organizations/clochefacc", :validation_client_name=>"clochefacc-validator", :secret=>nil, :first_boot_attributes => {"container_service"=>{"chef-init-test"=>{"command"=>"C:\\opscode\\chef\\bin"}}} }
          @sample_runlist = ["recipe[getting-started]", "recipe[apt]"]
        end

        it "runs chef-client for the first time on windows" do
          allow(instance).to receive(:windows?).and_return(true)
          expect(Chef::Knife::Core::WindowsBootstrapContext).to receive(
            :new).with(@sample_config, @sample_runlist, any_args)
          allow(Erubis::Eruby).to receive(:new).and_return("template")
          expect(Erubis::Eruby.new).to receive(:evaluate)
          expect(instance).to receive(:shell_out).and_return(
            OpenStruct.new(:exitstatus => 0, :stdout => "")).thrice
          expect(instance).to receive(:load_cloud_attributes_in_hints)
          expect(instance).to receive(:secret_key)
          expect(FileUtils).to receive(:rm)
          expect(Process).to receive(:spawn).with("chef-client -c #{@bootstrap_directory}/client.rb -j #{@bootstrap_directory}/first-boot.json -E #{@sample_config[:environment]} -L #{@sample_config[:log_location]}/chef-client.log --once  && touch c:\\chef_client_success").and_return(789)
          instance.send(:configure_chef_only_once)
          expect(instance.instance_variable_get(:@child_pid)).to be == 789
          expect(instance.instance_variable_get(:@chef_client_success_file)).to be == 'c:\\chef_client_success'
          expect(instance.instance_variable_get(:@chef_client_run_start_time)).to_not be nil
        end

        it "runs chef-client for the first time on linux" do
          allow(instance).to receive(:windows?).and_return(false)
          expect(instance).to receive(:load_cloud_attributes_in_hints)
          expect(instance).to receive(:secret_key)
          expect(Chef::Knife::Core::BootstrapContext).to receive(
            :new).with(@sample_config, @sample_runlist, any_args)
          allow(Erubis::Eruby).to receive(:new).and_return("template")
          expect(Erubis::Eruby.new).to receive(:evaluate)
          expect(instance).to receive(:shell_out).and_return(
            OpenStruct.new(:exitstatus => 0, :stdout => ""))
          expect(Process).to receive(:spawn).with("chef-client -c #{@bootstrap_directory}/client.rb -j #{@bootstrap_directory}/first-boot.json -E #{@sample_config[:environment]} -L #{@sample_config[:log_location]}/chef-client.log --once  && touch /tmp/chef_client_success").and_return(120)
          instance.send(:configure_chef_only_once)
          expect(instance.instance_variable_get(:@child_pid)).to be == 120
          expect(instance.instance_variable_get(:@chef_client_success_file)).to be == '/tmp/chef_client_success'
          expect(instance.instance_variable_get(:@chef_client_run_start_time)).to_not be nil
        end
      end
    end

    context "subsequent chef_client run" do
      before do
        allow(File).to receive(:exists?).and_return(true)
      end

      it "does not spawn chef-client run process irrespective of the platform" do
        expect(instance).to_not receive(:load_cloud_attributes_in_hints)
        expect(Process).to_not receive(:spawn)
        expect(Process).to_not receive(:detach)
        expect(instance.instance_variable_get(:@child_pid)).to be nil
        instance.send(:configure_chef_only_once)
      end
    end
  end

  describe "#chef_client_log_path" do
    context "log_location defined in chef_config read from chef config file" do
      before do
        allow(instance).to receive(:chef_config)
        chef_config = {:log_location => './logs/chef-client.log'}
        instance.instance_variable_set(:@chef_config, chef_config)
        instance.instance_variable_set(:@azure_plugin_log_location, './logs_other')
      end

      it "returns chef_client log path from chef_config log_location" do
        response = instance.send(:chef_client_log_path)
        expect(response).to be == './logs/chef-client.log'
      end
    end

    context "log_location not defined in chef config file" do
      before do
        allow(instance).to receive(:chef_config)
        chef_config = {:log_location => nil}
        instance.instance_variable_set(:@chef_config, chef_config)
        instance.instance_variable_set(:@azure_plugin_log_location, './logs_other')
      end

      it "returns chef_client log path from chef_config log_location" do
        response = instance.send(:chef_client_log_path)
        expect(response).to be == './logs_other/chef-client.log'
      end
    end
  end

  describe "#fetch_chef_client_logs" do
    context "for windows" do
      before do
        instance.instance_variable_set(:@chef_extension_root, 'c:\\extension_root')
        instance.instance_variable_set(:@child_pid, 123)
        instance.instance_variable_set(:@chef_client_run_start_time, '2016-05-03 20:51:01 +0530')
        allow(instance).to receive(:chef_config).and_return(nil)
        instance.instance_variable_set(:@chef_config, {:log_location => nil})
        instance.instance_variable_set(:@azure_plugin_log_location, 'c:\\logs')
        instance.instance_variable_set(:@azure_status_file, 'c:\\extension_root\\status\\0.status')
        allow(instance).to receive(:windows?).and_return(true)
        ENV['SYSTEMDRIVE'] = 'c:'
        instance.instance_variable_set(:@chef_client_success_file, 'c:\\chef_client_success')
      end

      it "spawns chef_client run logs collection script" do
        expect(Process).to receive(:spawn).with(
          "ruby c:\\extension_root/bin/chef_client_logs.rb 123 \"2016-05-03 20:51:01 +0530\" c:\\logs/chef-client.log c:\\extension_root\\status\\0.status c:/chef c:\\chef_client_success").
            and_return(456)
        expect(Process).to receive(:detach).with(456)
        expect(instance).to receive(:puts)
        instance.send(:fetch_chef_client_logs)
      end
    end

    context "for linux" do
      before do
        instance.instance_variable_set(:@chef_extension_root, '/var/extension_root')
        instance.instance_variable_set(:@child_pid, 789)
        instance.instance_variable_set(:@chef_client_run_start_time, '2016-05-03 21:51:01 +0530')
        allow(instance).to receive(:chef_config).and_return(nil)
        instance.instance_variable_set(:@chef_config, {:log_location => nil})
        instance.instance_variable_set(:@azure_plugin_log_location, '/var/logs')
        instance.instance_variable_set(:@azure_status_file, '/var/extension_root/status/0.status')
        allow(instance).to receive(:windows?).and_return(false)
        instance.instance_variable_set(:@chef_client_success_file, '/tmp/chef_client_success')
      end

      it "spawns chef_client run logs collection script" do
        expect(Process).to receive(:spawn).with(
          "ruby /var/extension_root/bin/chef_client_logs.rb 789 \"2016-05-03 21:51:01 +0530\" /var/logs/chef-client.log /var/extension_root/status/0.status /etc/chef /tmp/chef_client_success").
            and_return(120)
        expect(Process).to receive(:detach).with(120)
        expect(instance).to receive(:puts)
        instance.send(:fetch_chef_client_logs)
      end
    end
  end

  context "#load_settings" do
    it "loads the settings from the handler settings file." do
      expect(instance).to receive(:handler_settings_file).exactly(8).times
      expect(instance).to receive(:value_from_json_file).exactly(8).times
      expect(instance).to receive(:get_validation_key)
      allow(instance).to receive(:get_client_key).and_return("")
      allow(instance).to receive(:get_chef_server_ssl_cert).and_return("")
      allow(instance).to receive(:secret_key).and_return("")
      instance.send(:load_settings)
    end
  end

  context "#handler_settings_file" do
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
      expect {instance.send(:handler_settings_file)}.to raise_error(
        "Configuration error. Azure chef extension Settings file missing.")
    end
  end

  context "#escape_runlist" do
    it "escapes and formats the runlist." do
      instance.send(:escape_runlist, "test")
    end
  end

  context "#get_validation_key on linux" , :unless => (RUBY_PLATFORM =~ /mswin|mingw|windows/) do
    before do
      @object = Object.new
      allow(File).to receive(:read)
      allow(File).to receive(:exists?).and_return(true)
      allow(OpenSSL::X509::Certificate).to receive(:new)
      allow(OpenSSL::PKey::RSA).to receive(:new).and_return(@object)
      allow(Base64).to receive(:decode64)
      allow(OpenSSL::PKCS7).to receive(:new).and_return(@object)
      allow(instance).to receive(:value_from_json_file).and_return('samplevalidationkeytext')
    end
    it "extracts and returns the validation_key from encrypted text." do
      allow(@object).to receive(:to_pem).and_return('samplevalidationkeytext')
      expect(instance.send(:get_validation_key, 'decrypted_text', 'format')).to eq("samplevalidationkeytext")
    end

    it "extracts and returns the validation_key from encrypted text containg null bytes" do
      allow(@object).to receive(:to_pem).and_return("sample\x00validation\x00keytext\x00")
      expect(instance.send(:get_validation_key, 'decrypted_text', 'format')).to eq("samplevalidationkeytext")
    end
  end

  context "#get_validation_key on windows" , :if => (RUBY_PLATFORM =~ /mswin|mingw|windows/) do
    before do
      @object = Object.new
      allow(File).to receive(:expand_path).and_return(".")
      allow(File).to receive(:dirname)
      allow(instance).to receive(:shell_out).and_return(OpenStruct.new(:exitstatus => 0, :stdout => ""))
      allow(OpenSSL::PKey::RSA).to receive(:new).and_return(@object)
      allow(instance).to receive(:value_from_json_file).and_return('samplevalidationkeytext')
    end
    it "extracts and returns the validation_key from encrypted text." do
      allow(@object).to receive(:to_pem).and_return('samplevalidationkeytext')
      expect(instance.send(:get_validation_key, 'decrypted_text', 'format')).to eq("samplevalidationkeytext")
    end

    it "extracts and returns the validation_key from encrypted text containg null bytes." do
      allow(@object).to receive(:to_pem).and_return("sample\x00validation\x00keytext\x00")
      expect(instance.send(:get_validation_key, 'decrypted_text', 'format')).to eq("samplevalidationkeytext")
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

  context "#load_cloud_attributes_in_hints" do
    before do
      hints = "{\"public_ip\"=>\"my_public_ip\",\"vm_name\"=>\"my_vm_name\",
        \"public_fqdn\"=>\"my_public_fqdn\",\"port\"=>\"my_port\",
        \"platform\"=>\"my_platform\"}"
      instance.instance_variable_set(:@ohai_hints, hints)
    end

    it 'loads cloud attributs in Chef::Config["knife"]["hints"]' do
      instance.send(:load_cloud_attributes_in_hints)
      hints = Chef::Config[:knife][:hints]["azure"]
      expect(hints['public_ip']).to eq 'my_public_ip'
      expect(hints['vm_name']).to eq 'my_vm_name'
      expect(hints['public_fqdn']).to eq 'my_public_fqdn'
      expect(hints['port']).to eq 'my_port'
      expect(hints['platform']).to eq 'my_platform'
    end
  end

  describe "#update_chef_status" do
    context "for enable" do
      context "when operation is successful" do
        it "displays the success message according to the option passed" do
          instance.instance_variable_set("@exit_code", 0)
          option_name = "service"
          disable_flag = false
          expect(instance).to receive(:report_status_to_azure).with("chef-#{option_name} enabled", "success")
          instance.send(:update_chef_status, option_name, disable_flag)
        end
      end

      context "when operation is unsuccessful" do
        it "displays the failure message according to the option passed" do
          instance.instance_variable_set("@exit_code", 1)
          instance.instance_variable_set("@error_message", "error")
          error_message = "error"
          option_name = "task"
          disable_flag = false
          expect(instance).to receive(:report_status_to_azure).with("chef-#{option_name} enable failed - #{error_message}", "error")
          instance.send(:update_chef_status, option_name, disable_flag)
        end
      end
    end

    context "for disable" do
      context "when operation is successful" do
        it "displays the success message according to the option passed" do
          instance.instance_variable_set("@exit_code", 0)
          option_name = "service"
          disable_flag = true
          expect(instance).to receive(:report_status_to_azure).with("chef-#{option_name} disabled", "success")
          instance.send(:update_chef_status, option_name, disable_flag)
        end
      end

      context "when operation is unsuccessful" do
        it "displays the failure message according to the option passed" do
          instance.instance_variable_set("@exit_code", 1)
          instance.instance_variable_set("@error_message", "error")
          error_message = "error"
          option_name = "task"
          disable_flag = true
          expect(instance).to receive(:report_status_to_azure).with("chef-#{option_name} disable failed - #{error_message}", "error")
          instance.send(:update_chef_status, option_name, disable_flag)
        end
      end
    end
  end

  describe "#enable_chef_sch_task" do
    context "when chef_daemon_interval is empty" do
      before do
        allow(instance).to receive(:load_chef_daemon_interval).and_return("")
      end

      it "creates the chef scheduled task with default interval" do
        expect_any_instance_of(ChefTask).to receive(:enable)
        expect(instance).to receive(:update_chef_status)
        instance.send(:enable_chef_sch_task)
      end
    end

    context "when chef_daemon_interval = 0" do
      before do
        allow(instance).to receive(:load_chef_daemon_interval).and_return("0")
      end

      it "disables the chef scheduled task" do
        expect_any_instance_of(ChefTask).to receive(:disable)
        expect(instance).to receive(:update_chef_status)
        instance.send(:enable_chef_sch_task)
      end
    end

    context "when chef_daemon_interval < 0" do
      before do
        allow(instance).to receive(:load_chef_daemon_interval).and_return("-2")
      end

      it "raises error" do
        expect { instance.send(:enable_chef_sch_task) }.to raise_error("Invalid value for chef_daemon_interval option.")
      end
    end

    context "when chef_daemon_interval > 0" do
      before do
        allow(instance).to receive(:load_chef_daemon_interval).and_return("34")
      end

      it "creates the chef scheduled task with the given interval" do
        expect_any_instance_of(ChefTask).to receive(:enable)
        expect(instance).to receive(:update_chef_status)
        instance.send(:enable_chef_sch_task)
      end
    end
  end
end
