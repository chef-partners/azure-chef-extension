require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require 'chef'
require 'chef/azure/chefhandlers/report_handler'
require 'tmpdir'

# These specs exercise ReportHandler#report against a real temp directory
# (rather than stubbing File) so they hit the actual File.exists? call the
# same way production code does. File.exists? was removed in Ruby 3.2, so
# these specs will fail with a NoMethodError on Ruby >= 3.2 until the
# production code is updated to use File.exist?.
describe AzureExtension::ReportHandler do
  let(:extension_root) { "./" }
  let(:instance) { AzureExtension::ReportHandler.new(extension_root) }
  let(:bootstrap_dir) { Dir.mktmpdir }

  after do
    FileUtils.remove_entry(bootstrap_dir)
  end

  before do
    allow(instance).to receive(:bootstrap_directory).and_return(bootstrap_dir)
    allow(instance).to receive(:load_azure_env)
    allow(instance).to receive(:report_heart_beat_to_azure)
  end

  context "when the chef-client run succeeded" do
    before { allow(instance.run_status).to receive(:success?).and_return(true) }

    it "creates the node-registered marker file when it does not exist yet" do
      marker = File.join(bootstrap_dir, "node-registered")
      expect(File.exist?(marker)).to be false

      instance.report

      expect(File.exist?(marker)).to be true
    end

    it "does not error when the node-registered marker file already exists" do
      marker = File.join(bootstrap_dir, "node-registered")
      File.write(marker, "Node registered.")

      expect { instance.report }.to_not raise_error
    end
  end

  context "when the chef-client run failed" do
    it "does not touch the node-registered marker file" do
      allow(instance.run_status).to receive(:success?).and_return(false)
      marker = File.join(bootstrap_dir, "node-registered")

      instance.report

      expect(File.exist?(marker)).to be false
    end
  end
end
