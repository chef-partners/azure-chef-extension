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
  end

  private

  def deserialize_json(file)
    normalized_content = `powershell -nologo -noninteractive -noprofile -command \"get-content #{file}\"`
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
  file = nil

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
  puts "\nparse_json_file"
  parse_json_file "#{ARGV[0]}"

  puts "\n\nvalue_from_json_file, version"
  value_from_json_file "#{ARGV[0]}", "version"

  if ARGV.length > 2
  puts "\n\nvalue_from_json_file, #{ARGV[1]},#{ARGV[2]}"
  value_from_json_file "#{ARGV[0]}", "handlerManifest", "installCommand"
  end
end
