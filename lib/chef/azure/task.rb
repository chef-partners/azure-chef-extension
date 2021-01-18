#
# Author:: Aliasgar Batterywala (aliasgar.batterywala@msystechnologies.com)
# Copyright:: Copyright (c) 2017 Opscode, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
require 'chef/azure/helpers/shared'

class ChefTask  
  include Chef::Mixin::ShellOut
  include ChefAzure::Shared
  DEFAULT_CHEF_DAEMON_INTERVAL = 30

  def enable(bootstrap_directory, log_location, chef_daemon_interval = DEFAULT_CHEF_DAEMON_INTERVAL)
    # Checking if chef-client service is running or not and if running then stop that service.
    if windows?
      result = shell_out("sc.exe query chef-client")
      if result.exitstatus == 0 and result.stdout.include?("RUNNING")
        stop_service
      end 
    end 
  	log_location = log_location || bootstrap_directory
    exit_code = 0
    message = "success"
    error_message = "Error enabling chef-client scheduled task"
    begin
      puts "#{Time.now} Getting chef-client scheduled task status"
      if is_installed?
        puts "#{Time.now} chef-client scheduled task is already installed."
        puts "#{Time.now} Enabling chef scheduled task with interval #{chef_daemon_interval} minutes."
        update_chef_sch_task(chef_daemon_interval)
      else
        install_service(bootstrap_directory, log_location, chef_daemon_interval)
      end
    rescue => e
      Chef::Log.error "#{error_message} (#{e})"
      message = "#{error_message} - #{e} - Check log file for details", "error"
      exit_code = 1
    end
    [exit_code, message]
  end

  def disable
    puts "#{Time.now} Disabling chef-client scheduled task..."
    exit_code = 0
    message = "success"
    error_message = "Error disabling chef-client scheduled task"
    begin
      result = shell_out("SCHTASKS.EXE /CHANGE /TN \"chef-client\" /DISABLE")
      result.error? ? result.error! : (puts "#{Time.now} Disabled chef-client scheduled task.")
    rescue => e
      Chef::Log.error "#{error_message} (#{e})"
      message = "#{error_message} - #{e} - Check log file for details", "error"
      exit_code = 1
    end
    puts "#{Time.now} Disabled chef-client service" if exit_code == 0
    [exit_code, message]
  end

  private

  def is_installed?
    puts "#{Time.now} Checking chef-client scheduled task install status..."
    result = shell_out("SCHTASKS.EXE /QUERY /TN \"chef-client\"")
    result.error? ? false : true
  end

  def install_service(bootstrap_directory, log_location, chef_daemon_interval)
    puts "#{Time.now} Installing chef-client scheduled task..."
    result = shell_out("SCHTASKS.EXE /CREATE /TN \"chef-client\" /F /SC \"MINUTE\" /MO \"#{chef_daemon_interval}\" /TR \"cmd /c 'C:/opscode/chef/embedded/bin/ruby.exe C:/opscode/chef/bin/chef-client -L C:/chef/chef-client.log -c #{bootstrap_directory}/client.rb'\" /RU \"NT Authority\\System\" /RP /RL \"HIGHEST\"")
    result.error? ? result.error! : (puts "#{Time.now} Installed chef-client scheduled task.")
  end

  def update_chef_sch_task(chef_daemon_interval)
    puts "#{Time.now} Updating chef-client scheduled task..."
    result = shell_out("SCHTASKS.EXE /CHANGE /TN \"chef-client\" /RI #{chef_daemon_interval} /RU \"NT Authority\\System\" /RP /RL \"HIGHEST\" /ENABLE")
    result.error? ? result.error! : (puts "#{Time.now} Updated chef-client scheduled task.")
  end

  def total_minutes(hours, minutes)
    (hours * 60) + minutes
  end


  def stop_service
    stop = shell_out("sc.exe stop chef-client")
    if stop.error?
       puts "Could not Stop chef-client service as chef-client cannot run as service and task simultaneously.. exiting"
       stop.error!           
    else
       puts "#{Time.now} Stopped chef-client service."
    end
  end
end
