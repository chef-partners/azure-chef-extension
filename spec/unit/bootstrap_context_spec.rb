require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require 'chef/azure/core/bootstrap_context'
require 'chef/azure/core/windows_bootstrap_context'

describe Chef::Knife::Core::BootstrapContext do
  let(:chef_config) { { knife: {} } }
  let(:run_list) { [] }

  def ctx(config_overrides = {})
    config = {
      user_client_rb: '',
      log_location: '/var/log/azure',
      chef_extension_root: '/var/lib/waagent/chef',
      first_boot_attributes: {}
    }.merge(config_overrides)
    described_class.new(config, run_list, chef_config)
  end

  context "standard (run_list) mode" do
    it "emits chef_server_url and validation_key path in client.rb" do
      c = ctx(chef_server_url: 'https://chef.example.com', validation_client_name: 'org-validator')
      content = c.config_content
      expect(content).to include('chef_server_url')
      expect(content).to include('validation_key')
      expect(content).to include('validation_client_name')
    end

    it "includes target_runlist in first_boot when run_list is present" do
      c = described_class.new(
        { user_client_rb: '', log_location: '/tmp', chef_extension_root: '/', first_boot_attributes: {} },
        ['recipe[foo]'],
        chef_config
      )
      expect(c.first_boot).to include(:target_runlist)
    end
  end

  context "policyfile mode (policy_name + policy_group in config)" do
    let(:policy_config) do
      {
        policy_name: 'my-policy',
        policy_group: 'production',
        chef_server_url: 'https://chef.example.com',
        user_client_rb: '',
        log_location: '/var/log/azure',
        chef_extension_root: '/var/lib/waagent/chef',
        first_boot_attributes: {}
      }
    end

    it "still emits validation_key and chef_server_url in client.rb" do
      c = described_class.new(policy_config, run_list, chef_config)
      expect(c.config_content).to include('validation_key')
      expect(c.config_content).to include('chef_server_url')
    end

    it "adds policy_name and policy_group to first_boot in place of run_list" do
      c = described_class.new(policy_config, ['recipe[foo]'], chef_config)
      expect(c.first_boot).to include(:policy_name => 'my-policy', :policy_group => 'production')
      expect(c.first_boot).not_to include(:target_runlist)
    end
  end
end

describe Chef::Knife::Core::WindowsBootstrapContext do
  let(:chef_config) { { knife: {} } }
  let(:run_list) { [] }

  def ctx(config_overrides = {})
    config = {
      user_client_rb: '',
      log_location: 'c:/chef/log',
      chef_extension_root: 'c:/chef',
      first_boot_attributes: {}
    }.merge(config_overrides)
    described_class.new(config, run_list, chef_config)
  end

  context "standard mode" do
    it "emits validation_key path in client.rb" do
      c = ctx(chef_server_url: 'https://chef.example.com', validation_client_name: 'org-validator')
      expect(c.config_content).to include('validation_key')
    end

    it "includes target_runlist in first_boot when run_list present" do
      c = described_class.new(
        { user_client_rb: '', log_location: 'c:/chef/log', chef_extension_root: 'c:/chef', first_boot_attributes: {} },
        ['recipe[foo]'],
        chef_config
      )
      # first_boot is escape_and_echo'd; check raw json contains the key
      expect(c.first_boot).to include('target_runlist')
    end
  end

  context "policyfile mode" do
    let(:policy_config) do
      {
        policy_name: 'my-policy',
        policy_group: 'production',
        chef_server_url: 'https://chef.example.com',
        user_client_rb: '',
        log_location: 'c:/chef/log',
        chef_extension_root: 'c:/chef',
        first_boot_attributes: {}
      }
    end

    it "still emits validation_key and chef_server_url in client.rb" do
      c = described_class.new(policy_config, run_list, chef_config)
      expect(c.config_content).to include('validation_key')
      expect(c.config_content).to include('chef_server_url')
    end

    it "adds policy_name and policy_group to first_boot in place of run_list" do
      c = described_class.new(policy_config, ['recipe[foo]'], chef_config)
      expect(c.first_boot).to include('policy_name')
      expect(c.first_boot).to include('policy_group')
      expect(c.first_boot).not_to include('target_runlist')
    end
  end
end
