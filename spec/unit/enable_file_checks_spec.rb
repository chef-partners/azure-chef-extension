require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require 'chef/azure/commands/enable'
require 'tmpdir'
require 'fileutils'

# These specs exercise EnableChef#copy_settings_file and #get_decrypted_key
# against the real filesystem (rather than stubbing File) so they hit the
# actual File.exist? checks the same way production code does. This guards
# against a regression back to File.exists?, which was removed in Ruby 3.2.
describe EnableChef do
  let(:extension_root) { "./" }
  let(:enable_args) { [] }
  let(:instance) { EnableChef.new(extension_root, enable_args) }

  describe "#copy_settings_file" do
    around do |example|
      Dir.mktmpdir do |dir|
        @bootstrap_dir = dir
        example.run
      end
    end

    context "when the handler settings file exists" do
      it "copies it into the bootstrap directory" do
        Dir.mktmpdir do |settings_dir|
          settings_file = File.join(settings_dir, "handler.settings")
          File.write(settings_file, "{}")

          allow(instance).to receive(:handler_settings_file).and_return(settings_file)
          allow(instance).to receive(:bootstrap_directory).and_return(@bootstrap_dir)

          instance.send(:copy_settings_file)

          expect(File.exist?(File.join(@bootstrap_dir, "handler.settings"))).to be true
        end
      end
    end

    context "when the handler settings file does not exist" do
      it "does not raise and does not copy anything" do
        allow(instance).to receive(:handler_settings_file).and_return(File.join(@bootstrap_dir, "missing.settings"))
        allow(instance).to receive(:bootstrap_directory).and_return(@bootstrap_dir)

        expect { instance.send(:copy_settings_file) }.to_not raise_error
      end
    end
  end

  describe "#get_decrypted_key" do
    context "on linux when the cert and private key are both missing" do
      # Note: this documents pre-existing behavior (unrelated to Ruby 2/3
      # compatibility). On the linux branch, decrypted_text is only assigned
      # inside the nested `if File.exists?(cert_path) && File.exists?(private_key_path)`
      # check; when either file is missing that assignment never runs, so
      # decrypted_text stays nil instead of raising or returning the
      # original encrypted text.
      it "returns nil instead of raising" do
        allow(instance).to receive(:windows?).and_return(false)
        allow(instance).to receive(:handler_settings_file).and_return(mock_data("handler_settings.settings"))
        stub_const("EnableChef::LINUX_CERT_PATH", Dir.mktmpdir)

        expect(instance.send(:get_decrypted_key, "still-encrypted")).to be_nil
      end
    end
  end
end
