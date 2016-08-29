require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require 'chef/azure/helpers/shared'
require 'chef/azure/service'
require 'ostruct'

describe ChefService do
  let (:instance) { ChefService.new }

  it { expect {instance}.to_not raise_error }

  context "enable" do
    it "doesn't enable again if chef-client is already running" do
      allow(instance).to receive(:is_running?).and_return(true)
      expect(instance).to receive(:puts).and_return("chef-client service is already running...")
      enable_cmd = instance.send(:enable, "", "", "")
      expect(enable_cmd).to eq([0, "success"])
    end

    it "enables for windows" do
      allow(instance).to receive(:is_running?).and_return(false)
      allow(instance).to receive(:windows?).and_return(true)
      expect(instance).to receive(:puts).and_return("Starting chef-client service...", "Started chef-client service.")
      expect(instance).to receive(:shell_out).with("sc.exe start chef-client").and_return(OpenStruct.new(:exitstatus => 0, :stdout => ""))
      enable_cmd = instance.send(:enable, "", "", "")
      expect(enable_cmd).to eq([0, "success"])
    end

    it "enables for unix like platforms" do
      allow(instance).to receive(:is_running?).and_return(false)
      allow(instance).to receive(:windows?).and_return(false)
      allow(instance).to receive(:chef_config).and_return({:interval => nil, :splay => nil})
      allow(ERBHelpers::ERBCompiler).to receive(:run).and_return("")
      expect(instance).to receive(:puts).and_return("Starting chef-client service...", "Adding chef cron = \"\"", "Started chef-client service.")
      expect(instance).to receive(:shell_out).and_return(OpenStruct.new(:exitstatus => 0, :stdout => ""))
      enable_cmd = instance.send(:enable, "", "", "")
      expect(enable_cmd).to eq([0, "success"])
    end
  end

  context "disable" do
    it "doesn't disable if chef-client is not running" do
      allow(instance).to receive(:is_running?).and_return(false)
      expect(instance).to receive(:puts).and_return("chef-client service is already stopped...")
      disable_cmd = instance.send(:disable, "")
      expect(disable_cmd).to eq([0, "success"])
    end

    it "disables for windows" do
      allow(instance).to receive(:is_running?).and_return(true)
      allow(instance).to receive(:windows?).and_return(true)
      expect(instance).to receive(:puts).and_return("Disabling chef-client service...", "Disabled chef-client service")
      expect(instance).to receive(:shell_out).with("sc.exe stop chef-client").and_return(OpenStruct.new(:exitstatus => 0, :stdout => ""))
      disable_cmd = instance.send(:disable, "")
      expect(disable_cmd).to eq([0, "success"])
    end

    it "disables for unix like platforms" do
      allow(instance).to receive(:is_running?).and_return(true)
      allow(instance).to receive(:windows?).and_return(false)
      allow(ERBHelpers::ERBCompiler).to receive(:run).and_return("")
      expect(instance).to receive(:puts).and_return("Disabling chef-client service...", "Removing chef-cron = \"\"" ,"Disabled chef-client service")
      expect(instance).to receive(:shell_out).and_return(OpenStruct.new(:exitstatus => 0, :stdout => ""))
      disable_cmd = instance.send(:disable, "")
      expect(disable_cmd).to eq([0, "success"])
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
          'sc.exe start chef-client').and_return(
            OpenStruct.new(:exitstatus => 0, :stdout => '', :error! => '')
        )
        response = instance.send(:start_service)
        expect(response.empty?).to be == true
      end
    end

    context 'service start un-successful' do
      it 'reports the error' do
        expect(instance).to receive(:shell_out).with(
          'sc.exe start chef-client').and_return(
            OpenStruct.new(:exitstatus => 1, :stdout => '', :error! => 'Some unknown error occurred.')
        )
        response = instance.send(:start_service)
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
    context 'cronjob disable successful' do
      it 'does not report any error' do
        expect(ERBHelpers::ERBCompiler).to receive(:run).and_return('delete_cron')
        expect(instance).to receive(:puts)
        expect(instance).to receive(:shell_out).with(
          'chef-apply -e "delete_cron"').and_return(
            OpenStruct.new(:exitstatus => 0, :stdout => '', :error! => '')
        )
        response = instance.send(:disable_cron)
        expect(response.empty?).to be == true
      end
    end

    context 'cronjob disable un-successful' do
      it 'reports the error' do
        expect(ERBHelpers::ERBCompiler).to receive(:run).and_return('delete_cron')
        expect(instance).to receive(:puts)
        expect(instance).to receive(:shell_out).with(
          'chef-apply -e "delete_cron"').and_return(
            OpenStruct.new(:exitstatus => 1, :stdout => '', :error! => 'Some unknown error occurred.')
        )
        response = instance.send(:disable_cron)
        expect(response.empty?).to be == false
        expect(response).to be == 'Some unknown error occurred.'
      end
    end
  end

  describe 'enable_service' do
    context 'chef-service enable successful' do
      it 'does not report any error' do
        expect(instance).to receive(:puts).exactly(2).times
        expect(instance).to receive(:shell_out).with(
          'chef-service-manager  -a install -c /bootstrap_directory\\client.rb -L /log_location\\chef-client.log ').and_return(
            OpenStruct.new(:exitstatus => 0, :stdout => '', :error! => '', :error? => false)
        )
        instance.send(:enable_service, '/bootstrap_directory', '/log_location')
      end
    end

    context 'chef-service enable un-successful' do
      it 'reports the error' do
        expect(instance).to receive(:puts).exactly(1).times
        expect(instance).to receive(:shell_out).with(
          'chef-service-manager  -a install -c /bootstrap_directory\\client.rb -L /log_location\\chef-client.log ').and_return(
            OpenStruct.new(:exitstatus => 0, :stdout => '', :error! => 'Some unknown error occurred.', :error? => true)
        )
        response = instance.send(:enable_service, '/bootstrap_directory', '/log_location')
        expect(response.empty?).to be == false
        expect(response).to be == 'Some unknown error occurred.'
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
