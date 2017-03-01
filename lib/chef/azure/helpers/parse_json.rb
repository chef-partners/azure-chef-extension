require 'json'

class JSONFileReader

  public

  def initialize(file, *keys)
    @deserialized_objects = deserialize_json(file)
    @keys = *keys
  end

  def read_value
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
   @deserialized_objects
  end

  private

  def deserialize_json(file)
    # User may give file path or file content as input.
    if File.exists?(file)
      normalized_content = File.read(file)
    else
      normalized_content = file
    end

    begin
      JSON.parse(normalized_content)
    rescue JSON::ParserError => e
      normalized_content = escape_unescaped_content(normalized_content)
      JSON.parse(normalized_content)
    end
  end

  def is_alphanumeric(sequence)
    sequence.match(/[\dA-Za-z\_]+/) ? ($~[0] == sequence) : false
  end

  def is_numeric(sequence)
    sequence.match(/[\d]+/) ? ($~[0] == sequence) : false
  end
end

def escape_unescaped_content(file_content)
  lines = file_content.lines.to_a
  # convert tabs to spaces -- technically invalidates content, but
  # if we know the content in question treats tabs and spaces the
  # same, we can do this.
  untabified_lines = lines.map { | line | line.gsub(/\t/," ") }

  # remove whitespace and trailing newline
  stripped_lines = untabified_lines.map { | line | line.strip }
    escaped_content = ""
    line_index = 0

    stripped_lines.each do | line |
    escaped_line = line

    # assume lines ending in json delimiters are not content,
    # and that lines followed by a line that starts with ','
    # are not content
    if !!(line[line.length - 1] =~ /[\,\}\]]/) || (line_index < (lines.length - 1) && lines[line_index + 1][0] == ',')
      escaped_line += "\n"
    end

    escaped_content += escaped_line
    line_index += 1
  end
  escaped_content
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
  json_value
end

def value_from_json_file_for_ps(file_name, *keys)
  json_value = value_from_json_file(file_name, *keys)
  print json_value
end
