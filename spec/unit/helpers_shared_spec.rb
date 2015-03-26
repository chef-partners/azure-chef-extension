require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require 'chef/azure/helpers/shared'

describe ChefAzure::Shared do
  let(:dummy_class) { Class.new { extend ChefAzure::Shared } }

  context "bootstrap directory" do
    it "for windows" do
      allow(dummy_class).to receive(:windows?).and_return(true)
      expect(dummy_class.bootstrap_directory).to eq("#{ENV['SYSTEMDRIVE']}/chef")
    end

    it "for linux" do
      allow(dummy_class).to receive(:windows?).and_return(false)
      expect(dummy_class.bootstrap_directory).to eq("/etc/chef")
    end
  end

  context "chef_bin path" do
    it "for windows" do
      allow(dummy_class).to receive(:windows?).and_return(true)
      expect(dummy_class.chef_bin_path).to eq("C:\\opscode\\chef\\bin;C:\\opscode\\chef\\embedded\\bin")
    end

    it "for linux" do
      allow(dummy_class).to receive(:windows?).and_return(false)
      expect(dummy_class.chef_bin_path).to eq("/opt/chef/bin:/opt/chef/embedded/bin")
    end
  end

  context "append_to path" do
    it "for windows" do
      allow(dummy_class).to receive(:windows?).and_return(true)
      append_path = dummy_class.send(:append_to_path,"")
      expect(append_path).to eq("#{ENV["PATH"]}")
    end

    it "for linux" do
      allow(dummy_class).to receive(:windows?).and_return(false)
      append_path = dummy_class.send(:append_to_path,"")
      expect(append_path).to eq("#{ENV["PATH"]}")
    end
  end

  context "chef_config" do
    it "returns chef_config from client.rb" do
      allow(Chef::Config).to receive(:from_file).and_return("")
      allow(Chef::Config).to receive(:empty?).and_return(true)
      expect(dummy_class.chef_config).to be_empty
    end
  end
end


describe ChefAzure::Config do
  let(:dummy_class) { Class.new { extend ChefAzure::Config } }

  context "read_config" do
    it "returns config value" do
      azure_heart_beat_file = "heartbeat"
      azure_status_folder = "status_folder"
      azure_plugin_log_location = "log"
      azure_config_folder = "config"
      azure_status_file = "status_folder/.status"

      expect(File).to receive(:read)
      json_response = ["handlerEnvironment" => {"heartbeatFile" => azure_heart_beat_file, "statusFolder" => azure_status_folder,
        "logFolder" => azure_plugin_log_location, "configFolder" => azure_config_folder}]
      allow(JSON).to receive(:parse).and_return(json_response)

      allow(File).to receive(:basename).and_return("")

      read_config = dummy_class.send(:read_config,"")
      expect(read_config).to match_array([azure_heart_beat_file,azure_status_folder,azure_plugin_log_location,azure_config_folder,azure_status_file])
    end
  end
end