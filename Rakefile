
# To create a zip file for publishing handler?

# To run tests (rspec)?

# May be task to publish the release-version of zip to azure using azure apis (release automation)

require 'rake/packagetask'
require 'uri'
require 'net/http'

PACKAGE_NAME = "ChefExtensionHandler"
VERSION = "1.0"
CHEF_BUILD_DIR = "pkg"
PESTER_VER_TAG = "2.0.4" # we lock down to specific tag version
PESTER_GIT_URL = 'https://github.com/pester/Pester.git'
PESTER_SANDBOX = './PESTER_SANDBOX'

# Helpers
def download_chef(download_url, target)
  uri = URI(download_url)
  Net::HTTP.start(uri.host) do |http|
    begin
        file = open(target, 'wb')
        http.request_get(uri.request_uri) do |response|
          response.read_body do |segment|
            file.write(segment)
          end
        end
    ensure
      file.close
    end
  end
end

task :build, [:chef_version, :machine_os, :machine_arch] => [:clean] do |t, args|
  args.with_defaults(:chef_version => nil, :machine_os => "2008r2", :machine_arch => "x86_64")
  puts "Building Chef Package..."
  puts %x{powershell -executionpolicy unrestricted "scripts\\createzip.ps1 #{CHEF_BUILD_DIR} #{PACKAGE_NAME}_#{VERSION}.zip #{PACKAGE_NAME} #{args.machine_os} #{args.machine_arch} #{args.chef_version}"}
end

task :gem => [:clean] do
  puts "Building gem file..."
  puts %x{gem build *.gemspec}
end

task :linux => [:gem] do |t, args|
  args.with_defaults(:chef_version => nil, :download_url => "https://opscode-omnibus-packages.s3.amazonaws.com/ubuntu/13.04/x86_64/chef_11.10.4-1.ubuntu.13.04_amd64.deb")
  puts "Building linux package..."
  # setup the sandbox
  FileUtils.mkdir_p CHEF_BUILD_DIR

  # Copy linux specific files to package dir
  puts "Copying linux scripts from ChefExtensionHandler/ to #{CHEF_BUILD_DIR}/"
  FileUtils.cp_r Dir.glob("ChefExtensionHandler/*.sh"), "#{CHEF_BUILD_DIR}/"
  puts "Copying linux bin files from ChefExtensionHandler to #{CHEF_BUILD_DIR}/bin"
  FileUtils.mkdir_p "#{CHEF_BUILD_DIR}/bin"
  FileUtils.cp_r Dir.glob("ChefExtensionHandler/bin/*.sh"), "#{CHEF_BUILD_DIR}/bin"
  FileUtils.cp_r Dir.glob("ChefExtensionHandler/bin/*.rb"), "#{CHEF_BUILD_DIR}/bin"
  FileUtils.cp_r Dir.glob("ChefExtensionHandler/bin/chef-client"), "#{CHEF_BUILD_DIR}/bin"

  puts "Copying the gem file to package"
  FileUtils.mkdir_p "#{CHEF_BUILD_DIR}/gems"
  FileUtils.cp_r Dir.glob("*.gem"), "#{CHEF_BUILD_DIR}/gems"

  puts "Copying the installer file to package"
  FileUtils.mkdir_p "#{CHEF_BUILD_DIR}/installer"
  puts "Downloading chef installer..."
  download_chef(args.download_url, "#{CHEF_BUILD_DIR}/installer/chef-client-latest.deb")
  # TODO Download the chef installer 

  puts "Copy the extension configs..."
  FileUtils.cp_r "ChefExtensionHandler/HandlerManifest.json.nix", "#{CHEF_BUILD_DIR}/HandlerManifest.json"

end

task :clean do
  puts "Cleaning Chef Package..."
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
    t.pattern = 'spec/unit/**/*_spec.rb'
  end
rescue LoadError
  STDERR.puts "\n*** RSpec not available. (sudo) gem install rspec to run unit tests. ***\n\n"
end