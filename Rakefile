
# To create a zip file for publishing handler?

# To run tests (rspec)?

# May be task to publish the release-version of zip to azure using azure apis (release automation)

require 'rake/packagetask'
require 'uri'
require 'net/http'
require 'json'
require 'zip'

PACKAGE_NAME = "ChefExtensionHandler"
EXTENSION_VERSION = "1.0"
CHEF_BUILD_DIR = "pkg"
PESTER_VER_TAG = "2.0.4" # we lock down to specific tag version
PESTER_GIT_URL = 'https://github.com/pester/Pester.git'
PESTER_SANDBOX = './PESTER_SANDBOX'

# Array of hashes {src : dest} for files to be packaged
LINUX_PACKAGE_LIST = [
  {"ChefExtensionHandler/*.sh" => "#{CHEF_BUILD_DIR}/"},
  {"ChefExtensionHandler/bin/*.sh" => "#{CHEF_BUILD_DIR}/bin"},
  {"ChefExtensionHandler/bin/*.rb" => "#{CHEF_BUILD_DIR}/bin"},
  {"ChefExtensionHandler/bin/chef-client" => "#{CHEF_BUILD_DIR}/bin"},
  {"*.gem" => "#{CHEF_BUILD_DIR}/gems"},
  {"ChefExtensionHandler/HandlerManifest.json.nix" => "#{CHEF_BUILD_DIR}/HandlerManifest.json"}
]

WINDOWS_PACKAGE_LIST = [
  {"ChefExtensionHandler/*.cmd" => "#{CHEF_BUILD_DIR}/"},
  {"ChefExtensionHandler/bin/*.bat" => "#{CHEF_BUILD_DIR}/bin"},
  {"ChefExtensionHandler/bin/*.ps1" => "#{CHEF_BUILD_DIR}/bin"},
  {"ChefExtensionHandler/bin/*.psm1" => "#{CHEF_BUILD_DIR}/bin"},
  {"ChefExtensionHandler/bin/*.rb" => "#{CHEF_BUILD_DIR}/bin"},
  {"ChefExtensionHandler/bin/chef-client" => "#{CHEF_BUILD_DIR}/bin"},
  {"*.gem" => "#{CHEF_BUILD_DIR}/gems"},
  {"ChefExtensionHandler/HandlerManifest.json" => "#{CHEF_BUILD_DIR}/HandlerManifest.json"}
]

# Helpers
def windows?
  if RUBY_PLATFORM =~ /mswin|mingw|windows/
    true
  else
    false
  end
end

def download_chef(download_url, target)
  puts "Downloading from url [#{download_url}]"
  uri = URI(download_url)
  Net::HTTP.start(uri.host) do |http|
    begin
        file = open(target, 'wb')
        http.request_get(uri.request_uri) do |response|
          case response
          when Net::HTTPSuccess then
            file = open(target, 'wb')
            response.read_body do |segment|
              file.write(segment)
            end
          when Net::HTTPRedirection then
            location = response['location']
            puts "WARNING: Redirected to #{location}"
            download_chef(location, target)
          else
            puts "ERROR: Download failed. Http response code: #{response.code}"
          end
        end
    ensure
      file.close if file
    end
  end
end

def load_build_environment(platform)
  puts "\n*************************************"
  puts "Reading build options from Build.json"
  puts "*************************************\n\n"
  build_options = JSON.parse(File.read("Build.json"))[platform]
  # TODO - we can extend this to form the download url using
  # additional params like machine_os, arch etc.
  download_url = build_options["download_url"]
  download_url
end

desc "Builds a azure chef extension gem."
task :gem => [:clean] do
  puts "Building gem file..."
  puts %x{gem build *.gemspec}
end

