#
# Author:: Mukta Aphale (mukta.aphale@clogeny.com)
# Copyright:: Copyright (c) 2014 Opscode, Inc.
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

require 'time'

class AzureExtensionStatus
  # status file path
  # status message
  def self.log(path, message, status_type="success")
    retries = 3
    begin
      puts "Logging status message: #{message}"
      status_message = message[-512, 512] || message
      status = [{
        "version" => "1.0",
        "timestampUTC" => Time.now.utc.iso8601,
        "status" => {
            "name" => "Chef Extension Handler",
            "operation" => "chef-client-run",
            "status" => "#{status_type}",
            "code" => 0,
            "formattedMessage" => {
                "lang" => "en-US",
                "message" => "#{status_message}"
            },
        }
      }]
      # TODO: if status_type is null, check the message for any errors
      # TODO: consider using substatus and message in the status json

      # Write the new status
      File.open(path, 'w') do |file|
        file.write(status.to_json)
      end
    rescue Errno::EACCES => e
      puts "{#{e.message}} - Retrying in 2 secs..."
      if not (retries -= 1).zero?
        sleep 2
        retry
      end
    end
  end
end