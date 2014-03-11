
# To create a zip file for publishing handler?

# To run tests (rspec)?

# May be task to publish the release-version of zip to azure using azure apis (release automation)

require 'rake/packagetask'

PACKAGE_NAME = "ChefExtensionHandler"
VERSION = "1.0"
CHEF_BUILD_DIR = "pkg"

task :build do
  puts "Building Chef Package..."
  puts %x{powershell "scripts\\createzip.ps1 #{CHEF_BUILD_DIR} #{PACKAGE_NAME}_#{VERSION}.zip #{PACKAGE_NAME}"}
end

task :clean do
  puts %x{ powershell -Command if (Test-Path "#{CHEF_BUILD_DIR}") { Remove-Item -Recurse -Force "#{CHEF_BUILD_DIR}"}}
end

task :spec do
  puts "Initializing Pester to run powershell unit tests..."
  puts %x{powershell -Command if (Test-Path "../Pester") {Remove-Item -Recurse -Force ../Pester"}}
  puts %x{powershell "git clone https://github.com/muktaa/Pester ../Pester"}
end

# Its runs pester unit tests
task :pester_test, [:spec_path] => [:spec] do |t, args|
  puts "\nRunning unit tests..."
  # Default: runs all tests under spec dir,
  # user can specify individual test file
  # Ex: rake pester_test["spec/sample.Tests.ps1"]
  args.with_defaults(:spec_path => "spec")

  # run pester tests
  puts %x{powershell -ExecutionPolicy Unrestricted Import-Module ../Pester/Pester.psm1; Invoke-Pester -relative_path #{args.spec_path}}
end