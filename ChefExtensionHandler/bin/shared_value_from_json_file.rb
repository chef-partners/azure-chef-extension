require 'json'

class JSONFileReader

  public

  def initialize(file)
    @deserialized_objects = deserialize_json(file)    
  end
  
  def read_value(keys)
    json_key_path = "self"
    
    keys.each do |key|
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
      @deserialized_objects.instance_eval(json_key_path)
    rescue
      STDERR.puts "Failed to deserialize the following object:\n#{@deserialized_objects}"
      raise
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

def value_from_json_file(command_arguments)
  file = nil

  if command_arguments.length >= 2
    file = command_arguments[0]
    keys = command_arguments.last(command_arguments.length - 1)
  end
  
  if file.nil?
    puts "No file specified -- you must specify a file argument -- doing nothing."
    return 
  end

  json_reader = JSONFileReader.new(file)
  
  json_value = json_reader.read_value(keys)

  if ! json_value.is_a?(String)
    raise ArgumentError, "Specified keys #{keys.to_s} retrieved an object of type #{json_value.class} instead of a String. Retrieved value was a(n) #{json_value.class.to_s}"
  end
  
  print json_value
end

if __FILE__ == $0
  value_from_json_file(ARGV)
end




