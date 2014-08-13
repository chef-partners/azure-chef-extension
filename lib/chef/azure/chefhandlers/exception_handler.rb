require 'chef/log'
require 'chef/azure/helpers/shared'

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
        load_azure_env(@chef_extension_root)
        message = "Check log file for details...\nBacktrace:\n"
        message << Array(backtrace).join("\n")
        report_status_to_azure message, "error"
      end
    end
  end
end
