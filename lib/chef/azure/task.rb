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

class ChefTask
  include Chef::Mixin::ShellOut
  DEFAULT_CHEF_SERVICE_INTERVAL = 30

  def enable(bootstrap_directory, log_location, chef_service_interval = DEFAULT_CHEF_SERVICE_INTERVAL)
  	log_location = log_location || bootstrap_directory
    exit_code = 0
    message = "success"
    error_message = "Error enabling chef-client scheduled task"
    begin
      puts "#{Time.now} Getting chef-client scheduled task status"
      if is_installed?
        puts "#{Time.now} chef-client scheduled task is already installed."
        if chef_sch_task_interval_changed?(chef_service_interval)
          puts "#{Time.now} yes..chef-client service interval has been changed by the user..updating the interval value to #{chef_service_interval} minutes."
          update_chef_sch_task(chef_service_interval)
        end
      else
        install_service(bootstrap_directory, log_location, chef_service_interval)
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
    result = shell_out("SCHTASKS.EXE /CHANGE /TN \"chef-client\" /DISABLE")
    result.error? ? result.error! : (puts "#{Time.now} Disabled chef-client scheduled task.")
  end

  private

  def is_installed?
    puts "#{Time.now} Checking chef-client scheduled task install status..."
    result = shell_out("SCHTASKS.EXE /QUERY /TN \"chef-client\"")
    result.error? ? false : true
  end

  def install_service(bootstrap_directory, log_location, chef_service_interval)
    puts "#{Time.now} Installing chef-client scheduled task..."
    result = shell_out("SCHTASKS.EXE /CREATE /TN \"chef-client\" /F /SC \"MINUTE\" /MO \"#{chef_service_interval}\" /TR \"cmd /c 'ruby chef-client -L #{log_location}/chef-client.log -c #{bootstrap_directory}/client.rb'\" /RU \"NT Authority\\System\" /RP /RL \"HIGHEST\"")
    result.error? ? result.error! : (puts "#{Time.now} Installed chef-client scheduled task.")
  end

  def update_chef_sch_task(chef_service_interval)
    puts "#{Time.now} Updating chef-client scheduled task..."
    result = shell_out("SCHTASKS.EXE /CHANGE /TN \"chef-client\" /RI #{chef_service_interval} /RU \"NT Authority\\System\" /RP /RL \"HIGHEST\"")
    result.error? ? result.error! : (puts "#{Time.now} Updated chef-client scheduled task.")
  end

  def chef_sch_task_interval_changed?(new_chef_service_interval)
    puts "#{Time.now} Checking if chef-client scheduled task interval has been changed by the user or not..."
    old_chef_service_interval = fetch_old_chef_service_interval
    old_chef_service_interval != new_chef_service_interval
  end

  def fetch_old_chef_service_interval
    hours_str, minutes_str = shell_out("(SCHTASKS.EXE /QUERY /TN \"chef-client\" /FO LIST /V | Select-String \"Repeat: Every\") -replace ' ','' | %{ $_.split(':')[-1] } | %{ $_.split(',') }")
    hours = shell_out("(#{hours_str}) -replace '(\d+)\D+', '$1'")
    minutes = shell_out("(#{minutes_str}) -replace '(\d+)\D+', '$1'")
    total_minutes(hours, minutes)
  end

  def total_minutes(hours, minutes)
    (hours * 60) + minutes
  end
end
