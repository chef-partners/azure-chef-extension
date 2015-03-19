#
# Author:: Seth Chisamore (<schisamo@opscode.com>)
# Copyright:: Copyright (c) 2011 Opscode, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'chef/knife/core/bootstrap_context'

# Chef::Util::PathHelper in Chef 11 is a bit juvenile still
  require 'chef/azure/core/path_helper'

class Chef
  class Knife
    module Core
      # Instances of BootstrapContext are the context objects (i.e., +self+) for
      # bootstrap templates. For backwards compatability, they +must+ set the
      # following instance variables:
      # * @config   - a hash of knife's config values
      # * @run_list - the run list for the node to boostrap
      #
      class WindowsBootstrapContext < BootstrapContext
        PathHelper = ::Knife::Windows::PathHelper

        def initialize(config, run_list, chef_config, secret=nil)
          @config       = config
          @run_list     = run_list
          @chef_config  = chef_config
          # Compatibility with Chef 12 and Chef 11 versions
          begin
            # Pass along the secret parameter for Chef 12
            super(config, run_list, chef_config, secret)
          rescue ArgumentError
            # The Chef 11 base class only has parameters for initialize
            super(config, run_list, chef_config)
          end
        end

        def validation_key
          escape_and_echo(super)
        end

        def encrypted_data_bag_secret
          escape_and_echo(@config[:encrypted_data_bag_secret])
        end

        def trusted_certs_script
          @trusted_certs_script ||= trusted_certs_content
        end

        def config_content
          client_rb = ""
          client_rb << @config[:user_client_rb] + "\r\n" unless @config[:user_client_rb].empty

          client_rb = super
          client_rb << <<-CONFIG
log_level        :info
log_location     '#{@config[:log_location]}/chef-client.log'
client_key        "c:/chef/client.pem"
validation_key    "c:/chef/validation.pem"

file_cache_path   "c:/chef/cache"
file_backup_path  "c:/chef/backup"
cache_options     ({:path => "c:/chef/cache/checksums", :skip_expires => true})
CONFIG

          # We configure :verify_api_cert only when it's overridden on the CLI
          # or when specified in the knife config.
          if !@config[:node_verify_api_cert].nil? || knife_config.has_key?(:verify_api_cert)
            value = @config[:node_verify_api_cert].nil? ? knife_config[:verify_api_cert] : @config[:node_verify_api_cert]
            client_rb << %Q{verify_api_cert #{value}\n}
          end

          # We configure :ssl_verify_mode only when it's overridden on the CLI
          # or when specified in the knife config.
          if @config[:node_ssl_verify_mode] || knife_config.has_key?(:ssl_verify_mode)
            value = case @config[:node_ssl_verify_mode]
            when "peer"
              :verify_peer
            when "none"
              :verify_none
            when nil
              knife_config[:ssl_verify_mode]
            else
              nil
            end

            if value
              client_rb << %Q{ssl_verify_mode :#{value}\n}
            end
          end

          if @config[:ssl_verify_mode]
            client_rb << %Q{ssl_verify_mode :#{knife_config[:ssl_verify_mode]}\n}
          end

          if knife_config[:bootstrap_proxy]
            client_rb << "\n"
            client_rb << %Q{no_proxy          "#{knife_config[:bootstrap_no_proxy]}"\n} if knife_config[:bootstrap_no_proxy]
          end

          if @config[:encrypted_data_bag_secret]
            client_rb << %Q{encrypted_data_bag_secret "c:/chef/encrypted_data_bag_secret"\n}
          end

          if(Gem::Specification.find_by_name('chef').version.version.to_f >= 12)
            unless trusted_certs.empty?
              client_rb << %Q{trusted_certs_dir "c:/chef/trusted_certs"\n}
            end
          end

          client_rb << <<-CONFIG
# Add support to use chef Handlers for heartbeat and
# status reporting to Azure
require \"chef/azure/chefhandlers/start_handler\"
require \"chef/azure/chefhandlers/report_handler\"
require \"chef/azure/chefhandlers/exception_handler\"

start_handlers << AzureExtension::StartHandler.new(\"#{@config[:chef_extension_root]}\")
report_handlers << AzureExtension::ReportHandler.new(\"#{@config[:chef_extension_root]}\")
exception_handlers << AzureExtension::ExceptionHandler.new(\"#{@config[:chef_extension_root]}\")

CONFIG

          escape_and_echo(client_rb)
        end

        def start_chef
          start_chef = "SET \"PATH=%PATH%;C:\\ruby\\bin;C:\\opscode\\chef\\bin;C:\\opscode\\chef\\embedded\\bin\"\n"
          start_chef << "chef-client -c c:/chef/client.rb -E #{bootstrap_environment}\n"
        end

        def bootstrap_directory
          bootstrap_directory = "C:\\chef"
        end

        def first_boot
          first_boot_attributes_and_run_list = (@config[:first_boot_attributes] || {}).merge(:run_list => @run_list)
          escape_and_echo(first_boot_attributes_and_run_list.to_json)
        end

        # escape WIN BATCH special chars
        # and prefixes each line with an
        # echo
        def escape_and_echo(file_contents)
          file_contents.gsub(/^(.*)$/, 'echo.\1').gsub(/([(<|>)^])/, '^\1')
        end

        private

        # Returns a string for copying the trusted certificates on the workstation to the system being bootstrapped
        # This string should contain both the commands necessary to both create the files, as well as their content
        def trusted_certs_content
          content = ""
          if @chef_config[:trusted_certs_dir]
            Dir.glob(File.join(PathHelper.escape_glob(@chef_config[:trusted_certs_dir]), "*.{crt,pem}")).each do |cert|
              content << "> #{bootstrap_directory}/trusted_certs/#{File.basename(cert)} (\n" +
                        escape_and_echo(IO.read(File.expand_path(cert))) + "\n)\n"
            end
          end
          content
        end
      end
    end
  end
end
