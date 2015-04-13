require 'chef/log'
require 'chef/azure/helpers/shared'
require 'json'

module AzureExtension
  class ExceptionHandler < Chef::Handler
    include ChefAzure::Shared
    include ChefAzure::Config
    include ChefAzure::Reporting

    def initialize(extension_root)
      @chef_extension_root = extension_root
    end

    def report
      if run_status.failed?
        if File.exists?("#{bootstrap_directory}/node-registered")
          # query node to get runlist of chef server
          query = Chef::Search::Query.new
          result = query.search(:node,"name:#{node.name}")
          remote_node_obj = result.first.first
          # load runlist from first_boot.json if runlist on chef server is empty
          load_run_list if remote_node_obj.run_list.empty?
        end
        load_azure_env
        message = "Check log file for details...\nBacktrace:\n"
        message << Array(backtrace).join("\n")
        report_heart_beat_to_azure(AzureHeartBeat::READY, 0, "chef-service is running properly. Chef client run failed with error- #{message}")
      end
    end

    def load_run_list
      first_boot = File.read("#{bootstrap_directory}/first-boot.json")
      first_boot = JSON.parse(first_boot)
      run_list = first_boot["run_list"]
      nodeObj = Chef::Node.load(node.name)
      set_run_list(nodeObj, run_list)
      nodeObj.save
    end

    # set runlist
    def set_run_list(node, entries)
      node.run_list.run_list_items.clear
      entries.each { |e| node.run_list << e }
    end
  end
end
