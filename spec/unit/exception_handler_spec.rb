require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require 'chef/azure/chefhandlers/exception_handler'
require 'ostruct'

describe AzureExtension do
  include AzureExtension
  let (:extension_root) { "./" }
  let (:instance) { AzureExtension::ExceptionHandler.new(extension_root) }

  # singleton class for mocking Chef::Search::Query
  class DummyClass
    def search
      [[OpenStruct.new(:run_list => [])]]
    end

    def reset!(some_arg)
    end

    def run_list
      OpenStruct.new(:run_list_items => OpenStruct.new(:clear => ""))
    end
  end

  context "report on chef-client failure" do
    it "reports to heartbeat when node is not registered" do
      allow(instance.run_status).to receive(:failed?).and_return(true)
      allow(File).to receive(:exists?).and_return(false)
      allow(instance).to receive(:backtrace).and_return(nil)
      expect(instance).to receive(:load_azure_env)
      expect(instance).to receive(:report_heart_beat_to_azure).with(AzureHeartBeat::READY, 0, "chef-service is running properly. Chef client run failed with error- Check log file for details...\nBacktrace:\n")
      instance.report
    end

    it "reports to heartbeat and loads runlist from first_boot.json is node is registered" do
      # mocking node method
      def instance.node
        OpenStruct.new(:name => "")
      end

      allow(instance.run_status).to receive(:failed?).and_return(true)
      allow(File).to receive(:exists?).and_return(true)
      allow(Chef::Search::Query).to receive(:new).and_return(DummyClass.new)
      allow(Chef::Search::Query.new).to receive(:search).and_return([[OpenStruct.new(:run_list => [])]])
      expect(instance).to receive(:load_run_list)
      allow(instance).to receive(:backtrace).and_return(nil)
      expect(instance).to receive(:load_azure_env)
      expect(instance).to receive(:report_heart_beat_to_azure).with(AzureHeartBeat::READY, 0, "chef-service is running properly. Chef client run failed with error- Check log file for details...\nBacktrace:\n")
      instance.report
    end
  end

  context "load_run_list" do
    it "loads runlist from first_boot.json" do
      # mocking node methods
      def instance.node
        OpenStruct.new(:run_list => DummyClass.new, :save => "", :name => "")
      end

      allow(File).to receive(:read).and_return("{\"run_list\":[\"recipe[getting-started]\"]}\n")
      expect(JSON).to receive(:parse).and_return({"run_list"=>["recipe[getting-started]"]})
      allow(Chef::Node).to receive(:load).with("").and_return(OpenStruct.new(:save => ""))
      allow(instance).to receive(:set_run_list)
      instance.load_run_list
    end
  end

  context "set_run_list" do
    it "sets runlist for node object" do
      #DummyClass has node method run_list
      node = DummyClass.new
      entries = []
      instance.send(:set_run_list, node, entries)
    end
  end
end

