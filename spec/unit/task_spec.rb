#
# Author:: Nimisha Sharad (nimisha.sharad@msystechnologies.com)
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

require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require 'chef'
require 'chef/azure/helpers/shared'
require 'chef/azure/task'
require 'ostruct'

describe ChefTask do
  let (:instance) { ChefTask.new }

  it { expect {instance}.to_not raise_error }

  describe "#enable" do
    before do
      allow(instance).to receive(:log_location)
      allow(instance).to receive(:bootstrap_directory)
    end

    it "installs the chef scheduled task if it's not already installed" do
      allow(instance).to receive(:is_installed?).and_return(false)
      expect(instance).to receive(:install_service)
      response = instance.send(:enable, '/bootstrap_directory', '/log_location', 17)
      expect(response).to be == [0, 'success']
    end

    it "installs the existing scheduled task if it's already installed" do
      allow(instance).to receive(:is_installed?).and_return(true)
      expect(instance).to receive(:update_chef_sch_task)
      response = instance.send(:enable, '/bootstrap_directory', '/log_location', 17)
      expect(response).to be == [0, 'success']
    end

    it "logs error if something goes wrong" do
      allow(instance).to receive(:is_installed?).and_return(false)
      allow(instance).to receive(:install_service).and_raise("Error")
      response = instance.send(:enable, '/bootstrap_directory', '/log_location', 17)
      expect(response).to be == [1, ["Error enabling chef-client scheduled task - Error - Check log file for details", "error"]]
    end
  end

  describe "#disable" do
    it "disables the chef scheduled task" do
      expect(instance).to receive(:shell_out).with("SCHTASKS.EXE /CHANGE /TN \"chef-client\" /DISABLE").and_return(double("result", :error? => false))
      response = instance.send(:disable)
      expect(response).to be == [0, 'success']
    end

    it "raises error if something goes wrong" do
      expect(instance).to receive(:shell_out).and_raise("error")
      response = instance.send(:disable)
      expect(response).to be == [1, ["Error disabling chef-client scheduled task - error - Check log file for details", "error"]]
    end
  end

  describe "#is_installed?" do
    it "checks if the scheduled task is installed or not" do
      expect(instance).to receive(:shell_out).with("SCHTASKS.EXE /QUERY /TN \"chef-client\"").and_return(double("result", :error? => false))
      instance.send(:is_installed?)
    end
  end

  describe "#install_service" do
    it "installs the chef scheduled task with the given interval" do
      chef_daemon_interval = 17
      log_location = "log"
      bootstrap_directory = "bootstrap_dir"
      expect(instance).to receive(:shell_out).with("SCHTASKS.EXE /CREATE /TN \"chef-client\" /F /SC \"MINUTE\" /MO \"#{chef_daemon_interval}\" /TR \"cmd /c 'C:/opscode/chef/embedded/bin/ruby.exe C:/opscode/chef/bin/chef-client -L C:/chef/chef-client.log -c #{bootstrap_directory}/client.rb'\" /RU \"NT Authority\\System\" /RP /RL \"HIGHEST\"").and_return(double("result", :error? => false))
      instance.send(:install_service, bootstrap_directory, log_location, chef_daemon_interval)
    end
  end

  describe "#update_chef_sch_task" do
    it "updates and enables the schedules task with the given interval" do
      chef_daemon_interval = 17
      expect(instance).to receive(:shell_out).with("SCHTASKS.EXE /CHANGE /TN \"chef-client\" /RI #{chef_daemon_interval} /RU \"NT Authority\\System\" /RP /RL \"HIGHEST\" /ENABLE").and_return(double("result", :error? => false))
      instance.send(:update_chef_sch_task, chef_daemon_interval)
    end
  end
end