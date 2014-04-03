
# To create a zip file for publishing handler?

# To run tests (rspec)?

# May be task to publish the release-version of zip to azure using azure apis (release automation)

require 'rake/packagetask'

PACKAGE_NAME = "ChefExtensionHandler"
VERSION = "1.0"
CHEF_BUILD_DIR = "pkg"
PESTER_VER_TAG = "2.0.4" # we lock down to specific tag version
PESTER_GIT_URL = 'https://github.com/pester/Pester.git'
PESTER_SANDBOX = './PESTER_SANDBOX'

task :build, [:chef_version, :machine_os, :machine_arch] => [:clean] do |t, args|
  args.with_defaults(:chef_version => nil, :machine_os => "2008r2", :machine_arch => "x86_64")
  puts "Building Chef Package..."
  puts %x{powershell -executionpolicy unrestricted "scripts\\createzip.ps1 #{CHEF_BUILD_DIR} #{PACKAGE_NAME}_#{VERSION}.zip #{PACKAGE_NAME} #{args.machine_os} #{args.machine_arch} #{args.chef_version}"}
end

task :clean do
<<<<<<< HEAD
  puts "Cleaning Chef Package..."
  puts %x{ powershell -Command if (Test-Path "#{CHEF_BUILD_DIR}") { Remove-Item -Recurse -Force "#{CHEF_BUILD_DIR}"}}
  puts %x{powershell -Command if (Test-Path "#{PESTER_SANDBOX}") {Remove-Item -Recurse -Force #{PESTER_SANDBOX}"}}
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