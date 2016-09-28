require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require 'chef/azure/commands/enable'
require 'tmpdir'
require 'ostruct'

# These testcases verify that secret_key file generated on windows and linux
# using encrypted protected settings has correct contents. Method that generates
# this file is 'secret_key'

describe "EnableChef secret_key generates correct encrrypted_data_bag_secret file" do
  let (:extension_root) { "./" }
  let (:enable_args) { [] }
  let (:instance) { EnableChef.new(extension_root, enable_args) }

  context "for windows" do
    before do
      @decrypted_settings = mock_data('correct_decrypted_json.txt')
      allow(instance).to receive(:windows?).and_return(true)
      allow(instance).to receive(:handler_settings_file).and_return(mock_data("handler_settings.settings"))
    end

    it "returns correct secret key if there is no escape character in the decrypted json" do
      allow(instance).to receive(:shell_out).and_return(OpenStruct.new(:exitstatus => 0, :stdout => @decrypted_settings))
      secret_key_cmd = instance.send(:secret_key,@decrypted_settings)
      expect(secret_key_cmd).to eq("secret_key")
    end

    it "returns correct secret key if there are escape characters in the decrypted json" do
      decrypted_validation_key = mock_data('incorrect_decrypted_json.txt')
      allow(instance).to receive(:shell_out).and_return(OpenStruct.new(:exitstatus => 0, :stdout => decrypted_validation_key))
      secret_key_cmd = instance.send(:secret_key,@decrypted_settings)
      expect(secret_key_cmd).to eq("secret_key")
    end
  end


  context "for linux" do
    before do
      @decrypted_settings = mock_data('correct_decrypted_json.txt')
      allow(instance).to receive(:windows?).and_return(false)
      allow(instance).to receive(:handler_settings_file).and_return(mock_data("handler_settings.settings"))
    end

    it "returns correct validation key" do
      EnableChef::LINUX_CERT_PATH = File.expand_path(File.dirname("spec/assets/*"))
      secret_key_cmd = instance.send(:secret_key,@decrypted_settings)
      expect(secret_key_cmd).to eq("secret_key")
    end
  end
end