require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require 'chef/azure/commands/disable'

describe DisableChef do
  let (:extension_root) { "./" }
  let (:enable_args) { [] }
  let (:instance) { DisableChef.new(extension_root, enable_args) }

  it { expect {instance}.to_not raise_error }

  context "run" do
    it "disables chef" do
      expect(instance).to receive(:load_env)
      expect(instance).to receive(:report_heart_beat_to_azure).twice
      expect(instance).to receive(:disable_chef)
      instance.run
    end
  end

  context "load_env" do
    it "loads azure specific environment configurations from config file." do
      expect(instance).to receive(:read_config)
      instance.send(:load_env)
    end
  end

  describe "#disable_chef" do
    before do
      allow(instance).to receive(:windows?).and_return(true)
    end

    context "when daemon is not passed" do
      context "when disable is successful" do
        it "disables chef service and returns the status to azure with success." do
          allow(instance).to receive(:handler_settings_file)
          allow(instance).to receive(:value_from_json_file)
          expect(instance).to receive(:report_status_to_azure).with("chef-service disabled", "success")
          allow(ChefService).to receive_message_chain(:new, :disable).and_return(0)
          instance.send(:disable_chef)
        end
      end

      context "whean disable is unsuccessful" do
        it "disables chef service and returns the status to azure with error." do
          allow(instance).to receive(:handler_settings_file)
          allow(instance).to receive(:value_from_json_file)
          expect(instance).to receive(:report_status_to_azure).with("chef-service disable failed - ", "error")
          allow(ChefService).to receive_message_chain(:new, :disable).and_return(1)
          instance.send(:disable_chef)
        end
      end
    end

    context "when daemon=service" do
      context "when disable is successful" do
        it "disables chef service and returns the status to azure with success." do
          allow(instance).to receive(:handler_settings_file)
          allow(instance).to receive(:value_from_json_file).and_return("service")
          expect(instance).to receive(:report_status_to_azure).with("chef-service disabled", "success")
          allow(ChefService).to receive_message_chain(:new, :disable).and_return(0)
          instance.send(:disable_chef)
        end
      end

      context "whean disable is unsuccessful" do
        it "disables chef service and returns the status to azure with error." do
          allow(instance).to receive(:handler_settings_file)
          allow(instance).to receive(:value_from_json_file).and_return("service")
          expect(instance).to receive(:report_status_to_azure).with("chef-service disable failed - ", "error")
          allow(ChefService).to receive_message_chain(:new, :disable).and_return(1)
          instance.send(:disable_chef)
        end
      end
    end

    context "when daemon=task" do
      context "when disable is successful" do
        it "disables chef service and returns the status to azure with success." do
          allow(instance).to receive(:handler_settings_file)
          allow(instance).to receive(:value_from_json_file).and_return("task")
          expect(instance).to receive(:report_status_to_azure).with("chef-sch-task disabled", "success")
          allow(ChefTask).to receive_message_chain(:new, :disable).and_return(0)
          instance.send(:disable_chef)
        end
      end

      context "whean disable is unsuccessful" do
        it "disables chef service and returns the status to azure with error." do
          allow(instance).to receive(:handler_settings_file)
          allow(instance).to receive(:value_from_json_file).and_return("task")
          expect(instance).to receive(:report_status_to_azure).with("chef-sch-task disable failed - ", "error")
          allow(ChefTask).to receive_message_chain(:new, :disable).and_return(1)
          instance.send(:disable_chef)
        end
      end
    end
  end

  describe "#update_chef_status" do
    context "when operation is successful" do
      it "displays the success message according to the option passed" do
        instance.instance_variable_set("@exit_code", 0)
        option_name = "service"
        expect(instance).to receive(:report_status_to_azure).with("chef-#{option_name} disabled", "success")
        instance.send(:update_chef_status, option_name)
      end
    end

    context "when operation is unsuccessful" do
      it "displays the failure message according to the option passed" do
        instance.instance_variable_set("@exit_code", 1)
        instance.instance_variable_set("@error_message", "error")
        error_message = "error"
        option_name = "task"
        expect(instance).to receive(:report_status_to_azure).with("chef-#{option_name} disable failed - #{error_message}", "error")
        instance.send(:update_chef_status, option_name)
      end
    end
  end
end
