require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require 'chef/azure/commands/enable'
require 'tmpdir'
require 'ostruct'

# These testcases verify enable command executes properly

describe "EnableChef" do
  let (:extension_root) { "./" }
  let (:enable_args) { [] }
  let (:instance) { EnableChef.new(extension_root, enable_args) }

  it "enables chef" do
    allow(instance).to receive(:load_env)
    allow(instance).to receive(:report_heart_beat_to_azure)
    allow(File).to receive(:exists?).and_return(false)
    allow(instance).to receive(:handler_settings_file).and_return(mock_data("handler_settings.settings"))
    allow(instance).to receive(:get_validation_key).and_return("")
    instance.run
  end
end