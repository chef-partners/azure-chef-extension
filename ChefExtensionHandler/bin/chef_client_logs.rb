#
# Author:: Aliasgar Batterywala (aliasgar.batterywala@clogeny.com)
# Copyright:: Copyright (c) 2016 Opscode, Inc.
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

require 'json'
require 'time'

class ChefClientLogs

  def initialize(client_pid, start_time, log_path, status_file)
    @chef_client_pid = client_pid
    @chef_client_run_start_time = start_time
    @chef_client_log_path = log_path
    @azure_status_file = status_file
  end

  def chef_client_run_exit_status
    if File.read("/tmp/exit_status").to_i == 0
      'success'    ## successful chef_client_run ##
    else
      'error'      ## unsuccessful chef_client_run ##
    end
  end

  def chef_client_process_alive?
    Process.kill(0, @chef_client_pid) rescue false
  end

  def chef_client_run_complete?
    ## wait for maximum 30 minutes for chef_client_run to complete ##
    chef_client_run_wait_time = ((Time.now - @chef_client_run_start_time) / 60).round
    if chef_client_process_alive? && chef_client_run_wait_time <= 30
      sleep 30
      chef_client_run_complete?
    end
    !chef_client_process_alive?
  end

  def write_chef_client_logs(sub_status)
    retries = 3
    begin
      ## read azure_status_file to preserve its existing contents ##
      status_file_contents = JSON.parse(File.read(@azure_status_file))

      ## update the timestamp ##
      status_file_contents[0]["timestampUTC"] = Time.now.utc.iso8601

      ## append chef_client_run logs into the substatus field of azure_status_file ##
      status_file_contents[0]["status"]["substatus"] = [{
        "name" => "Chef Client run logs",
        "status" => "#{sub_status[:status]}",
        "code" => 0,
        "formattedMessage" => {
          "lang" => "en-US",
          "message" => "#{sub_status[:message]}"
        }
      }]

      # Write the new status
      File.open(@azure_status_file, 'w') do |file|
        file.write(status_file_contents.to_json)
      end
    rescue Errno::EACCES => e
      puts "{#{e.message}} - Retrying in 2 secs..."
      if not (retries -= 1).zero?
        sleep 2
        retry
      end
    end
  end

  def chef_client_logs
    ## 'transitioning' status depicts that the chef_client_run is still going on and
    ## it exceeded maximum wait time limit of 30 minutes, whereas 'success' or 'error'
    ## status message depends on exit status of chef_client_run
    sub_status = { :status => chef_client_run_complete? ? chef_client_run_exit_status : 'transitioning',
      :message => File.read(@chef_client_log_path) }

    write_chef_client_logs(sub_status)
  end
end

begin
  bootstrap_directory = ARGV[4]
  if ARGV.length == 5 && !File.exists?("#{bootstrap_directory}/node-registered")
    logs = ChefClientLogs.new(ARGV[0].to_i, Time.parse(ARGV[1]), ARGV[2], ARGV[3])
    logs.chef_client_logs
    File.delete("/tmp/exit_status") if File.exists?("/tmp/exit_status")
  else
    raise "#{Time.now} Invalid invocation of the chef_client logs script."
  end
rescue => error
  puts error.message
  exit
end
