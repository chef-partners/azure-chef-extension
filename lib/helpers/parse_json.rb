require 'json'

class JSONFileReader

  public

  def initialize(file, *keys)
    @deserialized_objects = deserialize_json(file)
    @keys = *keys
  end

  def read_value()
    json_key_path = "self"

    @keys.each do |key|
      if key == "client_rb"
        return @client_rb
      end
      path_component = key

      if path_component.length > 1024
        raise ArgumentError, "Argument #{path_component.slice(0,15)}... exceeds maximum key length"
      end

      if ! is_alphanumeric(path_component)
        raise ArgumentError, "Argument '#{path_component}' must be alphanumeric"
      end

      path_component = "'#{path_component}'"  if ! is_numeric(path_component)

      json_key_path += "[#{path_component}]"
    end

    begin
      if @deserialized_objects.kind_of?(Array)
        @deserialized_objects = @deserialized_objects[0]
      end
      (@deserialized_objects.instance_eval(json_key_path)).to_s
    rescue
      STDERR.puts "Failed to deserialize the following object:\n#{@deserialized_objects}"
      raise
    end
  end

  def get_deserialized_objects
   if @deserialized_objects.kind_of?(Array)
     @deserialized_objects = @deserialized_objects[0]
   end
   @deserialized_objects
  end

  private

  def deserialize_json(file)
    normalized_content = File.read(file)
    # This is a bad hack to handle multiple lines in client_rb field of JSON file
    unless (normalized_content.match("\\\"client_rb\\\":") .nil?)
      part1 = normalized_content.split("\"client_rb\":")
      unless (part1[1].match("\\\"runlist\\\":").nil?)
        part2 = part1[1].split("\"runlist\":")
        normalized_content = part1[0] + "\"runlist\":" + part2[1]
        @client_rb = part2[0].gsub(",\n", "").gsub("\\", "").gsub("\"", "'").gsub(" \"", "")
        @client_rb = @client_rb.strip
        @client_rb[0] = @client_rb[@client_rb.length-1] = ""
      else
        normalized_content = part1[0]
        @client_rb = part1[1].gsub(",\n", "").gsub("\\", "").gsub("\"", "'").gsub(" \"", "")
        @client_rb = @client_rb.strip
        @client_rb[0] = @client_rb[@client_rb.length-1] = ""
      end
    else
      @client_rb = ""
    end

    JSON.parse(normalized_content)
  end

  def is_alphanumeric(sequence)
    if sequence.match(/[\dA-Za-z\_]+/)
      $~[0] == sequence
    end
  end

  def is_numeric(sequence)
    if sequence.match(/[\d]+/)
      $~[0] == sequence
    end
  end
end

def get_jsonreader_object(file_name, *keys)
  file = file_name

  if file.nil?
    puts "No file specified -- you must specify a file argument -- doing nothing."
    return
  end

  json_reader = JSONFileReader.new(file, *keys)
end

def value_from_json_file(file_name, *keys)
  json_reader = get_jsonreader_object(file_name, *keys)
  json_value = json_reader.read_value()

  if ! json_value.is_a?(String)
    raise ArgumentError, "Specified keys #{keys.to_s} retrieved an object of type #{json_value.class} instead of a String. Retrieved value was a(n) #{json_value.class.to_s}"
  end

  print json_value
end

def parse_json_file(file_name)
   json_reader = get_jsonreader_object(file_name, [])
   json = json_reader.get_deserialized_objects
   print json
end

def parse_json_contents (contents)
  deserialized_contents = JSON.parse(contents)
  if deserialized_contents.kind_of?(Array)
     deserialized_contents = deserialized_contents[0]
  end
  deserialized_contents
end

unless ARGV[0].nil?
  puts
  puts "..."
  #parse_json_file "#{ARGV[0]}"
  puts
  puts
  #value_from_json_file "#{ARGV[0]}", "#{ARGV[1]}"
  puts
  puts
  #value_from_json_file "#{ARGV[0]}", "runtimeSettings", "0", "handlerSettings", "publicSettings"
  value_from_json_file 'C:\\Users\\clogeny\\github\\azure-chef-extn3\\0.settings','client_rb'
end
