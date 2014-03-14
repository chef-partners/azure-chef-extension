#
# Author:: Kaustubh Deorukhkar (<kaustubh@clogeny.com>)
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

require 'json'

class AzureHeartBeat
  READY = "ready"
  NOTREADY = "notready"

  # path = path to heartbeat file
  # status = READY/NOTREADY
  # code = 0/1 - 1 indicates some error state
  # message = A human readable\actionable error message for the user
  def self.update(path, status, code, message)
    retries = 3
    begin
      # Load existing file
      heartBeat = JSON.parse(File.read(path)) if File.exists?(path)
      heartBeat = [{
          "version" => heartBeat ? heartBeat[0]["version"] : "1.0",
          "heartbeat" => {
            "status" => status,
            "code" => code,
            "Message" => message
          }
        }]

      # Write the new status
      File.open(path, 'w') do |file|
        file.write(heartBeat.to_json)
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