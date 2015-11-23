require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require 'chef/azure/commands/enable'
require 'tmpdir'
require 'ostruct'

# These testcases verify that validation.pem file generated on windows and linux
# using encrypted protected settings has correct contents. Method that generates
# this file is 'get_validation_key'

describe "EnableChef get_validation_key generates correct validation.pem file" do
  let (:extension_root) { "./" }
  let (:enable_args) { [] }
  let (:instance) { EnableChef.new(extension_root, enable_args) }

  context "for windows" do
    before do
      @encrypted_settings = mock_data('encrypted_settings.txt')
      validation_key = mock_data('validation_key.txt')
      @key = OpenSSL::PKey::RSA.new(validation_key.squeeze("\n")).to_pem
      allow(instance).to receive(:windows?).and_return(true)
      allow(instance).to receive(:handler_settings_file).and_return(mock_data("handler_settings.settings"))
    end

    it "returns correct validation key if there is no escape character in the decrypted json" do
      decrypted_validation_key = mock_data('correct_decrypted_json.txt')
      allow(instance).to receive(:shell_out).and_return(OpenStruct.new(:exitstatus => 0, :stdout => decrypted_validation_key))
      validation_key_cmd = instance.send(:get_validation_key,@encrypted_settings)
      expect(validation_key_cmd).to eq(@key)
    end

    it "returns correct validation key if there are escape characters in the decrypted json" do
      decrypted_validation_key = mock_data('incorrect_decrypted_json.txt')
      allow(instance).to receive(:shell_out).and_return(OpenStruct.new(:exitstatus => 0, :stdout => decrypted_validation_key))
      validation_key_cmd = instance.send(:get_validation_key,@encrypted_settings)
      expect(validation_key_cmd).to eq(@key)
    end
  end


  context "for linux" do
    before do
      @encrypted_settings = mock_data('linux_encrypted_settings.settings')
      validation_key = mock_data('linux_validation_key.txt')
      @key = OpenSSL::PKey::RSA.new(validation_key.squeeze("\n")).to_pem
      allow(instance).to receive(:windows?).and_return(false)
      allow(instance).to receive(:handler_settings_file).and_return(mock_data("handler_settings.settings"))
    end

    it "returns correct validation key" do
      EnableChef::LINUX_CERT_PATH = File.expand_path(File.dirname("spec/assets/*"))
      validation_key_cmd = instance.send(:get_validation_key,@encrypted_settings)
      expect(validation_key_cmd).to eq(@key)
    end
  end
end