#
# Author:: Bryan McLellan <btm@loftninjas.org>
# Copyright:: Copyright (c) 2014 Chef Software, Inc.
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

# Sourced from Chef::Util::PathHelper.
# Should be removed when Chef 11 catches up or we stop supporting Chef 11

module Knife
  module Windows
    class PathHelper
      def self.join(*args)
        args.flatten.inject do |joined_path, component|
          # Joined path ends with /
          joined_path = joined_path.sub(/[#{Regexp.escape(File::SEPARATOR)}#{Regexp.escape(path_separator)}]+$/, '')
          component = component.sub(/^[#{Regexp.escape(File::SEPARATOR)}#{Regexp.escape(path_separator)}]+/, '')
          joined_path += "#{path_separator}#{component}"
        end
      end

      def self.path_separator
        if Chef::Platform.windows?
          File::ALT_SEPARATOR || BACKSLASH
        else
          File::SEPARATOR
        end
      end

      def self.cleanpath(path)
        path = Pathname.new(path).cleanpath.to_s
        # ensure all forward slashes are backslashes
        if Chef::Platform.windows?
          path = path.gsub(File::SEPARATOR, path_separator)
        end
        path
      end

      # Paths which may contain glob-reserved characters need
      # to be escaped before globbing can be done.
      # http://stackoverflow.com/questions/14127343
      def self.escape_glob(*parts)
        path = cleanpath(join(*parts))
        path.gsub(/[\\\{\}\[\]\*\?]/) { |x| "\\"+x }
      end
    end
  end
end
