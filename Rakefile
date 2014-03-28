
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

task :build do
  puts "Building Chef Package..."
  puts %x{powershell "scripts\\createzip.ps1 #{CHEF_BUILD_DIR} #{PACKAGE_NAME}_#{VERSION}.zip #{PACKAGE_NAME}"}
end

task :clean do
  puts %x{ powershell -Command if (Test-Path "#{CHEF_BUILD_DIR}") { Remove-Item -Recurse -Force "#{CHEF_BUILD_DIR}"}}
  puts %x{powershell -Command if (Test-Path "#{PESTER_SANDBOX}") {Remove-Item -Recurse -Force #{PESTER_SANDBOX}"}}
end

task :init_pester do
  puts "Initializing Pester to run powershell unit tests..."
  puts %x{powershell -Command if (Test-Path "#{PESTER_SANDBOX}") {Remove-Item -Recurse -Force #{PESTER_SANDBOX}"}}
  puts %x{powershell "mkdir #{PESTER_SANDBOX}; cd #{PESTER_SANDBOX}; git clone --branch #{PESTER_VER_TAG} \'#{PESTER_GIT_URL}\'"; cd ..}
end

# Its runs pester unit tests
task :spec, [:spec_path] => [:init_pester] do |t, args|
  puts "\nRunning unit tests..."
  # Default: runs all tests under spec dir,
  # user can specify individual test file
  # Ex: rake spec["spec/sample.Tests.ps1"]
  args.with_defaults(:spec_path => "spec")

  # run pester tests
  puts %x{powershell -ExecutionPolicy Unrestricted Import-Module #{PESTER_SANDBOX}/Pester/Pester.psm1; Invoke-Pester -relative_path #{args.spec_path}}
end