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

  before(:all) do
    # All file artifacts from this test will be written into this directory
    #@temp_directory = Dir.mktmpdir('enable_test')
    @thumbprint = "C84D49E9F7BEC0C93B1EE11E03B0AB455D7F4934"
  end

  after(:all) do
    # Clear the temp directory upon exit
  #  if Dir.exists?(@temp_directory)
   #   FileUtils::remove_dir(@temp_directory)
   # end
  end

  context "for windows" do
    it "returns validation key" do
      protected_settings = mock_data('protected_settings.txt')
      validation_key = mock_data('decrypted_validation_key.txt')
      key = OpenSSL::PKey::RSA.new(validation_key.squeeze("\n")).to_pem
      assets_path = File.expand_path(File.dirname("spec/assets/*"))
      allow(instance).to receive(:windows?).and_return(true)
      allow(instance).to receive(:handler_settings_file).and_return(mock_data("handler_settings.settings"))
      allow(File).to receive(:expand_path).and_return(assets_path)
      validation_key_cmd = instance.send(:get_validation_key,protected_settings)
      expect(validation_key_cmd).to eq(key)
    end
  end

  def mock_data(file_name)
    file =  File.expand_path(File.dirname("spec/assets/*"))+"/#{file_name}"
    File.read(file)
  end
end