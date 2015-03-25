require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require 'chef/azure/helpers/shared'

describe ChefAzure::Shared do
  let(:dummy_class) { Class.new { extend ChefAzure::Shared } }

  context "bootstrap directory" do
    it "for windows" do
      allow(dummy_class).to receive(:windows?).and_return(true)
      expect(dummy_class.bootstrap_directory).to eq("#{ENV['SYSTEMDRIVE']}/chef")
    end

    it "for linux" do
      allow(dummy_class).to receive(:windows?).and_return(false)
      expect(dummy_class.bootstrap_directory).to eq("/etc/chef")
    end
  end
end