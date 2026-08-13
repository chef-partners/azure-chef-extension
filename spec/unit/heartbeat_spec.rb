require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require 'chef/azure/heartbeat'
require 'tmpdir'
require 'json'

# These specs deliberately exercise AzureHeartBeat.update against a real file
# on disk (rather than stubbing File) so that they exercise the actual
# File.exists?/File.exist? call the same way production code does. File.exists?
# was removed in Ruby 3.2, so these specs will fail with a NoMethodError on
# Ruby >= 3.2 until the production code is updated to use File.exist?.
describe AzureHeartBeat do
  around do |example|
    Dir.mktmpdir do |dir|
      @heartbeat_path = File.join(dir, "heartbeat.json")
      example.run
    end
  end

  context "when the heartbeat file does not yet exist" do
    it "creates the file with the requested status" do
      AzureHeartBeat.update(@heartbeat_path, AzureHeartBeat::READY, 0, "all good")

      contents = JSON.parse(File.read(@heartbeat_path))
      expect(contents[0]["heartbeat"]["status"]).to eq(AzureHeartBeat::READY)
      expect(contents[0]["heartbeat"]["code"]).to eq(0)
      expect(contents[0]["heartbeat"]["Message"]).to eq("all good")
    end
  end

  context "when the heartbeat file already exists" do
    before do
      File.open(@heartbeat_path, 'w') do |file|
        file.write([{ "version" => "1.0", "heartbeat" => { "status" => AzureHeartBeat::NOTREADY, "code" => 1, "Message" => "starting" } }].to_json)
      end
    end

    it "preserves the version and updates the status" do
      AzureHeartBeat.update(@heartbeat_path, AzureHeartBeat::READY, 0, "finished")

      contents = JSON.parse(File.read(@heartbeat_path))
      expect(contents[0]["version"]).to eq("1.0")
      expect(contents[0]["heartbeat"]["status"]).to eq(AzureHeartBeat::READY)
      expect(contents[0]["heartbeat"]["Message"]).to eq("finished")
    end
  end
end
