
require 'chef/application/windows_service.rb'

class Chef
  class Application
    class WindowsService

      # XXX - Additional config options for 
      # - HandlerEnvironment.json to read config folder location, heartbeat file location, status folder location

      # Override for AZURE -> 
      # XXX - risk is updates to windows_service.rb in chef?? Solution can to force a new chef-client in env:path which in turn runs a original chef-client and updates necessary status.
      # - Run the chef-client with settings from handlerSettings
      # - Writes azure extension status file during each chef-client run
      # - Also updates the heartbeat file
      private

      # Initializes Chef::Client instance and runs it
      def run_chef_client
        # The chef client will be started in a new process. We have used shell_out to start the chef-client.
        # The log_location and config_file of the parent process is passed to the new chef-client process.
        # We need to add the --no-fork, as by default it is set to fork=true.
        begin
          # XXX - We can write heart beat file here.
          Chef::Log.info "XXX--AZURE--Writing heartbeat status??"
          
          Chef::Log.info "Starting chef-client in a new process"
          # Pass config params to the new process
          config_params = " --no-fork"
          config_params += " -c #{Chef::Config[:config_file]}" unless  Chef::Config[:config_file].nil?
          config_params += " -L #{Chef::Config[:log_location]}" unless Chef::Config[:log_location] == STDOUT
          # Starts a new process and waits till the process exits
          result = shell_out("chef-client #{config_params}")

          # XXX Write the status for azure extension using the result.
          Chef::Log.info "XXX--AZURE--Writing chef-client run to azure status file.."

          Chef::Log.debug "#{result.stdout}"
          Chef::Log.debug "#{result.stderr}"
        rescue Mixlib::ShellOut::ShellCommandFailed => e
          Chef::Log.warn "Not able to start chef-client in new process (#{e})"
        rescue => e
          Chef::Log.error e
        ensure
          # Once process exits, we log the current process' pid
          Chef::Log.info "Child process exited (pid: #{Process.pid})"
        end
      end
    end
  end
end

# To run this file as a service, it must be called as a script from within
# the Windows Service framework.  In that case, kick off the main loop!
if __FILE__ == $0
    puts "Starting the chef-service for Azure extension..."
    Chef::Application::WindowsService.mainloop
end