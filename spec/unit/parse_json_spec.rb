require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require 'chef/azure/helpers/parse_json'

describe JSONFileReader do
  file_content = '[{ "name": "Test", "version": "1.0" }]'
  let (:instance) {JSONFileReader.new(file_content, 'name', 'version'){|obj| expect(obj).to receive(:deserialize_json).and_return(true)}}
  it { expect {instance}.to_not raise_error }
  it { expect {instance.read_value}.to_not raise_error }
  it { expect {instance.get_deserialized_objects}.to_not raise_error }
  it { expect {instance.send(:deserialize_json, file_content)}.to_not raise_error }

  context "is_alphanumeric" do
   it "returns true if the sequence is a alphabatic/numeric/alphanumeric string, false otherwise." do
   expect(instance.send(:is_alphanumeric, "123")).to be true
   expect(instance.send(:is_alphanumeric, "file")).to be true
   expect(instance.send(:is_alphanumeric, "file123")).to be true
   expect(instance.send(:is_alphanumeric, " ")).to be false
    end
  end

  context "is_numeric" do
   it "returns true if the sequence is a numeric string , false otherwise." do
   expect(instance.send(:is_numeric, "123")).to be true
   expect(instance.send(:is_numeric, "file")).to be false
   expect(instance.send(:is_numeric, "file123")).to be false
    end
  end
end

describe JSONFileReader do
  file_content = '[{ "name": "Test", "version": "1.0" }]'
  let (:instance) {JSONFileReader.new(file_content, 'test', "test2"){|obj| expect(obj).to receive(:deserialize_json).and_return(true)}}
  it { expect(STDERR).to receive(:puts).with('Failed to deserialize the following object:
{"name"=>"Test", "version"=>"1.0"}')
    expect {instance.read_value}.to raise_error
     }
end

describe "get_jsonreader_object" do
  it "returns a JSONFileReader object." do
    file_content = '[{ "name": "Test", "version": "1.0" }]'
    expect(get_jsonreader_object(file_content, "name").class).to eq JSONFileReader
  end
end

describe "escape_unescaped_content" do
  it "escapes unescaped content." do
    file_content = '[{ "name": "Test", "version": "1.0" }]'
    expect(escape_unescaped_content(file_content)).to eq "[{ \"name\": \"Test\", \"version\": \"1.0\" }]\n"
  end
end

describe "value_from_json_file" do
  before do
    @multi_lined = "first line\nsecond line\nthird line\n"
  end

  it "returns json value from the supplied json file_content." do
    file_content = '[{ "name": "Test", "version": "1.0" }]'
    expect(value_from_json_file(file_content, "name")).to eq "Test"
  end

  it "returns json multi-lined value from the supplied json file_content." do
    file_content = '[{ "name": "Test", "version": "1.0", "data": "first line
    second line
    third line
    " }]'
    expect(value_from_json_file(file_content, "data")).to eq @multi_lined
  end

  it "returns json multi-lined value from the supplied json file." do
    file =  File.expand_path(File.dirname("spec/assets/*"))+"/test_json_file.json"
    expect(value_from_json_file(file, "data")).to eq @multi_lined
  end
end