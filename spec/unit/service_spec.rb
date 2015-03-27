require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require 'chef/azure/helpers/shared'
require 'chef/azure/service'
require 'ostruct'

describe ChefService do
  let (:instance) { ChefService.new }

  it { expect {instance}.to_not raise_error }

  context "install" do
    it "installs service successfully for windows" do
      allow(instance).to receive(:windows?).and_return(true)
      shellout_output1 = OpenStruct.new(:exitstatus => 0, :stdout => "Service chef-client doesn't exist on the system")
      shellout_output2 = OpenStruct.new(:exitstatus => 0, :stdout => "", :error => nil)
      allow(instance).to receive(:shell_out).and_return(shellout_output1, shellout_output2)
      expect(instance).to receive(:puts).and_return("Installing chef-client service...", "Installed chef-client service.")
      install_cmd = instance.send(:install, "")
      expect(install_cmd).to eq([0, "success"])
    end

    it "doesn't install if chef-client service is already installed on windows" do
      allow(instance).to receive(:windows?).and_return(true)
      allow(instance).to receive(:shell_out).and_return(OpenStruct.new(:exitstatus => 1, :stdout => ""))
      expect(instance).to receive(:puts).and_return("chef-client service is already installed.")
      install_cmd = instance.send(:install, "")
      expect(install_cmd).to eq([0, "success"])
    end

    it "fails if shell_out commands fail" do
      error_message = "Error installing chef-client service"
      e = "Failure"
      allow(instance).to receive(:windows?).and_return(true)
      allow(instance).to receive(:shell_out).and_raise(e)
      expect(Chef::Log).to receive(:error)
      install_cmd = instance.send(:install, "")
      expect(install_cmd).to eq([1, "#{error_message}- #{e} - Check log file for details"])
    end
  end

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
      expect(instance).to receive(:shell_out).with("chef-service-manager -a start").and_return(OpenStruct.new(:exitstatus => 0, :stdout => ""))
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
      expect(instance).to receive(:shell_out).with("chef-service-manager -a stop").and_return(OpenStruct.new(:exitstatus => 0, :stdout => ""))
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
      expect(instance.get_chef_pid).to eq(1)
    end

    it "returns -1 if pid file doesn't exist" do
      allow(File).to receive(:exists?).and_return(false)
      expect(instance.get_chef_pid).to eq(-1)
    end
  end

  context "get_chef_pid!" do
    it "returns pid if exists" do
      allow(instance).to receive(:get_chef_pid).and_return(1)
      expect(instance.get_chef_pid!).to eq(1)
    end

    it "raises error if pid doesn't exist" do
      allow(instance).to receive(:get_chef_pid).and_return(-1)
      expect{instance.get_chef_pid!}.to raise_error
    end
  end

  context "is_running?" do
    it "tells if chef-service is running on windows" do
      allow(instance).to receive(:windows?).and_return(true)
      allow(instance).to receive(:shell_out).with("chef-service-manager -a status").and_return(OpenStruct.new(:exitstatus => 0, :stdout => "State of chef-client service is: running"))
      expect(instance.is_running?).to eq(true)
    end

    it "tells if chef-service is not running on windows" do
      allow(instance).to receive(:windows?).and_return(true)
      allow(instance).to receive(:shell_out).with("chef-service-manager -a status").and_return(OpenStruct.new(:exitstatus => 1, :stdout => ""))
      expect(instance.is_running?).to eq(false)
    end

    it "tells if chef-service is running on other platforms" do
      allow(instance).to receive(:windows?).and_return(false)
      cron_name = 'azure_chef_extension'
      allow(instance).to receive(:shell_out).with("crontab -l").and_return(OpenStruct.new(:exitstatus => 0, :stdout => cron_name))
      expect(instance.is_running?).to eq(true)
    end

    it "tells if chef-service is not running on other platforms" do
      allow(instance).to receive(:windows?).and_return(false)
      allow(instance).to receive(:shell_out).with("crontab -l").and_return(OpenStruct.new(:exitstatus => 0, :stdout => ""))
      expect(instance.is_running?).to eq(false)
    end
  end
end