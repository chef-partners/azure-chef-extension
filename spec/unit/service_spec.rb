require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require 'chef/azure/helpers/shared'
require 'chef/azure/service'
require 'ostruct'

describe ChefService do
  let (:instance) { ChefService.new }

  it { expect {instance}.to_not raise_error }

  describe 'enable' do
    context 'Windows platform' do
      before(:each) do
        allow(instance).to receive(:windows?).and_return(true)
        allow(instance).to receive(:puts)
      end

      context 'chef-service is already installed' do
        before(:each) do
          allow(instance).to receive(:is_installed?).and_return(true)
        end

        context 'chef-service interval has been changed by the user' do
          before do
            allow(instance).to receive(:chef_service_interval_changed?).and_return(true)
          end

          it 'updates the interval in client.rb file and restarts the service' do
            expect(instance).to receive(:interval_in_seconds).and_return(1020)
            expect(instance).to receive(:set_interval).with(
              "/bootstrap_directory\\client.rb", 1020)
            expect(instance).to receive(:restart_service)
            response = instance.send(:enable, '/extension_root', '/bootstrap_directory', '/log_location', 17)
            expect(response).to be == [0, 'success']
          end
        end

        context 'chef-service interval has not been changed by the user' do
          before(:each) do
            allow(instance).to receive(:chef_service_interval_changed?).and_return(false)
          end

          context 'chef-service is running' do
            before do
              allow(instance).to receive(:is_running?).and_return(true)
            end

            it 'just prints message saying no change in interval by user and does not invoke method to start the chef-service' do
              expect(instance).to_not receive(:start_service)
              expect(instance).to receive(:puts).exactly(3).times
              response = instance.send(:enable, '', '', '')
              expect(response).to be == [0, 'success']
            end
          end

          context 'chef-service is not running' do
            before do
              allow(instance).to receive(:is_running?).and_return(false)
            end

            it 'prints message saying no change in interval by user and also invokes the method to start the chef-service' do
              expect(instance).to receive(:start_service)
              expect(instance).to receive(:puts).exactly(3).times
              response = instance.send(:enable, '', '', '')
              expect(response).to be == [0, 'success']
            end
          end
        end
      end

      context 'chef-service is not installed' do
        before(:each) do
          allow(instance).to receive(:is_installed?).and_return(false)
        end

        context 'chef-service did not start automatically after its installation' do
          before do
            allow(instance).to receive(:is_running?).and_return(false)
          end

          it 'invokes methods to set the interval in client.rb file, enable and start the chef-service' do
            expect(instance).to receive(:interval_in_seconds).and_return(300)
            expect(instance).to receive(:set_interval).with(
              '/bootstrap_directory\\client.rb', 300)
            expect(instance).to receive(:install_service)
            expect(instance).to receive(:start_service).with(
              '/bootstrap_directory', '/log_location')
            response = instance.send(:enable, '/extension_root', '/bootstrap_directory', '/log_location', 5)
            expect(response).to be == [0, 'success']
          end
        end

        context 'chef-service starts automatically after its installation' do
          before do
            allow(instance).to receive(:is_running?).and_return(true)
          end

          it 'invokes methods to set the interval in client.rb file and enable the chef-service' do
            expect(instance).to receive(:interval_in_seconds).and_return(1800)
            expect(instance).to receive(:set_interval).with(
              '/bootstrap_directory\\client.rb', 1800)
            expect(instance).to receive(:install_service)
            expect(instance).to_not receive(:start_service).with(
              '/bootstrap_directory', '/log_location')
            response = instance.send(:enable, '/extension_root', '/bootstrap_directory', '/log_location')
            expect(response).to be == [0, 'success']
          end
        end
      end
    end

    context 'Linux platform' do
      before(:each) do
        allow(instance).to receive(:windows?).and_return(false)
        allow(instance).to receive(:puts)
      end

      context 'chef-service cronjob is already installed' do
        before(:each) do
          allow(instance).to receive(:is_installed?).and_return(true)
        end

        context 'chef-service interval has been changed by the user' do
          before do
            allow(instance).to receive(:chef_service_interval_changed?).and_return(true)
          end

          it 'deletes the old cronjob and installs new cronjob for the chef-service with the new interval value' do
            expect(instance).to receive(:puts).exactly(3).times
            expect(instance).to receive(:disable_cron)
            expect(instance).to receive(:enable_cron).with(
              '/extension_root', '/bootstrap_directory', '/log_location', 11)
            response = instance.send(:enable, '/extension_root', '/bootstrap_directory', '/log_location', 11)
            expect(response).to be == [0, 'success']
          end
        end

        context 'chef-service interval has not been changed by the user' do
          before do
            allow(instance).to receive(:chef_service_interval_changed?).and_return(false)
          end

          it 'just says no change in interval by user' do
            expect(instance).to_not receive(:start_service)
            expect(instance).to receive(:puts).exactly(3).times
            response = instance.send(:enable, '', '', '')
            expect(response).to be == [0, 'success']
          end
        end
      end

      context 'chef-service cronjob is not installed' do
        before do
          allow(instance).to receive(:is_installed?).and_return(false)
        end

        it 'installs the chef-service cronjob' do
          expect(instance).to receive(:puts).exactly(1).times
          expect(instance).to receive(:enable_cron).with(
            '/extension_root', '/bootstrap_directory', '/log_location', 20)
          response = instance.send(:enable, '/extension_root', '/bootstrap_directory', '/log_location', 20)
          expect(response).to be == [0, 'success']
        end
      end
    end

    context 'error handling' do
      context 'some error occurred while fetching the chef-service installation status' do
        before do
          allow(instance).to receive(:is_installed?).and_raise('Some unknown error occurred.')
          allow(instance).to receive(:puts)
        end

        it 'raises the error' do
          expect(Chef::Log).to receive(:error).with(
            "Error enabling chef-client service (Some unknown error occurred.)")
          response = instance.send(:enable, '', '', '')
          expect(response).to be == [1, ["Error enabling chef-client service - Some unknown error occurred. - Check log file for details", "error"]]
        end
      end
    end
  end

  describe 'disable' do
    context 'chef-service is already disabled' do
      before(:each) do
        allow(instance).to receive(:is_running?).and_return(false)
      end

      context 'disable command in process' do
        it 'prints message saying chef-service is already stopped' do
          expect(instance).to receive(:puts).with(
            "#{Time.now} chef-client service is already stopped...").exactly(1).times
          response = instance.send(:disable, '')
          expect(response).to be == [0, 'success']
        end
      end

      context 'enable command in process' do
        it 'prints message saying not enabling chef-service as per user\'s choice' do
          expect(instance).to receive(:puts).with(
            "#{Time.now} Not enabling the chef-client service as per the user's choice..."
          ).exactly(1).times
          response = instance.send(:disable, '', '', 0)
          expect(response).to be == [0, 'success']
        end
      end
    end

    context 'chef-service is not disabled' do
      before(:each) do
        allow(instance).to receive(:is_running?).and_return(true)
      end

      context 'Windows platform' do
        before(:each) do
          allow(instance).to receive(:windows?).and_return(true)
        end

        context 'disable command in process' do
          it 'invokes stop_service method to disable the chef-service' do
            expect(instance).to receive(:puts).exactly(2).times
            expect(instance).to_not receive(:set_interval)
            expect(instance).to receive(:stop_service)
            response = instance.send(:disable, '')
            expect(response).to be == [0, 'success']
          end
        end

        context 'enable command in process' do
          it 'invokes set_interval and stop_service method to disable the chef-service' do
            expect(instance).to receive(:puts).exactly(2).times
            expect(instance).to receive(:set_interval).with(
              "/bootstrap_directory\\client.rb", 0)
            expect(instance).to receive(:stop_service)
            response = instance.send(:disable, '/log_location', '/bootstrap_directory', 0)
            expect(response).to be == [0, 'success']
          end
        end
      end

      context 'Linux platform' do
        before do
          allow(instance).to receive(:windows?).and_return(false)
        end

        it 'invokes disable_cron method to disable the chef-service cronjob' do
          expect(instance).to receive(:puts).exactly(2).times
          expect(instance).to receive(:disable_cron)
          response = instance.send(:disable,'')
          expect(response).to be == [0, 'success']
        end
      end
    end

    context 'error handling' do
      context 'some error occurred while fetching the platform information' do
        before do
          allow(instance).to receive(:is_running?).and_return(true)
          allow(instance).to receive(:windows?).and_raise('Some unknown error occurred.')
        end

        it 'raises the error' do
          expect(instance).to receive(:puts).exactly(1).times
          expect(Chef::Log).to receive(:error).with(
            'Error disabling chef-client service (Some unknown error occurred.)')
          response = instance.send(:disable, '')
          expect(response).to be == [1, ["Error disabling chef-client service - Some unknown error occurred. - Check log file for details", "error"]]
        end
      end
    end
  end

  context "get_chef_pid" do
    it "returns chef pid if pid file exists" do
      allow(File).to receive(:exists?).and_return(true)
      allow(File).to receive(:read).and_return("1")
      expect(instance.send(:get_chef_pid)).to eq(1)
    end

    it "returns -1 if pid file doesn't exist" do
      allow(File).to receive(:exists?).and_return(false)
      expect(instance.send(:get_chef_pid)).to eq(-1)
    end
  end

  context "get_chef_pid!" do
    it "returns pid if exists" do
      allow(instance).to receive(:get_chef_pid).and_return(1)
      expect(instance.send(:get_chef_pid!)).to eq(1)
    end

    it "raises error if pid doesn't exist" do
      allow(instance).to receive(:get_chef_pid).and_return(-1)
      expect{instance.send(:get_chef_pid!)}.to raise_error
    end
  end

  context "is_running?" do
    it "tells if chef-service is running on windows" do
      allow(instance).to receive(:windows?).and_return(true)
      allow(instance).to receive(:shell_out).with("sc.exe query chef-client").and_return(OpenStruct.new(:exitstatus => 0, :stdout => "RUNNING"))
      expect(instance.send(:is_running?)).to eq(true)
    end

    it "tells if chef-service is not running on windows" do
      allow(instance).to receive(:windows?).and_return(true)
      allow(instance).to receive(:shell_out).with("sc.exe query chef-client").and_return(OpenStruct.new(:exitstatus => 1, :stdout => ""))
      expect(instance.send(:is_running?)).to eq(false)
    end

    it "tells if chef-service is running on other platforms" do
      allow(instance).to receive(:windows?).and_return(false)
      cron_name = 'azure_chef_extension'
      allow(instance).to receive(:shell_out).with("crontab -l").and_return(OpenStruct.new(:exitstatus => 0, :stdout => cron_name))
      expect(instance.send(:is_running?)).to eq(true)
    end

    it "tells if chef-service is not running on other platforms" do
      allow(instance).to receive(:windows?).and_return(false)
      allow(instance).to receive(:shell_out).with("crontab -l").and_return(OpenStruct.new(:exitstatus => 0, :stdout => ""))
      expect(instance.send(:is_running?)).to eq(false)
    end
  end

  describe 'start_service' do
    context 'service start successful' do
      it 'does not report any error' do
        expect(instance).to receive(:shell_out).with(
          'chef-service-manager  -a start -c /bootstrap_directory\\client.rb -L /log_location\\chef-client.log ').and_return(
            OpenStruct.new(:exitstatus => 0, :stdout => '', :error! => '')
        )
        response = instance.send(:start_service, '/bootstrap_directory', '/log_location')
        expect(response.empty?).to be == true
      end
    end

    context 'service start un-successful' do
      it 'reports the error' do
        expect(instance).to receive(:shell_out).with(
          'chef-service-manager  -a start -c /bootstrap_directory\\client.rb -L /log_location\\chef-client.log ').and_return(
            OpenStruct.new(:exitstatus => 1, :stdout => '', :error! => 'Some unknown error occurred.')
        )
        response = instance.send(:start_service, '/bootstrap_directory', '/log_location')
        expect(response.empty?).to be == false
        expect(response).to be == 'Some unknown error occurred.'
      end
    end
  end

  describe 'set_interval' do
    context 'chef_service_interval exists in the client.rb file' do
      let (:client_rb) { client_rb_with_interval }

      let (:new_client_rb) {
        ["log_level        :debug\n",
         "log_location     STDOUT\n",
         "chef_server_url  \"https://mychefserver.com/organizations/my_org\"\n",
         "validation_client_name  \"my_org-validator\"\n",
         "interval 960\n",
         "node_name \"my-node-01\"\n"
        ]
      }

      before do
        allow(instance).to receive(:read_client_rb).and_return(client_rb)
      end

      it 'updates the client.rb file with the new interval' do
        expect(instance).to receive(:write_client_rb).with(
          '/client.rb', new_client_rb.join
        )
        instance.send(:set_interval, '/client.rb', 960)
      end
    end

    context 'chef_service_interval does not exist in the client.rb file' do
      let (:client_rb) { client_rb_without_interval }

      let (:new_client_rb) {
        ["log_level        :debug\n",
         "log_location     STDOUT\n",
         "chef_server_url  \"https://mychefserver.com/organizations/my_org\"\n",
         "validation_client_name  \"my_org-validator\"\n",
         "node_name \"my-node-02\"\n",
         "interval 1380\n"
        ]
      }

      before do
        allow(instance).to receive(:read_client_rb).and_return(client_rb)
      end

      it 'adds interval in the client.rb file' do
        expect(instance).to receive(:write_client_rb).with(
          '/client.rb', new_client_rb.join
        )
        instance.send(:set_interval, '/client.rb', 1380)
      end
    end
  end

  describe 'stop_service' do
    context 'service stop successful' do
      it 'does not report any error' do
        expect(instance).to receive(:shell_out).with(
          'sc.exe stop chef-client').and_return(
            OpenStruct.new(:exitstatus => 0, :stdout => '', :error! => '')
        )
        response = instance.send(:stop_service)
        expect(response.empty?).to be == true
      end
    end

    context 'service stop un-successful' do
      it 'reports the error' do
        expect(instance).to receive(:shell_out).with(
          'sc.exe stop chef-client').and_return(
            OpenStruct.new(:exitstatus => 1, :stdout => '', :error! => 'Some unknown error occurred.')
        )
        response = instance.send(:stop_service)
        expect(response.empty?).to be == false
        expect(response).to be == 'Some unknown error occurred.'
      end
    end
  end

  describe 'restart_service' do
    context 'chef-service is already running' do
      before do
        allow(instance).to receive(:is_running?).and_return(true)
      end

      it 'stops and then starts the chef-service' do
        expect(instance).to receive(:stop_service)
        expect(instance).to receive(:start_service)
        instance.send(:restart_service)
      end
    end

    context 'chef-service is not running' do
      before do
        allow(instance).to receive(:is_running?).and_return(false)
      end

      it 'just starts the chef-service' do
        expect(instance).to_not receive(:stop_service)
        expect(instance).to receive(:start_service)
        instance.send(:restart_service)
      end
    end
  end

  describe 'disable_cron' do
    before do
      allow(File).to receive(:read).and_return('chef_client_cron_delete_erb')
    end

    context 'cronjob disable successful' do
      it 'does not report any error' do
        expect(ERBHelpers::ERBCompiler).to receive(:run).with('chef_client_cron_delete_erb',
          { :name => 'azure_chef_extension' }
        ).and_return('chef_disable_cron')
        expect(instance).to receive(:puts)
        expect(instance).to receive(:shell_out).with(
          'chef-apply -e "chef_disable_cron"').and_return(
            OpenStruct.new(:exitstatus => 0, :stdout => '', :error! => '')
        )
        response = instance.send(:disable_cron)
        expect(response.empty?).to be == true
      end
    end

    context 'cronjob disable un-successful' do
      it 'reports the error' do
        expect(ERBHelpers::ERBCompiler).to receive(:run).with('chef_client_cron_delete_erb',
          { :name => 'azure_chef_extension' }
        ).and_return('chef_disable_cron')
        expect(instance).to receive(:puts)
        expect(instance).to receive(:shell_out).with(
          'chef-apply -e "chef_disable_cron"').and_return(
            OpenStruct.new(:exitstatus => 1, :stdout => '', :error! => 'Some unknown error occurred.')
        )
        response = instance.send(:disable_cron)
        expect(response.empty?).to be == false
        expect(response).to be == 'Some unknown error occurred.'
      end
    end
  end

  describe 'install_service' do
    context 'chef-service enable successful' do
      it 'does not report any error' do
        expect(instance).to receive(:puts).exactly(2).times
        expect(instance).to receive(:shell_out).with(
          'chef-service-manager -a install').and_return(
            OpenStruct.new(:exitstatus => 0, :stdout => '', :error! => '', :error? => false)
        )
        instance.send(:install_service)
      end
    end

    context 'chef-service install un-successful' do
      it 'reports the error' do
        expect(instance).to receive(:puts).exactly(1).times
        expect(instance).to receive(:shell_out).with(
          'chef-service-manager -a install').and_return(
            OpenStruct.new(:exitstatus => 0, :stdout => '', :error! => 'Some unknown error occurred.', :error? => true)
        )
        response = instance.send(:install_service)
        expect(response.empty?).to be == false
        expect(response).to be == 'Some unknown error occurred.'
      end
    end
  end

  describe 'enable_cron' do
    before do
      allow(File).to receive(:read).and_return('chef_client_cron_create_erb')
      instance.instance_variable_set(:@chef_config, { :splay => nil })
    end

    context 'chef-service cronjob enable successful' do
      it 'does not report any error' do
        expect(instance).to receive(:puts).exactly(3).times
        expect(ERBHelpers::ERBCompiler).to receive(:run).with('chef_client_cron_create_erb',
          { :name => 'azure_chef_extension', :extension_root => '/extension_root',
            :bootstrap_directory => '/bootstrap_directory', :log_location =>  '/log_location',
            :interval => 15, :sleep_time => 0, :chef_pid_file => '/bootstrap_directory/azure-chef-client.pid'
          }
        ).and_return('chef_enable_cron')
        expect(instance).to receive(:shell_out).with(
          'chef-apply -e "chef_enable_cron"').and_return(
            OpenStruct.new(:exitstatus => 0, :stdout => '', :error! => '', :error? => false)
        )
        instance.send(:enable_cron, '/extension_root', '/bootstrap_directory', '/log_location', 15)
      end
    end

    context 'chef-service cronjob enable un-successful' do
      it 'reports the error' do
        expect(instance).to receive(:puts).exactly(2).times
        expect(ERBHelpers::ERBCompiler).to receive(:run).with('chef_client_cron_create_erb',
          { :name => 'azure_chef_extension', :extension_root => '/extension_root',
            :bootstrap_directory => '/bootstrap_directory', :log_location =>  '/log_location',
            :interval => 7, :sleep_time => 0, :chef_pid_file => '/bootstrap_directory/azure-chef-client.pid'
          }
        ).and_return('chef_enable_cron')
        expect(instance).to receive(:shell_out).with(
          'chef-apply -e "chef_enable_cron"').and_return(
            OpenStruct.new(:exitstatus => 1, :stdout => '', :error! => 'Some unknown error occurred.', :error? => true)
        )
        response = instance.send(:enable_cron, '/extension_root', '/bootstrap_directory', '/log_location', 7)
        expect(response.empty?).to be == false
        expect(response).to be == 'Some unknown error occurred.'
      end
    end
  end

  describe 'is_installed?' do
    context 'Windows platform' do
      before(:each) do
        allow(instance).to receive(:windows?).and_return(true)
      end

      context 'chef-service is installed' do
        it 'returns true' do
          expect(instance).to receive(:shell_out).with('sc.exe query chef-client').and_return(
            OpenStruct.new(:exitstatus => 0, :stdout => 'chef-service is installed')
          )
          response = instance.send(:is_installed?)
          expect(response).to be == true
        end
      end

      context 'chef-service is not installed' do
        it 'returns false' do
          expect(instance).to receive(:shell_out).with('sc.exe query chef-client').and_return(
            OpenStruct.new(:exitstatus => 1060, :stdout => 'The specified service does not exist as an installed service.')
          )
          response = instance.send(:is_installed?)
          expect(response).to be == false
        end
      end
    end

    context 'Linux platform' do
      before do
        allow(instance).to receive(:windows?).and_return(false)
      end

      it 'invokes is_running? method' do
        expect(instance).to receive(:is_running?)
        expect(instance).to_not receive(:shell_out)
        instance.send(:is_installed?)
      end
    end
  end

  describe 'read_client_rb' do
    it 'invokes File.readlines method' do
      expect(File).to receive(:readlines).with('/client_rb')
      instance.send(:read_client_rb, '/client_rb')
    end

    context 'example' do
      before do
        File.write('dummy_client.rb', "my dummy client file line1.\nmy dummy client file line2.\n")
      end

      it 'reads the file contents and returns an array of lines' do
        response = instance.send(:read_client_rb, 'dummy_client.rb')
        expect(response.class).to be == Array
        expect(response.length).to be == 2
        expect(response.first).to be == "my dummy client file line1.\n"
      end

      after do
        FileUtils.rm_rf 'dummy_client.rb'
      end
    end
  end

  describe 'interval_exist?' do
    context 'interval exist in the given client.rb file contents' do
      it 'returns true' do
        response = instance.send(:interval_exist?, client_rb_with_interval)
        expect(response).to be == true
      end
    end

    context 'interval does not exist in the given client.rb file contents' do
      it 'returns false' do
        response = instance.send(:interval_exist?, client_rb_without_interval)
        expect(response).to be == false
      end
    end
  end

  describe 'interval_index' do
    context 'interval exist in the given client.rb file contents' do
      it 'returns array index of the line where interval is set in the client.rb file' do
        response = instance.send(:interval_index, client_rb_with_interval)
        expect(response).to be == 4
      end
    end

    context 'interval does not exist in the given client.rb file contents' do
      it 'returns nil' do
        response = instance.send(:interval_index, client_rb_without_interval)
        expect(response).to be == nil
      end
    end
  end

  describe 'interval_string' do
    it 'returns the string containing the interval attribute' do
      response = instance.send(:interval_string, 27)
      expect(response).to be == "interval 27\n"
    end
  end

  describe 'write_client_rb' do
    it 'invokes File.write method to write the given contents into the client.rb file' do
      expect(File).to receive(:write).with('/client_rb', ['line1', 'line2'])
      instance.send(:write_client_rb, '/client_rb', ['line1', 'line2'])
    end
  end

  describe 'interval_in_seconds' do
    it 'returns the value in seconds of the given interval' do
      response = instance.send(:interval_in_seconds, 18)
      expect(response).to be == 1080
    end
  end

  describe 'interval_in_minutes' do
    it 'returns the value in minutes of the given interval' do
      response = instance.send(:interval_in_minutes, 1080)
      expect(response).to be == 18
    end
  end

  describe 'old_client_rb_interval' do
    context 'example-1' do
      it 'returns the integer value of the interval extracted from the given interval attribute string' do
        response = instance.send(:old_client_rb_interval, "interval 1620\n")
        expect(response.class).to be == Fixnum
        expect(response).to be == 1620
      end
    end

    context 'example-2' do
      it 'returns the integer value of the interval extracted from the given interval attribute string' do
        response = instance.send(:old_client_rb_interval, "interval             480  \n")
        expect(response.class).to be == Fixnum
        expect(response).to be == 480
      end
    end
  end

  describe 'chef_service_interval_changed?' do
    before(:each) do
      allow(instance).to receive(:puts)
    end

    context 'Windows platform' do
      before(:each) do
        allow(instance).to receive(:windows?).and_return(true)
      end

      context 'interval exist in the given client.rb file contents' do
        before do
          allow(instance).to receive(:read_client_rb).and_return(client_rb_with_interval)
        end

        context 'interval has changed' do
          it 'returns true' do
            response = instance.send(:chef_service_interval_changed?, 25)
            expect(response).to be == true
          end
        end

        context 'interval has not changed' do
          it 'returns false' do
            response = instance.send(:chef_service_interval_changed?, 21)
            expect(response).to be == false
          end
        end
      end

      context 'interval does not exist in the given client.rb file contents' do
        before do
          allow(instance).to receive(:read_client_rb).and_return(client_rb_without_interval)
        end

        context 'interval has changed' do
          it 'returns true' do
            response = instance.send(:chef_service_interval_changed?, 15)
            expect(response).to be == true
          end
        end

        context 'interval has not changed' do
          it 'returns false' do
            response = instance.send(:chef_service_interval_changed?, 30)
            expect(response).to be == false
          end
        end
      end
    end

    context 'Linux platform' do
      before(:each) do
        allow(instance).to receive(:windows?).and_return(false)
      end

      context 'interval has changed' do
        it 'returns true' do
          expect(instance).to receive(:shell_out).with(
            "crontab -l | grep -A 1 azure_chef_extension | sed -n '2p'").and_return(
              OpenStruct.new(:exitstatus => 0, :stdout => '*/19 * * * * /bin/sleep 0; chef-client -c /client.rb -L /chef-client.log --pid /azure-chef-client.pid --once')
            )
          response = instance.send(:chef_service_interval_changed?, 15)
          expect(response).to be == true
        end
      end

      context 'interval has not changed' do
        it 'returns false' do
          expect(instance).to receive(:shell_out).with(
            "crontab -l | grep -A 1 azure_chef_extension | sed -n '2p'").and_return(
              OpenStruct.new(:exitstatus => 0, :stdout => '*/19 * * * * /bin/sleep 0; chef-client -c /client.rb -L /chef-client.log --pid /azure-chef-client.pid --once')
            )
          response = instance.send(:chef_service_interval_changed?, 19)
          expect(response).to be == false
        end
      end
    end
  end
end

def client_rb_with_interval
  [
    "log_level        :debug\n",
    "log_location     STDOUT\n",
    "chef_server_url  \"https://mychefserver.com/organizations/my_org\"\n",
    "validation_client_name  \"my_org-validator\"\n",
    "interval 1260\n",
    "node_name \"my-node-01\"\n"
  ]
end

def client_rb_without_interval
  [
    "log_level        :debug\n",
    "log_location     STDOUT\n",
    "chef_server_url  \"https://mychefserver.com/organizations/my_org\"\n",
    "validation_client_name  \"my_org-validator\"\n",
    "node_name \"my-node-02\"\n"
  ]
end
