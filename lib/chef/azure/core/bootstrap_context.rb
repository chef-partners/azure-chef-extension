class Chef
  class Knife
    module Core
      # Instances of BootstrapContext are the context objects (i.e., +self+) for
      # bootstrap templates. For backwards compatability, they +must+ set the
      # following instance variables:
      # * @config   - a hash of knife's config values
      # * @run_list - the run list for the node to boostrap
      #
      class BootstrapContext

        def validation_key
          @chef_config[:validation_key_content]
        end

        def client_key
          @chef_config[:client_key_content]
        end

        def first_boot
          Hash(@config[:first_boot_attributes]).merge(:run_list => @run_list)
        end

        def config_content
          client_rb = ""
          # Add user provided client_rb to the beginning of a file.
          # And replace user_client_rb "'" (single qoute) by "\"" (escaped double qoute) if any,
          # This is necessary as Mixlib::Shellout removes "'" (single qoute) on Linux.
          client_rb << @config[:user_client_rb].gsub("'","\"") + "\r\n" unless @config[:user_client_rb].empty?

          if @config[:chef_node_name]
            client_rb << %Q{node_name "#{@config[:chef_node_name]}"\n}
          else
            client_rb << "# Using default node name (fqdn)\n"
          end

          if knife_config[:bootstrap_proxy]
            client_rb << %Q{http_proxy        "#{knife_config[:bootstrap_proxy]}"\n}
            client_rb << %Q{https_proxy       "#{knife_config[:bootstrap_proxy]}"\n}
          end

          if knife_config[:bootstrap_no_proxy]
            client_rb << %Q{no_proxy       "#{knife_config[:bootstrap_no_proxy]}"\n}
          end

          if encrypted_data_bag_secret
            client_rb << %Q{encrypted_data_bag_secret "/etc/chef/encrypted_data_bag_secret"\n}
          end

          if(Gem::Specification.find_by_name('chef').version.version.to_f >= 12)
            if @chef_config[:chef_server_ssl_cert_content]
              client_rb << %Q{trusted_certs_dir       "/etc/chef/trusted_certs"\n}
            end
          end

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

          client_rb <<  %Q{log_location       "#{@config[:log_location]}/chef-client.log"\n}
          client_rb <<  %Q{chef_server_url       "#{@config[:chef_server_url]}"\n} if @config[:chef_server_url]
          client_rb <<  %Q{validation_client_name       "#{@config[:validation_client_name]}"\n} if @config[:validation_client_name]
          client_rb <<  %Q{client_key      "/etc/chef/client.pem"\n}
          client_rb <<  %Q{validation_key      "/etc/chef/validation.pem"\n}

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

          client_rb
        end

      end
    end
  end
end