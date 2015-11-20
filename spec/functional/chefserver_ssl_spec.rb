
require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require 'chef/azure/commands/enable'
require 'tmpdir'
require 'ostruct'

describe "get_chef_server_ssl_cert" do

  let(:extension_root) { "./" }
  let(:enable_args) { [] }
  let(:instance) { EnableChef.new(extension_root, enable_args) }
  
  context "for Linux" do
    before do
      @linux_cert_prv = mock_data('ssl_certs/linux_cert_prv.txt')
      @encrypted_protected_settings = mock_data('ssl_certs/encrypted_protected_settings.txt')
      chefserver_ssl_cert = mock_data('ssl_certs/chefserver_ssl_cert.txt')
      @actual_ssl_cert = OpenSSL::X509::Certificate.new(chefserver_ssl_cert.squeeze("\n")).to_pem
      allow(instance).to receive(:windows?).and_return(false)
      allow(instance).to receive(:handler_settings_file).and_return(mock_data("ssl_certs/runtime_settings.settings"))
      allow(File).to receive(:exists?).and_return(true)
    end

    it "returns correct chef_server_ssl_cert" do
      allow(File).to receive(:read).and_return(@linux_cert_prv)
      returned_ssl_cert = instance.send(:get_chef_server_ssl_cert,@encrypted_protected_settings)
      expect(returned_ssl_cert).to eq(@actual_ssl_cert)
    end
  end

  context "for Windows" do
  	before do
      @encrypted_protected_settings = mock_data('ssl_certs/encrypted_protected_settings.txt')
      chefserver_ssl_cert = mock_data('ssl_certs/chefserver_ssl_cert.txt')
      @actual_ssl_cert = OpenSSL::X509::Certificate.new(chefserver_ssl_cert.squeeze("\n")).to_pem
      allow(instance).to receive(:windows?).and_return(true)
      allow(instance).to receive(:handler_settings_file).and_return(mock_data("ssl_certs/runtime_settings.settings"))
    end

    it "returns correct chef_server_ssl_cert if there is no escape character in the decrypted json" do
      decrypted_chef_server_ssl_cert = mock_data('ssl_certs/correct_decrypted_ssl_cert_json.txt')
      allow(instance).to receive(:shell_out).and_return(OpenStruct.new(:exitstatus => 0, :stdout => decrypted_chef_server_ssl_cert))
      returned_ssl_cert = instance.send(:get_chef_server_ssl_cert,@encrypted_protected_settings)
      expect(returned_ssl_cert).to eq(@actual_ssl_cert)
    end

    it "returns correct chef_server_ssl_cert if there are escape characters in the decrypted json" do
      decrypted_chef_server_ssl_cert = mock_data('ssl_certs/incorrect_decrypted_ssl_cert_json.txt')
      allow(instance).to receive(:shell_out).and_return(OpenStruct.new(:exitstatus => 0, :stdout => decrypted_chef_server_ssl_cert))
      returned_ssl_cert = instance.send(:get_chef_server_ssl_cert,@encrypted_protected_settings)
      expect(returned_ssl_cert).to eq(@actual_ssl_cert)
    end
  end
end
