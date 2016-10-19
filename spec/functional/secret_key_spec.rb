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

  let(:correct_decrypted_settings) { mock_data('correct_decrypted_json.txt') }
  let(:incorrect_decrypted_settings) { mock_data('incorrect_decrypted_json.txt') }

  describe "secret_key" do
    it "returns correct secret key if there is no escape character in the decrypted json" do
      allow(OpenSSL::PKey::RSA).to receive_message_chain(:new, :to_pem).and_return('secret_key')
      response = instance.send(:secret_key, correct_decrypted_settings)
      expect(response).to eq("secret_key")
    end

    it "returns correct secret key if there are escape characters in the decrypted json" do
      allow(OpenSSL::PKey::RSA).to receive_message_chain(:new, :to_pem).and_return('secret_key')
      response = instance.send(:secret_key,incorrect_decrypted_settings)
      expect(response).to eq("secret_key")
    end

    context "when secret is not passed by the user" do
      it "returns nil" do
        response = instance.send(:secret_key, "{\"validation_key\" : \"my_key\"}")
        expect(response).to eq(nil)
      end
    end
  end
end