desc "Builds the azure chef extension package Ex: build[platform], default is build[windows]."
task :build, [:target_type] => [:gem] do |t, args|
  args.with_defaults(:target_type => "windows")

  download_url = load_build_environment(args.target_type)

  puts "Building #{args.target_type} package..."
  # setup the sandbox
  FileUtils.mkdir_p CHEF_BUILD_DIR
  FileUtils.mkdir_p "#{CHEF_BUILD_DIR}/bin"
  FileUtils.mkdir_p "#{CHEF_BUILD_DIR}/gems"
  FileUtils.mkdir_p "#{CHEF_BUILD_DIR}/installer"
  
  # Copy platform specific files to package dir
  puts "Copying #{args.target_type} scripts to package directory..."
  package_list = if args.target_type == "windows"
    WINDOWS_PACKAGE_LIST
  else
    LINUX_PACKAGE_LIST
  end

  package_list.each do |rule|
    src = rule.keys.first
    dest = rule[src]
    puts "Copy: src [#{src}] => dest [#{dest}]"
    if File.directory?(dest)
      FileUtils.cp_r Dir.glob(src), dest
    else
      FileUtils.cp Dir.glob(src).first, dest
    end
  end

  puts "Downloading chef installer..."
  target_chef_pkg = case args.target_type
                    when "ubuntu"
                      "#{CHEF_BUILD_DIR}/installer/chef-client-latest.deb"
                    when "centos"
                      "#{CHEF_BUILD_DIR}/installer/chef-client-latest.rpm"
                    else
                      "#{CHEF_BUILD_DIR}/installer/chef-client-latest.msi"
                    end
                    
  download_chef(download_url, target_chef_pkg)

  puts "Creating a zip package..."
  Zip::File.open("#{PACKAGE_NAME}_#{EXTENSION_VERSION}.zip", Zip::File::CREATE) do |zipfile|
    Dir[File.join("#{CHEF_BUILD_DIR}/", '**', '**')].each do |file|
      zipfile.add(file.sub("#{CHEF_BUILD_DIR}/", ''), file)
    end
  end
end

desc "Cleans up the package sandbox"
task :clean do
  puts "Cleaning Chef Package..."
  FileUtils.rm_f(Dir.glob("*.zip"))
  puts "Deleting #{CHEF_BUILD_DIR} and #{PESTER_SANDBOX}"
  FileUtils.rm_rf(Dir.glob("#{CHEF_BUILD_DIR}"))
  FileUtils.rm_rf(Dir.glob("#{PESTER_SANDBOX}"))
  puts "Deleting gem file..."
  FileUtils.rm_f(Dir.glob("*.gem"))
end

task :init_pester do
  puts "Initializing Pester to run powershell unit tests..."
  puts %x{powershell -Command if (Test-Path "#{PESTER_SANDBOX}") {Remove-Item -Recurse -Force #{PESTER_SANDBOX}"}}
  puts %x{powershell "mkdir #{PESTER_SANDBOX}; cd #{PESTER_SANDBOX}; git clone --branch #{PESTER_VER_TAG} \'#{PESTER_GIT_URL}\'"; cd ..}
end

# Its runs pester unit tests
# have a winspec task that can be used to trigger tests in jenkins
desc "Runs pester unit tests ex: rake spec[\"spec\\ps_specs\\sample.Tests.ps1\"]"
task :winspec, [:spec_path] => [:init_pester] do |t, args|
  puts "\nRunning unit tests for powershell scripts..."
  # Default: runs all tests under spec dir,
  # user can specify individual test file
  # Ex: rake spec["spec\ps_specs\sample.Tests.ps1"]
  args.with_defaults(:spec_path => "spec/ps_specs")

  # run pester tests
  puts %x{powershell -ExecutionPolicy Unrestricted Import-Module #{PESTER_SANDBOX}/Pester/Pester.psm1; Invoke-Pester -relative_path #{args.spec_path}}
end

# rspec
begin
  require 'rspec/core/rake_task'
  desc "Run all specs in spec directory"
  RSpec::Core::RakeTask.new(:spec) do |t|
    t.rspec_opts = ["--format", "nested"]
    t.pattern = 'spec/unit/**/*_spec.rb'
  end
rescue LoadError
  STDERR.puts "\n*** RSpec not available. (sudo) gem install rspec to run unit tests. ***\n\n"
end