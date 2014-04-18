require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require 'chef/azure/helpers/parse_json'

describe JSONFileReader do
  file_content = '[{ "name": "Test", "version": "1.0" }]'
  let (:instance) {JSONFileReader.new(file_content, 'name', 'version'){|obj| obj.should_receive(:deserialize_json).and_return(true)}}
  it { expect {instance}.to_not raise_error }
  it { expect {instance.read_value}.to_not raise_error }
  it { expect {instance.get_deserialized_objects}.to_not raise_error }
  it { expect {instance.send(:deserialize_json, file_content)}.to_not raise_error }

  context "is_alphanumeric" do
   it "returns true if the sequence is a alphabatic/numeric/alphanumeric string, false otherwise." do
   instance.send(:is_alphanumeric, "123").should be true
   instance.send(:is_alphanumeric, "file").should be true
   instance.send(:is_alphanumeric, "file123").should be true
   instance.send(:is_alphanumeric, " ").should be false
    end
  end

  context "is_numeric" do
   it "returns true if the sequence is a numeric string , false otherwise." do
   instance.send(:is_numeric, "123").should be true
   instance.send(:is_numeric, "file").should be false
   instance.send(:is_numeric, "file123").should be false
    end
  end
end

describe JSONFileReader do
  file_content = '[{ "name": "Test", "version": "1.0" }]'
  let (:instance) {JSONFileReader.new(file_content, 'test', "test2"){|obj| obj.should_receive(:deserialize_json).and_return(true)}}
  it { STDERR.should_receive(:puts).with('Failed to deserialize the following object:
{"name"=>"Test", "version"=>"1.0"}')
    expect {instance.read_value}.to raise_error
     }
end

describe "get_jsonreader_object" do
  it "returns a JSONFileReader object." do
    file_content = '[{ "name": "Test", "version": "1.0" }]'
    get_jsonreader_object(file_content, "name").class.should eq JSONFileReader
  end
end

describe "escape_unescaped_content" do
  it "escapes unescaped content." do
    file_content = '[{ "name": "Test", "version": "1.0" }]'
    escape_unescaped_content(file_content).should eq "[{ \"name\": \"Test\", \"version\": \"1.0\" }]\n"
  end
end

describe "value_from_json_file" do
  it "returns json value from the supplied json file_content." do
    file_content = '[{ "name": "Test", "version": "1.0" }]'
    value_from_json_file(file_content, "name").should eq "Test"
  end
end

describe "value_from_json_file" do
  it "returns json multi-lined value from the supplied json file_content." do
    file_content = '[{ "name": "Test", "version": "1.0", "data": "first line
    second line
    third line
    " }]'
    value_from_json_file(file_content, "data").should eq "first line\nsecond line\nthird line\n"
  end
end

describe "value_from_json_file" do
  it "returns json multi-lined value from the supplied json file." do
    file =  File.expand_path(File.dirname("spec/assets/*"))+"/test_json_file.txt"
    value_from_json_file(file, "data").should eq "first line\nsecond line\nthird line\n"
  end
end
