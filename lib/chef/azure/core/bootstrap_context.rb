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
        def start_chef
          # If the user doesn't have a client path configure, let bash use the PATH for what it was designed for
          client_path = @chef_config[:chef_client_path] || 'chef-client'
          s = "#{client_path} "
          s << ' -l debug' if @config[:verbosity] and @config[:verbosity] >= 2
          s << " -E #{bootstrap_environment}"
          s
        end
      end
    end
  end
end